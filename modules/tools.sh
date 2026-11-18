# shellcheck shell=bash
# Tool installer driven by tools.conf

TOOLS_CONF="$ROOT_DIR/tools.conf"
TOOL_CATEGORIES="ad web cloud ai extra"   # installed by default
OPTIONAL_CATEGORIES="ai-local"            # only when asked for by name

# Prints trimmed "name|apt|method|source|bin" lines for a category
tools_in() {
    awk -F'|' -v cat="$1" '
        /^[[:space:]]*(#|$)/ { next }
        { for (i = 1; i <= NF; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i) }
        $1 == cat { print $2 "|" $3 "|" $4 "|" $5 "|" $6 }
    ' "$TOOLS_CONF"
}

install_tool() {
    local name=$1 apt=$2 method=$3 src=$4 bin=$5
    if [ -n "$bin" ] && have "$bin"; then skip "$name already installed"; return 0; fi
    if [ -n "$apt" ] && pkg_available "$apt"; then
        pkg_install "$apt" && { ok "$name (apt)"; return 0; }
    fi
    case "$method" in
        pipx) pipx_install "$src" "$bin" ;;
        uv)   uv_install "$src" "$bin" ;;
        go)   go_install "$src" "$bin" ;;
        gh)   # shellcheck disable=SC2086
              gh_install $src "$bin" ;;
        func) "$src" ;;
        none) note "$name: not in $DISTRO repos and no fallback, skipped" ;;
        *)    note "$name: unknown method '$method'" ;;
    esac
}

install_category() {
    local cat=$1 name apt method src bin
    section "Tools: $cat"
    while IFS="|" read -r -u 3 name apt method src bin; do
        install_tool "$name" "$apt" "$method" "$src" "$bin"
    done 3< <(tools_in "$cat")
}

module_tools() {
    local cats=${1:-$TOOL_CATEGORIES} c
    for c in ${cats//,/ }; do
        case " $TOOL_CATEGORIES $OPTIONAL_CATEGORIES " in
            *" $c "*) install_category "$c" ;;
            *) warn "Unknown tool category '$c' (valid: $TOOL_CATEGORIES $OPTIONAL_CATEGORIES)" ;;
        esac
    done
}

# ---------- custom installers (method "func") ----------

install_docker() {
    have docker && return 0
    pkg_install docker.io
    pkg_install docker-compose-plugin 2>/dev/null || pkg_install docker-compose-v2 2>/dev/null || pkg_install docker-compose
    if ! have docker && [ "$DRY_RUN" != 1 ]; then note "Docker could not be installed"; return 1; fi
    as_root systemctl enable --now docker
    as_root usermod -aG docker "$USER"
    note "You were added to the 'docker' group: log out and back in to use docker without sudo."
}

install_bloodhound_ce() {
    install_docker || return 1
    local arch=amd64; [ "$ARCH" = arm64 ] && arch=arm64
    gh_install SpecterOps/bloodhound-cli "bloodhound-cli-linux-${arch}\.tar\.gz" bloodhound-cli
    note "BloodHound CE: run 'bloodhound-cli install' once (pulls containers, prints the admin password), then open http://127.0.0.1:8080"
}

install_pdtm_suite() {
    pkg_install libpcap-dev
    go_install github.com/projectdiscovery/pdtm/cmd/pdtm@latest pdtm || return 1
    info "pdtm: installing nuclei, httpx, subfinder, katana, naabu, dnsx, interactsh-client"
    run pdtm -bp "$HOME/.pdtm/go/bin" -i nuclei,httpx,subfinder,katana,naabu,dnsx,interactsh-client \
        || note "pdtm failed to install some ProjectDiscovery tools"
    # Kali's python 'httpx' package can shadow PD httpx; ~/.pdtm/go/bin is first in PATH via pentest.bashrc
    have nuclei && run nuclei -update-templates -silent
}

install_claude_code() {
    sh_run "curl -fsSL https://claude.ai/install.sh | bash" || note "Claude Code install failed"
}

install_opencode() {
    sh_run "curl -fsSL https://opencode.ai/install | bash" || note "OpenCode install failed"
}

install_ollama() {
    local ram_gb
    ram_gb=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
    if [ "${ram_gb:-0}" -lt 8 ]; then
        warn "Only ${ram_gb}GB RAM: local models will be very slow or won't load."
        ask "Install ollama anyway?" n || return 0
    fi
    sh_run "curl -fsSL https://ollama.com/install.sh | sh" || note "ollama install failed"
}

install_chrome() {
    [ "$ARCH" = amd64 ] || { note "Google Chrome is amd64 only, skipped"; return 0; }
    local deb=/tmp/google-chrome-stable_current_amd64.deb
    run curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o "$deb" || { note "Chrome download failed"; return 1; }
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$deb" || note "Chrome install failed"
    run rm -f "$deb"
}

install_ligolo() {
    local a=amd64; [ "$ARCH" = arm64 ] && a=arm64
    gh_install nicocha30/ligolo-ng "ligolo-ng_proxy_.*_linux_${a}\.tar\.gz$" ligolo-proxy proxy
    gh_install nicocha30/ligolo-ng "ligolo-ng_agent_.*_linux_${a}\.tar\.gz$" ligolo-agent agent
}

install_kubectl() {
    have kubectl && return 0
    local a=amd64 v; [ "$ARCH" = arm64 ] && a=arm64
    v=$(curl -fsSL https://dl.k8s.io/release/stable.txt) || { note "kubectl: could not get latest version"; return 1; }
    run mkdir -p "$HOME/.local/bin"
    run curl -fsSL "https://dl.k8s.io/release/$v/bin/linux/$a/kubectl" -o "$HOME/.local/bin/kubectl" && run chmod +x "$HOME/.local/bin/kubectl" \
        || note "kubectl download failed"
}

install_vscode() {
    have code && { skip "VS Code already installed"; return 0; }
    local a=x64 deb=/tmp/vscode.deb; [ "$ARCH" = arm64 ] && a=arm64
    run curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-$a" -o "$deb" || { note "VS Code download failed"; return 1; }
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$deb" || note "VS Code install failed"
    run rm -f "$deb"
}

install_sliver() {
    local a=amd64; [ "$ARCH" = arm64 ] && a=arm64
    gh_install BishopFox/sliver "sliver-server_linux-${a}$" sliver-server
    gh_install BishopFox/sliver "sliver-client_linux-${a}$" sliver-client
}
