---
title: "Step 1: ArduPilot SITL Setup"
aliases: [ArduPilot SITL Setup, ArduPilot SITL, SITL Setup]
tags: [simulation, ardupilot, sitl, linux, setup]
created: 2026-09-30
status: stable
---

# Step 1: Install ArduPilot SITL (Software In The Loop)

[[README|← Back to Old Stack Archive]] | [[Robotics Simulation Pipeline|Pipeline MOC]] | [[02 - Gazebo Harmonic Setup (ArduPilot)|Next: Step 2 - Gazebo Harmonic Setup →]]

---

## 📌 Overview

**ArduPilot SITL** allows you to execute the real ArduPilot C++ autopilot firmware on your Linux host machine without physical flight controller hardware. It emulates sensors (accelerometers, gyros, compass, barometers, GPS) and generates motor actuation signals over network sockets.

---

## 📥 1. Clone ArduPilot Repository

ArduPilot relies on multiple git submodules (MAVLink, libcanard, waf, etc.). Ensure you clone recursively:

```bash
# Navigate to home directory
cd ~

# Clone ArduPilot repository with all required submodules
git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git

# Enter the repository
cd ardupilot
```

> [!warning] Submodule Incompleteness
> If you cloned without `--recurse-submodules`, initialize them manually:
> ```bash
> git submodule update --init --recursive
> ```

---

## 📦 2. Install Build Prerequisites

ArduPilot provides automated installation scripts for standard Linux distributions. Run the script corresponding to your operating system:

### On Ubuntu / Debian:
```bash
cd ~/ardupilot
./Tools/environment_install/install-prereqs-ubuntu.sh -y
```

### On Arch Linux / Manjaro:
```bash
cd ~/ardupilot
./Tools/environment_install/install-prereqs-arch.sh -y
```

> [!note] What the install script does
> - Installs native compilers (`gcc`, `g++`, `ccache`)
> - Configures Python 3 virtual environment / pip packages (`pymavlink`, `MAVProxy`, `future`, `pexpect`, `empy`)
> - Installs cross-compilation toolchains if needed
> - Appends `export PATH=$PATH:$HOME/ardupilot/Tools/autotest` and JSBSim paths to your shell profile.

---

## 🔄 3. Reload Shell Environment

After the prerequisite script completes, reload your environment variables and shell paths:

```bash
# Reload environment variables
source ~/.profile

# Reload current shell profile (bash or zsh)
source ~/.bashrc   # If using bash
# source ~/.zshrc  # If using zsh
```

---

## ✅ 4. Verification Check

Confirm that the ArduPilot autotest utility scripts are accessible in your `$PATH`:

```bash
which sim_vehicle.py
```

**Expected output:**
```plaintext
/home/<your-user>/ardupilot/Tools/autotest/sim_vehicle.py
```

> [!tip] Troubleshooting PATH issues
> If `sim_vehicle.py` is not found, verify that `~/.bashrc` contains:
> ```bash
> export PATH=$HOME/ardupilot/Tools/autotest:$PATH
> ```
> Run `export PATH=$HOME/ardupilot/Tools/autotest:$PATH` in your current terminal to test immediately.

---

## ⏭️ Next Step

Proceed to [[02 - Gazebo Harmonic Setup (ArduPilot)|Step 2: Install Gazebo Sim (Harmonic)]].
