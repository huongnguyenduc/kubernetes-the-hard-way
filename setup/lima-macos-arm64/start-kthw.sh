#!/bin/bash
set -e

# --- COLORS & VARIABLES ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
SOCKET_VMNET_PATH="/opt/socket_vmnet/bin/socket_vmnet"
SUDOERS_FILE="/etc/sudoers.d/lima"
NETWORK_CONFIG_FILE="$HOME/.lima/_config/networks.yaml"

# Cluster Config
NETWORK_NAME="subnet-desktop-shared"
GATEWAY_IP="192.168.205.1"
SUBNET_PREFIX="192.168.205"
NODES=(
  "jumpbox:10"
  "server:11"
  "node-0:20"
  "node-1:21"
)

echo -e "${GREEN}>>> Kubernetes The Hard Way - Local Setup Script (v7)${NC}"

# --- STEP 0: FIX GHOST DIRECTORIES ---
if [ -d "$HOME/.lima/run_sockets" ]; then
    rm -rf "$HOME/.lima/run_sockets"
fi

# --- STEP 1: CHECK ROOT ACCESS ---
echo ">>> Requesting sudo access..."
sudo -v

# --- STEP 2: CHECK SOCKET_VMNET BINARY ---
if [ ! -f "$SOCKET_VMNET_PATH" ]; then
    echo -e "${RED}❌ Error: socket_vmnet binary not found at $SOCKET_VMNET_PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✅ socket_vmnet binary found.${NC}"

# --- STEP 3: CONFIGURE LIMA NETWORKS.YAML (GROUP FIX) ---
mkdir -p "$(dirname "$NETWORK_CONFIG_FILE")"
# ADDED: 'group: everyone' to ensure your user can connect to the root-owned socket
cat <<EOF > "$NETWORK_CONFIG_FILE"
paths:
  socketVMNet: "$SOCKET_VMNET_PATH"
  varRun: "/private/var/run"
group: "everyone"
networks:
  $NETWORK_NAME:
    mode: shared
    gateway: $GATEWAY_IP
    dhcpEnd: ${SUBNET_PREFIX}.254
    netmask: 255.255.255.0
EOF
echo -e "${GREEN}✅ Lima networks.yaml configured (Group: everyone).${NC}"

# --- STEP 4: CONFIGURE SUDOERS ---
echo ">>> Configuring Sudoers..."
cat <<EOF > lima.sudoers.tmp
$USER ALL=(root:wheel) NOPASSWD: /bin/mkdir
$USER ALL=(root:wheel) NOPASSWD: /usr/bin/pkill
$USER ALL=(root:wheel) NOPASSWD: /usr/bin/true
$USER ALL=(root:wheel) NOPASSWD: $SOCKET_VMNET_PATH
EOF

sudo mv lima.sudoers.tmp "$SUDOERS_FILE"
sudo chown root:wheel "$SUDOERS_FILE"
sudo chmod 440 "$SUDOERS_FILE"
echo -e "${GREEN}✅ Sudoers permissions applied.${NC}"

# --- STEP 5: DEEP CLEANUP ---
echo ">>> Cleaning up old instances & network sockets..."
limactl delete -f jumpbox server node-0 node-1 2>/dev/null || true
sudo pkill socket_vmnet || true
# Brutally clean potential stale sockets
sudo rm -f /private/var/run/socket_vmnet.subnet-desktop-shared*
sudo rm -f /var/run/socket_vmnet.subnet-desktop-shared*
echo -e "${GREEN}✅ Network sockets cleaned.${NC}"

# --- STEP 6: GENERATE VM TEMPLATE (QEMU MODE) ---
echo ">>> Generating VM Template (Forcing QEMU)..."
cat <<EOF > k8s-node-debian.yaml
vmType: "qemu"
images:
- location: "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  arch: "x86_64"
- location: "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"
  arch: "aarch64"
cpus: 2
memory: "2GiB"
networks:
- lima: $NETWORK_NAME
provision:
- mode: system
  script: |
    #!/bin/bash
    set -e
    cat <<EOT > /etc/systemd/network/10-lima0.network
    [Match]
    Name=lima0
    [Network]
    Address=IP_PLACEHOLDER/24
    Gateway=$GATEWAY_IP
    DNS=8.8.8.8
    EOT
    chmod 644 /etc/systemd/network/10-lima0.network
    systemctl restart systemd-networkd
EOF

# --- STEP 7: PROVISION NODES ---
HOSTS_ENTRY=""
for node in "${NODES[@]}"; do
  NAME=${node%%:*}
  IP_SUFFIX=${node##*:}
  IP="$SUBNET_PREFIX.$IP_SUFFIX"
  HOSTS_ENTRY="$HOSTS_ENTRY
$IP $NAME"
done

for node in "${NODES[@]}"; do
  NAME=${node%%:*}
  IP_SUFFIX=${node##*:}
  IP="$SUBNET_PREFIX.$IP_SUFFIX"

  echo "------------------------------------------------"
  echo ">>> Launching $NAME ($IP)..."

  sed -e "s/NAME_PLACEHOLDER/$NAME/g" \
      -e "s/IP_PLACEHOLDER/$IP/g" \
      k8s-node-debian.yaml > "$NAME.yaml"

  limactl start "$NAME.yaml" --name "$NAME" --tty=false

  echo ">>> Waiting for SSH..."
  for i in {1..40}; do
    if limactl shell "$NAME" true 2>/dev/null; then break; fi
    sleep 1
  done

  echo "$HOSTS_ENTRY" | limactl shell "$NAME" sudo tee -a /etc/hosts > /dev/null
done

# --- STEP 8: VERIFICATION ---
echo "------------------------------------------------"
echo -e "${GREEN}>>> Verifying Cluster Network...${NC}"
sleep 5
if limactl shell server ping -c 1 192.168.205.20 > /dev/null; then
    echo -e "${GREEN}✅ Success: server can ping node-0${NC}"
else
    echo -e "${RED}❌ Error: Network unreachable${NC}"
fi

echo "------------------------------------------------"
echo -e "${GREEN}>>> SETUP COMPLETE!${NC}"
