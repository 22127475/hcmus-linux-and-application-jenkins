# #!/bin/bash

# # 🟡 Lấy giá trị từ CloudFormation exports
# CLUSTER_NAME="linux-and-application"
# SUBNET_1=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnet-1a'].Value" --output text)
# SUBNET_2=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnet-1b'].Value" --output text)
# SECURITY_GROUP=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-App-Tier-SG-ID'].Value" --output text)

# # 🟡 Các biến còn lại
# REGION="us-east-1"

# DOCKER_IMAGE="$1"
# TASK_DEF_NAME="jenkins-app"

# if [ -z "$IMAGE_TAG" ]; then
#   echo "❌ Thiếu IMAGE_TAG. "
#   exit 1
# fi

# echo "🚀 Chạy ECS task với Docker image: $DOCKER_IMAGE"

# aws ecs run-task \
#   --cluster "$CLUSTER_NAME" \
#   --task-definition "$TASK_DEF_NAME" \
#   --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_1,$SUBNET_2],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
#   --overrides '{
#       "containerOverrides": [{
#         "name": "jenkins-app",
#         "image": "22127475/jenkinsapp:main-abc123"
#       }]
#     }'









#!/bin/bash

set -e

# 🟡 Lấy giá trị từ CloudFormation exports
CLUSTER_NAME="linux-and-application"
SUBNET_1=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnet-1a'].Value" --output text)
SUBNET_2=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnet-1b'].Value" --output text)
SECURITY_GROUP=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-App-Tier-SG-ID'].Value" --output text)

# 🟡 Các biến còn lại
REGION="us-east-1"
DOCKER_IMAGE="$1"

if [ -z "$DOCKER_IMAGE" ]; then
  echo "❌ Thiếu Docker image tag (VD: 22127475/jenkinsapp:main-abc123)"
  exit 1
fi

# 🟡 Tạo một task definition mới
TASK_DEF_NAME="jenkins-app"
CONTAINER_NAME="jenkins-app"
TASK_DEF_FAMILY="${TASK_DEF_NAME}-$(echo "$DOCKER_IMAGE" | tr ':/' '--')"

echo "🛠️  Đăng ký task definition mới với image: $DOCKER_IMAGE"

aws ecs register-task-definition \
  --family "$TASK_DEF_FAMILY" \
  --requires-compatibilities FARGATE \
  --network-mode awsvpc \
  --cpu "256" \
  --memory "512" \
  --container-definitions "[
    {
      \"name\": \"$CONTAINER_NAME\",
      \"image\": \"$DOCKER_IMAGE\",
      \"essential\": true,
      \"portMappings\": [
        {
          \"containerPort\": 80,
          \"hostPort\": 80,
          \"protocol\": \"tcp\"
        }
      ]
    }
  ]" \
  --region "$REGION"

echo "🚀 Chạy ECS task từ task definition mới..."

aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_1,$SUBNET_2],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
  --task-definition "$TASK_DEF_FAMILY" \
  --region "$REGION"
