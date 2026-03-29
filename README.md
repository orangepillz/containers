# Apple `container` Dev Box

This repo builds a reusable development container around Apple's [`container`](https://github.com/apple/container) CLI.

The wrapper script creates a single long-lived dev box with:

- Go
- Node.js 22
- Git
- Python 3
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

The script fails fast on unsupported hosts. On this machine, for example, it will reject macOS `14.7.4` because Apple documents `container` support for macOS `26+`.

## Quick Start

```bash
./scripts/dev-container.sh build
./scripts/dev-container.sh up
./scripts/dev-container.sh shell
```

Inside the shell, Docker runs entirely inside the guest:

```bash
docker run --rm hello-world
```

## SSH

The default SSH mode is `import`, which copies a private key into the persistent guest home directory:

```bash
./scripts/dev-container.sh import-ssh-key ~/.ssh/id_ed25519
```

If you prefer agent forwarding instead, set `SSH_MODE=agent` before `create`:

```bash
SSH_MODE=agent ./scripts/dev-container.sh create
SSH_MODE=agent ./scripts/dev-container.sh up
```

## Commands

```bash
./scripts/dev-container.sh build
./scripts/dev-container.sh create
./scripts/dev-container.sh up
./scripts/dev-container.sh shell
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
SSH_MODE=import
```

Example:

```bash
DEV_MEMORY=12g DEV_CPUS=6 ./scripts/dev-container.sh up
```

## Notes

- `destroy` removes the container but keeps the named volumes by default.
- `destroy --purge` removes the container and both named volumes.
- The shell command passes through `OPENAI_API_KEY` if it is set on the host when you launch the shell.
