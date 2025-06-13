# flink-cdc-orphan-poc
# Flink CDC Orphan Record Validation Pipeline

This repository implements a CDC (Change Data Capture) validation pipeline using **Apache Flink SQL** on **Confluent Cloud** to identify and route orphan child records (ADR) that lack a corresponding parent record (CI).

---

## ✅ Objective

To validate whether each ADR record in the `source_cba_ci_adr` topic has a matching CI parent record in the `source_cba_ci` topic:

* ✅ If match found → route to `sink_valid_cba_ci_adr`
* ❌ If no match → route to `sink_orphan_ci_adr` with error reason

---

## 📌 Topics

| Role        | Topic Name              |
| ----------- | ----------------------- |
| Parent CI   | `source_cba_ci`         |
| Child ADR   | `source_cba_ci_adr`     |
| Valid ADRs  | `sink_valid_cba_ci_adr` |
| Orphan ADRs | `sink_orphan_ci_adr`    |

---

## 🛠️ Step-by-Step Instructions

### Step 1: Create Source Tables

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
```

```sql
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

### Step 2: Create Sink Tables

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
```

```sql
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

### Step 3: Insert Logic

```sql
INSERT INTO SINK_ORPHAN_CI_ADR
SELECT
  adr.CI_ID,
  adr.CI_A1_1,
  'No matching CI_ID in SOURCE_CBA_CI' AS ERROR_REASON
FROM SOURCE_CBA_CI_ADR adr
LEFT JOIN SOURCE_CBA_CI ci
ON adr.CI_ID = ci.CI_ID
WHERE ci.CI_ID IS NULL;
```

```sql
INSERT INTO SINK_VALID_CBA_CI_ADR
SELECT
  adr.CI_ID,
  adr.CI_A1_1
FROM SOURCE_CBA_CI_ADR adr
JOIN SOURCE_CBA_CI ci
ON adr.CI_ID = ci.CI_ID;
```

### Step 4: Produce Test Records

#### Valid Parent Record

Topic: `source_cba_ci`

```json
// Key
{ "CI_ID": "CBA202" }
// Value
{ "CI_ID": "CBA202", "CI_STATE_C": { "string": "ACTIVE" } }
```

#### Valid ADR Record

Topic: `source_cba_ci_adr`

```json
// Key
{ "CI_ID": "CBA202" }
// Value
{ "CI_ID": "CBA202", "CI_A1_1": { "string": "Green Valley" } }
```

#### Orphan ADR Record

Topic: `source_cba_ci_adr`

```json
// Key
{ "CI_ID": "CBA404" }
// Value
{ "CI_ID": "CBA404", "CI_A1_1": { "string": "Missing Link Road" } }
```

---

## 🔍 Expected Behavior

| Input CI\_ID | Parent Exists? | Sink Output             |
| ------------ | -------------- | ----------------------- |
| `CBA202`     | ✅ Yes          | `sink_valid_cba_ci_adr` |
| `CBA404`     | ❌ No           | `sink_orphan_ci_adr`    |

---

## 📁 Folder Structure

```
flink-cdc-orphan-validation/
├── create-source-tables.sql
├── create-sink-tables.sql
├── insert-queries.sql
├── test-messages/
│   ├── valid-parent.json
│   ├── valid-adr.json
│   └── orphan-adr.json
└── README.md
```

---

## 💬 Notes

* Flink SQL jobs must be created using **Confluent Cloud UI**.
* Topics must use **Avro + Schema Registry** for type enforcement.
* `ORPHAN` sink topic is analogous to a **dead letter queue (DLQ)**.

---

## 🧑‍💻 Author

Prateek
