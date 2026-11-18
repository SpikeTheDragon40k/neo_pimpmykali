# shellcheck shell=bash
# Shared helpers: output, prompts, dry-run aware command runner, notes.

if [ -t 1 ]; then
    RED=$'\e[1;31m'; GREEN=$'\e[1;32m'; YELLOW=$'\e[1;33m'; BLUE=$'\e[1;34m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
else
    RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
fi

DRY_RUN=${DRY_RUN:-0}
ASSUME_YES=${ASSUME_YES:-0}
NOTES=()

section() { printf '\n%s==> %s%s\n' "$BLUE$BOLD" "$*" "$RESET"; }
info()    { printf '  %s[*]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()      { printf '  %s[+]%s %s\n' "$GREEN" "$RESET" "$*"; }
skip()    { printf '  %s[-]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()    { printf '  %s[!]%s %s\n' "$YELLOW" "$RESET" "$*"; }
err()     { printf '  %s[x]%s %s\n' "$RED" "$RESET" "$*" >&2; }
die()     { err "$*"; exit 1; }

# Remember something to show in the final summary
note() { NOTES+=("$*"); warn "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ask "Question?" [default y|n] -> 0 for yes
ask() {
    local q=$1 def=${2:-n} ans hint="[y/N]"
    [ "$def" = y ] && hint="[Y/n]"
    if [ "$ASSUME_YES" = 1 ]; then return 0; fi
    if [ ! -t 0 ]; then [ "$def" = y ]; return; fi
    read -r -p "  ${YELLOW}[?]${RESET} $q $hint " ans
    ans=${ans:-$def}
    [[ $ans =~ ^[Yy] ]]
}

# run CMD... : execute, or just print it in dry-run mode
run() {
    if [ "$DRY_RUN" = 1 ]; then
        printf '  %s[dry-run]%s %s\n' "$YELLOW" "$RESET" "$*" >&2
        return 0
    fi
    "$@"
}

# sh_run "shell string" : for pipelines like curl ... | sh
sh_run() { run bash -c "$1"; }

# sudo only when needed
as_root() { if [ "$(id -u)" -eq 0 ]; then run "$@"; else run sudo "$@"; fi; }

# Write stdin to a root-owned file
root_write() {
    local dest=$1
    if [ "$DRY_RUN" = 1 ]; then
        printf '  %s[dry-run]%s write %s\n' "$YELLOW" "$RESET" "$dest"; cat >/dev/null; return 0
    fi
    sudo tee "$dest" >/dev/null
}

print_notes() {
    [ ${#NOTES[@]} -eq 0 ] && { ok "Finished with no warnings."; return; }
    section "Things that need your attention"
    local n; for n in "${NOTES[@]}"; do warn "$n"; done
}
