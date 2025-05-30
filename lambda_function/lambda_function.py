import boto3
import os
import io
from PIL import Image
import base64

s3 = boto3.client('s3')
BUCKET_NAME = 'naveen-uploaded-images'  # change to your bucket

ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png'}

def lambda_handler(event, context):
    try:
        # Get the file from API Gateway event (multipart/form-data base64)
        content_type = event['headers'].get('content-type') or event['headers'].get('Content-Type')
        if not content_type or 'multipart/form-data' not in content_type:
            return respond(400, 'Invalid content-type. Must be multipart/form-data.')

        # Decode the body
        body = base64.b64decode(event['body'])
        
        # Parse multipart form-data manually (simple parse for one file)
        file_bytes, filename = parse_multipart(body, content_type)
        if not filename:
            return respond(400, 'No file found in request.')

        ext = filename.rsplit('.', 1)[-1].lower()
        if ext not in ALLOWED_EXTENSIONS:
            return respond(400, f'File extension {ext} not allowed.')

        # Open image with Pillow
        image = Image.open(io.BytesIO(file_bytes))

        # Convert to black and white
        bw_image = image.convert('L')

        # Resize image (example: max width or height 500px)
        bw_image.thumbnail((500, 500))

        # Save to bytes
        output_buffer = io.BytesIO()
        bw_image.save(output_buffer, format='PNG')
        output_buffer.seek(0)

        # Upload to S3
        s3_key = f"processed/{filename.rsplit('.',1)[0]}_bw.png"
        s3.put_object(Bucket=BUCKET_NAME, Key=s3_key, Body=output_buffer, ContentType='image/png')

        return respond(200, f"Image processed and uploaded to s3://{BUCKET_NAME}/{s3_key}")

    except Exception as e:
        return respond(500, f"Error: {str(e)}")


def respond(status_code, message):
    return {
        'statusCode': status_code,
        'body': message,
        'headers': {'Content-Type': 'text/plain'}
    }


def parse_multipart(body_bytes, content_type):
    """
    Simple parser for multipart/form-data, extracting file bytes and filename.
    Assumes only one file in form.
    """
    import re

    boundary = re.findall('boundary=([^;]+)', content_type)[0]
    boundary_bytes = boundary.encode()

    parts = body_bytes.split(b'--' + boundary_bytes)
    for part in parts:
        if b'Content-Disposition' in part and b'filename=' in part:
            # Extract filename
            filename_match = re.search(b'filename="([^"]+)"', part)
            if not filename_match:
                continue
            filename = filename_match.group(1).decode()

            # Extract file content
            file_start = part.find(b'\r\n\r\n') + 4
            file_end = part.rfind(b'\r\n')
            file_bytes = part[file_start:file_end]

            return file_bytes, filename
    return None, None
