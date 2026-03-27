#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  LocalStack — Initialization script
#  (mounted at /etc/localstack/init/ready.d/)
# ─────────────────────────────────────────────────────────────────────────────

set -e

REGION="us-east-1"
ACCOUNT_ID="000000000000"
QUEUE_NAME="fiscal-guard-events"
DLQ_NAME="fiscal-guard-events-dlq"
BUCKET_NAME="fiscal-guard-data"

echo "Initializing LocalStack resources..."

# ── SQS: Dead Letter Queue ────────────────────────────────────────────────────
echo "  → Creating DLQ: $DLQ_NAME"
awslocal sqs create-queue \
  --queue-name "$DLQ_NAME" \
  --region "$REGION" \
  --attributes MessageRetentionPeriod=1209600  # 14 days

DLQ_URL="http://localhost:4566/$ACCOUNT_ID/$DLQ_NAME"
DLQ_ARN="arn:aws:sqs:$REGION:$ACCOUNT_ID:$DLQ_NAME"

# ── SQS: Main Queue ───────────────────────────────────────────────────────
echo "  → Creating main queue: $QUEUE_NAME"
awslocal sqs create-queue \
  --queue-name "$QUEUE_NAME" \
  --region "$REGION" \
  --attributes VisibilityTimeout=60,MessageRetentionPeriod=86400

# Link DLQ to main queue (after creating both)
awslocal sqs set-queue-attributes \
  --queue-url "http://localhost:4566/$ACCOUNT_ID/$QUEUE_NAME" \
  --region "$REGION" \
  --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}"

# ── S3: Data Bucket ───────────────────────────────────────────────────────
echo "  → Creating S3 bucket: $BUCKET_NAME"
awslocal s3 mb "s3://$BUCKET_NAME" --region "$REGION"

# Configure lifecycle: expire temporary objects after 30 days
awslocal s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET_NAME" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "expire-tmp",
      "Filter": { "Prefix": "tmp/" },
      "Status": "Enabled",
      "Expiration": { "Days": 30 }
    }]
  }'

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "LocalStack ready!"
echo "   SQS Queue : http://localhost:4566/$ACCOUNT_ID/$QUEUE_NAME"
echo "   SQS DLQ   : $DLQ_URL"
echo "   S3 Bucket : s3://$BUCKET_NAME"
