# BoilStream — Streaming Ingestion Lakehouse

[BoilStream](https://www.boilstream.com/) is a multi-tenant DuckDB server written in Rust with native DuckLake integration. Ingest, transform, aggregate, search, and consume streaming data — all with SQL.

Download, start, and connect with any Postgres-compatible BI tool. Data streams to S3 as DuckLake-managed Parquet files in real-time.

## Key Features

**Streaming Data Flow** — Ingest → Transform → Aggregate → Search → Consume

- **Multi-tenant DuckDB** — Full tenant isolation (secrets, attachments, DuckLakes, filesystem)
- **Streaming views** — Continuous row-by-row SQL transforms on ingested data
- **Materialized views** — Tumbling/sliding window aggregations with DuckDB SQL
- **Full-text search** — Integrated [Tantivy](https://github.com/quickwit-oss/tantivy) indexing with hot/cold tiered storage and `multilake_search()` SQL function
- **Real-time consumption** — SSE push with Arrow IPC batches via [`@boilstream/consumer`](https://github.com/dforsber/boilstream-consumer-js) JS SDK
- **DuckLake integration** — Embedded PostgreSQL catalog, 1s hot tier commits, cold tier hydration (>1GB/s)
- **DuckLake vending** — Credential vending for native DuckDB, DuckDB-WASM, and in-server queries
- **Enterprise auth** — Entra ID SAML, SCIM provisioning, MFA/Passkeys, Web Auth GUI
- **Cluster mode** — S3-based leader election, distributed catalog management
- **Multi-cloud** — AWS S3, Azure Blob, GCS, MinIO, filesystem

**Companion projects:** [boilstream-extension](https://github.com/dforsber/boilstream-extension) for DuckDB/WASM clients | [`@boilstream/consumer`](https://github.com/dforsber/boilstream-consumer-js) for SSE consumption

## Interfaces

| Interface | Port | Description |
|-----------|------|-------------|
| **Postgres** | 5432 | BI tools (Power BI, DBeaver, Grafana, psql). [Type compliance report](https://boilstream.com/test_report.html) |
| **FlightRPC** | 50051 | High-performance Arrow ingestion via Airport extension |
| **FlightSQL** | 50250 | Arrow SQL for ADBC drivers and FlightSQL clients |
| **HTTP/2 Arrow** | 443 | Arrow POST from browsers or HTTP clients |
| **Kafka** | 9092 | Kafka wire protocol with Schema Registry and Confluent binary Avro |
| **SSE** | 443 | Real-time Arrow IPC push to browsers and services |

## Start

See [GitHub releases](https://github.com/boilingdata/boilstream/releases) for the latest version.

```bash
# Download — pick your platform from:
#   darwin-aarch64   Apple Silicon Mac
#   darwin-x64       Intel Mac
#   linux-aarch64    Linux ARM64 — AWS Graviton-tuned (fastest on AWS EC2 Graviton 2/3/4)
#   linux-x64        Linux x86_64
#   windows-x64      Windows
# Replace {VERSION} with the latest release (see GitHub releases above, e.g. 0.10.21)
curl -L -o boilstream https://www.boilstream.com/binaries/darwin-aarch64/boilstream-{VERSION}
curl -L -o boilstream-admin https://www.boilstream.com/binaries/darwin-aarch64/boilstream-admin-{VERSION}
chmod +x boilstream boilstream-admin

# Non-AWS ARM64 (Hetzner, Oracle Ampere, Apple Silicon inside a Linux Docker container):
# the default linux-aarch64 build uses AWS Graviton extensions and will SIGILL on
# Ampere Altra and similar. Use the -generic variant instead:
#   curl -L -o boilstream       https://www.boilstream.com/binaries/linux-aarch64/boilstream-{VERSION}-generic
#   curl -L -o boilstream-admin https://www.boilstream.com/binaries/linux-aarch64/boilstream-admin-{VERSION}-generic

SERVER_IP_ADDRESS=1.2.3.4 ./boilstream

# Docker — AWS Graviton or x86_64:
docker run -v ./config.yaml:/app/config.yaml \
   -p 443:443 -p 5432:5432 -p 50051:50051 -p 50250:50250 \
   -e SERVER_IP_ADDRESS=1.2.3.4 boilinginsights/boilstream:aarch64-linux-{VERSION}

# Docker on non-AWS ARM64 (Hetzner, Oracle Ampere, Apple Silicon):
#   boilinginsights/boilstream:aarch64-generic-linux-{VERSION}
```

> _Use the accompanying `docker-compose.yml` to start Grafana and MinIO_

## Streaming DuckLakes

DuckLakes with `__stream` suffix enable real-time streaming. Tables become ingestion topics.

```sql
CREATE TABLE my_data__stream.main.events (user_id VARCHAR, event_type VARCHAR, ts TIMESTAMP, payload JSON);

-- Streaming view: continuous row-by-row filter
CREATE STREAMING VIEW clicks AS SELECT * FROM events WHERE event_type = 'click';

-- Materialized view: windowed aggregation
CREATE MATERIALIZED VIEW events_per_min AS
  SELECT event_type, COUNT(*) AS cnt FROM events
  WITH (window_type='tumbling', window_size='1 minute', timestamp_column='ts');

-- Full-text search: enable indexing, then query
ALTER TABLE my_data__stream.main.events SET (tantivy_enabled = true, tantivy_text_fields = 'payload');
SELECT * FROM multilake_search('my_data__stream', 'events__tantivy_idx', 'error timeout');
```

### Ingest with DuckDB

**When INSERT returns, data is guaranteed on S3.**

```sql
INSTALL airport FROM community;
LOAD airport;
ATTACH 'my_data__stream' (TYPE AIRPORT, location 'grpc://localhost:50051/');

INSERT INTO my_data__stream.main.events
   SELECT 'user_' || i::VARCHAR, CASE WHEN i % 3 = 0 THEN 'click' ELSE 'view' END,
          NOW(), '{"page": "home"}'
   FROM generate_series(1, 20000) AS t(i);
```

## Requirements

- 8GB+ RAM recommended
- macOS (arm64) or Linux (x64, arm64)
- Docker optional (for Grafana, MinIO)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## Documentation

Full docs: **[docs.boilstream.com](https://docs.boilstream.com)** | Contact: **[boilstream.com](https://www.boilstream.com)**
