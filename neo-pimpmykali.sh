#!/usr/bin/env bash
# neo-pimpmykali - modern setup for Kali / Debian / Ubuntu / Parrot
# Fork of Dewalt-arch/pimpmykali, merged with SpikeTheDragon40k/mybashrc
set -uo pipefail

VERSION="3.0.0"
ROOT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LOG_FILE="$HOME/.neo-pimpmykali.log"

# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"
# shellcheck source=lib/distro.sh
. "$ROOT_DIR/lib/distro.sh"
# shellcheck source=lib/pkg.sh
. "$ROOT_DIR/lib/pkg.sh"
for m in "$ROOT_DIR"/modules/*.sh; do
    # shellcheck disable=SC1090
    . "$m"
done

usage() {
    cat <<EOF
neo-pimpmykali v$VERSION

Usage: ./neo-pimpmykali.sh [options]
       (no options: interactive menu)

Modules:
  --all               core + toolchain + shell + wordlists + vm + all tools
  --core              system fixes, full-upgrade, base packages
  --toolchain         go, rust, pipx, uv
  --shell             your bash setup (starship, ble.sh, eza, zoxide, fzf, Nerd Font)
  --tools [LIST]      tools by category, comma separated (default: all)
                      default: ${TOOL_CATEGORIES// /, }
                      optional: ${OPTIONAL_CATEGORIES} (ollama, heavy; never part of --all)
  --wordlists         SecLists + rockyou
  --vm                hypervisor guest tools, disable lock/power saving
  --update            update apt, pipx, uv, pdtm, go tools, rust and this repo

Options:
  -y, --yes           answer yes to every question
  -n, --dry-run       show what would happen, change nothing
  --no-upgrade        skip apt full-upgrade in --core
  --copy-bashrc       copy .bashrc instead of symlinking it to this repo
  -h, --help          this help
  -v, --version       print version
EOF
}

menu() {
    cat <<EOF

  ${BOLD}neo-pimpmykali v$VERSION${RESET}

   1) Full setup        (everything)
   2) Pentest tools     (core + toolchain + wordlists + all tools)
   3) Shell only        (bash, starship, ble.sh, CLI tools)
   4) VM fixes only
   5) Update everything
   6) Pick tool categories
   0) Quit

EOF
    local c
    read -r -p "  Choice: " c
    case "$c" in
        1) DO=(core toolchain shell wordlists vm tools) ;;
        2) DO=(core toolchain wordlists tools) ;;
        3) DO=(shell) ;;
        4) DO=(vm) ;;
        5) DO=(update) ;;
        6) read -r -p "  Categories (${TOOL_CATEGORIES// /,},$OPTIONAL_CATEGORIES): " TOOL_LIST; DO=(toolchain tools) ;;
        *) exit 0 ;;
    esac
}

DO=()
TOOL_LIST=""
while [ $# -gt 0 ]; do
    case "$1" in
        --all)        DO+=(core toolchain shell wordlists vm tools) ;;
        --core)       DO+=(core) ;;
        --toolchain)  DO+=(toolchain) ;;
        --shell)      DO+=(shell) ;;
        --wordlists)  DO+=(wordlists) ;;
        --vm)         DO+=(vm) ;;
        --update)     DO+=(update) ;;
        --tools)      DO+=(toolchain tools)
                      if [ -n "${2:-}" ] && [ "${2#-}" = "$2" ]; then TOOL_LIST=$2; shift; fi ;;
        -y|--yes)     ASSUME_YES=1 ;;
        -n|--dry-run) DRY_RUN=1 ;;
        --no-upgrade) export NO_UPGRADE=1 ;;
        --copy-bashrc) export BASHRC_COPY=1 ;;
        -v|--version) echo "$VERSION"; exit 0 ;;
        -h|--help)    usage; exit 0 ;;
        *)            usage; die "Unknown option: $1" ;;
    esac
    shift
done

# Run as your normal user: user-level tools (pipx, go, shell config) belong in your $HOME
if [ "$(id -u)" -eq 0 ]; then
    if [ -n "${SUDO_USER:-}" ]; then die "Don't run with sudo. Run as $SUDO_USER: ./neo-pimpmykali.sh (it asks for sudo when needed)."; fi
    warn "Running as root: everything will be set up for root's home ($HOME)."
fi

detect_distro
[ ${#DO[@]} -eq 0 ] && menu

if [ "$DRY_RUN" != 1 ]; then
    [ "$(id -u)" -eq 0 ] || sudo -v || die "sudo is required"
    # keep sudo alive for the whole run
    ( while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
    exec > >(tee -a "$LOG_FILE") 2>&1
    info "Logging to $LOG_FILE"
fi

# Run each module once, in a fixed order
for step in core toolchain shell wordlists vm tools update; do
    case " ${DO[*]} " in
        *" $step "*)
            if [ "$step" = tools ]; then module_tools "$TOOL_LIST"; else "module_$step"; fi ;;
    esac
done

print_notes
ok "Done. Open a new terminal (or 'exec bash') to load the new environment."
