# Cloud Tunnel Setup

**Made By Frosts**

A friendly, zero-hassle Bash script that sets up [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) on Linux — no port forwarding, no router config, no headaches.

Run it once. It figures out what you need and walks you through it in plain English.

---

## What it does

- **Already have `cloudflared` installed?** It lists every tunnel you've already created.
- **Don't have it yet?** It installs `cloudflared` for your distro, logs you into your Cloudflare account, asks you to name a tunnel and pick a port, then creates the tunnel and generates a ready-to-use config file.

No manual downloads, no digging through docs — just answer two questions and you're online.

---

## Requirements

- A Linux system (Debian/Ubuntu, Fedora/RHEL/CentOS, Arch, or generic)
- `curl`
- `sudo` access (only needed if `cloudflared` isn't already installed)
- A free [Cloudflare account](https://dash.cloudflare.com/sign-up)

---

## Usage

```bash
git clone https://github.com/your-username/your-repo.git
cd your-repo
chmod +x cloud-tunnel-setup.sh
./cloud-tunnel-setup.sh
```

Then just follow the prompts.

### If `cloudflared` is already installed

The script prints a list of all your saved tunnels. If you're not logged in yet, it'll offer to log you in first.

### If `cloudflared` isn't installed

1. The script detects your OS and CPU architecture.
2. It downloads and installs `cloudflared` the right way for your system (`.deb`, `.rpm`, AUR, or raw binary fallback).
3. It opens a browser tab so you can log into Cloudflare.
4. It asks:
   - **What would you like to name the tunnel?**
   - **Which local port should it point to?**
5. It creates the tunnel and writes a config file to `~/.cloudflared/<tunnel-name>-config.yml`.

---

## After setup

Two optional final steps, both printed at the end of the script:

**Connect a domain to your tunnel:**
```bash
cloudflared tunnel route dns <tunnel-name> <your-hostname>
```

**Start the tunnel:**
```bash
cloudflared tunnel --config ~/.cloudflared/<tunnel-name>-config.yml run <tunnel-name>
```

---

## Supported systems

| Distro family        | Install method     |
|-----------------------|--------------------|
| Debian / Ubuntu        | `.deb` package     |
| Fedora / RHEL / CentOS | `.rpm` package      |
| Arch (with `yay`)      | AUR                |
| Everything else         | Raw binary fallback |

Supported architectures: `amd64`, `arm64`, `arm`, `386`.

---

## License

MIT — do whatever you'd like with it.
