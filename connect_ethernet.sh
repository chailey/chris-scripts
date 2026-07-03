#!/bin/bash

INTERFACE=""
DHCP_MODE="true"
IP_ADDRESS=""
NETMASK=""
GATEWAY=""

show_help() {
  echo "Ethernet connection script"
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --interface <name>          Network interface (default: auto-detect)"
  echo "  --dhcp                      Use DHCP (default)"
  echo "  --static-ip <ip>            Static IP address"
  echo "  --netmask <mask>            Netmask for static IP"
  echo "  --gateway <gateway>         Gateway for static IP"
  echo "  --help                      Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0                         # Auto-connect with DHCP"
  echo "  $0 --interface eth0        # Connect specific interface with DHCP"
  echo "  $0 --interface eth0 --static-ip 192.168.1.100 --netmask 255.255.255.0 --gateway 192.168.1.1"
}

list_interfaces() {
  echo "Available network interfaces:"
  ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' | while read iface; do
    if [ "$iface" != "lo" ]; then
      status=$(ip link show "$iface" 2>/dev/null | grep -o 'state [^ ]*' | cut -d' ' -f2)
      echo "  $iface (state: $status)"
    fi
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --interface)
        INTERFACE="$2"
        shift 2
        ;;
      --dhcp)
        DHCP_MODE="true"
        shift
        ;;
      --static-ip)
        DHCP_MODE="false"
        IP_ADDRESS="$2"
        shift 2
        ;;
      --netmask)
        NETMASK="$2"
        shift 2
        ;;
      --gateway)
        GATEWAY="$2"
        shift 2
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

detect_interface() {
  if [ -z "$INTERFACE" ]; then
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$INTERFACE" ]; then
      INTERFACE=$(ip link show | grep -E '^[0-9]+: e[tn]' | awk -F': ' '{print $2}' | head -n1)
    fi
    if [ -z "$INTERFACE" ]; then
      INTERFACE=$(ip link show | grep -v 'lo:' | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' | head -n1)
    fi
  fi
  
  if [ -z "$INTERFACE" ]; then
    echo "Error: Could not auto-detect network interface"
    list_interfaces
    exit 1
  fi
  
  if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
    echo "Error: Interface $INTERFACE does not exist"
    list_interfaces
    exit 1
  fi
}

configure_dhcp() {
  echo "Configuring DHCP on $INTERFACE..."
  sudo ip link set "$INTERFACE" up
  
  if command -v dhclient >/dev/null 2>&1; then
    sudo dhclient "$INTERFACE"
  elif command -v dhcpcd >/dev/null 2>&1; then
    sudo dhcpcd "$INTERFACE"
  elif command -v systemd-networkctl >/dev/null 2>&1; then
    sudo systemd-networkctl up "$INTERFACE"
  else
    echo "Warning: No DHCP client found, interface may not get IP"
  fi
}

configure_static() {
  echo "Configuring static IP on $INTERFACE..."
  
  if [ -z "$IP_ADDRESS" ]; then
    echo "Error: Static IP address required for static configuration"
    exit 1
  fi
  
  sudo ip link set "$INTERFACE" up
  
  if [ -n "$NETMASK" ]; then
    sudo ip addr add "$IP_ADDRESS/$NETMASK" dev "$INTERFACE"
  else
    sudo ip addr add "$IP_ADDRESS/24" dev "$INTERFACE"
  fi
  
  if [ -n "$GATEWAY" ]; then
    sudo ip route add default via "$GATEWAY" dev "$INTERFACE"
  fi
}

test_connection() {
  echo "Testing network connectivity..."
  if ping -c 4 8.8.8.8 >/dev/null 2>&1; then
    echo "Network connection successful"
  else
    echo "Warning: Could not reach 8.8.8.8"
    exit 1
  fi
}

main() {
  parse_args "$@"
  detect_interface
  
  echo "Using interface: $INTERFACE"
  
  if [ "$DHCP_MODE" = "true" ]; then
    configure_dhcp
  else
    configure_static
  fi
  
  sleep 2
  test_connection
}

main "$@"