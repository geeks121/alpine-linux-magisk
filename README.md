# Alpine Linux - Magisk Module

Run Alpine Linux via chroot on Android devices with this Magisk module.

**Version: v1.3.4**

---

## Features

- ✅ Auto-download rootfs, auto-detect architecture
- ✅ Service management, unified `service` command
- ✅ Pre-configured common apps, one-click service add
- ✅ Auto-start on boot
- ✅ One-click SSH configuration
- ✅ Storage mounting (internal storage, external SD card)
- ✅ Multiple mirror sources (TUNA, USTC, Official)

---

## Requirements

| Item | Requirement |
|------|-------------|
| Android | 5.0+ |
| Magisk | v20.4+ |
| Permission | root |
| Space | ~100MB |

---

## Installation

### Method 1: Direct Install (Recommended)

1. Package `alpine-linux` directory as zip
2. Magisk Manager → Modules → Install from local storage
3. Reboot device

### Method 2: Manual Copy

```bash
# On device
cp -r alpine-linux/* /data/adb/modules/alpine_linux/
chmod +x /data/adb/modules/alpine_linux/*.sh
chmod +x /data/adb/modules/alpine_linux/system/bin/alpine
reboot
```

---

## Quick Start

```bash
# Download and install rootfs
alpine download

# Start Alpine Linux
alpine start

# Enter shell
alpine shell

# Check status
alpine status
```

---

## Complete Command Reference

### Container Management

| Command | Description |
|---------|-------------|
| `alpine start` | Start Alpine |
| `alpine stop` | Stop Alpine |
| `alpine restart` | Restart Alpine |
| `alpine status` | Check status |
| `alpine shell` | Enter shell |
| `alpine exec <cmd>` | Execute command |

### Rootfs Management

| Command | Description |
|---------|-------------|
| `alpine download` | Auto-download install (auto-detect arch) |
| `alpine download aarch64` | Download for specific arch |
| `alpine download aarch64 3.19.0` | Specify arch and version |
| `alpine download aarch64 3.19.0 tuna` | Specify mirror source |
| `alpine install <file>` | Install from local tar.gz |
| `alpine mirror tuna` | Set mirror source |

**Mirror Options:**

| Name | Address |
|------|---------|
| `tuna` | Tsinghua University (default, recommended for China) |
| `ustc` | University of Science and Technology of China |
| `official` | Official source |

### Service Management

| Command | Description |
|---------|-------------|
| `alpine service add <name>` | Add preset service |
| `alpine service add <name> "cmd"` | Add custom service |
| `alpine service list` | List services |
| `alpine service start <name>` | Start service |
| `alpine service stop <name>` | Stop service |
| `alpine service restart <name>` | Restart service |
| `alpine service status <name>` | Check service status |
| `alpine service enable <name>` | Enable auto-start on boot |
| `alpine service disable <name>` | Disable auto-start |
| `alpine service logs <name>` | View logs |
| `alpine service rm <name>` | Remove service |

**Preset Apps:**

Adding a preset app auto-configures the startup command — no manual specification needed:

| Preset | Description | Auto-start Command | Must Install First |
|--------|-------------|-------------------|-------------------|
| `openclaw` | OpenClaw Gateway | `openclaw gateway --port 18789` | `npm i -g openclaw` |
| `hermes` | Hermes Agent Gateway | `hermes gateway` | `alpine install-hermes` |
| `sshd` | SSH Service | `/usr/sbin/sshd` | `alpine ssh` auto-installs |
| `nginx` | Web Server | `nginx` | `apk add nginx` |
| `redis` | In-memory DB | `redis-server` | `apk add redis` |
| `mysql` | Relational DB | `mysqld` | `apk add mysql` |
| `postgres` | Relational DB | `postgres` | `apk add postgresql` |

> ⚠️ **Note**: Preset apps only configure startup commands — you must install the corresponding packages first.

**Usage Example:**

```bash
# Using nginx as example
alpine shell
# In shell, install nginx
apk add nginx
exit

# Add preset service (auto-configures startup command)
alpine service add nginx

# Start service
alpine service start nginx

# Check status
alpine service status nginx
```

**Custom Service:**

If presets don't meet needs, specify custom startup command:

```bash
# Custom startup command
alpine service add myapp "/usr/local/bin/myapp --port 8080"
alpine service start myapp
```

### SSH Configuration

| Command | Description |
|---------|-------------|
| `alpine ssh` | One-click SSH config (port 22, password 123456) |
| `alpine ssh 22 mypassword` | Specify port and password |
| `alpine ssh start` | Start SSH |
| `alpine ssh stop` | Stop SSH |
| `alpine ssh restart` | Restart SSH |
| `alpine ssh status` | Check status |

> ⚠️ **Security**: Default password `123456` is for testing only — change it in production!

### Package Installation

| Command | Description |
|---------|-------------|
| `alpine install-pkg` | Install basic tools |
| `alpine install-pkg dev` | Install dev environment |
| `alpine install-pkg net` | Install network tools |
| `alpine install-pkg tools` | Install common tools |
| `alpine install-pkg all` | Install all packages |
| `alpine install-pkg <pkg>` | Install specific package |

#### Basic Tools

| Package | Description |
|---------|-------------|
| `bash` | Bourne Again Shell |
| `coreutils` | GNU core utilities (ls, cp, mv, cat, etc.) |
| `vim` | Classic text editor |
| `curl` | CLI data transfer tool |
| `wget` | File download tool |

#### Dev Environment

| Package | Description |
|---------|-------------|
| `bash` | Bourne Again Shell |
| `vim` | Text editor |
| `curl` | Data transfer tool |
| `git` | Distributed version control |
| `python3` | Python 3 interpreter |
| `nodejs` | Node.js JavaScript runtime |
| `gcc` | GNU C compiler |

#### Network Tools

| Package | Description |
|---------|-------------|
| `bash` | Bourne Again Shell |
| `vim` | Text editor |
| `curl` | Data transfer tool |
| `openssh` | OpenSSH client & server |
| `openssl` | SSL/TLS crypto toolkit |

#### Common Tools

| Package | Description |
|---------|-------------|
| `bash` | Bourne Again Shell |
| `vim` | Text editor |
| `curl` | Data transfer tool |
| `htop` | Interactive process viewer |
| `tree` | Directory tree display |
| `rsync` | File sync tool |

#### All Packages

Contains all above — 13 total: `bash`, `coreutils`, `vim`, `curl`, `wget`, `git`, `python3`, `nodejs`, `gcc`, `openssh`, `htop`, `tree`, `rsync`

#### Package Manager Mirror Config

When installing `python3` or `nodejs`, domestic mirrors auto-configure:

| Language | Package Manager | Mirror |
|----------|-----------------|--------|
| Python | pip | TUNA pypi.tuna.tsinghua.edu.cn |
| Node.js | npm | npmmirror.com |

> 💡 **Tip**: Python pip needs separate install on Alpine — `install-pkg` handles this.

#### Custom Install

```bash
# Install single package
alpine install-pkg nginx

# Install multiple packages (enter shell)
alpine shell
apk add nginx redis mysql
```

### Other Commands

| Command | Description |
|---------|-------------|
| `alpine log` | View recent logs |
| `alpine module-version` | View module version |
| `alpine module-upgrade <zip>` | Upgrade module |
| `alpine help` | Show help |

### One-Click Hermes Agent Install

```bash
alpine install-hermes
```

One-click install [Hermes Agent](https://github.com/NousResearch/hermes-agent) (Nous Research open-source AI agent), auto-completes:

| Step | Description |
|------|-------------|
| System deps | python3, nodejs, npm, git, gcc, ripgrep, etc. |
| Package mirrors | pip TUNA + npm Taobao |
| Source download | Auto-select fastest method |
| Python venv | Create venv & install deps |
| Node.js deps | Install browser tool deps |
| Command config | Create `hermes` command link |
| Config init | Create `.env`, `config.yaml`, etc. |

#### Download Acceleration

Due to unstable GitHub access in China, install tries in order:

| Priority | Method | Description |
|----------|--------|-------------|
| 1 | Gitee user mirror | Clone from user's Gitee mirror |
| 2 | Gitee auto-create mirror | Interactive input account, auto-create Gitee mirror repo |
| 3 | GitHub tarball | codeload download, small size |
| 4 | `git clone --depth 1` | Shallow clone fallback |

First install prompts if Gitee not configured:

```
Configure Gitee? [Y/n] y
Enter Gitee username: chuanglizhe1
Enter Gitee token: xxxxxxxx
```

> 💡 **Tip**: Generate Gitee token at Gitee → Settings → Personal Tokens, check `projects` permission. After config, module auto-creates private Gitee mirror repo synced from GitHub — future downloads use Gitee domestic lines.

#### After Install

```bash
alpine shell

# Configure API keys
hermes setup

# Start chat
hermes

# Add as service (auto-start)
exit
alpine service add hermes
alpine service start hermes
```

> ⚠️ **Note**: Install requires internet; Python dependency compilation may take several minutes.

---

## Usage Examples

### Example 1: Run Web Server

```bash
# Install nginx
alpine start
alpine shell
# In shell:
apk add nginx
echo "Hello from Alpine!" > /var/www/localhost/htdocs/index.html
nginx

# Or add as service
exit
alpine service add nginx
alpine service start nginx
```

### Example 2: Add Custom Service

```bash
# Add Python HTTP server
alpine service add pyserver "python3 -m http.server 8080 --directory /root/web"
alpine service start pyserver
alpine service status pyserver
```

### Example 3: SSH Remote Access

```bash
# Configure SSH (change default password!)
alpine ssh 2222 my_secure_password

# Connect from PC
ssh root@<phone-IP> -p 2222
```

---

## Directory Structure

### Android Side

| Path | Description |
|------|-------------|
| `/data/alpine_linux/rootfs` | Alpine rootfs |
| `/data/alpine_linux/services` | Service config directory |
| `/data/alpine_linux/alpine.log` | Runtime log |

### Inside Alpine

| Path | Description |
|------|-------------|
| `/mnt/sdcard` | Android internal storage |
| `/mnt/external_sd` | External SD card |
| `/var/log/<service>.log` | Service logs |

---

## FAQ

### Q: "rootfs not found"?

```bash
alpine download
alpine start
```

### Q: "Cannot detect latest version"?

Manually specify version:
```bash
alpine download aarch64 3.19.0
```

### Q: How to fully uninstall?

```bash
# Uninstall module (keep rootfs)
alpine stop
# Remove module in Magisk Manager

# Full cleanup (including rootfs)
rm -rf /data/alpine_linux
```

### Q: How to view logs?

```bash
# Recent logs
alpine log

# Full log file
cat /data/alpine_linux/alpine.log
```

### Q: Service won't start?

Check service logs:
```bash
alpine service logs <service-name>
```

---

## License

MIT License

---

## Project Links

| Platform | URL |
|----------|-----|
| GitHub | https://github.com/chuanglizhe/alpine-linux-magisk |
| Gitee | https://gitee.com/chuanglizhe1/alpine-linux-magisk |

---

## Credits

- Alpine Linux: https://alpinelinux.org
- Magisk: https://github.com/topjohnwu/Magisk
