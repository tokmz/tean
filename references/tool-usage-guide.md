---
name: team:tool-usage
description: 工具使用决策树 — 为不同场景选择最高效的工具组合
---

# 工具使用决策树

AI 在执行任务时，选择正确的工具组合可以大幅提升效率。本指南提供明确的决策规则。

## 核心原则

1. **能并行就并行** — 无依赖的工具调用在同一消息中发起
2. **先快后慢** — 先用快速工具缩小范围，再用精确工具定位
3. **避免重复读取** — 同一文件在一次对话中只读一次，记住内容

## 场景决策树

### 场景 1：查找文件

| 需求 | 工具 | 示例 |
|------|------|------|
| 找所有某类型文件 | Glob | `Glob({pattern: "**/*.go"})` |
| 找特定名称的文件 | Glob | `Glob({pattern: "**/user_handler.go"})` |
| 找包含某关键字的文件 | Grep | `Grep({pattern: "UserService", output_mode: "files_with_matches"})` |

**效率对比**：
- Glob 查找文件名：< 1s
- Grep 查找内容：1-3s
- 遍历目录 + Read：> 10s（禁止）

### 场景 2：理解代码结构

| 需求 | 工具组合 | 说明 |
|------|---------|------|
| 了解项目整体结构 | Glob → Read 关键文件 | 先 Glob 看文件列表，再 Read go.mod/package.json |
| 找某个功能的实现 | Grep → Read | 先 Grep 找到文件，再 Read 具体实现 |
| 理解分层架构 | Grep 多个模式 | `Grep "func.*Handler"` + `Grep "func.*Service"` |
| 找函数定义位置 | LSP goToDefinition | 精确定位，比 Grep 更准确 |

### 场景 3：修改代码

| 需求 | 工具组合 | 说明 |
|------|---------|------|
| 修改已知文件 | Read → Edit | 先 Read 确认内容，再 Edit 精确替换 |
| 批量重命名符号 | LSP findReferences → Edit | 找到所有引用，逐个修改 |
| 检查修改影响 | LSP findReferences | 改函数签名前必须用 LSP 找引用 |
| 删除未使用代码 | LSP findReferences | 确认无引用再删除 |

### 场景 4：项目分析

| 阶段 | 工具组合 | 并行策略 |
|------|---------|---------|
| 识别技术栈 | Read go.mod + Read package.json | 并行读取 |
| 分析目录结构 | Glob "**/*.go" + Glob "**/*.ts" | 并行 Glob |
| 提取编码规范 | Grep 多个模式 | 串行（需要根据前面结果调整） |
| 理解数据模型 | Grep "type.*struct" → Read 具体文件 | 先 Grep 后 Read |

### 场景 5：调试问题

| 需求 | 工具组合 | 说明 |
|------|---------|------|
| 找错误日志来源 | Grep 错误信息 | 搜索错误字符串定位代码 |
| 追踪函数调用链 | LSP findReferences | 找谁调用了这个函数 |
| 检查配置项 | Grep 配置键名 | 找所有使用该配置的地方 |
| 定位性能瓶颈 | Grep "time.Sleep\|SELECT.*FROM" | 找可疑的慢操作 |

## 工具特性对比

| 工具 | 速度 | 精度 | 适用场景 | 限制 |
|------|------|------|---------|------|
| Glob | ⚡️⚡️⚡️ | 文件名精确 | 找文件 | 只能匹配文件名 |
| Grep | ⚡️⚡️ | 内容模糊 | 找关键字、模式 | 不理解语法 |
| LSP | ⚡️ | 语义精确 | 找定义、引用 | 需要语言服务器支持 |
| Read | ⚡️ | 完整内容 | 读文件详细内容 | 一次只能读一个文件 |
| Edit | ⚡️ | 精确替换 | 修改文件 | 需要先 Read |

## 反模式（禁止）

❌ **遍历目录读取所有文件**
```
# 错误示例
Glob "**/*.go" → 对每个文件 Read
```
正确做法：先 Grep 缩小范围，再 Read 关键文件

❌ **用 Bash 代替专用工具**
```
# 错误示例
Bash "find . -name '*.go'"
```
正确做法：用 Glob

❌ **重复读取同一文件**
```
# 错误示例
Read user.go → Edit user.go → Read user.go 验证
```
正确做法：Read 一次，记住内容，Edit 后信任结果

❌ **串行执行无依赖的查询**
```
# 错误示例
Read go.mod → 等待 → Read package.json
```
正确做法：并行读取

## 最佳实践

### 1. 项目分析的高效模式

```
# 第一轮：并行获取基础信息
Read go.mod
Read package.json  
Read Makefile
Glob "**/*.go"

# 第二轮：根据第一轮结果精确查询
Grep "func.*Handler" (如果是 Go 项目)
Grep "export.*function" (如果是 TS 项目)

# 第三轮：读取关键文件细节
Read {从 Grep 结果中选择的关键文件}
```

### 2. 代码修改的安全模式

```
# 1. 先找到要改的位置
Grep "UserService"

# 2. 读取完整上下文
Read {Grep 找到的文件}

# 3. 检查影响范围
LSP findReferences (如果改函数签名)

# 4. 执行修改
Edit {精确的 old_string 和 new_string}

# 5. 验证（不需要重新 Read）
Bash "go build" 或 "npm run build"
```

### 3. 并行查询的模板

```
# 场景：分析 Go 项目的分层架构
在同一消息中发起：

Grep({pattern: "func.*Handler", output_mode: "files_with_matches"})
Grep({pattern: "func.*Service", output_mode: "files_with_matches"})
Grep({pattern: "func.*Repository", output_mode: "files_with_matches"})
Grep({pattern: "type.*struct.*gorm", output_mode: "files_with_matches"})

# 等所有结果返回后，再决定读取哪些文件
```

## 性能优化建议

1. **减少工具调用次数**
   - 用 Grep 的 context 参数一次获取上下文，而不是 Grep + Read
   - 用 Glob 的通配符一次匹配多种文件，而不是多次 Glob

2. **利用缓存**
   - 同一文件在对话中只 Read 一次
   - Grep 结果记住，不要重复搜索

3. **批量操作**
   - 多个独立查询用并行
   - 多个文件修改在同一阶段完成

4. **提前规划**
   - 在开始前想清楚需要哪些信息
   - 一次性获取所有需要的数据，避免来回查询
