---
name: split-task
description: Read user-provided task descriptions and/or project documents, summarize the current task, first write a draft current_tasks.md plus confirmation questions, then refine it after user confirmation; mirror subtasks into TodoWrite, and maintain persistent progress/task-branch checkpoints between subtasks. Use when the user asks to turn context into a step-by-step task breakdown for future execution or resume from current_tasks.md.
---

# split-task

## 适用场景

当用户希望你基于某个文档、若干项目文档，或直接输入的一段任务描述，提炼当前项目任务并产出一个可后续逐步执行的 `current_tasks.md` 时，使用此 skill。

默认采用“两段式确认流程”：先快速阅读必要上下文，向用户说明准备怎么做，并写入一版可阅读的 `current_tasks.md` 草案；如果存在不确定点，用优先选择题的方式向用户确认。用户确认后，再根据用户选择更新 `current_tasks.md` 为正式计划，并同步创建会话内 TodoWrite 列表。后续执行任务时，`current_tasks.md` 是持久进度记录，必须随每个子任务的完成情况更新。

典型触发语义：

- “阅读这个文档，帮我总结当前任务并切分子任务”
- “根据我下面这段任务描述，先阅读项目，再使用 split-task”
- “把任务分解成 3-5 个阶段，写到 current_tasks.md”
- “之后我想让你按 current_tasks.md 一步一步做，并在 todo list 里显示”
- “总结这个项目现在要做什么，并给每步验证方式”
- “阅读 current_tasks.md，继续上次的任务”
- “好的继续 / 继续下一个任务”

## 输出目标

在当前项目目录下创建或更新 `current_tasks.md`。默认先写草案版，再在用户确认后更新为正式版。

草案版 `current_tasks.md` 必须包含：

1. `计划状态`：写明 `draft_awaiting_user_confirmation`。
2. `任务摘要`：尽量 200 字以内，用简体中文精炼说明项目背景、当前目标和阶段重点。
3. `准备怎么做`：用 3-6 条概括 agent 初步判断的执行路线。
4. `待确认问题`：列出需要用户确认的分歧点；每个问题优先给 2-4 个互斥选项，并标出推荐选项和影响。
5. `子任务草案`：按当前理解切分 3-5 个子任务，每个子任务写清初步目标和验证方式；状态统一为 `pending`。

正式版 `current_tasks.md` 必须包含：

1. `任务摘要`：尽量 200 字以内，用简体中文精炼说明项目背景、当前目标和阶段重点。
2. `子任务拆分`：按人类工程执行顺序切分 3-5 个子任务；如果任务复杂可以更多，任务简单可以更少。
3. 每个子任务包含：
   - `做什么`：本阶段要完成的具体结果。
   - `怎么做`：关键实现路径、参考文件、命令或注意事项。
   - `验证方式`：用户或后续 agent 如何阶段性判断该子任务成功。
     对包含代码、脚本或运行时配置改动的子任务，必须规划至少一个随仓库提交、可重复运行的
     自动化测试；优先单元测试，跨网络/进程/存储边界时可用自包含集成测试。纯文档子任务也要
     写可自动执行的文档检查或说明为什么只能人工审阅。
   - `状态`：`pending` / `in_progress` / `awaiting_user_review` / `completed` / `cancelled`。
   - `完成记录`：完成后写入实际改动、验证结果、用户确认情况和 commit 信息。
4. 子任务之间应能自然衔接，后一个任务默认依赖前一个任务的可验证结果。

草案阶段也应同步创建 TodoWrite 或当前环境等价的计划列表；如果环境没有 TodoWrite，则使用可用的 plan/progress 工具，并在回复中说明。

正式版阶段使用 TodoWrite 创建一份会话内 todo list：

1. 每个子任务对应一个 todo。
2. todo 文案使用子任务标题，必要时附上简短验证目标。
3. 初始状态全部设为 `pending`，除非用户明确要求立即开始执行第一个子任务。
4. 优先级按执行重要性设置，通常核心路径为 `high`，辅助验证为 `medium`。
5. TodoWrite 是会话内可视化进度，`current_tasks.md` 是持久任务文档，两者都要保留。

`current_tasks.md` 还承担跨 session 恢复任务状态的职责：新 session 中如果用户要求“阅读 current_tasks.md 继续任务”，必须先读取该文件。如果 `计划状态` 仍是 `draft_awaiting_user_confirmation`，不要直接执行子任务，先向用户复述草案和待确认问题；如果已是正式计划，则根据各子任务的状态和完成记录重建 TodoWrite 列表，再继续执行合适的下一步。

## 工作流程

1. 判断上下文来源。
   - 如果用户指定了某个或多个文档，例如 `@docs/foo.md`、`task.md`、绝对路径或相对路径，必须优先读取这些文档，并以它们作为主要任务来源。
   - 如果用户直接输入了一段任务描述，先把这段描述作为主要任务来源，再按需阅读当前项目结构、相关代码、配置、README、docs 等来补足实现背景。
   - 如果用户既指定文档又输入任务描述，以用户直接输入的任务描述为当前需求，以指定文档作为背景和约束。
   - 如果用户没有指定文件也没有给出明确描述，先在当前目录查找 `README.md`、`PLAN.md`、`DESIGN.md`、`TASK.md`、`docs/**/*.md` 等相关文档；信息仍不足时，问一个简短澄清问题。
   - 不要凭空假设项目目标；必须基于用户输入或已读取文档总结。

2. 快速形成草案判断。
   - 区分“项目长期目标”和“当前阶段任务”。
   - 优先写当前最应该执行的阶段，不要把长期远景写成当前立即任务。
   - 如果文档中有验收标准、推荐命令、输入输出路径、参考实现、风险点，要纳入摘要或子任务。
   - 不要一开始就输出最终详细计划；先说明“准备怎么做”的粗略路径，让用户能快速判断方向是否符合预期。

3. 识别需要确认的不确定点。
   - 如果存在范围、验收标准、是否提交、是否创建分支、是否执行重测试、是否重构文件结构、是否保留历史等分歧，必须先列成待确认问题。
   - 待确认问题优先使用选择题，而不是开放问答。每个问题给 2-4 个互斥选项，并标明推荐项与取舍。
   - 如果当前环境提供选择题 UI 工具，优先使用该工具提问；否则在回复里用简短选项列出。
   - 如果没有明显不确定点，也要说明“我没有发现必须先确认的分歧”，并给用户一次调整方向的机会。

4. 写入草案版 `current_tasks.md`。
   - 即使仍需用户确认，也必须先写一版 `current_tasks.md` 草案，方便用户阅读完整上下文和初步拆分。
   - 草案必须包含 `计划状态：draft_awaiting_user_confirmation`。
   - 草案中的子任务状态全部为 `pending`，不得把任何子任务标为 `in_progress`，除非用户明确要求立即开始执行。
   - 草案必须把“执行规则”写入文档本身，不能只依赖 skill 上下文。

5. 向用户汇报草案并等待确认。
   - 回复中简要说明已写入草案路径、准备怎么做、待确认问题和推荐选项。
   - 不要在用户确认前开始执行子任务或大规模修改项目文件。
   - 如果用户回复的是选项或方向调整，必须先更新 `current_tasks.md`，再进入正式执行流程。

6. 用户确认后，切分正式子任务。
   - 以可阶段性验证为核心，而不是按代码文件机械拆分。
   - 每步都应有清晰成功信号，例如脚本能运行、schema 对齐、单样本通过、报告可复现、测试通过、构建成功。
   - 优先先做探查/脚手架，再做核心实现，再做对比验证，再做扩展或性能迁移。
   - 每个子任务尽量小到用户能在完成后检查方向是否正确。
   - 每个包含代码、脚本或运行时配置改动的子任务，至少安排一个仓库内自动化测试作为阶段
     交付；构建成功、`static_assert`、lint、临时命令和人工操作不能代替运行时测试。
   - 自动化测试应尽量直接调用生产代码并接入项目现有测试入口；若核心边界天然跨 TCP、进程
     或文件，可使用无需外部服务的自包含集成测试，并在文档中如实分类。

7. 写入正式版 `current_tasks.md`。
   - 如果文件不存在，创建新文件。
   - 如果文件已存在，先读取它；除非用户明确要求保留历史，否则用新的任务拆分替换内容。
   - 使用简体中文 Markdown。
   - 保留代码、命令、路径、字段名、API 名称的原文。
   - 正式版必须包含 `计划状态：confirmed`。
   - 新建任务拆分时，每个子任务默认写入 `状态：pending` 和 `完成记录：暂无`。
   - 必须把“执行规则”写入 `current_tasks.md` 本身，不能只依赖 skill 上下文；这样在上下文压缩或新会话只读取 `current_tasks.md` 时，也能继续遵守规则。
   - `current_tasks.md` 中的执行规则至少要覆盖：状态含义、TodoWrite 恢复、任务专用分支策略、完成后等待用户确认、用户确认后提交子任务 commit、全部完成后 squash merge 回原分支、进入下一任务前更新文档、非 git repo 时记录原因。

8. 同步创建 TodoWrite 列表。
   - 将 `current_tasks.md` 中的每个子任务同步为一个 todo。
   - 如果用户只是要求拆任务，不要把第一个 todo 标成 `in_progress`；全部保持 `pending`。
   - 如果用户明确要求“拆完后开始做第一步”，则把第一个 todo 标成 `in_progress`。
   - 后续按 `current_tasks.md` 执行任务时，开始某个子任务前把对应 todo 标为 `in_progress`，完成后立即标为 `completed`。
   - 如果当前环境没有 TodoWrite，使用等价的 plan/progress 工具；如果也没有，则在回复中说明只能依赖 `current_tasks.md`。

9. 从 `current_tasks.md` 恢复进度。
   - 当用户要求“阅读 current_tasks.md 继续任务”或类似表达时，先读取 `current_tasks.md`。
   - 如果 `计划状态` 是 `draft_awaiting_user_confirmation`，不要执行子任务；先复述草案、待确认问题和推荐选项，等待用户确认。
   - 根据每个子任务的 `状态` 重建 TodoWrite：`completed` 映射为 completed，`in_progress` 或 `awaiting_user_review` 映射为 in_progress，`pending` 映射为 pending，`cancelled` 映射为 cancelled。
   - 如果没有 `in_progress` 或 `awaiting_user_review`，下一步默认选择第一个 `pending` 子任务。
   - 如果有 `awaiting_user_review`，不要直接进入下一任务；先询问或等待用户确认该子任务是否通过。
   - 恢复后在回复中说明当前进度、下一个建议执行的子任务，以及已重建 TodoWrite。

10. 完成后直接汇报任务内容。
   - 说明已写入的文件路径。
   - 说明已同步创建 TodoWrite 列表，或说明当前环境使用了等价 plan 工具。
   - 必须直接输出一段简短的任务描述，让用户无需打开文件也能知道当前要做什么。
   - 必须直接列出子任务标题和每步验证方式的简短版，让用户无需打开文件也能知道如何分步做。
   - 如果还在草案阶段，必须明确说明“等待用户确认后才会更新为正式计划并开始执行”。
   - 不要重复粘贴整份 `current_tasks.md`；输出应是精简摘要版。

## 子任务执行与确认流程

执行 `current_tasks.md` 中的子任务时，必须遵守以下流程：

1. 开始子任务前，把 `current_tasks.md` 中该子任务状态更新为 `in_progress`，并同步 TodoWrite。
2. 完成代码或文档改动后，运行该子任务对应的验证方式；如果无法验证，记录原因。包含代码、
   脚本或运行时配置改动时，必须先补并运行至少一个仓库内自动化测试。只有用户明确豁免，或
   技术上确实无法自动化且已记录具体原因/替代验证时，才能例外。
3. 编写 code review 文档（默认 `docs/review/<taskName>/phase<N>_<subtaskName>.md`，taskName 取自任务专用分支名去掉 `split-task/` 前缀，作为子目录；subtaskName 为子任务主题的 kebab-case 简称；路径可按项目结构调整并写进 `current_tasks.md` 执行规则）。该文档面向“只了解项目背景、不了解本次具体改动”的 reviewer，必须包含三部分：① 设计思路（整体设计，易读好懂，先讲为什么再讲怎么做）；② 本子任务的具体改动（逐文件、代码级）；③ 跑通的测试与实际结果。“设计思路”不得只复述字段、类名或调用流程；对每个非显然的关键决策，要写清它要解决的真实场景/失败模式、为什么现有条件或更简单方案不够、所选机制如何解决、适用边界与兼容性代价。只有确实评估过的替代方案才写取舍，不要为了套模板虚构方案。“测试与实际结果”必须分开列出：仓库内自动化测试、依赖外部服务/真实数据的集成测试、人工故障注入或性能采样；说明每项覆盖和未覆盖什么，不能把构建或临时命令统称为测试。
4. 将完成情况写回 `current_tasks.md`：包括实际改动、验证命令/结果、遗留问题、待用户确认项。
5. 确认阶段自动化测试已随改动落入仓库并运行通过后，再将状态更新为 `awaiting_user_review`，
   并把 review 文档呈现给用户审阅。若缺少必需自动化测试且没有明确豁免/技术原因，保持
   `in_progress`。**此时不要 git commit**——必须等用户 review 通过后才提交。
6. 只有当用户明确表达认可，例如“继续下一个任务”、“好的继续”、“可以，继续”、“没问题，下一步”时，才把该子任务状态从 `awaiting_user_review` 更新为 `completed`。
7. 用户 review 通过后，再把该子任务的代码改动、review 文档、`current_tasks.md` 进度更新放进**同一个 commit**（review 文档与代码同 commit，一个 hash 自包含）。提交后才开始下一个子任务。
8. 如果当前目录不是 git repo，或用户明确要求不提交，则不要强行提交；在完成记录和回复中说明原因。
9. 如果用户指出问题或要求修改，不要进入下一子任务，也不要 commit；继续修正当前子任务，更新 review 文档和完成记录，再次进入 `awaiting_user_review`。

## 任务分支与提交规则

- 第一次开始执行某个任务拆分中的第一个子任务时，如果当前目录是 git repo，应先记录当前分支为“原分支”，再从该分支创建并切换到任务专用分支：`git checkout -b <task-branch>`。
- 任务专用分支名应能对应当前整体任务，优先使用 `split-task/<short-task-name>`；如果项目已有分支命名规范，则遵循项目规范。
- 如果 `current_tasks.md` 已记录任务专用分支，恢复任务时应先确认当前分支；不在该分支时，切换回已记录的任务专用分支再继续。
- 每个被用户确认完成的子任务，都应在用户 review 通过后、进入下一个子任务前，在任务专用分支上单独 git commit；**code review 文档与代码改动进入同一个 commit**。
- 子任务 commit 内容应包含该子任务的所有相关代码/配置/文档改动、code review 文档，以及 `current_tasks.md` 的状态和完成记录更新。
- 子任务 commit message 应准确概括该子任务结果，优先使用“标题 + Implementation 正文”的统一规范；如果项目已有更明确规范，则遵循项目规范。
- 所有子任务都被用户确认完成后，应切换回原分支，并将任务专用分支 squash merge 回原分支：`git merge --squash <task-branch>`。
- squash merge 后只创建一个面向整体任务的 commit，commit message 使用统一规范，说明整体功能和关键代码结构，不需要逐条保留每个子任务的细节。
- 任务专用分支不要删除，保留其中的详细子任务 commit 以便之后追溯。
- 提交前必须检查 git status 和 diff，避免提交明显无关文件、密钥或用户未要求提交的敏感文件。
- 如果当前目录不是 git repo，或用户明确要求不提交，则不要强行提交；在 `current_tasks.md` 完成记录和最终回复中说明原因。
- 不要 amend，不要 force push，不要执行 destructive git 命令。

### Commit Message 规范

优先使用下面的统一格式：

```text
<type>(<area>): <summary>

Implementation:
- <changed file/module/structure>: <what it does>
- <changed behavior>: <user-visible or workflow result>
- <important implementation detail if any>
```

要求：

- `type` 优先使用 `feat`、`fix`、`docs`、`refactor`、`test`、`chore`。
- `area` 使用功能名、目录名或主要模块名，例如 `split-task`、`codex`、`readme`、`setup`、`skills`。
- `summary` 简明说明实现了什么能力或修复了什么问题。
- `Implementation` 至少列出 2-3 条关键改动，尽量提到文件、模块、脚本、配置或核心代码结构。
- 最终 squash commit 应面向整体任务写 message；子任务细节保留在任务专用分支的历史里。

示例：

```text
feat(skills): support Codex install and branch-based split-task execution

Implementation:
- add install-to-codex.sh mirroring Claude Code installer behavior
- extend README with Codex/Claude Code skill install sections
- change split-task SKILL.md from per-subtask mainline commits to task-branch commits
- preserve detailed subtask commits by leaving task branches undeleted
```

## current_tasks.md 推荐模板

```markdown
# 当前任务

## 执行规则

本文档是跨 session 的持久任务状态源。即使对话上下文被压缩或开启新会话，也必须先阅读本文档，并按以下规则继续任务。

### Git 分支信息

- 原分支：待开始第一个子任务时记录。
- 任务专用分支：待开始第一个子任务时创建并记录，建议命名为 `split-task/<short-task-name>`。

### 计划状态

- 当前状态：draft_awaiting_user_confirmation
- 状态说明：这是初版草案，供用户确认方向和选择项；用户确认后必须更新为 `confirmed`，再开始执行子任务。

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

1. 第一次开始执行第一个子任务前，如果当前目录是 git repo，先记录当前分支为“原分支”，再创建并切换到任务专用分支：`git checkout -b <task-branch>`，并把分支名写回本文档。
2. 恢复任务时，如果本文档已记录任务专用分支，应先确认当前分支；不在任务专用分支时，切换回任务专用分支再继续子任务。
3. 开始某个子任务前，先把该子任务状态更新为 `in_progress`，并同步 TodoWrite。
4. 完成实现和验证后，编写 code review 文档 `docs/review/<taskName>/phase<N>_<subtaskName>.md`（taskName 取自任务专用分支名去掉 `split-task/` 前缀，作为子目录；subtaskName 为子任务主题的 kebab-case 简称；路径按项目结构调整）。该文档面向“只了解项目背景、不了解本次具体改动”的 reviewer，必须包含三部分：① 设计思路（整体设计，易读好懂，先讲为什么再讲怎么做）；② 本子任务的具体改动（逐文件、代码级）；③ 跑通的测试与实际结果。“设计思路”不能让 reader 根据实现反推原因：对每个非显然关键决策，明确写出触发该设计的场景/失败模式、较简单直觉方案为何不足、最终机制与因果链、适用边界/故障语义/兼容性影响；若没有真实备选方案，不要硬凑对比。简单直接的改动可以简述，不要为满足格式过度扩写。“测试与实际结果”分开列出仓库自动化测试、外部服务/真实数据集成测试、人工故障注入/性能采样，并说明覆盖边界；构建、lint、`static_assert`、临时命令不能冒充测试。包含代码、脚本或运行时配置改动时，至少一个随仓库提交且已通过的自动化测试是进入 review 的前置条件；例外必须记录用户豁免或具体技术原因。同时把实际改动、验证命令/结果、遗留问题写入该子任务的 `完成记录`。
5. agent 完成子任务后，只能把状态更新为 `awaiting_user_review`，并把 review 文档呈现给用户审阅。**此时不要 git commit**——必须等用户 review 通过后才提交。
6. 只有当用户明确表示认可，例如“继续下一个任务”“好的继续”“可以，继续”“没问题，下一步”时，才把该子任务状态更新为 `completed`。
7. 用户 review 通过后，再把该子任务的代码/测试/review 文档/本文档状态更新放进**同一个 commit**（review 文档与代码同 commit，一个 hash 自包含）。提交后才开始下一个子任务。
8. 如果当前目录不是 git repo，或用户明确要求不提交，则不要强行提交；必须在完成记录和回复中说明原因。
9. 如果用户指出问题或要求修改，不要进入下一子任务，也不要 commit；继续修正当前子任务，更新 review 文档和完成记录，再次进入 `awaiting_user_review`。

### 提交规则

- 每个被用户确认完成的子任务应在任务专用分支上单独提交。
- 提交前检查 git status 和 diff，避免提交无关文件、密钥或用户未要求提交的敏感文件。
- 子任务 commit message 应准确概括该子任务结果，并尽量使用“标题 + Implementation 正文”的统一规范。
- 所有子任务都被用户确认完成后，切换回原分支，执行 `git merge --squash <task-branch>`，再创建一个面向整体任务的最终 commit。
- 最终 commit message 使用统一规范，只写针对整个 task 的描述和关键代码结构，不需要逐条罗列每个子任务。
- 不要删除任务专用分支，保留其中的详细子任务 commit 以便之后追溯。
- 不要 amend，不要 force push，不要执行 destructive git 命令。

### Commit Message 规范

优先使用下面的统一格式：

```text
<type>(<area>): <summary>

Implementation:
- <changed file/module/structure>: <what it does>
- <changed behavior>: <user-visible or workflow result>
- <important implementation detail if any>
```

要求：

- `type` 优先使用 `feat`、`fix`、`docs`、`refactor`、`test`、`chore`。
- `area` 使用功能名、目录名或主要模块名，例如 `split-task`、`codex`、`readme`、`setup`、`skills`。
- `summary` 简明说明实现了什么能力或修复了什么问题。
- `Implementation` 至少列出 2-3 条关键改动，尽量提到文件、模块、脚本、配置或核心代码结构。
- 最终 squash commit 应面向整体任务写 message；子任务细节保留在任务专用分支的历史里。

## 任务摘要

<用尽量 200 字以内说明：项目背景、当前目标、阶段重点、最终验收方向。>

## 准备怎么做

- <3-6 条粗略执行路线。>

## 待确认问题

### 1. <问题标题>

推荐选项：A

- A. <选项 A>：<影响/取舍。>
- B. <选项 B>：<影响/取舍。>
- C. <选项 C>：<影响/取舍。>

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
- 每个包含代码、脚本或运行时配置改动的子任务至少有一个随仓库提交、可重复运行的自动化
  测试；优先单元测试，必要时使用无外部依赖的自包含集成测试，并接入项目测试入口。
- 构建成功、lint、`static_assert`、临时脚本和人工测试都可作为补充证据，但不能代替阶段自动化
  测试。review 必须把自动化、外部集成和人工验证分开写，并说明各自覆盖/未覆盖的场景。
- code review 的“设计思路”必须回答“为什么需要这个设计”，不能只回答“代码怎么实现”。reader 不应靠猜测才能知道设计考虑了哪些运行场景、错误风险和恢复边界。
- 关键术语首次出现时，用项目场景解释其角色和必要性；例如某个 ID、watermark、锁或协议字段解决的是哪类歧义，缺少它会出现什么可观察后果。
- 设计说明必须与最终代码一致；已知限制、失败后的处理方式、兼容性变化和需要人工介入的边界要明确写出，不能用“支持”“可靠”等笼统结论代替。
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
4. 如果已有已确认的 `completed` 子任务且下一个为 `pending`，开始该 pending 子任务前先检查是否需要在任务专用分支上为上一个已确认任务补 git commit。
5. 如果所有子任务都已 `completed`，检查是否已 squash merge 回原分支；尚未合并时，执行 squash merge，并用整体任务描述创建最终 commit。
