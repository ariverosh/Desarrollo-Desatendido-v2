#!/bin/bash
# Wrapper para sync-frontend-files.sh
source "$(dirname "${BASH_SOURCE[0]}")/../state/project-config.sh"
cd "$AVICLOUD_ROOT"
exec "$(dirname "${BASH_SOURCE[0]}")/avicloud/sync-frontend-files.sh" "$@"
