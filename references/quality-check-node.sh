#!/bin/bash
# 质量检查一键脚本 - 适用于 Node.js/TypeScript 项目

set -e

echo "📊 开始质量检查..."
echo ""

# 1. 依赖安装检查
echo "📦 [1/5] 依赖检查"
if [ ! -d "node_modules" ]; then
    echo "   ⚠️  node_modules 不存在，正在安装..."
    npm install
fi
echo "   ✓ 依赖完整"
echo ""

# 2. 编译检查
echo "✅ [2/5] 编译检查"
if npm run build; then
    echo "   ✓ 编译通过"
else
    echo "   ✗ 编译失败"
    exit 1
fi
echo ""

# 3. 测试检查
echo "🧪 [3/5] 测试检查"
if npm test -- --coverage; then
    echo "   ✓ 测试通过"
else
    echo "   ✗ 测试失败"
    exit 1
fi
echo ""

# 4. Lint 检查
echo "🔍 [4/5] Lint 检查"
if npm run lint; then
    echo "   ✓ Lint 通过"
else
    echo "   ✗ Lint 有问题"
    exit 1
fi
echo ""

# 5. 类型检查（如果是 TypeScript）
echo "📝 [5/5] 类型检查"
if [ -f "tsconfig.json" ]; then
    if npx tsc --noEmit; then
        echo "   ✓ 类型检查通过"
    else
        echo "   ✗ 类型检查失败"
        exit 1
    fi
else
    echo "   ⚠️  非 TypeScript 项目，跳过"
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
echo "│ 📝 类型正确   │ 是          │"
echo "├───────────────┼─────────────┤"
echo "│ 📦 依赖完整   │ 是          │"
echo "└───────────────┴─────────────┘"
