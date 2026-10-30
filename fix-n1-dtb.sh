#!/bin/bash
set -euo pipefail

echo "🚀 开始获取并注入 N1 专用 DTB..."

# 动态查找 dtb 输出目录
DTB_TARGET_DIR=$(find openwrt/bin/targets -type d -name "amlogic" -path "*/dtb/*" 2>/dev/null | head -n 1)
if [ -z "${DTB_TARGET_DIR:-}" ]; then
    echo "⚠️ 未找到现有 dtb/amlogic 目录，创建默认路径..."
    DTB_TARGET_DIR="openwrt/bin/targets/armsr/armv8/dtb/amlogic"
fi
mkdir -p "$DTB_TARGET_DIR"
echo "📁 DTB 目标路径: $DTB_TARGET_DIR"

TARGET_FILE="$DTB_TARGET_DIR/meson-gxl-s905d-phicomm-n1.dtb"
FOUND=0

# === 源1: clone ophub 仓库并搜索 ===
if [ "$FOUND" -eq 0 ]; then
    echo "🔍 [源1] 从 ophub/amlogic-s9xxx-openwrt 仓库搜索..."
    TMPDIR=$(mktemp -d)
    if git clone --depth 1 --filter=blob:none --sparse https://github.com/ophub/amlogic-s9xxx-openwrt.git "$TMPDIR/repo" 2>/dev/null; then
        cd "$TMPDIR/repo"
        git sparse-checkout set build 2>/dev/null || true
        SRC=$(find . -type f -name "meson-gxl-s905d-phicomm-n1.dtb" | head -n 1)
        if [ -n "${SRC:-}" ]; then
            cp "$SRC" "$TARGET_FILE"
            FOUND=1
            echo "✅ [源1] 成功找到并复制 DTB"
        fi
        cd - > /dev/null
    fi
    rm -rf "$TMPDIR"
fi

# === 源2: clone unifreq/openwrt_packit 搜索 ===
if [ "$FOUND" -eq 0 ]; then
    echo "🔍 [源2] 从 unifreq/openwrt_packit 仓库搜索..."
    TMPDIR=$(mktemp -d)
    if git clone --depth 1 --filter=blob:none --sparse https://github.com/unifreq/openwrt_packit.git "$TMPDIR/repo" 2>/dev/null; then
        cd "$TMPDIR/repo"
        git sparse-checkout set files 2>/dev/null || true
        SRC=$(find . -type f -name "meson-gxl-s905d-phicomm-n1.dtb" | head -n 1)
        if [ -n "${SRC:-}" ]; then
            cp "$SRC" "$TARGET_FILE"
            FOUND=1
            echo "✅ [源2] 成功找到并复制 DTB"
        fi
        cd - > /dev/null
    fi
    rm -rf "$TMPDIR"
fi

# === 源3: 从 Armbian build 仓库直链下载 ===
if [ "$FOUND" -eq 0 ]; then
    echo "🌐 [源3] 从 Armbian build 仓库下载..."
    URL="https://raw.githubusercontent.com/armbian/build/main/config/kernel/dtb/meson-gxl-s905d-phicomm-n1.dtb"
    if curl -fSL --retry 3 --connect-timeout 15 -o "$TARGET_FILE" "$URL" 2>/dev/null; then
        FOUND=1
        echo "✅ [源3] 下载成功"
    fi
fi

# === 最终校验 ===
if [ "$FOUND" -eq 0 ] || [ ! -s "$TARGET_FILE" ]; then
    echo "❌ FATAL: 所有源均未能获取有效 DTB！"
    exit 1
fi

# 验证是否为真实 DTB 二进制（用 xxd 检查魔数 d00dfeed，避免 file 命令不可用）
MAGIC=$(xxd -p -l 4 "$TARGET_FILE" 2>/dev/null || true)
if [ "$MAGIC" != "d00dfeed" ]; then
    echo "❌ FATAL: 文件不是有效 DTB (魔数: $MAGIC)"
    rm -f "$TARGET_FILE"
    exit 1
fi

echo "✅ N1 DTB 注入成功! 大小: $(du -h "$TARGET_FILE" | cut -f1)"
ls -lh "$TARGET_FILE"
