---
title: "Step 1: PX4 Autopilot SITL Setup"
aliases: [PX4 Autopilot SITL Setup, PX4 SITL Setup, PX4 Setup, Step 1 PX4]
tags: [simulation, px4, sitl, linux, setup, robotics, ubuntu, arch]
created: 2026-09-30
updated: 2026-10-16
status: stable
---

# Step 1: PX4 Autopilot SITL Setup

[[00 - Day One Zero-to-Hero Quickstart|← Previous: Step 0 - Day One Quickstart]] | [[Robotics Simulation Pipeline|Pipeline MOC]] | [[02 - Gazebo Harmonic Setup|Next: Step 2 - Gazebo Harmonic Setup →]]

---

## 📌 Overview

**PX4 Autopilot SITL (Software In The Loop)** executes the complete C++ PX4 flight control firmware natively on your Linux host machine without requiring physical flight controller hardware. It calculates EKF2 state estimation, executes native flight modes (Takeoff, Hold, Mission, Offboard), and communicates directly with Gazebo Harmonic for physics simulation and sensor data via `gz-transport`.

> [!info] Legacy ArduPilot Note
> The previous ArduPilot SITL setup documentation has been archived in [[Old Stack - ArduPilot/README|Old Stack - ArduPilot/01 - ArduPilot SITL Setup]].

---

## 📦 Distribution-Specific Prerequisites Installation

Before cloning and building PX4 SITL, install the essential system compilers, CMake, Ninja, and Python build tools for your Linux distribution:

### 🐧 Option A: On Ubuntu 22.04 LTS (Jammy) / 24.04 LTS (Noble)

```bash
# 1. Update package lists
sudo apt update

# 2. Install base compilers, CMake, Ninja, and Python dev packages
sudo apt install -y git build-essential cmake ninja-build ccache \
    python3-dev python3-pip python3-venv \
    libxml2-dev libxslt1-dev

# Note: PX4 provides an automated Ubuntu setup script if desired:
# cd ~/PX4-Autopilot && bash ./Tools/setup/ubuntu.sh --no-nuttx --no-sim-tools
```

### 🏹 Option B: On Arch Linux / Manjaro

```bash
# 1. Install base build toolchain, CMake, Ninja, and ccache via pacman
sudo pacman -S --needed git base-devel cmake ninja ccache python python-pip

# 2. Ensure ccache is enabled in your PATH (optional, accelerates rebuilds)
export PATH="/usr/lib/ccache/bin:$PATH"
```

---

## 📥 1. Clone PX4 Autopilot Repository

Clone the official PX4 Autopilot repository with all necessary submodules recursively:

```bash
# Navigate to your user home directory
cd ~

# Clone PX4-Autopilot repository with all submodules
git clone --recursive https://github.com/PX4/PX4-Autopilot.git
cd PX4-Autopilot
```

> [!tip] Symlink in `installed gigs/`
> A symlink is maintained in the project workspace at `installed gigs/PX4-Autopilot` pointing directly to `~/PX4-Autopilot`.

---

## 🐍 2. Configure Python Virtual Environment (`~/venv-px4`)

PX4 SITL code generation, Kconfig definition parsers, and uORB message generators require specific Python libraries:

```bash
# 1. Create a clean Python 3 virtual environment
python3 -m venv ~/venv-px4

# 2. Activate the virtual environment
source ~/venv-px4/bin/activate

# 3. Upgrade pip and install required build dependencies
pip install --upgrade pip
pip install kconfiglib jinja2 empy==3.3.4 jsonschema pyros-genmsg pyyaml
```

> [!important] EmPy Version Warning
> PX4 v1.17 code generators specifically require `empy==3.3.4`. Do not install `empy>=4.0` as the API changed and will cause build failures during ROS/uORB header generation.

---

## 🔨 3. Build & Run PX4 SITL with Gazebo Harmonic

Compile and execute the SITL target for the standard `x500` quadcopter airframe:

```bash
cd ~/PX4-Autopilot
source ~/venv-px4/bin/activate

# Build target for Gazebo Harmonic with x500 quadcopter
make px4_sitl gz_x500
```

PX4 will automatically compile its modules, generate internal uORB topics, and initialize the Gazebo Harmonic client.

---

## ✅ 4. Preflight Health Verification Check

When the simulation finishes building and initializes, PX4 drops into the interactive console (`pxh>`):

```text
pxh> commander check
INFO  [commander] Preflight check: OK
```

### Basic Command Test:
You can test autonomous climb and touchdown directly from the PX4 shell:
```text
pxh> commander takeoff
# Vehicle arms and ascends to default 2.5m altitude

pxh> commander land
# Vehicle executes smooth descent and disarms on ground contact
```

---

## ⏭️ Next Step

Proceed to [[02 - Gazebo Harmonic Setup|Step 2: Gazebo Sim (Harmonic) Setup & Physics Stabilization]].
