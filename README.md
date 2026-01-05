# 64router NAT64 Container

A Docker container that provides NAT64 routing functionality, allowing IPv6-only clients to access IPv4 services using Tayga, CoreDNS, and radvd.

## Environment Variables

### Required
- `NAT64_PREFIX`: The NAT64 IPv6 prefix (e.g., `fd64:cafe::/96`)
- `LAN_INTERFACE`: The LAN interface name (e.g., `bridge1`)

### Optional
- `COREDNS_DISABLE`: Disable CoreDNS (default: `false`)
- `COREDNS_UPSTREAM_DNS`: Upstream DNS server (default: `1.1.1.1`)
- `COREDNS_TRANSLATE_ALL`: Translate all queries (default: `translate-all`)
- `RADVD_DISABLE`: Disable radvd (default: `false`)
- `RADVD_FULL`: Use full radvd config (default: `false`)
- `LAN_PREFIX`: LAN IPv6 prefix for full radvd (required if `RADVD_FULL=true`)
- `DNS_IPV6`: Container IPv6 DNS address for full radvd (required if `RADVD_FULL=true`)

## Building for RouterOS 7.20+

Build the image for the target architecture (amd64 or arm64):

```bash
docker buildx build --platform linux/amd64 -t 64router:amd64 .
docker buildx build --platform linux/arm64 -t 64router:arm64 .
```

## Using on Mikrotik RouterOS 7.20+

Mikrotik RouterOS 7.20+ supports containers with NAT64 functionality. To use this NAT64 container:

### Prerequisites
- RouterOS device with RouterOS v7.20 or later and installed Container package
- Physical access to enable container mode
- Attached HDD, SSD or USB drive for storage (minimum 100MB/s sequential read/write speed recommended)

### Step 1: Enable Container Mode
Enable container mode and confirm with reset button or cold reboot:
```
/system/device-mode/update container=yes
```

### Step 2: Configure Network
Create veth interface and bridge for container networking:
```
/interface/veth/add name=veth1 address=172.17.0.2/24 gateway=172.17.0.1
/interface/bridge/add name=containers
/ip/address/add address=172.17.0.1/24 interface=containers
/interface/bridge/port/add bridge=containers interface=veth1
```

Configure IPv6 on the bridge:
```
/ipv6/address/add address=fd01:a1::1/64 interface=containers
```

### Step 3: Configure NAT Rules
Set up NAT for container traffic:
```
/ip/firewall/nat/add chain=srcnat action=masquerade src-address=172.17.0.0/24
/ipv6/firewall/nat/add chain=srcnat action=masquerade src-address=fd01:a1::/64
```

Port forwarding for DNS (UDP port 53):
```
/ip/firewall/nat/add action=dst-nat chain=dstnat dst-port=53 protocol=udp to-addresses=172.17.0.2 to-ports=53
```

### Step 4: Configure Container Environment
Set up environment variables:
```
/container/envs/add list=ENV_NAT64 key=NAT64_PREFIX value="fd64:cafe::/96"
/container/envs/add list=ENV_NAT64 key=LAN_INTERFACE value="veth1"
/container/envs/add list=ENV_NAT64 key=RADVD_FULL value="true"
/container/envs/add list=ENV_NAT64 key=LAN_PREFIX value="fd01:a1::/64"
/container/envs/add list=ENV_NAT64 key=DNS_IPV6 value="fd01:a1::1"
```

### Step 5: Add Container

**Option A: Pull from external registry**
```
/container/config/set registry-url=https://registry-1.docker.io tmpdir=disk1/tmp
/container/add remote-image=your-registry/64router interface=veth1 root-dir=disk1/images/nat64 envlist=ENV_NAT64 name=nat64 logging=yes
```

**Option B: Import from PC**
Build and save image on PC (for your router's architecture):
```
docker buildx build --platform linux/arm64 --output=type=docker -t 64router .
docker save 64router > 64router.tar
```
Upload `64router.tar` to router, then import:
```
/container/add file=disk1/64router.tar interface=veth1 root-dir=disk1/images/nat64 envlist=ENV_NAT64 name=nat64 logging=yes
```

### Step 6: Configure IPv6 Routing
Add route for NAT64 prefix:
```
/ipv6/route/add dst-address=fd64:cafe::/96 gateway=veth1
```

### Step 7: Start Container
Check container status:
```
/container/print
```
Start the container:
```
/container/start nat64
```

### Step 8: Enable Logging (Optional)
View container output in RouterOS log:
```
/container/set nat64 logging=yes
/log/print follow
```

### Troubleshooting
- Access container shell: `/container/shell nat64`
- Check container status: `/container/print`
- Ensure external disk is used for `root-dir` to avoid internal storage issues
- Set `start-on-boot=yes` for automatic startup: `/container/set nat64 start-on-boot=yes`