# Dev Container

A unified development container that includes Symphony, OpenClaw, Hermes (Nous Research), Claude Code, and Codex.

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
./images/dev/container.sh setup-openclaw
./images/dev/container.sh onboard-openclaw
./images/dev/container.sh run-openclaw
./images/dev/container.sh run-openclaw --port 3000
./images/dev/container.sh xcode-status
./images/dev/container.sh xcodebuild -version
./images/dev/container.sh xcrun --show-sdk-path --sdk macosx
./images/dev/container.sh simctl list devices
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
NODE_MAJOR=24
MISE_VERSION=v2025.11.11
ERLANG_VERSION=28
ELIXIR_VERSION=1.19.5-otp-28
SSH_MODE=import
SYMPHONY_DIR=/home/dev/symphony
SYMPHONY_CONFIG_DIR=/home/dev/.config/symphony
SYMPHONY_WORKSPACE_ROOT=/home/dev/code/symphony-workspaces
OPENCLAW_DIR=/home/dev/openclaw
OPENCLAW_UPSTREAM_URL=https://github.com/openclaw/openclaw.git
OPENCLAW_REF=main
GIT_SSH_HOST=github.com
```

## Included Tools

- **Symphony** -- `setup-symphony` clones or updates `openai/symphony`, installs the Elixir toolchain with `mise`, and writes guest-local config. `run-symphony` launches the Elixir reference implementation.
- **OpenClaw** -- `setup-openclaw` clones or updates `openclaw/openclaw` and builds with pnpm. `onboard-openclaw` runs interactive onboarding. `run-openclaw` launches the gateway.
- **Hermes** -- Nous Research autonomous agent, pre-installed at `/opt/hermes-agent` and available as `hermes` on PATH. Configure with `hermes` after first shell.
- **Claude Code** -- Anthropic CLI coding agent, pre-installed via npm and available as `claude` on PATH.
- **Codex** -- OpenAI Codex CLI, pre-installed via npm and available as `codex` on PATH.
- **Xcode host tools** -- Xcode, Command Line Tools, Apple SDKs, and Simulator tooling are macOS-only and do not run inside the Ubuntu guest. The wrapper provides host passthrough commands for `xcodebuild`, `xcrun`, and `xcrun simctl` so you can use the host installation alongside the container.

## Xcode And Apple SDKs

This image is based on Ubuntu, so it cannot install or execute Xcode, Apple SDKs, `xcodebuild`, `xcrun`, or Simulator binaries inside the guest. Use the host passthrough commands instead:

```bash
./images/dev/container.sh xcode-status
./images/dev/container.sh xcodebuild -version
./images/dev/container.sh xcrun --show-sdk-path --sdk macosx
./images/dev/container.sh simctl list devices
```

These commands run on the macOS host. They work best from a checkout that is visible to the host filesystem; projects cloned only into the container's `/home/dev` named volume are not visible to host Xcode tooling.

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
