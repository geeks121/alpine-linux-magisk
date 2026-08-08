#!/system/bin/sh
# Alpine Linux - Common Functions Library v1.3.4

#=======================================
# Path Configuration
#=======================================
R="/data/alpine_linux"
RF="$R/rootfs"
SVC="$R/services"
LOG="$R/alpine.log"

#=======================================
# Common Environment Variables
#=======================================
CHROOT_ENV="HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin TERM=xterm-256color LANG=C.UTF-8"

#=======================================
# Colors and Logging
#=======================================
Rd='\033[0;31m'; Gr='\033[0;32m'; Yw='\033[1;33m'; Nc='\033[0m'
log() {
    mkdir -p "${LOG%/*}" 2>/dev/null
    if [ -f "$LOG" ]; then
        local lines=$(wc -l < "$LOG" 2>/dev/null)
        [ -n "$lines" ] && [ "$lines" -gt 1000 ] && mv "$LOG" "$LOG.1" 2>/dev/null
    fi
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [$1] $2"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${Gr}[$1]${Nc} $2"
    echo "$msg" >> "$LOG"
}
err() { log ERROR "$1"; }
wrn() { log WARN "$1"; }
inf() { log INFO "$1"; }

#=======================================
# rootfs Check
#=======================================
ck() {
    [ -d "$RF" ] || return 1
    for d in bin dev etc lib root usr sbin var tmp; do
        [ -d "$RF/$d" ] || return 1
    done
    [ -x "$RF/bin/sh" ] || [ -L "$RF/bin/sh" ]
}

#=======================================
# Runtime Status
#=======================================
run() {
    mountpoint -q "$RF/proc" 2>/dev/null
}

#=======================================
# Mount Management
#=======================================
mnt() {
    inf "Mounting..."
    mount -t proc proc "$RF/proc" 2>/dev/null
    mount -t sysfs sysfs "$RF/sys" 2>/dev/null
    mount --bind /dev "$RF/dev" 2>/dev/null
    mkdir -p "$RF/dev/pts" && mount -t devpts devpts "$RF/dev/pts" 2>/dev/null
    mkdir -p "$RF/tmp" "$RF/run"
    mount -t tmpfs tmpfs "$RF/tmp" 2>/dev/null && chmod 1777 "$RF/tmp"
    mount -t tmpfs tmpfs "$RF/run" 2>/dev/null
}

umnt() {
    inf "Unmounting..."
    for m in run tmp dev/pts dev sys proc; do
        mountpoint -q "$RF/$m" 2>/dev/null && umount -l "$RF/$m" 2>/dev/null
    done
}

#=======================================
# Network Configuration
#=======================================
net() {
    inf "Configuring network..."
    cp /system/etc/resolv.conf "$RF/etc/resolv.conf" 2>/dev/null || \
        cp /etc/resolv.conf "$RF/etc/resolv.conf" 2>/dev/null || \
        echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > "$RF/etc/resolv.conf"
    grep -q "127.0.0.1" "$RF/etc/hosts" 2>/dev/null || \
        echo -e "127.0.0.1 localhost\n::1 localhost" > "$RF/etc/hosts"
}

#=======================================
# Storage Mount (Fixed: Remove Android system directory mount)
#=======================================
smnt() {
    inf "Mounting storage..."
    mkdir -p "$RF/mnt/sdcard" "$RF/mnt/external_sd"
    [ -d /sdcard ] && mount --bind /sdcard "$RF/mnt/sdcard" 2>/dev/null
    local sd=""; [ -d /storage/external_SD ] && sd="/storage/external_SD"; [ -d /external_sd ] && sd="/external_sd"
    [ -n "$sd" ] && mount --bind "$sd" "$RF/mnt/external_sd" 2>/dev/null
    return 0
}

sumnt() {
    for m in sdcard external_sd; do
        mountpoint -q "$RF/mnt/$m" 2>/dev/null && umount -l "$RF/mnt/$m" 2>/dev/null
    done
}

#=======================================
# Container Start/Stop (Fixed: Improve error handling)
#=======================================
alpine_start() {
    ck || { err "rootfs not found"; inf "Please run: alpine download first"; return 1; }
    run && { wrn "Already running"; return 0; }
    inf "Starting Alpine Linux..."
    mkdir -p "$R" && chmod 755 "$R" "$RF"
    mnt || { err "Mount failed"; return 1; }
    net || { umnt; err "Network config failed"; return 1; }
    smnt
    inf "Start complete"
    alpine_service_start_all
}

alpine_stop() {
    run || { wrn "Not running"; return 0; }
    inf "Stopping Alpine Linux..."
    inf "Terminating processes..."
    # Terminate all processes with rootfs as root
    local rf_path=$(echo "$RF" | sed 's#/$##')
    for pid in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
        [ -L "/proc/$pid/root" ] || continue
        local root=$(readlink "/proc/$pid/root" 2>/dev/null | sed 's#/$##')
        [ "$root" = "$rf_path" ] && kill -9 "$pid" 2>/dev/null
    done
    # Use fuser to ensure cleanup
    fuser -k "$RF" 2>/dev/null
    fuser -k "$RF"/mnt/* 2>/dev/null
    sleep 1
    sumnt; umnt
    inf "Stopped"
}

#=======================================
# Execute Command (Fixed: Use common environment variables)
#=======================================
alpine_exec() {
    ck || { err "rootfs not found"; return 1; }
    if [ -z "$1" ]; then
        chroot "$RF" /bin/sh -c "export $CHROOT_ENV; exec /bin/sh"
    else
        chroot "$RF" /bin/sh -c "export $CHROOT_ENV; $*"
    fi
}

#=======================================
# Status View
#=======================================
alpine_status() {
    echo "========================================"
    echo " Alpine Linux Status"
    echo "========================================"
    run && echo -e "Status: ${Gr}Running${Nc}" || echo -e "Status: ${Rd}Stopped${Nc}"
    echo "Path: $RF"
    ck && echo -e "\nROOTFS: ${Gr}Installed${Nc}" || echo -e "\nROOTFS: ${Rd}Not installed${Nc}"
    echo -e "\nMount points:"
    for m in proc sys dev tmp run; do
        mountpoint -q "$RF/$m" 2>/dev/null && echo -e "  /$m: ${Gr}Mounted${Nc}" || echo -e "  /$m: ${Rd}Not mounted${Nc}"
    done
    echo "========================================"
}

#=======================================
# Architecture Detection (Fixed: Unknown arch error)
#=======================================
arch() {
    local a=$(uname -m 2>/dev/null); [ -z "$a" ] && a=$(getprop ro.product.cpu.abi 2>/dev/null)
    case "$a" in
        aarch64|arm64-v8a) echo "aarch64" ;;
        armv7*|armeabi-v7a) echo "armv7" ;;
        arm*|armeabi) echo "armhf" ;;
        x86_64|amd64) echo "x86_64" ;;
        x86|i686) echo "x86" ;;
        *) err "Unknown arch: $a"; return 1 ;;
    esac
}

#=======================================
# Mirror Sources
#=======================================
murl() {
    case "$1" in
        tuna) echo "https://mirrors.tuna.tsinghua.edu.cn/alpine/latest-stable" ;;
        ustc) echo "https://mirrors.ustc.edu.cn/alpine/latest-stable" ;;
        *) echo "https://dl-cdn.alpinelinux.org/alpine/latest-stable" ;;
    esac
}

# Default mirror for download (can be overridden by 3rd arg)
default_mirror() {
    echo "official"
}

#=======================================
# rootfs Download/Install (Fixed: Remove hardcoded version, must detect)
#=======================================
alpine_download() {
    local a="$1" v="$2" m="${3:-$(default_mirror)}"
    [ -z "$a" ] || [ "$a" = "auto" ] && { a=$(arch) || return 1; inf "Arch: $a"; }
    case "$a" in aarch64|armv7|armhf|x86_64|x86) ;; *) err "Unsupported: $a"; return 1 ;; esac
    local u="$(murl $m)/releases"; inf "Mirror: $m"
    if [ -z "$v" ]; then
        inf "Detecting version..."
        # Try direct file existence check for known major versions (more reliable than dir listing)
        for major in 3.24 3.23 3.22 3.21 3.20; do
            for mirror_base in "https://dl-cdn.alpinelinux.org/alpine/v${major}/releases/${a}/" \
                               "https://mirrors.ustc.edu.cn/alpine/v${major}/releases/${a}/" \
                               "https://mirrors.tuna.tsinghua.edu.cn/alpine/v${major}/releases/${a}/"; do
                test_url="${mirror_base}alpine-minirootfs-${major}.0-${a}.tar.gz"
                if curl -sL -I "$test_url" 2>/dev/null | grep -q "200 OK"; then
                    # Found major version, now detect exact patch version
                    v=$(curl -sL "${mirror_base}" 2>/dev/null | grep -o "alpine-minirootfs-${major}\.[0-9]\+-${a}\.tar\.gz" | tail -1 | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+")
                    [ -n "$v" ] && break 2
                fi
            done
        done
        # Fallback: try latest-stable directory listing (may not work on all mirrors)
        if [ -z "$v" ]; then
            for mirror_url in "${u}/${a}/" \
                "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${a}/" \
                "https://mirrors.ustc.edu.cn/alpine/latest-stable/releases/${a}/"; do
                v=$(curl -sL "$mirror_url" 2>/dev/null | grep -o 'alpine-minirootfs-[0-9.]\+-'${a}'.tar.gz' | tail -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
                [ -n "$v" ] && break
            done
        fi
        if [ -z "$v" ]; then
            err "Cannot detect latest version, please specify manually"
            inf "Usage: alpine download $a <version> $m"
            return 1
        fi
        inf "Version: $v"
    fi
    local f="alpine-minirootfs-${v}-${a}.tar.gz" d="/sdcard/Download"
    mkdir -p "$d" 2>/dev/null || { d="/data/local/tmp"; mkdir -p "$d" 2>/dev/null; }
    local p="${d}/${f}"
    # Check existing file integrity (prevent HTML error page from failed download)
    if [ -f "$p" ]; then
        local sz
        sz=$(wc -c < "$p" 2>/dev/null)
        if [ -z "$sz" ] || [ "$sz" -lt 1048576 ]; then
            wrn "File may be corrupted (${sz:-0} bytes), re-downloading..."
            rm -f "$p"
        else
            inf "File exists"
        fi
    fi
    # Download (only if file doesn't exist)
    if [ ! -f "$p" ]; then
        inf "Downloading: ${u}/${a}/${f}"
        if ! wget -O "$p" "${u}/${a}/${f}" 2>&1; then
            rm -f "$p" 2>/dev/null
            # Download failed, try official source fallback
            local fallback="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${a}/${f}"
            inf "Mirror download failed, trying official: ${fallback}"
            curl -L -o "$p" "$fallback" 2>&1 || { rm -f "$p"; return 1; }
        fi
        # Verify downloaded file integrity
        sz=$(wc -c < "$p" 2>/dev/null)
        if [ -z "$sz" ] || [ "$sz" -lt 1048576 ]; then
            err "Downloaded file may be corrupted (${sz:-0} bytes)"
            rm -f "$p"
            return 1
        fi
    fi
    alpine_install "$p" && alpine_set_mirror "$m"
}

alpine_install() {
    local f="$1"
    [ -z "$f" ] && { err "Usage: alpine install <file>"; return 1; }
    [ ! -f "$f" ] && { err "File not found: $f"; return 1; }
    inf "Installing to: $RF"
    [ -d "$RF" ] && [ "$(ls -A $RF 2>/dev/null)" ] && { wrn "Backing up old rootfs..."; mv "$RF" "$RF.bak"; }
    mkdir -p "$RF"; inf "Extracting..."
    case "$f" in
        *.tar.gz|*.tgz) tar -xzf "$f" -C "$RF" ;;
        *.tar.xz) tar -xJf "$f" -C "$RF" ;;
        *.tar.bz2) tar -xjf "$f" -C "$RF" ;;
        *) err "Unsupported format"; rm -rf "$RF"; return 1 ;;
    esac || { err "Extract failed"; rm -rf "$RF"; return 1; }
    [ ! -d "$RF/bin" ] && { err "Structure error"; rm -rf "$RF"; return 1; }
    mkdir -p "$RF/etc/apk" "$RF/root" "$RF/tmp" "$RF/var/run"
    chmod 1777 "$RF/tmp"
    chmod 700 "$RF/root"
    alpine_set_mirror tuna
    inf "Install complete, run: alpine start"
}

#=======================================
# Mirror Setting
#=======================================
alpine_set_mirror() {
    [ ! -d "$RF" ] && { err "rootfs not installed"; return 1; }
    local u=$(murl "$1"); mkdir -p "$RF/etc/apk"
    echo -e "${u}/main\n${u}/community" > "$RF/etc/apk/repositories"
    inf "Mirror: $1"
}

#=======================================
# Package Manager Mirror Config
#=======================================
setup_npm_mirror() {
    if ! alpine_exec "command -v npm >/dev/null 2>&1"; then
        inf "Installing npm..."
        alpine_exec "apk add npm" 2>/dev/null || return
    fi
    inf "Configuring npm domestic mirror..."
    alpine_exec "npm config set registry https://registry.npmmirror.com" 2>/dev/null
    inf "npm mirror: npmmirror.com"
}

setup_pip_mirror() {
    alpine_exec "command -v pip3 >/dev/null 2>&1" && {
        inf "Configuring pip domestic mirror..."
        alpine_exec "mkdir -p /root && cat > /root/pip.conf << 'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple" 2>/dev/null
        inf "pip mirror: pypi.tuna.tsinghua.edu.cn"
        return
    }
    # pip doesn't exist, install py3-pip then configure mirror
    inf "Installing pip..."
    alpine_exec "apk add py3-pip" 2>/dev/null || return
    inf "Configuring pip domestic mirror..."
    alpine_exec "mkdir -p /root && cat > /root/pip.conf << 'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple" 2>/dev/null
    inf "pip mirror: pypi.tuna.tsinghua.edu.cn"
}

#=======================================
# OpenClaw Environment Config
#=======================================
setup_openclaw() {
    alpine_exec "command -v openclaw >/dev/null 2>&1" || return
    inf "Configuring OpenClaw environment..."
    # Install bash (OpenClaw exec depends on it)
    alpine_exec "command -v bash >/dev/null 2>&1 || apk add bash" 2>/dev/null
    # Set SHELL environment variable
    alpine_exec "grep -q 'SHELL=' /etc/profile 2>/dev/null || echo 'export SHELL=/bin/bash' >> /etc/profile" 2>/dev/null
    alpine_exec "grep -q 'SHELL=' /root/.bashrc 2>/dev/null || echo 'export SHELL=/bin/bash' >> /root/.bashrc" 2>/dev/null
    # Configure exec permissions (merge with existing config, don't overwrite)
    alpine_exec "mkdir -p /root/.openclaw"
    local cfg="$RF/root/.openclaw/openclaw.json"
    if [ -f "$cfg" ]; then
        # Config exists, add exec permission
        if grep -q '"exec"' "$cfg" 2>/dev/null; then
            # exec config exists, change security to allow
            sed -i 's/"security"[[:space:]]*:[[:space:]]*"[^"]*"/"security": "full"/' "$cfg" 2>/dev/null
        else
            # No exec config, add to tools block
            sed -i 's/"tools"[[:space:]]*:[[:space:]]*{/"tools": {"exec": {"security": "full"},/' "$cfg" 2>/dev/null
        fi
    else
        # No config file, create default
        cat > "$cfg" << 'CONF'
{
  "tools": {
    "exec": {
      "security": "full"
    }
  }
}
CONF
    fi
    inf "OpenClaw environment configured"
}

#=======================================
# Package Installation
#=======================================
alpine_install_packages() {
    run || { wrn "Starting..."; alpine_start || return 1; }
    local p; case "$1" in
        ""|basic) p="bash coreutils vim curl wget" ;;
        dev) p="bash vim curl git python3 nodejs gcc" ;;
        net) p="bash vim curl openssh openssl" ;;
        tools) p="bash vim curl htop tree rsync" ;;
        all) p="bash vim curl git python3 nodejs gcc openssh htop tree rsync" ;;
        *) p="$1" ;;
    esac
    inf "Installing: $p"
    alpine_exec "apk add $p" || { err "Install failed"; return 1; }
    case "$1" in
        dev|net|all|*python*) setup_pip_mirror ;;
        dev|all|*node*) setup_npm_mirror ;;
        *openclaw*) setup_openclaw ;;
    esac
    inf "Done"
}

#=======================================
# Preset Apps
#=======================================
preset() {
    case "$1" in
        openclaw) echo "openclaw gateway --port 18789" ;;
        hermes) echo "/root/.hermes/hermes-agent/venv/bin/hermes gateway" ;;
        sshd) echo "/usr/sbin/sshd" ;;
        nginx) echo "nginx" ;;
        redis) echo "redis-server" ;;
        mysql) echo "mysqld" ;;
        postgres) echo "postgres" ;;
        *) echo "$1" ;;
    esac
}

#=======================================
# Service Management (Fixed: Command injection, subshell issues, service stop)
#=======================================
alpine_service() {
    local cmd="$1" name="$2" arg="$3"
    mkdir -p "$SVC"
    # Fix: Service name validation, prevent command injection
    case "$name" in
        *[!a-zA-Z0-9_-]*) err "Service name only allows letters, numbers, underscore, hyphen"; return 1 ;;
    esac
    case "$cmd" in
        add)
            [ -z "$name" ] && { err "Usage: alpine service add <name> [command]"; return 1; }
            local c="${arg:-$(preset $name)}"
            [ "$c" = "openclaw gateway" ] && c="openclaw gateway --port 18789"
            cat > "$SVC/$name.service" << EOF
[Unit]
Description=$name

[Service]
ExecStart=$c
EOF
            touch "$SVC/$name.enabled"
            inf "Added: $name ($c)"
            ;;
        list)
            echo "Service list:"
            ls "$SVC"/*.service 2>/dev/null | while read f; do
                [ -f "$f" ] || continue
                local n=$(basename "$f" .service)
                [ -f "$SVC/$n.enabled" ] && echo "  $n *" || echo "  $n"
            done
            ;;
        start)
            [ -f "$SVC/$name.service" ] || { err "Service not found: $name"; return 1; }
            run || alpine_start
            # Auto-configure OpenClaw env before start
            [ "$name" = "openclaw" ] && setup_openclaw
            local c=$(grep "^ExecStart=" "$SVC/$name.service" | cut -d= -f2-)
            inf "Starting: $name"
            # Record service PID
            alpine_exec "nohup $c > /var/log/$name.log 2>&1 & echo \$! > /var/run/$name.pid"
            ;;
        stop)
            inf "Stopping: $name"
            # Fix: Use PID file for precise stop
            alpine_exec "if [ -f /var/run/$name.pid ]; then kill \$(cat /var/run/$name.pid) 2>/dev/null; rm -f /var/run/$name.pid; else pkill -f '$name'; fi" 2>/dev/null
            ;;
        restart) alpine_service stop "$name"; sleep 1; alpine_service start "$name" ;;
        status) alpine_exec "pgrep -f '$name'" >/dev/null 2>&1 && echo -e "$name: ${Gr}Running${Nc}" || echo -e "$name: ${Rd}Stopped${Nc}" ;;
        enable) [ -f "$SVC/$name.service" ] && { touch "$SVC/$name.enabled"; inf "Enabled: $name"; } ;;
        disable) rm -f "$SVC/$name.enabled"; inf "Disabled: $name" ;;
        logs) alpine_exec "tail -50 /var/log/$name.log" ;;
        rm) rm -f "$SVC/$name.service" "$SVC/$name.enabled"; inf "Removed: $name" ;;
        *) echo "Usage: alpine service <add|list|start|stop|restart|status|enable|disable|logs|rm>"; echo "Presets: openclaw, sshd, nginx, redis, mysql, postgres" ;;
    esac
}

#=======================================
# 启动已启用服务（修复：避免管道子shell）
#=======================================
#=======================================
# Start Enabled Services (Fixed: Avoid pipe subshell)
#=======================================
alpine_service_start_all() {
    [ ! -d "$SVC" ] && return
    # Fix: Use for loop instead of pipe
    for f in "$SVC"/*.enabled; do
        [ -f "$f" ] || continue
        alpine_service start "$(basename "$f" .enabled)" 2>/dev/null
    done
}

#=======================================
# Shell (Fixed: Use common env vars)
#=======================================
alpine_shell() {
    run || { wrn "Starting..."; alpine_start || return 1; }
    local s="/bin/sh"; [ -x "$RF/bin/bash" ] && s="/bin/bash"
    inf "Entering shell"
    chroot "$RF" /bin/sh -c "export $CHROOT_ENV; cd /root; exec $s -l"
}

#=======================================
# SSH Config/Management (Keep original logic)
#=======================================
alpine_ssh() {
    run || { err "Not running"; return 1; }
    case "$1" in
        setup|"")
            local p="${2:-22}" pw="${3:-123456}" pr="${4:-yes}"
            run || alpine_start
            inf "Installing OpenSSH..."; alpine_exec "apk update && apk add openssh openssh-server" || return 1
            alpine_exec "ssh-keygen -A" 2>/dev/null
            cat > "$RF/etc/ssh/sshd_config" << EOF
Port $p
PermitRootLogin $pr
PasswordAuthentication yes
PubkeyAuthentication yes
UseDNS no
EOF
            echo "root:$pw" | chroot "$RF" /usr/sbin/chpasswd 2>/dev/null
            alpine_exec "/usr/sbin/sshd" 2>/dev/null
            echo "========================================"; echo " SSH Configured"; echo "========================================"
            echo "Port: $p"; echo "User: root"; echo "Password: $pw"; echo "========================================"
            ;;
        start) alpine_exec "/usr/sbin/sshd" && inf "Started" ;;
        stop) alpine_exec "pkill sshd" && inf "Stopped" ;;
        restart) alpine_exec "pkill sshd; sleep 1; /usr/sbin/sshd" && inf "Restarted" ;;
        status) alpine_exec "pgrep sshd" >/dev/null 2>&1 && echo -e "SSH: ${Gr}Running${Nc}" || echo -e "SSH: ${Rd}Stopped${Nc}" ;;
    esac
}

# Legacy function compatibility
alpine_setup_ssh() { alpine_ssh setup "$@"; }
alpine_ssh_manage() { alpine_ssh "$@"; }

#=======================================
# GitHub Download Acceleration (Multi-source Fallback)
#=======================================
# Gitee Config (User can override via env vars)
GITEE_USER="${GITEE_USER:-}"
GITEE_TOKEN="${GITEE_TOKEN:-}"

gh_download_repo() {
    local owner="$1" repo="$2" dest="$3"

    inf "Downloading ${owner}/${repo} ..."

    # Ensure git is installed
    alpine_exec "command -v git >/dev/null 2>&1 || apk add git" 2>/dev/null

    # 1. User configured Gitee, try clone from user repo
    if [ -n "$GITEE_USER" ]; then
        local user_gitee_url="https://gitee.com/${GITEE_USER}/${repo}.git"
        inf "Trying Gitee user mirror (${GITEE_USER}) ..."
        if alpine_exec "git clone --depth 1 '${user_gitee_url}' '${dest}'" 2>/dev/null; then
            inf "Gitee user mirror download success"
            return 0
        fi
        alpine_exec "rm -rf '${dest}'" 2>/dev/null
    fi

    # 2. Ask to configure Gitee (only if not configured)
    if [ -z "$GITEE_USER" ] || [ -z "$GITEE_TOKEN" ]; then
        echo ""
        echo "GitHub download may be slow, configure Gitee to accelerate"
        printf "Configure Gitee? [Y/n] "
        local answer
        read -r answer 2>/dev/null || answer=""
        case "$answer" in
            n|N|no|NO) ;;
            *)
                printf "Enter Gitee username: "
                read -r GITEE_USER 2>/dev/null
                printf "Enter Gitee personal token: "
                read -r GITEE_TOKEN 2>/dev/null
                if [ -z "$GITEE_USER" ] || [ -z "$GITEE_TOKEN" ]; then
                    wrn "Empty input, skipping Gitee config"
                else
                    inf "Gitee config: $GITEE_USER"
                fi
                ;;
        esac
    fi

    # 3. Gitee configured, auto-create mirror repo and sync
    if [ -n "$GITEE_USER" ] && [ -n "$GITEE_TOKEN" ]; then
        inf "Trying to create Gitee mirror ..."
        # Create Gitee repo (with import_url to auto-import from GitHub)
        local create_result
        create_result=$(curl -s -X POST "https://gitee.com/api/v5/user/repos" \
            -d "access_token=${GITEE_TOKEN}" \
            -d "name=${repo}" \
            -d "private=true" \
            -d "auto_init=false" \
            -d "import_url=https://github.com/${owner}/${repo}.git" 2>/dev/null)
        if echo "$create_result" | grep -q '"id"'; then
            inf "Importing from GitHub to Gitee, waiting for sync..."
            local i=0
            while [ $i -lt 24 ]; do
                sleep 5
                inf "Waiting for sync... ($((i*5))s)"
                local user_gitee_url="https://gitee.com/${GITEE_USER}/${repo}.git"
                if alpine_exec "git clone --depth 1 '${user_gitee_url}' '${dest}'" 2>/dev/null; then
                    inf "Gitee mirror download success"
                    return 0
                fi
                alpine_exec "rm -rf '${dest}'" 2>/dev/null
                i=$((i+1))
            done
            wrn "Gitee import timeout, falling back to GitHub"
        else
            wrn "Gitee repo creation failed, falling back to GitHub"
        fi
    fi

    # 4. GitHub codeload download zip
    inf "Trying GitHub codeload ..."
    alpine_exec "mkdir -p /tmp/gh-dl" 2>/dev/null
    local gh_url="https://codeload.github.com/${owner}/${repo}/zip/refs/heads/main"
    if alpine_exec "wget -q -O /tmp/gh-dl/repo.zip '${gh_url}' 2>/dev/null || curl -sL -o /tmp/gh-dl/repo.zip '${gh_url}'"; then
        if alpine_exec "mkdir -p '${dest}' && cd /tmp/gh-dl && unzip -q -o repo.zip -d extracted 2>/dev/null && cp -r extracted/*/* '${dest}'/ 2>/dev/null || cp -r extracted/* '${dest}'/ 2>/dev/null"; then
            alpine_exec "rm -rf /tmp/gh-dl"
            inf "GitHub download success"
            return 0
        fi
    fi
    alpine_exec "rm -rf /tmp/gh-dl" 2>/dev/null

    # 5. Final fallback: git clone
    inf "Trying git clone ..."
    alpine_exec "git clone --depth 1 https://github.com/${owner}/${repo}.git '${dest}'" || { alpine_exec "rm -rf '${dest}'" 2>/dev/null; err "Download failed, check network"; return 1; }
}

#=======================================
# Hermes Agent One-Click Install
#=======================================
alpine_install_hermes() {
    run || { wrn "Starting..."; alpine_start || return 1; }
    inf "========================================"
    inf " Hermes Agent One-Click Install"
    inf "========================================"

    # 1. Install system dependencies
    inf "Installing system deps..."
    alpine_exec "apk update && apk add python3 py3-pip python3-dev gcc g++ musl-dev libffi-dev olm-dev py3-olm make cmake samurai pkgconf git nodejs npm ripgrep" || { err "System deps install failed"; return 1; }

    # 2. Configure package manager domestic mirrors
    setup_npm_mirror
    setup_pip_mirror

    # 3. Download Hermes Agent source
    inf "Downloading Hermes Agent source..."
    if alpine_exec "[ -d /root/.hermes/hermes-agent ]"; then
        inf "Existing install, updating..."
        alpine_exec "cd /root/.hermes/hermes-agent && git pull --ff-only 2>/dev/null || true"
    else
        gh_download_repo "NousResearch" "hermes-agent" "/root/.hermes/hermes-agent" || { err "Download failed, check network"; return 1; }
    fi

    # 4. Create virtual environment
    inf "Creating Python venv..."
    alpine_exec "cd /root/.hermes/hermes-agent && python3 -m venv venv --system-site-packages" || { err "Venv creation failed"; return 1; }

    # 5. Install Python deps
    inf "Installing Python deps (may take a few minutes)..."
    alpine_exec "cd /root/.hermes/hermes-agent && ./venv/bin/pip install --upgrade pip setuptools wheel"
    alpine_exec "cd /root/.hermes/hermes-agent && ./venv/bin/pip install -e '.[all]'" || {
        wrn "Full install failed, trying basic..."
        alpine_exec "cd /root/.hermes/hermes-agent && ./venv/bin/pip install -e '.'" || { err "Deps install failed"; return 1; }
    }

    # 6. Install Node.js deps (browser tools, optional)
    inf "Installing Node.js deps..."
    alpine_exec "cd /root/.hermes/hermes-agent && npm install" 2>/dev/null || {
        wrn "Node.js native module build failed, trying skip scripts..."
        alpine_exec "cd /root/.hermes/hermes-agent && npm install --ignore-scripts" 2>/dev/null || wrn "Node.js deps failed (core functionality unaffected)"
    }

    # 7. Configure PATH and command link
    # 7. Configure PATH and command link
        inf "Configuring command..."
        alpine_exec "ln -sf /root/.hermes/hermes-agent/venv/bin/hermes /usr/local/bin/hermes" 2>/dev/null
        alpine_exec "touch /root/.bashrc && grep -q '.hermes' /root/.bashrc || echo 'export PATH=/root/.hermes/hermes-agent/venv/bin:\\$PATH' >> /root/.bashrc"

        # 8. Initialize config directory
        inf "Initializing config..."
        alpine_exec "mkdir -p /root/.hermes/{cron,sessions,logs,pairing,hooks,image_cache,audio_cache,memories,skills}"
        alpine_exec "[ -f /root/.hermes/.env ] || touch /root/.hermes/.env"
        alpine_exec "[ -f /root/.hermes/config.yaml ] || touch /root/.hermes/config.yaml"

        inf "========================================"
        inf " Hermes Agent Install Complete!"
        inf "========================================"
        inf "Usage:"
        inf "  hermes setup    - Configure API keys"
        inf "  hermes          - Start chat"
        inf "  hermes gateway  - Start gateway service"
        inf ""
        inf "Config files:"
        inf "  /root/.hermes/.env        - API keys"
        inf "  /root/.hermes/config.yaml - Config file"
        inf "========================================"
    }

    #=======================================
    # Module Update
    #=======================================
    alpine_update() {
        local z="${1:-/sdcard/Download/alpine-linux.zip}"
        [ ! -f "$z" ] && { err "File not found: $z"; return 1; }
        local t="/data/local/tmp/alpine-update"; rm -rf "$t"; mkdir -p "$t"
        inf "Extracting..."; unzip -o "$z" -d "$t" >/dev/null 2>&1 || { rm -rf "$t"; return 1; }
        [ -f "$t/common.sh" ] || { err "Invalid format"; rm -rf "$t"; return 1; }
        inf "Updating..."
        cp -f "$t/"*.sh "$t/module.prop" /data/adb/modules/alpine_linux/ 2>/dev/null
        cp -f "$t/system/bin/"* /data/adb/modules/alpine_linux/system/bin/ 2>/dev/null
        chmod +x /data/adb/modules/alpine_linux/*.sh /data/adb/modules/alpine_linux/system/bin/*
        rm -rf "$t"; inf "Done, please reboot"
    }

    # Legacy function compatibility
    alpine_update_auto() { alpine_update; }
    alpine_update_local() { alpine_update "$1"; }
