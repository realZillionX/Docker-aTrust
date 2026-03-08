中文 | [**English**](README.en.md)

# Docker-aTrust（Ubuntu GUI + Chromium）

本仓库基于 [docker-easyconnect](https://github.com/docker-easyconnect/docker-easyconnect) 开发，构建一个带图形界面的 Ubuntu 容器，在容器内安装并运行图形界面版 aTrust，并将默认浏览器与 aTrust 的跳转浏览器统一设为 Chromium，便于完成 aTrust 浏览器登录页面的跳转。

容器同时提供：

- VNC 桌面（端口 `5901`，密码固定为 `password`）。
- SOCKS5 代理（默认端口 `1080`，推荐用于 Proxifier 分流）。
- HTTP 代理（默认端口 `8888`，必选）。
- aTrust 本地 Web 登录端口（端口 `54631`，用于 aTrust 拉起浏览器的登录流程）。

> **端口可自定义。** SOCKS5 和 HTTP 代理的宿主机端口可通过环境变量 `SOCKS_PORT` 和 `HTTP_PORT` 调整（参见[运行容器](#2-运行容器)），容器内服务始终监听 `1080` / `8888`。

> **外网代理与本仓库无关。** 如果你同时使用公网代理工具（如 Clash Verge 监听 `7897`），只需在 Proxifier 中按域名分别指向 Docker 容器代理（内网）和公网代理即可，本仓库不涉及外网代理配置。

## 0. 前置条件

- 已安装 Docker Desktop（macOS / Windows）或 Docker Engine（Linux）。
- 已安装任意 VNC 客户端（macOS 可用系统自带"屏幕共享"；Windows 可用 RealVNC / TightVNC；Linux 可用 TigerVNC Viewer / Remmina）。
- （可选）已安装 Proxifier（用于在宿主机做分流）。

### 各平台注意事项

| 平台        | 说明                                                                                                                                                                                                                                                                                                               |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **macOS**   | Docker Desktop + 系统自带"屏幕共享"即可。构建命令见下文。                                                                                                                                                                                                                                                          |
| **Windows** | Docker Desktop for Windows + VNC 客户端。`docker run` 命令在 PowerShell 中使用 `` ` `` 换行而非 `\`，`$HOME` 换为 `$env:USERPROFILE`。                                                                                                                                                                             |
| **Linux**   | Docker Engine + VNC 客户端。命令与 macOS 一致。确保 `/dev/net/tun` 设备存在。                                                                                                                                                                                                                                      |
| **WSL 2**   | **推荐直接在 Windows 宿主机运行容器，不在 WSL 内运行。** WSL 2 开启 [Mirrored Networking](https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking) 后，WSL 内的进程可直接通过 `127.0.0.1` 访问 Windows 侧的代理端口，由 Windows 上的 Proxifier 统一管理分流，无需在 WSL 内单独配置代理。 |

## 1. 构建镜像

本仓库内置了 aTrust 安装包下载地址（Sangfor CDN）对应的 build args，你只需要选择与你的目标架构匹配的文件即可。

### 1.1 Apple Silicon（推荐：arm64）

```bash
cd Docker-aTrust
docker build -t atrust-ubuntu:chromium \
  -f Dockerfile.ubuntu \
  $(cat build-args/atrust-arm64.txt) \
  --build-arg CHROMIUM=1 \
  .
```

### 1.2 Intel / AMD（amd64 / x86_64）

```bash
cd Docker-aTrust
docker build -t atrust-ubuntu:chromium \
  --platform linux/amd64 \
  -f Dockerfile.ubuntu \
  $(cat build-args/atrust-amd64.txt) \
  --build-arg CHROMIUM=1 \
  .
```

说明：

- `--build-arg CHROMIUM=1` 用于在镜像内安装 Chromium。
- `build-args/` 下也提供了多个版本的 aTrust build args，你可以按需替换。

## 2. 运行容器

### 端口配置

宿主机暴露的 SOCKS5 和 HTTP 代理端口可通过环境变量自定义（默认 `1080` / `8888`）：

```bash
# 可选：自定义端口（默认值如下，无需修改即可直接使用）
export SOCKS_PORT=${SOCKS_PORT:-1080}
export HTTP_PORT=${HTTP_PORT:-8888}
```

### 启动命令

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
<summary>Windows PowerShell 版本</summary>

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

> PowerShell 不支持 `${VAR:-default}` 语法，可在运行前手动设置 `$env:SOCKS_PORT = "1080"` 等，或直接硬编码端口号。

</details>

关键点解释：

- `--device /dev/net/tun` + `--cap-add NET_ADMIN`：aTrust 需要创建并配置 TUN 设备。
- `--sysctl net.ipv4.conf.default.route_localnet=1`：用于让 aTrust 的 DNS 分流生效（Docker Desktop 下无法在容器内可靠设置该 sysctl，必须在 `docker run` 时传入）。
- `--shm-size=512m`：避免 Chromium 因 `/dev/shm` 过小而"闪退"。
- `-e PASSWORD=password`：固定 VNC 密码为 `password`（你也可以自行改成别的值，但本仓库默认建议固定为 `password`）。
- `-e CHROMIUM=1`：启用容器内 Chromium 自动拉起与跳转处理（包括 aTrust 的登录跳转）。
- `-e URLWIN=1`：当 aTrust 试图打开 URL 时，额外弹窗提示并把 URL 写入剪贴板（排障时很有用）。
- `-v $HOME/.atrust-data:/root`：持久化 `/root`（包括 aTrust 登录信息、Chromium 配置等）。
- `-p ${HTTP_PORT:-8888}:8888`：`8888` 为必选 HTTP 代理端口，若 tinyproxy 启动失败或运行中丢失监听，容器会退出。

## 3. 通过 VNC 打开桌面并登录 aTrust

1. 使用 VNC 连接到：`127.0.0.1:5901`。
2. 密码：`password`。
3. 桌面上会有两个图标：`aTrust` 与 `Chromium`。
4. 双击 `aTrust`，按你的学校/单位配置登录。
5. aTrust 需要网页认证时会自动拉起 Chromium 打开跳转页面（例如 `cas.sii.edu.cn`）。

如果你仍然需要手动复制 URL，优先检查：

- 运行容器时是否设置了 `-e CHROMIUM=1`。
- 是否使用了本仓库构建出来的新镜像（不要混用旧镜像）。

## 4. 在宿主机使用 Proxifier 做分流（推荐）

容器内 aTrust 建立连接后，会在宿主机暴露代理端口：

- **SOCKS5 代理**：`127.0.0.1:${SOCKS_PORT}`（默认 `1080`）。
- **HTTP 代理**：`127.0.0.1:${HTTP_PORT}`（默认 `8888`）。

### 4.1 添加代理服务器

在 Proxifier 中新增一个 Proxy Server：

- Protocol：SOCKS5。
- Address：`127.0.0.1`。
- Port：`1080`（或你自定义的 `SOCKS_PORT`）。

建议开启"通过代理解析域名"（不同版本 UI 文案可能是 `Resolve hostnames through proxy` 或 `Remote DNS`）。

### 4.2 添加分流规则（示例）

你可以按域名分流（推荐从小范围开始）：

- 规则 1：目标域名匹配 `*.sii.edu.cn`，走 aTrust 容器的 SOCKS5 代理。
- 规则 2（如有外网代理）：其他流量走你本地的公网代理（如 Clash Verge 的 `127.0.0.1:7897`），或直连。
- Default：Direct。

提示：

- 内网域名经常依赖 aTrust 下发的"内网 DNS"才能解析。开启 Proxifier 的 Remote DNS 后，域名解析会在容器侧完成，更容易避免 `NXDOMAIN`。
- 即便 aTrust 已生效，容器内仍然可能可以访问 `google.com`，这通常是分流（Split Tunnel）的结果，并不必然代表 aTrust 没有接管流量。

## 5. 常见问题与自检

### 5.1 Chromium 点击就闪退

优先确认运行参数包含 `--shm-size=512m`。其次确认你是通过桌面图标或 `chromium-launcher` 启动（本仓库已统一加上 `--no-sandbox` 与 `--disable-dev-shm-usage`）。

### 5.2 aTrust 已登录但访问不了 `qz.sii.edu.cn`

先在容器内检查域名解析是否走到内网 DNS：

```bash
docker exec atrust-ubuntu dig qz.sii.edu.cn +short
```

再确认 aTrust 的 TUN 与策略是否正常：

```bash
docker exec atrust-ubuntu ip route
docker exec atrust-ubuntu sysctl -n net.ipv4.conf.utun7.route_localnet
```

如果 `net.ipv4.conf.utun7.route_localnet` 不是 `1`，几乎可以确定你运行容器时没有加：

- `--sysctl net.ipv4.conf.default.route_localnet=1`。

### 5.3 桌面图标偶尔消失

当你把宿主机目录挂载到 `/root` 时，某些环境下 `~/.cache` 不支持 Unix socket，导致桌面管理器启动失败。本仓库已将 `pcmanfm` 的缓存与运行目录指向 `/tmp`，并做了延迟重试。

你可以用下面命令查看 `pcmanfm` 日志：

```bash
docker exec atrust-ubuntu tail -n 200 /tmp/pcmanfm-desktop.log
```

### 5.4 `8888` 代理不可用导致容器退出

`8888` 是必选代理端口。容器启动时会严格检查 tinyproxy，运行中若 tinyproxy 进程消失或 `8888` 不再监听，容器会主动退出，避免出现"VPN 在线但 HTTP 代理已失效"的假健康状态。

可用以下命令排障：

```bash
docker logs --tail 200 atrust-ubuntu
docker exec atrust-ubuntu ss -lntp | grep ':8888'
docker exec atrust-ubuntu tail -n 200 /var/log/tinyproxy/tinyproxy.log
```

### 5.5 Windows 上 `/dev/net/tun` 不存在

Docker Desktop for Windows 使用 Linux VM 运行容器，`/dev/net/tun` 在 VM 内自动可用。如果报错，确认 Docker Desktop 已启用 WSL 2 后端或 Hyper-V 后端。

## 免责声明

aTrust 为 Sangfor 的商业软件。本仓库仅提供容器化与运行环境的配置与脚本示例，不对 aTrust 软件本体作任何修改或分发承诺。请确保你的使用符合相关许可与合规要求。
