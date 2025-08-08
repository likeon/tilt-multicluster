#!/bin/bash
#
# Dynamic version of kind-with-registry.sh that supports multiple isolated instances
#
# Adapted from:
# https://github.com/kubernetes-sigs/kind/commits/master/site/static/examples/kind-with-registry.sh

set -o errexit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

KIND_CLUSTER_OPTS="--name ${CLUSTER_NAME}"
KIND_NETWORK="kind-${CLUSTER_NAME}"
REGISTRY_NAME="registry-${CLUSTER_NAME}"

podman network create --driver bridge $KIND_NETWORK

podman run \
    -d --restart=always --name "${REGISTRY_NAME}" --net "$KIND_NETWORK" \
    -p "${REGISTRY_PORT}:5000" \
    registry:2

REGISTRY_IP="$(podman inspect -f '{{.NetworkSettings.IPAddress}}' "${REGISTRY_NAME}")"

# Detect if systemd-run with delegation is needed
NEEDS_SYSTEMD_RUN=false
if command -v systemd-run >/dev/null 2>&1; then
    if systemd-run --scope --user -p "Delegate=yes" true 2>/dev/null; then
      NEEDS_SYSTEMD_RUN=true
    fi
fi

# Create the kind cluster configuration
KIND_CONFIG=$(cat <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_NAME}:5000"]
nodes:
  - role: control-plane
    extraMounts:
      - hostPath: "${DATA_PATH}"
        containerPath: /data
        selinuxRelabel: true
      - hostPath: "$HOME/.docker/config.json"
        containerPath: /var/lib/kubelet/config.json
EOF
)

# Run kind create cluster with or without systemd-run based on system requirements
if [ "$NEEDS_SYSTEMD_RUN" = true ]; then
    echo "$KIND_CONFIG" | systemd-run --scope --user -p "Delegate=yes" kind create cluster ${KIND_CLUSTER_OPTS} --config=-
else
    echo "$KIND_CONFIG" | kind create cluster ${KIND_CLUSTER_OPTS} --config=-
fi

# Apply registry config to the cluster
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
