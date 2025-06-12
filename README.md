# BoilStream - Free Tier Data Ingestion

BoilStream is a high-performance data ingestion system that streams your data directly to S3 with automatic Parquet conversion, schema validation, and real-time monitoring.

It supports thousands of concurrent writers and GBs per second data ingestion rates, while using efficient stream aggregation from all the writers into per topic Parquet files. High throughput streaming creates S3 multipart upload files where Parquet row groups are uploaded concurrently (s3 multipart parts). The Parquet file is finalised when size/time threshold is reached.

This repository contains free tier binary builds and docker compose file for running the required auxiliary services for metadata registry and monitoring dashboard.

## 🚀 Start

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
# NOTE: You can use the help switch to get configuration options
AWS_REGION=us-east-1 S3_BUCKET=my_bucket S3_FLUSH_INTERVAL_MS=250 ./boilstream --help

# Start streaming data with DuckDB
# NOTE: When DuckDB statement returns, data is guaranteed to be on S3
duckdb
```

> NOTE: If the amazing [Airport extension](https://github.com/Query-farm/airport) is not already available on the community DuckDB registry (the `INSTALL` command fails), you can compile it yourself as per the repository guideline.

```sql
INSTALL airport FROM community;
LOAD airport;
ATTACH 'boilstream' (TYPE AIRPORT, location 'grpc://localhost:50051/');
CREATE TABLE boilstream.s3.people (name VARCHAR, age INT, tags VARCHAR[]);
INSERT INTO boilstream.s3.people
   SELECT
      'boilstream_' || i::VARCHAR AS name,
      (i % 100) + 1 AS age,
      ['duckdb', 'ducklake'] AS tags
   FROM generate_series(1, 20000) as t(i);
```

**Monitor your data**:

- **Grafana**: http://localhost:3000 (admin/admin)

## 📋 Requirements

- Docker and Docker Compose
- 8GB+ RAM recommended
- OSX or Linux (Ubuntu 24+)

## 🎯 Free Tier Limits

> NOTE: BoilStream can ingest GBs per second, so you may hit the free tier limit quickly.

- **Data ingestion**: 1GB per hour (you need to restart if you hit the limit)
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

Auxiliary services:

4. **Prometheus** - Metrics collection
5. **Grafana** - Real-time monitoring dashboards

## 🆙 Upgrading to Paid version

- **Security**: FlightRPC with TLS, authentication and access control
- **Uncapped**: No throughput limits, max concurrent sessions with single node 10k (configurable)
- **Rate limiting**: Rate limiting support
- **DuckLake**: Integration with [DuckLake](https://duckdb.org/2025/05/27/ducklake.html) for transactional Data Lake

## 🆙 Upgrading to Enterprise version

- **Multi-node**: Horizontal scaling by just adding more nodes
- **Federated Authentication**: Integration with authentication providers

Need higher limits or advanced features? Contact us at **[boilstream.com](https://www.boilstream.com)**
