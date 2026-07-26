#!/usr/bin/env bash
set -euo pipefail

info()  { printf '\033[1;34m→\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m✓\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m!\033[0m %s\n' "$1"; }
err()   { printf '\033[1;31m✗\033[0m %s\n' "$1" >&2; }

banner() {
    printf '\033[1;36m'
    cat <<'EOF'

   ____ _                 _  _____                    _
  / ___| | ___  _   _  __| |_   _|   _ _ __  _ __   ___| |
 | |   | |/ _ \| | | |/ _` | | || | | | '_ \| '_ \ / _ \ |
 | |___| | (_) | |_| | (_| | | || |_| | | | | | | |  __/ |
  \____|_|\___/ \__,_|\__,_| |_| \__,_|_| |_|_| |_|\___|_|

                     C L O U D   T U N N E L   S E T U P
                              Made By Frosts

EOF
    printf '\033[0m'
    echo "This script gives your computer a secure, public web address using"
    echo "Cloudflare Tunnel, without opening any ports on your router."
    echo
    echo "Here's what's about to happen:"
    echo "  1. It checks if the Cloudflare Tunnel tool is already on your system."
    echo "  2. If it is, it shows you every tunnel you've already set up."
    echo "  3. If it isn't, it installs it, logs you into your Cloudflare account,"
    echo "     and helps you create your very first tunnel."
    echo
}

need_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            SUDO="sudo"
        else
            err "Installing software here needs admin rights, and 'sudo' isn't available."
            err "Try running this script as root instead."
            exit 1
        fi
    else
        SUDO=""
    fi
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)   echo "amd64" ;;
        aarch64|arm64)  echo "arm64" ;;
        armv7l)         echo "arm" ;;
        i386|i686)      echo "386" ;;
        *) err "Sorry, this script doesn't recognize your processor type: $(uname -m)"; exit 1 ;;
    esac
}

install_cloudflared() {
    need_sudo
    ARCH="$(detect_arch)"
    info "Your system's processor type is $ARCH. Good to know."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
    else
        DISTRO_ID="unknown"
    fi

    info "Looks like you're running: $DISTRO_ID"

    if command -v apt-get >/dev/null 2>&1; then
        info "Downloading and installing the Cloudflare Tunnel tool for your system..."
        TMP_DEB="$(mktemp --suffix=.deb)"
        curl -fsSL -o "$TMP_DEB" \
            "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
        $SUDO dpkg -i "$TMP_DEB" || $SUDO apt-get install -f -y
        rm -f "$TMP_DEB"

    elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        info "Downloading and installing the Cloudflare Tunnel tool for your system..."
        PKG_MGR="dnf"
        command -v dnf >/dev/null 2>&1 || PKG_MGR="yum"
        TMP_RPM="$(mktemp --suffix=.rpm)"
        curl -fsSL -o "$TMP_RPM" \
            "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.rpm"
        $SUDO "$PKG_MGR" install -y "$TMP_RPM"
        rm -f "$TMP_RPM"

    elif command -v pacman >/dev/null 2>&1; then
        info "Arch-based system detected."
        if command -v yay >/dev/null 2>&1; then
            info "Installing using yay..."
            yay -S --noconfirm cloudflared
        else
            warn "No AUR helper found, so this will grab the plain binary instead."
            install_raw_binary "$ARCH"
        fi

    else
        warn "Couldn't recognize your package manager, so this will grab the plain binary instead."
        install_raw_binary "$ARCH"
    fi

    if ! command -v cloudflared >/dev/null 2>&1; then
        err "Something went wrong. The install finished but cloudflared isn't showing up."
        exit 1
    fi

    ok "All set! Installed version: $(cloudflared --version)"
}

install_raw_binary() {
    ARCH="$1"
    need_sudo
    TMP_BIN="$(mktemp)"
    curl -fsSL -o "$TMP_BIN" \
        "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"
    chmod +x "$TMP_BIN"
    $SUDO mv "$TMP_BIN" /usr/local/bin/cloudflared
    ok "Installed to /usr/local/bin/cloudflared"
}

list_tunnels() {
    ok "Cloudflare Tunnel is already installed: $(cloudflared --version)"
    info "Here are all the tunnels you've saved so far:"
    echo
    if ! cloudflared tunnel list 2>/tmp/cf_list_err; then
        warn "Couldn't fetch your tunnels. You're probably not logged in yet."
        cat /tmp/cf_list_err
        echo
        read -r -p "Want to log in to Cloudflare now? A browser tab will open. [y/N]: " DO_LOGIN
        if [[ "$DO_LOGIN" =~ ^[Yy]$ ]]; then
            cloudflared tunnel login
            echo
            info "Trying again now that you're logged in:"
            cloudflared tunnel list
        fi
    fi
    rm -f /tmp/cf_list_err
}

create_new_tunnel() {
    CERT_PATH="${HOME}/.cloudflared/cert.pem"
    if [ ! -f "$CERT_PATH" ]; then
        echo
        info "One quick step first: you need to log into your Cloudflare account."
        info "A browser tab is about to open. Just log in and pick the domain you'd"
        info "like to use, then come back here."
        echo
        cloudflared tunnel login
        ok "Logged in successfully!"
    fi

    echo
    info "Now let's create your tunnel."
    read -r -p "What would you like to name it? (example: my-home-server): " TUNNEL_NAME
    while [ -z "$TUNNEL_NAME" ]; do
        read -r -p "That can't be empty, try again: " TUNNEL_NAME
    done

    echo
    info "Which local port should this tunnel send traffic to?"
    info "(This is usually whatever port your app or server is already running on,"
    info "like 3000, 8080, or 5000.)"
    read -r -p "Port number: " TUNNEL_PORT
    while ! [[ "$TUNNEL_PORT" =~ ^[0-9]+$ ]] || [ "$TUNNEL_PORT" -lt 1 ] || [ "$TUNNEL_PORT" -gt 65535 ]; do
        read -r -p "That's not a valid port. Enter a number between 1 and 65535: " TUNNEL_PORT
    done

    echo
    info "Creating your tunnel named '$TUNNEL_NAME'..."
    cloudflared tunnel create "$TUNNEL_NAME"

    TUNNEL_ID="$(cloudflared tunnel list --output json 2>/dev/null \
        | grep -o "\"id\":\"[a-f0-9-]*\",\"name\":\"${TUNNEL_NAME}\"" \
        | head -n1 | sed -E 's/"id":"([a-f0-9-]*)".*/\1/')"

    if [ -z "$TUNNEL_ID" ]; then
        warn "Your tunnel was created, but this script couldn't auto-detect its ID."
        warn "Run 'cloudflared tunnel list' to see it."
    else
        ok "Your tunnel is live! ID: $TUNNEL_ID"
        CONFIG_DIR="${HOME}/.cloudflared"
        CONFIG_FILE="${CONFIG_DIR}/${TUNNEL_NAME}-config.yml"
        mkdir -p "$CONFIG_DIR"
        cat > "$CONFIG_FILE" <<EOF
tunnel: ${TUNNEL_ID}
credentials-file: ${CONFIG_DIR}/${TUNNEL_ID}.json

ingress:
  - service: http://localhost:${TUNNEL_PORT}
EOF
        ok "A settings file was created for you at: $CONFIG_FILE"
        echo
        info "You're almost done. Just two optional steps left:"
        echo
        echo "  1. If you want a real web address (like tunnel.yourdomain.com),"
        echo "     connect it to this tunnel by running:"
        echo "       cloudflared tunnel route dns ${TUNNEL_NAME} <your-hostname>"
        echo
        echo "  2. Whenever you want to turn the tunnel on, run:"
        echo "       cloudflared tunnel --config ${CONFIG_FILE} run ${TUNNEL_NAME}"
        echo
        ok "That's it, you're ready to go!"
    fi
}

main() {
    banner
    if command -v cloudflared >/dev/null 2>&1; then
        list_tunnels
    else
        warn "Cloudflare Tunnel isn't installed on this system yet. Let's fix that."
        echo
        install_cloudflared
        create_new_tunnel
    fi
}

main "$@"
