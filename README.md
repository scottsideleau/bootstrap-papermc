# papermc-bootstrap

A lightweight, POSIX-friendly bootstrapper for quickly deploying a mostly-vanilla Minecraft server using [PaperMC](https://papermc.io/) and [Velocity](https://velocitypowered.com/), complete with essential plugin support and universal client compatibility — including offline/non-Microsoft Java accounts and Bedrock Edition clients via Geyser.

---

## Features

- Script-driven install of the latest PaperMC and Velocity builds
- Automatic plugin support:
  - [GeyserMC](https://geysermc.org/) and [Floodgate](https://geysermc.org/projects/floodgate/)
  - [ViaVersion](https://viaversion.com/)
- POSIX-compliant `sh` scripts (no bashisms)
- Minimal external dependencies
- Offline-mode and non-Microsoft account support
- Tested on macOS and Linux

---

## Directory Structure

```
papermc-bootstrap/
├── get-papermc.sh                  # Downloads the latest PaperMC build
├── clean.sh                        # Removes local cache files
├── update.sh                       # Updates all components
├── plugins/
│   ├── get-viaversion.sh           # Downloads ViaVersion plugin
│   └── update.sh                   # Updates all plugins in this directory
├── velocity/
│   ├── get-velocity.sh             # Downloads the latest Velocity build
│   ├── update.sh                   # Updates Velocity and its plugins
│   └── plugins/
│       ├── get-geyser.sh           # Downloads GeyserMC plugin
│       └── update.sh               # Updates all plugins in this directory
```

---

## Usage

```sh
# Download or update everything at once
./bootstrap.sh

# Clean all caches and remove all *.jar files
./clean.sh
```

Configuration files such as `server.properties`, `velocity.toml`, and plugin configs will need to be created or customized to match your desired setup.

---

## Offline Mode Notice

This bootstrap supports offline-mode operation (`online-mode=false` for PaperMC and `player-info-forwarding-mode=LEGACY` in Velocity), enabling non-Microsoft Java accounts to connect. Be aware:

- Player identity is not authenticated by Mojang/Microsoft
- Additional protections (whitelist, authentication plugins) are recommended for public servers

---

## Contributions

Pull requests and feedback are welcome. Suggestions for improvements, additional plugin support, or extended configuration options are encouraged.

