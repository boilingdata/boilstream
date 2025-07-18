# BoilStream - Stream to Gold 🏆

BoilStream is a high-performance data ingestion and analytics system that streams your data to S3 with automatic Parquet conversion, schema validation, and real-time monitoring.

**You can connect to BoilStream also with postgres compatible clients for realtime analytics with DuckDB SQL.**

It supports thousands of concurrent writers and GBs per second data ingestion rates (with single ingestion port), while using efficient stream aggregation from all the writers into per topic Parquet files. High throughput streaming creates S3 multipart upload files where Parquet row groups are uploaded concurrently (S3 multipart parts). The Parquet file is finalised when size/time threshold is reached.

- You create new topics with `CREATE TABLE` and write to them with `INSERT` from DuckDB with Airport extension, no other integration needed
- You create forked streams with `CREATE VIEW` (this requires our forked Airport extension for the `CREATE VIEW` command routing to the FlightRPC server). Forked streams are diskless pipelines like the main topics and land on their own S3 prefix with hive partitioning
- 🚀 Now BoilStream also stores data on **local disk persisted DuckDB databases** 🦆 with minimal impact on the data ingestion throughput 🔥. See [local-dev.yaml](local-dev.yaml) configuration file and the `duckdb_persistence` configuration block. Efficient zero-copy Arrow to DuckDB ingestion is used with native C++/Rust integration.
- 🚀 DuckLake integration included!

This repository contains download links to the free tier binary builds and docker compose file for running the required auxiliary services for metadata registry and monitoring dashboard.

## Start

```bash
# Start auxiliary containers
docker-compose up -d

# Download boilstream
#curl -L -o boilstream https://www.boilstream.com/binaries/linux-x64/boilstream
#curl -L -o boilstream https://www.boilstream.com/binaries/linux-x64/boilstream
#curl -L -o boilstream https://www.boilstream.com/binaries/linux-aarch64/boilstream
curl -L -o boilstream https://www.boilstream.com/binaries/darwin-aarch64/boilstream
chmod +x boilstream

# Start boilstream
./boilstream --config local-dev.yaml

# Start streaming data with DuckDB
# NOTE: The storage.backends.flush_interval_ms (backend type "s3") configuration option
#       defines the S3 synchronization interval, which also completes the DuckDB INSERT
#       transaction. The smaller the flush interval, the faster response times you get,
#       but smaller fragmented Parquet files.
# NOTE: When DuckDB statement returns, data is guaranteed to be on S3!
duckdb
```

> NOTE (2025-06-16): If the amazing [Airport extension](https://github.com/dforsber/airport/tree/create-materialized-view-support) is not already available on the community DuckDB registry (the `INSTALL` command fails or it does not support `CREATE VIEW` command), you can compile it yourself as per the repository guideline. The link points to forked version that has the `CREATE VIEW` capability. The [PR#20](https://github.com/Query-farm/airport/pull/20) is under review on the main repository.

```sql
INSTALL airport FROM community;
LOAD airport;
ATTACH 'boilstream' (TYPE AIRPORT, location 'grpc://localhost:50051/');

CREATE TABLE boilstream.s3.people (name VARCHAR, age INT, tags VARCHAR[]);
CREATE VIEW boilstream.s3.filtered_adults AS SELECT * FROM boilstream.s3.people WHERE age > 50;
CREATE VIEW boilstream.s3.filtered_b AS SELECT * FROM boilstream.s3.people WHERE name LIKE 'b%';
CREATE VIEW boilstream.s3.filtered_a AS SELECT * FROM boilstream.s3.people WHERE name LIKE 'a%';

INSERT INTO boilstream.s3.people
   SELECT
      'boilstream_' || i::VARCHAR AS name,
      (i % 100) + 1 AS age,
      ['duckdb', 'ducklake'] AS tags
   FROM generate_series(1, 20000) as t(i);
```

```sql
D ATTACH 'boilstream' (TYPE AIRPORT, location 'grpc://localhost:50051/');
D SELECT table_name, comment FROM duckdb_tables();
┌────────────────────────┬─────────────────────────────────────────────────────────────────────────────┐
│       table_name       │                                   comment                                   │
│        varchar         │                                   varchar                                   │
├────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
│ people→filtered_adults │ Materialized view: SELECT * FROM boilstream.s3.people WHERE age > 50;       │
│ people→filtered_b      │ Materialized view: SELECT * FROM boilstream.s3.people WHERE name LIKE 'b%'; │
│ people→filtered_a      │ Materialized view: SELECT * FROM boilstream.s3.people WHERE name LIKE 'a%'; │
│ people                 │ Topic created from DuckDB Airport CREATE TABLE request for table 'people'   │
└────────────────────────┴─────────────────────────────────────────────────────────────────────────────┘
```

**Monitor your data**:

- **Grafana**: http://localhost:3000 (admin/admin)

## 📋 Requirements

- Docker and Docker Compose
- 8GB+ RAM recommended
- OSX or Linux (Ubuntu 24+)

## 🎯 Free Tier Limits

> NOTE: BoilStream can ingest GBs per second, so you may hit the free tier limit quickly.

- **Data ingestion**: 40 GB per hour (you need to restart if you hit the limit)
- **Max concurrent sessions**: Limited to 10
- **No authentication**: No authentication or access control
- **No TLS**: Runs on plain FlightRPC connection without TLS

## 📚 Documentation

For complete documentation, visit: **[www.boilstream.com](https://www.boilstream.com)** and **[docs.boilstream.com](https://docs.boilstream.com)**

## 🏗️ Architecture

BoilStream processes your data through:

1. **Flight RPC** - High-performance data ingestion
2. **Valkey** - Metadata Registry, like for Arrow Schemas
3. **S3** - Automated Parquet storage with Hive partitioning
4. **DuckLake** - Integration with [DuckLake](https://duckdb.org/2025/05/27/ducklake.html)
5. **Rate limiting** - Rate limiting support
6. **BI Tool Integration** - Postgres compatible interface for BI Tool and other integrations

Auxiliary services:

7. **Prometheus** - Metrics collection
8. **Grafana** - Real-time monitoring dashboards

## 🆙 Upgrading to Paid version

- **Security**: FlightRPC with TLS, authentication and access control
- **Uncapped**: No throughput limits, max concurrent sessions with single node 10k (configurable)

## 🆙 Upgrading to Enterprise version

- **Multi-node**: Horizontal scaling by just adding more nodes
- **Federated Authentication**: Integration with authentication providers

Need higher limits or advanced features? Contact us at **[boilstream.com](https://www.boilstream.com)**
