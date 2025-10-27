# Podman Deployment Template - Changelog

## Version 3.0.0 - 2025-10-12

### Major Feature: Multi-Environment Support

This release adds comprehensive support for running development and production environments simultaneously on the same server with automatic port management and secure access controls.

---

### 🚀 New Features

#### Multi-Environment Configuration

- **Separate config files**: `podman.config.dev` and `podman.config.prod` for environment-specific settings
- **Environment-aware naming**: Containers automatically named `{project}-{environment}` (e.g., `myapp-dev`, `myapp-prod`)
- **Subdomain routing**: Dev at `dev.example.com`, Prod at `example.com`
- **Auto-detection**: `setup.sh` automatically detects environment from config files

#### Port Registry System (`bin/podman-port-registry`)

- **Automated port allocation**: No more manual port management or conflicts
- **Port tracking**: JSON-based registry at `~/.local/share/podman-ports/registry.json`
- **Collision avoidance**: Validates ports across all projects and environments
- **Commands**:
  - `reserve <project> <env> [port]` - Reserve specific or auto-allocate port
  - `release <project> <env>` - Release reserved port
  - `list [project]` - View all port allocations
  - `check <port>` - Check if port is available
  - `find-next` - Find next available port in range (8000-9000)

#### Tailscale Security for Dev

- **IP whitelisting**: Dev environments restricted to Tailscale VPN (100.64.0.0/10) and localhost (127.0.0.1/8)
- **Traefik middleware**: Automatic IP whitelist middleware generation for dev containers
- **Template**: `traefik-middleware.yaml.template` for Traefik dynamic configuration
- **Configurable**: `DEV_IP_WHITELIST` variable for custom IP ranges

#### Environment-Specific Resources

- **Separate networks**: Each environment gets isolated network (`{project}-{env}-network`)
- **Resource limits**: Different CPU/memory limits per environment
- **Branch targeting**: Dev typically tracks `develop`, Prod tracks `main`

---

### 🔧 Template Updates

#### setup.sh

- Added `-e, --environment` parameter for explicit environment selection
- Integrated port registry for automatic port allocation
- Auto-detects environment from config filename
- Passes `ENVIRONMENT`, `CONTAINER_NAME`, `FULL_DOMAIN` to all templates
- Generates Traefik middleware for dev environments
- Updated configuration summary with environment details

#### compose.yaml.template

- Uses `{{CONTAINER_NAME}}` instead of `{{PROJECT_NAME}}`
- Environment-aware Traefik routing with `{{FULL_DOMAIN}}`
- Automatic middleware application for dev environments
- Container image named with environment suffix

#### Script Templates

- `podman-dev.sh.template`: Updated to use `{{CONTAINER_NAME}}`
- `podman-prod.sh.template`: Updated to use `{{CONTAINER_NAME}}`
- Both display `{{FULL_DOMAIN}}` in success messages

#### Systemd Service Templates

- Filename pattern: `{{PROJECT_NAME}}-{{ENVIRONMENT}}.service`
- Service descriptions include environment (e.g., "My Project Container (dev)")
- All container references use `{{CONTAINER_NAME}}`

---

### 📝 New Configuration Files

**podman.config.dev.example / podman.config.prod.example**
- Minimal configs (~20 lines) - just the essentials
- Specify only what differs between environments
- Leverage setup.sh defaults for everything else
- Development: Lower resources (256M RAM, 0.5 CPU), `develop` branch, `READONLY_ROOTFS=false`
- Production: Higher resources (512M RAM, 1.0 CPU), `main` branch, `READONLY_ROOTFS=true`

---

### 📚 New Documentation

#### MULTI-ENVIRONMENT.md

Comprehensive guide covering:

- Quick start for multi-environment setup
- Port registry usage and commands
- Tailscale VPN configuration
- Container naming conventions
- Network isolation
- Domain and DNS configuration
- Deployment workflows
- Managing multiple projects
- Resource management
- Troubleshooting
- Best practices

#### Updated README.md

- Added features section highlighting multi-environment support
- Updated quick start for both single and multi-environment setups
- New "Multi-Environment Setup" section with examples
- Port registry command examples
- Links to MULTI-ENVIRONMENT.md

---

### 🔐 Security Enhancements

1. **Dev environment isolation**: Development sites not accessible from public internet
2. **Tailscale VPN integration**: Secure remote access to dev environments
3. **IP whitelisting**: Traefik middleware enforces access controls
4. **Network separation**: Each environment has isolated network
5. **Environment-specific security**: Different security profiles for dev vs prod

---

### 🛠️ Breaking Changes

**Configuration Files:**

- Recommended to use environment-specific configs (`podman.config.{env}`)
- `PORT_HOST` now optional (leave empty for auto-allocation)
- Legacy single config (`podman.config`) still supported but deprecated

**Container Naming:**

- Containers now named `{project}-{environment}` instead of just `{project}`
- Systemd services follow same pattern: `{project}-{environment}.service`

**Migration Path:**

1. Copy existing `podman.config` to `podman.config.prod`
2. Create `podman.config.dev` for development
3. Re-run `setup.sh` with `--environment` flag
4. Update any scripts referencing old container names

---

### 🎯 Use Cases

**Perfect for:**

- Running dev and prod on same server
- Testing features before production deploy
- Multiple projects on shared infrastructure
- Teams needing secure dev access via VPN
- Avoiding port conflict nightmares

**Example Scenario:**

```bash
# Project: myapp
# Containers: myapp-dev (port 8080), myapp-prod (port 8081)
# Domains: dev.myapp.com, myapp.com
# Access: dev via Tailscale only, prod public

# Project: blog  
# Containers: blog-dev (port 8082), blog-prod (port 8083)
# Domains: dev.blog.com, blog.com
# Access: dev via Tailscale only, prod public

# All ports auto-managed, no conflicts!
```

---

### 🧪 Testing

```bash
# Test dev environment
cp podman.config.dev.example podman.config.dev
# Edit with your settings
./setup.sh --environment dev
bash scripts/podman-dev.sh

# Test prod environment
cp podman.config.prod.example podman.config.prod
# Edit with your settings
./setup.sh --environment prod
bash scripts/podman-prod.sh

# Verify both running
podman ps | grep myproject
# Should show: myproject-dev and myproject-prod

# Check port allocations
bin/podman-port-registry list
```

---

### 📊 Compatibility

**Requires:**

- Bash 4.0+
- jq (for port registry JSON parsing)
- Podman 4.0+
- Traefik 2.0+ (for IP whitelisting)
- Tailscale (for secure dev access)

**Tested on:**

- Ubuntu 22.04 LTS, 24.04 LTS
- Linux Mint 22
- Debian 12

---

### 🙏 Credits

This release implements comprehensive multi-environment support with automated port management and Tailscale-secured development access based on real-world deployment needs.

---

## Version 2.0.0 - 2025-10-11

### Major Improvements

This release includes comprehensive fixes for Podman deployment issues, enhanced Linux distribution support, and improved developer experience.

---

### 🔧 Core Template Changes

#### compose.yaml.template

- **Removed obsolete version field** - Modern Docker Compose no longer requires version specification
- **Commented out proxy-network for development** - External network now optional, preventing startup failures in dev environments
- **Disabled read-only filesystem for development** - Read-only mode and tmpfs mounts now commented out by default to prevent nginx permission errors
- **Note**: Production deployments can re-enable security features by uncommenting these sections

#### Containerfile.template

- **Fully qualified image names** - Changed from `node:20-alpine` to `docker.io/library/node:20-alpine` to prevent Podman registry resolution errors
- **Smart package-lock.json handling** - Build now works with or without package-lock.json, using `npm ci` when available, falling back to `npm install`
- **Modern npm flags** - Updated from deprecated `--only=production` to `--omit=dev`
- **Simplified nginx user configuration** - Use existing `nginx` user (UID 101) instead of creating custom user to avoid GID conflicts

---

### 🐧 Linux Distribution Support

#### install-podman.sh

- **Linux Mint support** - Added detection and proper Ubuntu version mapping for derivatives
- **Pop!_OS support** - Handles Ubuntu-based distributions automatically
- **Ubuntu codename mapping** - Maps jammy, focal, noble to correct version numbers
- **Kubic repository availability check** - Validates repository exists before adding (prevents 404 errors on Ubuntu 24.04)
- **Multi-method podman-compose installation**:
  - Tries apt first (system package)
  - Falls back to pipx (recommended for PEP 668 compliance)
  - Falls back to pip3 --user (user installation)
  - Provides clear instructions if all methods fail
- **Skip reinstallation option** - Users with existing Podman can skip reinstall and just configure/install compose
- **Improved error handling** - Better messages and graceful fallbacks throughout

---

### 🚀 Developer Experience

#### podman-dev.sh.template

- **docker-compose with Podman socket** - Automatically configures DOCKER_HOST and enables podman.socket for docker-compose users
- **Socket health checking** - Validates socket availability and enables it if needed
- **Fixed template formatting** - Corrected podman format strings from `{{{{.Names}}}}` to `{{.Names}}`
- **Better error messages** - Clearer output when tools are missing or sockets unavailable

#### setup.sh

- **Automatic static-site starter files** - When PROJECT_TYPE=static-site, automatically copies starter files:
  - package.json with build scripts
  - src/index.html with responsive design
  - src/style.css with modern styling
  - src/script.js with basic functionality

---

### 📦 New Static Site Starter Files

Created professional starter template for static sites:

#### templates/static-site-starter/package.json.template

- Build script using simple file copy
- Dev server with http-server
- Clean command for build artifacts
- Placeholder replacement support

#### templates/static-site-starter/src/index.html.template

- Modern, responsive HTML5 structure
- Semantic markup
- Mobile-friendly viewport settings
- Professional welcome page

#### templates/static-site-starter/src/style.css.template

- Beautiful gradient background
- Responsive design with media queries
- Modern CSS with flexbox
- Professional color scheme and typography
- Card-based layout

#### templates/static-site-starter/src/script.js.template

- Dynamic copyright year
- Extensible structure for adding features
- Console logging for debugging

---

### 📝 Configuration Updates

#### .gitignore

- Added Node.js dependencies: `node_modules/`, `package-lock.json`
- Added build outputs: `dist/`, `build/`
- Added log files: `*.log`, `npm-debug.log*`, etc.

#### project-types/static-site.conf

- Updated CONTAINER_USER from `nginx-rootless` to `nginx`
- Added comment explaining nginx user is pre-existing in alpine image

---

### 🛡️ Security Considerations

**Development Mode (Default)**:

- Read-only filesystem: **Disabled** (prevents nginx temp file errors)
- tmpfs mounts: **Commented out**
- External proxy network: **Disabled**

**Production Mode (Recommended)**:
Users should uncomment in `compose.yaml`:

```yaml
read_only: true
tmpfs:
  - /tmp:rw,noexec,nosuid,size=64m
  - /var/cache/nginx:rw,noexec,nosuid,size=32m
  - /var/run:rw,noexec,nosuid,size=16m
networks:
  - proxy-network  # Ensure network exists first
```

---

### 🐛 Bugs Fixed

1. ✅ **Docker Compose socket issue** - docker-compose now properly configured to use Podman socket
2. ✅ **Linux Mint detection failure** - Distribution detection now handles Ubuntu derivatives
3. ✅ **Kubic repository 404 errors** - Added availability check before adding repository
4. ✅ **External network startup failures** - Proxy network now optional for development
5. ✅ **Read-only filesystem nginx errors** - Disabled by default, can be enabled for production
6. ✅ **Short image name resolution errors** - Using fully qualified image names
7. ✅ **Missing package.json errors** - Starter files now created automatically
8. ✅ **npm ci failures** - Smart handling of missing package-lock.json
9. ✅ **GID 101 conflicts** - Using existing nginx user instead of creating custom user
10. ✅ **Python PEP 668 errors** - Multiple installation methods for podman-compose
11. ✅ **Template formatting errors** - Fixed podman format string syntax

---

### 📚 Documentation

- Added comprehensive CHANGELOG.md (this file)
- Added README.md for static-site-starter templates
- Existing documentation (QUICKSTART.md, SETUP.md, etc.) remains current

---

### 🧪 Testing

After implementing these changes, test with:

```bash
# 1. Clean up any existing containers
podman stop <container-name> 2>/dev/null || true
podman rm <container-name> 2>/dev/null || true

# 2. Set up a new static-site project
cp podman.config.example podman.config
# Edit podman.config with your settings
bash setup.sh

# 3. Run the development environment
bash scripts/podman-dev.sh

# 4. Verify the site is accessible
curl http://localhost:8081/
curl http://localhost:8081/health
```

---

### 🔄 Migration Guide

**For existing deployments:**

1. **Update templates**: Pull latest template changes
2. **Review compose.yaml**: Consider keeping read-only disabled for dev
3. **Update Containerfile**: Use new fully qualified image names
4. **Update scripts**: Get latest install-podman.sh and podman-dev.sh
5. **Test locally**: Verify with `podman build` and `podman-compose up`
6. **Production**: Re-enable security features (read-only, tmpfs) in compose.yaml

**For new projects:**

Simply run `bash setup.sh` with updated templates - all improvements are included automatically.

---

### 📊 Compatibility

**Tested on:**

- Linux Mint 22 (Ubuntu 24.04 base)
- Ubuntu 22.04 LTS, 24.04 LTS
- Podman 4.9.3+
- docker-compose 2.x
- podman-compose 1.x

**Python Compatibility:**

- pip3 --user (PEP 668 compliant)
- pipx (recommended)
- System packages (apt)

---

### 🎯 Breaking Changes

**None.** All changes are backward compatible. Existing configurations continue to work, with improvements available on regeneration.

---

### 👥 Contributors

Changes implemented based on comprehensive testing and issue resolution across multiple Linux distributions.

---

### 📅 Release Date

October 11, 2025

---

## Previous Versions

### Version 1.0.0 - Initial Release

- Basic Podman deployment templates
- Static site, Node.js backend, Python backend support
- Rootless container configuration
- Nginx reverse proxy setup
- CI/CD templates
- Systemd service templates
