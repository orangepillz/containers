FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG GO_VERSION=1.24.2
ARG NODE_MAJOR=24
ARG SWIFT_VERSION=6.3.1
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
    gnupg2 \
    iproute2 \
    iptables \
    jq \
    less \
    libc6-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libgcc-13-dev \
    libncurses-dev \
    libpython3-dev \
    libsqlite3-0 \
    libssl-dev \
    libstdc++-13-dev \
    libxml2-dev \
    libxml2-utils \
    libz3-dev \
    m4 \
    ffmpeg \
    openssh-client \
    pkg-config \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    rsync \
    sudo \
    tzdata \
    uidmap \
    unzip \
    unixodbc-dev \
    xsltproc \
    xz-utils \
    zip \
    zsh \
    zlib1g-dev \
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

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    -o /etc/apt/keyrings/githubcli.gpg \
 && chmod a+r /etc/apt/keyrings/githubcli.gpg \
 && arch="$(dpkg --print-architecture)" \
 && echo \
    "deb [arch=${arch} signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list

RUN curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
    | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
 && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
    > /etc/apt/sources.list.d/ngrok.list

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    containerd.io \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    gh \
    ngrok \
    nodejs \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-arm64.tar.gz" -o /tmp/go.tgz \
 && rm -rf /usr/local/go \
 && tar -C /usr/local -xzf /tmp/go.tgz \
 && rm -f /tmp/go.tgz

RUN set -eux \
 && swift_release="swift-${SWIFT_VERSION}-RELEASE" \
 && swift_platform="ubuntu24.04-aarch64" \
 && swift_archive="${swift_release}-${swift_platform}.tar.gz" \
 && swift_base_url="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404-aarch64/${swift_release}" \
 && install -d -m 0755 /opt/swift \
 && curl -fsSL "${swift_base_url}/${swift_archive}" -o "/tmp/${swift_archive}" \
 && curl -fsSL "${swift_base_url}/${swift_archive}.sig" -o "/tmp/${swift_archive}.sig" \
 && curl -fsSL https://www.swift.org/keys/all-keys.asc | gpg --batch --import - \
 && gpg --batch --verify "/tmp/${swift_archive}.sig" "/tmp/${swift_archive}" \
 && tar -C /opt/swift --strip-components=1 -xzf "/tmp/${swift_archive}" \
 && rm -f "/tmp/${swift_archive}" "/tmp/${swift_archive}.sig" \
 && /opt/swift/usr/bin/swift --version

RUN npm install -g @openai/codex @anthropic-ai/claude-code \
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
      useradd_args=(--gid "${DEV_USER}" --create-home --shell /usr/bin/zsh); \
      if ! getent passwd "${DEV_UID}" >/dev/null; then \
        useradd_args+=(--uid "${DEV_UID}"); \
      fi; \
      useradd "${useradd_args[@]}" "${DEV_USER}"; \
    else \
      usermod --home "/home/${DEV_USER}" --shell /usr/bin/zsh "${DEV_USER}"; \
    fi \
 && usermod -aG sudo,docker "${DEV_USER}" \
 && install -d -m 0755 /etc/sudoers.d \
 && echo "${DEV_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${DEV_USER}" \
 && chmod 0440 "/etc/sudoers.d/${DEV_USER}"

ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
ENV MISE_DATA_DIR="/usr/local/share/mise"
ENV SWIFT_ROOT="/opt/swift"
ENV SYMPHONY_DIR="/home/dev/symphony"
ENV SYMPHONY_CONFIG_DIR="/home/dev/.config/symphony"
ENV SYMPHONY_WORKSPACE_ROOT="/home/dev/code/symphony-workspaces"
ENV OPENCLAW_DIR="/home/dev/openclaw"
ENV OPENCLAW_UPSTREAM_URL="https://github.com/openclaw/openclaw.git"
ENV OPENCLAW_REF="main"
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

RUN curl -fsSL https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh \
 && uv python install 3.11 \
 && git clone https://github.com/NousResearch/hermes-agent.git /opt/hermes-agent \
 && cd /opt/hermes-agent \
 && uv venv venv --python 3.11 \
 && . venv/bin/activate \
 && uv pip install -e ".[all]" \
 && ln -sf /opt/hermes-agent/venv/bin/hermes /usr/local/bin/hermes

RUN printf '%s\n' \
    'export GOPATH="${GOPATH:-$HOME/go}"' \
    'export SWIFT_ROOT="${SWIFT_ROOT:-/opt/swift}"' \
    'export PATH="${SWIFT_ROOT}/usr/bin:/usr/local/go/bin:${GOPATH}/bin:${PATH}"' \
    'export DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"' \
    'export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"' \
    'export HOMEBREW_CELLAR="${HOMEBREW_CELLAR:-${HOMEBREW_PREFIX}/Cellar}"' \
    'export HOMEBREW_REPOSITORY="${HOMEBREW_REPOSITORY:-${HOMEBREW_PREFIX}/Homebrew}"' \
    'export MISE_DATA_DIR="${MISE_DATA_DIR:-/usr/local/share/mise}"' \
    'export SYMPHONY_DIR="${SYMPHONY_DIR:-/home/dev/symphony}"' \
    'export SYMPHONY_CONFIG_DIR="${SYMPHONY_CONFIG_DIR:-/home/dev/.config/symphony}"' \
    'export SYMPHONY_WORKSPACE_ROOT="${SYMPHONY_WORKSPACE_ROOT:-/home/dev/code/symphony-workspaces}"' \
    'export OPENCLAW_DIR="${OPENCLAW_DIR:-/home/dev/openclaw}"' \
    'export OPENCLAW_UPSTREAM_URL="${OPENCLAW_UPSTREAM_URL:-https://github.com/openclaw/openclaw.git}"' \
    'export OPENCLAW_REF="${OPENCLAW_REF:-main}"' \
    'export GIT_SSH_HOST="${GIT_SSH_HOST:-github.com}"' \
    'export XCODE_BRIDGE_MOUNT="${XCODE_BRIDGE_MOUNT:-/xcode-bridge}"' \
    'if [ -x "${HOMEBREW_PREFIX}/bin/brew" ]; then' \
    '  eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' \
    'fi' \
    'if command -v mise >/dev/null 2>&1; then' \
    '  if [ -n "${ZSH_VERSION:-}" ]; then' \
    '    eval "$(mise activate zsh)"' \
    '  else' \
    '    eval "$(mise activate bash)"' \
    '  fi' \
    'fi' \
    'if [ -r "${XCODE_BRIDGE_MOUNT}/bridge.env" ]; then' \
    '  . "${XCODE_BRIDGE_MOUNT}/bridge.env"' \
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
    'if [ -f /etc/profile.d/devbox-paths.sh ]; then' \
    '  . /etc/profile.d/devbox-paths.sh' \
    'fi' \
    '' \
    '# >>> dev-container host zshrc >>>' \
    'if [ -f "$HOME/.host.zshrc" ]; then' \
    '  source "$HOME/.host.zshrc"' \
    'fi' \
    '# <<< dev-container host zshrc <<<' \
    > /usr/local/share/dev-home-skel/.zshrc \
 && printf '%s\n' \
    'if [ -f "$HOME/.bashrc" ]; then' \
    '  . "$HOME/.bashrc"' \
    'fi' \
    > /usr/local/share/dev-home-skel/.bash_profile \
 && cp /usr/local/share/dev-home-skel/.bash_profile /usr/local/share/dev-home-skel/.profile \
 && printf '%s\n' \
    '# zsh reads .zshrc for interactive shells.' \
    > /usr/local/share/dev-home-skel/.zprofile

COPY images/dev/templates/symphony /usr/local/share/devbox/symphony
COPY shared/guest/entrypoint.sh /usr/local/bin/container-entrypoint
COPY shared/guest/setup-git-ssh.sh /usr/local/bin/setup-git-ssh
COPY shared/guest/xcode-bridge /usr/local/bin/xcode-bridge
COPY images/dev/guest/setup-symphony.sh /usr/local/bin/setup-symphony
COPY images/dev/guest/run-symphony.sh /usr/local/bin/run-symphony
COPY images/dev/guest/setup-openclaw.sh /usr/local/bin/setup-openclaw
COPY images/dev/guest/onboard-openclaw.sh /usr/local/bin/onboard-openclaw
COPY images/dev/guest/run-openclaw.sh /usr/local/bin/run-openclaw

RUN chmod 0755 /usr/local/bin/container-entrypoint \
 && chmod 0755 /usr/local/bin/setup-git-ssh \
 && chmod 0755 /usr/local/bin/xcode-bridge \
 && chmod 0755 /usr/local/bin/setup-symphony \
 && chmod 0755 /usr/local/bin/run-symphony \
 && chmod 0755 /usr/local/bin/setup-openclaw \
 && chmod 0755 /usr/local/bin/onboard-openclaw \
 && chmod 0755 /usr/local/bin/run-openclaw \
 && ln -sf /usr/local/bin/xcode-bridge /usr/local/bin/xcodebuild \
 && ln -sf /usr/local/bin/xcode-bridge /usr/local/bin/xcrun \
 && ln -sf /usr/local/bin/xcode-bridge /usr/local/bin/simctl \
 && install -d /var/lib/docker \
 && chown -R "${DEV_USER}:${DEV_USER}" /home/linuxbrew \
 && chown -R "${DEV_USER}:${DEV_USER}" "${MISE_DATA_DIR}" \
 && chown -R "${DEV_USER}:${DEV_USER}" "/home/${DEV_USER}"

ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/opt/swift/usr/bin:/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/dev/go"
ENV SWIFT_ROOT="/opt/swift"
ENV DOCKER_HOST="unix:///var/run/docker.sock"

VOLUME ["/home/dev", "/var/lib/docker"]

ENTRYPOINT ["/usr/local/bin/container-entrypoint"]
