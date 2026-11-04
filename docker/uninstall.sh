#!/bin/bash
# uninstall.sh — remove container, image, and launcher
docker rm -f claude-docker claude-docker-test >/dev/null 2>&1
docker rmi -f claude-desktop-runtime
rm -f "$HOME/bin/claude-docker"
echo "Removed: containers, claude-desktop-runtime image, ~/bin/claude-docker"
