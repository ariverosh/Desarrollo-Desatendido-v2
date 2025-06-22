#!/bin/bash
# Wrapper para build-avicloud-enhanced.sh
source "$(dirname "${BASH_SOURCE[0]}")/../state/project-config.sh"
cd "$AVICLOUD_ROOT"
exec "$(dirname "${BASH_SOURCE[0]}")/avicloud/build-avicloud-enhanced.sh" "$@"
