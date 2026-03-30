# Apple `container` Images

This repo is organized around multiple long-lived Apple [`container`](https://github.com/apple/container) targets.

Common behavior lives in:

- `shared/host/` for the host-side Apple `container` lifecycle library
- `shared/guest/` for guest bootstrap assets shared by every image

Available container targets:

- `images/dev/`
  - wrapper: `./images/dev/container.sh`
  - docs: `./images/dev/README.md`
- `images/openclaw/`
  - wrapper: `./images/openclaw/container.sh`
  - docs: `./images/openclaw/README.md`

## Requirements

- Apple silicon
- macOS 26 or newer
- `container` CLI version `0.10.0` or newer

Both wrappers fail fast on unsupported hosts and keep the same isolation model:

- no host source directory mounts
- no shared host Docker socket
- persistent named volumes for `/home/dev` and `/var/lib/docker`
- a guest-local Docker daemon started by the shared entrypoint

## Targets

### Dev

```bash
./images/dev/container.sh build
./images/dev/container.sh up
./images/dev/container.sh shell
./images/dev/container.sh setup-git-ssh
./images/dev/container.sh setup-symphony
./images/dev/container.sh run-symphony
./images/dev/container.sh run-symphony --port 4000
./images/dev/container.sh stop
./images/dev/container.sh destroy
./images/dev/container.sh destroy --purge
./images/dev/container.sh status
```

### OpenClaw

```bash
./images/openclaw/container.sh build
./images/openclaw/container.sh up
./images/openclaw/container.sh shell
./images/openclaw/container.sh setup-git-ssh
./images/openclaw/container.sh setup-openclaw
./images/openclaw/container.sh onboard-openclaw
./images/openclaw/container.sh run-openclaw
./images/openclaw/container.sh run-openclaw --port 18789
./images/openclaw/container.sh stop
./images/openclaw/container.sh destroy
./images/openclaw/container.sh destroy --purge
./images/openclaw/container.sh status
```

Use the per-image READMEs for image-specific setup details and environment variables.
