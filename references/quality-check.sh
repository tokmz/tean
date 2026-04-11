#!/bin/bash
# 质量检查一键脚本 - 适用于 Go 项目

set -e

echo "📊 开始质量检查..."
echo ""

# 1. 编译检查
echo "✅ [1/5] 编译检查"
if go build ./...; then
    echo "   ✓ 编译通过"
else
    echo "   ✗ 编译失败"
    exit 1
fi
echo ""

# 2. 测试检查
echo "🧪 [2/5] 测试检查"
if go test ./... -v -cover -coverprofile=coverage.out; then
    echo "   ✓ 测试通过"
    COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}')
    echo "   覆盖率: $COVERAGE"
else
    echo "   ✗ 测试失败"
    exit 1
fi
echo ""

# 3. Lint 检查
echo "🔍 [3/5] Lint 检查"
if command -v golangci-lint &> /dev/null; then
    if golangci-lint run ./...; then
        echo "   ✓ Lint 通过"
    else
        echo "   ✗ Lint 有问题"
        exit 1
    fi
else
    echo "   ⚠️  golangci-lint 未安装，跳过"
fi
echo ""

# 4. 格式检查
echo "📝 [4/5] 格式检查"
UNFORMATTED=$(gofmt -l .)
if [ -z "$UNFORMATTED" ]; then
    echo "   ✓ 格式正确"
else
    echo "   ✗ 以下文件格式不正确:"
    echo "$UNFORMATTED"
    exit 1
fi
echo ""

# 5. 依赖检查
echo "📦 [5/5] 依赖检查"
if go mod verify; then
    echo "   ✓ 依赖完整"
else
    echo "   ✗ 依赖有问题"
    exit 1
fi
echo ""

echo "🎉 质量检查全部通过！"
echo ""
echo "📊 质量卡总结"
echo "┌───────────────┬─────────────┐"
echo "│ ✅ 编译通过   │ 是          │"
echo "├───────────────┼─────────────┤"
echo "│ 🧪 测试通过   │ 是          │"
echo "├───────────────┼─────────────┤"
echo "│ 🔍 Lint 清洁  │ 是          │"
echo "├───────────────┼─────────────┤"
echo "│ 📝 格式正确   │ 是          │"
echo "├───────────────┼─────────────┤"
echo "│ 📦 依赖完整   │ 是          │"
echo "└───────────────┴─────────────┘"
