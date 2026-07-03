#!/bin/bash

EMAIL=""
KEY_TYPE="ed25519"
KEY_PATH=""

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

install_dependencies() {
  if ! command -v ssh-keygen >/dev/null 2>&1; then
    echo "Installing OpenSSH for $DETECTED_DISTRO..."
    case $DETECTED_DISTRO in
      ubuntu|debian|pop|linuxmint)
        $INSTALL_CMD openssh-client
        ;;
      fedora|rhel|centos|rocky|almalinux)
        $INSTALL_CMD openssh
        ;;
      arch|manjaro|endeavouros)
        $INSTALL_CMD openssh
        ;;
      opensuse*suse*)
        $INSTALL_CMD openssh
        ;;
    esac
  fi
}

show_help() {
  echo "GitHub SSH key generation and setup script"
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --email <email>             GitHub email address (required)"
  echo "  --type <ed25519|rsa>        Key type (default: ed25519)"
  echo "  --path <path>               Custom key path (default: ~/.ssh/id_ed25519)"
  echo "  --help                      Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --email \"user@example.com\""
  echo "  $0 --email \"user@example.com\" --type rsa"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --email)
        EMAIL="$2"
        shift 2
        ;;
      --type)
        KEY_TYPE="$2"
        shift 2
        ;;
      --path)
        KEY_PATH="$2"
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

validate_args() {
  if [ -z "$EMAIL" ]; then
    echo "Error: Email is required"
    show_help
    exit 1
  fi
  
  if [ "$KEY_TYPE" != "ed25519" ] && [ "$KEY_TYPE" != "rsa" ]; then
    echo "Error: Key type must be 'ed25519' or 'rsa'"
    exit 1
  fi
  
  if [ -z "$KEY_PATH" ]; then
    if [ "$KEY_TYPE" = "ed25519" ]; then
      KEY_PATH="$HOME/.ssh/id_ed25519"
    else
      KEY_PATH="$HOME/.ssh/id_rsa"
    fi
  fi
}

generate_key() {
  echo "Generating $KEY_TYPE SSH key for $EMAIL..."
  
  KEY_ARGS=(-t "$KEY_TYPE" -C "$EMAIL")
  
  if [ "$KEY_TYPE" = "rsa" ]; then
    KEY_ARGS+=(-b 4096)
  fi
  
  if [ -f "$KEY_PATH" ]; then
    echo "Warning: Key file $KEY_PATH already exists"
    read -p "Overwrite existing key? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Key generation cancelled"
      exit 0
    fi
    rm -f "$KEY_PATH" "${KEY_PATH}.pub"
  fi
  
  ssh-keygen "${KEY_ARGS[@]}" -f "$KEY_PATH"
  
  if [ $? -eq 0 ]; then
    echo "Key generated successfully"
  else
    echo "Error: Failed to generate SSH key"
    exit 1
  fi
}

setup_ssh_agent() {
  echo "Setting up SSH agent..."
  eval "$(ssh-agent -s)"
  
  ssh-add "$KEY_PATH"
  
  if [ $? -eq 0 ]; then
    echo "Key added to SSH agent"
  else
    echo "Warning: Failed to add key to SSH agent"
  fi
}

show_key_info() {
  echo ""
  echo "=== SSH Key Information ==="
  echo "Key type: $KEY_TYPE"
  echo "Key file: $KEY_PATH"
  echo "Public key:"
  echo ""
  cat "${KEY_PATH}.pub"
  echo ""
  echo "=== Next Steps ==="
  echo "1. Copy your public key:"
  echo "   cat ${KEY_PATH}.pub"
  echo ""
  echo "2. Add it to your GitHub account:"
  echo "   - Go to https://github.com/settings/keys"
  echo "   - Click 'New SSH key'"
  echo "   - Paste the public key"
  echo ""
  echo "3. Test connection:"
  echo "   ssh -T git@github.com"
}

main() {
  detect_distro
  setup_install_cmd
  install_dependencies
  parse_args "$@"
  validate_args
  generate_key
  setup_ssh_agent
  show_key_info
}

main "$@"