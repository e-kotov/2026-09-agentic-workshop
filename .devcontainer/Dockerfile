FROM rocker/r-ver:latest

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive
ENV NCPUS=-1
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV RENV_CONFIG_REPOS_OVERRIDE="https://p3m.dev/cran/__linux__/noble/latest"


# 1. Create a non-root user (vscode) early and install essential tools including sudo
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN apt-get update && apt-get install -y --no-install-recommends \
    atop \
    bashtop \
    ca-certificates \
    curl \
    dialog \
    fish \
    gh \
    git \
    glances \
    gnupg \
    htop \
    lfm \
    mc \
    micro \
    nano \
    ncdu \
    nmon \
    openssh-client \
    p7zip-full \
    p7zip-rar \
    screen \
    sudo \
    time \
    tmux \
    tree \
    wget \
    xdg-utils \
    xz-utils \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /usr/bin/fish $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Combine all system prerequisites for Tidyverse, Geospatial, and httpgd into a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    default-libmysqlclient-dev \
    gdal-bin \
    gsfonts \
    lbzip2 \
    libcairo2-dev \
    libcurl4-openssl-dev \
    libdbus-1-dev \
    libfftw3-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libfribidi-dev \
    libgdal-dev \
    libgeos-dev \
    libgit2-dev \
    libgl1-mesa-dev \
    libglpk-dev \
    libglu1-mesa-dev \
    libgsl-dev \
    libharfbuzz-dev \
    libhdf4-alt-dev \
    libhdf5-dev \
    libicu-dev \
    libjpeg-dev \
    libjq-dev \
    libleptonica-dev \
    libmagick++-dev \
    libmbedtls-dev \
    libnetcdf-dev \
    libnode-dev \
    libomp-dev \
    libpng-dev \
    libpoppler-cpp-dev \
    libpq-dev \
    libproj-dev \
    libprotobuf-dev \
    libsasl2-dev \
    # libsecret-1-dev is for keyring r package
    libsecret-1-dev \
    libsodium-dev \
    libsqlite3-dev \
    libssh2-1-dev \
    libssl-dev \
    libtesseract-dev \
    libtiff-dev \
    libudunits2-dev \
    libuv1-dev \
    libwebp-dev \
    libxml2-dev \
    libxtst6 \
    libzmq3-dev \
    make \
    netcdf-bin \
    poppler-data \
    protobuf-compiler \
    python3-pip \
    python3-venv \
    smem \
    sqlite3 \
    tesseract-ocr-eng \
    tk-dev \
    unixodbc-dev \
    zlib1g-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2.1 Install Quarto
RUN QUARTO_ARCH=$(dpkg --print-architecture) && \
    curl -LO https://quarto.org/download/latest/quarto-linux-${QUARTO_ARCH}.deb && \
    sudo dpkg -i quarto-linux-${QUARTO_ARCH}.deb && \
    rm quarto-linux-${QUARTO_ARCH}.deb

# 3. Configure Posit Public Package Manager for binary packages
RUN . /etc/os-release && \
    echo "options(repos = c(CRAN = \"https://p3m.dev/cran/__linux__/${VERSION_CODENAME}/latest\"))" >> /usr/local/lib/R/etc/Rprofile.site

# 4. Install Rust toolchain for modern R packages
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# 5. Install essential R packages for VS Code and development
RUN install2.r --error --skipmissing --skipinstalled -n "$NCPUS" \
    languageserver \
    httpgd \
    jsonlite \
    rlang \
    devtools \
    rmarkdown \
    BiocManager \
    && rm -rf /tmp/downloaded_packages

# Enable httpgd plot device automatically when running interactively in VS Code / Codespaces
RUN echo 'if (interactive() && (Sys.getenv("TERM_PROGRAM") == "vscode" || Sys.getenv("CODESPACES") == "true")) {' >> /usr/local/lib/R/etc/Rprofile.site \
    && echo '  if (requireNamespace("httpgd", quietly = TRUE)) {' >> /usr/local/lib/R/etc/Rprofile.site \
    && echo '    options(vsc.plot = FALSE)' >> /usr/local/lib/R/etc/Rprofile.site \
    && echo '    options(device = httpgd::hgd)' >> /usr/local/lib/R/etc/Rprofile.site \
    && echo '  }' >> /usr/local/lib/R/etc/Rprofile.site \
    && echo '}' >> /usr/local/lib/R/etc/Rprofile.site

# 6. Switch to the non-root user to install Python and environment managers securely
USER $USERNAME
WORKDIR /home/$USERNAME

# NVIDIA NIM (OpenAI-compatible) configuration for nca
ENV NCA_PROVIDER_OPENAI_BASE_URL="https://integrate.api.nvidia.com/v1"
ENV NCA_PROVIDER_OPENAI_MODEL="minimaxai/minimax-m2.7"
ENV NVM_DIR="/home/$USERNAME/.nvm"

# Add an alias to the user's bashrc for nca-nvidia
RUN echo "alias nca-nvidia='NCA_PROVIDER=openai OPENAI_BASE_URL=\${NCA_PROVIDER_OPENAI_BASE_URL} NCA_MODEL=\${NCA_PROVIDER_OPENAI_MODEL} nca'" >> /home/$USERNAME/.bashrc

# Ensure all tools are in the PATH for the user session
ENV PATH="/home/$USERNAME/.local/bin:/home/$USERNAME/miniforge3/bin:/home/$USERNAME/.pixi/bin:/home/$USERNAME/.cargo/bin:$NVM_DIR/versions/node/default/bin:${PATH}"

# Add a build argument to invalidate the cache for CLI tool installations
ARG CACHE_BUSTER=1

# Install all CLI tools in a single layer to minimize metadata and clean caches
RUN mkdir -p /home/$USERNAME/.config/fish && \
    curl -fsSL -o /tmp/miniforge.sh https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh && \
    bash /tmp/miniforge.sh -b -p /home/$USERNAME/miniforge3 && \
    rm /tmp/miniforge.sh && \
    /home/$USERNAME/miniforge3/bin/conda init bash && \
    /home/$USERNAME/miniforge3/bin/conda clean -afy && \
    # Install nvm and node
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install 24 && \
    nvm alias default 24 && \
    ln -s $(nvm which 24 | sed 's/\/bin\/node//') $NVM_DIR/versions/node/default && \
    nvm cache clear && \
    npm install -g \
        opencode-ai \
        @google/gemini-cli \
        @mariozechner/pi-coding-agent \
        @openai/codex \
        codeburn && \
    npm cache clean --force && \
    # Install uv (defaults to ~/.local/bin)
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    export PATH="/home/$USERNAME/.local/bin:$PATH" && \
    # Install Claude CLI
    curl -fsSL https://claude.ai/install.sh | CI=1 bash && \
    # Install NCA CLI
    (curl -fsSL https://nca-cli.com/install | bash || echo "NCA CLI not available for this architecture, skipping.") && \
    # Install pixi (defaults to ~/.pixi/bin)
    curl -fsSL https://pixi.sh/install.sh | bash && \
    # Install Antigravity CLI
    curl -fsSL https://antigravity.google/cli/install.sh | bash && \
    # Install arf console to user's home directory
    curl --proto '=https' --tlsv1.2 -LsSf https://github.com/eitsupi/arf/releases/latest/download/arf-console-installer.sh | CARGO_HOME=/home/$USERNAME/.cargo sh && \
    # Install aider
    uv tool install aider-chat --python python3 && \
    # Cleanup user caches and unnecessary files
    rm -rf /home/$USERNAME/.cache/uv /home/$USERNAME/.cache/pip /home/$USERNAME/.npm/_cacache $NVM_DIR/.cache $NVM_DIR/src $NVM_DIR/test

# Set the default workspace directory
WORKDIR /workspace
