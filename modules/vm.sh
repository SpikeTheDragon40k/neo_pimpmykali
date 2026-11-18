# shellcheck shell=bash
# Virtual machine guest setup

disable_power_saving() {
    case "${XDG_CURRENT_DESKTOP:-}" in
        *GNOME*)
            info "GNOME: disabling suspend, screen blank and lock"
            run gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
            run gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
            run gsettings set org.gnome.settings-daemon.plugins.power power-button-action nothing
            run gsettings set org.gnome.desktop.session idle-delay 0
            run gsettings set org.gnome.desktop.screensaver lock-enabled false ;;
        *XFCE*)
            info "XFCE: disabling power management, blanking and lock"
            local p=/xfce4-power-manager
            run xfconf-query -c xfce4-power-manager -p $p/dpms-enabled -n -t bool -s false
            run xfconf-query -c xfce4-power-manager -p $p/blank-on-ac -n -t int -s 0
            run xfconf-query -c xfce4-power-manager -p $p/lock-screen-suspend-hibernate -n -t bool -s false
            run xfconf-query -c xfce4-screensaver -p /saver/enabled -n -t bool -s false
            run xfconf-query -c xfce4-screensaver -p /lock/enabled -n -t bool -s false ;;
        *)
            note "Desktop '${XDG_CURRENT_DESKTOP:-none}' not handled; disable screen lock/power saving manually if needed" ;;
    esac
}

module_vm() {
    section "VM guest setup"
    local virt
    virt=$(systemd-detect-virt 2>/dev/null || echo none)
    case "$virt" in
        oracle)
            info "VirtualBox detected"
            pkg_install virtualbox-guest-x11 virtualbox-guest-utils \
                || note "VirtualBox guest packages not in repos; insert Guest Additions CD from the VirtualBox menu"
            getent group vboxsf >/dev/null && ! id -nG "$USER" | grep -qw vboxsf && {
                as_root usermod -aG vboxsf "$USER"; note "Added to vboxsf (shared folders): log out and back in."; } ;;
        vmware)
            info "VMware detected"
            pkg_install open-vm-tools-desktop fuse3 ;;
        kvm|qemu)
            info "QEMU/KVM detected"
            pkg_install spice-vdagent qemu-guest-agent ;;
        microsoft)
            info "Hyper-V detected"
            pkg_install hyperv-daemons ;;
        none)
            warn "No hypervisor detected (bare metal?), skipping guest tools"; return 0 ;;
        *)
            warn "Hypervisor '$virt' has no specific handling" ;;
    esac
    disable_power_saving
}
