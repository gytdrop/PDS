---
title: "Step 2: Gazebo Harmonic Setup"
aliases: [Gazebo Harmonic Setup, Gazebo Sim, Gazebo Harmonic]
tags: [simulation, gazebo, gz-harmonic, robotics, setup]
created: 2026-09-30
status: stable
---

# Step 2: Install Gazebo Sim (Harmonic)

[[01 - ArduPilot SITL Setup|← Previous: Step 1 - ArduPilot SITL Setup]] | [[Robotics Simulation Pipeline|Pipeline MOC]] | [[03 - ardupilot_gazebo Plugin|Next: Step 3 - ardupilot_gazebo Plugin →]]

---

## 📌 Overview

**Gazebo Harmonic** (`gz-harmonic`, release 8) is the modern LTS generation of the Open Source Robotics Foundation (OSRF) Gazebo simulation suite. It provides:
- High-fidelity multi-body rigid physics (DART engine)
- Sensor rendering pipelines (cameras, LiDAR, IMU, GPS, magnetometers)
- Distributed GUI and simulation server architectures via `gz-transport`

---

## 📦 Distribution-Specific Installation

### On Ubuntu 22.04 LTS (Jammy) / 24.04 LTS (Noble)

Ubuntu requires the official OSRF APT repositories and development packages for plugin compilation:

```bash
# 1. Install prerequisites for repository management
sudo apt update && sudo apt install -y curl lsb-release gnupg

# 2. Add the official OSRF repository signing key
sudo curl https://packages.osrfoundation.org/gazebo.gpg \
    --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg

# 3. Add the OSRF APT source list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null

# 4. Update repository lists
sudo apt update

# 5. Install Gazebo Harmonic and plugin development dependencies
sudo apt install -y gz-harmonic libgz-sim8-dev rapidjson-dev \
    libopencv-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl
```

### On Arch Linux / Manjaro

On Arch Linux, base libraries are installed via `pacman`, and `gz-harmonic` is built via AUR:

```bash
# 1. Install development tools and multimedia libraries
sudo pacman -S --needed base-devel cmake git rapidjson opencv gstreamer gst-plugins-base gst-plugins-bad

# 2. Install Gazebo Harmonic from the Arch User Repository (AUR)
# Using yay:
yay -S gz-harmonic

# Or using paru:
# paru -S gz-harmonic
```

---

## ✅ Verification: Run Standalone Gazebo

Verify that Gazebo's rendering engine and graphical interface start without errors:

```bash
gz sim -v4 shapes.sdf
```

> [!tip] Expected Behavior
> A Gazebo 3D viewport window will appear rendering basic 3D shapes (box, sphere, cylinder).
> - Once the 3D shapes render cleanly, close the window.
> - If you receive an OpenGL or Wayland rendering issue, run:
>   ```bash
>   export GZ_PARTITION=sitl
>   export QT_QPA_PLATFORM=xcb  # Forces X11 fallback on Wayland
>   ```

---

## ⏭️ Next Step

Proceed to [[03 - ardupilot_gazebo Plugin|Step 3: Build the ardupilot_gazebo Plugin]].
