# Changelog

All notable changes to BoilStream will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
