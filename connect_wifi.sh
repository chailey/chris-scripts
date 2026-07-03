#!/bin/bash

SSID=""
PASSWORD=""
BAND=""
LIST_ONLY="false"

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

install_network_tools() {
  if ! command -v nmcli >/dev/null 2>&1; then
    echo "Installing NetworkManager for $DETECTED_DISTRO..."
    case $DETECTED_DISTRO in
      ubuntu|debian|pop|linuxmint)
        $INSTALL_CMD networkmanager
        ;;
      fedora|rhel|centos|rocky|almalinux)
        $INSTALL_CMD NetworkManager
        ;;
      arch|manjaro|endeavouros)
        $INSTALL_CMD networkmanager
        ;;
      opensuse*suse*)
        $INSTALL_CMD NetworkManager
        ;;
    esac
    
    if ! systemctl is-active NetworkManager >/dev/null 2>&1; then
      sudo systemctl enable NetworkManager
      sudo systemctl start NetworkManager
    fi
  fi
}

show_help() {
  echo "Wi-Fi connection script"
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --name <name>              Network name to connect to
  --password <password>      Network password
  --band <2.4|5|6>           Frequency band (optional)
  --list                     List available networks
  --help                     Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --list                                    # List available networks"
  echo "  $0 --name \"MyNetwork\" --password \"secret\"  # Connect to network"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name)
        SSID="$2"
        shift 2
        ;;
      --password)
        PASSWORD="$2"
        shift 2
        ;;
      --band)
        BAND="$2"
        shift 2
        ;;
      --list)
        LIST_ONLY="true"
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
}

list_networks() {
  echo "Enabling Wi-Fi radio..."
  sudo nmcli radio wifi on
  
  echo "Scanning for networks..."
  nmcli dev wifi list
}

find_strongest_signal() {
  echo "Scanning for networks to find strongest signal..."
  sudo nmcli radio wifi on
  
  local wifi_list=$(nmcli -t -f SSID,SIGNAL,BAND dev wifi list | grep "^${SSID}:")
  
  if [ -z "$wifi_list" ]; then
    echo "Warning: Could not find \"$SSID\" in scan results, proceeding without band specification"
    return
  fi
  
  local strongest_signal=$(echo "$wifi_list" | sort -t':' -k2 -nr | head -n1)
  local strongest_band=$(echo "$strongest_signal" | cut -d':' -f3)
  local strongest_signal_strength=$(echo "$strongest_signal" | cut -d':' -f2)
  
  BAND=$strongest_band
  echo "Found strongest signal at ${strongest_signal_strength}% on ${BAND} GHz band"
}

connect_wifi() {
  if [ -z "$SSID" ]; then
    echo "Error: Network name is required"
    show_help
    exit 1
  fi
  
  if [ -z "$PASSWORD" ]; then
    echo "Error: Password is required"
    show_help
    exit 1
  fi
  
  echo "Enabling Wi-Fi radio..."
  sudo nmcli radio wifi on
  
  if [ -z "$BAND" ]; then
    find_strongest_signal
  fi
  
  echo "Connecting to \"$SSID\"..."
  
  if [ -n "$BAND" ]; then
    echo "Using frequency band: $BAND GHz"
    sudo nmcli dev wifi connect "$SSID" password "$PASSWORD" band "$BAND"
  else
    sudo nmcli dev wifi connect "$SSID" password "$PASSWORD"
  fi
  
  if [ $? -eq 0 ]; then
    echo "Successfully connected to \"$SSID\""
  else
    echo "Error: Failed to connect to \"$SSID\""
    exit 1
  fi
}

test_connection() {
  echo "Testing network connectivity..."
  sleep 2
  if ping -c 4 8.8.8.8 >/dev/null 2>&1; then
    echo "Network connection successful"
  else
    echo "Warning: Could not reach 8.8.8.8"
  fi
}

main() {
  detect_distro
  setup_install_cmd
  install_network_tools
  parse_args "$@"
  
  if [ "$LIST_ONLY" = "true" ]; then
    list_networks
  else
    connect_wifi
    test_connection
  fi
}

main "$@"