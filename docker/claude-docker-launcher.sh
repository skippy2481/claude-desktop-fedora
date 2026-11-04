#!/bin/bash
# claude-docker — launch Claude Desktop (containerized) on the local session
# Re-derives everything dynamic at run time: xhost grant, GPU group, cookie-free Xwayland access.
# NOTE: uses the HOST user's real Claude config/session (shared identity with native install).

USER_UID=$(id -u); USER_GID=$(id -g)
GPU_GID=$(stat -c %g /dev/dri/card0 2>/dev/null || echo 44)
DISPLAY_NUM=${DISPLAY:-:0}

# X grant does not survive logout — re-apply every launch (scoped: local user only)
xhost +SI:localuser:$(whoami) >/dev/null 2>&1

docker rm -f claude-docker >/dev/null 2>&1
exec docker run --rm --name claude-docker \
  --network host \
  --shm-size=2g \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /run/user/${USER_UID}:/run/user/${USER_UID} \
  -v $HOME/.config/Claude:/home/skippy/.config/Claude \
  -v $HOME/.local/share/Claude:/home/skippy/.local/share/Claude \
  -e DISPLAY=${DISPLAY_NUM} \
  -e HOME=/home/skippy \
  -e XDG_RUNTIME_DIR=/run/user/${USER_UID} \
  -e DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${USER_UID}/bus \
  -e PULSE_SERVER=unix:/run/user/${USER_UID}/pulse/native \
  -e GDK_BACKEND=x11 \
  -e GTK_USE_PORTAL=0 \
  -e ELECTRON_DISABLE_SECURITY_WARNINGS=true \
  --device /dev/dri \
  --group-add ${GPU_GID} \
  --user ${USER_UID}:${USER_GID} \
  claude-desktop-runtime --disable-gpu
