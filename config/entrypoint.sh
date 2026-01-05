#!/bin/sh

set -eux

# Loggin
log() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ----------------------------------
# ------ Environment Variables -----
# ----------------------------------

# Required 
: "${NAT64_PREFIX:?Missing 64_PREFIX}"
: "${LAN_INTERFACE:?Missing LAN_INTERFACE}"

# Optional 
COREDNS_DISABLE="${COREDNS_DISABLE:-false}"
COREDNS_UPSTREAM_DNS="${COREDNS_UPSTREAM_DNS:-1.1.1.1}"
COREDNS_TRANSLATE_ALL="${COREDNS_TRANSLATE_ALL:-translate-all}"

RADVD_DISABLE="${RADVD_DISABLE:-false}"
RADVD_FULL="${RADVD_FULL:-false}"

# ------------------------------------------
# ----- Functions to create conf files -----
# ------------------------------------------

radvd_min() {
	cat > /app/radvd.conf <<EOF
interface ${LAN_INTERFACE}
{
	AdvSendAdvert on;
	AdvDefaultLifetime 0;
	
	route ${NAT64_PREFIX}
	{
		AdvRouteLifetime 1800;
	};

	nat64prefix ${NAT64_PREFIX}
	{
		AdvValidLifetime 1800;
	};
};
EOF
}

radvd_full() {
	cat > /app/radvd.conf <<EOF
interface ${LAN_INTERFACE}
{
	AdvSendAdvert on;
	AdvManagedFlag off;
	AdvOtherConfigFlag off;

	prefix ${LAN_PREFIX}
	{
		AdvOnLink on;
		AdvAutonomous on;
		AdvRouterAddr off;
	};

	RDNSS ${DNS_IPV6}
	{
		AdvRDNSSLifetime 3600;
	};

	nat64prefix ${NAT64_PREFIX}
	{
		AdvValidLifetime 1800;
	};
};
EOF
}

coredns_file() {
	cat > /app/Corefile <<EOF
. {
forward . ${COREDNS_UPSTREAM_DNS}
dns64 {
	prefix ${NAT64_PREFIX}
	${COREDNS_TRANSLATE_ALL}
	}
}
EOF
}

tayga_file() {
	cat > /app/tayga.conf <<EOF
tun-device nat64
ipv4-addr 192.0.2.1
dynamic-pool 192.0.2.0/24
prefix ${NAT64_PREFIX}
EOF
}

# ----------------------
# ----- IPv6 Checks ----
# ----------------------

check_v6() {
	/app/v6check addr $1 >/dev/null 2>&1
	if [ $? != 0 ]; then
		echo "Invalid Addr - $1"
		exit
	fi
}

check_prefix() {
	/app/v6check prefix $1 >/dev/null 2>&1
	if [ $? != 0 ]; then
		echo "Invalid Prefix - $1"
		exit
	fi
}

v6_in_prefix() {
	/app/v6check contains $1 $2 >/dev/null 2>&1
	if [ $? != 0 ]; then
		echo "$1 not in $2"
		exit
	fi
}

# ----------------------------------------
# ----- Run coredns, tayga and radvd -----
# ----------------------------------------

# Check 64_prefix
check_prefix $NAT64_PREFIX

# RADVD
if [ "$RADVD_DISABLE" = "false" ]; then
	if [ "$RADVD_FULL" = "true" ]; then
		# Required envs
		: "${LAN_PREFIX:?Missing LAN_PREFIX}"
		: "${DNS_IPV6:?Missing DNS_IPV6}"

		check_v6 $DNS_IPV6
		check_prefix $LAN_PREFIX
		v6_in_prefix $DNS_IPV6 $LAN_PREFIX

		# create full config file
		radvd_full
		
	elif [ "$RADVD_FULL" = "false" ]; then
		
		# create minimal config file
		radvd_min
		
	fi

	# Start radvd in the background
	log "Starting RADVD..."
	mkdir -p /run/radvd
	chmod 644 /app/radvd.conf && \
	radvd --config /app/radvd.conf &

fi

# Coredns
coredns_file
log "Starting CoreDNS..."
coredns -conf /app/Corefile -quiet &

# Tayga
tayga_file
log "Staring Tayga..."
/app/tayga --config /app/tayga.conf &

# Tayga interface config
log "Configuring Tayga Interface..."

while ! ip link show nat64 >/dev/null 2>&1; do
	log "Waiting for nat64 interface to be created"
	sleep 1
done

ip link set nat64 up
ip route add 192.0.2.0/24 dev nat64
ip route add "${NAT64_PREFIX}" dev nat64

iptables -t nat -A POSTROUTING -s 192.0.2.0/24 -j MASQUERADE
sysctl -w net.ipv6.conf.all.forwarding=1

log "Finished Tayga Interface Config..."
log "Running..."

trap 'log "Stopping..."; kill 0; exit 0' INT TERM

wait
