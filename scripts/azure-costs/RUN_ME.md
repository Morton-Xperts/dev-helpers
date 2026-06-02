# Pull 30d Azure utilization

Run this from any shell where your `XP_AZ_AZURE_*` env vars are already loaded
(the dev-helpers terminal you showed earlier works).

```bash
python3 azure_util_pull.py --out util.tsv --failures util_failures.tsv --debug
```

Expected runtime: a few minutes (the script fans out 16 concurrent metric
queries against Azure Monitor). It will print per-type counts and progress to
stderr.

When it finishes, drop `util.tsv` (and `util_failures.tsv` if non-empty) back
into the chat — I'll take it from there and drive the paste into the workbook.

## What it does

1. Auths as the service principal via the env vars.
2. Lists every resource in subscription `c5a9afc7-...` via Resource Graph.
3. For each resource of an in-scope type, queries Azure Monitor for the
   trailing 30 days:
   - **PostgreSQL flex**: `tps` (averaged → total tx), split into reads/writes
     by the `read_iops`/`write_iops` ratio (or 70/30 if no signal);
     `storage_used` max → `DataGB`.
   - **App Service web app (`Microsoft.Web/sites`)**: `Requests` sum → `MoRequests`.
   - **Storage account**: `UsedCapacity` max → `DataGB`; `Transactions` sum → `MoRequests`.
   - **CDN profile**: `RequestCount` → `MoRequests`; `ResponseSize` → `DataGB`.
   - **App Service plan**: zero (signal lives on the child sites).
4. Eliminated/skipped types (Redis, private endpoints, ACR, etc.) get all
   zeros — the workbook treats them as no utilization.
5. Writes `util.tsv` with columns:
   `ResourceId | MoRequests | MoItemWrites | MoItemReads | DataGB`.

## What it does NOT do

- Log Analytics / App Insights ingestion volume (lives in `Usage` table via
  Log Analytics query API, not Monitor metrics). Their cost rolls to CloudWatch
  Logs in the AWS model and the rate-card default kicks in. Tell me if you
  want me to add a `LogAnalyticsDataClient` pass.
- ML Services workspace (tabled per your notes).

## Auth scope needed

The service principal needs `Reader` on the subscription. If you get 403s on
`Microsoft.Insights/metrics/read`, add `Monitoring Reader` too.
