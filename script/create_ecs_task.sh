#!/bin/bash

set -e
if [ "$#" -ne 1 ]; then echo "Sử dụng: $0 <full-docker-image>"; exit 1; fi

DOCKER_IMAGE="$1"
TAG=$(echo "$DOCKER_IMAGE" | cut -d':' -f2)
UNIQUE_IDENTIFIER=$(echo "$TAG" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')

echo "🧠 Phân tích: Định danh duy nhất là '$UNIQUE_IDENTIFIER'"

REGION="us-east-1"
SERVICE_NAME="svc-${UNIQUE_IDENTIFIER}"
TASK_DEF_FAMILY="task-${UNIQUE_IDENTIFIER}"
TARGET_GROUP_NAME="tg-${UNIQUE_IDENTIFIER:0:28}"
PATH_PATTERN="/${UNIQUE_IDENTIFIER}/*"
CONTAINER_PORT=80

echo "📦 Đang lấy thông tin hạ tầng từ CloudFormation..."
ALB_DNS_NAME=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-ALB-DNSName'].Value" --output text)
ALB_LISTENER_ARN=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-ALB-Listener-ARN'].Value" --output text)
CLUSTER_NAME=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-ECS-Cluster-Name'].Value" --output text)
EXECUTION_ROLE_ARN=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-ECSTaskExecutionRole-ARN'].Value" --output text)
VPC_ID=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-VPC-ID'].Value" --output text)
SUBNETS=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-Public-Subnets'].Value" --output text)
SECURITY_GROUP=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-App-Tier-SG-ID'].Value" --output text)

echo "🔵 [1/5] Đang tạo Target Group: $TARGET_GROUP_NAME"
TARGET_GROUP_ARN=$(aws elbv2 create-target-group --name "$TARGET_GROUP_NAME" --protocol HTTP --port $CONTAINER_PORT --vpc-id "$VPC_ID" --health-check-path / --target-type ip --region "$REGION" --query "TargetGroups[0].TargetGroupArn" --output text)

echo "🔵 [2/5] Đang đăng ký Task Definition: $TASK_DEF_FAMILY"
TASK_DEF_ARN=$(aws ecs register-task-definition --family "$TASK_DEF_FAMILY" --requires-compatibilities FARGATE --network-mode awsvpc --cpu "256" --memory "512" --execution-role-arn "$EXECUTION_ROLE_ARN" --container-definitions "[{\"name\": \"${SERVICE_NAME}\", \"image\": \"$DOCKER_IMAGE\", \"essential\": true, \"environment\": [{\"name\": \"BASE_PATH\", \"value\": \"/${UNIQUE_IDENTIFIER}\"}], \"portMappings\": [{\"containerPort\": $CONTAINER_PORT, \"protocol\": \"tcp\"}]}]" --region "$REGION" --query "taskDefinition.taskDefinitionArn" --output text)

echo "🔵 [3/5] Đang tạo Rule trên ALB cho đường dẫn: $PATH_PATTERN"
NEXT_PRIORITY=$(aws elbv2 describe-rules --listener-arn "$ALB_LISTENER_ARN" --query "Rules[?Priority!='default'].Priority" --output json | jq '[.[] | tonumber] | max + 1 // 1')
aws elbv2 create-rule --listener-arn "$ALB_LISTENER_ARN" --priority "$NEXT_PRIORITY" --conditions "Field=path-pattern,Values=['${PATH_PATTERN}']" --actions "Type=forward,TargetGroupArn=${TARGET_GROUP_ARN}" --region "$REGION" > /dev/null

echo "🔵 [4/5] Đang tạo ECS Service: $SERVICE_NAME"
aws ecs create-service --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --task-definition "$TASK_DEF_ARN" --desired-count 1 --launch-type FARGATE --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" --load-balancers "targetGroupArn=${TARGET_GROUP_ARN},containerName=${SERVICE_NAME},containerPort=${CONTAINER_PORT}" --region "$REGION" > /dev/null

echo "🔵 [5/5] Đang chờ Service ổn định..."
aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME"

FINAL_URL="http://${ALB_DNS_NAME}/${UNIQUE_IDENTIFIER}/"
echo -e "\n=================================================================="
echo "✅ TRIỂN KHAI THÀNH CÔNG!"
echo "🔗 URL để test: $FINAL_URL"
echo "=================================================================="
