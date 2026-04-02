#!/bin/sh
# Mock ha CLI for testing outside the Supervisor environment.
# Simulates `ha core check`, `ha core restart`, and `ha core info`.
# Place at /usr/bin/ha (or anywhere on PATH) inside the test container.

SUBCOMMAND="$1"
ACTION="$2"
RAW_JSON=""

# Parse flags
shift 2 2>/dev/null || true
for arg in "$@"; do
  case "$arg" in
    --raw-json) RAW_JSON=1 ;;
  esac
done

case "${SUBCOMMAND}:${ACTION}" in
  core:check)
    CONFIG_DIR="/homeassistant"
    if [ ! -f "${CONFIG_DIR}/configuration.yaml" ]; then
      if [ -n "$RAW_JSON" ]; then
        echo '{"result":"error","data":{"message":"configuration.yaml not found"}}'
      else
        echo "Error: configuration.yaml not found in ${CONFIG_DIR}"
      fi
      exit 1
    fi
    # Basic YAML syntax check (tabs are invalid in YAML)
    if grep -rP '\t' "${CONFIG_DIR}"/*.yaml >/dev/null 2>&1; then
      if [ -n "$RAW_JSON" ]; then
        echo '{"result":"error","data":{"message":"YAML contains tab characters"}}'
      else
        echo "Error: YAML files contain tab characters"
      fi
      exit 1
    fi
    if [ -n "$RAW_JSON" ]; then
      echo '{"result":"ok","data":{"message":"Configuration valid"}}'
    else
      echo "Configuration valid"
    fi
    ;;
  core:restart)
    if [ -n "$RAW_JSON" ]; then
      echo '{"result":"ok","data":{"message":"Restart scheduled"}}'
    else
      echo "[mock] Home Assistant restart scheduled"
    fi
    ;;
  core:info)
    if [ -n "$RAW_JSON" ]; then
      echo '{"result":"ok","data":{"version":"2025.4.0","state":"running","machine":"test"}}'
    else
      echo "version: 2025.4.0"
      echo "state: running"
      echo "machine: test"
    fi
    ;;
  *)
    echo "[mock] ha ${SUBCOMMAND} ${ACTION}: not implemented"
    exit 1
    ;;
esac
