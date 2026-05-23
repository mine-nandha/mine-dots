#!/usr/bin/env bash
set -euo pipefail

# ─── mine-dots ──────────────────────────────────────────────────────────
# Dotfiles manager for Arch Linux + Hyprland
#
# Usage:
#   ./install.sh fresh            — Install everything on a new system
#   ./install.sh fresh --dry-run  — Preview what would be installed
#   ./install.sh sync             — Copy local dotfiles back into this repo
#   ./install.sh                  — Interactive menu
# ─────────────────────────────────────────────────────────────────────────

DOTDIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=false

# ── helpers ─────────────────────────────────────────────────────────────
info()  { printf "\033[1;34m[·]\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[✗]\033[0m %s\n" "$*"; }

run() {
  if $DRY_RUN; then
    printf "\033[2m  :: %s\033[0m\n" "$*"
  else
    eval "$@"
  fi
}

# ── config ──────────────────────────────────────────────────────────────
DOTFILES_SRC="$HOME"

DOTFILES_DIRS=(
  ".config/hypr"
  ".config/waybar"
  ".config/kitty"
)

# ── load packages from files ────────────────────────────────────────────
load_packages() {
  mapfile -t PACMAN_PKGS < "$DOTDIR/packages/pacman.txt"
  mapfile -t AUR_PKGS     < "$DOTDIR/packages/aur.txt"
}

# ── fresh install ───────────────────────────────────────────────────────
install_pacman() {
  info "Installing pacman packages..."
  if $DRY_RUN; then
    echo "${PACMAN_PKGS[@]}" | tr ' ' '\n' | sed 's/^/    /'
  fi
  run "sudo pacman -S --needed --noconfirm ${PACMAN_PKGS[*]}"
  ok "Pacman packages installed"
}

install_aur() {
  if ! command -v yay &>/dev/null; then
    info "Installing yay from AUR..."
    run "sudo pacman -S --needed --noconfirm git base-devel"
    run "git clone https://aur.archlinux.org/yay.git /tmp/yay-install"
    run "cd /tmp/yay-install && makepkg -si --noconfirm"
    run "rm -rf /tmp/yay-install"
    ok "yay installed"
  else
    ok "yay already installed"
  fi
  info "Installing AUR packages..."
  if $DRY_RUN; then
    echo "${AUR_PKGS[@]}" | tr ' ' '\n' | sed 's/^/    /'
  fi
  run "yay -S --needed --noconfirm ${AUR_PKGS[*]}"
  ok "AUR packages installed"
}

enable_services() {
  info "Enabling system services..."
  run "sudo systemctl enable --now NetworkManager.service 2>/dev/null" || warn "Could not enable NetworkManager"
  run "sudo systemctl enable --now bluetooth.service 2>/dev/null" || warn "Could not enable bluetooth"
  ok "Services enabled"
}

deploy_dots() {
  info "Deploying dotfiles..."
  for dir in "${DOTFILES_DIRS[@]}"; do
    local dest="$HOME/$dir"
    local src="$DOTDIR/$dir"
    if [[ -d "$src" ]]; then
      if $DRY_RUN; then
        printf "\033[2m  :: cp -r %s %s\033[0m\n" "$src" "$(dirname "$dest")/"
      else
        mkdir -p "$(dirname "$dest")"
        cp -r "$src" "$(dirname "$dest")"
      fi
      ok "Deployed  $dir"
    else
      warn "Skipped  $dir (not in repo)"
    fi
  done
}

cmd_fresh() {
  echo ""
  echo "  ╔══════════════════════════╗"
  echo "  ║     Fresh Install        ║"
  echo "  ╚══════════════════════════╝"
  echo ""
  $DRY_RUN && warn "DRY RUN — no changes will be made" && echo ""
  load_packages
  install_pacman
  install_aur
  enable_services
  deploy_dots
  echo ""
  info "All done! Reboot or start Hyprland with: Hyprland"
  echo ""
  echo "  Post-install tips:"
  echo "  - Lock screen:  Super + L"
  echo "  - Blue light:   Super + O (toggle)"
  echo "  - Clipboard:    Super + V"
  echo "  - Waybar reload: pkill waybar && waybar &"
  echo ""
}

# ── sync dotfiles ───────────────────────────────────────────────────────
cmd_sync() {
  echo ""
  echo "  ╔══════════════════════════╗"
  echo "  ║    Sync Local → Repo     ║"
  echo "  ╚══════════════════════════╝"
  echo ""

  local count=0
  for dir in "${DOTFILES_DIRS[@]}"; do
    local src="$DOTFILES_SRC/$dir"
    local dest="$DOTDIR/$dir"
    if [[ -d "$src" ]]; then
      rm -rf "$dest"
      mkdir -p "$(dirname "$dest")"
      cp -r "$src" "$(dirname "$dest")"
      info "Copied  $dir"
      count=$((count + 1))
    else
      warn "Skipped $dir (not found locally)"
    fi
  done
  echo ""
  ok "Synced $count directories to $DOTDIR"
}

# ── menu ────────────────────────────────────────────────────────────────
usage() {
  echo ""
  echo "  mine-dots — dotfiles manager"
  echo ""
  echo "  Usage:"
  echo "    ./install.sh fresh [--dry-run]   Install everything on a new system"
  echo "    ./install.sh sync                 Copy local dotfiles → mine-dots/"
  echo "    ./install.sh                      Interactive menu"
  echo ""
}

menu() {
  echo ""
  echo "  ╔══════════════════════════╗"
  echo "  ║      mine-dots           ║"
  echo "  ╚══════════════════════════╝"
  echo ""
  echo "  1) Fresh install  — install packages & deploy dotfiles"
  echo "  2) Dry run        — preview fresh install"
  echo "  3) Sync           — copy local changes back to this repo"
  echo "  4) Quit"
  echo ""
  read -rp "  Choose [1-4]: " choice
  case "$choice" in
    1) cmd_fresh ;;
    2) DRY_RUN=true; cmd_fresh ;;
    3) cmd_sync ;;
    4) exit 0 ;;
    *) err "Invalid choice"; exit 1 ;;
  esac
}

# ── main ────────────────────────────────────────────────────────────────
main() {
  case "${1:-}" in
    fresh|install)
      [[ "${2:-}" == "--dry-run" ]] && DRY_RUN=true
      cmd_fresh
      ;;
    sync|backup)    cmd_sync ;;
    -h|--help|help) usage ;;
    "")             menu ;;
    *)              err "Unknown command: $1"; usage; exit 1 ;;
  esac
}

main "$@"
