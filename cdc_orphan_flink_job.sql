-- ✅ FLINK CDC ORPHAN DETECTION POC: Confluent Cloud Edition

-- 🔹 STEP 1: SOURCE TABLE (Parent: CI)
CREATE TABLE SOURCE_CBA_CI (
  CI_ID STRING,
  CI_STATE_C STRING,
  PRIMARY KEY (CI_ID) NOT ENFORCED
) WITH (
  'connector' = 'confluent',
  'kafka.topic' = 'source_cba_ci',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry'
);

-- 🔹 STEP 2: SOURCE TABLE (Child: ADR)
CREATE TABLE SOURCE_CBA_CI_ADR (
  CI_ID STRING,
  CI_A1_1 STRING,
  PRIMARY KEY (CI_ID) NOT ENFORCED
) WITH (
  'connector' = 'confluent',
  'kafka.topic' = 'source_cba_ci_adr',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry'
);

-- 🔹 STEP 3: SINK TABLE (Orphans)
CREATE TABLE SINK_ORPHAN_CI_ADR (
  CI_ID STRING,
  CI_A1_1 STRING,
  ERROR_REASON STRING,
  PRIMARY KEY (CI_ID) NOT ENFORCED
) WITH (
  'connector' = 'confluent',
  'kafka.topic' = 'sink_orphan_ci_adr',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry'
);

-- 🔹 STEP 4: INSERT JOB (Anti-Join for Orphans)
INSERT INTO SINK_ORPHAN_CI_ADR
SELECT
  adr.CI_ID,
  adr.CI_A1_1,
  'NO MATCH FOUND' AS ERROR_REASON
FROM (
  SELECT *, ci.CI_ID AS match_check
  FROM SOURCE_CBA_CI_ADR adr
  LEFT JOIN SOURCE_CBA_CI ci
    ON adr.CI_ID = ci.CI_ID
)
WHERE match_check IS NULL;