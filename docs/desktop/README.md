# Desktop Security Setup

This directory contains security configurations and scripts specific to desktop environments.

## Structure
- Place all desktop-specific scripts in this directory.
- Use the `gnome/` subdirectory for scripts and settings specific to GNOME desktop environments.
- Shared scripts (used by both desktop and server) should go in the `common/` directory at the project root.

## Example Desktop Features
- Desktop firewall configuration
- User session hardening
- GNOME security settings (see `gnome/`)
- USB device control

## Adding New Scripts
- Place new desktop scripts here and document their purpose and usage in this README or a separate markdown file.
- If a script is only for GNOME, place it in the `gnome/` subdirectory.

## Usage
Refer to the main project README for general usage. For desktop-specific scripts, run them from this directory as needed.

## GNOME Security Settings

The `gnome/` directory contains scripts for configuring GNOME-specific security settings.
