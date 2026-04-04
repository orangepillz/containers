# OpenClaw Container

The OpenClaw image is a source-based Node 24 + `pnpm` container for the upstream [`openclaw/openclaw`](https://github.com/openclaw/openclaw) repo, with the GitHub CLI (`gh`) included in the base image.

## Commands

```bash
./images/openclaw/container.sh build
./images/openclaw/container.sh create
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

## Environment

```bash
OPENCLAW_NAME=openclaw-dev
OPENCLAW_IMAGE=openclaw-dev:latest
OPENCLAW_MEMORY=8g
OPENCLAW_CPUS=4
OPENCLAW_BUILDER_MEMORY=8g
OPENCLAW_BUILDER_CPUS=4
OPENCLAW_HOME_VOLUME=openclaw-dev-home
OPENCLAW_DOCKER_VOLUME=openclaw-dev-docker
OPENCLAW_HOME_VOLUME_SIZE=
OPENCLAW_DOCKER_VOLUME_SIZE=
OPENCLAW_NODE_MAJOR=24
OPENCLAW_DIR=/home/dev/openclaw
OPENCLAW_UPSTREAM_URL=https://github.com/openclaw/openclaw.git
OPENCLAW_REF=main
```

`setup-openclaw` clones or fast-forwards the upstream checkout in `/home/dev/openclaw`, skips pulling when the checkout is dirty, then runs `pnpm install`, `pnpm ui:build`, and `pnpm build`. `onboard-openclaw` runs `pnpm openclaw onboard` without daemon installation, and `run-openclaw` starts `pnpm openclaw gateway --verbose` in the foreground.

`OPENCLAW_HOME_VOLUME_SIZE` and `OPENCLAW_DOCKER_VOLUME_SIZE` are applied when their named volumes are first created. If you reuse an existing volume name, the wrapper keeps that existing volume and its existing size.
