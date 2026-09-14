#!/usr/bin/env bash
# dsh-pet 安装（macOS / Linux）
#   bash scripts/install.sh
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"          # 包根目录
DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
TARGET="$DSH_HOME_DIR/plugins/dsh-pet"
PATCH="$DSH_HOME_DIR/profiles/web/cordis.patch.yml"

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m    [ok] %s\033[0m\n' "$1"; }
warn() { printf '\033[33m    [!]  %s\033[0m\n' "$1"; }

step "DSH 目录：$DSH_HOME_DIR"
[ -d "$DSH_HOME_DIR" ] || warn "目录还不存在；如果你从没用过 DSH Web，请先运行一次再安装。"

step "复制插件到 $TARGET"
mkdir -p "$TARGET/data"
cp -R "$SRC/plugin/lib" "$SRC/plugin/assets" "$TARGET/"
[ -f "$SRC/plugin/package.json" ] && cp "$SRC/plugin/package.json" "$TARGET/"
[ -f "$SRC/README.md" ] && cp "$SRC/README.md" "$TARGET/"
[ -f "$SRC/LICENSE" ] && cp "$SRC/LICENSE" "$TARGET/"
for f in start-dsh.cmd stop-pet.cmd uninstall.cmd uninstall.vbs focus-or-open.vbs make-shortcuts.vbs; do
  [ -f "$SRC/scripts/$f" ] && cp "$SRC/scripts/$f" "$TARGET/"
done
ok "已复制 lib/ assets/ package.json README.md LICENSE + 脚本"

step "写入 Web profile 配置"
mkdir -p "$(dirname "$PATCH")"
HOST_PATH="$TARGET/lib/host.js"
[ -f "$HOST_PATH" ] || { echo "找不到 $HOST_PATH，复制似乎失败了"; exit 1; }
URL="file://$HOST_PATH"
ENTRY="# dsh-pet: pet widget (added by install.sh)
- insert:
    - id: dsh-pet
      name: '$URL'
"

if [ -f "$PATCH" ]; then
  if grep -qE '^[[:space:]]*-[[:space:]]*id:[[:space:]]*dsh-pet[[:space:]]*$' "$PATCH"; then
    ok "配置里已有 dsh-pet，无需改动"
  else
    cp "$PATCH" "$PATCH.bak-$(date +%Y%m%d-%H%M%S)"
    printf '%s\n' "$ENTRY" >> "$PATCH"
    ok "已追加配置（原文件已备份）"
  fi
else
  printf '%s\n' "$ENTRY" > "$PATCH"
  ok "已创建 $PATCH"
fi

cat <<EOF

$(printf '\033[32m安装完成！\033[0m')

接下来：
  1. 配置是热重载的：DSH Web 正在运行的话会自动重载
  2. 打开 DSH Web GUI，按 Ctrl+Shift+R 强刷，右下角就有看板娘
  3. 想显示余额：export DEEPSEEK_API_KEY=sk-...

完全卸载：bash scripts/uninstall.sh
EOF