---
name: technical-plan
description: Use when the user asks to turn a large engineering task into a technical proposal/design document before implementation, especially when they want phased implementation steps, validation plans, risks, and open questions for discussion/confirmation. The skill should research the codebase/docs first, write or update a design/plan document in the repo, and stop for user confirmation before coding.
---

# technical-plan

## 适用场景

当用户提出一个偏大的工程任务，并明确希望先“讨论技术方案”“写到文档里”“拆分几步实现/验证”“确认细节后再开工”时，使用此 skill。

典型触发语义：

- “这个任务比较大，先跟我讨论技术方案”
- “把技术方案和分步实现写到一个文档里”
- “先不要写代码，先设计方案”
- “帮我拆成几步实现和验证，等我确认”
- “以后会经常有这种大任务，先写方案文档再讨论”

## 核心原则

- 先理解现状，再写方案；不要基于旧印象或聊天记忆直接设计。
- 方案文档应服务后续实现，而不是写成空泛调研报告。
- 明确区分“当前阶段要做什么”和“后续可能做什么”。
- 分步计划必须可验证，每一步都有成功信号。
- 文档写完后停下来等待用户确认；除非用户明确要求，不要开始实现。
- 如果方案里有不确定输入，如上游清单、业务口径、参数网格、性能目标，要列成待确认问题。

## 工作流程

1. 收集上下文。
   - 先读项目入口文档，例如 `README.md`、`docs/README.md`、`AGENTS.md`、相关 `docs/design/*.md`、`docs/how-to/*.md`。
   - 再读与任务直接相关的代码、测试、脚本、reference 文件。
   - 如果用户指定了某些文档或文件，以它们为主要上下文。
   - 用 `rg` 搜索相关 symbol、配置、测试和历史文档，避免漏掉已有实现。

2. 明确任务边界。
   - 写清楚当前要解决的问题。
   - 写清楚不在本阶段处理的内容。
   - 如果任务可以拆成“立即实现”和“后续确认后实现”，必须分开。

3. 设计技术方案。
   - 描述当前架构/数据流/关键入口。
   - 描述目标架构/数据流/关键改动。
   - 明确主要数据结构、接口、文件路径、配置或脚本变化。
   - 说明兼容策略、迁移策略、性能影响和风险。
   - 对复杂方案给出取舍理由，尤其是为什么不选明显替代方案。

4. 拆分实现阶段。
   - 按工程依赖顺序拆分，通常是：catalog/schema 或接口冻结 -> 核心状态/模型 -> runtime 接入 -> reference/e2e -> 性能验证 -> 文档收尾。
   - 每个阶段包含：`目标`、`交付`、`验证`、必要的 `风险/注意事项`。
   - 阶段不要按文件机械拆，要按可验证能力拆。

5. 写入方案文档。
   - 优先放在项目已有设计目录，如 `docs/design/`、`docs/adr/`、`docs/proposals/`。
   - 如果项目没有惯例，使用 `docs/design/<n>.<short-topic>.md` 或 `docs/proposals/<date>-<topic>.md`。
   - 同步更新对应索引文档，例如 `docs/design/0.README.md` 或 `docs/README.md`。
   - 使用简体中文；代码、命令、路径、API 名称可保留英文。

6. 汇报并等待确认。
   - 回复中给出文档路径。
   - 用简短列表总结方案重点、阶段拆分和待确认问题。
   - 明确说明“当前只写了方案，尚未实现”。
   - 等用户确认、修改边界或补充资料后，再进入实现。

## 方案文档推荐结构

```markdown
# <任务名> 技术方案

## 背景

## 当前状态

## 目标和非目标

## 设计方案

## 数据结构 / 接口 / 文件改动

## 验证策略

## 分步实现计划

### Phase 0: <阶段名>

目标：

交付：

验证：

### Phase 1: <阶段名>

目标：

交付：

验证：

## 风险和待确认问题

## 建议先确认的方案点
```

## 质量标准

- 文档能让另一个新 session 读完后继续实现。
- 每个实现阶段都有具体验证命令或可观察结果。
- 方案中出现的路径和 symbol 真实存在，或明确标注为“建议新增”。
- 不确定项不能写成确定结论。
- 不要把用户尚未确认的扩展范围写成当前阶段目标。
