#!/bin/bash

set -e

UPGRADE_PACKAGES="${UPGRADEPACKAGES:-"true"}"
ADD_EZA="${ADDEZA:-"false"}"
ADD_GITLEAKS="${ADDGITLEAKS:-"false"}"
ADD_GRAPHIFY="${ADDGRAPHIFY:-"false"}"
ADD_GRPCURL="${ADDGRPCURL:-"false"}"
ADD_HADOLINT="${ADDHADOLINT:-"false"}"
ADD_IMAGEMAGICK="${ADDIMAGEMAGICK:-"false"}"
ADD_MAKE="${ADDMAKE:-"false"}"
ADD_NGINX="${ADDNGINX:-"false"}"
ADD_UV="${ADDUV:-"false"}"
# ADD_XXD: opt-in to explicitly include the `xxd` hex-dump utility.
#
# History: This flag was added with the intent of providing an opt-in install
# path for xxd, mirroring ADD_MAKE / ADD_EZA. During implementation it was
# discovered that `xxd` is already pulled in transitively by the always-installed
# `vim` package on both supported distros, so `xxd` is present on every build
# regardless of ADDXXD's value:
#   - Alpine 3.21: `vim` package directly depends on the `xxd` package
#   - Debian bookworm: `vim` -> `vim-common` -> `xxd`
#
# The flag is retained anyway for:
#   1. Explicit declaration of intent (do not rely on vim's transitive dep)
#   2. Forward-compatibility: if `vim` is ever removed from the always-installed
#      package set, ADDXXD becomes functionally meaningful with no code change
#   3. API consistency with the other ADD_xxx flags
ADD_XXD="${ADDXXD:-"false"}"
ADD_YQ="${ADDYQ:-"false"}"
ADD_AWS_CLI="${ADDAWSCLI:-"false"}"
ADD_CFN_GUARD="${ADDCFNGUARD:-"false"}"
ADD_CFN_LINT="${ADDCFNLINT:-"false"}"
ADD_CLAUDE_CODE="${ADDCLAUDECODE:-"false"}"

# Nginx docs server parameters (env-overridable). NGINX_DOC_ROOT is the default
# target of the /srv/docs symlink; the served root can be re-pointed at runtime
# with `docs-root <DIR>` (see install_nginx).
NGINX_PORT="${NGINXPORT:-"8080"}"
NGINX_DOC_ROOT="${NGINXDOCROOT:-"/app"}"

# AWS CLI v2 official installer version (env-overridable). Honored on Debian/glibc only;
# the Alpine path installs the distro's community `aws-cli` package (version not pinnable).
AWS_CLI_VERSION="${AWSCLIVERSION:-"2.27.41"}"
# uv standalone-installer version (env-overridable). uvx (= npx for Python) launches
# Python MCP servers such as mcp-google-sheets.
UV_VERSION="${UVVERSION:-"0.11.27"}"
# graphify: the PyPI package is `graphifyy` (double y) — `graphify` on PyPI is an
# unrelated project — while the command it installs is `graphify`. Installed with
# `uv tool install`, so ADDUV=true is required alongside ADDGRAPHIFY=true.
# GRAPHIFY_EXTRAS is a comma-separated subset of mcp / neo4j / falkordb / pdf /
# watch / svg; empty installs the base package only.
GRAPHIFY_VERSION="${GRAPHIFYVERSION:-"0.9.28"}"
GRAPHIFY_EXTRAS="${GRAPHIFYEXTRAS:-""}"
# Pinned versions for GitHub-released binaries (env-overridable)
GITLEAKS_VERSION="${GITLEAKSVERSION:-"8.30.1"}"
GRPCURL_VERSION="${GRPCURLVERSION:-"1.9.3"}"
HADOLINT_VERSION="${HADOLINTVERSION:-"2.12.0"}"
YQ_VERSION="${YQVERSION:-"4.53.2"}"
CFN_GUARD_VERSION="${CFNGUARDVERSION:-"3.2.0"}"
CFN_LINT_VERSION="${CFNLINTVERSION:-"1.51.2"}"

MARKER_FILE="/usr/local/etc/vscode-dev-containers/common-packages-ex"

# Debian / Ubuntu packages
install_debian_packages() {
    # Ensure apt is in non-interactive to avoid prompts
    export DEBIAN_FRONTEND=noninteractive

    local package_list=""
    if [ "${PACKAGES_ALREADY_INSTALLED}" != "true" ]; then
        package_list="${package_list} \
        aggregate \
        bat \
        dnsutils \
        fzf \
        gh \
        git \
        gnupg2 \
        gpg \
        iproute2 \
        ipset \
        iptables \
        iputils-ping \
        jq \
        less \
        man-db \
        netcat-openbsd \
        procps \
        ripgrep \
        sqlite3 \
        sudo \
        tmux \
        trash-cli \
        unzip \
        vim"
    fi

    if [ "${ADD_EZA}" = "true" ]; then
        mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | tee /etc/apt/sources.list.d/gierens.list
        chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        echo "Running apt-get update for eza..."
        package_list="${package_list} eza"
    fi

    if [ "${ADD_GITLEAKS}" = "true" ]; then
        # https://github.com/gitleaks/gitleaks/releases
        ARCH=$(dpkg --print-architecture)
        case "${ARCH}" in
            amd64)
                GITLEAKS_ARCH="x64"
                ;;
            arm64)
                GITLEAKS_ARCH="arm64"
                ;;
            *)
                echo "Unsupported architecture for gitleaks: ${ARCH}"
                exit 1
                ;;
        esac
        wget -qO /tmp/gitleaks.tar.gz "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GITLEAKS_ARCH}.tar.gz"
        tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks
        chmod +x /usr/local/bin/gitleaks
        rm /tmp/gitleaks.tar.gz
    fi

    if [ "${ADD_GRPCURL}" = "true" ]; then
        # https://github.com/fullstorydev/grpcurl/releases
        ARCH=$(dpkg --print-architecture)
        DEBFILENAME="grpcurl_${GRPCURL_VERSION}_linux_${ARCH}.deb"
        wget -qO /tmp/${DEBFILENAME} https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VERSION}/${DEBFILENAME}
        apt-get update -y
        apt-get -y install --no-install-recommends /tmp/${DEBFILENAME}
        rm /tmp/${DEBFILENAME}
    fi

    if [ "${ADD_HADOLINT}" = "true" ]; then
        # https://github.com/hadolint/hadolint/releases
        ARCH=$(dpkg --print-architecture)
        case "${ARCH}" in
            amd64)
                HADOLINT_ARCH="x86_64"
                ;;
            arm64)
                HADOLINT_ARCH="arm64"
                ;;
            *)
                echo "Unsupported architecture for hadolint: ${ARCH}"
                exit 1
                ;;
        esac
        wget -qO /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-${HADOLINT_ARCH}
        chmod +x /usr/local/bin/hadolint
    fi

    if [ "${ADD_YQ}" = "true" ]; then
        # https://github.com/mikefarah/yq/releases
        ARCH=$(dpkg --print-architecture)
        case "${ARCH}" in
            amd64)
                YQ_ARCH="amd64"
                ;;
            arm64)
                YQ_ARCH="arm64"
                ;;
            *)
                echo "Unsupported architecture for yq: ${ARCH}"
                exit 1
                ;;
        esac
        wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${YQ_ARCH}"
        chmod +x /usr/local/bin/yq
    fi

    if [ "${ADD_CFN_GUARD}" = "true" ]; then
        # https://github.com/aws-cloudformation/cloudformation-guard/releases
        # The release tag has NO leading "v" (e.g. 3.2.0). The "v3" in the asset
        # name is the major-version constant, not the pin. The binary is statically
        # linked, so the same artifact runs on both glibc (Debian) and musl (Alpine).
        ARCH=$(dpkg --print-architecture)
        case "${ARCH}" in
            amd64)
                CFN_GUARD_ARCH="x86_64"
                ;;
            arm64)
                CFN_GUARD_ARCH="aarch64"
                ;;
            *)
                echo "Unsupported architecture for cfn-guard: ${ARCH}"
                exit 1
                ;;
        esac
        CFN_GUARD_DIR="cfn-guard-v3-${CFN_GUARD_ARCH}-linux-latest"
        wget -qO /tmp/cfn-guard.tar.gz "https://github.com/aws-cloudformation/cloudformation-guard/releases/download/${CFN_GUARD_VERSION}/${CFN_GUARD_DIR}.tar.gz"
        tar -xzf /tmp/cfn-guard.tar.gz -C /usr/local/bin --strip-components=1 "${CFN_GUARD_DIR}/cfn-guard"
        chmod +x /usr/local/bin/cfn-guard
        rm /tmp/cfn-guard.tar.gz
    fi

    if [ "${ADD_MAKE}" = "true" ]; then
        package_list="${package_list} make"
    fi

    # ImageMagick — CLI image editing for the AI agent (convert/mogrify/identify).
    # Debian bookworm ships ImageMagick 6; the base package pulls the PNG/JPEG/WebP/
    # TIFF/GIF delegates as hard deps, so --no-install-recommends still yields a
    # working raster toolchain. A lightweight Japanese Gothic font (IPAex) is added
    # alongside so the AI can annotate images with Japanese text (no CJK font ships
    # in the base image, and -annotate uses a single face with no fallback).
    if [ "${ADD_IMAGEMAGICK}" = "true" ]; then
        package_list="${package_list} imagemagick fonts-ipaexfont-gothic"
    fi

    # NOTE: redundant under the current always-installed `vim` package
    # (vim -> vim-common -> xxd). See ADD_XXD declaration above for full rationale.
    if [ "${ADD_XXD}" = "true" ]; then
        package_list="${package_list} xxd"
    fi


    # Install the list of packages
    echo "Packages to verify are installed: ${package_list}"
    rm -rf /var/lib/apt/lists/*
    apt-get update -y
    apt-get -y install --no-install-recommends ${package_list} 2> >( grep -v 'debconf: delaying package configuration, since apt-utils is not installed' >&2 )

    # Get to latest versions of all packages
    if [ "${UPGRADE_PACKAGES}" = "true" ]; then
        apt-get -y upgrade --no-install-recommends
        apt-get autoremove -y
    fi

    PACKAGES_ALREADY_INSTALLED="true"

    # Clean up
    apt-get -y clean
    rm -rf /var/lib/apt/lists/*
}

# Alpine Linux packages
install_alpine_packages() {
    local package_list=""
    if [ "${PACKAGES_ALREADY_INSTALLED}" != "true" ]; then
        package_list="${package_list} \
        bat \
        bind-tools \
        fzf \
        git \
        github-cli \
        gnupg \
        iproute2 \
        ipset \
        iptables \
        iputils \
        jq \
        less \
        netcat-openbsd \
        procps-ng \
        ripgrep \
        sqlite \
        sudo \
        tmux \
        unzip \
        vim \
        wget"
    fi

    # man pages (Alpine 3.12+)
    if apk info man > /dev/null 2>&1; then
        package_list="${package_list} man man-pages"
    else
        package_list="${package_list} mandoc man-pages"
    fi

    # eza (optional)
    if [ "${ADD_EZA}" = "true" ]; then
        package_list="${package_list} eza"
    fi

    # xxd (optional)
    # NOTE: redundant under the current always-installed `vim` package
    # (vim directly depends on xxd on Alpine 3.21). See ADD_XXD declaration above for full rationale.
    if [ "${ADD_XXD}" = "true" ]; then
        package_list="${package_list} xxd"
    fi

    # make (optional)
    if [ "${ADD_MAKE}" = "true" ]; then
        package_list="${package_list} make"
    fi

    # ImageMagick (optional) — Alpine ships IM7 (`magick`). Format support is
    # modularized into subpackages, so JPEG/WebP are added explicitly for parity
    # with the Debian build (PNG is covered by the base package). font-ipa provides
    # a Japanese face so the AI can annotate images with Japanese text.
    if [ "${ADD_IMAGEMAGICK}" = "true" ]; then
        package_list="${package_list} imagemagick imagemagick-jpeg imagemagick-webp font-ipa"
    fi


    # Install packages
    echo "Packages to verify are installed: ${package_list}"
    apk update
    apk add --no-cache ${package_list}

    # gitleaks (optional) - binary download
    if [ "${ADD_GITLEAKS}" = "true" ]; then
        # https://github.com/gitleaks/gitleaks/releases
        ARCH=$(uname -m)
        case "${ARCH}" in
            x86_64)
                GITLEAKS_ARCH="x64"
                ;;
            aarch64)
                GITLEAKS_ARCH="arm64"
                ;;
            *)
                echo "Unsupported architecture for gitleaks: ${ARCH}"
                exit 1
                ;;
        esac
        wget -qO /tmp/gitleaks.tar.gz "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GITLEAKS_ARCH}.tar.gz"
        tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks
        chmod +x /usr/local/bin/gitleaks
        rm /tmp/gitleaks.tar.gz
    fi

    # grpcurl (optional) - binary download
    if [ "${ADD_GRPCURL}" = "true" ]; then
        # https://github.com/fullstorydev/grpcurl/releases
        ARCH=$(uname -m)
        case "${ARCH}" in
            x86_64)
                GRPCURL_ARCH="x86_64"
                ;;
            aarch64)
                GRPCURL_ARCH="arm64"
                ;;
            *)
                echo "Unsupported architecture for grpcurl: ${ARCH}"
                exit 1
                ;;
        esac
        wget -qO /tmp/grpcurl.tar.gz "https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VERSION}/grpcurl_${GRPCURL_VERSION}_linux_${GRPCURL_ARCH}.tar.gz"
        tar -xzf /tmp/grpcurl.tar.gz -C /usr/local/bin grpcurl
        chmod +x /usr/local/bin/grpcurl
        rm /tmp/grpcurl.tar.gz
    fi

    # hadolint (optional) - binary download
    if [ "${ADD_HADOLINT}" = "true" ]; then
        # https://github.com/hadolint/hadolint/releases
        ARCH=$(uname -m)
        case "${ARCH}" in
            x86_64)
                HADOLINT_ARCH="x86_64"
                ;;
            aarch64)
                HADOLINT_ARCH="arm64"
                ;;
            *)
                echo "Unsupported architecture for hadolint: ${ARCH}"
                exit 1
                ;;
        esac
        wget -qO /usr/local/bin/hadolint "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-${HADOLINT_ARCH}"
        chmod +x /usr/local/bin/hadolint
    fi

    # yq (optional) - binary download
    if [ "${ADD_YQ}" = "true" ]; then
        # https://github.com/mikefarah/yq/releases
        ARCH=$(uname -m)
        case "${ARCH}" in
            x86_64)
                YQ_ARCH="amd64"
                ;;
            aarch64)
                YQ_ARCH="arm64"
                ;;
            *)
                echo "Unsupported architecture for yq: ${ARCH}"
                exit 1
                ;;
        esac
        wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${YQ_ARCH}"
        chmod +x /usr/local/bin/yq
    fi

    # cfn-guard (optional) - statically linked binary (runs on musl too)
    if [ "${ADD_CFN_GUARD}" = "true" ]; then
        # https://github.com/aws-cloudformation/cloudformation-guard/releases
        ARCH=$(uname -m)
        case "${ARCH}" in
            x86_64)
                CFN_GUARD_ARCH="x86_64"
                ;;
            aarch64)
                CFN_GUARD_ARCH="aarch64"
                ;;
            *)
                echo "Unsupported architecture for cfn-guard: ${ARCH}"
                exit 1
                ;;
        esac
        CFN_GUARD_DIR="cfn-guard-v3-${CFN_GUARD_ARCH}-linux-latest"
        wget -qO /tmp/cfn-guard.tar.gz "https://github.com/aws-cloudformation/cloudformation-guard/releases/download/${CFN_GUARD_VERSION}/${CFN_GUARD_DIR}.tar.gz"
        tar -xzf /tmp/cfn-guard.tar.gz -C /usr/local/bin --strip-components=1 "${CFN_GUARD_DIR}/cfn-guard"
        chmod +x /usr/local/bin/cfn-guard
        rm /tmp/cfn-guard.tar.gz
    fi

    # Upgrade packages
    if [ "${UPGRADE_PACKAGES}" = "true" ]; then
        apk upgrade --no-cache
    fi

    PACKAGES_ALREADY_INSTALLED="true"
}

# cfn-lint (distro-independent, Python venv)
install_cfn_lint() {
    # https://github.com/aws-cloudformation/cfn-lint
    # Installed with uv, so ADDUV=true is required. uv gives the isolation the
    # hand-built venv used to provide (PEP 668 "externally-managed-environment"
    # never comes up, and cfn-lint's large dependency tree stays out of the
    # system Python) and supplies the interpreter too, so the image no longer
    # needs python3 / python3-venv for this.
    echo "Installing cfn-lint ${CFN_LINT_VERSION} with uv ..."
    uv_tool_install "cfn-lint==${CFN_LINT_VERSION}"
    echo "cfn-lint installed: $(cfn-lint --version)"
}

# AWS CLI v2 (distro-dependent)
#   Debian/glibc: official bundled installer, pinned to ${AWS_CLI_VERSION}.
#   Alpine/musl:  the official installer is glibc-linked and will NOT run, so
#                 install the community-repo `aws-cli` package (version follows
#                 the distro and cannot be pinned to ${AWS_CLI_VERSION}).
install_aws_cli() {
    local ARCH AWS_CLI_ARCH
    case "${ADJUSTED_ID}" in
        debian)
            # https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
            ARCH=$(dpkg --print-architecture)
            case "${ARCH}" in
                amd64)
                    AWS_CLI_ARCH="x86_64"
                    ;;
                arm64)
                    AWS_CLI_ARCH="aarch64"
                    ;;
                *)
                    echo "Unsupported architecture for aws-cli: ${ARCH}"
                    exit 1
                    ;;
            esac
            wget -qO /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_CLI_ARCH}-${AWS_CLI_VERSION}.zip"
            unzip -q /tmp/awscliv2.zip -d /tmp
            /tmp/aws/install
            rm -rf /tmp/aws /tmp/awscliv2.zip
            ;;
        alpine)
            apk add --no-cache aws-cli
            ;;
    esac
    echo "aws-cli installed: $(aws --version)"
}

# uv (distro-independent): official standalone installer, pinned to ${UV_VERSION}.
# Installs `uv` and `uvx` into /usr/local/bin (ARCH auto-detected, so no case block).
# uvx is the "npx for Python" that launches Python MCP servers (e.g. mcp-google-sheets).
install_uv() {
    wget -qO- "https://astral.sh/uv/${UV_VERSION}/install.sh" \
        | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh
    echo "uv installed: $(uv --version) / uvx: $(command -v uvx)"
}

# Install a CLI with `uv tool install` so that *every* user of the image can run
# it, not just root.
#
# uv keeps three things under ~/.local by default, and this script runs as root:
#
#   UV_TOOL_DIR            the tool's own environment
#   UV_TOOL_BIN_DIR        the symlink placed on PATH
#   UV_PYTHON_INSTALL_DIR  the interpreter uv downloads when the image has no
#                          suitable one
#
# Leaving any of the three under /root produces the same failure, because /root
# is mode 700: the command sits on PATH but a non-root user cannot follow it
# ("command not found", or "bad interpreter: Permission denied" when only the
# interpreter is out of reach). Root can run it and the build reports success,
# which is what makes this easy to ship by accident.
#
# The interpreter one is the subtle case: whether uv downloads a Python at all
# depends on what the image happens to have. Debian pulls python3 in
# transitively today, so a tool can work by luck here and break on a leaner base.
uv_tool_install() {
    if ! command -v uv > /dev/null 2>&1; then
        echo "Error: this tool is installed with uv. Set ADDUV=true." >&2
        exit 1
    fi

    env UV_TOOL_DIR=/opt/uv-tools \
        UV_TOOL_BIN_DIR=/usr/local/bin \
        UV_PYTHON_INSTALL_DIR=/opt/uv-python \
        uv tool install "$@"

    # a+rX: readable everywhere, executable only where it already was (dirs and
    # binaries), so the symlinks in /usr/local/bin stay followable.
    chmod -R a+rX /opt/uv-tools
    if [ -d /opt/uv-python ]; then
        chmod -R a+rX /opt/uv-python
    fi
}

# graphify (distro-independent): installed with `uv tool install`, so it needs
# ADDUV=true. Two names are in play: the PyPI package is `graphifyy` (double y —
# `graphify` on PyPI is an unrelated project), while the command it installs is
# `graphify`. For the same reason `uvx graphify` does not work: `uv tool run`
# reads the first word as a package, so it would have to be
# `uvx --from graphifyy graphify`.
#
# Installation goes through uv_tool_install(), which is what keeps the command
# usable by the developer user and not only root — see the comment there.
#
# No python3 required on the image: uv supplies an interpreter for the tool's own
# environment (graphifyy requires >=3.10).
#
# Registering the skill (`graphify install`) is deliberately NOT done at build
# time: it writes into a user's home or the current repository, so doing it as
# root during a build would either miss the developer user or land nowhere
# useful. It is a one-off command for whoever uses the container.
install_graphify() {
    local spec="graphifyy==${GRAPHIFY_VERSION}"
    if [ -n "${GRAPHIFY_EXTRAS}" ]; then
        spec="graphifyy[${GRAPHIFY_EXTRAS}]==${GRAPHIFY_VERSION}"
    fi

    echo "Installing ${spec} with uv ..."
    uv_tool_install "${spec}"
    echo "graphify installed: $(graphify --version)"
}

# Claude Code (distro-independent)
install_claude_code() {
    local target_user="${USERNAME:-""}"

    if [ -z "${target_user}" ]; then
        echo "Warning: USERNAME is not set. Installing Claude Code for root user."
        echo "Set USERNAME environment variable to install for a specific user."
        target_user="root"
    fi

    if ! id "${target_user}" > /dev/null 2>&1; then
        echo "Error: User '${target_user}' does not exist."
        exit 1
    fi

    if ! command -v curl > /dev/null 2>&1 && ! command -v wget > /dev/null 2>&1; then
        echo "Error: Either curl or wget is required to install Claude Code."
        exit 1
    fi

    echo "Installing Claude Code for user '${target_user}'..."

    # Download installer to a temporary file for safer execution
    local installer="/tmp/claude-install.sh"
    if command -v curl > /dev/null 2>&1; then
        curl -fsSL https://claude.ai/install.sh -o "${installer}"
    else
        wget -qO "${installer}" https://claude.ai/install.sh
    fi

    chmod +x "${installer}"

    if [ "${target_user}" = "root" ]; then
        bash "${installer}"
    else
        su - "${target_user}" -c "bash ${installer}"
    fi

    rm -f "${installer}"

    echo "Claude Code installed successfully for user '${target_user}'."
}

# Nginx docs server (distro-independent orchestration).
# Installs nginx, fixes the served root to the /srv/docs symlink (re-pointable at
# runtime via docs-root), runs workers as ${USERNAME} so the bind-mounted /app is
# readable, and ships the docs-root helper onto PATH.
install_nginx() {
    local conf_dir nginx_user="${USERNAME:-"root"}"

    case "${ADJUSTED_ID}" in
        debian)
            apt-get update -y
            apt-get -y install --no-install-recommends nginx
            rm -f /etc/nginx/sites-enabled/default
            conf_dir="/etc/nginx/conf.d"
            ;;
        alpine)
            apk add --no-cache nginx
            rm -f /etc/nginx/http.d/default.conf
            conf_dir="/etc/nginx/http.d"
            ;;
    esac

    # Run workers as the /app owner so the bind mount (and the symlink target) is readable.
    sed -i "s/^user .*/user ${nginx_user};/" /etc/nginx/nginx.conf
    chown -R "${nginx_user}" /var/lib/nginx /var/log/nginx 2>/dev/null || true

    # Fix the served root to a symlink; the runtime target defaults to ${NGINX_DOC_ROOT}.
    mkdir -p /srv
    ln -sfn "${NGINX_DOC_ROOT}" /srv/docs

    cat > "${conf_dir}/docs.conf" <<EOF
server {
    listen      0.0.0.0:${NGINX_PORT};
    server_name _;
    root        /srv/docs;
    charset     utf-8;
    autoindex   on;
    location / { try_files \$uri \$uri/ =404; }
}
EOF

    # Ship the runtime root-switch helper onto PATH ($0 is main.sh, so its dir is utils/).
    install -m 0755 "$(dirname "$0")/docs-root" /usr/local/bin/docs-root

    nginx -t
    echo "Nginx ready: root=/srv/docs -> ${NGINX_DOC_ROOT} on :${NGINX_PORT} (worker=${nginx_user})"
}

# ******************
# ** Main section **
# ******************

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Load markers to see which steps have already run
if [ -f "${MARKER_FILE}" ]; then
    echo "Marker file found:"
    cat "${MARKER_FILE}"
    source "${MARKER_FILE}"
fi

# Bring in ID, ID_LIKE, VERSION_ID, VERSION_CODENAME
. /etc/os-release
# Get an adjusted ID independent of distro variants
if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
    ADJUSTED_ID="debian"
elif [ "${ID}" = "alpine" ]; then
    ADJUSTED_ID="alpine"
else
    echo "Linux distro ${ID} not supported."
    exit 1
fi

# Install packages for appropriate OS
case "${ADJUSTED_ID}" in
    "debian")
        install_debian_packages
        ;;
    "alpine")
        install_alpine_packages
        ;;
esac

# Install AWS CLI (distro-dependent)
if [ "${ADD_AWS_CLI}" = "true" ]; then
    install_aws_cli
fi

# Install uv (distro-independent)
if [ "${ADD_UV}" = "true" ]; then
    install_uv
fi

# Install graphify (distro-independent; requires uv)
if [ "${ADD_GRAPHIFY}" = "true" ]; then
    install_graphify
fi

# Install cfn-lint (distro-independent)
if [ "${ADD_CFN_LINT}" = "true" ]; then
    install_cfn_lint
fi

# Install Claude Code (distro-independent)
if [ "${ADD_CLAUDE_CODE}" = "true" ]; then
    install_claude_code
fi

# Install Nginx docs server (distro-independent)
if [ "${ADD_NGINX}" = "true" ]; then
    install_nginx
fi

# Write marker file
if [ ! -d "/usr/local/etc/vscode-dev-containers" ]; then
    mkdir -p "$(dirname "${MARKER_FILE}")"
fi
echo -e "\
    PACKAGES_ALREADY_INSTALLED=${PACKAGES_ALREADY_INSTALLED}\n\
    " > "${MARKER_FILE}"

echo "Done!"
