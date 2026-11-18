# shellcheck shell=bash
# Package helpers: apt (skips packages the repos don't have), pipx, uv, go, GitHub releases.

APT_REFRESHED=0

apt_refresh() {
    [ "$APT_REFRESHED" = 1 ] && return 0
    if [ "$DRY_RUN" = 1 ] && [ -z "$(find /var/lib/apt/lists -maxdepth 1 -name '*Packages*' -mtime -1 2>/dev/null | head -n1)" ]; then
        note "apt package lists are older than 1 day: dry-run may wrongly report packages as 'not available'. Run 'sudo apt update' first."
    fi
    info "Refreshing apt package lists"
    if as_root apt-get update -qq; then APT_REFRESHED=1
    else note "apt-get update failed: package checks below may be wrong. Run 'sudo apt update' to see the error."; APT_REFRESHED=1; fi
}

pkg_installed() { LC_ALL=C dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"; }
# LC_ALL=C: apt translates "Candidate:" on non-English systems
pkg_available() { LC_ALL=C apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate: [^(]'; }

# pkg_install pkg... : installs what exists, notes what doesn't. Returns 1 if anything was missing.
pkg_install() {
    apt_refresh
    local p todo=() missing=0
    for p in "$@"; do
        if pkg_installed "$p"; then continue
        elif pkg_available "$p"; then todo+=("$p")
        else missing=1; warn "apt: '$p' not available on $DISTRO, skipping"
        fi
    done
    if [ ${#todo[@]} -gt 0 ]; then
        info "apt install ${todo[*]}"
        as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${todo[@]}" || { note "apt failed installing: ${todo[*]}"; return 1; }
    fi
    return $missing
}

# Paths for user-level tool installs
export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$HOME/.local/bin:$GOPATH/bin:$HOME/.pdtm/go/bin:$HOME/.cargo/bin:/usr/local/go/bin:$PATH"

pipx_install() {
    local spec=$1 bin=${2:-}
    if [ -n "$bin" ] && have "$bin"; then skip "$bin already installed"; return 0; fi
    have pipx || pkg_install pipx || { note "pipx missing, cannot install $spec"; return 1; }
    info "pipx install $spec"
    run pipx install --force "$spec" >/dev/null || { note "pipx failed: $spec"; return 1; }
}

uv_install() {
    local spec=$1 bin=${2:-}
    if [ -n "$bin" ] && have "$bin"; then skip "$bin already installed"; return 0; fi
    have uv || pipx_install uv uv || return 1
    info "uv tool install $spec"
    run uv tool install --force "$spec" >/dev/null || { note "uv failed: $spec"; return 1; }
}

go_install() {
    local spec=$1 bin=${2:-}
    if [ -n "$bin" ] && have "$bin"; then skip "$bin already installed"; return 0; fi
    have go || pkg_install golang-go || { note "go missing, cannot install $spec"; return 1; }
    info "go install $spec"
    run go install "$spec" || { note "go install failed: $spec"; return 1; }
}

# gh_install owner/repo asset-regex bin [name-inside-archive] : latest release asset into ~/.local/bin
gh_install() {
    local repo=$1 pattern=$2 bin=$3 inner=${4:-$3} url tmp
    if have "$bin"; then skip "$bin already installed"; return 0; fi
    url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
        | grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 | grep -E "$pattern" | head -n1)
    [ -n "$url" ] || { note "No release asset matching '$pattern' in $repo"; return 1; }
    info "Downloading $url"
    [ "$DRY_RUN" = 1 ] && { run install "$bin" "$HOME/.local/bin/"; return 0; }
    tmp=$(mktemp -d)
    mkdir -p "$HOME/.local/bin"
    curl -fsSL "$url" -o "$tmp/asset" || { rm -rf "$tmp"; note "Download failed: $url"; return 1; }
    case "$url" in
        *.tar.gz|*.tgz) tar -xzf "$tmp/asset" -C "$tmp" ;;
        *.zip)          unzip -q "$tmp/asset" -d "$tmp" ;;
        *)              mv "$tmp/asset" "$tmp/$inner" ;;
    esac
    local found
    found=$(find "$tmp" -type f -name "$inner" | head -n1)
    if [ -n "$found" ]; then install -m 755 "$found" "$HOME/.local/bin/$bin"; ok "$bin installed to ~/.local/bin"
    else note "$bin not found inside $url"; fi
    rm -rf "$tmp"
}
