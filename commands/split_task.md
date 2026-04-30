---
description: 总结或恢复当前任务，维护 current_tasks.md，拆分可验证子任务并同步 TodoWrite
---

请加载并执行 `split-task` skill。

用户传入的参数、文档引用或任务描述如下：

```text
$ARGUMENTS
```

要求：

1. 使用 `skill` 工具加载 `split-task`，以 skill 中的规则作为唯一权威流程。
2. 基于 `$ARGUMENTS` 读取指定文档，或把 `$ARGUMENTS` 作为任务描述并阅读项目上下文。
3. 如果 `$ARGUMENTS` 要求从 `current_tasks.md` 继续任务，则读取该文件并根据持久状态恢复 TodoWrite。
4. 创建、更新或维护当前项目目录下的 `current_tasks.md`。
5. 同步使用 TodoWrite 创建可视化 todo list，除非用户明确要求不创建 todo。
6. 最终直接输出任务摘要、当前进度和子任务简表，让用户无需打开 `current_tasks.md` 也能知道要做什么。

默认使用简体中文；代码、命令、路径和字段名保留原文。
