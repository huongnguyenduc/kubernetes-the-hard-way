#!/bin/bash
set -e

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}!!! KUBERNETES THE HARD WAY - FACTORY RESET (v2) !!!${NC}"
echo -e "${YELLOW}This will delete:${NC}"
echo "  1. All VMs (jumpbox, server, node-0, node-1)"
echo "  2. The Sudoers configuration (/etc/sudoers.d/lima)"
echo "  3. Lima network config (~/.lima/_config/networks.yaml)"
echo "  4. All generated certificates, keys, and kubeconfigs"
echo "  5. Any lingering socket_vmnet processes and socket files"
echo ""
read -p "Are you sure you want to destroy everything? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# 1. KILL DAEMONS (Crucial step to release file locks)
echo -e "\n${GREEN}>>> Killing background network daemons...${NC}"
sudo pkill socket_vmnet || true
sudo pkill -f "limactl" || true

# 2. DELETE VMS
echo -e "${GREEN}>>> Deleting VMs...${NC}"
limactl delete -f jumpbox server node-0 node-1 2>/dev/null || echo "VMs already deleted."

# 3. REMOVE GHOST DIRECTORIES (From v4/v5 attempts)
if [ -d "$HOME/.lima/run_sockets" ]; then
    echo -e "${GREEN}>>> Removing ghost directory ~/.lima/run_sockets...${NC}"
    rm -rf "$HOME/.lima/run_sockets"
fi

# 4. REMOVE SYSTEM SOCKETS (The Permission Denied Fix)
echo -e "${GREEN}>>> Scrubbing system socket files...${NC}"
sudo rm -f /private/var/run/socket_vmnet.subnet-desktop-shared*
sudo rm -f /var/run/socket_vmnet.subnet-desktop-shared*
sudo rm -f /private/var/run/subnet-desktop-shared_socket_vmnet*

# 5. REMOVE SUDOERS
echo -e "${GREEN}>>> Removing System Permissions (sudoers)...${NC}"
if [ -f "/etc/sudoers.d/lima" ]; then
    sudo rm /etc/sudoers.d/lima
    echo "Removed /etc/sudoers.d/lima"
else
    echo "Sudoers file not found, skipping."
fi

# 6. REMOVE LIMA NETWORK CONFIG
echo -e "${GREEN}>>> Removing Lima Network Config...${NC}"
rm -f ~/.lima/_config/networks.yaml
echo "Removed ~/.lima/_config/networks.yaml"

# 7. CLEAN KNOWN_HOSTS
echo -e "${GREEN}>>> Cleaning SSH known_hosts...${NC}"
sed -i '' '/192.168.205./d' ~/.ssh/known_hosts 2>/dev/null || true

# 8. REMOVE LOCAL ARTIFACTS
echo -e "${GREEN}>>> Removing local generated files...${NC}"
rm -f machines.txt hosts
rm -f *.yaml
rm -f *.kubeconfig
rm -f *.crt *.key *.csr *.srl *.pem

echo -e "\n${GREEN}✅ FACTORY RESET COMPLETE.${NC}"
echo "Your system is clean."
