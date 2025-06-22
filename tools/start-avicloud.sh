#!/bin/bash
# Wrapper para start-avicloud.sh
source "$(dirname "${BASH_SOURCE[0]}")/../state/project-config.sh"
cd "$AVICLOUD_ROOT"
exec "$(dirname "${BASH_SOURCE[0]}")/avicloud/start-avicloud.sh" "$@"
