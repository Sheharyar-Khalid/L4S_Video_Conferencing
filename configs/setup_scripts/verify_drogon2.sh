#!/bin/bash

# A script to verify network configurations by printing sysctl variables and tc qdisc settings
# on both the host and the network namespace 'router_ns_10'

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]: $*"
}

# Function to print sysctl variables
print_sysctl() {
    local scope="$1"  # "Host" or "router_ns_10"

    log "===== $scope: Sysctl Variables ====="

    # Define the list of sysctl variables to check
    local variables=("net.ipv4.tcp_ecn" "net.ipv4.tcp_congestion_control" "net.ipv4.ip_forward" "net.ipv4.tcp_no_metrics_save")

    for var in "${variables[@]}"; do
        if [[ "$scope" == "Host" ]]; then
            if sysctl -n "$var" &>/dev/null; then
                value=$(sysctl -n "$var")
            else
                value="Not Set"
            fi
        else
            if ip netns exec router_ns_10 sysctl -n "$var" &>/dev/null; then
                value=$(ip netns exec router_ns_10 sysctl -n "$var")
            else
                value="N/A or Not Set"
            fi
        fi
        echo "$var: $value"
    done
    echo ""
}

# Function to print tc qdisc
print_tc_qdisc() {
    local scope="$1"  # "Host" or "router_ns_10"

    log "===== $scope: tc qdisc ====="

    if [[ "$scope" == "Host" ]]; then
        # List all network interfaces excluding loopback and virtual interfaces
        interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo" | grep -v "virbr" | grep -v "docker" | grep -v "veth")
        if [[ -z "$interfaces" ]]; then
            log "No relevant interfaces found on Host."
            return
        fi
        for iface in $interfaces; do
            echo "Interface: $iface"
            tc qdisc show dev "$iface"
            echo ""
        done
    else
        # List all network interfaces inside the namespace excluding loopback
        interfaces=$(ip netns exec router_ns_10 ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")
        if [[ -z "$interfaces" ]]; then
            log "No relevant interfaces found in router_ns_10."
            return
        fi
        for iface in $interfaces; do
            base_iface="${iface%%@*}"
            echo "Interface: $base_iface"
            ip netns exec router_ns_10 tc qdisc show dev "$base_iface"
            echo ""
        done
    fi
    echo ""
}

# Main script execution

log "Starting verification of network configurations..."

# Print sysctl variables for Host
print_sysctl "Host"

# Print tc qdisc for Host
print_tc_qdisc "Host"

# Check if 'router_ns_10' namespace exists
if ip netns list | grep -qw "router_ns_10"; then
    # Print sysctl variables for router_ns_10
    print_sysctl "router_ns_10"

    # Print tc qdisc for router_ns_10
    print_tc_qdisc "router_ns_10"
else
    log "Network namespace 'router_ns_10' does not exist. Skipping verification for router_ns_10."
fi

log "Verification completed."
