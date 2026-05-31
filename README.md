# Apple `container` Images

This repo is organized around a unified long-lived Apple [`container`](https://github.com/apple/container) dev image.

Common behavior lives in:

- `shared/host/` for the host-side Apple `container` lifecycle library
- `shared/guest/` for guest bootstrap assets shared by every image

Available container targets:

- `images/dev/`
  - wrapper: `./images/dev/container.sh`
  - docs: `./images/dev/README.md`

## Requirements

- Apple silicon
- macOS 26 or newer
- `container` CLI version `0.10.0` or newer

The wrapper fails fast on unsupported hosts and keeps the same isolation model:

- no host source directory mounts
- no shared host Docker socket
- persistent named volumes for `/home/dev` and `/var/lib/docker`
- a guest-local Docker daemon started by the shared entrypoint

## Dev Container

The unified dev container includes Swift, Symphony, OpenClaw, Hermes, Claude Code, Codex, and Codex Profiles.

```bash
./images/dev/container.sh build
./images/dev/container.sh up
./images/dev/container.sh shell
./images/dev/container.sh setup-git-ssh
./images/dev/container.sh setup-symphony
./images/dev/container.sh run-symphony
./images/dev/container.sh run-symphony --port 4000
./images/dev/container.sh setup-openclaw
./images/dev/container.sh onboard-openclaw
./images/dev/container.sh run-openclaw
./images/dev/container.sh run-openclaw --port 18789
./images/dev/container.sh xcode-status
./images/dev/container.sh xcodebuild -version
./images/dev/container.sh xcode-bridge-dns
./images/dev/container.sh xcode-bridge-start
./images/dev/container.sh xcode-bridge simctl list devices available
./images/dev/container.sh stop
./images/dev/container.sh destroy
./images/dev/container.sh destroy --purge
./images/dev/container.sh status
```

The dev wrapper also syncs the host `${HOME}/.zshrc` and `${HOME}/.codex/skills` into a per-container host config directory. The guest sources the zsh config from `/home/dev/.zshrc` and copies skills into `/home/dev/.codex/skills`.

Xcode, Command Line Tools, Apple SDKs, and Simulator binaries remain on the macOS host because this image is an Ubuntu guest. The dev wrapper includes direct host passthrough commands for `xcodebuild`, `xcrun`, and `xcrun simctl`, plus a token-protected Xcode bridge sidecar that lets commands inside the guest invoke those host tools through `/xcode-bridge`.

Use the per-image README for image-specific setup details and environment variables.
