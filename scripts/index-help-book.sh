#!/bin/bash
# index-help-book.sh
#
# Generates the full-text search index and context-sensitive help index
# for the Relay help book inside the built product.
# Called as a Run Script build phase after resources are copied.
#
# Build settings consumed:
#   BUILT_PRODUCTS_DIR – path to the built .app wrapper
#   FULL_PRODUCT_NAME  – e.g. "Relay.app"

set -euo pipefail

HELP_DIR="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}/Contents/Resources/Relay.help"
LPROJ_DIR="${HELP_DIR}/Contents/Resources/en.lproj"

# --- Generate full-text search index ---

/usr/bin/hiutil -Caf "${LPROJ_DIR}/Relay.helpindex" "${LPROJ_DIR}"
echo "note: Generated Relay.helpindex"

# --- Generate context-sensitive help index ---

/usr/bin/hiutil -Caf "${LPROJ_DIR}/Relay.cshelpindex" -s en "${LPROJ_DIR}"
echo "note: Generated Relay.cshelpindex"
