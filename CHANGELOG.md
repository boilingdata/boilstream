# Changelog

All notable changes to BoilStream will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
