#!/bin/bash

set -e

SCRIPT_DIR=$(dirname "$0")

# Export all sourced variables
set -a
source "${SCRIPT_DIR}/../project.env"
set +a

# Find available ports for all TILT_PORT_* variables
for var in $(env | grep '^TILT_PORT_' | cut -d= -f1); do
    initial_port=$(eval echo \$$var)
    available_port=$("${SCRIPT_DIR}/find-available-port.sh" "$initial_port")
    export "$var=$available_port"
    echo "Set $var to $available_port"
done
export REGISTRY_PORT=$("${SCRIPT_DIR}/find-available-port.sh" "5000")
export TILT_PORT=$("${SCRIPT_DIR}/find-available-port.sh" "10350")

DEFAULT_DATA_PATH="${HOME}/.local/share/${PROJECT_NAME}"
for folder in ${DATA_FOLDERS}; do
  mkdir -p "${DEFAULT_DATA_PATH}/${folder}"
done
CLUSTER_ID="${PROJECT_NAME}-$(date +%s)"
export CLUSTER_NAME="${CLUSTER_ID}"
if [ "${COPY_DATA}" = "true" ]; then
  DATA_PATH="${HOME}/.local/share/${PROJECT_NAME}-${CLUSTER_ID}"
  echo "Copying data to ${DATA_PATH}"
  # needs sudo because container data files are owned by whoever
  sudo cp -a "${DEFAULT_DATA_PATH}" "${DATA_PATH}"
else
  DATA_PATH="${DEFAULT_DATA_PATH}"
fi
export DATA_PATH

# Function to be executed when the script is started
start_sequence() {
    COPY_DATA=${COPY_DATA} ${SCRIPT_DIR}/kind-with-registry.sh
    tilt up
}

# Function to be executed when the script is stopped
stop_sequence() {
    echo "Cleaning up cluster, registry, and network..."
    kind delete cluster --name "${CLUSTER_NAME}"
    podman rm -f "registry-${CLUSTER_NAME}" 2>/dev/null || true
    podman network rm "kind-${CLUSTER_NAME}" 2>/dev/null || true

    if [ "${COPY_DATA}" = "true" ]; then
      sudo rm -rf "${DATA_PATH}"
    fi

    exit 0
}

# Trap the Ctrl+C signal and call the stop_sequence function
trap stop_sequence SIGINT

# Call the start_sequence function
start_sequence
