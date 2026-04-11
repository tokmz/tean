# Team — Go 项目团队协作 Skills

Claude Code 插件，8 角色协同开发体系。支持新项目从零搭建、现有项目功能迭代、bug 修复维护。

## 安装

```bash
claude marketplace add tokmz/team && claude plugin install team@team-skills
```

需要代理：
```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=http://127.0.0.1:7890
claude marketplace add tokmz/team && claude plugin install team@team-skills
```

## 更新

```bash
claude plugin update team@team-skills
```

## 卸载

```bash
claude plugin uninstall team@team-skills
```

## 命令列表

| 命令 | 角色 | 用途 |
|------|------|------|
| `/team` | 调度中心 | 自动判断模式，编排所有角色 |
| `/team:tech-lead` | Tech Lead (P9) | 任务拆解、技术决策、团队编排 |
| `/team:architect` | 架构师 (P8) | 技术选型、系统设计、ADR |
| `/team:backend` | 后端 (P7) | Go API 开发、业务逻辑 |
| `/team:frontend` | 前端 (P7) | React/Vue/Flutter/UniApp UI 开发 |
| `/team:dba` | DBA (P7) | 数据库设计、SQL 优化、索引策略 |
| `/team:reviewer` | 审核员 (P7) | 代码审核、安全审计（OWASP Top 10） |
| `/team:devops` | DevOps (P7) | CI/CD、Docker、K8s 部署 |
| `/team:pm` | PM (P7) | 需求分析、排期、验收 |

## 三种工作模式

### 新项目（从零到交付）
检测到目录无代码时激活。**先问用户想从哪步开始**，不默认跑全流程：

1. 需求分析 → PM 出文档
2. 架构设计 → Architect 出技术选型
3. 数据库设计 → DBA 出表结构
4. 搭建框架 → 目录 + Makefile + CI + Docker
5. 一步到位 → 完整开发到部署

每步可独立交付，做完确认再继续。

### 新功能（现有项目迭代）
检测到目录有代码时激活。**先分析项目现状**（技术栈、架构、编码风格），再拆解任务，不破坏已有代码。

### 维护（修复/优化/重构）
bug 修复、性能优化、代码重构。**先定位问题**，最小改动修复，写回归测试。

## 质量体系

### 三条红线
1. **没有测试不交付** — 核心逻辑没测试的 PR 直接 reject
2. **没有验证不说完成** — 必须 build + test + lint，贴输出证据
3. **没有审核不上线** — 代码必须经 Reviewer 审核

### 质量反馈
每次交付按 4 项打分（编译20+测试30+Lint20+Review30=100）：
- S 级（90-100）：卓越
- A 级（75-89）：优秀
- B 级（60-74）：合格
- C 级（40-59）：需改进
- D 级（0-39）：打回重做

角色表现状态：
- 表现稳定：连续 3 次 A 级以上
- 需要改进：连续 2 次 C 级或 1 次 D 级
- 需要帮扶：连续 2 次 D 级

正向激励为主（80%），适度施压为辅（20%）

### 问责机制
项目整体不行 = Tech Lead + Architect 的问题。Leader 负全局，Architect 负架构。

### 项目记忆
跨会话传递关键决策和踩坑经验，自动存储在 `.claude/memory/team-project.md`：
- 只记 WHY（决策原因），不记 WHAT（代码事实）
- 上限 10 条，带时间戳
- 使用前验证有效性，防幻觉

## 目录结构

```
team/
├── .claude-plugin/
│   ├── plugin.json          # 插件元数据
│   └── marketplace.json     # 市场信息
├── commands/                 # 斜杠命令入口
│   ├── architect.md
│   ├── backend.md
│   ├── dba.md
│   ├── devops.md
│   ├── frontend.md
│   ├── pm.md
│   ├── reviewer.md
│   └── tech-lead.md
├── hooks/                    # 会话钩子
│   ├── hooks.json
│   └── session-restore.sh    # 新会话自动加载团队上下文
├── references/               # 角色详细协议
│   ├── architect.md
│   ├── backend.md
│   ├── dba.md
│   ├── devops.md
│   ├── frontend.md
│   ├── pm.md
│   ├── quality-feedback.md   # 质量反馈循环
│   ├── quality-protocol.md   # 质量红线
│   ├── quality-check.sh      # Go 项目质量检查脚本
│   ├── quality-check-node.sh # Node.js 项目质量检查脚本
│   ├── project-memory.md     # 项目记忆协议
│   ├── reviewer.md
│   ├── tech-lead.md
│   ├── tool-usage-guide.md   # 工具使用决策树
│   └── qi-framework.md       # Qi 框架开发规范
├── skills/                   # Agent Skills
│   ├── team/SKILL.md         # 主入口
│   ├── architect/SKILL.md
│   ├── backend/SKILL.md
│   ├── dba/SKILL.md
│   ├── devops/SKILL.md
│   ├── frontend/SKILL.md
│   ├── pm/SKILL.md
│   ├── reviewer/SKILL.md
│   └── tech-lead/SKILL.md
├── .gitignore
└── README.md
```

## 技术规范

- 后端：Go，分层架构（Handler → Service → Repository → Model）
  - **Qi 框架**（推荐）：统一响应、业务错误、泛型绑定、OpenAPI 自动生成
  - 其他框架：Gin / Echo / Fiber / Chi
- 前端：React / Vue / Flutter / UniApp
- 数据库：表设计规范、索引策略、迁移管理
- 部署：Dockerfile、docker-compose、CI/CD、Makefile
- 安全：OWASP Top 10 安全审计

## License

MIT
