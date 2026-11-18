# shellcheck shell=bash
# Language toolchains used by the tool installers: Go, Rust, pipx, uv

module_toolchain() {
    section "Toolchains: go, rust, pipx, uv"
    pkg_install golang-go pipx python3-venv git build-essential
    run mkdir -p "$HOME/.local/bin" "$GOPATH/bin"
    have pipx && run pipx ensurepath >/dev/null 2>&1
    pipx_install uv uv
    if ! have cargo && ! have rustup; then
        info "Installing Rust via rustup (user-level)"
        sh_run "curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path" \
            || note "rustup install failed"
    else
        skip "Rust already installed"
    fi
    have go && info "go: $(go version 2>/dev/null | awk '{print $3}')"
}
