#!/bin/bash

set -e

# 🟡 Các biến cần thiết
CLUSTER_NAME="linux-and-application"
REGION="us-east-1"
TASK_DEF_NAME="jenkins-app"
DOCKER_IMAGE="$1"  # ví dụ: 22127475/jenkinsapp:main-abc123
TG_ARN=$(aws cloudformation list-exports --query "Exports[?Name=='JenkinsApp-TG-ARN'].Value" --output text)

# Lấy từ CloudFormation
SUBNET_1=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnet-1a'].Value" --output text)
SUBNET_2=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnet-1b'].Value" --output text)
SECURITY_GROUP=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-App-Tier-SG-ID'].Value" --output text)

echo "🚀 Running ECS task with image: $DOCKER_IMAGE"

# 🟠 Run ECS Task
TASK_ARN=$(aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_1,$SUBNET_2],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
  --overrides "{
    \"containerOverrides\": [{
      \"name\": \"jenkins-app\"
    }]
  }" \
  --task-definition "$TASK_DEF_NAME" \
  --region "$REGION" \
  --query "tasks[0].taskArn" --output text)

echo "🔄 Waiting for task to run..."
aws ecs wait tasks-running --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN"

# 🟢 Get ENI (network interface)
ENI_ID=$(aws ecs describe-tasks \
  --cluster "$CLUSTER_NAME" \
  --tasks "$TASK_ARN" \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
  --output text)

# 🟢 Get Public IP
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids "$ENI_ID" \
  --query "NetworkInterfaces[0].Association.PublicIp" \
  --output text)

echo "🌐 Public IP: $PUBLIC_IP"

# 🟢 Register to Target Group
aws elbv2 register-targets \
  --target-group-arn "$TG_ARN" \
  --targets "Id=$PUBLIC_IP,Port=80"

echo "✅ ECS Task registered to ALB successfully."
echo "🔗 Access URL: http://$(aws cloudformation list-exports --query \"Exports[?Name=='JenkinsApp-ALB-DNSName'].Value\" --output text)"
