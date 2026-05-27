#!/bin/sh

set -e

UPGRADE_PACKAGES="${UPGRADEPACKAGES:-"true"}"
ADD_CFN_GUARD="${ADDCFNGUARD:-"false"}"
ADD_CFN_LINT="${ADDCFNLINT:-"false"}"
ADD_CLAUDE_CODE="${ADDCLAUDECODE:-"false"}"
ADD_EZA="${ADDEZA:-"false"}"
ADD_GITLEAKS="${ADDGITLEAKS:-"false"}"
ADD_GRPCURL="${ADDGRPCURL:-"false"}"
ADD_HADOLINT="${ADDHADOLINT:-"false"}"
ADD_MAKE="${ADDMAKE:-"false"}"
# ADD_XXD: opt-in for `xxd`; currently a no-op because `vim` brings xxd in
# transitively on both Debian/Alpine. See main.sh for full rationale.
ADD_XXD="${ADDXXD:-"false"}"
ADD_YQ="${ADDYQ:-"false"}"

# Pinned versions for GitHub-released binaries (env-overridable)
GITLEAKS_VERSION="${GITLEAKSVERSION:-"8.30.1"}"
GRPCURL_VERSION="${GRPCURLVERSION:-"1.9.3"}"
HADOLINT_VERSION="${HADOLINTVERSION:-"2.12.0"}"
YQ_VERSION="${YQVERSION:-"4.53.2"}"
CFN_GUARD_VERSION="${CFNGUARDVERSION:-"3.2.0"}"
CFN_LINT_VERSION="${CFNLINTVERSION:-"1.51.2"}"

if [ "$(id -u)" -ne 0 ]; then
    printf 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.\n'
    exit 1
fi

exec /bin/bash "$(dirname "$0")/main.sh" "$@"
exit $?
