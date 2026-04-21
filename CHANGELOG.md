# Changelog

All notable changes to BoilStream will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.10.7] - 2026-04-20

### Features

- **Horizontal PGWire scaling with leader-exclusive auth state**: non-leader pods now complete SCRAM-SHA-256 auth locally by fetching the password hash from the leader over the internal mTLS cluster API (:8444), rather than requiring cross-pod replication of `users.duckdb`. The `temp_credentials` table stays leader-exclusive — no new per-pod cred sync, no stale replicas, no extra storage — while every pod can accept PGWire connections and run the subsequent query session. One short gRPC round-trip at connect time on workers; queries themselves run locally.
  - **Why it matters**: `app.boilstream.com:5432` as a bare load-balanced entry point now just works. Clients don't need to parse the leader hostname out of a 307 redirect or pin to a pod-specific SNI; any pod accepts the connection and the auth path converges to a consistent hash on the leader. Fixes the ~50% auth-failure-rate observation in 2-pod Hetzner deploys under the `boilstream-any-*` TLSRoutes.
  - **How it works**: `OAuthCredentialStore::get_scram_hash()` now consults the cluster coordinator; on non-leader pods it opens a tonic mTLS channel to `{leader.host}:{internal_port}` and calls the new `ClusterSync.GetScramHash(username)` RPC. Leader answers from its local DuckDB `temp_credentials`. The RPC reuses the existing `ClusterTlsConfig` (cert_path / key_path / ca_cert_path) so no new cert material is required.
  - **New proto**: `GetScramHash(GetScramHashRequest) returns (GetScramHashResponse)` on the `ClusterSync` service. Request is a single `username` string; response carries the SCRAM-SHA-256 hash plus a `found` flag to disambiguate not-found from genuinely-empty. Backwards compatible — workers connecting to a pre-0.10.7 leader just fall back to their local (empty) lookup and surface the standard "Invalid username or password" error.
- **FlightRPC ingestion and FlightSQL consumer servers now serve TLS**: the top-level `tls.disabled: false` block is now honored end-to-end. All three Flight servers (ingestion Thread 1 on `:50051`, admin, consumer FlightSQL on `:50250`) present the configured identity; the Envoy Gateway `TLSRoute` passthrough works through to the backend. Previously the Hetzner chart's `flight` listener targeted `:50050` (Thread 0) while clients and docs referenced `:50051` (Thread 1, the canonical entry point) — that's now aligned on `50051` in the chart, with a new `flightsql` listener for `50250`.

### Notes

- **PGWire clients should use `sslnegotiation=direct` (libpq 17+)**. BoilStream's PGWire SSL handshake runs via ALPN and pure-TLS (not the PG-classic plaintext `SSLRequest` → `S` negotiation); direct-TLS is what Envoy passes through. Older libpq (<17) + `sslmode=require` without direct negotiation will fail with "received direct SSL connection request without ALPN protocol negotiation extension".
- Chart version **0.3.13** tracks appVersion `0.10.7`. Contains the new `BackendTrafficPolicy` CRDs for source-IP consistent-hash LB on the `boilstream-any-*` TLSRoutes, so clients behind different source IPs stay on the same pod across auth + data-plane listeners (the SCRAM fallback above means this is no longer a correctness requirement, but it keeps per-connection latency predictable by avoiding the leader round-trip when the pod is already the leader).
- Flight TLS gating is driven by the `TLS_CERT_PATH` / `TLS_KEY_PATH` environment variables on non-free-tier builds (see `src/tls.rs::load_tls_config_from_env`). The Hetzner chart's StatefulSet now exports these to `/tls/tls.crt` and `/tls/tls.key` — the same wildcard cert that pgwire and kafka already mount. No new Secrets required.

## [0.10.6] - 2026-04-20

### Fixes

- **SIGILL on ARM64 hosts without SHA3 / SHA512 hardware** (Ampere Altra / Neoverse N1: Hetzner cax*, Oracle Ampere A1, AWS Graviton 2): the `aarch64-generic-linux-0.10.5` binary shipped `sha512h`, `sha512su0`, `sha512su1`, `bcax`, `eor3`, `rax1`, `xar` instructions. `/proc/cpuinfo` on these CPUs correctly reports `aes pmull sha1 sha2 crc32 asimddp` without `sha3 sha512`, so every code path that hit those insns crashed with exit code 132 (SIGILL). Root cause: the previous "-generic" artefact was built on Apple Silicon under OrbStack, and that VM exposes `sha3`+`sha512` in `/proc/cpuinfo`; `aws-lc-sys`, `openssl-sys`, `nettle-sys` each autodetect CPU features at build time and compile in hardware-accelerated paths when the *build host* supports them, regardless of `RUSTFLAGS` / `CFLAGS` overrides.
  - **Fix**: `aarch64-generic-linux-0.10.6` is now built on AWS EC2 `c6gd.8xlarge` (Graviton 2 = Neoverse N1) — same microarchitecture as Ampere Altra — so the C autoconf layer in `nettle-sys` / `openssl-sys` never sees SHA3/SHA512 in `/proc/cpuinfo` and never compiles unconditional (non-runtime-dispatched) calls into those libraries. `aws-lc-sys` still ships its own pre-generated SHA3/SHA512 assembly, but it is guarded by `HWCAP_SHA3` / `HWCAP_SHA512` runtime checks and takes a scalar fallback on Ampere, so those insns remain in the binary as dead code. Verified empirically: 60/60 OPAQUE signups (20 sequential + 2×20 parallel) against a 0.10.6 leader pod on Hetzner Ampere Altra (Hetzner cax21) with zero pod restarts.
  - **Impact**: every OPAQUE-heavy auth path (`/auth/email/signup`, `/auth/email/login`, SCIM provisioning, TOTP enrollment) reliably crashed the pod on Ampere hosts. Kubelet restarted the container so the workload kept making forward progress, but ~every successful request cost a restart cycle. `0.10.6` eliminates the crash entirely.
- **Hetzner / CloudFleet clusters running `0.10.5` MUST upgrade to `0.10.6`** to avoid the SIGILL. AWS Graviton 2+ customers using the `aarch64-generic-linux` image should also upgrade (they'd hit the same crash on Graviton 2 but are unaffected on Graviton 3+). The `aarch64-linux-0.10.5` (Graviton-tuned, separate artefact) is NOT affected — it's built on c7gd.8xlarge and intentionally targets Neoverse V1+ features.

### Notes

- **Only `aarch64-generic-linux` is rebuilt at 0.10.6.** The other platforms (`darwin-aarch64`, `linux-aarch64` Graviton-tuned, `linux-x64`) never had the SIGILL — their build hosts matched their release targets — so they stay at `0.10.5`. No action needed for users on those variants.
- `aarch64-linux-0.10.5` (AWS Graviton-tuned) is still built on `c7gd.8xlarge` (Graviton 3 = Neoverse V1) and keeps SHA3+SHA512 hardware paths — AWS Graviton 3/4 users should use that variant for the perf.
- Chart version **0.3.11** tracks appVersion `0.10.6`.

## Chart [0.3.10] - 2026-04-20

### Fixes

- **3-way Karpenter/CloudFleet deadlock on `values-hetzner-example.yaml`**: During the 0.10.5 rollout the Hetzner/CloudFleet cluster repeatedly wedged with pods stuck `Pending` and phantom `Unknown` NodeClaims piling up. Root cause: the example's **hard pod anti-affinity** (`requiredDuringSchedulingIgnoredDuringExecution`) combined with Karpenter's aggressive `WhenEmptyOrUnderutilized` consolidation (`consolidateAfter: 1m`) meant every scale or pod-kill event tainted existing nodes `karpenter.sh/disrupted:NoSchedule` to drain them, while CFKE's locked `NodePool.limits.cpu: "16"` blocked Karpenter from provisioning replacements. Result: no node could accept the pods (all tainted) and no new node could be launched (over cap). Fix ships two values-hetzner-example defaults: `anti-affinity.preferredDuringSchedulingIgnoredDuringExecution` (pods still prefer distinct nodes but may co-locate during churn), and a `karpenter.sh/disrupted:NoSchedule` toleration so pods can temporarily schedule on draining nodes. App code (`0.10.5`) unchanged.

## [0.10.5] - 2026-04-20

### Fixes

- **Auth-database backup/restore in K8s cluster mode**: The pre-0.10.5 flow used `EXPORT DATABASE` / `IMPORT DATABASE` against an already-attached users / superadmin DuckDB database. On every pod restart after 0.10.3 enabled `/data`-emptyDir backup-to-S3, `IMPORT DATABASE` collided on pre-created objects (e.g. `duckdb_secrets_id_seq`) and the restore retried forever, so the emptyDir rollover effectively wiped the user table each time a pod was rescheduled. Replaced with a byte-level file snapshot (CHECKPOINT + `fs::copy` of the on-disk `.duckdb` file, gzip, S3 PUT) that the server atomically drops into place BEFORE the DuckDB ATTACH on the next boot. No schema replay, no sequence collisions, no retry loops.
- **Leader-failover correctness in 2+ pod clusters**: On leader failover, the newly-promoted worker's local auth DB was stale (the previous leader had been writing locally since this worker's last boot-time S3 restore) and the promotion path kept serving those stale reads as the new leader. 0.10.5 purges the local `/data/users.duckdb` + `data/superadmin.duckdb` and calls `std::process::exit(1)` on worker→leader transition; Kubernetes restarts the container and the normal boot path pulls the latest S3 snapshot before ATTACH + re-enters election with authoritative data.
- **Non-leader shutdown no longer clobbers S3**: `perform_shutdown_backup` and `perform_backup_with_retry` now check `is_leader()` before uploading. Previously a stale worker receiving SIGTERM would upload its local (potentially older) snapshot and overwrite the authoritative blob written by the live leader. Non-leaders on shutdown now log `not the cluster leader — worker state is not authoritative and must not overwrite the leader's S3 snapshot` and exit clean.

### Features

- **Helm chart — optional `updateStrategy.rollingUpdate.partition`** on the StatefulSet template, for explicit canary rollouts (update pod-1 first, verify, then lift the partition for pod-0).
- **Helm chart — `users_backup_path`** defaults to `auth/users.snapshot.duckdb.gz` (new format); `superadmin_backup_path` falls through to `backups/superadmin/superadmin.snapshot.duckdb.gz` via server-side defaults so no explicit config is needed.
- Chart version **0.3.9** / appVersion **0.10.5**.

### Verified on the Hetzner/CloudFleet cluster (`de29ffdf-…`)

- 6 test users + superadmin persist across both `pod-0→pod-1` and `pod-1→pod-0` leader deletions.
- S3 snapshot stays consistent at 28,066,348 bytes across both pods post-failover.
- Promoted pod logs show the expected `"💥 Promoted from worker to leader — purging local auth DBs..."` → `Deleted local database: /data/users.duckdb` → `✅ Restored users database from S3 snapshot` sequence on the container restart.

### Upgrade notes

- Any `auth/users.duckdb` (old `tar.gz` format from 0.10.3) left in S3 is orphaned by this release — safe to delete. The new backup writes to a fresh key, so there is no format-upgrade migration on the bucket; the old blob just becomes unreferenced.
- Rolling 0.10.3 → 0.10.5 through 0.10.4 is **not** supported: 0.10.4 was only ever an iterative Docker-tag build (never git-tagged) and had known promotion-staleness bugs in the `b1`/`b2` sub-builds. Roll directly from 0.10.3 to 0.10.5.

## [0.10.2] - 2026-04-19

### Fixes

- **WebAuthn passkey enrollment in K8s cluster mode**: Broker→leader redirects land the browser on a per-pod subdomain (`boilstream-N.<domain>`) different from the configured `webauthn_rp_origin`, and webauthn-rs's strict origin check rejected the ceremony with `HTTP 400 – Registration failed - The clients relying party origin does not match our servers information`.

### Features

- **`webauthn_additional_rp_origins` server config**: Optional list of extra origins accepted during WebAuthn registration/authentication. `rp_id` stays as the base domain so credentials roam across all pods; `rp_origin` is the canonical primary URL; the new list covers the redirect-target subdomains.
- **Helm chart**: ConfigMap overlay auto-renders both `:443` and `:8443` variants of every per-pod subdomain (`boilstream-0.<domain>`, …) into `webauthn_additional_rp_origins`. Chart version **0.3.5**.

## [0.10.1] - 2026-04-19

### Fixes

- **Cluster admin redirects + responses use public hostname**: Broker→leader redirects from the auth server's leader-check middleware, plus the `host` fields in `LeaderInfoResponse` / `BrokerInfoResponse`, now advertise an externally-reachable hostname when the new `cluster_mode.public_host` is set. Previously these paths only knew about `advertised_host` (in Kubernetes: the pod's internal headless-Service DNS, unreachable from outside the cluster), so `boilstream-admin` against a cluster's public endpoint could be redirected to a `*.svc.cluster.local` target or receive an internal hostname in the cluster status response.

### Features

- **`cluster_mode.public_host` config**: Optional per-node public hostname used for all client-facing paths — admin redirects, `boilstream-admin` cluster status responses, and future extensions for secret / bootstrap-URL vending. `advertised_host` remains the inside-the-cluster DNS name for pod-to-pod gRPC on `internal_api_port`, unchanged. Backward-compatible: missing `public_host` in S3 state (`leader.json`, `brokers/*.json`) deserialises cleanly and falls back to `host`.
- **Helm chart**: `configmap.yaml` overlay auto-renders `public_host = {POD_NAME}.{values.domain}` into each pod's runtime config, kept in sync with the per-pod `TLSRoute` resources (`boilstream-N.<domain>`). Chart version **0.3.3**.

## [0.10.0] - 2026-04-18

### Features

- **Official Kubernetes Helm Chart**: Production-ready chart for multi-pod cluster deployments
  - StatefulSet with headless Service for stable per-pod DNS
  - Per-pod ClusterIP Services exposing PGWire, Kafka, FlightRPC, auth, and cluster ports
  - Envoy Gateway integration with TLS passthrough + SNI-based routing — one external LoadBalancer IP terminates all protocols across all pods
  - cert-manager wiring: public wildcard cert (Let's Encrypt ACME, DNS-01 or HTTP-01) and a separate internal CA for pod-to-pod mTLS
  - PodDisruptionBudget, standard `app.kubernetes.io/*` labels, configurable `affinity` / `nodeSelector` / `tolerations` / `topologySpreadConstraints`
  - `preStop` hook + `terminationGracePeriodSeconds` for graceful connection drain during rolling updates
  - IRSA / Pod Identity annotations for AWS; image pull secrets for private registries
  - Superadmin password and MFA secret sourced from pre-created `Secret`s — never committed to values
  - Example overlays: `values-eks-example.yaml` (AWS / NLB) and `values-hetzner-example.yaml` (CloudFleet / Hetzner ARM64)
  - K8s production-readiness test suite under `tests/k8s/` (pod health, leader election, broker registry, SNI routing, failover)

- **Cluster-Mode mTLS**: Pod-to-pod cluster coordination traffic can now be encrypted with mutual TLS
  - Separate trust root from the public-facing cert — internal CA is isolated from browser trust
  - `cluster_mode.tls.{cert_path,key_path,ca_cert_path,require_client_cert}` configuration block
  - `require_client_cert` is now enforced at the TLS handshake (not just at the application layer)
  - Works out of the box with the chart's cert-manager `ClusterIssuer`

- **PGWire Direct-TLS ALPN**: Server now advertises the `postgresql` ALPN token during TLS negotiation, enabling `libpq >= 18` direct-TLS clients to connect without a downgrade round-trip

- **DuckDB 1.5.2**: Upgraded from 1.4.4 LTS
  - New PostgreSQL type inference for `format_type(oid, typmod)` parameter binding — now infers `[INT8, INT4]` (was `[TEXT, INT4]`). BI tools that previously relied on the old inference may need to cast explicitly
  - Inherits all DuckDB 1.5.x improvements (planner, vector operations, extension loader)

### Fixes

- **Leader heartbeat on non-AWS S3**: Heartbeat now retries with a re-read confirmation and an unconditional PUT fallback when `If-Match` ETag comparisons fail. Fixes stalled leadership on S3 implementations where ETags don't round-trip identically between GET and PUT (Hetzner Object Storage, some MinIO configurations)
- **Cluster-sync mTLS server on promotion**: The internal coordination server now starts when a worker is promoted to leader mid-life (previously only started at boot for pods that booted as leader — caused failover gaps)
- **Auth server loopback TLS**: The auth server on `:8443` now presents a self-signed loopback certificate for `localhost` / `127.0.0.1` SNI connections and the public cert for its real hostname. Fixes in-pod TLS handshakes when the public cert doesn't cover loopback addresses (e.g. Let's Encrypt deployments)

### Improvements

- **WebAuthn / RP config from single source**: The Helm chart now propagates `values.domain` into both `webauthn_rp_id` and `webauthn_rp_origin`, removing one place where the external hostname could drift
- **Helm chart de-localized**: Example charts no longer embed localhost certificates or hard-coded dev hostnames — production deploys use real FQDNs end-to-end
- **boilstream-admin wrapper for K8s**: New `scripts/boilstream-admin-k8s.sh` reads CA, superadmin password, and MFA secret live from Kubernetes `Secret`s; computes TOTP locally and execs the admin CLI against the in-cluster deployment
- **`testMode.disableTurnstile` chart value**: Lets CI/test clusters skip the Turnstile CAPTCHA on `/auth/email/signup` without rebuilding the image
- **Portable ARM64 Linux variant (`-generic` / `aarch64-generic-linux-0.10.0`)**: The default `aarch64-linux-0.10.0` build is AWS Graviton-tuned and uses extensions not present on Ampere Altra / Oracle Ampere / Apple Silicon (when run in a Linux Docker container); the new `-generic` variant is built against the ARMv8-a baseline so it runs everywhere. Both are published side-by-side on S3 and Docker Hub.

## [0.9.0] - 2026-04-08

### Features

- **Materialized Views (Windowed Aggregations)**: Tumbling and sliding window aggregations over streaming data
  - `CREATE MATERIALIZED VIEW ... WITH (window_type, window_size, timestamp_column)` DDL
  - Tumbling windows (non-overlapping) and sliding windows (overlapping with `slide_interval`)
  - Ingestion timestamp mode: omit `timestamp_column` to window by server ingestion time (`__boils_meta_timestamp`)
  - Wall-clock aligned window boundaries at Unix epoch multiples
  - Automatic `window_start` and `window_end` column injection for consumer-side deduplication
  - Crash recovery with PostgreSQL watermark persistence — no duplicate or skipped windows on restart
  - Dual semaphore executor: fast views (< 60s) get priority, slow views (≥ 60s) capped at N-1 slots
  - Per-view FIFO queue with round-robin dequeue — no dropped windows on backpressure
  - All standard aggregations: COUNT, SUM, AVG, MIN, MAX, PERCENTILE, MEDIAN, MODE, approx_count_distinct

- **CREATE/DROP STREAMING VIEW DDL**: Row-by-row derived topics with continuous SQL transformations
  - `CREATE STREAMING VIEW name AS SELECT ... FROM source WHERE ...`
  - `DROP STREAMING VIEW [IF EXISTS] name`
  - Supports filtering (WHERE), projections, CASE expressions, scalar functions (UPPER, DATE_TRUNC, casts)
  - Three-level view hierarchy: `CREATE VIEW` (query-time) → `CREATE STREAMING VIEW` (continuous row-level) → `CREATE MATERIALIZED VIEW` (windowed aggregation)

- **Tantivy Full-Text Search**: Per-table full-text search indexing with two-tier hot/cold architecture
  - Enable via `ALTER TABLE ... SET (tantivy_enabled=true, tantivy_text_fields='col1,col2')`
  - **Tantivy-only mode**: set `parquet_enabled=false` for search-only tables without Parquet overhead
  - Hot tier: local disk indexes, searchable within seconds of ingestion
  - Cold tier: segments packed into `.bundle` files and uploaded to S3, registered in DuckLake
  - Shadow DuckLake table (`{table}__tantivy_idx`) automatically tracks all cold tier bundles
  - Query with `multilake_search(catalog, shadow_table, query [, limit])` — returns results with `_score` relevance column
  - Automatic Arrow-to-tantivy type mapping: TEXT (tokenized), STRING (exact-match), numeric/timestamp (range queries)

- **Tenant Management**: Multi-tenant config schema, tenant admin API endpoints, dashboard, landing page, and member management
- **Auth Invite System**: Auto-create tenant at signup with URL-based invite tokens
- **Playwright Smoke Tests**: End-to-end browser smoke tests for auth flows

### Fixes

- **Schema Registry cascade**: Soft-delete schema_registry entries when topics are deleted, preventing stale topic_id references after DROP/CREATE cycles
- **Schema re-registration**: Clear `deleted_at` on schema re-registration to fix ghost soft-deleted entries after table recreation
- **Matview TIMESTAMP stats**: Convert TIMESTAMP column statistics from epoch integers to ISO strings for correct DuckLake registration
- **Matview persistence**: Harden matview persistence load and window boundary alignment
- **Tantivy S3 paths**: Fixed S3 key prefix stripping, shadow table data_path handling, and double-slash prevention in upload paths
- **Tantivy shutdown**: Fixed shutdown hang and durability ack broadcasting in tantivy-only mode
- **Tantivy shadow tables**: Create via DuckDB DDL instead of direct SQL for proper catalog integration
- **PgWire ATTACH performance**: Fixed clean-data ATTACH hang where all connections timed out at 15s. Moved role/schema setup to normal user init path, skip redundant work on DuckLake self-connections, and spawn post-ATTACH index creation as background tasks. 30-user concurrent P99: 15s → 800ms
- **PgWire ATTACH hang**: Fixed DuckLake ATTACH hanging after raw bytes relay by resetting client state
- **PgWire deadlock**: Eliminated `get_duckdb_context()` deadlock in streaming INSERT detection
- **PgWire streaming view errors**: Hardened CREATE/DROP STREAMING VIEW error handling with rollback on failure
- **Session init timeout**: Added initialization timeout to prevent indefinite connection hangs
- **DuckLake auto-attach**: Fixed `memory` database context being lost after DuckLake auto-attach
- **DuckLake ATTACH regression**: Fixed topic name resolution for ALTER TABLE after ATTACH
- **DuckLake table_id collision**: Fixed CDC metadata query collision when DuckLake reuses table_id values
- **Self-connection stability**: Replaced connection abort with `pg_connection_limit=2` and idle timeout cleanup
- **Airport loopback**: Fixed table discovery and schema mapping for streaming INSERT
- **Auth dark mode**: Corrected CSS variables across all UI files

### Improvements

- **PgWire performance**: Eliminated redundant SQL parsing in Extended Query protocol, added AST caching for parse_sql and detect_client_type
- **PgWire refactor**: Extracted shared cursor handlers, query classification, and streaming INSERT detection into reusable modules
- **Matview executor**: Redesigned to connect via pgwire as regular client with tenant isolation, replacing direct DuckDB access

## [0.8.4] - 2026-02-24

### Features

- **SSE Consumer Endpoint**: Real-time streaming consumer via Server-Sent Events (SSE)
  - `GET /stream/{token}` endpoint for browser and HTTP clients
  - Arrow IPC base64 encoding for efficient binary transport
  - Heartbeat and schema change events
  - PULL mode catchup via `Last-Event-ID` header for resumable streams
  - Per-user/topic rate limiting and connection limits
  - Shared token validation with configurable expiry
  - JS consumer SDK for browser integration

- **FlightSQL Multi-Tenant Bootstrap**: Full tenant isolation parity with pgwire
  - Per-user session bootstrap with DuckLake catalog attachment
  - Tenant-isolated metadata queries and prepared statements

- **DuckLake Parquet Statistics**: Extract real min/max column statistics from Parquet files for DuckLake catalog registration, improving query planning and pruning

### Fixes

- **Tenant isolation**: Fixed DDL handler using shared processor instead of bootstrapped connection, ensuring proper tenant separation
- **Postgres stability**: Fixed pgwire ATTACH failures and CDC retry reliability
- **Connection cache**: Fixed TTL expiry, added per-query RBAC enforcement and VIEW metadata support
- **PK/FK metadata APIs**: Return empty results instead of unimplemented error for better client compatibility
- **Kafka consumer**: Fixed ListOffsets fallback, HotChunkManager initialization, and stderr pipe handling
- **DuckLake column stats**: Fixed stats registration and Kafka server TOCTOU race condition

### Improvements

- **HotChunkManager startup reconstruction**: Automatic recovery of in-flight data on restart with slow consumer PULL fallback
- **Shared database utilities**: Extracted `shared_db_utils` module for hot chunk database queries
- **SSE view cache**: Cached view metadata for streaming DuckLake queries

## [0.8.3] - 2026-02-05

### Fixes

- **Boolean array encoding**: Fixed boolean arrays returning corrupted values over the PostgreSQL wire protocol. The Arrow Int8-based boolean array encoder incorrectly treated scalar byte values as bit-packed data, causing all values after the first `false` to become `false`. Affects `SELECT $1::BOOLEAN[]` roundtrips and any query returning boolean arrays via DuckDB's `arrow_lossless_conversion`.
- **Streaming INSERT classifier**: Fixed fully-qualified 3-part table names with `__stream` suffix (e.g. `catalog__stream.schema.table`) not being detected as streaming INSERTs when no session context was provided.

## [0.8.2] - 2026-01-30

### Fixes

- **S3 connectivity on non-EC2 environments**: Fixed S3 storage backend failing to connect on Hetzner, bare-metal, and other non-AWS environments
  - Explicitly enable virtual-hosted-style URLs for AWS S3 (required for buckets created after Sep 2020)
  - Removed forced HTTP/2-only mode that caused connection failures in some network environments
  - Added retry error logging to surface actual S3 errors instead of silent infinite retries
  - Added credential source logging (`explicit` vs `from-environment/IMDS`) for easier debugging

## [0.8.1] - 2026-01-30

- **boilstream-admin CLI Improvements**: Enhanced CLI for scripting and AI agent integration
  - `--json` flag: Shorthand for `--output json`
  - `help-json` command: Machine-readable command structure for tooling/skill discovery
  - `completions` command: Shell completions for bash, zsh, fish, powershell, elvish
  - `BOILSTREAM_PROFILE` env var: Set default profile without `--profile` flag
  - `--dry-run` flag: Preview destructive operations before execution (catalog/user/token delete, s3-state clear)
  - Semantic exit codes: 0=success, 2=auth, 3=not found, 4=permission denied, 5=validation, 6=network
  - Structured JSON error output: Error responses include `code`, `details`, and `exit_code` fields

- **Confluent Schema Registry (Read-Only Compatible)**: Production-ready schema registry for Kafka clients
  - Full read API compliance: `/subjects`, `/schemas/ids/{id}`, `/config`, `/compatibility`
  - Confluent wire format: magic byte `0x00` + 4-byte global ID + Avro payload
  - All 7 compatibility levels supported (BACKWARD, FORWARD, FULL + TRANSITIVE variants)
  - Bearer token authentication with tenant isolation
  - Schemas auto-registered via DuckLake DDL (`CREATE TABLE` → schema, `ALTER TABLE` → new version)
  - Subject naming: `{catalog_id}.{schema}.{table}-value` (TopicNameStrategy)

- **Kafka Consumer Group Improvements**
  - Fixed `seekToBeginning` support for re-reading from offset 0
  - Member validation on OFFSET_COMMIT (Kafka protocol compliance)
  - Consumer group offset state persisted in metadata database

### Fixes

- **Linux stability on high-CPU machines**: Fixed glibc malloc arena fragmentation causing "memory allocation failed" crashes on machines with 28+ vCPUs. Root cause: glibc creates up to `8 × num_cpus` arenas, fragmenting virtual address space so large allocations fail despite available physical memory. Fix: `mallopt(M_ARENA_MAX, 4)` at startup.
- **DuckDB FFI data race**: Fixed `global_call_count` race condition in C++ FFI layer using `std::atomic`

### Improvements

- **DuckDB v1.4.4 LTS**: Rebased embedded DuckDB fork to v1.4.4 LTS
- **C++ API only**: Migrated all DuckDB FFI from mixed C/C++ API to C++ API only
- **FFI safety test suites**: Added ASAN (memory safety) and TSAN (thread safety) test suites for the C++ FFI boundary with Makefile build targets
- **Test reorganization**: Restructured test files under `tests/` directory
- **Safety checks**: Architecture-aware sanitizer builds supporting both x86_64 and aarch64

### Documentation

- Schema Registry API documentation
- Kafka interface consumer group semantics

## [0.8.0] - 2026-01-13

### Features

- **Multi-tenant DuckDB**: Boilstream runs single DuckDB instance with tenant isolation security
  - Secrets, ATTACHments, DuckLakes, filesystem (chroot like), etc. separation between tenants
  - Tenants don't see each other, but share the same resources
  - Preliminary metrics collection for fair scheduling/billing in the future when needed
- **JIT Avro Decoder for Kafka Ingestion**: New state-of-the-art just-in-time (JIT) compiled Avro decoder
  - Achieving 3-5x faster performance compared to the Rust Apache Arrow decoder released Oct 2025
  - Bounds checking in/out to protect against corrupted/malicious data
  - All Avro types included and thoroughly tested, including complex/nested types, roundtrip and perf tests
- **Embedded DuckLake PostgreSQL Catalog**: Native pg_catalog support for DuckLake databases
  - Automatic catalog backup/restore to S3 based on user login/logout and changes
  - Seamless schema discovery with tools like DBeaver (ensure multidatabase support setting is on)
- **DuckLake Data Inlining Support for Stream Ingested Data**: Transactional batch commits to hot tier every 1s
  - Automatic hot and cold tier DuckLake snapshots
  - Realtime cpp appender data committed once per second, immediately visible for ducklake users
- **DuckLake Vending Support**: Unified data access across multiple client types.
  - In-server queries with multi-tenant DuckDB attached DuckLake databases
  - Remote native DuckDB clients with full PostgreSQL DuckLake catalog support, including the hot inline data
  - DuckDB-WASM browser clients with cached/synced (1min) DuckDB catalogs on S3 (DuckDB-WASM lacks postgres scanner)
  - Each client automatically vends correct temporary credentials per client type for each user
- **Cold Tier Hydration API**: Lift DuckLake tables from cold tier to hot tier
  - DuckDB cpp level appender with >1GB/s hydration speed, prioritised with ingestion streams
- **Entra ID SAML SSO and SCIM**: Enterprise SSO integration with XML metadata file download/upload
  - Download/upload XML files for easy setup
  - SCIM User Synchronization for automatic user provisioning and deprovisioning via SCIM protocol
  - If you enable SAML SSO, local users are disabled (except superadmin)
- **Preliminary Horizontal Cluster Mode**: Horizontal scaling support for distributed deployments
  - Cluster leader for user management and metadata with S3 locking and heartbeats
  - Users' DuckLake PG catalog leaders distributed over the cluster with on-demand backup/restore (login/logout/dirty)
  - Control with boilstream-admin CLI tool
- **boilstream-admin CLI**: New command-line tool for managing and observing BoilStream clusters (uses admin API)
  - Hydrating ducklake tables, demote/promote leader nodes
  - Let AI manage and observe your boilstream clusters
  - download as boilstream-admin-x.y.z matching with boilstream-x.y.z version, arch, and OS
- **matching boilstream extension version: 0.5.0**
  - Use with native DuckDB clients as well as with DuckDB-WASM
  - More details at https://github.com/dforsber/boilstream-extension

### Fixes

- Correct multi-database visibility over our 1st class Postgres interface, showing "memory" database and any attached databases as their own (like Ducklakes). DBeaver supports "multiple databases" and shows each database as a seprate Database on the navigator

## [0.7.19] - 2025-10-29

### Features

- Audit logging to separate logs folder on disk with partitioning

### Fixes

- Fixed CORS for auth server to work with boilstream duckdb wasm extension from browser
- Fixed session timestamp for opaque pake login response
- Less bloated info logs
- Server does not try to encrypt empty response body, but sends HTTP 204 instead

## [0.7.18] - 2025-10-15

### Features

- Session resumption support for Remote Secrets Store API, matches DuckDB boilstream extension v0.3.1

### Fixes

- Complete separation of Web Auth GUI sessions from OPAQUE login sessions

## [0.7.17] - 2025-10-14

### Features

- Re-designed the DuckDB Secure Remote Secrets Store protocol to be based on industry standard approaches (Facebook OPAQUE PAKE, OAuth2, HKDF, SHA256, etc.). See the DuckDB client extension and its [SECURITY_SPECIFICATION.md](https://github.com/dforsber/boilstream-extension/blob/main/SECURITY_SPECIFICATION.md) that also includes full conformance test suite with test vectors. We have independently developed both the server (Rust) and the DuckDB extension using the specification and its conformance test suites to make them fully interoperable. The Facebook's OPAQUE PAKE was audited by NCC back in 2021.
- Secrets Storage comms are integrity protected inside the TLS channel and secrets are encrypted inside the TLS channel with AEAD (i.e. application level e2e protection). Mounting the Remote Secrets Storage happens with anonymised one-time bootstrap token (privacy).

### Fixes

- Shutdown is more swift now (e.g. for rolling restarts/updates)
- Browser caching disabled with the Web Auth GUI

## [0.7.16] - 2025-10-09

### Features

- Security improvement: secrets token vending starts with bootstrap token that is exchanged to session token with PKCE token exchange (anti-theft)
- Web GUI shows token status
- Matching DuckDB boilstream community extension version: v0.2.0

## [0.7.15] - 2025-10-08

### Features

- DuckDB Secure Remote Secrets Storage REST API along with DuckDB Community Extension (https://github.com/dforsber/boilstream-extension)
- GDPR compliant user management with nonrepudiation/nondisputability with PGP encrypted user email address (identity) when user is deleted. Only if public PGP key is configured.
- Web tokens can be revoked like sessions. E.g. a revoked secrets scoped token used in the BoilStream DuckDB Extension does not have access to remote secrets storage anymore after revocation.

### Fixes

- Added verify password field to user manual sign up
- Clearing Web Auth portal password fields on timeout and tab change
- Added verify encryption key on initial boilstream ceremony
- The superadmin ("boilstream") password now has similar strength requirements as the encryption key
- If max sessions were reached, user was blocked. Now, the oldest session is revoked to allow user log in via API / WebAuth console (authentication must succeed).
- TOTP code cannot be reused
- Improved auth API input validations
- Web tokens are generated per purpose/scope (e.g. "secrets", "ingest") to adhere with least privilege security principle

## [0.7.14] - 2025-09-22

### Features

- NEW: Web Portal GUI. Start boilstream and go to https://host:443/ for vending Postgres interface and http ingestion token credentials with social logins (GitHub, Google) and SAML based SSO supported (e.g. AWS SSO SP) through https auth server interface. Includes CloudFlare turnstile captcha.
- MFA with TOTP and PassKey are supported. You can manage these on the auth portal and also revoke sessions, which also close the established postgres sessions if any with the respective credentials.
- BoilStream maintains encrypted users DuckDB database encrypted with key passed during server start (or from file if configued). Key is mem locked and zeroised immediately after use (dbs have been opened). The encrypted dbs are locked into the auth server only. The db encryption is DuckDB v1.4 new feature. By configuring the encryption key path, the key is stored on disk and reused from there, otherwise asked from the user every time the server starts.
- Proper implementation of Postgres `SCRAM-SHA-256` based logins with short time credentials vended with OAuth2/creds via login page served through server's auth https server. Postgres md5 passwords not supported anymore. Server never stores user's salted passwords.
- The users encrypted database is backed up on selected backend. The system validates the backend exists at startup, recovers the users database from backup if missing locally, and automatically backs up after user creation with configurable interval throttling.
- Superadmin account ("boilstream") password is bootstrapped when the server starts the first time and there is no encrypted superadmin.duckb database yet. Using the "boilstream" as username and the associated password, the postgres connection is established to a separate in-memory DuckDB instance that has the users database attached.
- The users.duckdb database is backed up on the primary backend storage

### Examples

- Vend http ingestion token through BoilStream auth portal and use it with [audio-arrow-streamer.html](audio-arrow-streamer.html) to stream audio into BoiilStream DuckDB and Data Lake

### Fixes

- Derived views (materialised topics) were still using old DuckDB instance per view approach. Now derived view processor uses single duckdb instance for much improved scalability.

## [0.7.13] - 2025-09-16

### Features

- DuckDB 1.4.0, extensions work again
- Arbitrary number of parameters supported (hard coded max is 10k to avoid OOM)
- Parametrized INSERT/DELETE queries

### Fixes

- DuckDB Arrow lossless Boolean extension type was misinterpreted when returning multiple boolean values
- JSON Array parameters, they were quoted but must not be

## [0.7.12] - 2025-09-12

### Features

- NEW INTERFACE: HTTPS ingestion with Arrow payloads, e.g. from Browsers with Flechette JS. >2GB/s and tens of thousands of concurrent connections.
- Configurable query/connection timeouts. Default from 5min to 30min. (pgwire.connection_timeout_seconds)

## [0.7.11] - 2025-09-04

### Features

- True streaming through postgres interface with lazy fetching from DuckDB to minimise memory consumption. Allows e.g. streaming tens of millions of rows concurrently to multiple clients without consuming much memory.
- Allow streaming all rows, not just first 1M. Allows e.g. Power BI to download all data.

### Fixes

- Fix "time with time zone", "timestamp with time zone", "uuid array", "boolean array" binary parameters handling for prepared queries

## [0.7.10] - 2025-09-04

### Fixes

- PG type name mapping vs native type naming fixed for allowing Power BI to detect all types properly

## [0.7.9] - 2025-09-03

### Features

- 1st class support for prepared statements including binary parameter types support (also arrays)
- Higher resiliency against attacks and hundreds of concurrent clients, including malicious
- Improved type compliancy HTML report: https://boilstream.com/test_report.html

### Fixes

- Many PG catalog fixes to make type system more complete

## [0.7.8] - 2025-08-30

### Fixes

- Postgres interface hardening in face of attacks and misbehaving clients

## [0.7.7] - 2025-08-27

### Features

- Improved Postgres interface robustness and resource management (query timeouts, idle connection mgmt, etc.)
- Postgres interface result row record improvements and type modifiers for allowing Power BI to use proper query folding (query pushdown)
- Type compliance report: https://www.boilstream.com/type_coverage_report.md
- Grafana Dashboard updated with more metrics
- NEW: Preliminary Kafka interface with Avro and schema validation. The boilstream.topic_schemas now also include avro_schema column that is the schema for Kafka clients.

### Fixes

- Storage backend now supports multiple Object Storage backends, not just e.g. S3 + filesystem
- By default having DuckDB arrow_lossless_conversion = true (preserves e.g. time zone information with "tiem with time zone" type). Both settings works.

## [0.7.6] - 2025-08-21

### Features

- Full support of Tableou in place. Tableou does not complain about any types it seems, so we only need a minor change to make Tableou work.

## [0.7.5] - 2025-08-21

### Fixed

- Extensive tests for various data types and special handling for Power BI as its npgsql version is outdated and can't handle TIME, TIMESTAMP, TIMESTAMPTZ and ARRAYs with NULLs. Thus, we convert them to TEXT (temporal) and JSON (ARRAY), but only for Power BI clients. Other clients get these types without conversion. See the [demo_database.sql](demo_database.sql) that we used for testing with Power BI Desktop client.

## [0.7.4] - 2025-08-19

### Fixed

- Fixed more Power BI connection failures due to type mismatch.

## [0.7.3] - 2025-08-18

### Features

- Using object_store crate for generalised Object Store and Filesystem support. E.g. AWS, GCP, and Azure object stores, and Minio.

### Fixed

- Performance: Fixed serialised metadata envelope recycling causing some operations to be serialised
- Defect: Power BI connection failure due to type mismatch

## [0.7.2] - 2025-08-12

### Features

- Flight SQL interface (e.g. with ADBC drivers)
- Self and cross-BoilStream writes with Airport extension (pre-compiled downloadable)

### Fixed

- Graceful shutdown sequence fixed to avoid data loss with derived view processor
- Derived topic id assignment and topic cache miss handling

## [0.7.1] - 2025-08-04

### Improvements / Features

- Improved BI Tool support: Power BI compatibility

## [0.7.0] - 2025-08-03

### Improvements / Features

- 1st tier derived topics (aka materialised views) support
- Support for recursive derived topics
- Data persistence layer tiered sticky load balancing for improved parquet locality
- The metadata.duckdb database catalog schema changed (keying by u64 not varchar)
- improved memory management with vector recycling, also switched from jemalloc to mimalloc
- Embedded DuckDB now has more inbuilt core extensions
- Linux and OSX x64 builds

### Fixed

- improved FlightRPC client communications with retries

## [0.6.2] - 2025-07-27

### Fixed

- **Derived view refresh**: Materialized views now automatically refresh within 1 second when created or dropped via SQL, eliminating the need to restart the agent
- View changes made through the `boilstream.s3` schema are now immediately picked up by the streaming processor

### Technical Details

- Added periodic cache invalidation (1s interval) to the derived view processor
- Improved cache consistency between SQL operations and stream processing
