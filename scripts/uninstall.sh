#!/usr/bin/env bash
# dsh-pet 卸载（macOS / Linux）
#   bash uninstall.sh          删除插件代码，保留 data/（用量与遥测）
#   bash uninstall.sh --purge  连 data/ 一起删除
#   bash uninstall.sh --yes    跳过确认（脚本化场景）
set -euo pipefail

DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
TARGET="$DSH_HOME_DIR/plugins/dsh-pet"
PATCH="$DSH_HOME_DIR/profiles/web/cordis.patch.yml"

PURGE=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
  esac
done

if [ "$ASSUME_YES" -eq 0 ]; then
  printf '\033[33m即将卸载 dsh-pet（请核对路径是否正确）：\033[0m\n'
  printf '  插件目录：%s\n' "$TARGET"
  printf '  配置文件：%s\n' "$PATCH"
  [ "$PURGE" -eq 1 ] && printf '\033[33m  注意：--purge 会连 data/（用量与遥测）一起删除\033[0m\n'
  printf '确认继续？(y/N) '
  read -r answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) printf '\033[36m已取消。\033[0m\n'; exit 0 ;;
  esac
fi

if [ -f "$PATCH" ] && grep -qE '^[[:space:]]*-[[:space:]]*id:[[:space:]]*dsh-pet[[:space:]]*$' "$PATCH"; then
  cp "$PATCH" "$PATCH.bak-$(date +%Y%m%d-%H%M%S)"
  # 删掉包含 dsh-pet 的那个 insert 块（从 "- insert:" 到下一个顶层条目）
  awk '
    /^[[:space:]]*-[[:space:]]*insert:[[:space:]]*$/ { block = $0; buf = $0 "\n"; inblock = 1; haspet = 0; next }
    inblock {
      if ($0 ~ /^[[:space:]]*-[[:space:]]*id:[[:space:]]*dsh-pet[[:space:]]*$/) haspet = 1
      if ($0 ~ /^[[:space:]]*-[[:space:]]*insert:[[:space:]]*$/ || $0 ~ /^[^[:space:]]/) {
        if (!haspet) printf "%s", buf
        inblock = 0
        buf = ""
        if ($0 ~ /^[[:space:]]*-[[:space:]]*insert:[[:space:]]*$/) { block = $0; buf = $0 "\n"; inblock = 1; haspet = 0; next }
      } else { buf = buf $0 "\n"; next }
    }
    { print }
    END { if (inblock && !haspet) printf "%s", buf }
  ' "$PATCH" > "$PATCH.tmp"
  mv "$PATCH.tmp" "$PATCH"
  printf '\033[32m    [ok] 已从配置中移除 dsh-pet 条目（原文件已备份）\033[0m\n'
else
  printf '\033[32m    [ok] 配置里没有 dsh-pet 条目\033[0m\n'
fi

if [ -d "$TARGET" ]; then
  if [ "$PURGE" -eq 1 ]; then
    rm -rf "$TARGET"
  else
    find "$TARGET" -mindepth 1 -maxdepth 1 ! -name data -exec rm -rf {} +
    printf '\033[90m    [i]  保留了 %s/data（加 --purge 可一并删除）\033[0m\n' "$TARGET"
  fi
  printf '\033[32m    [ok] 已清理 %s\033[0m\n' "$TARGET"
fi

printf '\n\033[36m卸载完成：刷新浏览器（Ctrl+Shift+R）即可看到挂件消失。\033[0m\n'
