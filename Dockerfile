FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG GO_VERSION=1.24.2
ARG NODE_MAJOR=22
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
    git \
    gnupg \
    iproute2 \
    iptables \
    jq \
    less \
    openssh-client \
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

RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-arm64.tar.gz" -o /tmp/go.tgz \
 && rm -rf /usr/local/go \
 && tar -C /usr/local -xzf /tmp/go.tgz \
 && rm -f /tmp/go.tgz

RUN npm install -g @openai/codex

RUN groupadd --gid "${DEV_GID}" "${DEV_USER}" \
 && useradd --uid "${DEV_UID}" --gid "${DEV_GID}" --create-home --shell /bin/bash "${DEV_USER}" \
 && usermod -aG sudo,docker "${DEV_USER}" \
 && echo "${DEV_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${DEV_USER}" \
 && chmod 0440 "/etc/sudoers.d/${DEV_USER}"

RUN printf '%s\n' \
    'export GOPATH="${GOPATH:-$HOME/go}"' \
    'export PATH="/usr/local/go/bin:${GOPATH}/bin:${PATH}"' \
    'export DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"' \
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

COPY scripts/entrypoint.sh /usr/local/bin/devbox-entrypoint

RUN chmod 0755 /usr/local/bin/devbox-entrypoint \
 && install -d /var/lib/docker \
 && chown -R "${DEV_USER}:${DEV_USER}" "/home/${DEV_USER}"

ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/dev/go"
ENV DOCKER_HOST="unix:///var/run/docker.sock"

VOLUME ["/home/dev", "/var/lib/docker"]

ENTRYPOINT ["/usr/local/bin/devbox-entrypoint"]
