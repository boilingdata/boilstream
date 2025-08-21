-- -------------------------------------
-- Load Airport extension
-- curl -L -o /tmp/airport.duckdb_extension https://www.boilstream.com/binaries/darwin-aarch64/airport.duckdb_extension
load '/tmp/airport.duckdb_extension';
select extension_name, loaded from duckdb_extensions() where loaded=true;

SELECT function_name FROM duckdb_functions() WHERE function_name LIKE 'airport%';
SELECT airport_version(), airport_user_agent();

-- NYC Yellow Taxi rides
CREATE TABLE boilstream.s3.nyc(
	VendorID INTEGER,
	tpep_pickup_datetime TIMESTAMP, 
	tpep_dropoff_datetime TIMESTAMP, 
	passenger_count BIGINT, 
	trip_distance DOUBLE, 
	RatecodeID BIGINT, 
	store_and_fwd_flag VARCHAR, 
	PULocationID INTEGER, 
	DOLocationID INTEGER, 
	payment_type BIGINT, 
	fare_amount DOUBLE, 
	extra DOUBLE, 
	mta_tax DOUBLE, 
	tip_amount DOUBLE, 
	tolls_amount DOUBLE, 
	improvement_surcharge DOUBLE, 
	total_amount DOUBLE, 
	congestion_surcharge DOUBLE, 
	Airport_fee DOUBLE, 
	cbd_congestion_fee double
);

-- Attach boilstream ingestion port into itself, so you can write to it with SQL
ATTACH 'boilstream' as data (TYPE AIRPORT, location 'grpc://localhost:50051/');
-- Download NYC Yellow Taxi tripdata parquet files from Internet and ingest them through BoilStream
insert into data.s3.nyc	select * from parquet_scan('yellow_tripdata_2025-*.parquet');
-- BoilStream will create a VIEW over the nyc table / topic, once it gets data and you have DuckDB 
-- local persistence enabled (i.e. on-disk caching into DuckDB databases)
-- The Postgres interface connects directly to BoilStream in-memory DuckDB database that has
-- real-time view over the ingested data, while also enabling concurrent writers and readers.
select COUNT(*) from nyc;
select * from nyc order by passenger_count asc limit 10;


-- Streaming Topic metadata (catalog)
-- The "topics" table is visible for DuckDB Airport clients along 
-- ..with the Arrow schema on "topic_schemas"
-- Derived views are materialised views.
select * from boilstream.topics;
select * from boilstream.topic_schemas;
select * from boilstream.derived_views;
select COUNT(*) from memory.boilstream.derived_views;

-- Streaming Topic management
CREATE TABLE boilstream.s3.people (name VARCHAR, age INT, tags VARCHAR[]);
CREATE TABLE boilstream.s3.teens AS SELECT name FROM boilstream.s3.people WHERE age > 12 AND age < 20;
CREATE TABLE boilstream.s3.adults AS SELECT name FROM boilstream.s3.people WHERE age = 50;
CREATE TABLE boilstream.s3.oldies AS SELECT name FROM boilstream.s3.people WHERE age = 80;
DROP TABLE boilstream.s3.people;
DROP TABLE boilstream.s3.teens;
DROP TABLE boilstream.s3.adults;
DROP TABLE boilstream.s3.oldies;

-- With the Airport extesion, attach ourselves for writing to the topic
-- ..Just like from any DuckDB client with Airport extension
detach data;
ATTACH 'boilstream' as data (TYPE AIRPORT, location 'grpc://localhost:50051/');
show databases;
show all tables;
INSERT INTO data.s3.people 
	SELECT 
		'boilstream_' || i::VARCHAR as name, 
		(i % 100) + 1 as age, 
		['airport', 'datasketches'] as tags 
	FROM generate_series(1, 6000000) as t(i);
-- After couple of seconds, BoilStream creates VIEW into memory.main named "people" (topic name)
-- memory.main has views over the DuckDB persisted database tables (topics)
select * from duckdb_views() where database_name='memory' and schema_name='main';

select COUNT(*) from people;
select COUNT(*) from teens;
select COUNT(*) from adults;
select COUNT(*) from oldies;
select COUNT(*) from people where age < 50;
select COUNT(*), age from people group by age limit 100;

-- -------------------------------------
-- Postgres Interface Types testing
-- For complete and extensive type testing, see demo_database.sql
-- It fully works with Power BI
CREATE TABLE IF NOT EXISTS psql_decimal128_test AS 
	SELECT i AS id, CAST(i * 3.14 AS DECIMAL(22,2)) AS value FROM range(5) t(i);

describe (select id, value::VARCHAR from psql_decimal128_test);
select id, value::VARCHAR from psql_decimal128_test;

describe (select id, value::DECIMAL(22,2) from psql_decimal128_test);
select id, value::DECIMAL(22,2) from psql_decimal128_test;

SELECT uuid() as uuid_v4, 
	gen_random_uuid() as gen_uuid_v4, 
	uuidv7() as uuid_v7;

SELECT 12345.67::DECIMAL(22,2) as price, 
	0.00::DECIMAL(22,2) as zero, 
	-999.99::DECIMAL(22,2) as negative;

describe (SELECT ['1aa', 'b2', 'c3', 'd4', 'z5'] as string_array);
SELECT ['1aa', 'b2', 'c3', 'd4', 'z5'] as string_array;

SELECT COUNT(*) as total_count, COUNT(oid) as non_null_oids FROM pg_catalog.pg_type;

DESCRIBE (SELECT [1, 2, 3, 4, 5] as int_array);
SELECT [1, 2, 3, 4, 5] as int_array;

SELECT '2023-12-25 14:30:45'::TIMESTAMP as basic_timestamp, 
	'2023-12-25 14:30:45.123456'::TIMESTAMP as timestamp_with_microseconds,  
	'2023-12-25 14:30:45+02:00'::TIMESTAMPTZ as timestamp_with_tz, 
	NOW() as current_timestamp, 
	'2023-12-25'::DATE as date_only, 
	'14:30:45'::TIME as time_only, 
	INTERVAL '1 day 2 hours 30 minutes' as interval_example, 
	to_timestamp(1703512245) as from_epoch, 
	date_trunc('hour', NOW()) as truncated_hour,
	date_part('year', NOW()) as year_part, 
	strptime('25/12/2023 14:30:45', '%d/%m/%Y %H:%M:%S') as parsed_timestamp;

describe (select INTERVAL '1 day 2 hours 30 minutes' as interval_example);
select INTERVAL '1 day 2 hours 30 minutes' as interval_example

SELECT json_object('name', 'John', 'age', 30, 'city', 'New York') as json_obj;

SELECT '\x48656c6c6f'::BLOB as hello_blob, '\x576f726c64'::BLOB as world_blob;

CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');
SELECT enum_code('happy'::mood) as happy_code, 
	enum_first(NULL::mood) as first_value, 
	enum_last(NULL::mood) as last_value;

CREATE VIEW test_view AS SELECT 1 as test_col;
SELECT relname, relkind, relnamespace 
	FROM pg_catalog.pg_class WHERE relname = 'test_view';