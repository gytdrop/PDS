---
title: "Installed Gigs & Simulation Tooling Reference"
aliases: [Installed Gigs, Tooling Reference, Simulation Tooling, Binaries Reference]
tags: [simulation, tools, binaries, shortcuts, px4, ros2, micro-xrce-dds, qgroundcontrol, gazebo]
created: 2026-10-28
updated: 2026-10-28
status: stable
---

# Installed Gigs & Simulation Tooling Reference 🛠️

[[Welcome|← Vault Index]] | [[Robotics Simulation Pipeline|Simulation Pipeline MOC]] | [[Quick Reference & Launch Script|Launch Script Cheat Sheet →]]

---

## 📌 Overview

This document aggregates shortcuts, symlinks, runtimes, and network mappings for all autonomous flight and simulation software installed on this workstation.

The source files and scripts reside in the project directory at `../../installed gigs/`.

---

## 🔗 Linked Components & Paths

| Name | Target Path | Description | Note Link |
| :--- | :--- | :--- | :--- |
| **`setup_modular_drone.sh`** | `../../setup_modular_drone.sh` | Linux system doctor & automated modular drone setup verifier (Arch & Ubuntu). | [[09 - Modular Drone & Parts Library Setup|Step 9: Modular Parts]] |
| **`start_sim.sh`** | `../../installed gigs/start_sim.sh` | Unified multi-pane simulation orchestrator (`tmux`). | [[Quick Reference & Launch Script|Launch Script Cheat Sheet]] |
| **`PX4-Autopilot`** | `~/PX4-Autopilot` | PX4 Autopilot firmware & native Gazebo Harmonic SITL integration. | [[01 - PX4 Autopilot SITL Setup|Step 1: PX4 SITL Setup]] |
| **`MicroXRCEAgent`** | `~/.local/bin/MicroXRCEAgent` | High-speed DDS middleware bridging PX4 uORB topics directly to ROS 2. | [[03 - Micro XRCE-DDS & ROS 2 Setup|Step 3: Micro XRCE-DDS Middleware]] |
| **`px4_ros2_ws`** | `~/px4_ros2_ws` | ROS 2 autonomy workspace (`px4_msgs`, `px4_ros_com`, offboard controllers). | [[03 - Micro XRCE-DDS & ROS 2 Setup|Step 3: Micro XRCE-DDS Middleware]] |
| **`px4-teleop`** | `~/.local/bin/px4-teleop` | Interactive keyboard teleoperation node with live terminal HUD. | [[07 - Sample Drone Flight|Step 7: Interactive Flight]] |
| **`ros2-shell`** | `~/.local/bin/ros2-shell` | Interactive subshell with pre-sourced ROS 2 Humble and tab-completion. | [[04 - Shell Environment & Launch Automation|Step 4: Shell & Paths]] |
| **`ros2`** | `~/.local/bin/ros2` | ROS 2 CLI wrapper with host networking and `px4_ros2_ws` mounting. | [[03 - Micro XRCE-DDS & ROS 2 Setup|Step 3: Micro XRCE-DDS Middleware]] |
| **`colcon`** | `~/.local/bin/colcon` | ROS 2 build system wrapper for compiling workspace packages. | [[03 - Micro XRCE-DDS & ROS 2 Setup|Step 3: Micro XRCE-DDS Middleware]] |
| **`gz`** | `/usr/bin/gz` | Gazebo Sim CLI (Harmonic 8.15.0) for multi-body physics and sensor simulation. | [[02 - Gazebo Harmonic Setup|Step 2: Gazebo Sim & Physics]] |
| **`QGroundControl.AppImage`** | `~/QGroundControl.AppImage` | Full-featured graphical ground station and flight mission planner. | [[05 - QGroundControl Setup|Step 5: QGroundControl Setup]] |

---

## 🩺 System Doctor & Setup Automation (`setup_modular_drone.sh`)

Located at the repository root, [`setup_modular_drone.sh`](file:///home/gytdrop/Documents/PROJECTS/DC-%20Drone%20Club/setup_modular_drone.sh) audits and repairs all 56 gates of the simulation stack:

```bash
# Display help and CLI options:
../../setup_modular_drone.sh --help

# Standalone 3D Gazebo model preview:
../../setup_modular_drone.sh --preview

# Direct simulation flight launch:
../../setup_modular_drone.sh --launch

# Self-heal missing symlinks, wrappers, and shell profiles:
../../setup_modular_drone.sh --fix

# Turnkey installation for fresh systems (Arch/Ubuntu):
../../setup_modular_drone.sh --all
```

### CLI Flags Reference:
| Flag | Description |
| :--- | :--- |
| **`-h, --help`** | Print usage syntax and command examples |
| **`-p, --preview`** | Spawns `modular_drone` inside standalone Gazebo Sim 3D GUI (`preview_world.sdf`) |
| **`-l, --launch`** | Verifies system readiness and immediately launches the full flight stack |
| **`-f, --fix`** | Auto-provisions `~/.local/bin/px4-teleop`, `~/.local/bin/ros2`, links models, and configures shell |
| **`-a, --all`** | Installs OS packages via package manager + fixes all configurations |
| **`-i, --install-deps`** | Runs distro package manager (`apt` or `pacman`/`yay`) to fetch system packages |
| **`--validate-only`** | Headless automated verification (exits with code 0 on pass, 1 on fail) |

---

## 🎮 Interactive Keyboard Flight Controls (`px4-teleop`)

Fly the simulated drone directly from your keyboard using the native teleoperation node:

```bash
px4-teleop
# or from any terminal:
ros2 run px4_ros_com px4_teleop_key.py
```

### Key Mappings:

| Action | Keys | Description |
| :--- | :--- | :--- |
| **Auto-Takeoff** | `T` | Arms drone, engages offboard mode, climbs to 2.5m, and locks into stable hover |
| **Hover / Brake** | `Space` / `H` | Zeroes all velocity commands and actively locks target yaw/heading |
| **Land** | `L` | Triggers autonomous landing descent and disarms on touchdown |
| **Flight Mode Toggle** | `M` | Toggles between **`BODY-RELATIVE`** (default, drives in nose direction) and `WORLD-RELATIVE` (absolute North/East) |
| **Pitch (Forward / Back)** | `W` / `S` | Drives forward along the drone's nose direction / reverses backward |
| **Roll (Strafe Left / Right)** | `A` / `D` | Strafes sideways left / right relative to vehicle orientation |
| **Altitude (Climb / Descend)**| `Up` / `R` / `I` & `Down` / `F` / `K` | Vertical ascent ($-Z$ NED) / Descent ($+Z$ NED) |
| **Yaw (Turn Left / Right)** | `Left` / `Q` & `Right` / `E` | Rotates heading counter-clockwise / clockwise (actively holds angle when released) |
| **Arm / Disarm** | `O` (Arm) / `P` (Disarm) | Manual motor arm and emergency disarm kill switch |
| **Speed Presets** | `1` (0.5 m/s) / `2` (1.5 m/s) / `3` (3.0 m/s) | Adjusts flight speed scaling dynamically |

---

## 📡 Port Architecture & Dataflow

| Port / Channel | Protocol | Source | Target | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **`8888`** | XRCE / UDP | PX4 SITL (`uxrce_dds_client`) | `MicroXRCEAgent` | High-speed uORB <-> ROS 2 pub/sub bridge |
| **`14550`** | MAVLink / UDP | PX4 SITL | `QGroundControl` | Ground Control Station telemetry & virtual RC |
| **`14540`** | MAVLink / UDP | PX4 SITL | Optional Companion API | Secondary companion computer telemetry |
| **ROS 2 Topics** | FastDDS | `MicroXRCEAgent` | `px4_ros_com` | Direct control via `/fmu/in/*` and `/fmu/out/*` |

### ROS 2 Interface Topics (PX4 v1.17 uXRCE-DDS)
- **Setpoint Streams (`in`):**
  - `/fmu/in/offboard_control_mode` (`px4_msgs/msg/OffboardControlMode`)
  - `/fmu/in/trajectory_setpoint` (`px4_msgs/msg/TrajectorySetpoint`)
  - `/fmu/in/vehicle_command` (`px4_msgs/msg/VehicleCommand`)
- **Telemetry Feeds (`out`):**
  - `/fmu/out/vehicle_local_position_v1` (`px4_msgs/msg/VehicleLocalPosition`)
  - `/fmu/out/vehicle_status_v1` (`px4_msgs/msg/VehicleStatus`)
  - `/fmu/out/vehicle_global_position` (`px4_msgs/msg/VehicleGlobalPosition`)
  - `/fmu/out/vehicle_odometry` (`px4_msgs/msg/VehicleOdometry`)

---

## ⚡ Quick Launch Commands

### 🩺 System Doctor & Modular Verification (Arch & Ubuntu)
```bash
# Run system doctor, inspect Gazebo, PX4, models, and Obsidian docs:
../../setup_modular_drone.sh

# Automatically fix paths, symlinks, and shell exports:
../../setup_modular_drone.sh --fix

# Open standalone 3D Gazebo preview of the modular drone:
../../setup_modular_drone.sh --preview
```

### 🚀 Recommended: Automated Multi-Pane Launcher
```bash
# Standard simulation (MicroXRCEAgent + PX4 SITL in Gazebo Harmonic + ROS 2 + QGC):
../../installed\ gigs/start_sim.sh

# Headless mode (runs Gazebo physics server without 3D GUI, ideal for low CPU usage):
../../installed\ gigs/start_sim.sh --headless

# Select specific airframe (options: gz_x500, modular_drone):
../../installed\ gigs/start_sim.sh -m modular_drone

# Check simulation process status & ports:
../../installed\ gigs/start_sim.sh --status

# Stop all simulation processes and clean up ports:
../../installed\ gigs/start_sim.sh --kill
```

---

## 🛠️ Diagnostics & Troubleshooting

| Issue | Root Cause | Solution |
| :--- | :--- | :--- |
| **Drone rejects arming (`Preflight Fail: Attitude failure (roll)`)** | Airframe spawned flipped or experienced collision explosion on ground. Model `gz_x500_depth` has an OakD-Lite bounding box that collides with `base_link` in Bullet Featherstone. | Use model `gz_x500` or `modular_drone`. Run `commander check` in PX4 console to verify `Preflight check: OK`. |
| **`px4-teleop` keys do not respond** | Terminal not in raw input mode or focus outside terminal. | Click inside the terminal running `px4-teleop`. Press `T` to takeoff, or check if ROS 2 topics are receiving setpoints. |
| **`No Micro-XRCE agent running`** | Agent not started or port 8888 blocked. | Run `start_sim.sh --status` to check UDP port 8888. Start agent manually with `MicroXRCEAgent udp4 -p 8888`. |
| **High CPU or lagging simulation** | Gazebo 3D rendering overhead on integrated GPU. | Run with `./start_sim.sh --headless` for full physics rate without GUI overhead. |

---

## 🔗 Related Notes
- [[Welcome|Vault Index]]
- [[Robotics Simulation Pipeline]]
- [[08 - Performance & Troubleshooting Guide]]
- [[09 - Modular Drone & Parts Library Setup]]
- [[PX4 ROS2 Migration Ledger]]
