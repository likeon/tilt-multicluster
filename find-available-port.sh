#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 <starting_port>" >&2
    exit 1
fi

port=$1

# Validate port is a number
if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    echo "Error: Port must be a number" >&2
    exit 1
fi

# Check if port is in valid range
if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    echo "Error: Port must be between 1 and 65535" >&2
    exit 1
fi

# Find first available port
while [ "$port" -le 65535 ]; do
    # Check if port is in use
    if ! lsof -i :"$port" >/dev/null 2>&1; then
        echo "$port"
        exit 0
    fi
    port=$((port + 1))
done

echo "Error: No available port found" >&2
exit 1