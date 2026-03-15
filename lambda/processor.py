import os
import io
import boto3
import pandas as pd
from datetime import datetime

s3 = boto3.client('s3')
glue = boto3.client('glue')

def normalize_anxiety_id(hid):
    """
    Transforms Homeless ID from 'HM15-18' format to '018-15' format 
    to match the Demographics table 'HID' column.
    """
    if str(hid).startswith('HM'):
        body = hid[2:] # '15-18'
        parts = body.split('-')
        if len(parts) == 2:
            yy = parts[0]
            xxx = parts[1].zfill(3) # pad with zeros to length 3
            return f"{xxx}-{yy}"
    return hid

def lambda_handler(event, context):
    try:
        raw_bucket = os.environ['RAW_BUCKET']
        processed_bucket = os.environ['PROCESSED_BUCKET']

        # 1. Fetch CSV files from the Raw S3 Bucket
        demo_obj = s3.get_object(Bucket=raw_bucket, Key='SF_HOMELESS_DEMOGRAPHICS_2026.csv')
        demo_df = pd.read_csv(io.BytesIO(demo_obj['Body'].read()))

        anx_obj = s3.get_object(Bucket=raw_bucket, Key='SF_HOMELESS_ANXIETY_2026.csv')
        anx_df = pd.read_csv(io.BytesIO(anx_obj['Body'].read()))

        # 2. Clean and Align data (The Core Project Challenge)
        anx_df['Normalized_ID'] = anx_df['Homeless ID'].apply(normalize_anxiety_id)

        # Merge datasets on the newly aligned ID
        merged_df = pd.merge(demo_df, anx_df, left_on='HID', right_on='Normalized_ID', how='inner')
        
        # Convert Encounter Date correctly and drop all unnecessary helper columns
        merged_df['Encounter Date'] = pd.to_datetime(merged_df['Encounter Date']).dt.strftime('%Y-%m-%d')
        merged_df = merged_df.drop(columns=['Identifier', 'Normalized_ID'], errors='ignore')

        # 3. Save to Processed Bucket as Parquet (Optimized for Athena)
        # Using pyarrow engine for pandas to parquet conversion
        out_buffer = io.BytesIO()
        merged_df.to_parquet(out_buffer, engine='pyarrow', index=False)
        
        # Create a partitioned S3 key matching Hive style partitioning
        # e.g., s3://processed-bucket/encounters/year=2019/month=05/data_timestamp.parquet
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        
        s3.put_object(
            Bucket=processed_bucket,
            # For the pilot, we assume current date processing. In a real system, 
            # we would loop through and write partitioned files based on the DataFrame's year/month.
            # Simplified here for the pilot writing to a generic path:
            Key=f'encounters_data/run_{timestamp}.parquet',
            Body=out_buffer.getvalue()
        )

        print(f"Successfully processed and wrote run_{timestamp}.parquet to {processed_bucket}")

        # 4. Trigger the Glue Crawler automatically to update Athena schema
        crawler_name = os.environ.get('CRAWLER_NAME')
        if crawler_name:
            try:
                glue.start_crawler(Name=crawler_name)
                print(f"Triggered Glue Crawler: {crawler_name}")
            except Exception as e:
                print(f"Warning: Failed to trigger crawler (it might already be running): {str(e)}")

        return {"statusCode": 200, "body": "Success"}
        
    except Exception as e:
        print(f"Error processing files: {str(e)}")
        # This will trigger the CloudWatch errors metric
        raise e
