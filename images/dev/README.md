# Dev Container

The dev image keeps the existing Symphony-focused workflow, now under `images/dev/`, and includes the GitHub CLI (`gh`) in the base image.

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
DEV_NAME=dev
DEV_IMAGE=dev:latest
DEV_MEMORY=8g
DEV_CPUS=4
DEV_BUILDER_MEMORY=8g
DEV_BUILDER_CPUS=4
DEV_HOME_VOLUME=dev-home
DEV_DOCKER_VOLUME=dev-docker
DEV_HOME_VOLUME_SIZE=
DEV_DOCKER_VOLUME_SIZE=
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

`DEV_HOME_VOLUME_SIZE` and `DEV_DOCKER_VOLUME_SIZE` are applied when their named volumes are first created. If you reuse an existing volume name, the wrapper keeps that existing volume and its existing size.

## Multiple Instances

The default image tag is always `dev:latest`, so you can build once and run as many named dev containers as you want by changing `DEV_NAME`.

```bash
./images/dev/container.sh build
DEV_NAME=dev-a ./images/dev/container.sh up
DEV_NAME=dev-b DEV_MEMORY=12g DEV_CPUS=6 DEV_HOME_VOLUME_SIZE=50G DEV_DOCKER_VOLUME_SIZE=150G ./images/dev/container.sh up
DEV_NAME=dev-a ./images/dev/container.sh shell
DEV_NAME=dev-b ./images/dev/container.sh destroy --purge
```
