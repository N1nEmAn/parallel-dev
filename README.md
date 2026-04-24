# Parallel-Dev

> Multi-Agent Parallel Development Framework for Claude Code / OMC

基于 **几千美金 Token 换来的并行开发经验** 沉淀出的 Claude Code Skill 框架。

**想法来源：** [我用几千美金token换来的并行开发经验：一群Agent一起帮你写代码](https://mp.weixin.qq.com/s/9ZMGAo0-06C7FcSOmWtG5w)

---

## 简介

Parallel-Dev 是一个让多个 AI Agent **并行推进不同开发任务** 的框架，同时保证产出质量不崩塌。

核心思路：**减少每个 Agent 需要人类介入的次数**。只有当单个 Agent 能在较少监督下独立完成高质量工作，并行才有意义。

- **人是技术负责人，不是 pair programmer** —— 你定方向、审测试计划、关键节点 spot-check，编码/测试/debug 由 Agent 自主完成。
- **Lead 自动路由，用户只拍板** —— 分析、分解、调度由 Lead Agent 做；你在关键决策点（并行模式、方案选择）一句话确认或修改。
- **需求对齐不可并行** —— 这是唯一必须消耗你深度注意力的环节；对齐完成后，开发执行才可以齐发。

---

## 三把钥匙

| 瓶颈 | 解法 | 文件 |
|------|------|------|
| 需求传递 | 需求对齐（穷尽式追问 / 方案生成+筛选）| `auto-req.md` |
| 功能正确性 | 测试计划驱动开发（TPDD）| `auto-dev.md` Part 1 |
| 可维护性 | 工程纪律注入（八大原则）| `auto-dev.md` Part 2 |

附加：
- **模拟真实用户测试** —— 多角色（新手/熟手/对抗性）`auto-test.md`
- **产出消化框架** —— 预留设计 `auto-triage.md`

---

## 安装

### 方式一：Claude Code 插件市场（推荐）

如果你使用 Claude Code（含 OMC 环境），直接通过插件市场安装：

```bash
# 添加市场源（只需一次）
# 如果 SSH 报错，改用下面的 HTTPS 方式
claude plugins marketplace add N1nEmAn/parallel-dev

# 或明确用 HTTPS（推荐，公共仓库免 SSH 配置）
claude plugins marketplace add https://github.com/N1nEmAn/parallel-dev

# 安装插件
claude plugins install parallel-dev

# 重启 Claude Code 生效
```

### 方式二：一键脚本

```bash
git clone https://github.com/N1nEmAn/parallel-dev.git
bash parallel-dev/install.sh
```

### 方式三：零终端安装（让 Claude 自己装）

完全不用离开 Claude Code 对话界面：

```
帮我安装 parallel-dev skill
```

Claude 会自动执行：
1. `claude plugins marketplace add github:N1nEmAn/parallel-dev`
2. `claude plugins install parallel-dev`
3. 提示你重启 Claude Code 生效

或者如果你不想用插件市场：

```
帮我克隆 https://github.com/N1nEmAn/parallel-dev.git 并安装到 skills 目录
```

Claude 会自己跑 `git clone` + `bash install.sh`。

### 方式四：手动复制

```bash
# 克隆到本地
git clone https://github.com/N1nEmAn/parallel-dev.git

# 复制到 Claude Code skills 目录
mkdir -p ~/.claude/skills/parallel-dev
cp parallel-dev/SKILL.md parallel-dev/auto-*.md ~/.claude/skills/parallel-dev/

# 刷新 Claude Code 技能缓存（如有必要）
```

### 前提条件

- [Claude Code](https://github.com/anthropics/claude-code) 或支持 Skill 机制的 AI 编程工具
- 推荐配合 [oh-my-claudecode (OMC)](https://github.com/oh-my-claudecode) 使用，获得完整的多 Agent 编排能力

---

## 使用

安装后，在 Claude Code 中调用：

```bash
# 模糊需求 → 自动走完整流程（需求对齐 → TPDD → 审核 → 并行开发）
/parallel-dev "实现一个订单导出功能，支持 CSV 和 Excel，能处理 10 万条记录"

# 明确小任务 → 极简路径（跳需求对齐和测试计划）
/parallel-dev "把 config.py 里的 hardcoded API key 改成从环境变量读取"

# 显式指定并行模式
/parallel-dev --mode=worktree "用两种方案实现缓存层：Redis vs 本地内存，跑完测试择优合并"

# 已有需求文档 → 跳过 Phase 1
/parallel-dev "基于 docs/requirements/auth-v2.md 实现登录模块"
```

### 执行流程

调用后，Lead Agent 自动执行以下 7 个 Phase：

1. **Parse & Classify** —— 自动判断需求类型、复杂度、推荐并行模式
2. **需求对齐** —— 模糊需求自动进入对齐流程，产出结构化需求文档
3. **测试计划生成** —— 基于需求产出单元/集成/E2E 测试计划（TPDD）
4. **独立审核** —— 强制由另一 Agent 审核测试计划，防止偏差污染
5. **并行模式确认与执行** —— 推荐模式，用户确认后 spawn Worker Agents
6. **验证闭环** —— 各 Agent 自主跑测试、debug、修复
7. **产出聚合** —— 输出 YAML 结构化摘要

---

## 文件结构

```
parallel-dev/
├── SKILL.md          # 主 Skill 文件：自动路由执行协议
├── auto-req.md       # 需求对齐 Prompt 模板
├── auto-dev.md       # TPDD 流程 + 工程纪律八大原则 + 自审查清单
├── auto-test.md      # 多角色模拟用户测试 Prompt
├── auto-triage.md    # 产出消化框架（实验性）
├── README.md         # 本文件
├── LICENSE           # MIT License
└── install.sh        # 一键安装脚本
```

---

## 并行模式

| 模式 | 名称 | 适用场景 |
|------|------|---------|
| `none` | 单 Agent 串行 | 简单任务（< 30 行改动）|
| `cross-module` | 跨模块并行 | 多个独立模块/项目同时推进 |
| `worktree` | worktree 隔离 | 同一项目多方向，或多方案择优合并 |
| `cross-concern` | 交叉并行 | 同一功能内，后端测试 + UI 测试 + Bug 修复并发 |

---

## 与其他 Skill 配合

- **gateway** —— 作为入口路由，将开发任务自动分发给 parallel-dev
- **team** —— 大规模多 Agent 协调，parallel-dev 可作为 team 的执行子框架
- **codex / gemini** —— Worker Agent 内部可路由到不同 CLI 执行特定子任务

---

## 注意事项

1. **需求对齐阶段不可并行** —— 这部分必须消耗你的深度注意力，装弹要专注，射击才能齐发。
2. **从两个 Agent 开始** —— 不要一上来就五六个。初学者舒适上限 3–4 个；熟练后可到 6–8 个。
3. **Agent 必须能动手** —— TPDD 成立的前提是 Agent 有真正的操作环境（shell、测试框架、browser/GUI），不是只给源代码。

---

## License

MIT License — 自由使用、修改、分发。

---

## 致谢

- 框架核心思想来自 [A7um / zero-review](https://github.com/A7um/zero-review) 的并行开发实践
- 原文：[我用几千美金token换来的并行开发经验：一群Agent一起帮你写代码](https://mp.weixin.qq.com/s/9ZMGAo0-06C7FcSOmWtG5w)
- 适配于 [oh-my-claudecode](https://github.com/oh-my-claudecode) 多 Agent 编排生态
