#!/bin/bash

# Script để dọn dẹp một môi trường test.
# Đã được sửa lỗi parsing bằng cách sử dụng jq.
set -e

# Script này nhận vào UNIQUE_IDENTIFIER (ví dụ: main-a1b2c3d)
# Tên file delete_ecs_task.sh có thể gây nhầm lẫn, bạn có thể đổi thành destroy_preview_env.sh
if [ "$#" -ne 1 ]; then
    echo "Sử dụng: $0 <unique-identifier>"
    echo "Ví dụ: bash ./script/delete_ecs_task.sh main-a1b2c3d"
    exit 1
fi

# ========================== #
# 🟡 Biến đầu vào
# ========================== #
UNIQUE_IDENTIFIER="$1"

# ========================== #
# 🟡 Biến cấu hình AWS
# ========================== #
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

echo -e "\n=================================================================="
echo "✅ DỌN DẸP HOÀN TẤT!"
echo "=================================================================="
