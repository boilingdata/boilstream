# BoilStream - Stream to Gold Easily 🏆

> **NOTE: 2025-07-26: BoilStream v0.6.2 runs DuckDB 1.4.0-pre version and thus extensions installations fail. DuckDB extension interface changes between v1.3 and v1.4 and thus pre-existing extensions can't be installed as they don't work. Once DuckDB v1.4 is out and extensions start to be compiled for it, you can install them normally, and then also DuckLake integration works again. We use v1.4.0-pre version because it includes new Arrow C API that is future-proof rather than the v1.3 deprecated one.**

[BoilStream](https://wwww.boilstream.com/) is a small binary DuckDB server with steroids written in Rust (and a bit of C++).

Download, start, and connect with any BI Tool with Postgres interface for real-time analytics - connect from [DuckDB clients with Airport extension](https://duckdb.org/community_extensions/extensions/airport.html) for high-throughput and scalable real-time data ingestion. It streams Parquet to storage backends like S3 with DuckLake in realtime as compact, hive partitioned Parquet files.

BoilStream supports:

1. 🚀 **High-performance zero-copy\* data ingestion** (FlightRPC, Arrow) with [DuckDB Airport community extension](https://duckdb.org/community_extensions/extensions/airport.html) from DuckDB clients
2. 🚀 **Postgres compatible BI interface for real-time (streaming) Analytics** directly 1:1 mapped into DuckDB memory connections
3. 🚀 **Local on-disk DuckDB database layer** with high ingestion throughput
4. 🚀 **Multiple "diskless" Parquet storage backends** like S3 and Filesystem - when DuckDB client FlightRPC `INSERT` returns, **data is guaranteed to be on primary storage** (e.g. Minio or AWS S3). The data pipeline to S3 is completely diskless, so if you don't enable DuckDB local persistence layer, the disk is not used at all.
5. 🚀 **Creating ingestion topics and materialised realtime views** (derived topics) with special `boilstream.s3` schema - use `CREATE TABLE` and `CREATE TABLE derived_view AS SELECT col1 FROM boilstream.s3.my_topic` for managing topics/views
6. 🚀 **DuckLake integration:** S3 uploaded files are automatically added to DuckLake
7. 🚀 **Our novel never-ending DuckDB SQL real-time streaming queries** for processing materialised views very efficiently (see CTAS over `boilstream.s3` schema below)
8. 🚀 **Monitoring through prometheus compatible interface** along with an example Grafana Dashboard (see [`docker-compose.yml`](docker-compose.yml))
9. 🚀 **Enterprise SSO with RBAC/ATAC as well as TLS and improved Postgres authentication** with [paid pro version](https://wwww.boilstream.com/)

This repository contains free download links and docker compose file for running the optional auxiliary services, like Grafana monitoring and Minio S3 for testing.

> \*) There is one data copy from kernel to userspace, which happens always unless you bypass kernel or use e.g. Linux XDP sockets to read raw data from the link directly. But then you also need to parse Ethernet and implement IP, TCP, TLS, gRPC, and Flight protocol stacks. Single port/core FlightRPC is already very efficient and reported to support +20GB/s data transfer speeds. In BoilStream, data copying also happens when you convert the incoming Arrow format to Parquet files - but that's all. The concurrent S3 Uploader and pre-allocated buffer pools ensure that the network copy reads from the Parquet writer output buffers directly.

## No Backups Needed

No backups needed as it streams your data to S3 with automatic compacted and optimised Parquet conversion. Ingested data schema is validated so you don't get bad data in. The data on S3 is ready for analytics and is Hive Partitioned (DuckLake integration also available).

Based on topic configuration, data is also persisted onto local disk as DuckDB database files. The realtime Analytics postgres connection reads directly from these DuckDB database files while the data is ingested into them.

BoilStream supports thousands of concurrent writers and GBs per second data ingestion rates (with single ingestion port), while using efficient stream aggregation from all the writers into per topic Parquet files. High throughput streaming creates S3 multipart upload files where Parquet row groups are uploaded concurrently (S3 multipart parts). The Parquet file is finalised when size/time threshold is reached.

> If you configure S3 as the primary storage and S3 is down, data ingestion stalls and the `INSERT` statements will hang until S3 becomes available again. Data integrity (security) is number one priority. FlightRPC data is also schema validated both on control plane (matching schema) as well as on data plane (actual data matches and validates with the schema).

> Secondary storage failures do not affect or stall data ingestion, like if you configure Filesystem as your primary and S3 as secondary.

> Local DuckDB on-disk database persistence layer can be turned on/off and is independent of configured storage layers. You can also configure no Parquet storage layers and just ingest data onto DuckDB on-disk databases (or e.g. EBS volumes on cloud)

> 2025-07-26: Currently, there is no DuckDB on-disk database file rotation or old data cleanup, but we will address this in the future release to avoid the common disk full scenario. For now, you can periodically delete old data.

## Postgres interface

**You can run any BI Tool over the postgres interface on the standard port 5432** (configurable). We have tested with Power BI, DBeaver, Metabase, Superset, Grafana, psql, pgbench.

> DuckDB itself does not have "server mode" and does not implement client-server paradigm. With BoilStream you can run DuckDB efficiently as a server too.

BoilStream supports:

1. 🚀 Both text and binary encoded fields with extensive type support (time/date formats, JSON, uuid, List/Map/Struct, etc.)
2. 🚀 Cursor and transaction management with DuckDB's native streaming queries
3. 🚀 Comprehensive pg catalog for metadata discovery from BI Tools with postgres SQL syntax

## Real-time SQL Streaming - never-ending SQL queries!

We use our _innovative never ending continuous stream processing with DuckDB_ 🚀 . This avoids SQL parsing, Arrow Table registration, cleanup and other hassle present (micro) batch processing approaches.

As the data flows in as Arrow data it goes through DuckDB stream processors that produce data for the derived views. These derived topic processors are initialised once with the specified SQL, but run as long as the data flows (unless you create SQL that finishes on purpose like with LIMIT). These streaming processors only work with DuckDB's physical streaming constructs (e.g. LAG etc.).

> **For all proper window queries, we are adding support through the on-disk cached DuckDB databases. This way we can provide even hourly "batching" automatically.** But for now, you can already run queries over the Postgres interface if you like.

## Start

```bash
# Download and start boilstream - if no configuration file is provided, it will generate an example one
# https://www.boilstream.com/binaries/linux-aarch64/boilstream
# https://www.boilstream.com/binaries/linux-x64/boilstream
# https://www.boilstream.com/binaries/darwin-x64/boilstream
curl -L -o boilstream https://www.boilstream.com/binaries/darwin-aarch64/boilstream
chmod +x boilstream
# SERVER_IP_ADDRESS is used on the Flight interface, use reachable IP address
SERVER_IP_ADDRESS=1.2.3.4 ./boilstream
```

> _You can use the accompanying docker-compose.yml file to start auxiliary containers for Grafana Dashboard and S3 Minio_

Connect through the postgres interface with your tool of choice (like psql):

**The `boilstream.s3.` schema is specific for real-time streaming. Tables created to it become avialable on the FlightRPC side for ingestion. CTAS tables become materialised views (not writable from FlightRPC ingestion side)**

```sql
-- Create topic
CREATE TABLE boilstream.s3.people (name VARCHAR, age INT, tags VARCHAR[]);
-- Derived topics aka **materialised real-time views**
-- With their own S3 Parquet data as well as on-disk DuckDB database views like the main topic
CREATE TABLE boilstream.s3.filtered_adults AS SELECT * FROM boilstream.s3.people WHERE age > 50;
CREATE TABLE boilstream.s3.filtered_b AS SELECT * FROM boilstream.s3.people WHERE name LIKE 'b%';
CREATE TABLE boilstream.s3.filtered_a AS SELECT * FROM boilstream.s3.people WHERE name LIKE 'a%';
```

Check existing topics and their metadata:

```sql
-- topic metadata
select * from boilstream.topics;
select * from boilstream.topic_schemas;
select * from boilstream.derived_views;
```

Start ingesting data with DuckDB. **When DuckDB statement returns, data is guaranteed to be on S3!**

```sql
INSTALL airport FROM community;
LOAD airport;
ATTACH 'boilstream' (TYPE AIRPORT, location 'grpc://localhost:50051/');
-- With pro-version, use TLS: 'grpc+tls://localhost:50051/'

SHOW ALL TABLES;

INSERT INTO boilstream.s3.people
   SELECT
      'boilstream_' || i::VARCHAR AS name,
      (i % 100) + 1 AS age,
      ['duckdb', 'ducklake'] AS tags
   FROM generate_series(1, 20000) as t(i);
```

> The BoilStream configuration file `storage.backends.flush_interval_ms` (with fbackend type "s3") configuration option defines the S3 synchronization interval, which also completes the DuckDB INSERT transactions you run with the Airport extension from all the clients. The smaller the flush interval, the faster response times you get, but smaller fragmented Parquet files. You can send millions of rows or just one row and the query completes in these intervals as the storage backend signals all verifiably (S3) stored sequence numbers onto Parquet back to the data ingestion frontend which ensures that all data is successfully stored on S3 before returning success back to Airport clients.

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

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

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
