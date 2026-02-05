# BoilStream - Stream to Gold Easily 🏆

[BoilStream](https://www.boilstream.com/) is a multi-tenant DuckDB server written in Rust (and C++) with native DuckLake integration. Use for real-time streaming analytics, as a Data Warehouse and/or Data Lakehouse.

Download, start, and connect with any Postgres-compatible BI tool. Ingest via Kafka, HTTPS Arrow, FlightRPC/FlightSQL. Data streams to S3 as DuckLake-managed Parquet files in realtime.

**Key Features:**

- **Multi-tenant DuckDB** with tenant isolation (secrets, attachments, DuckLakes, filesystem)
- **High-performance ingestion**: Kafka (JIT Avro decoder 3-5x faster), HTTPS Arrow, FlightRPC/FlightSQL
- **Postgres interface** for BI tools (Power BI, DBeaver, Metabase, Grafana). [Type compliance report](https://boilstream.com/test_report.html)
- **DuckLake integration** with embedded PostgreSQL catalog, 1s hot tier commits, automatic backup/restore
- **DuckLake vending** for native DuckDB clients, DuckDB-WASM browsers, and in-server queries
- **Cold tier hydration API** (>1GB/s) to lift tables from cold to hot tier
- **Streaming DuckLakes** with `__stream` suffix - tables become topics, views become materialised streams
- **Enterprise SSO or local user accounts**: Entra ID SAML, SCIM user provisioning, MFA/PassKey
- **Horizontal cluster mode** with S3-based leader election and distributed catalog management
- **boilstream-admin CLI** for cluster management and observability
- **DuckDB Remote Secrets Store** for secure credential storage via boilstream-extension
- **Prometheus/Grafana monitoring** (metrics port 8081)

**Companion extension**: [boilstream-extension v0.5.0](https://github.com/dforsber/boilstream-extension) for native DuckDB and DuckDB-WASM clients

## Web Auth GUI

**Normal users** (port 443):

- Vend temporary Postgres credentials and web tokens (ingest, secrets)
- MFA management (TOTP, Passkeys, backup codes)
- Session management and account settings

**Superadmin** (port 443/admin):

- Cloud accounts (AWS, Azure, GCP credential management)
- S3 bucket registry and BoilStream roles (IAM-like access control)
- DuckLake catalog management with ownership transfer
- User management, role assignments to users/SAML groups
- SAML SSO configuration (metadata upload, attribute mapping, SCIM)
- Cluster management (brokers, leader stepdown)
- Audit logging and cloud log forwarding (CloudWatch, Azure Monitor, GCP)

Also available via `boilstream-admin` CLI.

## Data Durability

Data streams to S3 with automatic Parquet conversion and schema validation. When `INSERT` returns, data is guaranteed on primary storage.

- **Primary storage failure**: Ingestion stalls until storage recovers (data integrity first)
- **Secondary storage failure**: Does not affect ingestion
- **Local DuckDB persistence**: Optional, independent of storage backends

## Interfaces

**Postgres (port 5432)**: Connect any BI tool - Power BI, DBeaver, Metabase, Superset, Grafana, psql. Also serves as DuckLake PostgreSQL catalog for native DuckDB clients (ducklake\_\* users).

**FlightRPC (port 50051)**: High-performance Arrow ingestion from DuckDB clients via Airport extension.

**FlightSQL (port 50250)**: Arrow-based SQL interface for ADBC drivers and FlightSQL clients.

**HTTP/2 Arrow ingestion (port 443)**: Stream Arrow data from browsers (Flechette JS) or any HTTP client. Supports tens of thousands of concurrent connections.

**Kafka (port 9092)**: Confluent Schema Registry compatible with Avro format. Built-in read-only schema registry at `/schema-registry` for schema discovery.

**Real-time SQL Streaming**: Views in `__stream` DuckLakes become never-ending continuous stream processors without micro-batch overhead.

## Start

```bash
# Download boilstream (generates example config if none provided)
# Linux: linux-x64, linux-aarch64 | macOS: darwin-x64, darwin-aarch64
curl -L -o boilstream https://www.boilstream.com/binaries/darwin-aarch64/boilstream-0.8.3
curl -L -o boilstream-admin https://www.boilstream.com/binaries/darwin-aarch64/boilstream-admin-0.8.3
chmod +x boilstream boilstream-admin

# SERVER_IP_ADDRESS is used on the Flight interface, use reachable IP address
SERVER_IP_ADDRESS=1.2.3.4 ./boilstream

# Docker: boilinginsights/boilstream:x64-linux-0.8.3 or :aarch64-linux-0.8.3
docker run -v ./config.yaml:/app/config.yaml \
   -p 443:443 -p 5432:5432 -p 50051:50051 -p 50250:50250 \
   -e SERVER_IP_ADDRESS=1.2.3.4 boilinginsights/boilstream:aarch64-linux-0.8.3
```

> _You can use the accompanying docker-compose.yml file to start auxiliary containers for Grafana Dashboard and S3 Minio_

## Streaming DuckLakes

Create a DuckLake with `__stream` suffix for real-time streaming. Tables become ingestion topics, views become materialised streaming views.

```sql
-- Create streaming DuckLake (via Web GUI or boilstream-admin CLI)
-- Tables in __stream DuckLakes automatically become ingestion topics
CREATE TABLE my_data__stream.main.people (name VARCHAR, age INT, tags VARCHAR[]);

-- Views become materialised real-time streaming views
CREATE VIEW my_data__stream.main.adults AS SELECT * FROM people WHERE age > 50;
```

### Ingesting with DuckDB clients

**When INSERT returns, data is guaranteed on S3.**

```sql
INSTALL airport FROM community;
LOAD airport;
ATTACH 'my_data__stream' (TYPE AIRPORT, location 'grpc://localhost:50051/');

INSERT INTO my_data__stream.main.people
   SELECT 'user_' || i::VARCHAR AS name, (i % 100) + 1 AS age, ['duckdb'] AS tags
   FROM generate_series(1, 20000) as t(i);
```

**Monitor with Grafana**: http://localhost:3000 (admin/admin)

## 📋 Requirements

- 8GB+ RAM recommended
- macOS (x64, arm64) or Linux (x64, arm64)
- Docker optional (for Grafana, Minio)

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## Documentation

Full docs: **[docs.boilstream.com](https://docs.boilstream.com)** | Contact: **[boilstream.com](https://www.boilstream.com)**
