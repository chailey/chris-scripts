#!/bin/bash

DETECTED_DISTRO=""
INSTALL_CMD=""
PACKAGES="curl git tmux htop vim ufw rsync speedtest"
QUIET_MODE="false"

show_help() {
  echo "Essential packages installation script"
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --packages \"pkg1 pkg2...\"  Space-separated list of packages"
  echo "  --quiet                    Silent mode (less output)"
  echo "  --help                     Show this help message"
  echo ""
  echo "Default packages: $PACKAGES"
  echo ""
  echo "Examples:"
  echo "  $0                                      # Install default packages"
  echo "  $0 --packages \"curl git vim\"            # Install specific packages"
  echo "  $0 --quiet                             # Install with minimal output"
}

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
      INSTALL_CMD="sudo apt-get update && sudo apt-get install -y"
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

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --packages)
        PACKAGES="$2"
        shift 2
        ;;
      --quiet)
        QUIET_MODE="true"
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

check_installed() {
  local pkg=$1
  case $DETECTED_DISTRO in
    ubuntu|debian|pop|linuxmint)
      dpkg -l | grep -q "^ii  $pkg "
      return $?
      ;;
    fedora|rhel|centos|rocky|almalinux)
      rpm -q "$pkg" >/dev/null 2>&1
      return $?
      ;;
    arch|manjaro|endeavouros)
      pacman -Q "$pkg" >/dev/null 2>&1
      return $?
      ;;
    opensuse*suse*)
      rpm -q "$pkg" >/dev/null 2>&1
      return $?
      ;;
  esac
  return 1
}

install_speedtest() {
  if command -v speedtest >/dev/null 2>&1; then
    if [ "$QUIET_MODE" != "true" ]; then
      echo "speedtest is already installed, skipping..."
    fi
    return
  fi
  
  if [ "$QUIET_MODE" != "true" ]; then
    echo "Installing speedtest..."
  fi
  
  case $DETECTED_DISTRO in
    ubuntu|debian|pop|linuxmint)
      curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
      sudo apt-get install -y speedtest
      ;;
    fedora|rhel|centos|rocky|almalinux)
      curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash
      sudo dnf install -y speedtest
      ;;
    arch|manjaro|endeavouros)
      if command -v yay >/dev/null 2>&1; then
        yay -S --noconfirm speedtest-cli
      elif command -v paru >/dev/null 2>&1; then
        paru -S --noconfirm speedtest-cli
      else
        echo "Warning: speedtest-cli requires yay or paru on Arch-based systems"
        echo "Install with: yay -S speedtest-cli"
      fi
      ;;
    opensuse*suse*)
      sudo zypper install -y speedtest-cli
      ;;
  esac
  
  if [ $? -eq 0 ] && command -v speedtest >/dev/null 2>&1; then
    if [ "$QUIET_MODE" != "true" ]; then
      echo "✓ speedtest installed successfully"
    fi
  else
    echo "✗ Failed to install speedtest"
  fi
}

install_packages() {
  if [ "$QUIET_MODE" != "true" ]; then
    echo "Detected distribution: $DETECTED_DISTRO"
    echo "Installing packages: $PACKAGES"
  fi
  
  for pkg in $PACKAGES; do
    if [ "$pkg" = "speedtest" ]; then
      install_speedtest
      continue
    fi
    
    if check_installed "$pkg"; then
      if [ "$QUIET_MODE" != "true" ]; then
        echo "$pkg is already installed, skipping..."
      fi
    else
      if [ "$QUIET_MODE" != "true" ]; then
        echo "Installing $pkg..."
      fi
      
      $INSTALL_CMD "$pkg"
      
      if [ $? -eq 0 ]; then
        if [ "$QUIET_MODE" != "true" ]; then
          echo "✓ $pkg installed successfully"
        fi
      else
        echo "✗ Failed to install $pkg"
      fi
    fi
  done
}

configure_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    if [ "$QUIET_MODE" != "true" ]; then
      echo "Configuring UFW firewall..."
    fi
    
    if ! sudo ufw status | grep -q "Status: active"; then
      sudo ufw default deny incoming
      sudo ufw default allow outgoing
      sudo ufw allow ssh
      sudo ufw --force enable
      
      if [ "$QUIET_MODE" != "true" ]; then
        echo "✓ UFW firewall configured and enabled"
      fi
    else
      if [ "$QUIET_MODE" != "true" ]; then
        echo "UFW firewall is already active"
      fi
    fi
  fi
}

main() {
  detect_distro
  setup_install_cmd
  parse_args "$@"
  install_packages
  configure_firewall
  
  if [ "$QUIET_MODE" != "true" ]; then
    echo ""
    echo "Installation complete!"
  fi
}

main "$@"