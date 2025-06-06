import json
import base64
import re
import io
import os
from PIL import Image, ImageOps
import boto3

s3 = boto3.client('s3')
sns = boto3.client('sns')

SOURCE_BUCKET_NAME = 'naveen-original-uploaded-images-vpikkili'
PROCESSED_BUCKET_NAME = 'naveen-processed-images-vpikkili'
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')  # from CloudFormation env variables

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
    "Access-Control-Allow-Methods": "POST,OPTIONS"
}

def respond(status_code, message):
    return {
        "statusCode": status_code,
        "body": json.dumps({"message": message}),
        "headers": CORS_HEADERS
    }

def send_sns_alert(subject, message):
    if SNS_TOPIC_ARN:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )

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

            # Verify image integrity
            try:
                Image.open(io.BytesIO(file_bytes)).verify()
            except Exception:
                return None, filename

            return file_bytes, filename

    return None, None

def resize_image(image, max_size=800):
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
    if event['httpMethod'] == 'OPTIONS':
        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps({"message": "CORS preflight check"})
        }

    try:
        is_base64_encoded = event.get('isBase64Encoded', False)
        headers = event.get('headers', {})
        content_type = headers.get('Content-Type') or headers.get('content-type')

        if not content_type or 'multipart/form-data' not in content_type:
            send_sns_alert("Invalid Upload", "Unsupported content type used in request.")
            return respond(400, "Unsupported Content-Type")

        body = base64.b64decode(event['body']) if is_base64_encoded else event['body'].encode('utf-8', errors='replace')

        file_bytes, filename = parse_multipart(body, content_type)
        if not file_bytes or not filename:
            send_sns_alert("Invalid Image Upload", "No valid image found or file type not supported.")
            return respond(400, "No image file found or file is invalid")

        # Open image for format validation
        image = Image.open(io.BytesIO(file_bytes))

        allowed_formats = ['JPEG', 'PNG']
        if image.format not in allowed_formats:
            send_sns_alert("Invalid Image Format", f"Upload rejected due to unsupported format: {image.format}")
            return respond(400, f"Invalid image format '{image.format}'. Only JPEG and PNG are allowed.")

        # Upload original image with correct ContentType
        content_type_map = {
            'JPEG': 'image/jpeg',
            'PNG': 'image/png'
        }
        s3.put_object(Bucket=SOURCE_BUCKET_NAME, Key=filename, Body=file_bytes, ContentType=content_type_map[image.format])

        # Process image: grayscale + resize
        bw_image = ImageOps.grayscale(image)
        resized_image = resize_image(bw_image, max_size=800)

        buffer = io.BytesIO()
        resized_image.save(buffer, format='JPEG')
        buffer.seek(0)
        processed_bytes = buffer.read()

        s3.put_object(Bucket=PROCESSED_BUCKET_NAME, Key=filename, Body=processed_bytes, ContentType='image/jpeg')

        return respond(200, f"Successfully uploaded and processed image '{filename}'.")

    except Exception as e:
        error_message = f"Lambda processing error: {str(e)}"
        print("Error occurred:", error_message)
        send_sns_alert("Processing Error", error_message)
        return respond(500, error_message)
