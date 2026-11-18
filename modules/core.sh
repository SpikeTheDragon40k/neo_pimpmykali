# shellcheck shell=bash
# Core system fixes and base packages

fix_kali_keyring() {
    is_kali || return 0
    info "Refreshing Kali archive signing key"
    as_root curl -fsSL https://archive.kali.org/archive-keyring.gpg -o /usr/share/keyrings/kali-archive-keyring.gpg \
        || note "Could not refresh the Kali signing key"
}

fix_bad_apt_hash() {
    # Works around 'Hash Sum mismatch' on some CPUs/VMs (libgcrypt hw acceleration)
    [ -f /etc/gcrypt/hwf.deny ] && return 0
    as_root mkdir -p /etc/gcrypt
    echo all | root_write /etc/gcrypt/hwf.deny
}

system_upgrade() {
    info "Upgrading the system (apt full-upgrade)"
    apt_refresh
    as_root env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -qq \
        -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold || note "apt full-upgrade reported errors"
    as_root apt-get --fix-broken install -y -qq
    as_root apt-get autoremove -y -qq
}

base_packages() {
    info "Installing base packages"
    pkg_install curl wget git unzip jq tmux rlwrap build-essential python3-venv pipx \
        "linux-headers-$(uname -r)" net-tools dnsutils locate htop samba-common-bin nmap
}

fix_smbconf() {
    local f=/etc/samba/smb.conf
    [ -f "$f" ] || return 0
    if grep -qi '^[[:space:]]*client min protocol *= *LANMAN1' "$f"; then skip "smb.conf already allows old SMB"; return 0; fi
    info "smb.conf: client min protocol = LANMAN1 (talk to legacy SMB targets)"
    as_root cp -n "$f" "$f.bak"
    as_root sed -i '/^[[:space:]]*client min protocol[[:space:]]*=/d' "$f"
    as_root sed -i '/^\[global\]/a\   client min protocol = LANMAN1' "$f"
}

fix_nmap_scripts() {
    local dir=/usr/share/nmap/scripts
    [ -d "$dir" ] || return 0
    info "Installing fixed http-shellshock.nse"
    as_root cp -f "$ROOT_DIR/addons/fixed-http-shellshock.nse" "$dir/http-shellshock.nse"
    as_root nmap --script-updatedb >/dev/null 2>&1
}

fix_hushlogin() { [ -f "$HOME/.hushlogin" ] || run touch "$HOME/.hushlogin"; }

silence_pcbeep() {
    [ -f /etc/modprobe.d/nobeep.conf ] && return 0
    echo "blacklist pcspkr" | root_write /etc/modprobe.d/nobeep.conf
    ok "PC speaker beep silenced"
}

module_core() {
    section "Core: system fixes and upgrade"
    fix_bad_apt_hash
    fix_kali_keyring
    if [ "${NO_UPGRADE:-0}" = 1 ]; then skip "Skipping full-upgrade (--no-upgrade)"; else system_upgrade; fi
    base_packages
    fix_smbconf
    fix_nmap_scripts
    fix_hushlogin
    silence_pcbeep
}
