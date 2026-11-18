# shellcheck shell=bash
# Wordlists: SecLists + decompressed rockyou

module_wordlists() {
    section "Wordlists"
    pkg_install wordlists seclists
    [ -f /usr/share/wordlists/rockyou.txt ] && skip "rockyou.txt ready"
    if [ -f /usr/share/wordlists/rockyou.txt.gz ] && [ ! -f /usr/share/wordlists/rockyou.txt ]; then
        info "Decompressing rockyou.txt"
        as_root gzip -dk /usr/share/wordlists/rockyou.txt.gz
    fi
    if [ -d /usr/share/seclists ] || [ -d /usr/share/wordlists/seclists ]; then skip "SecLists ready"
    else
        info "Cloning SecLists to /opt/SecLists"
        as_root git clone -q --depth 1 https://github.com/danielmiessler/SecLists /opt/SecLists || note "SecLists clone failed"
    fi
}
