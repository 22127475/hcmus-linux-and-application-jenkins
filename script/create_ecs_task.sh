#!/bin/bash

set -e

# ========================== #
# 🟡 Biến cấu hình
# ========================== #
CLUSTER_NAME="linux-and-application"
REGION="us-east-1"
DOCKER_IMAGE="$1"  # ví dụ: 22127475/jenkinsapp:main-abc123
TASK_DEF_NAME="jenkins-app-$(date +%s)"
CONTAINER_NAME="jenkins-app"

# ========================== #
# 📦 Lấy thông tin từ CloudFormation
# ========================== #
SUBNET_1=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnet-1a'].Value" --output text)
SUBNET_2=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnet-1b'].Value" --output text)
SECURITY_GROUP=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-App-Tier-SG-ID'].Value" --output text)
TARGET_GROUP_ARN=$(aws cloudformation list-exports --query "Exports[?Name=='JenkinsApp-TG-ARN'].Value" --output text)
ALB_DNS=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-ALB-DNSName'].Value" --output text)

# ========================== #
# 🛠 Đăng ký Task Definition
# ========================== #
echo "🚀 Registering ECS task definition with image: $DOCKER_IMAGE..."

aws ecs register-task-definition \
  --family "$TASK_DEF_NAME" \
  --requires-compatibilities FARGATE \
  --network-mode awsvpc \
  --cpu "256" \
  --memory "512" \
  --container-definitions "[{
    \"name\": \"$CONTAINER_NAME\",
    \"image\": \"$DOCKER_IMAGE\",
    \"essential\": true,
    \"portMappings\": [{
      \"containerPort\": 80,
      \"protocol\": \"tcp\"
    }]
  }]" \
  --region "$REGION" > /dev/null

echo "✅ Task definition [$TASK_DEF_NAME] registered."

# ========================== #
# 🔐 Mở cổng 80 nếu cần
# ========================== #
echo "🔒 Checking if SG $SECURITY_GROUP allows TCP:80 from 0.0.0.0/0..."
HAS_RULE=$(aws ec2 describe-security-groups \
  --group-ids "$SECURITY_GROUP" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\` && IpRanges[?CidrIp=='0.0.0.0/0']]" \
  --output text)

if [ -z "$HAS_RULE" ]; then
  echo "🛠️  Adding ingress rule for port 80..."
  aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0
  echo "✅ Port 80 opened to 0.0.0.0/0."
else
  echo "✅ Security group already allows port 80 from 0.0.0.0/0."
fi

# ========================== #
# ▶️ Chạy ECS task
# ========================== #
echo "🟢 Running ECS task..."
TASK_ARN=$(aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_1,$SUBNET_2],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
  --task-definition "$TASK_DEF_NAME" \
  --region "$REGION" \
  --query "tasks[0].taskArn" --output text)

echo "⏳ Waiting for task to run..."
aws ecs wait tasks-running --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN"

# ========================== #
# 🌐 Lấy IP và ENI
# ========================== #
ENI_ID=$(aws ecs describe-tasks \
  --cluster "$CLUSTER_NAME" \
  --tasks "$TASK_ARN" \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
  --output text)

PRIVATE_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids "$ENI_ID" \
  --query "NetworkInterfaces[0].PrivateIpAddress" \
  --output text)

PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids "$ENI_ID" \
  --query "NetworkInterfaces[0].Association.PublicIp" \
  --output text)

# ========================== #
# 🔗 Gán vào ALB Target Group
# ========================== #
echo "🔗 Registering private IP $PRIVATE_IP to ALB Target Group..."
aws elbv2 register-targets \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --targets "Id=$PRIVATE_IP,Port=80"
echo "✅ Task registered to ALB."

# ========================== #
# 📢 Kết quả
# ========================== #
echo ""
echo "========================= 🔗 ACCESS LINKS ========================="
echo "🔗 ALB URL:           http://$ALB_DNS"
echo "🔗 Direct Public IP:  http://$PUBLIC_IP"
echo "📦 ECS Task ARN:      $TASK_ARN"
echo "🧩 ENI ID:            $ENI_ID"
echo "=================================================================="
