#!/bin/sh

set -e

UPGRADE_PACKAGES="${UPGRADEPACKAGES:-"true"}"
ADD_EZA="${ADDEZA:-"false"}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

exec /bin/bash "$(dirname $0)/main.sh" "$@"
exit $?
