#!/bin/bash
# HL7 v2 メッセージを UTF-8 で表示するビューア
# IRIS が出力する HL7 ファイルは ISO-2022-JP でエンコードされているため、
# VSCode 等では文字化けする。このスクリプトで UTF-8 に変換して表示する。

HL7_DIR="./Out"

if [ -n "$1" ]; then
    # 引数があればそのファイルを表示
    echo "=== $1 ==="
    iconv -f ISO-2022-JP -t UTF-8 "$1" | tr '\r' '\n'
else
    # 引数なしなら Out/ 内の全ファイルを表示
    FILES=$(ls -t "$HL7_DIR"/_* 2>/dev/null)
    if [ -z "$FILES" ]; then
        echo "HL7 ファイルが見つかりません: $HL7_DIR/"
        exit 1
    fi
    for f in $FILES; do
        echo "=== $(basename "$f") ==="
        iconv -f ISO-2022-JP -t UTF-8 "$f" | tr '\r' '\n'
        echo ""
    done
fi
