# BoilStream - Stream to Gold 🏆

BoilStream is both a **high-performance data ingestion** (FlightRPC) and Postgres compatible **real-time (streaming) Analytics** system.

No backups needed as it streams your data to S3 with automatic compacted and optimised Parquet conversion. Ingested data schema is validated so you don't get bad data in. The data on S3 is ready for analytics and is Hive Partitioned (DuckLake integration also available).

Based on topic configuration, data is also persisted onto local disk as DuckDB database files. The realtime Analytics postgres connection reads directly from these DuckDB database files while the data is ingested into them.

BoilStream supports thousands of concurrent writers and GBs per second data ingestion rates (with single ingestion port), while using efficient stream aggregation from all the writers into per topic Parquet files. High throughput streaming creates S3 multipart upload files where Parquet row groups are uploaded concurrently (S3 multipart parts). The Parquet file is finalised when size/time threshold is reached.

- 🚀 You create new topics with `CREATE TABLE` and write to them with `INSERT` from DuckDB with Airport extension, no other integration needed
- 🚀 You create forked streams with `CREATE VIEW` (this requires our forked Airport extension for the `CREATE VIEW` command routing to the FlightRPC server). Forked streams are diskless pipelines like the main topics and land on their own S3 prefix with hive partitioning
- 🚀 DuckLake integration included!

This repository contains download links to the free tier binary builds and docker compose file for running the required auxiliary services for metadata registry and monitoring dashboard.

## Real-time SQL Streaming

We use our innovative never ending continuous stream processing with DuckDB. This avoids SQL parsing, Arrow Table registration, cleanup and other hassle with micro batch processing approach. As the data flows in as Arrow data it goes through DuckDB stream processors that produce data for the derived views. These derived topic processors are initialised once with the specified SQL, but run as long as the data flows (unless you create SQL that finishes on purpose like with LIMIT). These streaming processors only work with DuckDB's physical streamining constructs (e.g. LAG etc.).

> **For all proper window queries, we are adding support through the on-disk cached DuckDB databases. This way we can provide even hourly "batching" automatically.** But for now, you can already run queries over the Postgres interface if you like.

## Start

```bash
# Start auxiliary containers (optional)
docker-compose up -d

# Download boilstream
#curl -L -o boilstream https://www.boilstream.com/binaries/linux-aarch64/boilstream
curl -L -o boilstream https://www.boilstream.com/binaries/darwin-aarch64/boilstream
chmod +x boilstream

# Start boilstream
./boilstream --config local-dev.yaml

# Start streaming data with DuckDB
#    The YAML configuration file storage.backends.flush_interval_ms (backend type "s3")
#    configuration option defines the S3 synchronization interval, which also completes
#    the DuckDB INSERT transactions you run with the Airport extension from all the clients.
#
#    The smaller the flush interval, the faster response times you get, but smaller fragmented
#    Parquet files. When DuckDB statement returns, data is guaranteed to be on S3!
duckdb
```

```sql
INSTALL airport FROM community;
LOAD airport;
ATTACH 'boilstream' (TYPE AIRPORT, location 'grpc://localhost:50051/');

CREATE TABLE boilstream.s3.people (name VARCHAR, age INT, tags VARCHAR[]);
-- NOTE: CREATE VIEW is not supported on the community extension
-- CREATE VIEW boilstream.s3.filtered_adults AS SELECT * FROM boilstream.s3.people WHERE age > 50;
-- CREATE VIEW boilstream.s3.filtered_b AS SELECT * FROM boilstream.s3.people WHERE name LIKE 'b%';
-- CREATE VIEW boilstream.s3.filtered_a AS SELECT * FROM boilstream.s3.people WHERE name LIKE 'a%';

INSERT INTO boilstream.s3.people
   SELECT
      'boilstream_' || i::VARCHAR AS name,
      (i % 100) + 1 AS age,
      ['duckdb', 'ducklake'] AS tags
   FROM generate_series(1, 20000) as t(i);
```

> NOTE (2025-06-16): If the amazing [Airport extension](https://github.com/dforsber/airport/tree/create-materialized-view-support) is not already available on the community DuckDB registry (the `INSTALL` command fails or it does not support `CREATE VIEW` command), you can compile it yourself as per the repository guideline. The link points to forked version that has the `CREATE VIEW` capability. The [PR#20](https://github.com/Query-farm/airport/pull/20) is under review on the main repository. However, we also provide topic configurations through DuckDB or PostgresSQL database, so you can manage the topics and derived topics (views) there.

```sql
D ATTACH 'boilstream' (TYPE AIRPORT, location 'grpc://localhost:50051/');
D SELECT table_name, comment FROM duckdb_tables();
┌────────────────────────┬─────────────────────────────────────────────────────────────────────────────┐
│       table_name       │                                   comment                                   │
│        varchar         │                                   varchar                                   │
├────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
│ filtered_adults        │ Materialized view: SELECT * FROM boilstream.s3.people WHERE age > 50;       │
│ filtered_b             │ Materialized view: SELECT * FROM boilstream.s3.people WHERE name LIKE 'b%'; │
│ filtered_a             │ Materialized view: SELECT * FROM boilstream.s3.people WHERE name LIKE 'a%'; │
│ people                 │ Topic created from DuckDB Airport CREATE TABLE request for table 'people'   │
└────────────────────────┴─────────────────────────────────────────────────────────────────────────────┘
```

**Monitor your data with Grafana**: http://localhost:3000 (admin/admin)

## 📋 Requirements

- Docker and Docker Compose
- 8GB+ RAM recommended
- OSX or Linux (Ubuntu 24+)
- arm64 (we can build for OS/Arch on request)

## 🎯 Free Tier Limits

> NOTE: BoilStream can ingest GBs per second, so you may hit the free tier limit quickly. Thus, use the rate limiter configuration on the configuration file.

- **Data ingestion**: 40 GB per hour (you need to restart if you hit the limit)
- **Max concurrent sessions**: Limited to 10
- **No authentication**: No authentication or access control
- **No TLS**: Runs on plain FlightRPC connection without TLS

## 🏗️ Architecture

For complete documentation, visit: **[www.boilstream.com](https://www.boilstream.com)** and **[docs.boilstream.com](https://docs.boilstream.com)**

BoilStream processes your data through:

1. **Flight RPC** - High-performance data ingestion with Apache Arrow and zero-copy implementation
2. **S3** - Automated Parquet storage with Hive partitioning
3. **Rate limiting** - Rate limiting support
4. **BI Tool Integration** - Postgres compatible interface for BI Tool and other integrations
5. **DuckLake** - Integration with [DuckLake](https://duckdb.org/2025/05/27/ducklake.html)

Auxiliary services:

6. **Prometheus** - Metrics collection
7. **Grafana** - Real-time monitoring dashboards

## 🆙 Upgrading to Paid version

- **Security**: FlightRPC with TLS, authentication and access control
- **Uncapped**: No throughput limits, max concurrent sessions with single node 10k (configurable)

## 🆙 Upgrading to Enterprise version

- **Multi-node**: Horizontal scaling by just adding more nodes
- **Federated Authentication**: Integration with authentication providers

Need higher limits or advanced features? Contact us at **[boilstream.com](https://www.boilstream.com)**
