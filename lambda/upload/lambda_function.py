import json
import base64
import boto3
import os
import io
from PIL import Image, UnidentifiedImageError

s3 = boto3.client('s3')
BUCKET_NAME = os.environ.get('BUCKET_NAME', 'original-images-bucket')

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}

def lambda_handler(event, context):
    try:
        # Expect binary payload as Base64
        if not event.get("isBase64Encoded") or not event.get("body"):
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Invalid payload: expected a base64-encoded image."})
            }

        # Filename via custom header
        headers = {k.lower(): v for k, v in event.get("headers", {}).items()}
        file_name = headers.get('file-name')
        if not file_name or '.' not in file_name:
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Missing or invalid 'file-name' header."})
            }

        ext = file_name.rsplit('.', 1)[1].lower()
        if ext not in ALLOWED_EXTENSIONS:
            return {
                "statusCode": 400,
                "body": json.dumps({"message": f"Invalid file type '{ext}'. Allowed: {', '.join(ALLOWED_EXTENSIONS)}."})
            }

        # Decode and verify image
        image_data = base64.b64decode(event["body"])
        try:
            img = Image.open(io.BytesIO(image_data))
            img.verify()   # throws if not a valid image
        except (UnidentifiedImageError, IOError):
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Uploaded file is not a valid image."})
            }

        # Upload to S3
        key = f"uploads/{file_name}"
        s3.put_object(Bucket=BUCKET_NAME, Key=key, Body=image_data)

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Image uploaded successfully", "fileName": file_name, "s3Key": key})
        }

    except Exception as e:
        print("Error:", str(e))
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Internal server error"})
        }
