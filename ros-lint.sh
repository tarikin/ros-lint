#!/bin/bash
#
# ros-lint.sh - RouterOS Script Linter and Syntax Validator
# Version: 1.0.0 (2025-06-21)
#
# A robust tool to validate RouterOS script syntax without execution.
# Performs syntax checking by leveraging RouterOS's built-in :parse command
# through an SSH connection.
#
# Features:
# - Validates RouterOS script syntax without execution
# - Supports SSH key-based authentication
# - Configurable verbosity levels
# - Automatic cleanup of temporary files
# - Detailed error reporting with line numbers
#
# Usage: ros-lint.sh [-v 0|1|2] [-i identity_file] [user@]host[:port] <script.rsc>
#
# Author: Nikita Tarikin <nikita@tarikin.com>
# GitHub: https://github.com/tarikin
# License: MIT
#
# Copyright (c) 2025 Nikita Tarikin

# --- Configuration ----------------------------------------------------
DEFAULT_USER="admin"
DEFAULT_PORT=22
CONNECT_TIMEOUT=10
VERBOSITY=0

# --- Helper Functions -------------------------------------------------
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_error() {
  if [[ $VERBOSITY -ge 1 ]]; then
    echo -e "${RED}[ERROR]${NC} $1" >&2
  fi
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_info() {
  if [[ $VERBOSITY -ge 1 ]]; then
    echo -e "[INFO] $1" >&2
  fi
}

log_debug() {
  if [[ $VERBOSITY -ge 2 ]]; then
    echo -e "[DEBUG] $1" >&2
  fi
}

# Cleanup function is now handled within the SSH session
cleanup() {
  : # No-op since we clean up in the main SSH session
}

usage() {
  echo "RouterOS Script Linter and Syntax Validator v1.0.0 (2025-06-21)"
  echo "Usage: $0 [-v 0|1|2] [-i <identity_file>] <[user@]host[:port]> <script.rsc>"
  echo "  -v <level>        Verbosity: 0=results only, 1=info, 2=debug (default: 0)"
  echo "  -i <identity>     SSH identity file (private key)"
  echo "  -h, --help       Show this help message"
  echo
  echo "Examples:"
  echo "  $0 -v 1 admin@router.local script.rsc"
  echo "  $0 -i ~/.ssh/router_id_rsa 192.168.1.1:2222 script.rsc"
  exit 1
}

# --- Parse Arguments ---------------------------------------------------
IDENTITY_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbosity)
      VERBOSITY="$2"
      shift 2
      ;;
    -i|--identity)
      IDENTITY_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 2 ]]; then
  usage
fi

CONN_STRING="$1"
SCRIPT_LOCAL="$2"

# --- Main Script ------------------------------------------------------
# Extract user if specified
if [[ "$CONN_STRING" == *"@"* ]]; then
  USERNAME="${CONN_STRING%%@*}"
  HOST_PORT="${CONN_STRING#*@}"
else
  USERNAME="${DEFAULT_USER}"
  HOST_PORT="$CONN_STRING"
fi

# Extract port if specified
if [[ "$HOST_PORT" == *":"* ]]; then
  HOST="${HOST_PORT%%:*}"
  PORT="${HOST_PORT##*:}"
else
  HOST="$HOST_PORT"
  PORT="${DEFAULT_PORT}"
fi

TARGET="${USERNAME}@${HOST}"
REMOTE_FILE="$(basename "$SCRIPT_LOCAL")"

# --- Validate Input ---------------------------------------------------
if [[ ! -f "$SCRIPT_LOCAL" ]]; then
  log_error "Script file not found: $SCRIPT_LOCAL"
  exit 1
fi

# --- Upload -----------------------------------------------------------
log_info "Uploading script to ${HOST}:${REMOTE_FILE}"

# SSH and SCP options
SSH_OPTS=(
  -o BatchMode=yes
  -o ConnectTimeout=${CONNECT_TIMEOUT}
  -o StrictHostKeyChecking=accept-new
  -p "$PORT"
)
SCP_OPTS=(
  -o BatchMode=yes
  -o ConnectTimeout=${CONNECT_TIMEOUT}
  -o StrictHostKeyChecking=accept-new
  -P "$PORT"
)

if [[ -n "$IDENTITY_FILE" ]]; then
  SSH_OPTS+=( -i "$IDENTITY_FILE" )
  SCP_OPTS+=( -i "$IDENTITY_FILE" )
fi

# Upload the script
if [[ $VERBOSITY -ge 1 ]]; then
  scp "${SCP_OPTS[@]}" \
      "$SCRIPT_LOCAL" "${TARGET}:$REMOTE_FILE"
else
  scp "${SCP_OPTS[@]}" \
      "$SCRIPT_LOCAL" "${TARGET}:$REMOTE_FILE" >/dev/null 2>&1
fi

if [[ $? -ne 0 ]]; then
  log_error "Failed to upload script to router"
  exit 1
fi

# --- Verify Syntax ----------------------------------------------------
log_info "Verifying script syntax on ${HOST}"

# Build RouterOS command to parse the uploaded script without executing it
# and clean up the file in the same session
PARSE_CMD="\
:if ([/file find name=\"${REMOTE_FILE}\"] = \"\") do={ \
  :error (\"File not found: ${REMOTE_FILE}\") \
} else={ \
  :local scriptContent [/file get \"${REMOTE_FILE}\" contents]; \
  :put \"PARSING_START\"; \
  :put [:parse \$scriptContent]; \
  :put \"PARSING_END\"; \
  :delay 1s; \
  /file remove \"${REMOTE_FILE}\"; \
  :put \"FILE_REMOVED\" \
}"

if [[ $VERBOSITY -ge 2 ]]; then
  log_debug "Commands being executed on RouterOS:"
  log_debug "1. Check if file exists: /file find name=\"${REMOTE_FILE}\""
  log_debug "2. Get file contents and parse: :local scriptContent [/file get \"${REMOTE_FILE}\" contents]"
  log_debug "   :put ([:parse \$scriptContent])"
  log_debug "3. Clean up file: /file remove \"${REMOTE_FILE}\""
  log_debug "Full command to execute:"
  echo "$PARSE_CMD" | sed 's/^/  /'
  log_debug "Executing SSH command..."
fi

# Execute the parse command remotely and capture stdout+stderr
PARSE_OUT=$(ssh "${SSH_OPTS[@]}" "${TARGET}" "$PARSE_CMD" 2>&1) || true

if [[ $VERBOSITY -ge 2 ]]; then
  log_debug "Command output:"
  echo "$PARSE_OUT" | sed 's/^/  /'
fi

# --- Result -----------------------------------------------------------
# Check for our parsing markers to determine success/failure
if [[ "$PARSE_OUT" == *PARSING_END* ]]; then
  # Extract just the parse result between our markers
  PARSE_RESULT=$(echo "$PARSE_OUT" | sed -n '/PARSING_START/,/PARSING_END/p' | grep -v PARSING_ | grep -v 'FILE_REMOVED')
  
  # Check for real RouterOS parse errors (with line/column hints)
  if echo "$PARSE_RESULT" | grep -qiE 'syntax error \(line [0-9]+ column [0-9]+\)|expected end of command \(line [0-9]+ column [0-9]+\)'; then
    # Extract and display the first error line
    ERR_MSG=$(echo "$PARSE_RESULT" | grep -iE 'syntax error \(line [0-9]+ column [0-9]+\)|expected end of command \(line [0-9]+ column [0-9]+\)' | head -n1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    echo -e "${RED}✗ ${ERR_MSG}${NC}"
    STATUS=2
  elif [[ -z "$PARSE_RESULT" ]]; then
    log_success "Syntax OK (empty script or only comments)"
    STATUS=0
  else
    log_success "Syntax OK"
    STATUS=0
  fi
  
  # Verify file was removed
  if [[ "$PARSE_OUT" == *FILE_REMOVED* ]]; then
    log_info "Cleaned up temporary file"
  else
    log_error "Could not clean up temporary file"
  fi
  exit $STATUS
else
  echo -e "${RED}✗ Error during script parsing:${NC}"
  # Clean up the error message for better readability
  echo "$PARSE_OUT" | grep -v -E 'PARSING_|FILE_REMOVED'
  exit 2
fi
