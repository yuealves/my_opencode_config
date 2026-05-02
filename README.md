# my_opencode_config

个人常用 OpenCode 配置仓库。

## 安装

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
- `commands/*.md` -> `~/.config/opencode/commands/`
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

如果目标路径已有文件或目录，脚本会先移动到：

```text
~/.config/opencode/backups/YYYYMMDD-HHMMSS
```

安装完成后需要重启 OpenCode，新的 command 和 skill 才会被加载。

## 当前命令

```text
/split_task
```

用于总结或恢复当前任务，维护 `current_tasks.md`，拆分可验证子任务并同步 TodoWrite。
