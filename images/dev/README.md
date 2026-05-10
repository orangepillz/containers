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
./images/dev/container.sh xcode-bridge-dns
./images/dev/container.sh xcode-bridge-start
./images/dev/container.sh xcode-bridge simctl list devices available
./images/dev/container.sh xcode-bridge-stop
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
DEV_HOST_CONFIG_ENABLED=1
DEV_HOST_CONFIG_DIR=$HOME/.dev-container/$DEV_NAME/host-config
DEV_HOST_CONFIG_MOUNT=/host-config
DEV_HOST_ZSHRC_ENABLED=1
DEV_HOST_ZSHRC_SOURCE=$HOME/.zshrc
DEV_CODEX_SKILLS_ENABLED=1
DEV_CODEX_SKILLS_SOURCE=$HOME/.codex/skills
DEV_CODEX_SKILLS_TARGET=/home/dev/.codex/skills
DEV_CODEX_SKILLS_DELETE_STALE=0
GO_VERSION=1.24.2
NODE_MAJOR=24
SWIFT_VERSION=6.3.1
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
XCODE_BRIDGE_ENABLED=1
XCODE_BRIDGE_HOST_DIR=$HOME/.dev-container/$DEV_NAME/xcode-bridge
XCODE_BRIDGE_MOUNT=/xcode-bridge
XCODE_BRIDGE_HOSTNAME=host.container.internal
XCODE_BRIDGE_LOCALHOST_IP=203.0.113.113
XCODE_BRIDGE_BIND=127.0.0.1
XCODE_BRIDGE_PORT=8378
```

## Included Tools

- **Symphony** -- `setup-symphony` clones or updates `openai/symphony`, installs the Elixir toolchain with `mise`, and writes guest-local config. `run-symphony` launches the Elixir reference implementation.
- **OpenClaw** -- `setup-openclaw` clones or updates `openclaw/openclaw` and builds with pnpm. `onboard-openclaw` runs interactive onboarding. `run-openclaw` launches the gateway.
- **Hermes** -- Nous Research autonomous agent, pre-installed at `/opt/hermes-agent` and available as `hermes` on PATH. Configure with `hermes` after first shell.
- **Claude Code** -- Anthropic CLI coding agent, pre-installed via npm and available as `claude` on PATH.
- **Codex** -- OpenAI Codex CLI, pre-installed via npm and available as `codex` on PATH.
- **Swift** -- Swift 6.3.1 by default for Ubuntu 24.04 aarch64, installed from the official Swift.org tarball at `/opt/swift` with its PGP signature verified during image build. `swift`, `swiftc`, and SwiftPM are on PATH.
- **Host zshrc** -- `container.sh build`, `create`, `up`, and `shell` copy the host `${DEV_HOST_ZSHRC_SOURCE}` into `${DEV_HOST_CONFIG_DIR}/dotfiles/.zshrc`. The container mounts that config directory at `/host-config`, copies the file to `/home/dev/.host.zshrc`, and sources it from `/home/dev/.zshrc`.
- **Codex skills** -- `container.sh build`, `create`, `up`, and `shell` copy the host `${DEV_CODEX_SKILLS_SOURCE}` into `${DEV_HOST_CONFIG_DIR}/codex/skills`. The container mounts that config directory at `/host-config` and copies the skills into `${DEV_CODEX_SKILLS_TARGET}`.
- **Xcode host tools** -- Xcode, Command Line Tools, Apple SDKs, and Simulator tooling are macOS-only and do not run inside the Ubuntu guest. The wrapper provides direct host passthrough commands and an optional bridge sidecar for invoking Xcode tools from inside the container.

## Host Config

The dev image uses `zsh` for interactive shells. On local builds/runs, the wrapper syncs your host `.zshrc` and Codex skills into the per-container host config directory; they are mounted and copied into the guest at startup rather than baked into the image:

```bash
./images/dev/container.sh build
./images/dev/container.sh up
./images/dev/container.sh shell
```

Inside the container, the synced zsh file lives at `/home/dev/.host.zshrc` and is sourced by `/home/dev/.zshrc`. Host skills are copied into `/home/dev/.codex/skills`. Override or disable these syncs with:

```bash
DEV_HOST_ZSHRC_SOURCE=$HOME/.zshrc.work ./images/dev/container.sh up
DEV_HOST_ZSHRC_ENABLED=0 ./images/dev/container.sh up
DEV_CODEX_SKILLS_SOURCE=$HOME/.codex/skills-work ./images/dev/container.sh up
DEV_CODEX_SKILLS_ENABLED=0 ./images/dev/container.sh up
```

Guest skill sync overwrites matching files, but does not delete extra container-local skills by default. Set `DEV_CODEX_SKILLS_DELETE_STALE=1` if you want `/home/dev/.codex/skills` to exactly mirror the host copy on container startup.

## Xcode And Apple SDKs

This image is based on Ubuntu, so it cannot install or execute Xcode, Apple SDKs, `xcodebuild`, `xcrun`, or Simulator binaries inside the guest. Use the host passthrough commands instead:

```bash
./images/dev/container.sh xcode-status
./images/dev/container.sh xcodebuild -version
./images/dev/container.sh xcrun --show-sdk-path --sdk macosx
./images/dev/container.sh simctl list devices
```

These commands run on the macOS host. They work best from a checkout that is visible to the host filesystem; projects cloned only into the container's `/home/dev` named volume are not visible to host Xcode tooling.

## Xcode Bridge

The Xcode bridge lets commands inside the Ubuntu guest call host `xcodebuild`, `xcrun`, and `xcrun simctl`. It uses:

- a token-protected host sidecar bound to `127.0.0.1`
- Apple `container` DNS for the guest-to-host loopback name
- a narrow bind-mounted exchange directory at `/xcode-bridge`

Configure the host-loopback DNS once:

```bash
./images/dev/container.sh xcode-bridge-dns
```

Start the sidecar before using the guest shims:

```bash
./images/dev/container.sh xcode-bridge-start
./images/dev/container.sh xcode-bridge-status
```

From the host wrapper:

```bash
./images/dev/container.sh xcode-bridge status
./images/dev/container.sh xcode-bridge xcrun --show-sdk-path --sdk macosx
./images/dev/container.sh xcode-bridge simctl list devices available
```

From inside the container shell, the image installs shims:

```bash
xcode-bridge status
xcrun --show-sdk-path --sdk macosx
simctl list devices available
xcodebuild -version
```

Use `/xcode-bridge/exchange` for files that must cross the host/guest boundary:

```bash
xcode-bridge put ./Build/Products/Debug-iphonesimulator/My.app
simctl install booted /xcode-bridge/exchange/uploads/My.app
xcode-bridge sim-read booted com.example.MyApp data Documents ./sim-Documents
xcode-bridge sim-write booted com.example.MyApp data ./seed.json Documents/seed.json
```

Existing containers must be recreated to get Swift, the `/host-config` and `/xcode-bridge` mounts, `zsh`, Codex skills sync, and the guest shims. Rebuild the image, then destroy/recreate the container without `--purge` if you want to keep the named volumes:

```bash
./images/dev/container.sh build
./images/dev/container.sh destroy
./images/dev/container.sh up
```

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
