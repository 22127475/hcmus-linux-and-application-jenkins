#!/bin/bash

# 🟡 Lấy giá trị từ CloudFormation exports
CLUSTER_NAME="linux-and-application"
SUBNET_1=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnet-1a'].Value" --output text)
SUBNET_2=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnet-1b'].Value" --output text)
SECURITY_GROUP=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-App-Tier-SG-ID'].Value" --output text)

# 🟡 Các biến còn lại
REGION="us-east-1"
IMAGE_TAG="$1"
DOCKER_IMAGE="22127475/jenkinsapp:${IMAGE_TAG}"
TASK_DEF_NAME="jenkins-app"

if [ -z "$IMAGE_TAG" ]; then
  echo "❌ Thiếu IMAGE_TAG. "
  exit 1
fi

echo "🚀 Chạy ECS task với Docker image: $DOCKER_IMAGE"

aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --task-definition "$TASK_DEF_NAME" \
  --task-definition my-task-def:1 \
  --overrides '{
      "containerOverrides": [{
        "name": "jenkins-app",
        "image": "22127475/jenkinsapp:main-abc123"
      }]
    }'






