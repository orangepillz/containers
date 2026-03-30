FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_MAJOR=24
ARG DEV_USER=dev
ARG DEV_UID=1000
ARG DEV_GID=1000

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bash-completion \
    build-essential \
    ca-certificates \
    curl \
    file \
    git \
    gnupg \
    iproute2 \
    iptables \
    jq \
    less \
    openssh-client \
    pkg-config \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
    uidmap \
    unzip \
    xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg \
 && chmod a+r /etc/apt/keyrings/docker.gpg \
 && . /etc/os-release \
 && arch="$(dpkg --print-architecture)" \
 && echo \
    "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg \
 && chmod a+r /etc/apt/keyrings/nodesource.gpg \
 && echo \
    "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    containerd.io \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    nodejs \
 && rm -rf /var/lib/apt/lists/*

RUN npm install -g @openai/codex \
 && corepack enable \
 && corepack prepare pnpm@latest --activate

RUN set -eux \
 && if ! getent group "${DEV_USER}" >/dev/null; then \
      if getent group "${DEV_GID}" >/dev/null; then \
        groupadd "${DEV_USER}"; \
      else \
        groupadd --gid "${DEV_GID}" "${DEV_USER}"; \
      fi; \
    fi \
 && if ! id -u "${DEV_USER}" >/dev/null 2>&1; then \
      useradd_args=(--gid "${DEV_USER}" --create-home --shell /bin/bash); \
      if ! getent passwd "${DEV_UID}" >/dev/null; then \
        useradd_args+=(--uid "${DEV_UID}"); \
      fi; \
      useradd "${useradd_args[@]}" "${DEV_USER}"; \
    else \
      usermod --home "/home/${DEV_USER}" --shell /bin/bash "${DEV_USER}"; \
    fi \
 && usermod -aG sudo,docker "${DEV_USER}" \
 && install -d -m 0755 /etc/sudoers.d \
 && echo "${DEV_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${DEV_USER}" \
 && chmod 0440 "/etc/sudoers.d/${DEV_USER}"

ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
ENV OPENCLAW_DIR="/home/dev/openclaw"
ENV OPENCLAW_UPSTREAM_URL="https://github.com/openclaw/openclaw.git"
ENV OPENCLAW_REF="main"
ENV GIT_SSH_HOST="github.com"

RUN install -d -m 0755 /home/linuxbrew \
 && chown -R "${DEV_USER}:${DEV_USER}" /home/linuxbrew \
 && su - "${DEV_USER}" -c 'NONINTERACTIVE=1 CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' \
 && /bin/bash -lc 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew --version >/dev/null'

RUN printf '%s\n' \
    'export DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"' \
    'export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"' \
    'export HOMEBREW_CELLAR="${HOMEBREW_CELLAR:-${HOMEBREW_PREFIX}/Cellar}"' \
    'export HOMEBREW_REPOSITORY="${HOMEBREW_REPOSITORY:-${HOMEBREW_PREFIX}/Homebrew}"' \
    'export OPENCLAW_DIR="${OPENCLAW_DIR:-/home/dev/openclaw}"' \
    'export OPENCLAW_UPSTREAM_URL="${OPENCLAW_UPSTREAM_URL:-https://github.com/openclaw/openclaw.git}"' \
    'export OPENCLAW_REF="${OPENCLAW_REF:-main}"' \
    'export GIT_SSH_HOST="${GIT_SSH_HOST:-github.com}"' \
    'if [ -x "${HOMEBREW_PREFIX}/bin/brew" ]; then' \
    '  eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' \
    'fi' \
    > /etc/profile.d/devbox-paths.sh \
 && chmod 0644 /etc/profile.d/devbox-paths.sh \
 && install -d -m 0755 /usr/local/share/dev-home-skel \
 && printf '%s\n' \
    'if [ -f /etc/profile.d/devbox-paths.sh ]; then' \
    '  . /etc/profile.d/devbox-paths.sh' \
    'fi' \
    > /usr/local/share/dev-home-skel/.bashrc \
 && printf '%s\n' \
    'if [ -f "$HOME/.bashrc" ]; then' \
    '  . "$HOME/.bashrc"' \
    'fi' \
    > /usr/local/share/dev-home-skel/.bash_profile \
 && cp /usr/local/share/dev-home-skel/.bash_profile /usr/local/share/dev-home-skel/.profile

COPY shared/guest/entrypoint.sh /usr/local/bin/container-entrypoint
COPY shared/guest/setup-git-ssh.sh /usr/local/bin/setup-git-ssh
COPY images/openclaw/guest/setup-openclaw.sh /usr/local/bin/setup-openclaw
COPY images/openclaw/guest/onboard-openclaw.sh /usr/local/bin/onboard-openclaw
COPY images/openclaw/guest/run-openclaw.sh /usr/local/bin/run-openclaw

RUN chmod 0755 /usr/local/bin/container-entrypoint \
 && chmod 0755 /usr/local/bin/setup-git-ssh \
 && chmod 0755 /usr/local/bin/setup-openclaw \
 && chmod 0755 /usr/local/bin/onboard-openclaw \
 && chmod 0755 /usr/local/bin/run-openclaw \
 && install -d /var/lib/docker \
 && chown -R "${DEV_USER}:${DEV_USER}" /home/linuxbrew \
 && chown -R "${DEV_USER}:${DEV_USER}" "/home/${DEV_USER}"

ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV DOCKER_HOST="unix:///var/run/docker.sock"

VOLUME ["/home/dev", "/var/lib/docker"]

ENTRYPOINT ["/usr/local/bin/container-entrypoint"]
