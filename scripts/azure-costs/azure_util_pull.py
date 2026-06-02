#!/usr/bin/env python3
"""
Pulls trailing 30-day Azure Monitor metrics for every resource in a
subscription and emits a TSV that maps to the workbook's Data cols M-P:

    ResourceId  MoRequests  MoItemWrites  MoItemReads  DataGB

30-day aggregates are reported as-is (treat as a 30-day month for the model).

Auth: service principal via env vars. Accepts either AZURE_* or XP_AZ_AZURE_*
naming (whichever you have set).

Run:
    python3 azure_util_pull.py > util.tsv

Optional flags:
    --types pg,web,asp,storage    Restrict to a subset (default: all in-scope)
    --debug                       Verbose per-resource logging to stderr
    --workers 16                  Concurrent metric queries (default 16)
    --out util.tsv                Write TSV here instead of stdout
    --failures failures.tsv       Write a TSV of resources that errored

Only depends on Python stdlib + `requests`. If `requests` is missing the
script will pip-install it for the current user.
"""

from __future__ import annotations
import argparse
import concurrent.futures as cf
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Iterable, List, Optional, Tuple

# ---- lightweight bootstrap so user doesn't have to manage envs ---------------
def _bootstrap_requests() -> None:
    """Make `import requests` work on PEP-668 systems (Homebrew etc.) without
    asking the user to fiddle with venvs. We try, in order: import it; pip
    install --user; pip install --break-system-packages --user; finally,
    create a sibling venv at ./.azure_util_venv and re-exec inside it."""
    try:
        import requests  # noqa: F401
        return
    except ImportError:
        pass

    attempts = [
        [sys.executable, "-m", "pip", "install", "--user", "--quiet", "requests"],
        [sys.executable, "-m", "pip", "install", "--user", "--quiet",
         "--break-system-packages", "requests"],
    ]
    for cmd in attempts:
        try:
            subprocess.check_call(cmd, stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)
            # Make user site-packages importable in the current process.
            import site
            try:
                user_site = site.getusersitepackages()
                if user_site and user_site not in sys.path:
                    sys.path.insert(0, user_site)
            except Exception:
                pass
            import requests  # noqa: F401
            return
        except Exception:
            continue

    # Last resort: build a venv next to the script and re-exec inside it.
    here = os.path.dirname(os.path.abspath(__file__))
    venv_dir = os.path.join(here, ".azure_util_venv")
    venv_py = os.path.join(venv_dir, "bin", "python3")
    if not os.path.exists(venv_py):
        sys.stderr.write(f"Creating venv at {venv_dir} ...\n")
        subprocess.check_call([sys.executable, "-m", "venv", venv_dir])
    subprocess.check_call(
        [venv_py, "-m", "pip", "install", "--quiet", "--upgrade", "pip"]
    )
    subprocess.check_call(
        [venv_py, "-m", "pip", "install", "--quiet", "requests"]
    )
    sys.stderr.write(f"Re-exec under {venv_py} ...\n")
    os.execv(venv_py, [venv_py, os.path.abspath(__file__), *sys.argv[1:]])


_bootstrap_requests()
import requests  # type: ignore


# ---- env / config ------------------------------------------------------------
def env(*names: str) -> Optional[str]:
    for n in names:
        v = os.environ.get(n)
        if v:
            return v
    return None


CLIENT_ID = env("AZURE_CLIENT_ID", "XP_AZ_AZURE_CLIENT_ID")
CLIENT_SECRET = env("AZURE_CLIENT_SECRET", "XP_AZ_AZURE_CLIENT_SECRET")
TENANT_ID = env("AZURE_TENANT_ID", "XP_AZ_AZURE_TENANT_ID")
SUBSCRIPTION_ID = env("AZURE_SUBSCRIPTION_ID", "XP_AZ_AZURE_SUBSCRIPTION_ID")


def _validate_env() -> None:
    missing = []
    for label, val in [
        ("CLIENT_ID", CLIENT_ID),
        ("CLIENT_SECRET", CLIENT_SECRET),
        ("TENANT_ID", TENANT_ID),
        ("SUBSCRIPTION_ID", SUBSCRIPTION_ID),
    ]:
        if not val:
            missing.append(f"AZURE_{label} (or XP_AZ_AZURE_{label})")
    if missing:
        sys.stderr.write("Missing env: " + ", ".join(missing) + "\n")
        sys.exit(2)

ARM = "https://management.azure.com"
NOW = datetime.now(timezone.utc).replace(microsecond=0)
WINDOW_START = NOW - timedelta(days=30)
# Use 'Z' suffix instead of '+00:00' — Azure Monitor decodes %2B back to '+'
# and then misinterprets '+' as a space when parsing the timespan param.
TIMESPAN = (
    f"{WINDOW_START.replace(tzinfo=None).isoformat()}Z/"
    f"{NOW.replace(tzinfo=None).isoformat()}Z"
)
SECONDS_30D = 30 * 24 * 3600


# ---- auth --------------------------------------------------------------------
_token_cache: Dict[str, Tuple[str, float]] = {}


def get_token(resource: str = ARM) -> str:
    cached = _token_cache.get(resource)
    if cached and cached[1] > time.time() + 60:
        return cached[0]
    r = requests.post(
        f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token",
        data={
            "grant_type": "client_credentials",
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "scope": f"{resource}/.default",
        },
        timeout=30,
    )
    r.raise_for_status()
    j = r.json()
    tok = j["access_token"]
    expires = time.time() + int(j.get("expires_in", 3600))
    _token_cache[resource] = (tok, expires)
    return tok


class ArmError(Exception):
    """ARM call failed. status==0 means network/timeout (no HTTP response)."""
    def __init__(self, status: int, body: str, url: str):
        self.status = status
        self.body = body
        self.url = url
        super().__init__(f"HTTP {status} on {url}: {body}")


def _arm_call(method: str, url: str, *, params=None, payload=None) -> Dict[str, Any]:
    h = {"Authorization": f"Bearer {get_token()}"}
    if payload is not None:
        h["Content-Type"] = "application/json"
    last_exc: Optional[Exception] = None
    for attempt in range(4):
        try:
            r = requests.request(method, url, headers=h, params=params,
                                 json=payload, timeout=60)
        except requests.RequestException as e:
            last_exc = e
            time.sleep(2 ** attempt)
            continue
        if r.status_code == 429:
            wait = int(r.headers.get("Retry-After", "5"))
            time.sleep(wait)
            continue
        if 500 <= r.status_code < 600:
            time.sleep(2 ** attempt)
            last_exc = ArmError(r.status_code, r.text, r.url)
            continue
        if r.status_code >= 400:
            # Don't retry 4xx — won't recover.
            raise ArmError(r.status_code, r.text, r.url)
        try:
            return r.json()
        except ValueError:
            raise ArmError(r.status_code, r.text[:1000], r.url)
    if last_exc:
        raise last_exc
    raise ArmError(0, "exhausted retries with no response", url)


def arm_get(url: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    return _arm_call("GET", url, params=params)


def arm_post(url: str, payload: Dict[str, Any], params=None) -> Dict[str, Any]:
    return _arm_call("POST", url, params=params, payload=payload)


# ---- resource enumeration via Resource Graph --------------------------------
def enumerate_resources() -> List[Dict[str, str]]:
    """Returns [{'id': ..., 'type': ..., 'location': ...}, ...] for the sub."""
    url = f"{ARM}/providers/Microsoft.ResourceGraph/resources"
    params = {"api-version": "2022-10-01"}
    out: List[Dict[str, str]] = []
    skip_token = None
    while True:
        body = {
            "subscriptions": [SUBSCRIPTION_ID],
            "query": "Resources | project id, type, location",
            "options": {"$top": 1000, "resultFormat": "objectArray"},
        }
        if skip_token:
            body["options"]["$skipToken"] = skip_token
        j = arm_post(url, body, params=params)
        for row in j.get("data", []):
            out.append({
                "id": row["id"],
                "type": row["type"].lower(),
                "location": row.get("location", ""),
            })
        skip_token = j.get("$skipToken")
        if not skip_token:
            break
    return out


# ---- metric query helper -----------------------------------------------------
def metrics(
    resource_id: str,
    metric_names: Iterable[str],
    aggregation: str,
    interval: str = "P1D",
) -> Dict[str, List[Tuple[datetime, Optional[float]]]]:
    """Returns {metric_name: [(timestamp, value), ...]} (only points with data)."""
    url = f"{ARM}{resource_id}/providers/Microsoft.Insights/metrics"
    params = {
        "api-version": "2024-02-01",
        "metricnames": ",".join(metric_names),
        "aggregation": aggregation,
        "interval": interval,
        "timespan": TIMESPAN,
    }
    j = arm_get(url, params=params)
    out: Dict[str, List[Tuple[datetime, Optional[float]]]] = {}
    for v in j.get("value", []):
        name = v["name"]["value"]
        series: List[Tuple[datetime, Optional[float]]] = []
        for ts in v.get("timeseries", []):
            for d in ts.get("data", []):
                t = datetime.fromisoformat(d["timeStamp"].replace("Z", "+00:00"))
                # Pick the first non-null aggregation present.
                val = None
                for k in ("total", "average", "maximum", "minimum", "count"):
                    if k in d and d[k] is not None:
                        val = float(d[k])
                        break
                series.append((t, val))
        out[name] = series
    return out


def sum_total(points: List[Tuple[datetime, Optional[float]]]) -> float:
    return sum(p[1] for p in points if p[1] is not None)


def avg_then_scale_per_day(points: List[Tuple[datetime, Optional[float]]]) -> float:
    """For a per-second rate sampled per-day, return total over the 30d window."""
    vals = [p[1] for p in points if p[1] is not None]
    if not vals:
        return 0.0
    avg = sum(vals) / len(vals)  # per-second rate, averaged across days
    return avg * SECONDS_30D


def max_value(points: List[Tuple[datetime, Optional[float]]]) -> float:
    vals = [p[1] for p in points if p[1] is not None]
    return max(vals) if vals else 0.0


# ---- per-type extractors -----------------------------------------------------
# Each returns (mo_requests, mo_writes, mo_reads, data_gb).
# Anything not produced stays 0.0 (which the model treats as "no signal").

def pg_flex(rid: str) -> Tuple[float, float, float, float]:
    # `tps` requires PG14+ and an active workload, and was returning all-zero
    # for this fleet. read_iops/write_iops are universal across SKUs/versions
    # and map more directly to DynamoDB RCU/WCU pricing anyway.
    # Each daily sample is the avg IOPS for that day; multiply by 86400 to get
    # ops/day, then sum across days for total ops in the window.
    m = metrics(
        rid,
        ["read_iops", "write_iops", "storage_used"],
        aggregation="Average",
    )
    def _iops_to_ops(points):
        # Each point is an avg-iops over a 1-day interval. Convert to ops/day.
        return sum((v or 0.0) for _, v in points) * 86400.0
    writes = _iops_to_ops(m.get("write_iops", []))
    reads = _iops_to_ops(m.get("read_iops", []))
    data_gb = max_value(m.get("storage_used", [])) / (1024 ** 3)
    return (0.0, writes, reads, data_gb)


def web_site(rid: str) -> Tuple[float, float, float, float]:
    m = metrics(rid, ["Requests"], aggregation="Total")
    reqs = sum_total(m.get("Requests", []))
    return (reqs, 0.0, 0.0, 0.0)


def app_service_plan(rid: str) -> Tuple[float, float, float, float]:
    # ASPs don't have Requests metric directly. We sum requests from child sites
    # via a separate enumeration pass (kept simple: report 0 here, child sites
    # carry the signal). The Lambda cost will be computed on the web-app rows.
    return (0.0, 0.0, 0.0, 0.0)


def storage_account(rid: str) -> Tuple[float, float, float, float]:
    # Storage account metrics only allow the PT1H grain when combined; bigger
    # grains are rejected with "can not support requested time grain". Split
    # the two metrics so each can use its right aggregation.
    used_m = metrics(rid, ["UsedCapacity"], aggregation="Maximum",
                     interval="PT1H")
    tx_m = metrics(rid, ["Transactions"], aggregation="Total",
                   interval="PT1H")
    used = max_value(used_m.get("UsedCapacity", []))
    tx = sum_total(tx_m.get("Transactions", []))
    data_gb = used / (1024 ** 3)
    return (tx, 0.0, 0.0, data_gb)


def cdn_profile(rid: str) -> Tuple[float, float, float, float]:
    m = metrics(
        rid,
        ["RequestCount", "ResponseSize"],
        aggregation="Total",
    )
    reqs = sum_total(m.get("RequestCount", []))
    bytes_out = sum_total(m.get("ResponseSize", []))
    return (reqs, 0.0, 0.0, bytes_out / (1024 ** 3))


# ---- type routing ------------------------------------------------------------
HANDLERS = {
    "microsoft.dbforpostgresql/flexibleservers": ("pg", pg_flex),
    "microsoft.web/sites": ("web", web_site),
    "microsoft.web/serverfarms": ("asp", app_service_plan),
    "microsoft.storage/storageaccounts": ("storage", storage_account),
    "microsoft.cdn/profiles": ("cdn", cdn_profile),
}

# Eliminated / out-of-scope: explicitly emit zeros so we don't try to query.
SKIP = {
    "microsoft.cache/redis",
    "microsoft.network/privateendpoints",
    "microsoft.network/privatednszones",
    "microsoft.network/privatednszones/virtualnetworklinks",
    "microsoft.network/publicipaddresses",
    "microsoft.network/virtualnetworks",
    "microsoft.network/networkinterfaces",
    "microsoft.network/networksecuritygroups",
    "microsoft.containerregistry/registries",
    "microsoft.compute/disks",
    "microsoft.compute/virtualmachines",
    "microsoft.loadtestservice/loadtests",
    "microsoft.insights/components",  # App Insights ingestion is via LA query
    "microsoft.insights/actiongroups",
    "microsoft.insights/metricalerts",
    "microsoft.operationalinsights/workspaces",  # ingestion via LA query
    "microsoft.machinelearningservices/workspaces",
    "microsoft.keyvault/vaults",
    "microsoft.web/serverfarms/slot",
}


def process(resource: Dict[str, str], debug: bool) -> Tuple[str, Tuple[float, float, float, float], Optional[str]]:
    rid = resource["id"]
    rtype = resource["type"]
    if rtype in SKIP:
        return rid, (0.0, 0.0, 0.0, 0.0), None
    handler = HANDLERS.get(rtype)
    if not handler:
        return rid, (0.0, 0.0, 0.0, 0.0), None
    label, fn = handler
    try:
        vals = fn(rid)
        if debug:
            sys.stderr.write(f"OK   {label:8s} {rid} -> {vals}\n")
        return rid, vals, None
    except ArmError as e:
        # 404 typically means the resource exists in Graph but has no metrics
        # endpoint (paused server, deleted between enumeration and query, etc.)
        msg = f"HTTP {e.status} {e.body[:500].replace(chr(10), ' ')}"
        if debug:
            sys.stderr.write(f"FAIL {label:8s} {rid} : {msg}\n")
        return rid, (0.0, 0.0, 0.0, 0.0), msg
    except Exception as e:
        msg = f"{type(e).__name__}: {e}"
        if debug:
            sys.stderr.write(f"FAIL {label:8s} {rid} : {msg}\n")
        return rid, (0.0, 0.0, 0.0, 0.0), msg


# ---- main --------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--types", default="all",
                    help="Comma list of labels (pg,web,asp,storage,cdn) or 'all'")
    ap.add_argument("--debug", action="store_true")
    ap.add_argument("--workers", type=int, default=16)
    ap.add_argument("--out", default="-", help="Output TSV path or '-' for stdout")
    ap.add_argument("--failures", default=None,
                    help="If set, write a TSV of resources that errored")
    args = ap.parse_args()
    _validate_env()

    if args.types != "all":
        wanted = set(args.types.split(","))
        for k, (label, _) in list(HANDLERS.items()):
            if label not in wanted:
                del HANDLERS[k]

    sys.stderr.write(f"Enumerating resources in {SUBSCRIPTION_ID}...\n")
    resources = enumerate_resources()
    sys.stderr.write(f"  {len(resources)} resources total\n")

    in_scope = [r for r in resources if r["type"] in HANDLERS]
    sys.stderr.write(f"  {len(in_scope)} in scope for metric queries\n")
    by_type: Dict[str, int] = {}
    for r in in_scope:
        by_type[r["type"]] = by_type.get(r["type"], 0) + 1
    for t, n in sorted(by_type.items(), key=lambda x: -x[1]):
        sys.stderr.write(f"    {n:5d}  {t}\n")

    rows: List[Tuple[str, Tuple[float, float, float, float]]] = []
    failures: List[Tuple[str, str]] = []

    # Eliminated/unknown types -> emit zero rows so the workbook can XLOOKUP.
    out_of_scope_count = 0
    with cf.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = [pool.submit(process, r, args.debug) for r in resources]
        done = 0
        t0 = time.time()
        for f in cf.as_completed(futs):
            rid, vals, err = f.result()
            rows.append((rid, vals))
            if err:
                failures.append((rid, err))
            done += 1
            if done % 100 == 0:
                el = time.time() - t0
                sys.stderr.write(
                    f"  {done}/{len(futs)} done ({el:.1f}s, "
                    f"{done/el:.1f} req/s)\n"
                )

    sys.stderr.write(f"Writing {len(rows)} rows...\n")
    fh = sys.stdout if args.out == "-" else open(args.out, "w", encoding="utf-8")
    try:
        fh.write("ResourceId\tMoRequests\tMoItemWrites\tMoItemReads\tDataGB\n")
        for rid, (req, w, r, gb) in sorted(rows):
            fh.write(f"{rid}\t{req:.4f}\t{w:.4f}\t{r:.4f}\t{gb:.6f}\n")
    finally:
        if fh is not sys.stdout:
            fh.close()

    if args.failures and failures:
        with open(args.failures, "w", encoding="utf-8") as f:
            f.write("ResourceId\tError\n")
            for rid, err in failures:
                f.write(f"{rid}\t{err}\n")
        sys.stderr.write(f"  {len(failures)} failures -> {args.failures}\n")
    elif failures:
        sys.stderr.write(f"  {len(failures)} failures (rerun with --failures FILE)\n")

    sys.stderr.write("Done.\n")


if __name__ == "__main__":
    main()
