#!/bin/bash

set -e

UPGRADE_PACKAGES="${UPGRADEPACKAGES:-"true"}"
ADD_EZA="${ADDEZA:-"false"}"
ADD_GRPCURL="${ADDGRPCURL:-"false"}"
ADD_HADOLINT="${ADDHADOLINT:-"false"}"

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

    if [ "${ADD_GRPCURL}" = "true" ]; then
        # https://github.com/fullstorydev/grpcurl/releases
        GRPCURL_VERSION="1.9.3"
        ARCH=$(dpkg --print-architecture)
        DEBFILENAME="grpcurl_${GRPCURL_VERSION}_linux_${ARCH}.deb"
        wget -qO /tmp/${DEBFILENAME} https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VERSION}/${DEBFILENAME}
        apt-get update -y
        apt-get -y install --no-install-recommends /tmp/${DEBFILENAME}
        rm /tmp/${DEBFILENAME}
    fi

    if [ "${ADD_HADOLINT}" = "true" ]; then
        # https://github.com/hadolint/hadolint/releases
        HADOLINT_VERSION="2.12.0"
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

    # Install packages
    echo "Packages to verify are installed: ${package_list}"
    apk update
    apk add --no-cache ${package_list}

    # grpcurl (optional) - binary download
    if [ "${ADD_GRPCURL}" = "true" ]; then
        # https://github.com/fullstorydev/grpcurl/releases
        GRPCURL_VERSION="1.9.3"
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
        HADOLINT_VERSION="2.12.0"
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

    # Upgrade packages
    if [ "${UPGRADE_PACKAGES}" = "true" ]; then
        apk upgrade --no-cache
    fi

    PACKAGES_ALREADY_INSTALLED="true"
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

# Write marker file
if [ ! -d "/usr/local/etc/vscode-dev-containers" ]; then
    mkdir -p "$(dirname "${MARKER_FILE}")"
fi
echo -e "\
    PACKAGES_ALREADY_INSTALLED=${PACKAGES_ALREADY_INSTALLED}\n\
    " > "${MARKER_FILE}"

echo "Done!"
