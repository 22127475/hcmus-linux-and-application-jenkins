#!/bin/bash

set -e
if [ "$#" -ne 1 ]; then echo "Sử dụng: $0 <unique-identifier>"; exit 1; fi

UNIQUE_IDENTIFIER="$1"
REGION="us-east-1"
SERVICE_NAME="svc-${UNIQUE_IDENTIFIER}"
TARGET_GROUP_NAME="tg-${UNIQUE_IDENTIFIER:0:28}"
PATH_PATTERN_TO_FIND="/${UNIQUE_IDENTIFIER}/*"

echo "🧹 Bắt đầu dọn dẹp môi trường: $UNIQUE_IDENTIFIER"

echo "📦 Đang lấy thông tin hạ tầng từ CloudFormation..."
ALB_LISTENER_ARN=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-ALB-Listener-ARN'].Value" --output text)
CLUSTER_NAME=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-ECS-Cluster-Name'].Value" --output text)

echo "🔵 [1/3] Đang xóa Rule trên ALB cho đường dẫn ${PATH_PATTERN_TO_FIND}..."
RULE_ARN=$(aws elbv2 describe-rules --listener-arn "$ALB_LISTENER_ARN" --query "Rules[?Conditions[0].PathPatternConfig.Values[0]=='${PATH_PATTERN_TO_FIND}']].RuleArn" --output text)
if [ -n "$RULE_ARN" ]; then aws elbv2 delete-rule --rule-arn "$RULE_ARN" > /dev/null; echo "✅ Rule đã được xóa."; else echo "🟡 Không tìm thấy Rule."; fi

echo "🔵 [2/3] Đang xóa ECS Service: $SERVICE_NAME"
SERVICE_EXISTS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --query "services[?status!='INACTIVE']" --output text)
if [ -n "$SERVICE_EXISTS" ]; then aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --desired-count 0 > /dev/null; aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME"; aws ecs delete-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --force > /dev/null; echo "✅ Service đã được xóa."; else echo "🟡 Không tìm thấy Service."; fi

echo "🔵 [3/3] Đang xóa Target Group: $TARGET_GROUP_NAME"
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names "$TARGET_GROUP_NAME" --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")
if [ -n "$TARGET_GROUP_ARN" ]; then aws elbv2 delete-target-group --target-group-arn "$TARGET_GROUP_ARN" > /dev/null; echo "✅ Target Group đã được xóa."; else echo "🟡 Không tìm thấy Target Group."; fi

echo -e "\n=================================================================="
echo "✅ DỌN DẸP HOÀN TẤT!"
echo "=================================================================="
