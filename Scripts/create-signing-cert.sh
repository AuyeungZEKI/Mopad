#!/bin/zsh
# 在登录钥匙串中创建本地自签名代码签名证书「Mopad Local Signing」
# 作用：签名指纹在重新构建后保持不变，「辅助功能」授权只需授予一次。
# 证书仅存在于本机；可在「钥匙串访问」中搜索 "Mopad Local Signing" 删除。
set -euo pipefail
NAME="Mopad Local Signing"

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
  echo "✓ 已存在「$NAME」，无需重复创建"; exit 0
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cfg.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

/usr/bin/openssl req -new -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "$TMP/cfg.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$NAME" -passout "pass:$PASS" -out "$TMP/id.p12"
security import "$TMP/id.p12" -k ~/Library/Keychains/login.keychain-db -P "$PASS" \
  -T /usr/bin/codesign -T /usr/bin/security >/dev/null

echo "✓ 已创建「$NAME」。之后运行 ./Scripts/build.sh 会自动使用它签名。"
