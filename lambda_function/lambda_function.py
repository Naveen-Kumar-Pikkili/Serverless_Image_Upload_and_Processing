import json
import base64
import re
import io
from PIL import Image, ImageOps
import boto3

# S3 clients and bucket names
s3 = boto3.client('s3')
SOURCE_BUCKET_NAME = 'naveen-original-uploaded-images'      # Original bucket
PROCESSED_BUCKET_NAME = 'naveen-processed-images'           # Bucket for processed images

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

def resize_image(image, max_size=800):
    # Resize image maintaining aspect ratio so that max dimension is max_size
    width, height = image.size
    if max(width, height) <= max_size:
        return image

    if width > height:
        new_width = max_size
        new_height = int((max_size / width) * height)
    else:
        new_height = max_size
        new_width = int((max_size / height) * width)

    return image.resize((new_width, new_height), Image.Resampling.LANCZOS)

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

        # Upload original image to SOURCE_BUCKET_NAME
        s3.put_object(Bucket=SOURCE_BUCKET_NAME, Key=filename, Body=file_bytes, ContentType='image/jpeg')

        # Open image from bytes
        image = Image.open(io.BytesIO(file_bytes))

        # Convert to grayscale (black and white)
        bw_image = ImageOps.grayscale(image)

        # *** Removed rotation here ***

        # Resize image to max 800 pixels width/height
        resized_image = resize_image(bw_image, max_size=800)

        # Save processed image to bytes buffer
        buffer = io.BytesIO()
        # Save as JPEG regardless of original format for consistency
        resized_image.save(buffer, format='JPEG')
        buffer.seek(0)
        processed_bytes = buffer.read()

        # Upload processed image to the processed bucket
        s3.put_object(Bucket=PROCESSED_BUCKET_NAME, Key=filename, Body=processed_bytes, ContentType='image/jpeg')

        return respond(200, f"Successfully uploaded original and processed image '{filename}' to S3 buckets")

    except Exception as e:
        print("Error occurred:", str(e))
        return respond(500, f"Error: {str(e)}")
