#!/bin/bash
# Runtime inside container; chrome refuses sandbox as container-root, hence --no-sandbox
exec /opt/electron/electron /usr/lib64/claude-desktop/app.asar \
  --ozone-platform-hint=auto --no-sandbox --disable-gpu-sandbox "$@"
