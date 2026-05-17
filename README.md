# my_opencode_config

个人常用 OpenCode 配置仓库。

## 安装

### OpenCode

在新机器上执行：

```bash
git clone <this-repo-url> ~/Code/my_opencode_config
cd ~/Code/my_opencode_config
chmod +x setup.sh
./setup.sh
```

默认安装到：

```text
~/.config/opencode
```

安装内容：

- `global-chinese.md` -> `~/.config/opencode/instructions/global-chinese.md`
- `skills/*` -> `~/.config/opencode/skills/`
- 生成 `~/.config/opencode/opencode.json`

默认使用 symlink，方便后续修改仓库内容后立即生效。

## 选项

预览安装动作但不改文件：

```bash
./setup.sh --dry-run
```

复制文件而不是创建 symlink：

```bash
./setup.sh --copy
```

指定 OpenCode 配置目录：

```bash
OPENCODE_CONFIG_DIR=/path/to/opencode ./setup.sh
```

## 说明

新版 OpenCode 已支持直接通过 slash 触发 skill，因此这里不再保留单独的 `commands/` 包装层；`setup.sh` 现在也不会再安装 `commands/`。

## 当前 Skill

```text
split-task
```

用于总结或恢复当前任务，维护 `current_tasks.md`，拆分可验证子任务并同步 TodoWrite。

## 安装到 Codex

把 `split-task` skill 安装到 Codex：

```bash
chmod +x install-to-codex.sh
./install-to-codex.sh
```

默认安装到：

```text
~/.codex/skills/split-task
```

默认使用 symlink。可用选项：

```bash
./install-to-codex.sh --dry-run
./install-to-codex.sh --copy
CODEX_HOME=/path/to/codex ./install-to-codex.sh
CODEX_SKILLS_DIR=/path/to/skills ./install-to-codex.sh
```

安装后重启 Codex 或开启新会话，让 skill 生效。

## 安装到 Claude Code

把 `split-task` skill 安装到 Claude Code：

```bash
chmod +x install-to-claude-code.sh
./install-to-claude-code.sh
```

默认安装到：

```text
~/.claude/skills/split-task
```
