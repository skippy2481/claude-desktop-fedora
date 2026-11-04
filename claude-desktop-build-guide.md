# Claude Desktop on Ultramarine Linux 44 — Start-to-Finish Build & Install
REF: MSI-1104-CDD — 2026-11-04 — Fedora 44 system (Ultramarine 44 Plasma, x86_64)
Source: https://github.com/bsneed/claude-desktop-fedora
Installed: Claude Desktop 0.14.10 (RPM claude-desktop-0.14.10-1.um44.x86_64.rpm) + standalone Electron v37.0.0

## What this is
The repo's build script downloads Anthropic's official Windows installer,
extracts app.asar, swaps the Windows-only claude-native-binding module for a
Linux-compatible stub, and repackages everything as an RPM. The installed app
is then run with a standalone Electron binary to avoid GTK conflicts with the
system Electron.

## 1. Prerequisites
Ultramarine/Fedora 44 x86_64, rpm-build (dnf), git, npm/npx (script pulls in
icoutils, root-global electron + asar via npm as side effects).

## 2. Build the RPM
    git clone https://github.com/bsneed/claude-desktop-fedora.git
    cd claude-desktop-fedora
    sudo ./build-fedora.sh

Downloads ~126MB Windows installer, builds RPM at:
    build/electron-app/x86_64/claude-desktop-0.14.10-1.um44.x86_64.rpm

GOTCHA #1: running the build under sudo leaves build/ root-owned with
restrictive perms (especially on umask-027 hardened hosts). The README's
relative-path `ls` and `dnf install build/...` then FAIL with permission
denied. Fix: use the ABSOLUTE path for install, then reclaim the tree:
    sudo dnf install /home/<user>/claude-desktop-fedora/build/electron-app/x86_64/claude-desktop-*.rpm
    sudo chown -R <user>:<user> ~/claude-desktop-fedora

The "chrome-sandbox binary not found" %post warning is benign — the launcher
runs with --no-sandbox.

## 3. Standalone Electron
GOTCHA #2: the electron-v37.0.0-linux-x64.zip archive has NO top-level folder.
The README's `unzip -d /opt` + `mv /opt/electron-v37.0.0-linux-x64` sequence
FAILS and scatters ~70 files (locales/, *.pak, libEGL.so, electron, etc.)
loose in /opt. Correct procedure:
    cd /tmp
    wget https://github.com/electron/electron/releases/download/v37.0.0/electron-v37.0.0-linux-x64.zip
    sudo mkdir -p /opt/electron
    sudo unzip electron-v37.0.0-linux-x64.zip -d /opt/electron
    sudo chmod +x /opt/electron/electron

(If /opt was previously polluted by the README sequence, clean it with:
    cd /tmp && unzip -Z1 electron-v37.0.0-linux-x64.zip | while read -r f; do sudo rm -rf "/opt/$f"; done
before re-extracting.)

## 4. Replace the launcher script
The stock launcher tries to use the system Electron. Back it up, then:
    sudo cp /usr/bin/claude-desktop /usr/bin/claude-desktop.backup
    sudo tee /usr/bin/claude-desktop <<'INNER'
    #!/usr/bin/bash
    LOG_FILE="$HOME/claude-desktop-launcher.log"
    export GDK_BACKEND=x11
    export GTK_USE_PORTAL=0
    export ELECTRON_DISABLE_SECURITY_WARNINGS=true
    /opt/electron/electron /usr/lib64/claude-desktop/app.asar --ozone-platform-hint=auto --enable-logging=file --log-file=$LOG_FILE --log-level=INFO --disable-gpu-sandbox --no-sandbox "$@"
    INNER
    sudo chmod 755 /usr/bin/claude-desktop

## 5. Permissions hardening pass (CRITICAL on umask-027 hosts)
GOTCHA #3: with umask 027, every root-created artifact lands 0750/0640.
Symptoms: `claude-desktop` → "permission denied", then a MISLEADING
"Unable to find Electron app at /usr/lib64/claude-desktop/app.asar" (Electron
reports unreadable files as missing). Fix everything in one pass:
    sudo chmod -R a+rX /opt/electron
    sudo chmod 755 /usr/bin/claude-desktop /usr/bin/claude-desktop.backup
    sudo chmod a+rx /usr/lib64/claude-desktop
    sudo chmod -R a+rX /usr/lib64/claude-desktop

## 6. App drawer / desktop icon
    sudo chmod 644 /usr/share/applications/claude-desktop.desktop
    for f in /usr/share/icons/hicolor/*/apps/claude-desktop.png; do sudo chmod 644 "$f"; done
    kbuildsycoca6 --noincremental 2>/dev/null || true
    sudo gtk-update-icon-cache -f /usr/share/icons/hicolor

## 7. Verification
    file /opt/electron/electron        # ELF 64-bit executable
    head -1 /usr/bin/claude-desktop    # #!/usr/bin/bash
    claude-desktop                     # app launches
    tail -20 ~/claude-desktop-launcher.log   # if launch fails

## 8. Rollback / uninstall
    sudo dnf remove claude-desktop
    sudo rm -rf /opt/electron
    sudo mv /usr/bin/claude-desktop.backup /usr/bin/claude-desktop
    sudo npm rm -g electron asar   # optional: build-script side effects

## 9. Upgrading to a newer Claude version
Per repo README: update CLAUDE_DOWNLOAD_URL in the build script to the new
installer, rerun sudo ./build-fedora.sh, reinstall RPM. The launcher rewrite
must be reapplied AFTER every RPM install (dnf overwrites /usr/bin/claude-desktop).
Recheck section 5 perms after every upgrade.

## Standing rule for Fedora 44 system
On this box (umask 027, REF MSI-1030-LNS) ANY file/dir created via sudo
(mkdir, tee, unzip, RPM %post) silently lands 750/640. Always follow root
creates with an explicit perms check. Do not let BleachBit near /opt/electron.
