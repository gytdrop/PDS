---
title: "Step 5: QGroundControl Setup"
aliases: [QGroundControl Setup, QGC Setup, QGroundControl]
tags: [simulation, qgroundcontrol, gcs, telemetry, mavlink]
created: 2026-09-30
status: stable
---

# Step 5: Install QGroundControl (Virtual Telemetry & RC)

[[04 - Shell Environment & Launch Automation|← Previous: Step 4 - Shell Environment & Launch Automation]] | [[Robotics Simulation Pipeline|Pipeline MOC]] | [[06 - Smoke Test & Flight Verification|Next: Step 6 - Smoke Test & Flight Verification →]]

---

## 📌 Overview

**QGroundControl (QGC)** provides graphical ground station control, pilot telemetry, and flight planning for **PX4 Autopilot** UAVs. In simulation, QGC connects automatically over standard MAVLink UDP ports (`14550`), providing:
- Real-time artificial horizon HUD, altitude, heading, airspeed, and GPS telemetry
- Virtual on-screen joystick and gamepad RC transmitter input
- Automated waypoint navigation and survey mission planning
- Live parameter inspection, calibration, and tuning

---

## 🔒 1. User Permissions (`dialout`)

To communicate with USB radio telemetry hardware, serial devices, and virtual PTY serial ports without root permissions, add your user account to the `dialout` group:

```bash
sudo usermod -a -G dialout $USER
```

> [!important] Group Membership Activation
> Group changes require a logout/login cycle or running `newgrp dialout` in your active terminal to take effect immediately.

---

## 🚫 2. Disable ModemManager Interference

Linux distributions often run `ModemManager`, a background daemon that scans and locks serial devices (assuming they are cellular GSM/LTE modems). When ModemManager intercepts serial telemetry devices or flight controller ports, it corrupts MAVLink streams.

### On Ubuntu / Debian:
```bash
sudo apt-get remove -y modemmanager
```

### On Arch Linux / Manjaro:
```bash
sudo systemctl stop ModemManager.service
sudo systemctl disable ModemManager.service
```

---

## 📥 3. Download & Make Executable

Download the stable AppImage of QGroundControl:

```bash
# Navigate to home directory
cd ~

# Download official QGroundControl AppImage from GitHub Releases
wget -O ~/QGroundControl.AppImage https://github.com/mavlink/qgroundcontrol/releases/download/v5.1.4/QGroundControl-x86_64.AppImage

# Grant execute permissions
chmod +x ~/QGroundControl.AppImage
```

> [!tip] Desktop Launcher (Optional)
> You can launch QGroundControl directly from terminal anytime with:
> ```bash
> ~/QGroundControl.AppImage
> ```
> Or move it to `/usr/local/bin/qgroundcontrol` for universal `$PATH` availability.

---

## ⏭️ Next Step

Proceed to [[06 - Smoke Test & Flight Verification|Step 6: Smoke Test (Verifying the Bridge)]].
