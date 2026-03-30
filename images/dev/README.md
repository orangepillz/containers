# Dev Container

The dev image keeps the existing Symphony-focused workflow, now under `images/dev/`.

## Commands

```bash
./images/dev/container.sh build
./images/dev/container.sh create
./images/dev/container.sh up
./images/dev/container.sh shell
./images/dev/container.sh setup-git-ssh
./images/dev/container.sh setup-git-ssh --force
./images/dev/container.sh setup-symphony
./images/dev/container.sh run-symphony
./images/dev/container.sh run-symphony --port 4000
./images/dev/container.sh stop
./images/dev/container.sh destroy
./images/dev/container.sh destroy --purge
./images/dev/container.sh status
```

## Environment

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

`setup-symphony` clones or updates `openai/symphony`, installs the Elixir toolchain with `mise`, and writes guest-local config under `/home/dev/.config/symphony/`. `run-symphony` launches the built Elixir reference implementation from the guest checkout.
