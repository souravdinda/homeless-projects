# SF Homelessness Analytics Pipeline

A serverless data pipeline on AWS that ingests raw SF homelessness data, transforms it via Lambda, and makes it queryable through Amazon Athena.

---

## Architecture Overview

```
Raw CSVs → S3 (Raw) → Lambda (Transform) → S3 (Processed/Parquet) → Glue Crawler → Athena
```

| Component | Service | Purpose |
|---|---|---|
| Raw Storage | Amazon S3 | Stores the two input CSV files |
| Processing | AWS Lambda (Python 3.12) | Merges, cleans, and converts data to Parquet |
| Processed Storage | Amazon S3 | Stores the output Parquet file |
| Schema Catalog | AWS Glue Crawler | Automatically detects Parquet schema |
| Analytics | Amazon Athena | SQL queries over the Parquet data |
| Monitoring | CloudWatch Logs + Alarm | Tracks Lambda errors |
| IaC | Terraform | Provisions all infrastructure |
| CI/CD | GitHub Actions | Runs `terraform apply` on push |

---

## Input Data

Two CSV files must be uploaded to the **raw S3 bucket**:

### `SF_HOMELESS_DEMOGRAPHICS_2026.csv`
Contains demographic information about homeless individuals.

| Column | Example | Description |
|---|---|---|
| `HID` | `001-15` | Unique Homeless ID (`XXX-YY` format) |
| `Registration Date` | `01-09-2007` | Date of registration |
| `First Name`, `Last Name` | `Meri`, `American` | Name fields |
| `Date Of Birth` | `02-25-1981` | Date of birth |
| `Gender` | `Male` | Gender |
| `Race#1` | `Unknown` | Race |
| `Shelter` | `Billy's Shelter` | Current shelter assignment |

### `SF_HOMELESS_ANXIETY_2026.csv`
Contains anxiety encounter records.

| Column | Example | Description |
|---|---|---|
| `Homeless ID` | `HM15-18` | Homeless ID in `HMxx-xxx` format |
| `Encounter Date` | `2019-05-01` | Date of anxiety encounter |
| `Anxiety Lvl` | `4` | Anxiety level score (1-10) |

---

## Lambda Processor: Step-by-Step

The Lambda function (`lambda/processor.py`) is triggered automatically when a CSV file is uploaded to the raw S3 bucket. Here is exactly what it does:

### Step 1 — Read both CSVs from S3

```python
demo_obj = s3.get_object(Bucket=raw_bucket, Key='SF_HOMELESS_DEMOGRAPHICS_2026.csv')
demo_df = pd.read_csv(io.BytesIO(demo_obj['Body'].read()))

anx_obj = s3.get_object(Bucket=raw_bucket, Key='SF_HOMELESS_ANXIETY_2026.csv')
anx_df = pd.read_csv(io.BytesIO(anx_obj['Body'].read()))
```

Both files are streamed directly from S3 into in-memory Pandas DataFrames using `io.BytesIO`.

---

### Step 2 — Normalize the ID formats

The two files use **different ID formats** for the same person:
- Demographics uses: `001-15` (`XXX-YY`)
- Anxiety uses: `HM15-1` (`HMxx-x`)

The `normalize_anxiety_id()` function converts the Anxiety ID to match the Demographics format:

```python
def normalize_anxiety_id(hid):
    # Input:  'HM15-18'
    # Output: '018-15'
    if str(hid).startswith('HM'):
        body = hid[2:]          # Strip 'HM' → '15-18'
        parts = body.split('-') # Split  → ['15', '18']
        yy = parts[0]           # Year   → '15'
        xxx = parts[1].zfill(3) # ID padded to 3 digits → '018'
        return f"{xxx}-{yy}"    # Result → '018-15'
```

Applied to every row in the anxiety dataframe:
```python
anx_df['Normalized_ID'] = anx_df['Homeless ID'].apply(normalize_anxiety_id)
```

---

### Step 3 — Join the two datasets

A left join is performed on the aligned ID columns. This keeps all demographic records, adding any anxiety encounter data where a match is found:

```python
merged_df = pd.merge(demo_df, anx_df, left_on='HID', right_on='Normalized_ID', how='left')
merged_df = merged_df.drop_duplicates()
```

---

### Step 4 — Clean up columns

The temporary `Normalized_ID` helper column and the numeric `Identifier` row index are dropped. The `Encounter Date` is reformatted as a clean `YYYY-MM-DD` string so Athena reads it correctly:

```python
merged_df['Encounter Date'] = pd.to_datetime(merged_df['Encounter Date']).dt.strftime('%Y-%m-%d')
merged_df = merged_df.drop(columns=['Identifier', 'Normalized_ID'], errors='ignore')
```

> **Note:** The date is formatted as a string to avoid Parquet `TIMESTAMP(NANOS)` precision issues that cause errors in Athena's Trino query engine.

---

### Step 5 — Write to S3 as Parquet

The merged DataFrame is serialized to the Apache Parquet format (columnar, efficient for Athena queries) and uploaded to the processed S3 bucket:

```python
out_buffer = io.BytesIO()
merged_df.to_parquet(out_buffer, engine='pyarrow', index=False)
s3.put_object(Bucket=processed_bucket, Key='encounters_data/run.parquet', Body=out_buffer.getvalue())
```

---

### Step 6 — Trigger the Glue Crawler

After writing the file, the Lambda automatically starts the Glue Crawler to refresh the Athena schema, ensuring any new columns or data types are detected:

```python
glue.start_crawler(Name=crawler_name)
```

---

## Final Athena Schema

After the crawler runs, the `encounters_data` table in Athena will contain:

| Column | Type | Source |
|---|---|---|
| `hid` | string | Demographics CSV |
| `registration_date` | string | Demographics CSV |
| `first_name` | string | Demographics CSV |
| `last_name` | string | Demographics CSV |
| `date_of_birth` | string | Demographics CSV |
| `gender` | string | Demographics CSV |
| `race_1` | string | Demographics CSV |
| `shelter` | string | Demographics CSV |
| `homeless_id` | string | Anxiety CSV |
| `encounter_date` | string | Anxiety CSV |
| `anxiety_lvl` | bigint | Anxiety CSV |

---

## Saved Athena Query

A named query is pre-provisioned via Terraform:

```sql
SELECT
  Shelter,
  ROUND(AVG(anxiety_lvl), 2) as average_anxiety,
  COUNT(*) as total_encounters
FROM
  encounters_data
GROUP BY
  Shelter
ORDER BY
  average_anxiety DESC;
```

---

## Terraform Modules

| Module | Path | Provisions |
|---|---|---|
| `storage` | `modules/storage` | 3 S3 buckets (raw, processed, athena results) |
| `processing` | `modules/processing` | Lambda, IAM roles, S3 trigger, CloudWatch Alarm |
| `analytics` | `modules/analytics` | Glue DB, Crawler, Athena Workgroup, Named Query |

---

## CI/CD Workflows

| Workflow | File | Trigger | Action |
|---|---|---|---|
| Deploy | `.github/workflows/deploy.yml` | Push to any branch or manual | `terraform init` + `terraform apply` |
| Destroy | `.github/workflows/destroy.yml` | Manual only | `terraform destroy` |

---

## Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region to deploy to |
| `project_prefix` | `e84-pilot` | Prefix for all resource names |
| `glue_database_name` | `e84_homelessness_analytics` | Glue database name |
| `athena_workgroup_name` | `e84AnalyticsWorkgroup` | Athena workgroup name |

---

## Resetting the Pipeline

If you need to reprocess data or fix a schema issue:

1. **Delete** all files in the processed S3 bucket under `encounters_data/`
2. **Delete** the `encounters_data` table in the Glue Data Catalog
3. **Re-upload** both CSV files to the raw S3 bucket
4. Lambda will re-run, re-write the Parquet file, and the Crawler will refresh the schema