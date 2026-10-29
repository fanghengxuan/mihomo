# 精简内核（低内存设备 / 路由器）

这个 fork 额外提供一路 **slim 构建**：保留协议与规则能力，去掉组网、gVisor 与部分高内存实现，
产物可再用 UPX 压缩，适合 32 位 ARM 路由器（仅几十 MB 内存可用）这类场景。

## 与官方构建的差异

| 构建标签 | 作用 |
|---|---|
| `with_low_memory` | 用低内存缓冲池实现替换默认缓冲池，显著降低常驻内存 |
| `no_fake_tcp` | 关闭 Hysteria 的 fake-TCP 通道（UDP 模式下用它模拟 TCP） |
| `no_tailscale` | 不编译 Tailscale 出站 |
| `no_easytier` | 不编译 EasyTier 出站 |
| `no_zerotier` | 不编译 ZeroTier 出站 |

同时**不开启** `with_gvisor`：TUN 只用系统栈（路由器场景本来就走 iptables REDIRECT，用不到 gVisor）。

对比参考（`linux/armv7`，Go 1.26.10，`-trimpath -w -s`）：

| 构建 | 原始大小 | UPX 后 |
|---|---|---|
| 官方 release（含 gVisor / 组网） | ≈ 53 MB | — |
| **slim（本仓库）** | ≈ 34.8 MB | ≈ 7.9 MB |
| 参考产线二进制（同一套标签） | 34,996,350 字节 | 7,973,176 字节 |

> 差异在 1% 以内，剩下的差别来自构建时的 VCS 信息与 Go 工具链补丁版本。

## 构建

```bash
# 单个目标（默认 linux-armv7）
./scripts/build-slim.sh

# 多目标
TARGETS="linux-armv7 linux-arm64 linux-amd64" ./scripts/build-slim.sh

# 不压缩
UPX=0 ./scripts/build-slim.sh
```

环境变量：`TAGS`（覆盖默认标签集）、`VERSION`（写进 `constant.Version`）、`OUT`（输出目录）。

也可以直接手写：

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 \
  go build -tags "with_low_memory,no_fake_tcp,no_tailscale,no_easytier,no_zerotier" \
  -trimpath -ldflags "-w -s -buildid=" -o mihomo-linux-armv7 .
upx --best --lzma mihomo-linux-armv7
```

## 这些标签会影响什么

- **不会再有的能力**：Tailscale / EasyTier / ZeroTier 出站；Hysteria 的 fake-TCP；gVisor 网络栈（TUN 仍可用，走系统栈）
- **不受影响**：SS / VMess / VLESS / Trojan / Hysteria2 / TUIC / WireGuard / SOCKS 等出站，
  规则与规则集、DNS（含 fake-ip）、TUN、sniffer、RESTful API、订阅 provider

## 校验

```bash
./mihomo-linux-armv7 -v            # 版本与构建时间
go version -m ./mihomo-linux-armv7 # 查看 -tags / GOARM / trimpath 等构建信息
```

## 在路由器上使用

这个产物与 [mihomo-merlin](https://github.com/fanghengxuan/mihomo-merlin)（华硕梅林软件中心插件）
配合验证过：`/koolshare/bin/mihomo` 直接替换即可，插件面板会读取 `-v` 显示的版本号。

## 上游

- 上游仓库：https://github.com/MetaCubeX/mihomo
- 本 fork 的 slim 分支只增加构建脚本、文档与 CI，**不改动内核逻辑**
