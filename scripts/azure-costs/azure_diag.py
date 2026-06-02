#!/usr/bin/env python3
"""
One-shot diagnostic: hit Azure Monitor against one Postgres flex server and
one storage account. Print raw HTTP status + body so we can see what's
actually failing.

    python3 azure_diag.py
"""
from __future__ import annotations
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone

try:
    import requests
except ImportError:
    for cmd in (
        [sys.executable, "-m", "pip", "install", "--user", "--quiet", "requests"],
        [sys.executable, "-m", "pip", "install", "--user", "--quiet",
         "--break-system-packages", "requests"],
    ):
        try:
            subprocess.check_call(cmd, stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)
            break
        except Exception:
            continue
    import site, importlib
    sys.path.insert(0, site.getusersitepackages())
    import requests


def env(*names):
    for n in names:
        v = os.environ.get(n)
        if v:
            return v
    return None


CLIENT_ID = env("AZURE_CLIENT_ID", "XP_AZ_AZURE_CLIENT_ID")
CLIENT_SECRET = env("AZURE_CLIENT_SECRET", "XP_AZ_AZURE_CLIENT_SECRET")
TENANT_ID = env("AZURE_TENANT_ID", "XP_AZ_AZURE_TENANT_ID")
SUB = env("AZURE_SUBSCRIPTION_ID", "XP_AZ_AZURE_SUBSCRIPTION_ID")

ARM = "https://management.azure.com"

print(f"Tenant:       {TENANT_ID}")
print(f"Subscription: {SUB}")
print(f"Client ID:    {CLIENT_ID}")
print()

# 1) Token
print("=" * 70)
print("STEP 1: Acquire token")
print("=" * 70)
r = requests.post(
    f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token",
    data={
        "grant_type": "client_credentials",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "scope": f"{ARM}/.default",
    },
    timeout=30,
)
print(f"  HTTP {r.status_code}")
if r.status_code != 200:
    print(r.text)
    sys.exit(1)
token = r.json()["access_token"]
print(f"  token len={len(token)}, expires_in={r.json().get('expires_in')}s")
print()

H = {"Authorization": f"Bearer {token}"}

# 2) Resource Graph: find one Postgres and one Storage
print("=" * 70)
print("STEP 2: Pick one Postgres + one Storage via Resource Graph")
print("=" * 70)
rg_body = {
    "subscriptions": [SUB],
    "query": (
        "Resources | where type in~ ("
        "'microsoft.dbforpostgresql/flexibleservers',"
        "'microsoft.storage/storageaccounts',"
        "'microsoft.web/sites'"
        ") | project id, type, location | top 3 by type"
    ),
    "options": {"resultFormat": "objectArray"},
}
r = requests.post(
    f"{ARM}/providers/Microsoft.ResourceGraph/resources",
    headers={**H, "Content-Type": "application/json"},
    params={"api-version": "2022-10-01"},
    json=rg_body,
    timeout=30,
)
print(f"  HTTP {r.status_code}")
if r.status_code != 200:
    print(r.text)
    sys.exit(1)
samples = r.json()["data"]
for s in samples:
    print(f"  {s['type']:55s} {s['id']}")
print()

# 3) For each sample, try Monitor metrics with several API versions / shapes
print("=" * 70)
print("STEP 3: Hit Azure Monitor metrics for each sample")
print("=" * 70)

now = datetime.now(timezone.utc).replace(microsecond=0)
start = now - timedelta(days=1)  # short window so it's fast
# Z-suffix instead of +00:00 — Azure decodes %2B as '+' then as space.
timespan = (
    f"{start.replace(tzinfo=None).isoformat()}Z/"
    f"{now.replace(tzinfo=None).isoformat()}Z"
)

metric_by_type = {
    "microsoft.dbforpostgresql/flexibleservers": ("tps", "Average"),
    "microsoft.storage/storageaccounts": ("UsedCapacity", "Maximum"),
    "microsoft.web/sites": ("Requests", "Total"),
}

API_VERSIONS = ["2024-02-01", "2023-10-01", "2021-05-01", "2019-07-01", "2018-01-01"]

for s in samples:
    rid = s["id"]
    rtype = s["type"].lower()
    metric, agg = metric_by_type.get(rtype, ("Requests", "Total"))
    print(f"\n--- {rtype} ---")
    print(f"    {rid}")
    print(f"    metric={metric}  agg={agg}  window=1d")
    for v in API_VERSIONS:
        url = f"{ARM}{rid}/providers/Microsoft.Insights/metrics"
        params = {
            "api-version": v,
            "metricnames": metric,
            "aggregation": agg,
            "interval": "PT1H",
            "timespan": timespan,
        }
        try:
            r = requests.get(url, headers=H, params=params, timeout=30)
            line = f"      api-version={v:12s} HTTP {r.status_code}"
            if r.status_code == 200:
                j = r.json()
                pts = j.get("value", [{}])[0].get("timeseries", [{}])[0].get("data", [])
                line += f"  (timeseries pts={len(pts)})"
                print(line)
                break  # working version found
            else:
                body = r.text[:400].replace("\n", " ")
                line += f"  body: {body}"
                print(line)
        except Exception as e:
            print(f"      api-version={v}  exception: {e}")

print()
print("Done.")
