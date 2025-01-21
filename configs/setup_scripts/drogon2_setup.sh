#!/bin/bash

# A script to clean and set up network configurations using Open vSwitch (OVS).
# Usage:
#   sudo ./drogon2_setup.sh clean
#   sudo ./drogon2_setup.sh setup --delay <delay_ms> --ecn <0|1|2|3> --cc <cubic|bbr|reno|prague> --dualpi2 <1|0> --htb_rate <rate>

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage information
usage() {
    echo "Usage:"
    echo "  sudo $0 clean"
    echo "  sudo $0 setup --delay <delay_ms> --ecn <0|1|2|3> --cc <cubic|bbr|reno|prague> --dualpi2 <1|0> --htb_rate <rate>"
    echo ""
    echo "Options for setup:"
    echo "  --delay    Delay in milliseconds (e.g., 25)"
    echo "  --ecn      ECN setting (0: Disabled, 1: Enabled, 2: Custom1, 3: Custom2)"
    echo "  --cc       Congestion Control Algorithm (cubic, bbr, reno, prague)"
    echo "  --dualpi2  Dualpi2 setting (1: Enable, 0: Disable)"
    echo "  --htb_rate HTB rate (e.g., 500Mbit)"
    exit 1
}

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]: $*"
}

# Function to clean existing network configurations
clean() {
    log "Starting cleanup of existing network configurations..."

    # Delete all OVS bridges
    log "Deleting existing OVS bridges..."
    for bridge in $(ovs-vsctl list-br); do
        log "Deleting bridge: $bridge"
        ovs-vsctl del-br "$bridge"
    done

    # Delete veth_host_2 if it exists
    if ip link show veth_host_2 &>/dev/null; then
        log "Deleting veth_host_2 interface..."
        ip link del veth_host_2
    else
        log "veth_host_2 does not exist. Skipping deletion."
    fi

    # Delete network namespace router_ns_10 if it exists
    if ip netns list | grep -qw router_ns_10; then
        log "Deleting network namespace: router_ns_10"
        ip netns del router_ns_10
    else
        log "Network namespace router_ns_10 does not exist. Skipping deletion."
    fi

    # Bring down and up enp89s0 to reset it
    log "Resetting interface enp89s0..."
    ip link set enp89s0 down
    ip link set enp89s0 up

    # Remove specific routes if they exist
    ROUTE_TO_DELETE="10.0.0.1"
    if ip route show | grep -qw "$ROUTE_TO_DELETE"; then
        log "Deleting route to $ROUTE_TO_DELETE..."
        ip route del "$ROUTE_TO_DELETE"
    else
        log "Route to $ROUTE_TO_DELETE does not exist. Skipping deletion."
    fi

    # Restart networking services
    log "Restarting networking services..."
    systemctl restart networking || log "Failed to restart networking service."
    systemctl restart NetworkManager || log "Failed to restart NetworkManager service."

    sleep 3

    # Delete default route via 192.168.1.254 if it exists
    DEFAULT_ROUTE="default via 192.168.1.254"
    if ip route show | grep -qw "$DEFAULT_ROUTE"; then
        log "Deleting default route via 192.168.1.254..."
        ip route del default via 192.168.1.254
    else
        log "Default route via 192.168.1.254 does not exist. Skipping deletion."
    fi
    log "Cleanup completed successfully."
}

# Function to set up network configurations
setup() {
    # Default values
    DELAY=""
    ECN=""
    CC=""
    DUALPI2=""
    HTB_RATE=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --delay)
                DELAY="$2"
                shift
                shift
                ;;
            --ecn)
                ECN="$2"
                shift
                shift
                ;;
            --cc)
                CC="$2"
                shift
                shift
                ;;
            --dualpi2)
                DUALPI2="$2"
                shift
                shift
                ;;
            --htb_rate)
                HTB_RATE="$2"
                shift
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Validate inputs
    if [[ -z "$DELAY" || -z "$ECN" || -z "$CC" || -z "$DUALPI2" || -z "$HTB_RATE" ]]; then
        echo "Error: Missing required arguments for setup."
        usage
    fi

    if ! [[ "$DELAY" =~ ^[0-9]+$ ]]; then
        echo "Error: Delay must be a positive integer representing milliseconds."
        exit 1
    fi

    if ! [[ "$ECN" =~ ^[0-3]$ ]]; then
        echo "Error: ECN must be 0, 1, 2, or 3."
        exit 1
    fi

    if [[ "$CC" != "cubic" && "$CC" != "bbr" && "$CC" != "reno" && "$CC" != "prague" ]]; then
        echo "Error: Congestion Control Algorithm must be 'cubic', 'bbr', 'reno', or 'prague'."
        exit 1
    fi

    if [[ "$DUALPI2" != "0" && "$DUALPI2" != "1" ]]; then
        echo "Error: Dualpi2 must be either 1 (Enable) or 0 (Disable)."
        exit 1
    fi

    # Validate HTB_RATE format (e.g., 500Mbit, 1Gbit)
    if ! [[ "$HTB_RATE" =~ ^[0-9]+([KMG]bit)$ ]]; then
        echo "Error: HTB rate must be a positive integer followed by 'K', 'M', or 'G' (e.g., 500Mbit)."
        exit 1
    fi

    log "Starting network setup with parameters:"
    log "  Delay: $DELAY ms"
    log "  ECN: $ECN"
    log "  Congestion Control: $CC"
    log "  Dualpi2: $DUALPI2"
    log "  HTB Rate: $HTB_RATE"

    # Stop NetworkManager
    log "Stopping NetworkManager..."
    systemctl stop NetworkManager

    # Flush IP addresses on enp89s0
    log "Flushing IP addresses on enp89s0..."
    ip addr flush dev enp89s0

    # Delete existing OVS bridges
    log "Deleting existing OVS bridges (if any)..."
    for bridge in $(ovs-vsctl list-br); do
        log "Deleting bridge: $bridge"
        ovs-vsctl del-br "$bridge"
    done

    # Create OVS bridges
    log "Creating OVS bridges bridge10 and bridge11..."
    ovs-vsctl --may-exist add-br bridge10
    ovs-vsctl --may-exist add-br bridge11
    ip link set ovs-system up

    # Create veth pairs
    log "Creating veth pairs..."
    ip link show veth20 &>/dev/null || ip link add veth20 type veth peer name veth21
    ip link show veth22 &>/dev/null || ip link add veth22 type veth peer name veth23

    # Add veth ports to bridges
    log "Adding veth20 to bridge10 and veth22 to bridge11..."
    ovs-vsctl --may-exist add-port bridge10 veth20
    ovs-vsctl --may-exist add-port bridge11 veth22

    # Configure enp89s0
    log "Configuring enp89s0 on bridge11..."
    ip link set enp89s0 down
    ovs-vsctl --may-exist add-port bridge11 enp89s0
    ip link set enp89s0 up

    # Bring up interfaces and bridges
    log "Bringing up interfaces and bridges..."
    ip link set veth20 up
    ip link set veth22 up
    ip link set bridge10 up
    ip link set bridge11 up

    # Create network namespace router_ns_10
    log "Creating network namespace router_ns_10..."
    ip netns list | grep -qw router_ns_10 || ip netns add router_ns_10

    # Move veth interfaces to namespace
    log "Moving veth21 and veth23 to router_ns_10..."
    ip link set veth21 netns router_ns_10
    ip link set veth23 netns router_ns_10

    # Bring up interfaces inside namespace
    log "Bringing up interfaces inside router_ns_10..."
    ip netns exec router_ns_10 ip link set lo up
    ip netns exec router_ns_10 ip link set veth21 up
    ip netns exec router_ns_10 ip link set veth23 up

    # Assign IP addresses inside namespace
    log "Assigning IP addresses inside router_ns_10..."
    ip netns exec router_ns_10 ip addr add 11.0.0.254/24 dev veth21
    ip netns exec router_ns_10 ip addr add 192.168.1.2/24 dev veth23

    # Add route inside namespace
    log "Adding route inside router_ns_10: 10.0.0.0/24 via 192.168.1.1 dev veth23..."
    ip netns exec router_ns_10 ip route add 10.0.0.0/24 via 192.168.1.1 dev veth23 || log "Route addition failed or already exists."

    # Enable IP forwarding inside namespace
    log "Enabling IP forwarding inside router_ns_10..."
    ip netns exec router_ns_10 sysctl -w net.ipv4.ip_forward=1

    log "Enabling IP forwarding on Host..."
    sysctl -w net.ipv4.ip_forward=1


    # Set ECN based on input
    log "Setting TCP ECN host to $ECN..."
    case "$ECN" in
        0)
            sysctl -w net.ipv4.tcp_ecn=0
            ;;
        1)
            sysctl -w net.ipv4.tcp_ecn=1
            ;;
        2)
            sysctl -w net.ipv4.tcp_ecn=2
            ;;
        3)
            sysctl -w net.ipv4.tcp_ecn=3
            ;;
        *)
            echo "Error: Invalid ECN value. Must be 0, 1, 2, or 3."
            exit 1
            ;;
    esac

    # Set ECN based on input router
    log "Setting TCP ECN router to $ECN..."
    case "$ECN" in
        0)
            ip netns exec router_ns_10 sysctl -w net.ipv4.tcp_ecn=0
            ;;
        1)
            ip netns exec router_ns_10 sysctl -w net.ipv4.tcp_ecn=1
            ;;
        2)
            ip netns exec router_ns_10 sysctl -w net.ipv4.tcp_ecn=2
            ;;
        3)
            ip netns exec router_ns_10 sysctl -w net.ipv4.tcp_ecn=3
            ;;
        *)
            echo "Error: Invalid ECN value. Must be 0, 1, 2, or 3."
            exit 1
            ;;
    esac
    
    log "Applying TCP no metrics save to host"
    sysctl -w net.ipv4.tcp_no_metrics_save=1
    
    log "Applying TCP no metrics save to router"
    ip netns exec router_ns_10 sysctl -w net.ipv4.tcp_no_metrics_save=1
    
    # Apply congestion control specific settings
    if [[ "$CC" == "bbr" ]]; then
        log "Configuring settings specific to BBR..."
        modprobe tcp_bbr
        # Set congestion control algorithm
        log "Setting TCP congestion control algorithm to $CC..."
        sysctl -w net.ipv4.tcp_congestion_control="$CC"
        sysctl -w net.core.default_qdisc=fq
    
    elif [[ "$CC" == "cubic" ]]; then
        log "Configuring settings specific to CUBIC..."
        # Set congestion control algorithm
        log "Setting TCP congestion control algorithm to $CC..."
        sysctl -w net.ipv4.tcp_congestion_control="$CC"
    
    elif [[ "$CC" == "reno" ]]; then
        log "Configuring settings specific to RENO..."
        # Set congestion control algorithm
        log "Setting TCP congestion control algorithm to $CC..."
        sysctl -w net.ipv4.tcp_congestion_control="$CC"
    
    elif [[ "$CC" == "prague" ]]; then
        log "Configuring settings specific to PRAGUE..."
        modprobe tcp_prague
        modprobe sch_dualpi2
        # Set congestion control algorithm
        log "Setting TCP congestion control algorithm to $CC..."
        sysctl -w net.ipv4.tcp_congestion_control="$CC"
    fi

    # Setup traffic control (tc) with delay on veth21
    if [[ "$DELAY" -gt 0 ]]; then
        log "Configuring traffic control with $DELAY ms delay on veth21..."
        ip netns exec router_ns_10 tc qdisc add dev veth21 root netem delay "${DELAY}ms"
    fi

    # Setup HTB on veth23 with user-specified rate
    log "Configuring HTB on veth23 with rate $HTB_RATE..."
    ip netns exec router_ns_10 tc qdisc add dev veth23 root handle 1: htb default 3
    ip netns exec router_ns_10 tc class add dev veth23 parent 1: classid 1:3 htb rate "$HTB_RATE"

    # Setup Dualpi2 on veth23 if enabled
    if [[ "$DUALPI2" == "1" ]]; then
        log "Dualpi2 is enabled. Configuring Dualpi2 on veth23..."
        ip netns exec router_ns_10 tc qdisc add dev veth23 parent 1:3 dualpi2
    else
        log "Dualpi2 is disabled. Skipping Dualpi2 configuration on veth23..."
    fi


    # Connect bridge10 to host1 via veth_host_2 and veth_bridge20
    log "Creating and connecting veth_host_2 and veth_bridge20..."
    ip link show veth_host_2 &>/dev/null || ip link add veth_host_2 type veth peer name veth_bridge20
    ovs-vsctl --may-exist add-port bridge10 veth_bridge20
    ip link set veth_host_2 up
    ip link set veth_bridge20 up

    # Assign IP to veth_host_2
    log "Assigning IP 11.0.0.1/24 to veth_host_2..."
    ip addr add 11.0.0.1/24 dev veth_host_2 || log "IP assignment to veth_host_2 failed or already exists."

    # Add route to 11.0.0.0/24 via 10.0.0.254
    log "Adding route to 10.0.0.0/24 via 11.0.0.254 dev veth_host_2..."
    ip route add 10.0.0.0/24 via 11.0.0.254 dev veth_host_2 || log "Route addition failed or already exists."

    # Turning off tso gro and lro on veths
    ip netns exec router_ns_10 ethtool -K veth21 tso off gro off gso off lro off
    ip netns exec router_ns_10 ethtool -K veth23 tso off gro off gso off lro off
    # Turning off tso gro and lro on enp89s0
    ethtool -K enp89s0 tso off gro off gso off lro off
    ethtool -K veth_host_2 tso off gro off gso off lro off

    if [[ "$CC" == "bbr" ]]; then
        log "Setting fq at veth_host_2"
        tc qdisc replace dev veth_host_2 root fq
    fi

    log "Network setup completed successfully."
}

# Main script execution
if [[ $# -lt 1 ]]; then
    echo "Error: Insufficient arguments."
    usage
fi

COMMAND="$1"
shift

case "$COMMAND" in
    clean)
        clean
        ;;
    setup)
        setup "$@"
        ;;
    *)
        echo "Error: Unknown command '$COMMAND'."
        usage
        ;;
esac
