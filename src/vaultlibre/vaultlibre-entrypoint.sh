#!/bin/bash

set -e; set -x; \
    dotnet /vaultlibre/vaultlibre.dll && \
    mv /app/Core.dll /app/Core.orig.dll && \
    mv /app/modified.dll /app/Core.dll

sh /entrypoint.sh
