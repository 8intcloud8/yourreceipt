#!/bin/bash

# Create deployment package for AWS Lambda
echo "Creating Lambda deployment package..."

# Create a temporary directory
mkdir -p package

# Install dependencies
pip install -r requirements.txt -t package/

# Copy Lambda function and dependencies
cp lambda_function.py package/
cp openai_client.py package/
cp parse_response.py package/

# Create zip file
cd package
zip -r ../receipt-scanner-lambda.zip .
cd ..

# Clean up
rm -rf package

echo "Deployment package created: receipt-scanner-lambda.zip"
echo "Package size: $(du -h receipt-scanner-lambda.zip | cut -f1)"