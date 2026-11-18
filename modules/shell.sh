# shellcheck shell=bash
# shellcheck disable=SC2088  # "~/" in messages is for display only
# Shell setup, merged from github.com/SpikeTheDragon40k/mybashrc (setty.sh)

install_cli_tools() {
    info "Installing modern CLI tools"
    pkg_install bash bash-completion tree rsync fontconfig xz-utils micro nano libnotify-bin pciutils \
        btop duf ripgrep bat eza trash-cli zoxide fzf multitail fastfetch
    cli_release_fallbacks
    # Debian/Ubuntu name bat 'batcat'
    if ! have bat && have batcat; then run mkdir -p "$HOME/.local/bin"; run ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"; fi
    if ! have zoxide; then
        sh_run "curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh" || note "zoxide install failed"
    fi
    if ! have fzf && [ ! -d "$HOME/.fzf" ]; then
        run git clone -q --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" && run "$HOME/.fzf/install" --bin >/dev/null
    fi
    have fastfetch || [ "$DRY_RUN" = 1 ] || note "fastfetch could not be installed (optional)"
}

# When apt doesn't have them, get the official static builds from GitHub into ~/.local/bin
cli_release_fallbacks() {
    local x=x86_64 ff=amd64 duf=x86_64 mi=linux64-static
    if [ "$ARCH" = arm64 ]; then x=aarch64 ff=aarch64-polyfilled duf=arm64 mi=linux-arm64; fi
    have rg       || gh_install BurntSushi/ripgrep     "ripgrep-.*-${x}-unknown-linux-musl\.tar\.gz$" rg
    have bat      || have batcat || gh_install sharkdp/bat "bat-v.*-${x}-unknown-linux-musl\.tar\.gz$" bat
    have eza      || gh_install eza-community/eza      "eza_${x}-unknown-linux-gnu\.tar\.gz$" eza
    have duf      || gh_install muesli/duf             "duf_.*_linux_${duf}\.tar\.gz$" duf
    have btop     || gh_install aristocratos/btop      "btop-${x}-unknown-linux-musl\.tar\.gz$" btop
    have fastfetch || gh_install fastfetch-cli/fastfetch "fastfetch-linux-${ff}\.tar\.gz$" fastfetch
    have micro    || gh_install micro-editor/micro     "micro-.*-${mi}\.tar\.gz$" micro
    have trash-put || pipx_install trash-cli trash-put
}

install_blesh() {
    if [ -f /usr/share/blesh/ble.sh ] || [ -f "$HOME/.local/share/blesh/ble.sh" ]; then skip "ble.sh already installed"; return 0; fi
    pkg_install blesh 2>/dev/null && return 0
    info "Installing ble.sh nightly to ~/.local/share/blesh"
    sh_run 't=$(mktemp -d) && curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar -xJf - -C "$t" && bash "$t"/ble-nightly/ble.sh --install "$HOME/.local/share"; rm -rf "$t"' \
        || note "ble.sh install failed"
}

install_nerd_font() {
    local name="MesloLGS Nerd Font Mono" dir="$HOME/.local/share/fonts/Meslo"
    local fonts; fonts=$(fc-list : family 2>/dev/null)
    if grep -iqF "$name" <<<"$fonts"; then skip "Nerd Font already installed"; return 0; fi
    info "Installing $name"
    sh_run "t=\$(mktemp -d) && curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip -o \"\$t/m.zip\" && unzip -q \"\$t/m.zip\" -d \"\$t\" && mkdir -p '$dir' && find \"\$t\" -name '*.ttf' -exec mv {} '$dir'/ \\; ; rm -rf \"\$t\"; fc-cache -f >/dev/null 2>&1" \
        || note "Nerd Font install failed"
}

install_starship() {
    if ! have starship; then
        pkg_install starship 2>/dev/null || sh_run "mkdir -p \"\$HOME/.local/bin\" && curl -sS https://starship.rs/install.sh | sh -s -- -y -b \"\$HOME/.local/bin\"" \
            || { note "Starship install failed"; return 1; }
    fi
    if [ ! -f "$HOME/.config/starship.toml" ]; then
        run mkdir -p "$HOME/.config"
        run starship preset bracketed-segments -o "$HOME/.config/starship.toml"
    fi
}

link_bashrc() {
    local src="$ROOT_DIR/dotfiles/.bashrc"
    if [ -L "$HOME/.bashrc" ] && [ "$(readlink -f "$HOME/.bashrc")" = "$(readlink -f "$src")" ]; then
        skip "~/.bashrc already linked to this repo"
    else
        if [ -e "$HOME/.bashrc" ]; then
            local bak; bak="$HOME/.bashrc.backup.$(date +%Y%m%d%H%M%S)"
            info "Backing up ~/.bashrc to $bak"; run cp -P "$HOME/.bashrc" "$bak"
        fi
        if [ -d "$ROOT_DIR/.git" ] && [ "${BASHRC_COPY:-0}" != 1 ]; then
            run ln -sf "$src" "$HOME/.bashrc"; ok "~/.bashrc -> $src (git pull keeps it updated)"
        else
            run cp "$src" "$HOME/.bashrc"; ok "Copied .bashrc to ~/.bashrc"
        fi
    fi
    # Pentest additions live in their own file, loaded from ~/.bashrc.local
    run mkdir -p "$HOME/.config/neo-pimpmykali"
    run cp -f "$ROOT_DIR/dotfiles/pentest.bashrc" "$HOME/.config/neo-pimpmykali/pentest.bashrc"
    local line='[ -f "$HOME/.config/neo-pimpmykali/pentest.bashrc" ] && . "$HOME/.config/neo-pimpmykali/pentest.bashrc"'
    if ! grep -qsF "neo-pimpmykali/pentest.bashrc" "$HOME/.bashrc.local"; then
        if [ "$DRY_RUN" = 1 ]; then run "append pentest loader to ~/.bashrc.local"; else printf '%s\n' "$line" >>"$HOME/.bashrc.local"; fi
    fi
}

set_default_shell_bash() {
    local cur; cur=$(getent passwd "$USER" | cut -d: -f7)
    [ "$cur" = /bin/bash ] || [ "$cur" = /usr/bin/bash ] && { skip "Default shell is already bash"; return 0; }
    info "Changing default shell from $cur to bash"
    as_root chsh -s /bin/bash "$USER" && note "Default shell is now bash: log out and back in."
}

module_shell() {
    section "Shell: bash + starship + ble.sh + modern CLI (from mybashrc)"
    install_cli_tools
    install_blesh
    install_nerd_font
    install_starship
    link_bashrc
    set_default_shell_bash
}
