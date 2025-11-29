# Kubernetes The Hard Way - Local macOS Lab (Lima Edition)

This repository contains automation scripts to provision a local computer cluster on macOS for following Kelsey Hightower's [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way "null").

Instead of using Google Cloud Platform (GCP), this setup uses **Lima** with QEMU and bridged networking (`socket_vmnet`) to create 4 distinct Linux VMs (Debian 12) on your local machine with static IPs.

## Prerequisites

1.  **macOS** (Apple Silicon or Intel)
    
2.  **Homebrew** installed
    
3.  **Lima** (v0.16.0 or higher)
    
    ```
    brew install lima
    
    ```
    
4.  **socket_vmnet** (Must be installed manually to `/opt`) _Do not use `brew install socket_vmnet`. Run these commands:_
    
    ```
    git clone [https://github.com/lima-vm/socket_vmnet.git](https://github.com/lima-vm/socket_vmnet.git)
    cd socket_vmnet
    sudo make PREFIX=/opt/socket_vmnet install
    
    ```
    

## Architecture

This lab creates a "Virtual Data Center" on your Mac using the `192.168.205.0/24` subnet.

Role

Hostname

IP Address

Description

**Gateway**

`lima0`

`192.168.205.1`

The host (your Mac) gateway address.

**Jumpbox**

`jumpbox`

`192.168.205.10`

The command center. You run all tutorial commands here.

**Control Plane**

`server`

`192.168.205.11`

Runs the API Server, Controller Manager, Scheduler, Etcd.

**Worker**

`node-0`

`192.168.205.20`

Kubernetes Worker Node.

**Worker**

`node-1`

`192.168.205.21`

Kubernetes Worker Node.

## Quick Start

### 1. Provision the Cluster

Run the start script. This will:

-   Configure `sudoers` permissions for networking (asks for password once).
    
-   Configure Lima's `networks.yaml`.
    
-   Launch 4 VMs using QEMU.
    
-   Setup Static IPs and `/etc/hosts` resolution.
    

```
chmod +x start-kthw.sh
./start-kthw.sh

```

### 2. Log in

Once the script finishes, log into the **Jumpbox**. This is where you will perform the tutorial steps.

```
limactl shell jumpbox

```

From here, you can access the other nodes as `root`:

```
# Example
sudo ssh root@server
sudo ssh root@node-0

```

### 3. Clean Up (Factory Reset)

When you are done or want to restart from scratch, run the cleanup script. This performs a deep clean, removing VMs, network sockets, and system configurations.

```
chmod +x cleanup-kthw.sh
./cleanup-kthw.sh

```

## Tutorial Adjustments

When following the official "Kubernetes The Hard Way" guide, make these mental adjustments:

1.  **IP Addresses:**
    
    -   Replace GCP IPs (e.g., `10.240.0.10`) with your Local IPs (e.g., `192.168.205.10`).
        
2.  **SSH Access:**
    
    -   You do not need to enable root login in `sshd_config` manually.
        
    -   Instead, generate an SSH key on the **jumpbox** and copy it to the other nodes.
        
3.  **Load Balancer:**
    
    -   The tutorial uses a GCP External Load Balancer. For this local lab, simply point your `kubeconfig` files directly to the `server` IP (`192.168.205.11`) or hostname (`server.kubernetes.local`).
        

## Troubleshooting

**Error: `dial unix ...: connect: permission denied`**

-   This means a stale root-owned socket file exists from a previous crash.
    
-   **Fix:** Run `./cleanup-kthw.sh` to forcefully remove stale sockets.
    

**Error: `FATA[0000] open .../run_sockets/lima.yaml: no such file`**

-   This means an old, invalid directory structure exists in `~/.lima`.
    
-   **Fix:** Run `./start-kthw.sh` (v6+), which automatically detects and removes this folder.
    

**Networking Fails (Pings fail)**

-   Ensure you installed `socket_vmnet` into `/opt/socket_vmnet`, NOT via Homebrew.
    
-   Ensure your local subnet matches `192.168.205.x`. If your Mac uses a different range for `shared` mode, update `SUBNET_PREFIX` in the scripts.
