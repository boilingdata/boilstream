-- === Schema (keeps things organized) ===
CREATE SCHEMA IF NOT EXISTS demo;

-- === Boolean ===
CREATE OR REPLACE TABLE demo.bool_samples(val BOOLEAN);
INSERT INTO demo.bool_samples
VALUES (TRUE),(FALSE),(TRUE),(FALSE),(TRUE),(FALSE),(TRUE),(FALSE),(TRUE),(FALSE);

-- === Signed integers ===
CREATE OR REPLACE TABLE demo.tinyint_samples(val TINYINT);
INSERT INTO demo.tinyint_samples VALUES (-128),(-1),(0),(1),(12),(34),(56),(78),(100),(127);

CREATE OR REPLACE TABLE demo.smallint_samples(val SMALLINT);
INSERT INTO demo.smallint_samples VALUES (-32768),(-12345),(-1),(0),(1),(99),(500),(12345),(20000),(32767);

CREATE OR REPLACE TABLE demo.int_samples(val INTEGER);
INSERT INTO demo.int_samples VALUES (-2147483648),(-999999999),(-1),(0),(1),(42),(123456),(2000000000),(2147480000),(2147483647);

CREATE OR REPLACE TABLE demo.bigint_samples(val BIGINT);
INSERT INTO demo.bigint_samples VALUES
(-9223372036854775808),(-9000000000000000000),(-1),(0),(1),(42),(1234567890123),(9000000000000000000),(9223372036854770000),(9223372036854775807);

-- === Unsigned integers ===
CREATE OR REPLACE TABLE demo.utinyint_samples(val UTINYINT);
INSERT INTO demo.utinyint_samples VALUES (0),(1),(2),(3),(10),(100),(200),(240),(254),(255);

CREATE OR REPLACE TABLE demo.usmallint_samples(val USMALLINT);
INSERT INTO demo.usmallint_samples VALUES (0),(1),(2),(3),(1000),(10000),(40000),(50000),(65000),(65535);

CREATE OR REPLACE TABLE demo.uinteger_samples(val UINTEGER);
INSERT INTO demo.uinteger_samples VALUES (0),(1),(2),(3),(1000),(1000000),(4000000000),(4200000000),(4294967000),(4294967295);

CREATE OR REPLACE TABLE demo.ubigint_samples(val UBIGINT);
INSERT INTO demo.ubigint_samples VALUES
(0),(1),(2),(3),(1000),(1000000),(1000000000000),(18446744073709500000),(18446744073709551614),(18446744073709551615);

-- === Huge integers (128-bit) ===
CREATE OR REPLACE TABLE demo.hugeint_samples(val HUGEINT);
INSERT INTO demo.hugeint_samples VALUES
(-170141183460469231731687303715884105728), -- min
(-1),(0),(1),
(170141183460469231731687303715884105727),   -- max
(123456789012345678901234567890),
(-123456789012345678901234567890),
(99999999999999999999999999999),
(-99999999999999999999999999999),
(42);

-- === Floating point & Decimal ===
CREATE OR REPLACE TABLE demo.real_samples(val REAL);
INSERT INTO demo.real_samples VALUES (-1e10),(-3.14),(-0.0),(0.0),(1.0),(3.14159),(1e-5),(1e5),(12345.678),(42.0);

CREATE OR REPLACE TABLE demo.double_samples(val DOUBLE);
INSERT INTO demo.double_samples VALUES (-1e308),(-2.5),(0.0),(1.0),(2.5),(3.141592653589793),(1e-10),(1e10),(9.99e99),(42.42);

CREATE OR REPLACE TABLE demo.decimal_samples(val DECIMAL(38,10));
INSERT INTO demo.decimal_samples VALUES
(-9999999999.1234567890),(-1.0000000000),(0.0000000000),(1.0000000000),
(3.1415926535),(2.7182818281),(1234567890.1234567890),
(0.0000000001),(9999999999.9999999999),(42.4200000000);

-- === Character / String & BLOB ===
CREATE OR REPLACE TABLE demo.varchar_samples(val VARCHAR);
INSERT INTO demo.varchar_samples VALUES
(''),('a'),('hello'),('DuckDB'),('😀 emoji'),
('multi word string'),('UPPER lower'),('12345'),('json-ish {"a":1}'),('end');

CREATE OR REPLACE TABLE demo.blob_samples(val BLOB);
-- Hex literal X'..'
INSERT INTO demo.blob_samples VALUES
(X''),      -- empty
(X'00'),
(X'FF'),
(X'DEADBEEF'),
(X'CAFEBABE'),
(X'01020304'),
(X'FFFFFFFF'),
(X'A1B2C3D4'),
(X'1122334455'),
(X'ABCD');

-- === UUID ===
CREATE OR REPLACE TABLE demo.uuid_samples(val UUID);
INSERT INTO demo.uuid_samples VALUES
('00000000-0000-0000-0000-000000000000'),
('11111111-1111-1111-1111-111111111111'),
('123e4567-e89b-12d3-a456-426614174000'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
('cccccccc-cccc-cccc-cccc-cccccccccccc'),
('dddddddd-dddd-dddd-dddd-dddddddddddd'),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
('ffffffff-ffff-ffff-ffff-ffffffffffff'),
('00000000-0000-0000-0000-000000000001');

-- === Dates & times ===
CREATE OR REPLACE TABLE demo.date_samples(val DATE);
INSERT INTO demo.date_samples VALUES
('0001-01-01'),('1970-01-01'),('1999-12-31'),
('2000-01-01'),('2020-02-29'),('2024-02-29'),
('2025-01-01'),('2025-08-19'),('9999-12-31'),('2010-07-15');

CREATE OR REPLACE TABLE demo.time_samples(val TIME);
INSERT INTO demo.time_samples VALUES
('00:00:00'),('00:00:00.123'),('06:30:00'),
('12:00:00'),('12:00:00.999999'),('18:45:10'),
('23:59:59.999999'),('01:02:03'),('13:37:59'),('21:21:21');

CREATE OR REPLACE TABLE demo.timestamp_samples(val TIMESTAMP);
INSERT INTO demo.timestamp_samples VALUES
('1970-01-01 00:00:00'),
('1999-12-31 23:59:59.999'),
('2000-01-01 00:00:00'),
('2020-02-29 12:34:56'),
('2024-02-29 23:59:59.999999'),
('2025-01-01 00:00:00'),
('2025-08-19 15:00:00'),
('2010-07-15 08:09:10'),
('1995-05-23 03:04:05'),
('2030-12-31 23:59:59');

-- TIMESTAMP WITH TIME ZONE (aka TIMESTAMPTZ)
CREATE OR REPLACE TABLE demo.timestamptz_samples(val TIMESTAMPTZ);
INSERT INTO demo.timestamptz_samples VALUES
('1970-01-01 00:00:00+00'),
('1999-12-31 23:59:59+00'),
('2000-01-01 00:00:00-05'),
('2020-02-29 12:34:56+03'),
('2024-02-29 23:59:59.999999-03'),
('2025-01-01 00:00:00+00'),
('2025-08-19 15:00:00-03'),
('2010-07-15 08:09:10+09'),
('1995-05-23 03:04:05-08'),
('2030-12-31 23:59:59+14');

-- === INTERVAL ===
CREATE OR REPLACE TABLE demo.interval_samples(val INTERVAL);
INSERT INTO demo.interval_samples VALUES
(INTERVAL '1' SECOND),
(INTERVAL '1' MINUTE),
(INTERVAL '1' HOUR),
(INTERVAL '1' DAY),
(INTERVAL '1' MONTH),
(INTERVAL '1' YEAR),
(INTERVAL '2 days 03:04:05'),
(INTERVAL '6 months 15 days'),
(INTERVAL '3 years 2 months 1 day'),
(INTERVAL '90 minutes');

-- === JSON ===
CREATE OR REPLACE TABLE demo.json_samples(val JSON);
INSERT INTO demo.json_samples VALUES
('null'::JSON),
('true'::JSON),
('123'::JSON),
('"text"'::JSON),
('{"a":1}'::JSON),
('{"a":1,"b":[1,2,3]}'::JSON),
('[1,2,3]'::JSON),
('[{"k":"v"},{"k":"w"}]'::JSON),
('{"nested":{"x":10,"y":[false, true]}}'::JSON),
('{"empty":{}}'::JSON);

-- === Nested types: LIST, STRUCT, MAP ===
CREATE OR REPLACE TABLE demo.list_int_samples(val INT[]);
INSERT INTO demo.list_int_samples VALUES
([ ]),([1]),([1,2]),([10,20,30]),
([NULL]),([5,NULL,7]),([100,200]),([3,3,3]),([42]),([1,2,3,4,5]);

CREATE OR REPLACE TABLE demo.struct_samples(val STRUCT(a INT, b VARCHAR, c BOOLEAN));
INSERT INTO demo.struct_samples VALUES
({a: NULL, b: NULL, c: NULL}),
({a: 1, b: 'x', c: TRUE}),
({a: 2, b: 'y', c: FALSE}),
({a: 3, b: 'z', c: TRUE}),
({a: 10, b: 'abc', c: FALSE}),
({a: -1, b: '', c: TRUE}),
({a: 0, b: 'zero', c: FALSE}),
({a: 999, b: 'end', c: TRUE}),
({a: 42, b: 'meaning', c: TRUE}),
({a: 7, b: 'seven', c: FALSE});

-- MAP<K,V> (DuckDB map type). Use the map(keys, values) constructor.
CREATE OR REPLACE TABLE demo.map_samples(val MAP(VARCHAR, INT));
INSERT INTO demo.map_samples VALUES
(map([], [])),
(map(['a'], [1])),
(map(['k','v'], [10,20])),
(map(['x','y','z'], [1,2,3])),
(map(['only'], [NULL])),
(map(['neg','pos'], [-1,1])),
(map(['wide','tall'], [100,200])),
(map(['forty-two'], [42])),
(map(['n','m','p','q'], [5,6,7,8]));

-- === ENUM ===
CREATE TYPE mood AS ENUM ('happy','sad','neutral','excited','tired');
CREATE OR REPLACE TABLE demo.enum_samples(val mood);
INSERT INTO demo.enum_samples VALUES
('happy'),('sad'),('neutral'),('excited'),('tired'),
('happy'),('neutral'),('excited'),('sad'),('tired');

-- === Sanity checks ===
-- Count rows for all tables (should be 10 each)
SELECT table_name, row_count
FROM (
  SELECT 'bool_samples' AS table_name, (SELECT COUNT(*) FROM demo.bool_samples) AS row_count UNION ALL
  SELECT 'tinyint_samples',(SELECT COUNT(*) FROM demo.tinyint_samples) UNION ALL
  SELECT 'smallint_samples',(SELECT COUNT(*) FROM demo.smallint_samples) UNION ALL
  SELECT 'int_samples',(SELECT COUNT(*) FROM demo.int_samples) UNION ALL
  SELECT 'bigint_samples',(SELECT COUNT(*) FROM demo.bigint_samples) UNION ALL
  SELECT 'utinyint_samples',(SELECT COUNT(*) FROM demo.utinyint_samples) UNION ALL
  SELECT 'usmallint_samples',(SELECT COUNT(*) FROM demo.usmallint_samples) UNION ALL
  SELECT 'uinteger_samples',(SELECT COUNT(*) FROM demo.uinteger_samples) UNION ALL
  SELECT 'ubigint_samples',(SELECT COUNT(*) FROM demo.ubigint_samples) UNION ALL
  SELECT 'hugeint_samples',(SELECT COUNT(*) FROM demo.hugeint_samples) UNION ALL
  SELECT 'real_samples',(SELECT COUNT(*) FROM demo.real_samples) UNION ALL
  SELECT 'double_samples',(SELECT COUNT(*) FROM demo.double_samples) UNION ALL
  SELECT 'decimal_samples',(SELECT COUNT(*) FROM demo.decimal_samples) UNION ALL
  SELECT 'varchar_samples',(SELECT COUNT(*) FROM demo.varchar_samples) UNION ALL
  SELECT 'blob_samples',(SELECT COUNT(*) FROM demo.blob_samples) UNION ALL
  SELECT 'uuid_samples',(SELECT COUNT(*) FROM demo.uuid_samples) UNION ALL
  SELECT 'date_samples',(SELECT COUNT(*) FROM demo.date_samples) UNION ALL
  SELECT 'time_samples',(SELECT COUNT(*) FROM demo.time_samples) UNION ALL
  SELECT 'timestamp_samples',(SELECT COUNT(*) FROM demo.timestamp_samples) UNION ALL
  SELECT 'timestamptz_samples',(SELECT COUNT(*) FROM demo.timestamptz_samples) UNION ALL
  SELECT 'interval_samples',(SELECT COUNT(*) FROM demo.interval_samples) UNION ALL
  SELECT 'json_samples',(SELECT COUNT(*) FROM demo.json_samples) UNION ALL
  SELECT 'list_int_samples',(SELECT COUNT(*) FROM demo.list_int_samples) UNION ALL
  SELECT 'struct_samples',(SELECT COUNT(*) FROM demo.struct_samples) UNION ALL
  SELECT 'map_samples',(SELECT COUNT(*) FROM demo.map_samples) UNION ALL
  SELECT 'enum_samples',(SELECT COUNT(*) FROM demo.enum_samples)
);
