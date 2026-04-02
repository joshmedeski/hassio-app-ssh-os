ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install core packages
RUN apk add --no-cache \
    openssh \
    tmux \
    neovim \
    fish \
    git \
    curl \
    ripgrep \
    fd \
    fzf \
    build-base \
    nodejs \
    npm \
    python3 \
    unzip

# Install starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Set fish as default shell
RUN sed -i 's|root:x:0:0:root:/root:.*|root:x:0:0:root:/root:/usr/bin/fish|' /etc/passwd

# Copy filesystem overlay
COPY rootfs /
