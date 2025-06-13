# Flink CDC Orphan Record Validation Pipeline

## 🧠 Logical Flow
1. Child records from source_cba_ci_adr are streamed into Flink.

2. Each record’s CI_ID is LEFT JOINED with records in the parent table SOURCE_CBA_CI (i.e., topic source_cba_ci).

3. If the CI_ID exists in source_cba_ci, it's a valid record.

4. If the CI_ID does not exist in source_cba_ci, it's marked as orphan and sent to sink_orphan_ci_adr.

## This proof-of-concept demonstrates a CDC (Change Data Capture) validation flow using **Apache Flink SQL on Confluent Cloud**, focusing on identifying **orphan child records** in a streaming architecture.

---

## ✅ Objective

Identify child records in the ADR topic that have no matching parent record in the CI topic. Route them to a dedicated "orphan" sink.

* ✅ If a matching CI\_ID is found → send to `sink_valid_cba_ci_adr`
* ❌ If CI\_ID is missing in the parent table → send to `sink_orphan_ci_adr`

---

## 📦 Topics Used

| Table Role      | Kafka Topic             |
| --------------- | ----------------------- |
| Parent Table    | `source_cba_ci`         |
| Child Table     | `source_cba_ci_adr`     |
| Valid ADR Sink  | `sink_valid_cba_ci_adr` |
| Orphan ADR Sink | `sink_orphan_ci_adr`    |

---

## 🪄 Steps Performed

### 1. Created Source Tables in Flink SQL

```sql
CREATE TABLE SOURCE_CBA_CI (
  CI_ID STRING,
  CI_STATE_C STRING,
  PRIMARY KEY (CI_ID) NOT ENFORCED
) WITH (
  'connector' = 'confluent',
  'topic' = 'source_cba_ci',
  'key.format' = 'avro',
  'value.format' = 'avro-registry'
);

CREATE TABLE SOURCE_CBA_CI_ADR (
  CI_ID STRING,
  CI_A1_1 STRING,
  PRIMARY KEY (CI_ID) NOT ENFORCED
) WITH (
  'connector' = 'confluent',
  'topic' = 'source_cba_ci_adr',
  'key.format' = 'avro',
  'value.format' = 'avro-registry'
);
```

### 2. Created Sink Tables

```sql
CREATE TABLE SINK_VALID_CBA_CI_ADR (
  CI_ID STRING,
  CI_A1_1 STRING,
  PRIMARY KEY (CI_ID) NOT ENFORCED
) WITH (
  'connector' = 'confluent',
  'topic' = 'sink_valid_cba_ci_adr',
  'key.format' = 'avro',
  'value.format' = 'avro-registry'
);

CREATE TABLE SINK_ORPHAN_CI_ADR (
  CI_ID STRING,
  CI_A1_1 STRING,
  ERROR_REASON STRING,
  PRIMARY KEY (CI_ID) NOT ENFORCED
) WITH (
  'connector' = 'confluent',
  'topic' = 'sink_orphan_ci_adr',
  'key.format' = 'avro',
  'value.format' = 'avro-registry'
);
```

### 3. Insert Queries

```sql
INSERT INTO SINK_VALID_CBA_CI_ADR
SELECT adr.CI_ID, adr.CI_A1_1
FROM SOURCE_CBA_CI_ADR adr
JOIN SOURCE_CBA_CI ci ON adr.CI_ID = ci.CI_ID;

INSERT INTO SINK_ORPHAN_CI_ADR
SELECT adr.CI_ID, adr.CI_A1_1, 'No matching CI_ID in SOURCE_CBA_CI' AS ERROR_REASON
FROM SOURCE_CBA_CI_ADR adr
LEFT JOIN SOURCE_CBA_CI ci ON adr.CI_ID = ci.CI_ID
WHERE ci.CI_ID IS NULL;
```

### 4. Schemas Used (All JSON-formatted Avro)

#### Key Schema (All Tables)

```json
{
  "type": "record",
  "name": "key",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [
    { "name": "CI_ID", "type": "string" }
  ]
}
```

#### Value Schemas

* **source\_cba\_ci**

```json
{
  "type": "record",
  "name": "SOURCE_CBA_CI_value",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [
    { "name": "CI_ID", "type": "string" },
    { "name": "CI_STATE_C", "type": ["null", "string"], "default": null }
  ]
}
```

* **source\_cba\_ci\_adr**

```json
{
  "type": "record",
  "name": "SOURCE_CBA_CI_ADR_value",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [
    { "name": "CI_ID", "type": "string" },
    { "name": "CI_A1_1", "type": ["null", "string"], "default": null }
  ]
}
```

* **sink\_orphan\_ci\_adr**

```json
{
  "type": "record",
  "name": "SINK_ORPHAN_CI_ADR_value",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [
    { "name": "CI_ID", "type": "string" },
    { "name": "CI_A1_1", "type": ["null", "string"], "default": null },
    { "name": "ERROR_REASON", "type": ["null", "string"], "default": null }
  ]
}
```

---

## 🔎 Validation Data

### Valid Message

* Topic: `source_cba_ci`

```json
// Key
{ "CI_ID": "CBA202" }
// Value
{ "CI_ID": "CBA202", "CI_STATE_C": { "string": "ACTIVE" } }
```

* Topic: `source_cba_ci_adr`

```json
// Key
{ "CI_ID": "CBA202" }
// Value
{ "CI_ID": "CBA202", "CI_A1_1": { "string": "Main St" } }
```

### Orphan Message

* Topic: `source_cba_ci_adr`

```json
// Key
{ "CI_ID": "CBA999" }
// Value
{ "CI_ID": "CBA999", "CI_A1_1": { "string": "Unknown Rd" } }
```

---

## ✅ Output Expectations

| CI\_ID | Exists in CI? | Output Topic              |
| ------ | ------------- | ------------------------- |
| CBA202 | ✅ Yes         | sink\_valid\_cba\_ci\_adr |
| CBA999 | ❌ No          | sink\_orphan\_ci\_adr     |

---

## 🧑 Author

Prateek
