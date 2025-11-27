import boto3
import os
import json
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

TABLE_NAME = os.environ["TABLE_NAME"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    try:
        # Increment visitor count
        response = table.update_item(
            Key={"id": "visitor_total"},
            UpdateExpression="ADD visit_count :inc",
            ExpressionAttributeValues={":inc": 1},
            ReturnValues="UPDATED_NEW"
        )

        new_count = response["Attributes"]["visit_count"]

        # Send SNS notification
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="👓 New Visitor to Your Portfolio!",
            Message=f"""Hey! Someone is checking out your portfolio website!

👓 Total visits: {new_count}
⏳ Time: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC

Keep creating amazing work! """
        )

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            "body": json.dumps({"count": new_count})
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({"error": "Internal server error"})
        }