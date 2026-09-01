FROM ghcr.io/rocker-org/binder:latest

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive
ENV NCPUS=-1
ENV RENV_CONFIG_REPOS_OVERRIDE="https://p3m.dev/cran/__linux__/noble/latest"

# 1. System prerequisites, P3M configuration, and directory setup (Root)
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    atop \
    bashtop \
    ca-certificates \
    cmake \
    curl \
    default-libmysqlclient-dev \
    dialog \
    fish \
    gdal-bin \
    gh \
    git \
    glances \
    gnupg \
    gsfonts \
    htop \
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
    lfm \
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
    mc \
    micro \
    nano \
    ncdu \
    netcdf-bin \
    nmon \
    openssh-client \
    p7zip-full \
    p7zip-rar \
    poppler-data \
    protobuf-compiler \
    python3-pip \
    python3-venv \
    screen \
    smem \
    sqlite3 \
    sudo \
    tesseract-ocr-eng \
    time \
    tk-dev \
    tmux \
    tree \
    unixodbc-dev \
    wget \
    xdg-utils \
    xz-utils \
    zlib1g-dev && \
    # Set fish as default shell
    usermod -s /usr/bin/fish ${NB_USER} && \
    # Install Quarto
    QUARTO_ARCH=$(dpkg --print-architecture) && \
    curl -LO https://quarto.org/download/latest/quarto-linux-${QUARTO_ARCH}.deb && \
    dpkg -i quarto-linux-${QUARTO_ARCH}.deb && \
    rm quarto-linux-${QUARTO_ARCH}.deb && \
    # Configure Posit Public Package Manager for binary packages
    . /etc/os-release && \
    echo "options(repos = c(CRAN = \"https://p3m.dev/cran/__linux__/${VERSION_CODENAME}/latest\"))" >> /usr/lib/R/etc/Rprofile.site && \
    # Setup directories
    mkdir -p /opt/share/code-server \
             /home/${NB_USER}/.local/bin \
             /home/${NB_USER}/.local/state/opencode \
             /home/${NB_USER}/project && \
    chown -R ${NB_USER} /opt/share/code-server /home/${NB_USER}/.local /home/${NB_USER}/project && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 1.1 Enable httpgd plot device automatically when running interactively in VS Code / Codespaces
RUN echo 'if (interactive() && (Sys.getenv("TERM_PROGRAM") == "vscode" || Sys.getenv("CODESPACES") == "true")) {' >> /usr/lib/R/etc/Rprofile.site \
    && echo '  if (requireNamespace("httpgd", quietly = TRUE)) {' >> /usr/lib/R/etc/Rprofile.site \
    && echo '    options(vsc.plot = FALSE)' >> /usr/lib/R/etc/Rprofile.site \
    && echo '    options(device = httpgd::hgd)' >> /usr/lib/R/etc/Rprofile.site \
    && echo '  }' >> /usr/lib/R/etc/Rprofile.site \
    && echo '}' >> /usr/lib/R/etc/Rprofile.site

# Add a build argument to invalidate the cache for CLI tool installations
ARG CACHE_BUSTER=1

# 2. Global CLI tools installation (Root)
RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/home/${NB_USER}/.local/bin sh && \
    curl -fsSL https://claude.ai/install.sh | CI=1 bash && \
    curl -fsSL https://nca-cli.com/install | bash || echo "NCA CLI not available for this architecture, skipping." && \
    curl --proto '=https' --tlsv1.2 -LsSf https://github.com/eitsupi/arf/releases/latest/download/arf-console-installer.sh | sh && \
    rm -rf /home/${NB_USER}/.cache/uv

# 3. Install Rust toolchain for modern R packages
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# Configure code-server env vars
ENV CODE_EXTENSIONSDIR="/opt/share/code-server"
ENV CODE_USERDATADIR="/home/${NB_USER}/.local/share/code-server"
ENV CODE_WORKINGDIR="/home/${NB_USER}/project"
ENV NVM_DIR="/home/${NB_USER}/.nvm"
ENV PATH="/home/${NB_USER}/.local/bin:/home/${NB_USER}/.nvm/versions/node/default/bin:/home/${NB_USER}/.cargo/bin:${PATH}"

# 4. User-level installations (Node, NPM packages, Python tools, Extensions)
USER ${NB_USER}
WORKDIR /home/${NB_USER}

RUN mkdir -p /home/${NB_USER}/.config/fish && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install 24 && \
    nvm alias default 24 && \
    ln -s $(nvm which 24 | sed 's/\/bin\/node//') $NVM_DIR/versions/node/default && \
    npm install -g opencode-ai @google/gemini-cli @mariozechner/pi-coding-agent @openai/codex codeburn && \
    npm cache clean --force && \
    # Install aider
    python3 -m pip install --user aider-install && \
    aider-install --yes && \
    # Install Antigravity CLI
    curl -fsSL https://antigravity.google/cli/install.sh | bash && \
    # Extension management
    code-server --extensions-dir ${CODE_EXTENSIONSDIR} --uninstall-extension saoudrizwan.claude-dev || true && \
    code-server --extensions-dir ${CODE_EXTENSIONSDIR} --uninstall-extension cline.cline || true && \
    for ext in \
        AbdulkaderSafi.file-explorer \
        sst-dev.opencode \
        chrisdias.vscode-opennewinstance \
        FedaykinDev.openchamber \
        ms-vscode.live-server \
        ritwickdey.LiveServer \
        posit.air-vscode \
        posit.shiny \
        quarto.quarto \
        reditorsupport.r \
        reditorsupport.r-syntax \
        mathematic.vscode-pdf; do \
      code-server --extensions-dir ${CODE_EXTENSIONSDIR} --install-extension $ext --force || echo "Failed to install $ext on code-server"; \
    done && \
    # Final cleanup
    rm -rf ${CODE_USERDATADIR}/CachedExtensionVSIXs \
           ${CODE_USERDATADIR}/CachedExtensions \
           ${CODE_EXTENSIONSDIR}/.obsolete \
           /home/${NB_USER}/.cache/pip \
           /home/${NB_USER}/.npm \
           $NVM_DIR/.cache

# NVIDIA NIM (OpenAI-compatible) configuration for nca
ENV NCA_PROVIDER_OPENAI_BASE_URL="https://integrate.api.nvidia.com/v1"
ENV NCA_PROVIDER_OPENAI_MODEL="minimaxai/minimax-m2.7"

# Add an alias to the user's bashrc
RUN echo "alias nca-nvidia='NCA_PROVIDER=openai OPENAI_BASE_URL=\${NCA_PROVIDER_OPENAI_BASE_URL} NCA_MODEL=\${NCA_PROVIDER_OPENAI_MODEL} nca'" >> /home/${NB_USER}/.bashrc

RUN code-server --extensions-dir ${CODE_EXTENSIONSDIR} --list-extensions
