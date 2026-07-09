# OpenCode Profile Kit

Language: [English](README.md) | [简体中文](README.zh-CN.md)

Run multiple OpenCode agent stacks without letting them conflict.

Agents, skills, plugins, MCP servers, and instructions often work best as stacks. But as those stacks grow, they can interfere with each other: different prompts, tools, plugins, permissions, and environment variables do not always belong in one shared setup.

OpenCode already has the right foundation for this: a profile config can layer on top of the global config instead of replacing it. That makes OpenCode especially good for multi-agent workflows compared with tools that only support fully separate config directories.

`opencode-profile-kit` does not invent that model. It makes it practical.

It gives each stack an isolated, switchable OpenCode profile, while preserving the shared base that OpenCode itself provides: sessions, common plugins, common skills, and global configuration.

The core model is:

```text
OpenCode global config + OpenCode profile config = shared base + isolated stack
```

Use it to:

- keep conflicting agent/skill stacks isolated
- switch between different OpenCode runtimes quickly
- share common sessions, plugins, skills, and base config
- keep profile-specific plugins, skills, MCP servers, and env vars separate
- experiment with new stacks without breaking your daily setup

Everything stays local, transparent, and scriptable.

---

## Table of Contents

- [Install](#install)
- [Layout](#layout)
- [Configuration](#configuration)
- [Commands](#commands)
- [Basic Usage](#basic-usage)
- [Installing Into a Profile](#installing-into-a-profile)
- [Upgrade Recipes](#upgrade-recipes)
- [Migration Archives](#migration-archives)
- [Rewriting Hardcoded Paths](#rewriting-hardcoded-paths)
- [Clone](#clone)
- [Shared Config Links](#shared-config-links)
- [Profile Launcher Commands](#profile-launcher-commands)
- [Registry](#registry)
- [Completion](#completion)
- [Optional Shell Helpers](#optional-shell-helpers)
- [Doctor](#doctor)

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/flyinghail/opencode-profile-kit/main/install.sh | bash
```

`ocp` is the default CLI command name, but installation can use a custom command name:

```bash
curl -fsSL https://raw.githubusercontent.com/flyinghail/opencode-profile-kit/main/install.sh | CLI_NAME=ocpk bash
```

Manual local install from checkout:

```bash
mkdir -p ~/.local/bin
ln -sfn "$PWD/bin/ocp" ~/.local/bin/ocp
```

---

## Layout

Defaults follow XDG-style separation:

```text
~/.config/opencode-profile-kit/config.env          # user-editable config
~/.local/share/opencode-profile-kit/state/         # registry/state
~/.local/share/opencode-profile-kit/bin/ocp        # installed source by install.sh
~/.opencode-profiles/<profile>/                    # profile directories
```

Default profile directory:

```text
~/.opencode-profiles
```

OpenCode global config directory used by `link`:

```text
~/.config/opencode
```

---

## Configuration

Create `~/.config/opencode-profile-kit/config.env` to override defaults:

```bash
OC_PROFILES_DIR="$HOME/.opencode-profiles"
OC_BIN_DIR="$HOME/.local/bin"
```

`OC_PROFILES_DIR` must be under `$HOME`.

---

## Commands

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

## Basic usage

Create a profile:

```bash
ocp new my-profile
```

Run OpenCode with that profile:

```bash
ocp run my-profile
```

Pass arguments to OpenCode:

```bash
ocp run my-profile --port 0
```

Run any command inside the profile environment:

```bash
ocp exec my-profile -- env | grep OPENCODE_CONFIG_DIR
ocp exec my-profile -- zsh
```

### Profile shell

`ocp shell <profile>` starts `${SHELL:-/bin/sh}` in the profile directory with `OPENCODE_CONFIG_DIR` set.

### Profile environment presets

Store profile-specific environment variables in `.ocp-env`:

```bash
ocp env set my-profile ANTHROPIC_SMALL_FAST_MODEL=claude-haiku
ocp env list my-profile
ocp env remove my-profile ANTHROPIC_SMALL_FAST_MODEL
```

Presets are applied by `ocp run`, `ocp shell`, `ocp exec`, and `ocp env <profile>`. `OPENCODE_CONFIG_DIR` is always set by `ocp` and cannot be overridden by `.ocp-env`.

### Multi-line scripts

Use `--stdin` when an install command needs multiple shell lines:

```bash
ocp exec my-profile --stdin <<'SCRIPT'
echo "$OPENCODE_CONFIG_DIR"
npx some-package install
SCRIPT
```

For installers that write to `~/.config/opencode`, prefer an explicit `ocp upgrade` recipe.

### Rename

`ocp rename <old> <new>` renames the profile directory and updates registry, manifest, and registered launcher commands. It warns if markdown files still contain the old profile path.

Show the current profile from `OPENCODE_CONFIG_DIR`:

```bash
ocp which
```

---

## Installing Into a Profile

Most OpenCode ecosystem tools install configuration, plugins, MCP servers, agents, or runtime files into the current `OPENCODE_CONFIG_DIR`.

To install something into a specific profile:

```bash
ocp exec my-profile -- npx <package> install
```

You can also enter the profile environment first:

```bash
ocp shell my-profile
```

Then run the installer normally:

```bash
npx <package> install
```

Everything should now install into:

```text
~/.opencode-profiles/my-profile
```

instead of the global OpenCode config directory.

---

## Upgrade Recipes

`ocp upgrade <profile>` runs `$OC_PROFILES_DIR/<profile>/.ocp-recipes` with cwd set to the profile directory.

Create a guided recipe:

```bash
ocp upgrade init my-profile
```

Edit or view it:

```bash
ocp upgrade edit my-profile
ocp upgrade show my-profile
```

Global OpenCode config uses `-g`:

```bash
ocp upgrade init -g
ocp upgrade -g
```

Recipes are Bash scripts. Profile recipes get these variables:

```bash
OCP_TARGET=profile
OCP_PROFILE=my-profile
OCP_PROFILE_DIR=$HOME/.opencode-profiles/my-profile
OCP_GLOBAL_DIR=$HOME/.config/opencode
OPENCODE_CONFIG_DIR=$OCP_PROFILE_DIR
```

Global recipes get these variables:

```bash
OCP_TARGET=global
OCP_PROFILE=
OCP_PROFILE_DIR=
OCP_GLOBAL_DIR=$HOME/.config/opencode
OPENCODE_CONFIG_DIR=$OCP_GLOBAL_DIR
```

Use `rewrite-paths=true` as the first non-comment line for profile recipes when generated markdown should be rewritten after all commands succeed. `rewrite-paths=true` is invalid for global recipes.

### Example upgrade recipes

These examples create the profile recipe and then run it. If the recipe already exists, add `--force` to replace it.

Install `oh-my-openagent` into `oma`:

```bash
ocp new oma
ocp upgrade init --no-rewrite-paths oma <<'EOF'
bunx oh-my-openagent install
EOF
ocp upgrade oma
```

Install the stable `oh-my-opencode-slim@v2` into `oos` and enable background subagents for that profile:

```bash
ocp new oos
ocp upgrade init --no-rewrite-paths oos <<'EOF'
bunx oh-my-opencode-slim@latest install
ocp env set "${OCP_PROFILE}" OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=1
EOF
ocp upgrade oos
```

Install `gstack` into `gs`:

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

## Migration Archives

Export one profile:

```bash
ocp export my-profile
```

Export all profiles, global OpenCode config, or both:

```bash
ocp export -a
ocp export -g
ocp export -a -g
```

Default archive names are based on what is exported:

```text
<profile>.ocp-profile.tar.gz
all.ocp.tar.gz
global.ocp-global.tar.gz
all-with-global.ocp.tar.gz
```

Use `-f` or `--force` to overwrite an existing archive path.

`--all` and `--global` are long aliases for `-a` and `-g`.

Global migration archives include `~/.config/opencode` plus opencode-profile-kit global metadata from `~/.config/opencode-profile-kit/global`, including the global manifest and global upgrade recipe when present.

External allowlists let a profile or the global config include additional files or directories under `$HOME` that live outside the main profile/global config tree:

```bash
ocp external add my-profile ~/.local/share/my-tool
ocp external add -g ~/.local/share/global-tool
ocp external list my-profile
ocp external list -g
ocp external remove my-profile ~/.local/share/my-tool
ocp external remove -g ~/.local/share/global-tool
```

Import restores the archive into the current `$HOME` and rebases external allowlist paths from the source home to the destination home:

```bash
ocp import archive.ocp.tar.gz
```

When an import destination already exists, use one conflict policy:

```bash
ocp import -f archive.ocp.tar.gz             # overwrite existing destinations
ocp import --force archive.ocp.tar.gz        # same as -f
ocp import --skip-existing archive.ocp.tar.gz # keep existing destinations
ocp import -y archive.ocp.tar.gz             # answer yes to prompts
ocp import --yes archive.ocp.tar.gz          # same as -y
```

With `--skip-existing`, an existing profile or global config skips that whole unit, including its external path restore and manifest rebasing. Existing external destinations are also kept when their owning profile/global unit is imported.

If no archive is provided interactively, `ocp import` looks for one `.ocp` archive in the current directory and prompts when multiple candidates exist.

---

## Rewriting Hardcoded Paths

Some installers generate files containing hardcoded references to the global OpenCode config path.

These references are commonly embedded in generated `agents/`, `skills/`, and `commands/` markdown files.

Currently, `rewrite-paths` only modifies `*.md` files.

These references may appear in different forms:

```text
~/.config/opencode/skills
$HOME/.config/opencode/agents
${HOME}/.config/opencode/commands
...
```

Use `rewrite-paths` to rewrite them into the target profile directory:

```bash
ocp rewrite-paths my-profile
```

By default, this rewrites references under:

```text
/.config/opencode
```

to the profile directory suffix:

```text
/.opencode-profiles/my-profile
```

Only markdown files (`*.md`) are modified.

You can also rewrite only a specific subtree:

```bash
ocp rewrite-paths my-profile /.config/opencode/skills
ocp rewrite-paths my-profile /.config/opencode/agents
ocp rewrite-paths my-profile /.config/opencode/commands
```

For new global-path installer workflows, prefer an explicit recipe under [Upgrade Recipes](#upgrade-recipes) and enable `rewrite-paths=true` when generated markdown should be rewritten after a successful upgrade.

Upgrade recipe workflow:

```bash
ocp upgrade init my-profile
ocp upgrade edit my-profile
ocp upgrade my-profile
ocp rewrite-paths my-profile
```

---

## Clone

Create a new profile by cloning an existing profile:

```bash
ocp clone my-profile other-profile
```

`new --from` is a convenience alias for `clone`:

```bash
ocp new other-profile --from my-profile
```

By default, clone preserves symlinks and skips common runtime/cache paths:

```text
session tmp logs semantic index cache .cache
```

Copy everything:

```bash
ocp clone my-profile other-profile --full
```

---

## Shared config links

Link a file or directory from `~/.config/opencode` into a profile:

```bash
ocp link my-profile AGENTS.md
```

Do not overwrite existing profile paths unless `--force` is supplied:

```bash
ocp link my-profile AGENTS.md --force
```

Link into all registered profiles:

```bash
ocp link-all AGENTS.md
ocp link-all AGENTS.md --force
```

---

## Profile launcher commands

Create a dedicated launcher command:

```bash
ocp bin create my-profile oc-my-profile
```

Then run:

```bash
oc-my-profile
oc-my-profile --port 0
```

The launcher calls the installed `ocp` path and runs:

```bash
ocp run my-profile "$@"
```

---

## Registry

Profiles are indexed in:

```text
~/.local/share/opencode-profile-kit/state/profiles.tsv
```

List profiles:

```bash
ocp list
```

Print profile path:

```bash
ocp path my-profile
```

Remove from registry:

```bash
ocp remove my-profile
```

Remove from registry and delete the profile directory:

```bash
ocp remove my-profile --delete-dir
```

Rebuild registry from `OC_PROFILES_DIR`:

```bash
ocp refresh
```

---

## Completion

Print completion script for the current shell:

```bash
ocp completion
```

Install completion for the current shell:

```bash
ocp completion --install
```

The shell is automatically detected from:

```text
$SHELL
```

You can also explicitly specify the shell:

```bash
ocp completion bash
ocp completion zsh

ocp completion bash --install
ocp completion zsh --install
```
Bash completion is installed to the standard user completion directory:

```text
${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions/<command-name>
```

This does not modify `~/.bashrc`. It requires `bash-completion` to be installed and loaded by your shell.

Zsh completion is installed under:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/opencode-profile-kit/completions/zsh/_<command-name>
```

For zsh, `--install` appends an idempotent marked block to `~/.zshrc` with the required `fpath` / `compinit` setup.

The generated completion dynamically reads profiles from:

```bash
ocp list
```

so newly created profiles do not require reinstalling completion.

---

## Optional Shell Helpers

`ocp env` and `ocp clear` print shell code.

To modify the current shell environment, use `eval`.

For Bash in `~/.bashrc`:

```bash
ocd() {
  eval "$(ocp env "$1" bash)"
}

ocr() {
  eval "$(ocp clear bash)"
}
```

For Zsh in `~/.zshrc`:

```zsh
ocd() {
  eval "$(ocp env "$1" zsh)"
}

ocr() {
  eval "$(ocp clear zsh)"
}
```

Then use:

```bash
ocd my-profile
npx <package> install
ocr
```

These helpers internally use `eval`.

---

## Doctor

Check installation health:

```bash
ocp doctor
```

Check one profile:

```bash
ocp doctor my-profile
```

It reports:

- resolved config/state/profile/bin paths
- whether `opencode` is found
- missing manifest
- broken symlinks
- common runtime/cache paths inside a profile
