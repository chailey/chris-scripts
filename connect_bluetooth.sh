#!/bin/bash

DETECTED_DISTRO=""
INSTALL_CMD=""

detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DETECTED_DISTRO=$ID
  elif command -v lsb_release >/dev/null 2>&1; then
    DETECTED_DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
  elif [ -f /etc/redhat-release ]; then
    DETECTED_DISTRO="rhel"
  elif [ -f /etc/debian_version ]; then
    DETECTED_DISTRO="debian"
  else
    echo "Error: Unable to detect Linux distribution"
    exit 1
  fi
}

setup_install_cmd() {
  case $DETECTED_DISTRO in
    ubuntu|debian|pop|linuxmint)
      INSTALL_CMD="sudo apt-get install -y"
      ;;
    fedora|rhel|centos|rocky|almalinux)
      INSTALL_CMD="sudo dnf install -y"
      ;;
    arch|manjaro|endeavouros)
      INSTALL_CMD="sudo pacman -S --noconfirm"
      ;;
    opensuse*suse*)
      INSTALL_CMD="sudo zypper install -y"
      ;;
    *)
      echo "Unsupported distribution: $DETECTED_DISTRO"
      exit 1
      ;;
  esac
}

install_bluetooth() {
  if ! command -v bluetoothctl >/dev/null 2>&1; then
    echo "Installing bluetooth packages for $DETECTED_DISTRO..."
    case $DETECTED_DISTRO in
      ubuntu|debian|pop|linuxmint)
        $INSTALL_CMD bluez bluez-tools
        ;;
      fedora|rhel|centos|rocky|almalinux)
        $INSTALL_CMD bluez bluez-tools
        ;;
      arch|manjaro|endeavouros)
        $INSTALL_CMD bluez bluez-utils
        ;;
      opensuse*suse*)
        $INSTALL_CMD bluez
        ;;
    esac
    
    if [ "$DETECTED_DISTRO" = "arch" ] || [ "$DETECTED_DISTRO" = "manjaro" ] || [ "$DETECTED_DISTRO" = "endeavouros" ]; then
      sudo systemctl enable bluetooth
      sudo systemctl start bluetooth
    fi
  fi
}

MAC_ADDRESS=""
SCAN_MODE="false"

show_help() {
  echo "Bluetooth connection script"
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --mac <XX:XX:XX:XX:XX:XX>  Bluetooth MAC address to connect to"
  echo "  --scan                      Scan for available devices"
  echo "  --help                      Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --scan                  # Scan for devices"
  echo "  $0 --mac AA:BB:CC:DD:EE:FF # Connect to specific device"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --mac)
        MAC_ADDRESS="$2"
        shift 2
        ;;
      --scan)
        SCAN_MODE="true"
        shift
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
  
  if [ -z "$MAC_ADDRESS" ] && [ "$SCAN_MODE" != "true" ]; then
    echo "Error: Either --mac or --scan is required"
    show_help
    exit 1
  fi
}

connect_bluetooth() {
  echo "Starting bluetooth daemon..."
  if ! sudo systemctl is-active --quiet bluetooth; then
    sudo systemctl start bluetooth
  fi
  
  echo "Powering on bluetooth..."
  bluetoothctl power on
  
  echo "Starting agent..."
  bluetoothctl agent on
  bluetoothctl default-agent
  
  if [ "$SCAN_MODE" = "true" ]; then
    echo "Scanning for devices (Ctrl+C to stop)..."
    bluetoothctl scan on
  fi
  
  if [ -n "$MAC_ADDRESS" ]; then
    echo "Pairing with $MAC_ADDRESS..."
    bluetoothctl pair "$MAC_ADDRESS"
    
    echo "Trusting device $MAC_ADDRESS..."
    bluetoothctl trust "$MAC_ADDRESS"
    
    echo "Connecting to $MAC_ADDRESS..."
    bluetoothctl connect "$MAC_ADDRESS"
    
    echo "Device connection process complete"
  fi
}

detect_distro
setup_install_cmd
install_bluetooth
parse_args "$@"
connect_bluetooth