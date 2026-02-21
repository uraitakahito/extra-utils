#!/bin/sh

set -e

UPGRADE_PACKAGES="${UPGRADEPACKAGES:-"true"}"
ADD_EZA="${ADDEZA:-"false"}"
ADD_GRPCURL="${ADDGRPCURL:-"false"}"
ADD_HADOLINT="${ADDHADOLINT:-"false"}"
ADD_CLAUDE_CODE="${ADDCLAUDECODE:-"false"}"

if [ "$(id -u)" -ne 0 ]; then
    printf 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.\n'
    exit 1
fi

exec /bin/bash "$(dirname "$0")/main.sh" "$@"
exit $?
