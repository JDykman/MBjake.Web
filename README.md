# Podman Deployment Template

Production-ready template for deploying containerized applications with Podman. Rootless, secure, automated.

## Features

- **Multi-environment support**: Run dev and prod simultaneously on one server
- **Automated port management**: Port registry prevents conflicts
- **Secure dev access**: Restrict dev to Tailscale VPN + localhost
- **Rootless containers**: Enhanced security with user namespaces
- **Zero-downtime deploys**: Health checks and rolling updates
- **Resource isolation**: Per-environment CPU and memory limits

## Quick Start

### 1. Configure Both Environments

```bash
# Copy example configs
cp podman.config.dev.example podman.config.dev
cp podman.config.prod.example podman.config.prod

# Edit with your project details
nano podman.config.dev
nano podman.config.prod
```

Required settings in each:

```bash
PROJECT_NAME=myproject           # MUST be same in both configs
ENVIRONMENT=dev                  # dev or prod
PROJECT_DISPLAY_NAME="My Project"
PROJECT_TYPE=static-site
DOMAIN=example.com
BUILD_COMMAND="npm run build"
BUILD_OUTPUT=dist
PORT_HOST=                       # Leave empty for auto-allocation
```

### 2. Run Setup (Once)

```bash
# One-time bootstrap - generates BOTH environments
./setup.sh
```

This single command:
- Generates dev files: `compose-dev.yaml`, `scripts/podman-dev.sh`, etc.
- Generates prod files: `compose-prod.yaml`, `scripts/podman-prod.sh`, etc.
- Allocates ports for both via registry
- Cleans up all template files
- Removes itself

**Note**: Setup script is designed to run ONCE. It cleans up and removes itself after generating your project files.

### 3. Deploy Both Environments

**Development:**

```bash
bash scripts/install-podman.sh    # First time only
bash scripts/podman-dev.sh
```

**Production:**

```bash
bash scripts/podman-prod.sh
```

Both containers run simultaneously with different ports and domains!

## Multiple Sites on One Server

Each site is completely isolated. Just ensure each has:

1. **Unique `PROJECT_NAME`** - Creates unique containers, services, networks
2. **Unique `PORT_HOST`** - Avoids port conflicts (or use reverse proxy)
3. **Shared `proxy-network`** - Create once for all sites:

```bash
podman network create proxy-network
```

**Example - Three sites:**

```bash
# Site 1
PROJECT_NAME=site1
PORT_HOST=8081
DOMAIN=site1.com

# Site 2
PROJECT_NAME=site2
PORT_HOST=8082
DOMAIN=site2.com

# Site 3
PROJECT_NAME=site3
PORT_HOST=8083
DOMAIN=site3.com
```

Each site gets its own:

- Container: `site1`, `site2`, `site3`
- Systemd service: `site1.service`, `site2.service`, `site3.service`
- Network: `site1-network`, `site2-network`, `site3-network`
- Deploy dir: `/home/user/projects/site1`, `/home/user/projects/site2`, etc.

## Multi-Environment Setup (Dev + Prod)

Run development and production environments simultaneously on the same server. Development is secured to Tailscale VPN access only.

**Setup workflow:**

```bash
# 1. Create both configs
cp podman.config.dev.example podman.config.dev
cp podman.config.prod.example podman.config.prod

# 2. Edit with your project details  
nano podman.config.dev podman.config.prod

# 3. Run setup ONCE - generates both environments
./setup.sh

# 4. Deploy both
bash scripts/podman-dev.sh
bash scripts/podman-prod.sh
```

**Result:**
- Dev: `myproject-dev` container at `dev.example.com` (Tailscale + localhost only)
- Prod: `myproject-prod` container at `example.com` (public access)
- No port conflicts (automatic allocation)
- Both coexist happily!

**Port management:**

```bash
# List all reserved ports
bin/podman-port-registry list

# Release a port
bin/podman-port-registry release myproject dev

# Check port availability
bin/podman-port-registry check 8080
```

**See [MULTI-ENVIRONMENT.md](MULTI-ENVIRONMENT.md) for complete guide including:**
- Tailscale VPN configuration
- Port registry usage
- Domain and DNS setup
- Security and access control
- Troubleshooting

## Configuration

Config files are minimal - only specify what's essential and what differs between environments.

See `podman.config.{dev,prod}.example` for templates, and project-types/*.conf for type-specific defaults.

**Common settings:**

- `PROJECT_NAME` - Lowercase project identifier
- `PROJECT_TYPE` - static-site | node-backend | python-backend
- `DOMAIN` - Primary domain
- `BUILD_COMMAND` - Build command
- `BUILD_OUTPUT` - Build output directory
- `PORT_HOST` - Host port
- `MEMORY_LIMIT` - Memory limit (512M, 1G, etc.)
- `DEPLOY_DIR` - Server deployment path
- `GIT_BRANCH` - Git branch to deploy

## Commands

**Development:**

```bash
podman logs -f myproject          # View logs
podman restart myproject          # Restart
bash scripts/podman-dev.sh        # Rebuild
```

**Production:**

```bash
systemctl --user status myproject     # Status
systemctl --user restart myproject    # Restart
journalctl --user -u myproject -f     # Logs
```

## Auto-Start (Systemd)

```bash
mkdir -p ~/.config/systemd/user/
cp scripts/myproject-user.service ~/.config/systemd/user/
loginctl enable-linger $USER
systemctl --user enable myproject
systemctl --user start myproject
```

## CI/CD (GitHub Actions)

Add repository secrets:

- `DEPLOY_SSH_KEY` - SSH private key
- `DEPLOY_HOST` - Server hostname
- `DEPLOY_USER` - SSH username

## Troubleshooting

```bash
# Missing config
cp podman.config.prod.example podman.config

# Port conflict
podman ps | grep 8080
podman stop <container-name>

# Rebuild from scratch
podman rm -f myproject
podman rmi -f myproject:latest
bash scripts/podman-dev.sh

# View logs
podman logs myproject
```

## Requirements

- Podman (via `scripts/install-podman.sh`)
- Git
- Bash
- Linux (production)