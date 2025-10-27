# Podman Deployment Template - Utilities

This directory contains utility scripts for managing Podman deployments.

## Port Registry Tool

`podman-port-registry` - Manages port allocations across multiple projects and environments to prevent conflicts.

### Installation

The port registry is included with the template and requires `jq` for JSON parsing:

```bash
# Install jq if not already installed
sudo apt-get install jq    # Ubuntu/Debian
sudo yum install jq        # RHEL/CentOS
sudo dnf install jq        # Fedora
```

### Usage

See `podman-port-registry --help` for full documentation or refer to [MULTI-ENVIRONMENT.md](../MULTI-ENVIRONMENT.md) for detailed usage examples.

### Quick Reference

```bash
# Reserve port automatically
bin/podman-port-registry reserve myproject dev

# Reserve specific port
bin/podman-port-registry reserve myproject prod 8080

# List all ports
bin/podman-port-registry list

# Release port
bin/podman-port-registry release myproject dev

# Check port availability
bin/podman-port-registry check 8080
```

