#!/bin/bash

TAILSCALE_ARGS=""
QUIET_MODE="false"
REINSTALL="false"

show_help() {
  echo "Tailscale installation and setup script"
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --args <arguments>           Additional arguments for 'tailscale up'"
  echo "  --quiet                      Silent mode (less output)"
  echo "  --reinstall                  Force reinstall Tailscale"
  echo "  --help                       Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0                           # Install and start Tailscale"
  echo "  $0 --args \"--accept-routes\" # Install with custom arguments"
  echo "  $0 --reinstall               # Force reinstall Tailscale"
}

check_installed() {
  command -v tailscale >/dev/null 2>&1
}

install_tailscale() {
  if [ "$QUIET_MODE" != "true" ]; then
    echo "Installing Tailscale..."
  fi
  
  curl -fsSL https://tailscale.com/install.sh | sh
  
  if [ $? -eq 0 ]; then
    if [ "$QUIET_MODE" != "true" ]; then
      echo "✓ Tailscale installed successfully"
    fi
  else
    echo "✗ Failed to install Tailscale"
    exit 1
  fi
}

start_tailscale() {
  if [ "$QUIET_MODE" != "true" ]; then
    echo "Starting Tailscale daemon..."
  fi
  
  sudo systemctl enable --now tailscaled
  
  if [ $? -eq 0 ]; then
    if [ "$QUIET_MODE" != "true" ]; then
      echo "✓ Tailscale daemon started"
    fi
  else
    echo "✗ Failed to start Tailscale daemon"
    exit 1
  fi
}

connect_tailscale() {
  if [ "$QUIET_MODE" != "true" ]; then
    echo "Connecting to Tailscale network..."
    echo "If this is your first time, you'll need to authenticate in your browser"
  fi
  
  if [ -n "$TAILSCALE_ARGS" ]; then
    sudo tailscale up $TAILSCALE_ARGS
  else
    sudo tailscale up
  fi
  
  if [ $? -eq 0 ]; then
    if [ "$QUIET_MODE" != "true" ]; then
      echo "✓ Connected to Tailscale network"
      echo ""
      echo "Your Tailscale IP:"
      tailscale ip -4
    fi
  else
    echo "✗ Failed to connect to Tailscale network"
    exit 1
  fi
}

show_status() {
  if [ "$QUIET_MODE" != "true" ]; then
    echo ""
    echo "=== Tailscale Status ==="
    tailscale status
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --args)
        TAILSCALE_ARGS="$2"
        shift 2
        ;;
      --quiet)
        QUIET_MODE="true"
        shift
        ;;
      --reinstall)
        REINSTALL="true"
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

main() {
  parse_args "$@"
  
  if [ "$REINSTALL" = "true" ] || ! check_installed; then
    if [ "$REINSTALL" = "true" ]; then
      echo "Reinstalling Tailscale..."
      sudo systemctl stop tailscaled
    fi
    install_tailscale
  else
    if [ "$QUIET_MODE" != "true" ]; then
      echo "Tailscale is already installed"
    fi
  fi
  
  if ! sudo systemctl is-active --quiet tailscaled; then
    start_tailscale
  fi
  
  if ! sudo tailscale status >/dev/null 2>&1; then
    connect_tailscale
  else
    if [ "$QUIET_MODE" != "true" ]; then
      echo "Tailscale is already connected"
    fi
  fi
  
  show_status
}

main "$@"