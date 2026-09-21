#!/usr/bin/env bash
#
# context-for.sh — package durable context for one work unit.
#
# Kept for compatibility with the /context-package skill. The package is built by
# scripts/ctx.sh from the register: filtered by work-unit tag, never re-summarized from a
# conversation.
#
# usage: scripts/context-for.sh <work-unit>

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3
exec bash scripts/ctx.sh package "$@"
