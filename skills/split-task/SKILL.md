---
name: split-task
description: Read user-provided task descriptions and/or project documents, summarize the current task, split it into verifiable sequential subtasks saved as current_tasks.md, mirror subtasks into TodoWrite, and maintain persistent progress/commit checkpoints between subtasks. Use when the user asks to turn context into a step-by-step task breakdown for future execution or resume from current_tasks.md.
---

# split-task

## 适用场景

当用户希望你基于某个文档、若干项目文档，或直接输入的一段任务描述，提炼当前项目任务并产出一个可后续逐步执行的 `current_tasks.md` 时，使用此 skill。此 skill 还应同步创建会话内 TodoWrite 列表，让用户无需打开文档也能在界面上看到分步任务。后续执行任务时，`current_tasks.md` 是持久进度记录，必须随每个子任务的完成情况更新。

典型触发语义：

- “阅读这个文档，帮我总结当前任务并切分子任务”
- “根据我下面这段任务描述，先阅读项目，再使用 split-task”
- “把任务分解成 3-5 个阶段，写到 current_tasks.md”
- “之后我想让你按 current_tasks.md 一步一步做，并在 todo list 里显示”
- “总结这个项目现在要做什么，并给每步验证方式”
- “阅读 current_tasks.md，继续上次的任务”
- “好的继续 / 继续下一个任务”

## 输出目标

在当前项目目录下创建或更新 `current_tasks.md`，包含：

1. `任务摘要`：尽量 200 字以内，用简体中文精炼说明项目背景、当前目标和阶段重点。
2. `子任务拆分`：按人类工程执行顺序切分 3-5 个子任务；如果任务复杂可以更多，任务简单可以更少。
3. 每个子任务包含：
   - `做什么`：本阶段要完成的具体结果。
   - `怎么做`：关键实现路径、参考文件、命令或注意事项。
   - `验证方式`：用户或后续 agent 如何阶段性判断该子任务成功。
   - `状态`：`pending` / `in_progress` / `awaiting_user_review` / `completed` / `cancelled`。
   - `完成记录`：完成后写入实际改动、验证结果、用户确认情况和 commit 信息。
4. 子任务之间应能自然衔接，后一个任务默认依赖前一个任务的可验证结果。

同时使用 TodoWrite 创建一份会话内 todo list：

1. 每个子任务对应一个 todo。
2. todo 文案使用子任务标题，必要时附上简短验证目标。
3. 初始状态全部设为 `pending`，除非用户明确要求立即开始执行第一个子任务。
4. 优先级按执行重要性设置，通常核心路径为 `high`，辅助验证为 `medium`。
5. TodoWrite 是会话内可视化进度，`current_tasks.md` 是持久任务文档，两者都要保留。

`current_tasks.md` 还承担跨 session 恢复任务状态的职责：新 session 中如果用户要求“阅读 current_tasks.md 继续任务”，必须先读取该文件，根据各子任务的状态和完成记录重建 TodoWrite 列表，再继续执行合适的下一步。

## 工作流程

1. 判断上下文来源。
   - 如果用户指定了某个或多个文档，例如 `@docs/foo.md`、`task.md`、绝对路径或相对路径，必须优先读取这些文档，并以它们作为主要任务来源。
   - 如果用户直接输入了一段任务描述，先把这段描述作为主要任务来源，再按需阅读当前项目结构、相关代码、配置、README、docs 等来补足实现背景。
   - 如果用户既指定文档又输入任务描述，以用户直接输入的任务描述为当前需求，以指定文档作为背景和约束。
   - 如果用户没有指定文件也没有给出明确描述，先在当前目录查找 `README.md`、`PLAN.md`、`DESIGN.md`、`TASK.md`、`docs/**/*.md` 等相关文档；信息仍不足时，问一个简短澄清问题。
   - 不要凭空假设项目目标；必须基于用户输入或已读取文档总结。

2. 提炼当前任务。
   - 区分“项目长期目标”和“当前阶段任务”。
   - 优先写当前最应该执行的阶段，不要把长期远景写成当前立即任务。
   - 如果文档中有验收标准、推荐命令、输入输出路径、参考实现、风险点，要纳入摘要或子任务。

3. 切分子任务。
   - 以可阶段性验证为核心，而不是按代码文件机械拆分。
   - 每步都应有清晰成功信号，例如脚本能运行、schema 对齐、单样本通过、报告可复现、测试通过、构建成功。
   - 优先先做探查/脚手架，再做核心实现，再做对比验证，再做扩展或性能迁移。
   - 每个子任务尽量小到用户能在完成后检查方向是否正确。

4. 写入 `current_tasks.md`。
   - 如果文件不存在，创建新文件。
   - 如果文件已存在，先读取它；除非用户明确要求保留历史，否则用新的任务拆分替换内容。
   - 使用简体中文 Markdown。
   - 保留代码、命令、路径、字段名、API 名称的原文。
   - 新建任务拆分时，每个子任务默认写入 `状态：pending` 和 `完成记录：暂无`。
   - 必须把“执行规则”写入 `current_tasks.md` 本身，不能只依赖 skill 上下文；这样在上下文压缩或新会话只读取 `current_tasks.md` 时，也能继续遵守规则。
   - `current_tasks.md` 中的执行规则至少要覆盖：状态含义、TodoWrite 恢复、完成后等待用户确认、用户确认后提交 git commit、进入下一任务前更新文档、非 git repo 时记录原因。

5. 同步创建 TodoWrite 列表。
   - 将 `current_tasks.md` 中的每个子任务同步为一个 todo。
   - 如果用户只是要求拆任务，不要把第一个 todo 标成 `in_progress`；全部保持 `pending`。
   - 如果用户明确要求“拆完后开始做第一步”，则把第一个 todo 标成 `in_progress`。
   - 后续按 `current_tasks.md` 执行任务时，开始某个子任务前把对应 todo 标为 `in_progress`，完成后立即标为 `completed`。

6. 从 `current_tasks.md` 恢复进度。
   - 当用户要求“阅读 current_tasks.md 继续任务”或类似表达时，先读取 `current_tasks.md`。
   - 根据每个子任务的 `状态` 重建 TodoWrite：`completed` 映射为 completed，`in_progress` 或 `awaiting_user_review` 映射为 in_progress，`pending` 映射为 pending，`cancelled` 映射为 cancelled。
   - 如果没有 `in_progress` 或 `awaiting_user_review`，下一步默认选择第一个 `pending` 子任务。
   - 如果有 `awaiting_user_review`，不要直接进入下一任务；先询问或等待用户确认该子任务是否通过。
   - 恢复后在回复中说明当前进度、下一个建议执行的子任务，以及已重建 TodoWrite。

7. 完成后直接汇报任务内容。
   - 说明已写入的文件路径。
   - 说明已同步创建 TodoWrite 列表。
   - 必须直接输出一段简短的任务描述，让用户无需打开文件也能知道当前要做什么。
   - 必须直接列出子任务标题和每步验证方式的简短版，让用户无需打开文件也能知道如何分步做。
   - 不要重复粘贴整份 `current_tasks.md`；输出应是精简摘要版。

## 子任务执行与确认流程

执行 `current_tasks.md` 中的子任务时，必须遵守以下流程：

1. 开始子任务前，把 `current_tasks.md` 中该子任务状态更新为 `in_progress`，并同步 TodoWrite。
2. 完成代码或文档改动后，运行该子任务对应的验证方式；如果无法验证，记录原因。
3. 将完成情况写回 `current_tasks.md`：包括实际改动、验证命令/结果、遗留问题、待用户确认项。
4. 将该子任务状态更新为 `awaiting_user_review`，表示 agent 认为已完成，但还未获得用户认可。
5. 向用户汇报本子任务完成情况，并等待用户判断。
6. 只有当用户明确表达认可，例如“继续下一个任务”、“好的继续”、“可以，继续”、“没问题，下一步”时，才把该子任务状态从 `awaiting_user_review` 更新为 `completed`。
7. 用户确认后、开始下一个子任务前，必须创建 git commit，提交本子任务的代码改动和 `current_tasks.md` 进度更新。
8. 如果用户指出问题或要求修改，不要进入下一子任务；继续修正当前子任务，并更新完成记录。

## 子任务提交规则

- 每个被用户确认完成的子任务，都应在进入下一个子任务前单独 git commit。
- commit 内容应包含该子任务的所有相关代码/配置/文档改动，以及 `current_tasks.md` 的状态和完成记录更新。
- commit message 应准确概括该子任务结果，优先使用简洁英文或遵循项目既有风格。
- 提交前必须检查 git status 和 diff，避免提交明显无关文件、密钥或用户未要求提交的敏感文件。
- 如果当前目录不是 git repo，或用户明确要求不提交，则不要强行提交；在 `current_tasks.md` 完成记录和最终回复中说明原因。
- 不要 amend，不要 force push，不要执行 destructive git 命令。

## current_tasks.md 推荐模板

```markdown
# 当前任务

## 执行规则

本文档是跨 session 的持久任务状态源。即使对话上下文被压缩或开启新会话，也必须先阅读本文档，并按以下规则继续任务。

### 状态含义

- `pending`：尚未开始。
- `in_progress`：正在执行。
- `awaiting_user_review`：agent 认为当前子任务已完成，已写入完成记录，正在等待用户确认。
- `completed`：用户已确认该子任务完成。
- `cancelled`：该子任务已取消。

### TodoWrite 恢复规则

新会话或上下文压缩后继续任务时，必须根据本文档重建 TodoWrite：

- `completed` 映射为 completed。
- `in_progress` 或 `awaiting_user_review` 映射为 in_progress。
- `pending` 映射为 pending。
- `cancelled` 映射为 cancelled。

如果存在 `awaiting_user_review` 的子任务，不要直接进入下一步，必须先等待用户确认。

### 子任务执行规则

1. 开始某个子任务前，先把该子任务状态更新为 `in_progress`，并同步 TodoWrite。
2. 完成实现和验证后，把实际改动、验证命令/结果、遗留问题写入该子任务的 `完成记录`。
3. agent 完成子任务后，只能把状态更新为 `awaiting_user_review`，不能自行判定为最终完成。
4. 只有当用户明确表示认可，例如“继续下一个任务”“好的继续”“可以，继续”“没问题，下一步”时，才把该子任务状态更新为 `completed`。
5. 用户确认后、开始下一个子任务前，必须 git commit 当前子任务的代码/配置/文档改动，以及本文档的状态和完成记录更新。
6. 如果当前目录不是 git repo，或用户明确要求不提交，则不要强行提交；必须在完成记录和回复中说明原因。
7. 如果用户指出问题或要求修改，不要进入下一子任务；继续修正当前子任务，并更新完成记录。

### 提交规则

- 每个被用户确认完成的子任务应单独提交。
- 提交前检查 git status 和 diff，避免提交无关文件、密钥或用户未要求提交的敏感文件。
- commit message 应准确概括该子任务结果，并尽量遵循项目既有风格。
- 不要 amend，不要 force push，不要执行 destructive git 命令。

## 任务摘要

<用尽量 200 字以内说明：项目背景、当前目标、阶段重点、最终验收方向。>

## 子任务拆分

### 1. <子任务标题>

状态：pending

做什么：<本阶段要产出的结果。>

怎么做：<关键步骤、参考文件、命令、数据路径或实现注意事项。>

验证方式：<如何判断本阶段成功，最好包含可运行命令、检查项或预期现象。>

完成记录：暂无

### 2. <子任务标题>

状态：pending

做什么：<...>

怎么做：<...>

验证方式：<...>

完成记录：暂无
```

## 质量要求

- 摘要要精炼，不写空泛套话。
- 子任务标题要具体，能看出阶段目标。
- 验证方式必须可操作，避免只写“检查是否正确”。
- 不要过早承诺具体实现方案；如果文档中已有推荐方案，优先沿用。
- 不要创建过度复杂的项目管理格式；`current_tasks.md` 应服务于后续一步一步执行。
- `current_tasks.md` 是重要的持久状态文件，执行子任务时必须及时写回进度，不能只依赖会话内 TodoWrite。
- 默认使用简体中文；代码、命令、路径和字段名保留原文。

## TodoWrite 使用要求

- 只要执行此 skill，就应调用 TodoWrite 创建或更新 todo list，除非当前环境没有 TodoWrite 工具。
- TodoWrite 的 todo 数量应与 `current_tasks.md` 的子任务数量一致。
- TodoWrite 文案要短，适合界面显示；详细说明和验证方式放在 `current_tasks.md` 与最终回复里。
- 如果当前会话已有 unrelated todo，不要无故保留旧 todo；执行 `split-task` 时应以新的任务拆分为准重建 todo list。
- 如果用户要求只生成文档、不创建 todo，则尊重用户要求，不调用 TodoWrite。
- 从 `current_tasks.md` 恢复任务时，必须根据文档中的状态重建 TodoWrite，而不是从头创建全部 pending。

## 完成回复要求

完成后回复必须包含：

1. 文件路径：`current_tasks.md` 的实际路径。
2. TodoWrite 状态：说明已创建或更新可视化 todo list。
3. 任务摘要：1-3 句话。
4. 子任务简表：按顺序列出每个子任务的标题和一句话验证方式。

不要只说“已创建文件”，因为用户希望不打开文件也能快速了解任务内容和拆分方式。

## 示例用户请求

```text
@docs/task_brief.md 阅读这个文档，帮我总结当前任务是什么，然后把任务分解成 3-5 个可以阶段性验证的子任务，放到 current_tasks.md 里。

根据下面这段任务描述，先阅读项目相关代码，再使用 `split-task`：
我要给登录页增加短信验证码登录，并保证原有密码登录不受影响。
```

## 示例完成回复

```text
已创建 `current_tasks.md`：`<project>/current_tasks.md`，并同步创建了 TodoWrite 列表。

任务摘要：本次任务是给登录页增加短信验证码登录，同时保持原有密码登录流程不变，并补充验证覆盖。

子任务：
1. 梳理现有登录流程；验证方式：确认密码登录入口、状态管理和 API 调用链路。
2. 增加短信验证码 UI 与状态；验证方式：页面可切换登录方式且表单校验正确。
3. 接入验证码发送和登录接口；验证方式：mock 或测试环境能完成验证码登录。
4. 回归密码登录和错误处理；验证方式：原有密码登录测试通过，新增异常场景可复现。
```

## 示例恢复请求

```text
阅读 current_tasks.md，恢复 todo list，并继续下一个未完成任务。
```

示例行为：

1. 读取 `current_tasks.md`。
2. 根据 `状态` 和 `完成记录` 重建 TodoWrite。
3. 如果上一子任务是 `awaiting_user_review`，先等待用户确认，不直接进入下一步。
4. 如果已有已确认的 `completed` 子任务且下一个为 `pending`，开始该 pending 子任务前先检查是否需要为上一个已确认任务补 git commit。
