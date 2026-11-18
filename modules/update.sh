# shellcheck shell=bash
# Update everything installed by neo-pimpmykali

module_update() {
    section "Updating everything"
    system_upgrade
    have pipx    && { info "pipx upgrade-all"; run pipx upgrade-all; }
    have uv      && { info "uv tool upgrade --all"; run uv tool upgrade --all; }
    have pdtm    && { info "pdtm update all"; run pdtm -bp "$HOME/.pdtm/go/bin" -ua; }
    have nuclei  && run nuclei -update-templates -silent
    have rustup  && run rustup update
    if have go; then
        local _name _apt method src bin
        while IFS='|' read -r -u 3 _name _apt method src bin; do
            [ "$method" = go ] || continue
            # only refresh go tools we actually installed (not the apt copy)
            [ -x "$GOPATH/bin/$bin" ] && { info "go: $src"; run go install "$src"; }
        done 3< <(for c in $TOOL_CATEGORIES; do tools_in "$c"; done)
    fi
    [ -d "$ROOT_DIR/.git" ] && { info "Updating neo-pimpmykali repo"; run git -C "$ROOT_DIR" pull --ff-only || note "git pull failed in $ROOT_DIR"; }
}
