import json
import base64
import re
import io
from PIL import Image
import boto3

s3 = boto3.client('s3')
BUCKET_NAME = 'naveen-original-uploaded-images'  # Replace with your actual bucket name

def respond(status_code, message):
    return {
        "statusCode": status_code,
        "body": json.dumps({"message": message}),
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        }
    }

def parse_multipart(body_bytes, content_type):
    boundary_match = re.search('boundary=([^;]+)', content_type)
    if not boundary_match:
        return None, None
    boundary = boundary_match.group(1).encode()

    parts = body_bytes.split(b'--' + boundary)

    for part in parts:
        if b'Content-Disposition' in part and b'filename=' in part:
            filename_match = re.search(b'filename="([^"]+)"', part)
            if not filename_match:
                continue
            filename = filename_match.group(1).decode('utf-8', errors='replace')

            header_end = part.find(b'\r\n\r\n')
            if header_end == -1:
                continue

            file_bytes = part[header_end + 4:]
            file_bytes = file_bytes.rstrip(b'\r\n')

            try:
                Image.open(io.BytesIO(file_bytes)).verify()
            except Exception:
                continue

            return file_bytes, filename

    return None, None

def lambda_handler(event, context):
    try:
        is_base64_encoded = event.get('isBase64Encoded', False)
        content_type = event['headers'].get('Content-Type') or event['headers'].get('content-type')

        if not content_type or 'multipart/form-data' not in content_type:
            return respond(400, "Unsupported Content-Type")

        body = base64.b64decode(event['body']) if is_base64_encoded else event['body'].encode('utf-8', errors='replace')

        file_bytes, filename = parse_multipart(body, content_type)
        if not file_bytes or not filename:
            return respond(400, "No image file found or file is invalid")

        # Upload to S3
        s3.put_object(Bucket=BUCKET_NAME, Key=filename, Body=file_bytes, ContentType='image/jpeg')

        return respond(200, f"Successfully uploaded {filename} to S3 bucket {BUCKET_NAME}")

    except Exception as e:
        print("Error occurred:", str(e))
        return respond(500, f"Error: {str(e)}")
