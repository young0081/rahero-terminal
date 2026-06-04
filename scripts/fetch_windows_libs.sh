#!/usr/bin/env bash
# 预置 media_kit 的 Windows 视频库（ANGLE / libmpv），用国内 GitHub 镜像下载，
# 避免国内网络直连 GitHub Releases 失败导致 `flutter build windows` 中断。
#
# 用法：在项目根目录执行  bash scripts/fetch_windows_libs.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/build/windows/x64"
mkdir -p "$DEST"

# 镜像前缀（按可用性依次尝试）
MIRRORS=( "https://ghfast.top/" "https://gh-proxy.com/" "https://ghproxy.net/" "" )

# 资源：URL 与期望 MD5（与 media_kit_libs_windows_video 的 CMakeLists 保持一致）
ANGLE_URL="https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z"
ANGLE_MD5="e866f13e8d552348058afaafe869b1ed"
LIBMPV_URL="https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z"
LIBMPV_MD5="a832ef24b3a6ff97cd2560b5b9d04cd8"

md5_of() {
  if command -v md5sum >/dev/null 2>&1; then md5sum "$1" | awk '{print $1}';
  else certutil -hashfile "$1" MD5 | sed -n '2p' | tr -d ' \r'; fi
}

fetch() {
  local url="$1" md5="$2" out="$3"
  if [[ -f "$out" ]] && [[ "$(md5_of "$out")" == "$md5" ]]; then
    echo "[skip] $(basename "$out") 已存在且校验通过"
    return 0
  fi
  for m in "${MIRRORS[@]}"; do
    echo "[try ] ${m}${url}"
    if curl -fL --connect-timeout 20 --max-time 600 -o "$out" "${m}${url}"; then
      if [[ "$(md5_of "$out")" == "$md5" ]]; then
        echo "[ ok ] $(basename "$out") 下载并校验成功"
        return 0
      fi
      echo "[warn] MD5 不匹配，换下一个镜像"
    fi
  done
  echo "[fail] $(basename "$out") 全部镜像均失败" >&2
  return 1
}

fetch "$ANGLE_URL"  "$ANGLE_MD5"  "$DEST/ANGLE.7z"
fetch "$LIBMPV_URL" "$LIBMPV_MD5" "$DEST/mpv-dev-x86_64-20230924-git-652a1dd.7z"

echo "完成。现在可以执行：flutter build windows"
