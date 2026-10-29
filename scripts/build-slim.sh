#!/bin/sh
# 精简内核构建脚本（树莓派/路由器/低内存设备）
#
# 用法：
#   ./scripts/build-slim.sh                 # 默认构建 linux/armv7
#   TARGETS="linux-armv7 linux-arm64 linux-amd64" ./scripts/build-slim.sh
#   UPX=0 ./scripts/build-slim.sh           # 不压缩
#
# 依赖：Go 1.26+（推荐与上游 release 对齐的版本）、upx（可选）
set -eu

TAGS="${TAGS:-with_low_memory,no_fake_tcp,no_tailscale,no_easytier,no_zerotier}"
TARGETS="${TARGETS:-linux-armv7}"
VERSION="${VERSION:-$(git describe --tags --always 2>/dev/null || echo dev)}"
OUT="${OUT:-dist}"
UPX="${UPX:-1}"
BUILDTIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$OUT"

build_one() {
  target="$1"
  os="${target%%-*}"
  rest="${target#*-}"
  case "$rest" in
    armv7) arch=arm; arm=7; ext=armv7 ;;
    armv6) arch=arm; arm=6; ext=armv6 ;;
    armv5) arch=arm; arm=5; ext=armv5 ;;
    arm64) arch=arm64; arm=; ext=arm64 ;;
    amd64) arch=amd64; arm=; ext=amd64 ;;
    386)   arch=386; arm=; ext=386 ;;
    *) echo "不支持的 target: $target" >&2; return 1 ;;
  esac

  out="$OUT/mihomo-$target-$VERSION"
  echo "==> 构建 ${target}（tags: ${TAGS}）"
  if [ -n "$arm" ]; then
    CGO_ENABLED=0 GOOS="$os" GOARCH="$arch" GOARM="$arm" \
      go build -tags "$TAGS" -trimpath \
      -ldflags "-X 'github.com/metacubex/mihomo/constant.Version=$VERSION' -X 'github.com/metacubex/mihomo/constant.BuildTime=$BUILDTIME' -w -s -buildid=" \
      -o "$out" .
  else
    CGO_ENABLED=0 GOOS="$os" GOARCH="$arch" \
      go build -tags "$TAGS" -trimpath \
      -ldflags "-X 'github.com/metacubex/mihomo/constant.Version=$VERSION' -X 'github.com/metacubex/mihomo/constant.BuildTime=$BUILDTIME' -w -s -buildid=" \
      -o "$out" .
  fi

  before=$(wc -c < "$out")
  if [ "$UPX" = "1" ]; then
    upx --best --lzma "$out" >/dev/null 2>&1 || upx --best "$out" >/dev/null 2>&1 || echo "!! upx 失败，保留未压缩版本"
  fi
  after=$(wc -c < "$out")
  printf '   %s  %s 字节 → %s 字节\n' "$out" "$before" "$after"
}

for t in $TARGETS; do
  build_one "$t"
done
echo "完成，产物在 $OUT/"
