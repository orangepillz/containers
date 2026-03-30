# Apple `container` Dev Box

This repo builds a reusable development container around Apple's [`container`](https://github.com/apple/container) CLI.

The wrapper script creates a single long-lived dev box with:

- Go
- Node.js 22
- Git
- Python 3
- Homebrew
- `mise`
- Erlang/OTP and Elixir for Symphony
- Docker Engine, Buildx, and Compose
- OpenAI Codex CLI

The default setup is isolation-first:

- no host source directory mounts
- no shared host Docker socket
- persistent named volumes for `/home/dev` and `/var/lib/docker`

## Requirements

- Apple silicon
- macOS 26 or newer
- `container` CLI version `0.10.0` or newer

The script fails fast on unsupported hosts and reports the detected host version when it blocks execution. For example, it will reject macOS `14.7.4` because Apple documents `container` support for macOS `26+`.

## Quick Start

```bash
./scripts/dev-container.sh build
./scripts/dev-container.sh up
./scripts/dev-container.sh shell
```

Inside the shell, Docker runs entirely inside the guest:

```bash
docker run --rm hello-world
brew --version
```

## Git SSH

The original import flow is still available:

```bash
./scripts/dev-container.sh import-ssh-key ~/.ssh/id_ed25519
```

There is now also a guided guest-local bootstrap flow:

```bash
./scripts/dev-container.sh setup-git-ssh
./scripts/dev-container.sh setup-git-ssh --force
```

`setup-git-ssh`:

- ensures the dev container is running
- prompts for Git user name, Git email, SSH key name, and Git host
- creates `~/.ssh`, `known_hosts`, and a minimal `config` file with strict permissions
- generates a container-local Ed25519 keypair by default
- sets global Git identity inside the guest
- prints the public key and a matching `ssh -T git@<host>` test command

Reruns are non-destructive by default. Use `--force` only when you explicitly want to replace an existing keypair.

If you prefer agent forwarding instead, set `SSH_MODE=agent` before `create`:

```bash
SSH_MODE=agent ./scripts/dev-container.sh create
SSH_MODE=agent ./scripts/dev-container.sh up
```

## Symphony

The image now preinstalls `mise`, Erlang/OTP, and Elixir so the upstream `openai/symphony` Elixir reference implementation can be bootstrapped without extra manual runtime installs.

Run the guided setup once:

```bash
./scripts/dev-container.sh setup-symphony
```

That flow:

- ensures the dev container is running
- clones or updates `openai/symphony` into `/home/dev/symphony`
- runs `mise trust`, `mise install`, `mix setup`, and `mix build` in `/home/dev/symphony/elixir`
- prompts for `LINEAR_API_KEY`, the Linear project slug, the source repo URL, and the workspace root
- writes guest-local Symphony config under `/home/dev/.config/symphony/`

Config output locations:

- `/home/dev/.config/symphony/env`
  - mode `0600`
  - stores `LINEAR_API_KEY` plus the generated Symphony runtime config
- `/home/dev/.config/symphony/WORKFLOW.md`
  - generated from the upstream Elixir workflow shape
  - uses the guest-local env file instead of shell startup files for secrets and config

Launch Symphony with:

```bash
./scripts/dev-container.sh run-symphony
./scripts/dev-container.sh run-symphony --port 4000
```

`run-symphony` sources `/home/dev/.config/symphony/env` and starts `/home/dev/symphony/elixir/bin/symphony` with the generated workflow. If setup has not been completed yet, it fails fast with a clear error message.

## Commands

```bash
./scripts/dev-container.sh build
./scripts/dev-container.sh create
./scripts/dev-container.sh up
./scripts/dev-container.sh shell
./scripts/dev-container.sh setup-git-ssh
./scripts/dev-container.sh setup-git-ssh --force
./scripts/dev-container.sh setup-symphony
./scripts/dev-container.sh run-symphony
./scripts/dev-container.sh run-symphony --port 4000
./scripts/dev-container.sh stop
./scripts/dev-container.sh destroy
./scripts/dev-container.sh destroy --purge
./scripts/dev-container.sh status
./scripts/dev-container.sh import-ssh-key ~/.ssh/id_ed25519
```

## Configuration

These environment variables control the build and runtime defaults:

```bash
DEV_NAME=codex-dev
DEV_IMAGE=codex-dev:latest
DEV_MEMORY=8g
DEV_CPUS=4
DEV_BUILDER_MEMORY=8g
DEV_BUILDER_CPUS=4
DEV_HOME_VOLUME=codex-dev-home
DEV_DOCKER_VOLUME=codex-dev-docker
GO_VERSION=1.24.2
NODE_MAJOR=22
MISE_VERSION=v2025.11.11
ERLANG_VERSION=28
ELIXIR_VERSION=1.19.5-otp-28
SSH_MODE=import
SYMPHONY_DIR=/home/dev/symphony
SYMPHONY_CONFIG_DIR=/home/dev/.config/symphony
SYMPHONY_WORKSPACE_ROOT=/home/dev/code/symphony-workspaces
GIT_SSH_HOST=github.com
```

Examples:

```bash
DEV_MEMORY=12g DEV_CPUS=6 ./scripts/dev-container.sh up
ERLANG_VERSION=28 ELIXIR_VERSION=1.19.5-otp-28 ./scripts/dev-container.sh build
GIT_SSH_HOST=git.example.com ./scripts/dev-container.sh setup-git-ssh
```

## Notes

- `destroy` removes the container but keeps the named volumes by default.
- `destroy --purge` removes the container and both named volumes.
- `shell`, `setup-symphony`, and `run-symphony` pass through `OPENAI_API_KEY` if it is set on the host.
- existing tools still run inside the guest; Docker remains isolated inside the container rather than sharing the host Docker socket.
- Homebrew is preinstalled in the supported Linux prefix `/home/linuxbrew/.linuxbrew` and added to the guest shell `PATH`.
