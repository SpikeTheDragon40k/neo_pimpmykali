# shellcheck shell=bash
# Distro detection. Supported: Kali, Debian, Ubuntu, Parrot (apt-based only).

DISTRO=""
DISTRO_NAME=""
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)

detect_distro() {
    local osr=${OS_RELEASE:-/etc/os-release}  # override for testing
    [ -r "$osr" ] || die "$osr not found; unsupported system."
    # shellcheck disable=SC1090,SC1091
    . "$osr"
    DISTRO_NAME=${PRETTY_NAME:-$ID}
    case "${ID:-}" in
        kali|debian|ubuntu|parrot) DISTRO=$ID ;;
        *)
            case " ${ID_LIKE:-} " in
                *" ubuntu "*) DISTRO=ubuntu ;;
                *" debian "*) DISTRO=debian ;;
                *) die "Unsupported distro '$DISTRO_NAME'. Supported: Kali, Debian, Ubuntu, Parrot." ;;
            esac ;;
    esac
    have apt-get || die "apt-get not found."
    info "Detected $DISTRO_NAME ($DISTRO, $ARCH)"
    [ "$DISTRO" = kali ] || warn "Not Kali: tools missing from your repos are installed via pipx/go, or skipped."
}

is_kali() { [ "$DISTRO" = kali ]; }
