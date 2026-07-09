# OpenCode Profile Kit

语言: [English](README.md) | [简体中文](README.zh-CN.md)

运行多个 OpenCode agent stack，同时避免它们互相冲突。

Agent、skill、插件、MCP server 和指令通常会以 stack 的形式组合使用。但随着 stack 变多，它们很容易互相影响：不同的 prompt、工具、插件、权限和环境变量，并不总是适合放在同一套共享配置里。

OpenCode 本身已经具备适合这个场景的基础能力：profile config 可以叠加在 global config 之上，而不是替换 global config。相比只支持完全独立 config directory 的工具，这让 OpenCode 更适合多 agent 工作流。

`opencode-profile-kit` 并不是发明这套模型，而是让它变得实用。

它让每个 stack 都拥有隔离、可切换的 OpenCode profile，同时保留 OpenCode 自身提供的共享基础：session、通用插件、通用 skill 和全局配置。

核心模型是:

```text
OpenCode global config + OpenCode profile config = shared base + isolated stack
```

你可以用它来:

- 隔离互相冲突的 agent/skill stack
- 快速切换不同的 OpenCode runtime
- 共享通用 session、插件、skill 和基础配置
- 将 profile 专属的插件、skill、MCP server 和环境变量分开管理
- 在不破坏日常配置的前提下试验新 stack

所有东西都保持本地、透明、可脚本化。

---

## 目录

- [安装](#安装)
- [目录布局](#目录布局)
- [配置](#配置)
- [命令](#命令)
- [基础用法](#基础用法)
- [安装到 Profile](#安装到-profile)
- [升级配方](#升级配方)
- [迁移归档](#迁移归档)
- [重写硬编码路径](#重写硬编码路径)
- [克隆](#克隆)
- [共享配置链接](#共享配置链接)
- [Profile 启动命令](#profile-启动命令)
- [注册表](#注册表)
- [补全](#补全)
- [可选 Shell 辅助函数](#可选-shell-辅助函数)
- [Doctor](#doctor)

---

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/flyinghail/opencode-profile-kit/main/install.sh | bash
```

`ocp` 是默认 CLI 命令名，但安装时可以使用自定义命令名:

```bash
curl -fsSL https://raw.githubusercontent.com/flyinghail/opencode-profile-kit/main/install.sh | CLI_NAME=ocpk bash
```

从本地 checkout 手动安装:

```bash
mkdir -p ~/.local/bin
ln -sfn "$PWD/bin/ocp" ~/.local/bin/ocp
```

---

## 目录布局

默认遵循 XDG 风格的分离方式:

```text
~/.config/opencode-profile-kit/config.env          # 用户可编辑配置
~/.local/share/opencode-profile-kit/state/         # 注册表/状态
~/.local/share/opencode-profile-kit/bin/ocp        # install.sh 安装的源码
~/.opencode-profiles/<profile>/                    # profile 目录
```

默认 profile 目录:

```text
~/.opencode-profiles
```

`link` 使用的 OpenCode 全局配置目录:

```text
~/.config/opencode
```

---

## 配置

创建 `~/.config/opencode-profile-kit/config.env` 来覆盖默认值:

```bash
OC_PROFILES_DIR="$HOME/.opencode-profiles"
OC_BIN_DIR="$HOME/.local/bin"
```

`OC_PROFILES_DIR` 必须位于 `$HOME` 之下。

---

## 命令

```text
ocp new <profile> [--from <template>]
ocp clone <src> <dst> [--full]
ocp rename <old> <new>
ocp remove <profile> [--delete-dir]

ocp run <profile> [opencode args...]
ocp shell <profile>
ocp exec <profile> -- <command...>
ocp exec <profile> --stdin

ocp env <profile> [bash|zsh]
ocp env list <profile>
ocp env set <profile> KEY=value
ocp env remove <profile> KEY
ocp clear [bash|zsh]
ocp which

ocp link <profile> <path> [--force]
ocp link-all <path> [--force]

ocp bin create <profile> <command-name>
ocp bin list [profile]
ocp bin remove <command-name>
ocp bin repair <command-name|--all>

ocp upgrade <profile>
ocp upgrade -g
ocp upgrade init [-f|--force] [--rewrite-paths|--no-rewrite-paths] <profile>
ocp upgrade init [-f|--force] -g
ocp upgrade edit <profile>
ocp upgrade edit -g
ocp upgrade show <profile>
ocp upgrade show -g

ocp external add <profile> <path>
ocp external add -g <path>
ocp external list <profile>
ocp external list -g
ocp external remove <profile> <path>
ocp external remove -g <path>

ocp export [-f|--force] <profile> [file.tar.gz]
ocp export [-f|--force] -a [file.tar.gz]
ocp export [-f|--force] -g [file.tar.gz]
ocp export [-f|--force] -a -g [file.tar.gz]
ocp import [-f|--force|--skip-existing|-y|--yes] [file.tar.gz]

ocp rewrite-paths <profile> [path-suffix]

ocp list
ocp path <profile>
ocp refresh
ocp doctor [profile]
ocp completion [bash|zsh] [--install]
ocp config
```

---

## 基础用法

创建一个 profile:

```bash
ocp new my-profile
```

使用该 profile 运行 OpenCode:

```bash
ocp run my-profile
```

向 OpenCode 传递参数:

```bash
ocp run my-profile --port 0
```

在 profile 环境中运行任意命令:

```bash
ocp exec my-profile -- env | grep OPENCODE_CONFIG_DIR
ocp exec my-profile -- zsh
```

### Profile shell

`ocp shell <profile>` 会在 profile 目录中启动 `${SHELL:-/bin/sh}`，并设置 `OPENCODE_CONFIG_DIR`。

### Profile 环境预设

在 `.ocp-env` 中保存 profile 专属环境变量:

```bash
ocp env set my-profile ANTHROPIC_SMALL_FAST_MODEL=claude-haiku
ocp env list my-profile
ocp env remove my-profile ANTHROPIC_SMALL_FAST_MODEL
```

预设会由 `ocp run`、`ocp shell`、`ocp exec` 和 `ocp env <profile>` 应用。`OPENCODE_CONFIG_DIR` 始终由 `ocp` 设置，不能被 `.ocp-env` 覆盖。

### 多行脚本

当安装命令需要多行 shell 脚本时，使用 `--stdin`:

```bash
ocp exec my-profile --stdin <<'SCRIPT'
echo "$OPENCODE_CONFIG_DIR"
npx some-package install
SCRIPT
```

对于会写入 `~/.config/opencode` 的安装器，优先使用显式的 `ocp upgrade` 配方。

### 重命名

`ocp rename <old> <new>` 会重命名 profile 目录，并更新注册表、manifest 和已注册的启动命令。如果 markdown 文件中仍包含旧 profile 路径，它会发出警告。

显示 `OPENCODE_CONFIG_DIR` 对应的当前 profile:

```bash
ocp which
```

---

## 安装到 Profile

大多数 OpenCode 生态工具会把配置、插件、MCP server、agent 或运行时文件安装到当前 `OPENCODE_CONFIG_DIR`。

要将内容安装到指定 profile:

```bash
ocp exec my-profile -- npx <package> install
```

也可以先进入 profile 环境:

```bash
ocp shell my-profile
```

然后正常运行安装器:

```bash
npx <package> install
```

所有内容现在都应安装到:

```text
~/.opencode-profiles/my-profile
```

而不是全局 OpenCode 配置目录。

---

## 升级配方

`ocp upgrade <profile>` 会以 profile 目录作为 cwd 运行 `$OC_PROFILES_DIR/<profile>/.ocp-recipes`。

创建一个引导式配方:

```bash
ocp upgrade init my-profile
```

编辑或查看它:

```bash
ocp upgrade edit my-profile
ocp upgrade show my-profile
```

全局 OpenCode 配置使用 `-g`:

```bash
ocp upgrade init -g
ocp upgrade -g
```

配方是 Bash 脚本。Profile 配方会获得这些变量:

```bash
OCP_TARGET=profile
OCP_PROFILE=my-profile
OCP_PROFILE_DIR=$HOME/.opencode-profiles/my-profile
OCP_GLOBAL_DIR=$HOME/.config/opencode
OPENCODE_CONFIG_DIR=$OCP_PROFILE_DIR
```

全局配方会获得这些变量:

```bash
OCP_TARGET=global
OCP_PROFILE=
OCP_PROFILE_DIR=
OCP_GLOBAL_DIR=$HOME/.config/opencode
OPENCODE_CONFIG_DIR=$OCP_GLOBAL_DIR
```

当生成的 markdown 需要在所有命令成功后重写路径时，可在 profile 配方中把 `rewrite-paths=true` 作为第一行非注释内容。`rewrite-paths=true` 对全局配方无效。

### 升级配方示例

这些示例会创建 profile 配方，然后运行它。如果配方已经存在，添加 `--force` 来替换。

将 `oh-my-openagent` 安装到 `oma`:

```bash
ocp new oma
ocp upgrade init --no-rewrite-paths oma <<'EOF'
bunx oh-my-openagent install
EOF
ocp upgrade oma
```

将正式版 `oh-my-opencode-slim` v2 安装到 `oos`，并为该 profile 启用后台 subagent:

```bash
ocp new oos
ocp upgrade init --no-rewrite-paths oos <<'EOF'
bunx oh-my-opencode-slim@latest install
ocp env set "${OCP_PROFILE}" OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=1
EOF
ocp upgrade oos
```

将 `gstack` 安装到 `gs`:

```bash
ocp new gs
ocp upgrade init --rewrite-paths gs <<'EOF'
if [ ! -d ~/gstack/.git ]; then
  git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/gstack
fi
cd ~/gstack
git pull --ff-only
./setup --host opencode --prefix
mkdir -p "${OCP_PROFILE_DIR}/skills"
rm -rf "${OCP_PROFILE_DIR}"/skills/gstack*
mv "${OCP_GLOBAL_DIR}"/skills/gstack* "${OCP_PROFILE_DIR}/skills/"
EOF
ocp upgrade gs
```

---

## 迁移归档

导出一个 profile:

```bash
ocp export my-profile
```

导出所有 profile、全局 OpenCode 配置，或两者都导出:

```bash
ocp export -a
ocp export -g
ocp export -a -g
```

默认归档名基于导出内容生成:

```text
<profile>.ocp-profile.tar.gz
all.ocp.tar.gz
global.ocp-global.tar.gz
all-with-global.ocp.tar.gz
```

使用 `-f` 或 `--force` 覆盖已存在的归档路径。

`--all` 和 `--global` 是 `-a` 与 `-g` 的长别名。

全局迁移归档包含 `~/.config/opencode`，以及来自 `~/.config/opencode-profile-kit/global` 的 opencode-profile-kit 全局元数据，包括全局 manifest 和存在时的全局升级配方。

外部 allowlist 允许 profile 或全局配置包含 `$HOME` 下位于主 profile/全局配置树之外的额外文件或目录:

```bash
ocp external add my-profile ~/.local/share/my-tool
ocp external add -g ~/.local/share/global-tool
ocp external list my-profile
ocp external list -g
ocp external remove my-profile ~/.local/share/my-tool
ocp external remove -g ~/.local/share/global-tool
```

导入会把归档恢复到当前 `$HOME`，并将外部 allowlist 路径从源 home 重新映射到目标 home:

```bash
ocp import archive.ocp.tar.gz
```

当导入目标已存在时，使用一种冲突策略:

```bash
ocp import -f archive.ocp.tar.gz             # 覆盖现有目标
ocp import --force archive.ocp.tar.gz        # 等同于 -f
ocp import --skip-existing archive.ocp.tar.gz # 保留现有目标
ocp import -y archive.ocp.tar.gz             # 对提示回答 yes
ocp import --yes archive.ocp.tar.gz          # 等同于 -y
```

使用 `--skip-existing` 时，已存在的 profile 或全局配置会跳过整个单元，包括它的外部路径恢复和 manifest 重映射。当所属的 profile/全局单元被导入时，现有外部目标也会被保留。

如果在交互模式下未提供归档，`ocp import` 会在当前目录查找一个 `.ocp` 归档；如果存在多个候选项，则会提示选择。

---

## 重写硬编码路径

有些安装器会生成包含全局 OpenCode 配置路径硬编码引用的文件。

这些引用通常嵌入在生成的 `agents/`、`skills/` 和 `commands/` markdown 文件中。

目前，`rewrite-paths` 只会修改 `*.md` 文件。

这些引用可能以不同形式出现:

```text
~/.config/opencode/skills
$HOME/.config/opencode/agents
${HOME}/.config/opencode/commands
...
```

使用 `rewrite-paths` 将它们重写为目标 profile 目录:

```bash
ocp rewrite-paths my-profile
```

默认情况下，这会重写以下路径下的引用:

```text
/.config/opencode
```

到 profile 目录后缀:

```text
/.opencode-profiles/my-profile
```

只有 markdown 文件 (`*.md`) 会被修改。

也可以只重写特定子树:

```bash
ocp rewrite-paths my-profile /.config/opencode/skills
ocp rewrite-paths my-profile /.config/opencode/agents
ocp rewrite-paths my-profile /.config/opencode/commands
```

对于新的全局路径安装器工作流，优先使用 [升级配方](#升级配方) 中的显式配方，并在生成的 markdown 需要在成功升级后重写时启用 `rewrite-paths=true`。

升级配方工作流:

```bash
ocp upgrade init my-profile
ocp upgrade edit my-profile
ocp upgrade my-profile
ocp rewrite-paths my-profile
```

---

## 克隆

通过克隆现有 profile 创建新 profile:

```bash
ocp clone my-profile other-profile
```

`new --from` 是 `clone` 的便捷别名:

```bash
ocp new other-profile --from my-profile
```

默认情况下，clone 会保留符号链接，并跳过常见运行时/缓存路径:

```text
session tmp logs semantic index cache .cache
```

复制所有内容:

```bash
ocp clone my-profile other-profile --full
```

---

## 共享配置链接

将 `~/.config/opencode` 中的文件或目录链接到 profile:

```bash
ocp link my-profile AGENTS.md
```

除非提供 `--force`，否则不会覆盖已存在的 profile 路径:

```bash
ocp link my-profile AGENTS.md --force
```

链接到所有已注册 profile:

```bash
ocp link-all AGENTS.md
ocp link-all AGENTS.md --force
```

---

## Profile 启动命令

创建专用启动命令:

```bash
ocp bin create my-profile oc-my-profile
```

然后运行:

```bash
oc-my-profile
oc-my-profile --port 0
```

启动器会调用已安装的 `ocp` 路径并运行:

```bash
ocp run my-profile "$@"
```

---

## 注册表

Profile 索引保存在:

```text
~/.local/share/opencode-profile-kit/state/profiles.tsv
```

列出 profile:

```bash
ocp list
```

打印 profile 路径:

```bash
ocp path my-profile
```

从注册表中移除:

```bash
ocp remove my-profile
```

从注册表中移除并删除 profile 目录:

```bash
ocp remove my-profile --delete-dir
```

从 `OC_PROFILES_DIR` 重建注册表:

```bash
ocp refresh
```

---

## 补全

为当前 shell 打印补全脚本:

```bash
ocp completion
```

为当前 shell 安装补全:

```bash
ocp completion --install
```

shell 会从以下变量自动检测:

```text
$SHELL
```

也可以显式指定 shell:

```bash
ocp completion bash
ocp completion zsh

ocp completion bash --install
ocp completion zsh --install
```

Bash 补全会安装到标准用户补全目录:

```text
${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions/<command-name>
```

这不会修改 `~/.bashrc`。它要求你的 shell 已安装并加载 `bash-completion`。

Zsh 补全会安装到:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/opencode-profile-kit/completions/zsh/_<command-name>
```

对于 zsh，`--install` 会向 `~/.zshrc` 追加一个带标记且幂等的代码块，其中包含所需的 `fpath` / `compinit` 设置。

生成的补全会动态读取以下命令的 profile 列表:

```bash
ocp list
```

因此，新创建的 profile 不需要重新安装补全。

---

## 可选 Shell 辅助函数

`ocp env` 和 `ocp clear` 会打印 shell 代码。

要修改当前 shell 环境，请使用 `eval`。

用于 Bash 的 `~/.bashrc`:

```bash
ocd() {
  eval "$(ocp env "$1" bash)"
}

ocr() {
  eval "$(ocp clear bash)"
}
```

用于 Zsh 的 `~/.zshrc`:

```zsh
ocd() {
  eval "$(ocp env "$1" zsh)"
}

ocr() {
  eval "$(ocp clear zsh)"
}
```

然后使用:

```bash
ocd my-profile
npx <package> install
ocr
```

这些辅助函数内部使用 `eval`。

---

## Doctor

检查安装健康状态:

```bash
ocp doctor
```

检查一个 profile:

```bash
ocp doctor my-profile
```

它会报告:

- 解析后的 config/state/profile/bin 路径
- 是否找到 `opencode`
- 缺失的 manifest
- 损坏的符号链接
- profile 内常见的运行时/缓存路径
