import boto3
import os
import json
import re

ses = boto3.client("ses")

TO_EMAIL = os.environ["TO_EMAIL"]


def lambda_handler(event, context):
    try:
        # Parse request body
        body = json.loads(event["body"])

        name = body.get("name", "").strip()
        email = body.get("email", "").strip()
        message = body.get("message", "").strip()

        # Validation
        if not name or not email or not message:
            return {
                "statusCode": 400,
                "headers": {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "POST, OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type"
                },
                "body": json.dumps({"error": "All fields are required"})
            }

        # Email validation
        if not re.match(r'^[^@]+@[^@]+\.[^@]+$', email):
            return {
                "statusCode": 400,
                "headers": {"Access-Control-Allow-Origin": "*"},
                "body": json.dumps({"error": "Invalid email format"})
            }

        # Send email via SES
        email_body = f"""
New message from your portfolio website!

Name: {name}
Email: {email}

Message:
{message}

---
Sent from your portfolio contact form
        """

        ses.send_email(
            Source=TO_EMAIL,
            Destination={"ToAddresses": [TO_EMAIL]},
            Message={
                "Subject": {"Data": f"📧 Portfolio Message from {name}"},
                "Body": {"Text": {"Data": email_body}}
            }
        )

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            "body": json.dumps({"status": "Message sent successfully!"})
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": "Internal server error"})
        }