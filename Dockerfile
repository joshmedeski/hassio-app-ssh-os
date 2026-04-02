ARG BUILD_FROM
ARG BUILD_ARCH
FROM ghcr.io/home-assistant/${BUILD_ARCH}-hassio-cli AS cli
FROM ${BUILD_FROM}

# Pinned versions (update these when upgrading)
ARG SESH_VERSION=2.24.2
ARG STARSHIP_VERSION=1.24.2
ARG HASS_LSP_VERSION=2.2.0

# Install core packages (pinned to Alpine 3.21)
# Neovim 0.11+ from edge for built-in LSP support
RUN apk add --no-cache \
    openssh=~9.9 \
    tmux=~3.5a \
    fish=~3.7.1 \
    git=~2.47 \
    curl=~8.14 \
    ripgrep=~14.1 \
    fd=~10.2 \
    fzf=~0.56 \
    build-base \
    nodejs=~22.15 \
    npm \
    python3=~3.12 \
    mosh-server \
    unzip \
    sqlite && \
    apk add --no-cache --upgrade \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
    libuv neovim=~0.11.7

# Install sesh (smart tmux session manager)
RUN ARCH="$(uname -m)" && \
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi && \
    curl -sL "https://github.com/joshmedeski/sesh/releases/download/v${SESH_VERSION}/sesh_Linux_${ARCH}.tar.gz" \
    | tar xz -C /usr/local/bin sesh

# Install starship prompt
RUN curl -sS https://starship.rs/install.sh -o /tmp/starship-install.sh && \
    sh /tmp/starship-install.sh --yes --version "v${STARSHIP_VERSION}" && \
    rm /tmp/starship-install.sh

# Build Home Assistant language server
RUN curl -sL "https://github.com/keesschollaart81/vscode-home-assistant/archive/refs/tags/v${HASS_LSP_VERSION}.tar.gz" \
    | tar xz -C /tmp && \
    cd /tmp/vscode-home-assistant-${HASS_LSP_VERSION} && \
    npm ci --ignore-scripts && \
    npx tsc -p . && \
    mkdir -p /opt/hass-lsp && \
    cp -r out/server node_modules /opt/hass-lsp/ && \
    rm -rf /tmp/vscode-home-assistant-*

# Set fish as default shell
RUN sed -i 's|root:x:0:0:root:/root:.*|root:x:0:0:root:/root:/usr/bin/fish|' /etc/passwd

# Install Home Assistant CLI
COPY --from=cli /usr/bin/ha /usr/bin/ha

# Copy filesystem overlay
COPY rootfs /
