#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Entrypoint script that proxies the host Docker socket into the container
# so that the non-root "openserverless" user can access Docker.
# Works on both Linux (native socket) and macOS/Docker Desktop.

set -e

DOCKER_SOCKET="/var/run/docker.sock"
DOCKER_HOST_SOCKET="/var/run/docker-host.sock"

start_socat_proxy() {
    # If the host socket is mounted at the expected location, start socat
    if [ -S "$DOCKER_HOST_SOCKET" ]; then
        # Remove stale socket if it exists
        rm -f "$DOCKER_SOCKET"

        echo "Starting Docker socket proxy (socat)..."
        socat UNIX-LISTEN:${DOCKER_SOCKET},fork,mode=666 \
              UNIX-CONNECT:${DOCKER_HOST_SOCKET} &
        SOCAT_PID=$!

        # Wait for the socket to become available (up to 5 seconds)
        for i in $(seq 1 50); do
            if [ -S "$DOCKER_SOCKET" ]; then
                echo "Docker socket proxy is ready."
                return 0
            fi
            sleep 0.1
        done

        echo "WARNING: Docker socket proxy started but socket not yet available."
        return 0
    else
        echo "WARNING: Host Docker socket not found at $DOCKER_HOST_SOCKET"
        echo "Docker commands will not work unless DOCKER_HOST is set to a reachable endpoint."
        return 0
    fi
}

# Start the socat proxy (runs as root before dropping privileges)
start_socat_proxy

# Hand off to the provided command, or default to sleep infinity (keeps container alive)
if [ $# -gt 0 ]; then
    exec "$@"
else
    exec sleep infinity
fi
