# Docker-aTrust (Ubuntu GUI + Chromium)

[**中文文档**](README.md) | English

This repository is based on [docker-easyconnect](https://github.com/docker-easyconnect/docker-easyconnect). It builds an Ubuntu container with a graphical desktop, installs and runs the GUI version of aTrust inside the container, and unifies the default browser and aTrust's redirect browser to Chromium for seamless web-based login flow.

The container provides:

- VNC desktop (port `5901`, password `password`).
- SOCKS5 proxy (default port `1080`, recommended for Proxifier routing).
- HTTP proxy (default port `8888`, mandatory).
- aTrust local web login port (`54631`, used for aTrust's browser login redirect).

> **Ports are customizable.** Host-side SOCKS5 and HTTP proxy ports can be adjusted via `SOCKS_PORT` and `HTTP_PORT` environment variables (see [Running the Container](#2-running-the-container)). Services inside the container always listen on `1080` / `8888`.

> **Public internet proxies are unrelated to this repo.** If you also use a public proxy tool (e.g. Clash Verge on `7897`), simply configure Proxifier to route internal traffic to the Docker container proxy and public traffic to your local proxy. This repo does not manage public proxy configuration.

## 0. Prerequisites

- Docker Desktop (macOS / Windows) or Docker Engine (Linux) installed.
- A VNC client installed (macOS: built-in "Screen Sharing"; Windows: RealVNC / TightVNC; Linux: TigerVNC Viewer / Remmina).
- (Optional) Proxifier installed for host-side traffic routing.

### Platform Notes

| Platform    | Notes                                                                                                                                                                                                                                                                                                                                                              |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **macOS**   | Docker Desktop + built-in "Screen Sharing". Build commands below.                                                                                                                                                                                                                                                                                                  |
| **Windows** | Docker Desktop for Windows + VNC client. Use `` ` `` for line continuation instead of `\` in PowerShell; replace `$HOME` with `$env:USERPROFILE`.                                                                                                                                                                                                                  |
| **Linux**   | Docker Engine + VNC client. Commands are the same as macOS. Ensure `/dev/net/tun` device exists.                                                                                                                                                                                                                                                                   |
| **WSL 2**   | **Recommended: run the container on the Windows host, not inside WSL.** With WSL 2 [Mirrored Networking](https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking) enabled, processes inside WSL can access Windows-side proxy ports via `127.0.0.1`, and Proxifier on Windows manages all routing — no separate WSL proxy config needed. |

## 1. Building the Image

This repo includes aTrust installer download URLs (Sangfor CDN) as build args. Choose the file matching your target architecture.

### 1.1 Apple Silicon (recommended: arm64)

```bash
cd Docker-aTrust
docker build -t atrust-ubuntu:chromium \
  -f Dockerfile.ubuntu \
  $(cat build-args/atrust-arm64.txt) \
  --build-arg CHROMIUM=1 \
  .
```

### 1.2 Intel / AMD (amd64 / x86_64)

```bash
cd Docker-aTrust
docker build -t atrust-ubuntu:chromium \
  --platform linux/amd64 \
  -f Dockerfile.ubuntu \
  $(cat build-args/atrust-amd64.txt) \
  --build-arg CHROMIUM=1 \
  .
```

Notes:

- `--build-arg CHROMIUM=1` installs Chromium inside the image.
- `build-args/` contains multiple aTrust versions — swap as needed.

## 2. Running the Container

### Port Configuration

Host-exposed SOCKS5 and HTTP proxy ports can be customized (defaults: `1080` / `8888`):

```bash
# Optional: customize ports (defaults shown below, no change needed for standard usage)
export SOCKS_PORT=${SOCKS_PORT:-1080}
export HTTP_PORT=${HTTP_PORT:-8888}
```

### Start Command

```bash
docker run -d --name atrust-ubuntu \
  --device /dev/net/tun \
  --cap-add NET_ADMIN \
  --sysctl net.ipv4.conf.default.route_localnet=1 \
  --shm-size=512m \
  -e PASSWORD=password \
  -e CHROMIUM=1 \
  -e URLWIN=1 \
  -p 5901:5901 \
  -p ${SOCKS_PORT:-1080}:1080 \
  -p ${HTTP_PORT:-8888}:8888 \
  -p 54631:54631 \
  -v $HOME/.atrust-data:/root \
  atrust-ubuntu:chromium
```

<details>
<summary>Windows PowerShell version</summary>

```powershell
docker run -d --name atrust-ubuntu `
  --device /dev/net/tun `
  --cap-add NET_ADMIN `
  --sysctl net.ipv4.conf.default.route_localnet=1 `
  --shm-size=512m `
  -e PASSWORD=password `
  -e CHROMIUM=1 `
  -e URLWIN=1 `
  -p 5901:5901 `
  -p "${env:SOCKS_PORT ?? 1080}:1080" `
  -p "${env:HTTP_PORT ?? 8888}:8888" `
  -p 54631:54631 `
  -v "$env:USERPROFILE\.atrust-data:/root" `
  atrust-ubuntu:chromium
```

> PowerShell does not support `${VAR:-default}` syntax. Set `$env:SOCKS_PORT = "1080"` manually before running, or hardcode the port numbers.

</details>

Key parameters explained:

- `--device /dev/net/tun` + `--cap-add NET_ADMIN`: aTrust requires TUN device creation.
- `--sysctl net.ipv4.conf.default.route_localnet=1`: enables aTrust DNS routing (cannot be reliably set inside the container on Docker Desktop).
- `--shm-size=512m`: prevents Chromium crashes due to small `/dev/shm`.
- `-e PASSWORD=password`: fixed VNC password (change if desired, but `password` is the default).
- `-e CHROMIUM=1`: enables automatic Chromium launch for aTrust login redirects.
- `-e URLWIN=1`: shows URL popup and copies to clipboard when aTrust opens a URL (useful for debugging).
- `-v $HOME/.atrust-data:/root`: persists `/root` (aTrust login data, Chromium config, etc.).
- `-p ${HTTP_PORT:-8888}:8888`: `8888` is the mandatory HTTP proxy port. If tinyproxy fails or stops listening, the container exits.

## 3. VNC Desktop Login

1. Connect VNC to `127.0.0.1:5901`.
2. Password: `password`.
3. Two desktop icons: `aTrust` and `Chromium`.
4. Double-click `aTrust`, log in per your organization's config.
5. aTrust will auto-launch Chromium for web authentication pages (e.g. `cas.sii.edu.cn`).

If you still need to manually copy the URL, check:

- Container was started with `-e CHROMIUM=1`.
- You're using the image built from this repo (don't mix with old images).

## 4. Proxifier Routing (Recommended)

After aTrust connects inside the container, proxy ports are exposed on the host:

- **SOCKS5**: `127.0.0.1:${SOCKS_PORT}` (default `1080`).
- **HTTP**: `127.0.0.1:${HTTP_PORT}` (default `8888`).

### 4.1 Add Proxy Server

In Proxifier, add a new Proxy Server:

- Protocol: SOCKS5.
- Address: `127.0.0.1`.
- Port: `1080` (or your custom `SOCKS_PORT`).

Enable "Resolve hostnames through proxy" (may appear as `Remote DNS` in some versions).

### 4.2 Routing Rules (Example)

Route by domain (start narrow):

- Rule 1: `*.sii.edu.cn` → aTrust container SOCKS5 proxy.
- Rule 2 (if using public proxy): other traffic → local public proxy (e.g. Clash Verge `127.0.0.1:7897`), or Direct.
- Default: Direct.

Tips:

- Internal domains often require aTrust's internal DNS. Proxifier's Remote DNS resolves domains on the container side, avoiding `NXDOMAIN`.
- aTrust containers may still access `google.com` — this is typically split-tunnel behavior and doesn't mean aTrust isn't working.

## 5. Troubleshooting

### 5.1 Chromium Crashes on Click

Ensure `--shm-size=512m` is in your run command. Use the desktop icon or `chromium-launcher` (this repo adds `--no-sandbox` and `--disable-dev-shm-usage`).

### 5.2 aTrust Connected but Can't Access `qz.sii.edu.cn`

Check DNS resolution inside the container:

```bash
docker exec atrust-ubuntu dig qz.sii.edu.cn +short
```

Verify TUN and routing:

```bash
docker exec atrust-ubuntu ip route
docker exec atrust-ubuntu sysctl -n net.ipv4.conf.utun7.route_localnet
```

If `route_localnet` is not `1`, you likely forgot `--sysctl net.ipv4.conf.default.route_localnet=1`.

### 5.3 Desktop Icons Disappear

When mounting a host directory to `/root`, `~/.cache` may not support Unix sockets, causing the desktop manager to fail. This repo redirects `pcmanfm` cache to `/tmp` with delayed retry.

```bash
docker exec atrust-ubuntu tail -n 200 /tmp/pcmanfm-desktop.log
```

### 5.4 Port `8888` Unavailable Causes Container Exit

`8888` is the mandatory proxy port. The container strictly monitors tinyproxy — if it crashes or stops listening, the container exits to avoid a "VPN online but proxy dead" false-healthy state.

```bash
docker logs --tail 200 atrust-ubuntu
docker exec atrust-ubuntu ss -lntp | grep ':8888'
docker exec atrust-ubuntu tail -n 200 /var/log/tinyproxy/tinyproxy.log
```

### 5.5 `/dev/net/tun` Not Found on Windows

Docker Desktop for Windows runs containers in a Linux VM where `/dev/net/tun` is automatically available. If you get an error, ensure Docker Desktop has WSL 2 or Hyper-V backend enabled.

## Disclaimer

aTrust is commercial software by Sangfor. This repository only provides containerization and runtime configuration scripts — it does not modify or distribute aTrust itself. Ensure your usage complies with relevant licenses and regulations.
