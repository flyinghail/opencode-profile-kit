# OpenCode Profile Kit

`opencode-profile-kit` is a lightweight runtime profile manager for OpenCode.

It treats each profile as an isolated `OPENCODE_CONFIG_DIR` runtime instead of mutating a shared global configuration.

This makes it easier to manage multiple OpenCode setups for different workflows, agent stacks, plugins, MCP servers, and instruction environments.

The core idea is:

```text
one profile = one isolated OPENCODE_CONFIG_DIR runtime
```

That gives you:

- safer isolation between agent stacks
- faster switching between workflows
- repeatable profile creation
- shared config through symlinks
- generated profile launch commands
- shell completion based on known profiles

This tool is for people who want OpenCode profile management to be boring, local, transparent, and scriptable.

---

## Table of Contents

- [Install](#install)
- [Layout](#layout)
- [Configuration](#configuration)
- [Commands](#commands)
- [Basic Usage](#basic-usage)
- [Installing Into a Profile](#installing-into-a-profile)
- [Capturing Global Installers](#capturing-global-installers)
- [Upgrade Recipes](#upgrade-recipes)
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
ocp upgrade init [-f|--force] <profile>
ocp upgrade init [-f|--force] -g
ocp upgrade edit <profile>
ocp upgrade edit -g
ocp upgrade show <profile>
ocp upgrade show -g

ocp external add <profile> <path>
ocp external list <profile>
ocp external remove <profile> <path>
ocp external add -g <path>
ocp external list -g
ocp external remove -g <path>

ocp export [-f|--force] <profile> [archive.tar.gz]
ocp export [-f|--force] -g [archive.tar.gz]
ocp export [-f|--force] -a [-g] [archive.tar.gz]
ocp import [-f|--force|--skip-existing|-y|--yes] [file.tar.gz]

ocp capture <profile> -- <command...>
ocp capture <profile> --stdin
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

### Multi-line scripts

Use `--stdin` when an install command needs multiple shell lines:

```bash
ocp exec my-profile --stdin <<'SCRIPT'
echo "$OPENCODE_CONFIG_DIR"
npx some-package install
SCRIPT
```

For new installers that write to `~/.config/opencode`, prefer an explicit `ocp upgrade` recipe; use deprecated `capture --stdin` only for legacy workflows.

### Rename

`ocp rename <old> <new>` renames the profile directory and updates registry, manifest, and registered launcher commands. It warns if markdown files still contain the old profile path.

Export the profile into the current shell:

```bash
eval "$(ocp env my-profile)"
```

Clear it:

```bash
eval "$(ocp clear)"
```

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
eval "$(ocp env my-profile)"
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

This uses `eval` because a child process cannot modify the environment of its parent shell.

**Only run this with a trusted local `ocp` installation.** If you prefer not to use `eval`, use `ocp exec` instead.

---

## Capturing Global Installers

`ocp capture` is deprecated. It remains available for users who know exactly what it does, but new workflows should prefer `ocp upgrade` scripts with explicit backup, install, selective copy, and restore commands. `capture` syncs the changed `~/.config/opencode` tree into a profile, so a changed global `opencode.json` can be copied into the profile and override profile-specific configuration.

Some tools ignore `OPENCODE_CONFIG_DIR` and always install into:

```text
~/.config/opencode
```

Legacy capture invocation:

```bash
ocp capture my-profile -- npx <package> install
```

`capture` will:

1. backup `~/.config/opencode`
2. run the installer
3. copy resulting changes into the target profile
4. restore the original global config

This can provide profile-isolated installation even for tools that hardcode global paths, but it remains deprecated. For new workflows, write an explicit recipe under [Upgrade Recipes](#upgrade-recipes) instead.

`capture` requires `rsync`.

Install it first:

Ubuntu/Debian:

```bash
sudo apt update && sudo apt install -y rsync
```

macOS:

```bash
brew install rsync
```

Arch:

```bash
sudo pacman -S rsync
```

Fedora:

```bash
sudo dnf install rsync
```

---

## Upgrade Recipes

`ocp upgrade <profile>` runs `$OC_PROFILES_DIR/<profile>/.ocp-recipes` with `OPENCODE_CONFIG_DIR` set to the profile directory and cwd set to the profile directory.

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

Recipes are Bash scripts. Use `rewrite-paths=true` as the first non-comment line for profile recipes when generated markdown should be rewritten after all commands succeed. `rewrite-paths=true` is invalid for global recipes.

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

Legacy capture workflow:

```bash
ocp capture my-profile -- npx <package> install
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
