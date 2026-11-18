# neo-pimpmykali

A modern, modular setup script for **Kali** (also Debian, Ubuntu and Parrot) for 2026 and beyond.

It is a rewrite of [Dewalt-arch/pimpmykali](https://github.com/Dewalt-arch/pimpmykali), merged with
my shell setup from [mybashrc](https://github.com/SpikeTheDragon40k/mybashrc).

## Quick start

```bash
git clone https://github.com/SpikeTheDragon40k/neo_pimpmykali.git ~/neo_pimpmykali
cd ~/neo_pimpmykali
./neo-pimpmykali.sh            # interactive menu
./neo-pimpmykali.sh --all      # everything
./neo-pimpmykali.sh -n --all   # dry run: show what would happen
```

Run it as your **normal user**, not with `sudo`. It asks for sudo when it needs it, so user-level
tools (pipx, go, your shell config) land in your own home.

## Options

| Flag | What it does |
|------|--------------|
| `--all` | core + toolchain + shell + wordlists + vm + all tools |
| `--core` | Kali signing key, apt hash fix, full-upgrade, base packages, smb.conf, nmap shellshock fix, hushlogin, no PC beep |
| `--toolchain` | go, rust (rustup), pipx, uv |
| `--shell` | bash as default shell, `.bashrc` from mybashrc, starship, ble.sh, eza, bat, zoxide, fzf, btop, fastfetch, Nerd Font |
| `--tools [ad,web,cloud,ai,extra]` | tools by category (default: all) |
| `--wordlists` | SecLists + decompressed rockyou |
| `--vm` | guest tools for VirtualBox/VMware/QEMU/Hyper-V, disables screen lock and power saving |
| `--update` | updates apt, pipx, uv, pdtm, go tools, rust, nuclei templates and this repo |
| `-y` | answer yes to everything |
| `-n`, `--dry-run` | change nothing, just print |
| `--no-upgrade` | skip apt full-upgrade |
| `--copy-bashrc` | copy `.bashrc` instead of symlinking it to the repo |

Everything is logged to `~/.neo-pimpmykali.log`. Running it twice is safe: anything already installed is skipped.

## Tools

The list lives in [`tools.conf`](tools.conf), one line per tool. The apt package is tried first, then a fallback
(pipx, uv, go, GitHub release or a custom function).

- **AD / internal**: netexec, impacket, BloodHound CE (bloodhound-cli + docker), bloodhound-ce-python, certipy, bloodyAD, evil-winrm-py, coercer, pywhisker, kerbrute, ligolo-ng, sliver, responder
- **Web / recon**: ProjectDiscovery via pdtm (nuclei, httpx, subfinder, katana, naabu, dnsx, interactsh), ffuf, feroxbuster, gowitness v3, arjun, dalfox, waybackurls, assetfinder
- **Cloud**: awscli, azure-cli, kubectl, trivy, pacu, prowler, ScoutSuite, roadrecon, azurehound
- **AI** (asks first): Claude Code, ollama, Kali MCP server
- **Extras**: ghidra, flameshot, VS Code (code-oss), Google Chrome

## Shell

`--shell` symlinks `~/.bashrc` to `dotfiles/.bashrc` in this repo (backing up the old one), so `git pull`
updates it. Pentest helpers go in `~/.config/neo-pimpmykali/pentest.bashrc`, loaded from `~/.bashrc.local`:

| Command | |
|---|---|
| `ipof [if]`, `tun0` | IP of an interface (default tun0) |
| `serve [port]` | python HTTP server, prints your tun0 URL |
| `smbserve [dir] [share]` | impacket SMB server |
| `listen [port]` | `rlwrap nc` listener |
| `ptyup` | prints the PTY upgrade one-liner |
| `mkengage <name>` | creates `~/engagements/<name>/{scans,loot,exploits,notes}` |
| `$SECLISTS`, `$ROCKYOU` | wordlist paths |

Put machine-specific settings in `~/.bashrc.local`.

## Layout

```
neo-pimpmykali.sh   entry point (flags + menu)
lib/                common helpers, distro detection, package helpers
modules/            core, toolchain, shell, tools, wordlists, vm, update
dotfiles/           .bashrc (from mybashrc), pentest.bashrc
tools.conf          tool list
addons/             fixed nmap http-shellshock.nse
```

## Credits

Original pimpmykali by [Dewalt](https://github.com/Dewalt-arch/pimpmykali) and contributors.
