---
title: Quick Reference & Launch Script
aliases: [Launch Script, Simulation Cheat Sheet, Fast Reference]
tags: [simulation, script, bash, cheat-sheet, automation, px4, ros2, teleop]
created: 2026-09-30
updated: 2026-10-16
status: stable
---

# Simulation Pipeline: Quick Reference & Launch Automation

[[09 - Modular Drone & Parts Library Setup|← Previous: Step 9 - Modular Drone & Parts Library Setup]] | [[Robotics Simulation Pipeline|Pipeline MOC]] | [[Installed Gigs & Simulation Tooling|Next: Installed Gigs & Tooling →]]

---

## ⚡ Fast Command Cheat Sheet

### 0. Automated Setup & System Doctor (`setup_modular_drone.sh`)

```bash
# Complete turnkey install (installs OS packages, fetches QGC/PX4, links models, configures shell):
./setup_modular_drone.sh --all

# Auto-configure symlinks, airframe, and shell profiles (if tools already installed):
./setup_modular_drone.sh --fix

# Standalone 3D Gazebo model preview (inspect frame, motors, and LiDAR):
./setup_modular_drone.sh --preview

# Verify and launch full flight simulation stack directly:
./setup_modular_drone.sh --launch

# Non-destructive 56-point system health audit:
./setup_modular_drone.sh

# View help and all available CLI flags:
./setup_modular_drone.sh --help
```

#### CLI Flags for `setup_modular_drone.sh`:
| Flag | Description |
| :--- | :--- |
| **`-h, --help`** | Show usage syntax, options list, and command examples |
| **`-p, --preview`** | Open modular drone inside standalone Gazebo Sim 3D GUI (`preview_world.sdf`) |
| **`-l, --launch`** | Run system checks and immediately start multi-pane simulation stack (`start_sim.sh -m modular_drone`) |
| **`-f, --fix`** | Auto-provisions `~/.local/bin/px4-teleop` and `ros2`, links models to PX4, and configures shell |
| **`-a, --all`** | Complete end-to-end setup (runs `--install-deps` + `--fix` together) |
| **`-i, --install-deps`** | Installs system packages via OS package manager (APT on Ubuntu, Pacman/AUR on Arch) |
| **`--validate-only`** | Headless automated verification (exits with code 0 on pass, 1 on fail) |

### 1. Launch Complete Stack (MicroXRCEAgent + PX4 SITL + ROS 2 + QGC)
```bash
cd ~/Documents/PROJECTS/DC-\ Drone\ Club/installed\ gigs
./start_sim.sh
```

### 2. Fly via Keyboard Teleoperation
In Pane 2 (or any terminal):
```bash
px4-teleop
# or explicitly via ros2:
ros2 run px4_ros_com px4_teleop_key.py
```

### 3. Check Simulation Status & Ports
```bash
./start_sim.sh --status
```

### 4. Stop and Clean Up All Processes
```bash
./start_sim.sh --kill
```

---

## 📜 All-in-One Tmux Launch Script (`start_sim.sh`)

The `start_sim.sh` orchestrator creates an optimized multi-pane `tmux` environment running under host networking:

```bash
Usage: ./start_sim.sh [OPTIONS]

Options:
  -h, --help         Show help message and exit
  -s, --headless     Run Gazebo in headless mode (server physics only, no 3D GUI)
  --gui              Run Gazebo with interactive 3D GUI (default)
  -m, --model MODEL  PX4 SITL Gazebo model (default: gz_x500, options: gz_x500, gz_x500_depth, gz_x500_lidar, modular_drone)
  --no-qgc           Do not launch QGroundControl
  --kill, -k         Terminate all running simulation processes, agents, and tmux sessions
  --status           Display status of simulation background processes and network ports
```

### 🖥️ Tmux Pane Architecture
The launcher structures your workspace into 3 dedicated operational areas:
- **Pane 0 (Left 45%)**: `MicroXRCEAgent` bridging uORB topics to ROS 2 over UDP port `8888`.
- **Pane 1 (Top-Right 55%)**: PX4 SITL firmware avionics and Gazebo Harmonic physics simulation (with `PX4_GZ_FOLLOW=1` camera chase mode and North-aligned spawn).
- **Pane 2 (Bottom-Right 55%)**: Interactive ROS 2 autonomy shell with `px4_ros2_ws` sourced, ready for `px4-teleop`.
- **Background**: QGroundControl launches as an independent graphical window without cluttering terminal pipes.

### Tmux Navigation Shortcuts:
- **Switch Panes**: Press `Ctrl + B`, then use arrow keys.
- **Detach Session**: Press `Ctrl + B`, then press `D`.
- **Re-attach**: Run `tmux -S /tmp/tmux-1000/default attach -t drone_sim`.
- **Kill All**: Run `./start_sim.sh --kill`.

---

## 🎮 Interactive Keyboard Flight Controls (`px4-teleop`)

The teleoperation node communicates via native PX4 v1.17 uXRCE-DDS topics, providing a live terminal HUD and responsive velocity control:

| Command / Flight Action | Key(s) | Function |
| :--- | :--- | :--- |
| **Auto-Takeoff** | `T` | Arms drone, commands offboard mode, ascends to 2.5m, and stabilizes |
| **Hover / Brake** | `Space` / `H` | Zeroes body velocities immediately and actively locks target yaw |
| **Land** | `L` | Enters autonomous descent and disarms upon ground touchdown |
| **Flight Mode Toggle** | `M` | Toggles between **`BODY-RELATIVE`** (nose-aligned) and `WORLD-RELATIVE` (compass North) |
| **Pitch (Forward / Back)** | `W` / `S` | Drives forward along the drone's nose direction / reverses backward |
| **Roll (Strafe Left / Right)** | `A` / `D` | Strafes sideways left / right relative to vehicle orientation |
| **Altitude (Climb / Descend)**| `Up` / `R` / `I` & `Down` / `F` / `K` | Vertical climb ($-Z$ NED) / Descent ($+Z$ NED) |
| **Yaw (Turn Left / Right)** | `Left` / `Q` & `Right` / `E` | Rotates yaw heading counter-clockwise / clockwise (actively holds angle when released) |
| **Arm / Disarm** | `O` (Arm) / `P` (Disarm) | Manual motor arming and emergency kill switch |
| **Speed Scale Presets** | `1` / `2` / `3` | Preset speeds: `1` = 0.5 m/s, `2` = 1.5 m/s, `3` = 3.0 m/s |
| **Exit** | `Ctrl + C` / `ESC` | Exits teleoperation safely |

---

## 🛠️ Diagnostics & Port Mapping

| Port / Interface | Target | Purpose | Health Check |
| :--- | :--- | :--- | :--- |
| **`UDP 8888`** | `MicroXRCEAgent` | uORB to ROS 2 bridge | Verify with `ss -ulnp \| grep 8888` |
| **`UDP 14550`** | `QGroundControl` | MAVLink telemetry | Check QGC connected indicator |
| **`/fmu/out/vehicle_local_position_v1`** | ROS 2 | State feedback ($x, y, z, v_x, v_y, v_z$) | Verify with `ros2 topic echo ... --once` |
| **`/fmu/out/vehicle_status_v1`** | ROS 2 | Arming state & nav mode | Check arming state via `pxh> listener vehicle_status` |

---

## 🔗 Related Notes
- [[Robotics Simulation Pipeline|Simulation Pipeline MOC]]
- [[06 - Smoke Test & Flight Verification]]
- [[07 - Sample Drone Flight]]
- [[08 - Performance & Troubleshooting Guide]]
- [[09 - Modular Drone & Parts Library Setup]]
- [[PX4 ROS2 Migration Ledger]]
- [[Installed Gigs & Simulation Tooling|Installed Tools & Binaries Reference]] ([`../../installed gigs/`](../../installed%20gigs/))
