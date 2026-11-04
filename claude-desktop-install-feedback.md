# Install notes: claude-desktop-fedora on Ultramarine Linux 44 (Fedora 44 base)

Thanks for this project — Claude Desktop 0.14.10 is now running on my
Ultramarine 44 (Plasma) machine using the v37.0.0 standalone Electron. The
step-1 copy block mostly worked, but four issues surfaced on my host that
others will likely hit too. Details and fixes below, in hopes they're useful.

## Environment
Ultramarine Linux 44 (Flying Fish), x86_64, KDE Plasma, system umask set to 027
(security hardening pass), non-root user, sudo for installs.

## Issue 1 — build tree is root-owned after `sudo ./build-fedora.sh`
The build succeeds, but everything under build/ is owned by root. The step-1
block then fails at:
    ls build/electron-app/$(uname -m)/          → "Permission denied"
    sudo dnf install build/electron-app/...    → "No such file or directory"
(the sudo dnf failure is misleading — it's the same permission problem, dnf
just can't traverse the directory.)
Fix used: install with the absolute path, and/or chown the build tree back to
the invoking user. Suggestion: have build-fedora.sh `chown -R "$SUDO_USER"`
the output dir at the end, or note the absolute-path requirement in the README.

## Issue 2 — Electron zip extracts flat; README path assumptions break
electron-v37.0.0-linux-x64.zip has no top-level folder, but the README
sequence is:
    sudo unzip electron-v37.0.0-linux-x64.zip -d /opt
    sudo mv /opt/electron-v37.0.0-linux-x64 /opt/electron
The mv fails ("No such file or directory") and /opt ends up littered with
~70 loose files (electron binary, locales/, *.pak, libEGL.so, etc.), while
/opt/electron is the BINARY, not a directory. Every later step referencing
/opt/electron/electron then fails confusingly.
Fix used:
    sudo mkdir -p /opt/electron
    sudo unzip electron-v37.0.0-linux-x64.zip -d /opt/electron
    sudo chmod +x /opt/electron/electron
Suggestion: change the README (and mv/chmod lines) to extract straight into
/opt/electron.

## Issue 3 — umask 027 hosts: unreadable perms cascade
With umask 027, root-created artifacts land 0750/0640. On my box this meant:
- /opt/electron tree: 0750 → user can't run Electron ("permission denied")
- /usr/bin/claude-desktop (written by the README's sudo tee): 0750
- /usr/lib64/claude-desktop/ tree as installed: not readable by the user
The last one produces a genuinely misleading runtime error:
    Error launching app
    Unable to find Electron app at /usr/lib64/claude-desktop/app.asar
The file exists — it's just unreadable, and Electron reports unreadable as
missing. I spent a roundtrip chasing a wrong path because of this.
Fix used:
    sudo chmod -R a+rX /opt/electron
    sudo chmod 755 /usr/bin/claude-desktop
    sudo chmod a+rx /usr/lib64/claude-desktop
    sudo chmod -R a+rX /usr/lib64/claude-desktop
Suggestion: add explicit chmod lines to the README (or a note for hardened-
umask systems).

## Issue 4 — minor: chrome-sandbox %post warning
    >>> Warning: chrome-sandbox binary not found. Sandbox may not function correctly.
This appears benign given the recommended launcher uses --no-sandbox, but a
README note saying it's expected would save confusion.

## Minor README nit
The step-1 block comments "Check what file was actually created" but runs as a
continuous paste; if any single line fails (e.g., Issue 1), subsequent lines
still execute and their failures cascade (my first run showed cp/tee/mv
failures from the not-yet-installed package). Consider splitting install and
launcher-fix into separately-runnable blocks.

## Working end-to-end sequence (Ultramarine 44, umask 027)
    git clone https://github.com/bsneed/claude-desktop-fedora.git
    cd claude-desktop-fedora && sudo ./build-fedora.sh
    sudo dnf install ~/claude-desktop-fedora/build/electron-app/x86_64/claude-desktop-*.rpm
    cd /tmp && wget https://github.com/electron/electron/releases/download/v37.0.0/electron-v37.0.0-linux-x64.zip
    sudo mkdir -p /opt/electron
    sudo unzip electron-v37.0.0-linux-x64.zip -d /opt/electron
    sudo chmod +x /opt/electron/electron
    sudo cp /usr/bin/claude-desktop /usr/bin/claude-desktop.backup
    # ...rewrite /usr/bin/claude-desktop per README (absolute asar path) ...
    sudo chmod 755 /usr/bin/claude-desktop
    sudo chmod -R a+rX /opt/electron
    sudo chmod a+rx /usr/lib64/claude-desktop && sudo chmod -R a+rX /usr/lib64/claude-desktop
    claude-desktop

## Addendum — confirmed working on Fedora 44, plus build-script findings

Verified end-to-end on a Fedora 44-base system with the fixes above:
    NAME="Ultramarine Linux"
    ID=ultramarine
    VERSION="44 (Plasma Edition)"
    ID_LIKE=fedora
    VERSION_ID=44
    PRETTY_NAME="Ultramarine Linux 44 (Plasma Edition)"

Note: Ultramarine passes the script's `is_fedora_based()` check via the
`ID_LIKE=fedora` line in /etc/os-release, so Fedora-derived distros work
out of the box here. The README requirements section lists only "Fedora 41".

Two findings from reading build-fedora.sh that explain the symptom patterns:

1. The RPM spec has no %attr/%defattr directives, so the package preserves
   the file modes the files had at build time. Building under sudo on a
   host with a hardened umask (027) bakes 0640/0750 INTO the RPM — the
   installed package then ships unreadable files even on a normal system
   afterwards. A `chmod -R a+rX` in %install (or explicit %attr lines in
   the spec) would make the package umask-proof regardless of who builds.

2. The %post chrome-sandbox hunt only looks under an npm-global electron
   install (lib/node_modules/electron/dist/chrome-sandbox). Under the
   standalone-Electron flow the README prescribes, that path can never
   exist, so the "chrome-sandbox binary not found" warning is structurally
   guaranteed rather than an environment problem — worth a README note.
