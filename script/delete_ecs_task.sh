#!/bin/bash


set -e

if [ "$#" -ne 1 ]; then
    echo "Sử dụng: $0 <unique-identifier>"
    exit 1
fi

UNIQUE_IDENTIFIER="$1"

REGION="us-east-1"
SERVICE_NAME="svc-${UNIQUE_IDENTIFIER}"
TARGET_GROUP_NAME="tg-${UNIQUE_IDENTIFIER:0:28}"
PATH_PATTERN_TO_FIND="/${UNIQUE_IDENTIFIER}/*"

echo "🧹 Bắt đầu dọn dẹp môi trường: $UNIQUE_IDENTIFIER"

# ================================================================= #
# 🚀 BẮT ĐẦU QUÁ TRÌNH DỌN DẸP
# ================================================================= #

# 📦 [1/4] TỰ ĐỘNG TÌM ALB LISTENER ARN
echo "📦 [1/4] Đang tự động tìm ALB Listener ARN..."
ALB_ARN=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-ALB-ARN'].Value" --output text)
ALB_LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query "Listeners[?Port==\`80\`].ListenerArn | [0]" --output text)
CLUSTER_NAME=$(aws cloudformation list-exports --query "Exports[?Name=='Project01-ECS-Cluster-Name'].Value" --output text)

# 🔵 [2/4] XÓA RULE TRÊN ALB
echo "🔵 [2/4] Đang xóa Rule trên ALB cho đường dẫn ${PATH_PATTERN_TO_FIND}..."

# --- PHẦN SỬA LỖI ---
# Lấy toàn bộ các rule dưới dạng JSON và dùng jq để lọc một cách an toàn
RULE_ARN=$(aws elbv2 describe-rules --listener-arn "$ALB_LISTENER_ARN" --output json | \
           jq -r --arg pattern "$PATH_PATTERN_TO_FIND" '.Rules[] | select(.Conditions[0].PathPatternConfig.Values[0] == $pattern) | .RuleArn')

if [ -n "$RULE_ARN" ]; then
    aws elbv2 delete-rule --rule-arn "$RULE_ARN" > /dev/null
    echo "✅ Rule đã được xóa."
else
    echo "🟡 Không tìm thấy Rule."
fi
# --- KẾT THÚC PHẦN SỬA LỖI ---


# 🔵 [3/4] XÓA ECS SERVICE
echo "🔵 [3/4] Đang xóa ECS Service: $SERVICE_NAME"
SERVICE_EXISTS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --query "services[?status!='INACTIVE']" --output text)
if [ -n "$SERVICE_EXISTS" ]; then
    aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --desired-count 0 > /dev/null
    aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME"
    aws ecs delete-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --force > /dev/null
    echo "✅ Service đã được xóa."
else
    echo "🟡 Không tìm thấy Service."
fi

# 🔵 [4/4] XÓA TARGET GROUP
echo "🔵 [4/4] Đang xóa Target Group: $TARGET_GROUP_NAME"
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names "$TARGET_GROUP_NAME" --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")
if [ -n "$TARGET_GROUP_ARN" ]; then
    aws elbv2 delete-target-group --target-group-arn "$TARGET_GROUP_ARN" > /dev/null
    echo "✅ Target Group đã được xóa."
else
    echo "🟡 Không tìm thấy Target Group."
fi

# 🔵 [5/5] HỦY ĐĂNG KÝ TASK DEFINITION
echo "🔵 [5/5] Đang hủy đăng ký các phiên bản Task Definition cho family: task-${UNIQUE_IDENTIFIER}"
# Lấy danh sách tất cả các ARN của các phiên bản trong family này
TASK_DEF_ARNS=$(aws ecs list-task-definitions --family-prefix "task-${UNIQUE_IDENTIFIER}" --status ACTIVE --query "taskDefinitionArns" --output json)

# Lặp qua từng ARN và hủy đăng ký nó
for arn in $(echo "${TASK_DEF_ARNS}" | jq -r '.[]'); do
    echo "  -> Deregistering $arn"
    aws ecs deregister-task-definition --task-definition "$arn" > /dev/null
done
echo "✅ Các Task Definition liên quan đã được chuyển sang trạng thái INACTIVE."

echo -e "\n=================================================================="
echo "✅ DỌN DẸP HOÀN TẤT!"
echo "=================================================================="
