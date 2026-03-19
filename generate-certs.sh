#!/bin/bash
# Generates a local root CA and a server certificate for the Nexus nginx reverse proxy.
# Run this once before starting docker-compose.
# After running, trust rootCA.crt in your OS / Docker Desktop so Docker accepts the registry.

CERTS_DIR="./nginx/certs"
mkdir -p "$CERTS_DIR"

# ── 1. Root CA ──────────────────────────────────────────────────────────────
echo "[1/3] Generating root CA..."
openssl genrsa -out "$CERTS_DIR/rootCA.key" 4096

MSYS_NO_PATHCONV=1 openssl req -x509 -new -nodes \
  -key "$CERTS_DIR/rootCA.key" \
  -sha256 -days 3650 \
  -subj "/C=XX/ST=Local/L=Local/O=dep-pipeline-CA/CN=dep-pipeline Root CA" \
  -out "$CERTS_DIR/rootCA.crt"

# ── 2. Server key + CSR ──────────────────────────────────────────────────────
echo "[2/3] Generating server key and CSR..."
openssl genrsa -out "$CERTS_DIR/nexus.key" 2048

MSYS_NO_PATHCONV=1 openssl req -new \
  -key "$CERTS_DIR/nexus.key" \
  -subj "/C=XX/ST=Local/L=Local/O=dep-pipeline/CN=localhost" \
  -out "$CERTS_DIR/nexus.csr"

# ── 3. Sign with root CA (SAN covers localhost + 127.0.0.1) ─────────────────
echo "[3/3] Signing server cert with root CA..."
cat > "$CERTS_DIR/nexus.ext" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = dep-pipeline-nexus
IP.1  = 127.0.0.1
EOF

openssl x509 -req \
  -in "$CERTS_DIR/nexus.csr" \
  -CA "$CERTS_DIR/rootCA.crt" \
  -CAkey "$CERTS_DIR/rootCA.key" \
  -CAcreateserial \
  -out "$CERTS_DIR/nexus.crt" \
  -days 825 \
  -sha256 \
  -extfile "$CERTS_DIR/nexus.ext"

echo ""
echo "Done. Files written to $CERTS_DIR:"
ls -1 "$CERTS_DIR"
echo ""
echo "Next steps to trust the registry:"
echo "  Windows : double-click rootCA.crt → install to 'Trusted Root Certification Authorities'"
echo "            then restart Docker Desktop"
echo "  Linux   : sudo cp $CERTS_DIR/rootCA.crt /usr/local/share/ca-certificates/dep-pipeline.crt"
echo "            sudo update-ca-certificates && sudo systemctl restart docker"
