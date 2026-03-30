FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG GO_VERSION=1.24.2
ARG NODE_MAJOR=22
ARG MISE_VERSION=v2025.11.11
ARG ERLANG_VERSION=28
ARG ELIXIR_VERSION=1.19.5-otp-28
ARG DEV_USER=dev
ARG DEV_UID=1000
ARG DEV_GID=1000

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    autoconf \
    bash-completion \
    build-essential \
    ca-certificates \
    curl \
    default-jdk-headless \
    file \
    fop \
    git \
    gnupg \
    iproute2 \
    iptables \
    jq \
    less \
    libncurses-dev \
    libssl-dev \
    libxml2-utils \
    m4 \
    openssh-client \
    pkg-config \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
    uidmap \
    unzip \
    unixodbc-dev \
    xsltproc \
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

RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-arm64.tar.gz" -o /tmp/go.tgz \
 && rm -rf /usr/local/go \
 && tar -C /usr/local -xzf /tmp/go.tgz \
 && rm -f /tmp/go.tgz

RUN npm install -g @openai/codex

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
ENV MISE_DATA_DIR="/usr/local/share/mise"
ENV SYMPHONY_DIR="/home/dev/symphony"
ENV SYMPHONY_CONFIG_DIR="/home/dev/.config/symphony"
ENV SYMPHONY_WORKSPACE_ROOT="/home/dev/code/symphony-workspaces"
ENV GIT_SSH_HOST="github.com"

RUN install -d -m 0755 /home/linuxbrew \
 && chown -R "${DEV_USER}:${DEV_USER}" /home/linuxbrew \
 && su - "${DEV_USER}" -c 'NONINTERACTIVE=1 CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' \
 && /bin/bash -lc 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew --version >/dev/null'

RUN install -d -m 0755 /etc/mise "${MISE_DATA_DIR}" /usr/local/share/devbox/symphony \
 && curl -fsSL https://mise.run | MISE_VERSION="${MISE_VERSION}" MISE_INSTALL_PATH=/usr/local/bin/mise sh \
 && printf '%s\n' \
    '[tools]' \
    "erlang = \"${ERLANG_VERSION}\"" \
    "elixir = \"${ELIXIR_VERSION}\"" \
    > /etc/mise/config.toml \
 && chmod 0644 /etc/mise/config.toml \
 && mise install \
 && ln -sf "$(mise which elixir)" /usr/local/bin/elixir \
 && ln -sf "$(mise which mix)" /usr/local/bin/mix \
 && ln -sf "$(mise which erl)" /usr/local/bin/erl

RUN printf '%s\n' \
    'export GOPATH="${GOPATH:-$HOME/go}"' \
    'export PATH="/usr/local/go/bin:${GOPATH}/bin:${PATH}"' \
    'export DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"' \
    'export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"' \
    'export HOMEBREW_CELLAR="${HOMEBREW_CELLAR:-${HOMEBREW_PREFIX}/Cellar}"' \
    'export HOMEBREW_REPOSITORY="${HOMEBREW_REPOSITORY:-${HOMEBREW_PREFIX}/Homebrew}"' \
    'export MISE_DATA_DIR="${MISE_DATA_DIR:-/usr/local/share/mise}"' \
    'export SYMPHONY_DIR="${SYMPHONY_DIR:-/home/dev/symphony}"' \
    'export SYMPHONY_CONFIG_DIR="${SYMPHONY_CONFIG_DIR:-/home/dev/.config/symphony}"' \
    'export SYMPHONY_WORKSPACE_ROOT="${SYMPHONY_WORKSPACE_ROOT:-/home/dev/code/symphony-workspaces}"' \
    'export GIT_SSH_HOST="${GIT_SSH_HOST:-github.com}"' \
    'if [ -x "${HOMEBREW_PREFIX}/bin/brew" ]; then' \
    '  eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' \
    'fi' \
    'if command -v mise >/dev/null 2>&1; then' \
    '  eval "$(mise activate bash)"' \
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

COPY images/dev/templates/symphony /usr/local/share/devbox/symphony
COPY shared/guest/entrypoint.sh /usr/local/bin/container-entrypoint
COPY shared/guest/setup-git-ssh.sh /usr/local/bin/setup-git-ssh
COPY images/dev/guest/setup-symphony.sh /usr/local/bin/setup-symphony
COPY images/dev/guest/run-symphony.sh /usr/local/bin/run-symphony

RUN chmod 0755 /usr/local/bin/container-entrypoint \
 && chmod 0755 /usr/local/bin/setup-git-ssh \
 && chmod 0755 /usr/local/bin/setup-symphony \
 && chmod 0755 /usr/local/bin/run-symphony \
 && install -d /var/lib/docker \
 && chown -R "${DEV_USER}:${DEV_USER}" /home/linuxbrew \
 && chown -R "${DEV_USER}:${DEV_USER}" "${MISE_DATA_DIR}" \
 && chown -R "${DEV_USER}:${DEV_USER}" "/home/${DEV_USER}"

ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/dev/go"
ENV DOCKER_HOST="unix:///var/run/docker.sock"

VOLUME ["/home/dev", "/var/lib/docker"]

ENTRYPOINT ["/usr/local/bin/container-entrypoint"]
