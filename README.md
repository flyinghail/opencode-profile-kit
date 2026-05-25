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

## Commands

```text
ocp new <profile> [--from <template>]
ocp clone <src> <dst> [--full]
ocp remove <profile> [--delete-dir]

ocp run <profile> [opencode args...]
ocp exec <profile> -- <command...>

ocp env <profile> [bash|zsh]
ocp clear [bash|zsh]
ocp which

ocp link <profile> <path> [--force]
ocp link-all <path> [--force]

ocp bin <profile> <command-name>

ocp list
ocp path <profile>
ocp refresh
ocp doctor [profile]
ocp completion <bash|zsh> [command-name]
ocp config
```

## Layout

Defaults follow XDG-style separation:

```text
~/.config/opencode-profile-kit/config.env          # user-editable config
~/.local/share/opencode-profile-kit/state/         # registry/state
~/.local/share/opencode-profile-kit/bin/ocp        # installed source by install.sh
~/.opencode-profiles/<profile>/                     # profile directories
```

Default profile directory:

```text
~/.opencode-profiles
```

Default OpenCode global config directory used by `link`:

```text
~/.config/opencode
```

## Install

Default command name:

```bash
curl -fsSL https://raw.githubusercontent.com/flyinghail/opencode-profile-kit/main/install.sh | bash
```

Use a custom command name:

```bash
curl -fsSL https://raw.githubusercontent.com/flyinghail/opencode-profile-kit/main/install.sh | CLI_NAME=ocpk bash
```

Manual local install from checkout:

```bash
mkdir -p ~/.local/bin
ln -sfn "$PWD/bin/ocp" ~/.local/bin/ocp
```

## Configuration

Create `~/.config/opencode-profile-kit/config.env` to override defaults:

```bash
OC_PROFILES_DIR="$HOME/.opencode-profiles"
OC_GLOBAL_DIR="$HOME/.config/opencode"
OC_BIN_DIR="$HOME/.local/bin"
```

## Basic usage

Create a profile:

```bash
ocp new omo
```

Run OpenCode with that profile:

```bash
ocp run omo
```

Pass arguments to OpenCode:

```bash
ocp run omo --port 0
```

Run any command with the profile environment:

```bash
ocp exec omo -- env | grep OPENCODE_CONFIG_DIR
ocp exec omo -- zsh
```

Export the profile into the current shell:

```bash
eval "$(ocp env omo)"
```

Clear it:

```bash
eval "$(ocp clear)"
```

Show the current profile from `OPENCODE_CONFIG_DIR`:

```bash
ocp which
```

## Clone / template workflow

Create a profile from a template:

```bash
ocp new omo-sp --from omo
```

Clone a profile:

```bash
ocp clone omo omo-sp
```

By default, clone preserves symlinks and skips common runtime/cache paths:

```text
session tmp logs semantic index cache .cache
```

Copy everything:

```bash
ocp clone omo-s gsd --full
```

## Shared config links

Link a file or directory from `~/.config/opencode` into a profile:

```bash
ocp link omo AGENTS.md
```

Do not overwrite existing profile paths unless `--force` is supplied:

```bash
ocp link omo AGENTS.md --force
```

Link into all registered profiles:

```bash
ocp link-all AGENTS.md
ocp link-all AGENTS.md --force
```

## Profile launcher commands

Create a dedicated launcher command:

```bash
ocp bin omo oc-omo
```

Then run:

```bash
oc-omo
oc-omo --port 0
```

The launcher calls the installed `ocp` path and runs:

```bash
ocp run omo "$@"
```

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
ocp path omo
```

Remove from registry:

```bash
ocp remove omo
```

Remove from registry and delete the profile directory:

```bash
ocp remove omo --delete-dir
```

Rebuild registry from `OC_PROFILES_DIR`:

```bash
ocp refresh
```

## Completion

Bash:

```bash
mkdir -p ~/.local/share/bash-completion/completions
ocp completion bash ocp > ~/.local/share/bash-completion/completions/ocp
```

Zsh:

```bash
mkdir -p ~/.zfunc
ocp completion zsh ocp > ~/.zfunc/_ocp
```

Then ensure this exists in `.zshrc` if you use zsh:

```zsh
fpath=(~/.zfunc $fpath)
autoload -Uz compinit
compinit
```

If installed with another command name:

```bash
CLI_NAME=ocpk bash install.sh
ocpk completion bash ocprof > ~/.local/share/bash-completion/completions/ocpk
ocpk completion zsh ocprof > ~/.zfunc/_ocpk
```

## Doctor

Check installation health:

```bash
ocp doctor
```

Check one profile:

```bash
ocp doctor omo
```

It reports:

- resolved config/state/profile/bin paths
- whether `opencode` is found
- missing manifest
- broken symlinks
- common runtime/cache paths inside a profile

