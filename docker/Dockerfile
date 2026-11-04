# ---- Stage 1: build the claude-desktop RPM from the fork's build script ----
FROM fedora:44 AS builder
RUN dnf install -y rpm-build rpm wget p7zip-plugins ImageMagick icoutils sqlite \
                   nodejs npm curl tar gzip file procps-ng findutils \
    && dnf clean all
WORKDIR /src
COPY build-fedora.sh /src/
# script requires EUID 0; in-container we are root, so it passes as-is
RUN bash /src/build-fedora.sh

# ---- Stage 2: runtime image with RPM + standalone Electron ----
FROM fedora:44
RUN dnf install -y nodejs npm p7zip-plugins wget unzip nss nspr gtk3 alsa-lib pulseaudio-libs pulseaudio-utils alsa-plugins-pulseaudio atk at-spi2-atk at-spi2-core atk cups-libs dbus-libs libdrm libXcomposite libXdamage libXfixes libXrandr libxkbcommon libxshmfence libXtst libXScrnSaver mesa-libgbm libglvnd pango policycoreutils && dnf clean all
COPY --from=builder /src/build/electron-app/x86_64/claude-desktop-*.rpm /tmp/
RUN dnf install -y /tmp/claude-desktop-*.rpm && rm -f /tmp/claude-desktop-*.rpm
# standalone Electron (zip extracts FLAT - must target /opt/electron directly)
RUN mkdir -p /opt/electron && cd /tmp \
    && wget -q https://github.com/electron/electron/releases/download/v37.0.0/electron-v37.0.0-linux-x64.zip \
    && unzip -q electron-v37.0.0-linux-x64.zip -d /opt/electron \
    && chmod +x /opt/electron/electron && rm -f electron-v37.0.0-linux-x64.zip
ENV GDK_BACKEND=x11 GTK_USE_PORTAL=0 ELECTRON_DISABLE_SECURITY_WARNINGS=true
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh
RUN mkdir -p /home/skippy && chown 1000:1000 /home/skippy && mkdir -p /home/skippy/.cache /home/skippy/.pki && chown -R 1000:1000 /home/skippy
ENTRYPOINT ["/entrypoint.sh"]
