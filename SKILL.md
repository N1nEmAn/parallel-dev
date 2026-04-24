---
name: parallel-dev
description: Parallel AI development framework — auto-routes through req-alignment, TPDD, engineering discipline, and concurrency patterns based on task classification.
argument-hint: "[--mode=auto|1|2|3|none] <task description or req-doc path>"
aliases: [pdev]
level: 5
---

# Parallel-Dev — 多 Agent 并行开发框架（自动路由版）

调用时，Claude 作为 **Lead Agent** 自动分析任务、选择路径、spawn 子 Agent 执行，无需用户手动挑选 prompt 模板。

## 设计哲学

- **Lead 自动路由，用户只拍板** —— 分析、分解、调度由 Lead 做；用户在关键决策点（并行模式、方案选择）一句话确认或修改。
- **人是技术负责人，不是 pair programmer** —— 你定方向、审测试计划、关键节点 spot-check，编码/测试/debug 由 Agent 自主完成。
- **需求对齐不可并行** —— 这是唯一必须消耗你深度注意力的环节；对齐完成后，开发执行才可以齐发。

## 零终端安装（用户在 Claude Code 对话中直接说）

如果本 skill 尚未安装，用户无需离开 Claude Code：

```
用户：帮我安装 parallel-dev
Claude（自动执行）：
  1. Bash: claude plugins marketplace add github:N1nEmAn/parallel-dev
  2. Bash: claude plugins install parallel-dev
  3. 提示用户重启 Claude Code 后使用 /parallel-dev
```

或不用插件市场：
```
用户：帮我克隆 https://github.com/N1nEmAn/parallel-dev.git 并安装到 skills 目录
Claude（自动执行）：
  1. Bash: git clone https://github.com/N1nEmAn/parallel-dev.git /tmp/parallel-dev
  2. Bash: bash /tmp/parallel-dev/install.sh
```

---

## Execution Protocol

When invoked, Claude MUST follow this workflow. Do not ask the user "what do you want to do first" — analyze and decide automatically.

### Phase 0: Parse & Classify

读取用户输入，判断以下维度：

**输入类型判断：**
| 特征 | 类型 | 处理 |
|------|------|------|
| 包含"功能范围、验收标准、边界条件"等结构化章节 | 结构化需求文档 | Phase 1 SKIP |
| 已有测试计划 + 需求文档一起传入 | 完整规格包 | Phase 1-2 SKIP，进入审核 |
| "把 X 改成 Y" / "修复 Z" / "重构 W"，范围明确 | 纯开发指令 | Phase 1-2 SKIP，极简路径 |
| 其他自然语言描述，验收标准未明确 | 模糊需求 | 触发 Phase 1 |

**复杂度判断：**
- **简单**：单函数修改、配置变更、小重构（预期 < 30 行改动）
- **中等**：单功能开发（1-3 个模块交互，有明确输入输出）
- **复杂**：多模块重构、架构决策、新系统搭建、跨服务协调

**并行模式推荐（自动判断，Phase 4 向用户确认）：**
| 条件 | 推荐模式 | 说明 |
|------|---------|------|
| 简单任务 | `none` | 单 Agent 串行，不并行 |
| 中等任务 + 涉及前后端/UI 交互 | `cross-concern` | 模式三：后端测试、UI 测试、bug 修复并行 |
| 复杂任务 + 多个独立方向/方案 | `worktree` | 模式二：git worktree 隔离，多方向并行 |
| 多个独立模块/项目 | `cross-module` | 模式一：模块级并行 |
| 用户显式 `--mode=X` | 按用户指定 | 覆盖自动判断 |

**状态初始化：**

```
state_write(mode="parallel-dev", active=true, current_phase="p0-classify", state={
  "task_slug": "<derived-from-task>",
  "input_type": "fuzzy|structured|dev-only|full-spec",
  "complexity": "simple|medium|complex",
  "recommended_mode": "none|cross-module|worktree|cross-concern",
  "user_confirmed_mode": null,
  "phase_history": "p0-classify",
  "artifacts": []
})
```

### Phase 1: 需求对齐（条件触发）

**如果 input_type = fuzzy：**
1. 读取 `auto-req.md`
2. 自动选择追问模式：
   - 如果用户明确说"你定" / "按最佳实践来" / 需求明显是外围功能 → 使用 **模式 B（方案生成+筛选）**
   - 否则默认使用 **模式 A（穷尽式追问）**
3. Lead 自己执行需求对齐对话（因为需要与用户直接交互），按 auto-req.md 模板引导用户
4. 产出结构化需求文档，保存到 `.omc/parallel-dev/req-<task-slug>.md`
5. 更新状态：`current_phase="p1-req-done"`

**如果 input_type = structured / full-spec：**
- 直接使用传入的需求文档，标记 Phase 1 SKIP
- 如有必要，向用户确认"需求文档中的以下点我理解对吗？"（3 个关键假设）

**如果 input_type = dev-only：**
- 标记 Phase 1 SKIP，极简路径进入 Phase 4（单 Agent 开发）

### Phase 2: 测试计划生成（TPDD，条件触发）

**如果 input_type ≠ dev-only：**
1. 读取 `auto-dev.md` 的 Phase 1 Prompt
2. Lead 基于需求文档生成测试计划（因为 Lead 持有完整上下文，效率最高）
3. 保存到 `.omc/parallel-dev/testplan-<task-slug>.md`
4. 更新状态：`current_phase="p2-testplan-done"`

**如果 input_type = dev-only：**
- 标记 Phase 2 SKIP

### Phase 3: 独立审核（强制，条件触发）

**如果 input_type ≠ dev-only：**
1. 读取 `auto-dev.md` 的独立审核 Prompt
2. Spawn 一个全新的 `verifier` 或 `code-reviewer` Agent（**必须新会话**，不给实现上下文）
3. 传递内容：需求文档 + 测试计划（**不传递代码库路径、不传递已有实现**）
4. 等待审核结果
5. **审核结果处理：**
   - 通过（无 Critical/High）→ 进入 Phase 4
   - 有 Critical/High → **暂停执行**，向用户汇报问题清单，等待修复指令
   - 有 Medium/Low → Lead 自行判断是否能快速修复；能则修完再审一次，不能则升级给用户
6. 更新状态：`current_phase="p3-review-done"`

### Phase 4: 并行模式确认与执行

1. 向用户报告自动推荐的并行模式及理由：
   ```
   【并行模式推荐】
   任务复杂度：<simple/medium/complex>
   推荐模式：<模式名称>
   理由：<一句话>
   预计 Agent 数量：<N>

   确认按此执行？（直接回车确认 / 回复模式名修改 / 回复"不并行"）
   ```
2. 根据用户确认的模式执行：

#### Mode: none（单 Agent 串行）

```
Spawn 1 × executor Agent
Prompt: [auto-dev.md Phase 3-4 开发 Prompt] + 需求文档 + 测试计划 + [auto-dev.md 工程纪律]
Agent 自主完成：架构设计 → 编码 → 跑测试 → debug → 修复 → 自审查
```

#### Mode: cross-module（模式一：跨模块并行）

```
1. Lead 将任务拆分为 N 个模块级子任务（文件/模块级，重叠度 < 20%）
2. 对每个子任务 spawn executor Agent
3. 各 Agent 独立加载 auto-dev.md 工程纪律 + TPDD 开发 Prompt
4. 各 Agent 独立执行开发-测试闭环
```

#### Mode: worktree（模式二：worktree 隔离并行）

```
1. Lead 判断需要几个方向/方案（默认 1 个需求 = 1 个方向；如需多方案择优，说明理由）
2. git worktree add ../<branch-name>-<dir> <branch>
3. 对每个 worktree spawn executor Agent，指定工作目录
4. 各 Agent 独立开发
5. 完成后 Lead 对比产出，向用户汇报择优建议，或自动合并冲突
```

#### Mode: cross-concern（模式三：交叉并行）

```
1. Lead 将同一功能拆分为不同事务类型：
   - Agent A：后端逻辑 + 单元/集成测试（auto-dev.md TPDD）
   - Agent B：UI 端到端测试（auto-test.md 多角色测试）
   - Agent C：已知 bug 修复 / 文档更新（如适用）
2. 各 spawn 对应 Agent，加载对应 Prompt 模板
3. 各 Agent 独立执行
```

4. 更新状态：`current_phase="p4-exec"`

### Phase 5: 验证闭环

- Lead 通过 `TaskList` 轮询各 Agent 进度
- 各 Agent 自主跑测试、debug、修复
- 如果 Agent 报告测试失败且无法自行修复：
  - 尝试 spawn `debugger` Agent 协助
  - 仍无法解决 → 升级 blocker 给用户
- 所有 Agent 达到终端状态后，更新状态：`current_phase="p5-verify-done"`

### Phase 6: 模拟用户测试（条件触发）

- 如果需求涉及 UI / Web / GUI / 交互流程：
  1. 读取 `auto-test.md`
  2. Spawn executor Agent 执行多角色测试（新手/熟手/对抗性）
  3. 收集测试报告
- 更新状态：`current_phase="p6-usertest-done"`

### Phase 7: 产出聚合

收集所有 Agent 产出，向用户输出统一 YAML 摘要：

```yaml
status: success | partial | blocked | failed
summary: "一句话描述整体成果"
parallel_mode: none | cross-module | worktree | cross-concern
artifacts:
  - type: req_doc
    location: ".omc/parallel-dev/req-<slug>.md"
  - type: test_plan
    location: ".omc/parallel-dev/testplan-<slug>.md"
  - type: code
    location: "<file paths>"
  - type: test_report
    location: "<file paths or inline summary>"
  - type: user_test_report
    location: "<if applicable>"

agents:
  - id: "worker-1"
    task: "后端逻辑开发"
    status: completed
    tests_passed: true
  - id: "worker-2"
    task: "UI 测试"
    status: completed
    tests_passed: true

verification:
  tests_passed: true | false | partial
  review_passed: true | false
  user_test_passed: true | false | skipped

decisions_needed:
  - "<需要人类拍板的架构决策或方案选择>"

blockers:
  - "<如果有阻塞项，列出原因和需要的支持>"

next_steps:
  - "<建议的下一步动作>"
```

更新状态：`current_phase="p7-done"`, `active=false`

### Resume 语义

如果调用时 `state_read(mode="parallel-dev")` 返回 `active=true` 且 `current_phase` 非终端：
1. 读取上次状态
2. 读取已保存的 artifacts（需求文档、测试计划）
3. 从断点阶段恢复执行，而不是从头开始
4. 终端状态：`p7-done`, `p7-failed`

---

## 三把钥匙（快速参考）

并行开发的底座。执行协议自动按条件触发。

| 瓶颈 | 钥匙 | 触发文件 | 触发条件 |
|------|------|---------|---------|
| 需求传递 | 需求对齐 | `auto-req.md` | Phase 0 判断 input_type = fuzzy |
| 功能正确性 | TPDD | `auto-dev.md` Part 1 | Phase 0 判断 input_type ≠ dev-only |
| 可维护性 | 工程纪律 | `auto-dev.md` Part 2 | 所有开发 Agent 必加载 |
| 真实体验 | 模拟用户测试 | `auto-test.md` | Phase 6 判断涉及 UI/Web |
| 产出消化 | 自动分类 | `auto-triage.md` | Phase 7 聚合时参考格式 |

### TPDD 核心要点（供 Lead 快速判断）

- **测试计划必须独立审核** —— 同一个 Agent 的理解偏差会同时污染测试和代码，导致一起错、一起全绿。
- **审核主体按复杂度选择** —— 低风险项目换 Agent 审；高风险项目 Agent 先审 + 人类再审业务盲区。
- **Agent 能动手才谈得上 TPDD** —— 必须暴露 shell + 日志 + 测试框架 + browser/GUI/debugger（按需）。

### 工程纪律八大原则（所有开发 Agent 必遵守）

1. 模块深度 —— 接口简单、内部深厚；禁止为拆而拆
2. 信息隐藏 —— 按"谁拥有知识"拆分，不是按时间顺序
3. 抽象分层 —— 禁止只转发的透传层；复杂度往下压
4. 内聚与分离 —— 必须同时理解的放一起；通用和特例分开
5. 错误处理 —— 尽量"把错误定义掉"，减少异常位置
6. 命名与显而易见性 —— 读者第一眼就能猜出代码在做什么
7. 文档与注释 —— 注释描述代码无法表达的东西（意图、为什么）
8. 战略式设计 —— 每次修改是投资，不是补丁；同时警惕过度设计

---

## 并行模式（快速参考）

执行协议在 Phase 4 自动推荐，用户确认后执行。

### 模式一：跨模块并行（cross-module）

不同模块/项目各起一个 Agent，之间无代码依赖。Lead 把任务拆成模块级子任务，重叠度 < 20%。

### 模式二：worktree 隔离并行（worktree）

同一项目里多个方向同时推进，或多方案择优合并。用 `git worktree` 创建独立工作目录，各 checkout 不同分支。

### 模式三：交叉并行（cross-concern）

同一功能内部按事务类型拆开并行。如后端测试 + UI 测试 + bug 修复三路并发。

### 模式四：单任务内部并行（实验性）

Agent 自己识别可并行子模块、自己拆多路跑。当前限制较多，执行协议中不自动推荐，用户显式要求时才启用。

---

## Gateway 集成

本框架设计为可由 `gateway` skill 路由触发。gateway 作为入口，parallel-dev 作为执行引擎。

### 典型数据流

```
User Request
    |
    v
[gateway] 初步分类 + 保战略上下文
    |
    +-- 若需多 Agent 并行开发 → 路由到 parallel-dev
    |       |
    |       v
    |   [parallel-dev Lead] 自动执行 Phase 0-7
    |       Phase 1: 需求对齐（条件触发）
    |       Phase 2: 测试计划
    |       Phase 3: 独立审核
    |       Phase 4: 模式选择 + spawn Agents
    |       Phase 5: 验证闭环
    |       Phase 6: 用户测试（条件触发）
    |       Phase 7: 产出聚合 → YAML 摘要
    |
    +-- 若纯编程小任务 → 路由到 codex / executor
    +-- 若调研分析 → 路由到 explore / analyst
```

### gateway → parallel-dev 上下文传递

- **必须携带**：任务描述（或需求文档路径）
- **可选携带**：`--mode=` 覆盖并行模式、`--skip-req` 跳过需求对齐、`--complexity=` 覆盖复杂度判断
- **返回**：Phase 7 YAML 摘要，含 `decisions_needed` 和 `blockers`

### 简化版调度策略（parallel-dev 内部 Worker 路由）

parallel-dev Lead 在 Phase 4 spawn 的 Worker，同样可以按 gateway 思路自我路由：

| Worker 子任务 | 执行方式 | 理由 |
|-------------|---------|------|
| 纯编码实现 | Bash 调用 Codex CLI | 编程任务 token 成本低 |
| 长文档阅读（>10k tokens）| Bash 调用 Gemini CLI | 长上下文性价比优 |
| 跑脚本/测试/数据处理 | Bash 直接执行 | 无需 LLM |
| 深度推理但 Sonnet 能搞定 | Worker 自己思考 + Bash | 不外调 |
| 超复杂（核心架构、疑难 Bug）| 返回 blocker，Lead spawn Opus | 不硬上 |
| UI/前端实现 | 路由到 designer Agent | 专用模型 |
| 审查类 | 路由到 verifier / reviewer | 专用审查 |

**Worker 铁律**：
1. 搞不定的不要硬上 —— 返回 blocker
2. 保险审查不可跳过 —— 代码类跑测试+语法检查，分析类交叉验证
3. 回滚优先于修复 —— 审查失败则 git checkout

---

## 使用示例

```bash
# 模糊需求 → 自动走完整流程（需求对齐 → TPDD → 审核 → 模式三并行）
/oh-my-claudecode:parallel-dev "实现一个订单导出功能，支持 CSV 和 Excel，能处理 10 万条记录"

# 明确小任务 → 极简路径（跳需求对齐和测试计划）
/oh-my-claudecode:parallel-dev "把 config.py 里的 hardcoded API key 改成从环境变量读取"

# 显式指定并行模式
/oh-my-claudecode:parallel-dev --mode=worktree "用两种方案实现缓存层：Redis vs 本地内存，跑完测试择优合并"

# 已有需求文档 → 跳过 Phase 1
/oh-my-claudecode:parallel-dev "基于 docs/requirements/auth-v2.md 实现登录模块"

# 单 Agent 串行（覆盖自动推荐的并行）
/oh-my-claudecode:parallel-dev --mode=none "给 UserService 加一个根据邮箱查找用户的方法"
```

---

## 文件索引

| 文件 | 内容 | 触发阶段 |
|------|------|---------|
| `SKILL.md` | 本文件，自动路由执行协议 | Lead 全程 |
| `auto-req.md` | 需求对齐 Prompt 模板 | Phase 1 |
| `auto-dev.md` | TPDD 流程 + 工程纪律 + 自审查清单 | Phase 2-5 |
| `auto-test.md` | 多角色模拟用户测试 Prompt | Phase 6 |
| `auto-triage.md` | 产出消化框架（实验性） | Phase 7 参考 |

---

> **来源：** 本文框架沉淀自 "几千美金 token 换来的并行开发经验"（A7um / zero-review 实践）。
> **关联：** 可与 `team`, `ultrawork`, `gateway` skill 组合使用。
