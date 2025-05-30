import boto3
import os
import io
import base64
import cgi
from PIL import Image

s3 = boto3.client('s3')
BUCKET_NAME = os.environ['BUCKET_NAME']

ALLOWED_EXTENSIONS = ['jpg', 'jpeg', 'png']
RESIZE_WIDTH = 300
RESIZE_HEIGHT = 300

def lambda_handler(event, context):
    try:
        # Get content type and decode body
        content_type = event['headers'].get('Content-Type') or event['headers'].get('content-type')
        body = event['body']
        if event.get('isBase64Encoded'):
            body = io.BytesIO(base64.b64decode(body))
        else:
            body = io.BytesIO(body.encode())

        environ = {'REQUEST_METHOD': 'POST'}
        headers = {'content-type': content_type}
        form = cgi.FieldStorage(fp=body, environ=environ, headers=headers)

        # Get uploaded image
        image_file = form['file']
        filename = image_file.filename
        file_ext = filename.split('.')[-1].lower()

        # ❌ Check allowed extensions
        if file_ext not in ALLOWED_EXTENSIONS:
            return {
                'statusCode': 400,
                'body': f"Invalid file type: .{file_ext}. Only JPG, JPEG, and PNG are allowed."
            }

        # Read and process image
        image_data = image_file.file.read()
        image = Image.open(io.BytesIO(image_data))

        # ✅ Resize
        image = image.resize((RESIZE_WIDTH, RESIZE_HEIGHT))

        # ✅ Convert to black & white (1-bit)
        image = image.convert('1')  # '1' = binary (black and white)

        # Save processed image to buffer
        buffer = io.BytesIO()
        image.save(buffer, format='PNG')
        buffer.seek(0)

        output_filename = f"processed-{filename.rsplit('.', 1)[0]}.png"

        # Upload to S3
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=output_filename,
            Body=buffer,
            ContentType='image/png'
        )

        return {
            'statusCode': 200,
            'body': f"Image processed and uploaded as {output_filename}"
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': f"Error: {str(e)}"
        }
