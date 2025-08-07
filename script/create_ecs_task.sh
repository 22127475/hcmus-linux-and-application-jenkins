#!/bin/bash

# Script để tạo một môi trường test sử dụng Path-based routing.
set -e

# Kiểm tra đủ tham số đầu vào
if [ "$#" -ne 1 ]; then
    echo "Sử dụng: $0 <full-docker-image>"
    exit 1
fi

# ========================== #
# 🟡 Biến đầu vào từ Jenkins
# ========================== #
DOCKER_IMAGE="$1"

# ========================== #
# 🧠 PHÂN TÍCH DOCKER IMAGE TAG
# ========================== #
echo "🧠 Parsing Docker image tag..."
TAG=$(echo "$DOCKER_IMAGE" | cut -d':' -f2)
UNIQUE_IDENTIFIER=$(echo "$TAG" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
echo "  -> Unique Identifier for AWS: $UNIQUE_IDENTIFIER"

# ========================== #
# 🟡 Biến cấu hình AWS
# ========================== #
REGION="us-east-1"
CLUSTER_NAME="linux-and-application"
SERVICE_NAME="svc-${UNIQUE_IDENTIFIER}"
TASK_DEF_FAMILY="task-${UNIQUE_IDENTIFIER}"
TARGET_GROUP_NAME="tg-${UNIQUE_IDENTIFIER:0:28}"
PATH_PATTERN="/${UNIQUE_IDENTIFIER}/*"
CONTAINER_PORT=80

# ================================================================= #
# 🚀 BẮT ĐẦU QUÁ TRÌNH TẠO MÔI TRƯỜNG
# ================================================================= #

# 📦 [1/6] Lấy thông tin hạ tầng tĩnh
echo "📦 [1/6] Fetching infrastructure details..."
ALB_ARN=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-ALB-ARN'].Value" --output text)
ALB_DNS_NAME=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-ALB-DNSName'].Value" --output text)
ALB_LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query "Listeners[?Port==\`80\`].ListenerArn | [0]" --output text)
VPC_ID=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-VPC-ID'].Value" --output text)
SUBNETS=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnets'].Value" --output text)
SECURITY_GROUP=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-App-Tier-SG-ID'].Value" --output text)
EXECUTION_ROLE_ARN=$(aws iam get-role --role-name ECSTaskExecutionRole --query "Role.Arn" --output text)

# 🔵 [2/6] TẠO TARGET GROUP
echo "🔵 [2/6] Creating Target Group: $TARGET_GROUP_NAME"
TARGET_GROUP_ARN=$(aws elbv2 create-target-group --name "$TARGET_GROUP_NAME" --protocol HTTP --port $CONTAINER_PORT --vpc-id "$VPC_ID" --health-check-protocol HTTP --health-check-path / --target-type ip --region "$REGION" --query "TargetGroups[0].TargetGroupArn" --output text)
echo "✅ Target Group created: $TARGET_GROUP_ARN"

# 🔵 [3/6] ĐĂNG KÝ TASK DEFINITION
echo "🔵 [3/6] Registering Task Definition: $TASK_DEF_FAMILY"
TASK_DEF_ARN=$(aws ecs register-task-definition --family "$TASK_DEF_FAMILY" --requires-compatibilities FARGATE --network-mode awsvpc --cpu "256" --memory "512" --execution-role-arn "$EXECUTION_ROLE_ARN" --container-definitions "[{\"name\": \"${SERVICE_NAME}\", \"image\": \"$DOCKER_IMAGE\", \"essential\": true, \"portMappings\": [{\"containerPort\": $CONTAINER_PORT, \"protocol\": \"tcp\"}]}]" --region "$REGION" --query "taskDefinition.taskDefinitionArn" --output text)
echo "✅ Task Definition registered: $TASK_DEF_ARN"

# 🔵 [4/6] TẠO RULE TRÊN ALB
# THAY ĐỔI LỚN: Điều kiện bây giờ là 'path-pattern' thay vì 'host-header'
echo "🔵 [4/6] Creating ALB Rule for path: $PATH_PATTERN"
NEXT_PRIORITY=$(aws elbv2 describe-rules --listener-arn "$ALB_LISTENER_ARN" --query "Rules[?Priority!='default'].Priority" --output json | jq '[.[] | tonumber] | max + 1 // 1')
aws elbv2 create-rule \
  --listener-arn "$ALB_LISTENER_ARN" \
  --priority "$NEXT_PRIORITY" \
  --conditions "Field=path-pattern,Values=['${PATH_PATTERN}']" \
  --actions "Type=forward,TargetGroupArn=${TARGET_GROUP_ARN}" \
  --region "$REGION" > /dev/null
echo "✅ ALB Rule created with priority $NEXT_PRIORITY"

# 🔵 [5/6] TẠO VÀ CHỜ ECS SERVICE
echo "🔵 [5/6] Creating and waiting for ECS Service: $SERVICE_NAME"
aws ecs create-service --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --task-definition "$TASK_DEF_ARN" --desired-count 1 --launch-type FARGATE --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" --load-balancers "targetGroupArn=${TARGET_GROUP_ARN},containerName=${SERVICE_NAME},containerPort=${CONTAINER_PORT}" --region "$REGION" > /dev/null
aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME"

# ========================== #
# 📢 KẾT QUẢ
# ========================== #
# THAY ĐỔI: Xây dựng URL cuối cùng từ DNS của ALB và đường dẫn
FINAL_URL="http://${ALB_DNS_NAME}/${UNIQUE_IDENTIFIER}/"
echo ""
echo "=================================================================="
echo "✅ DEPLOYMENT SUCCESSFUL! Environment is ready."
echo "🔗 Your unique test URL is: $FINAL_URL"
echo "=================================================================="
