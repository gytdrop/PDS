---
title: "Drone Club Simulation Implementation Plan"
aliases: [Implementation Plan, Simulation Roadmap]
tags: [simulation, planning, roadmap, px4, ros2, gazebo, modular]
created: 2026-10-28
updated: 2026-10-28
status: completed
---

# 📋 Drone Club Simulation Stack: Implementation Plan & Architecture

[[Welcome|← Vault Index]] | [[Robotics Simulation Pipeline|Simulation Pipeline MOC]] | [[09 - Modular Drone & Parts Library Setup|Step 9: Modular Parts →]]

---

## 🎯 Architecture Milestones

### Milestone 1: Core Flight & Simulation Stack (Completed)
- **PX4 Autopilot (v1.17)**: Native software-in-the-loop (SITL) firmware compiled with Bullet Featherstone physics engine.
- **Gazebo Sim (Harmonic 8.15.0)**: Multi-body rigid physics, enlarged $500\text{m} \times 500\text{m}$ ground plane, camera chase follow mode (`PX4_GZ_FOLLOW=1`).
- **Micro XRCE-DDS Agent**: High-speed UDP middleware bridge (Port `8888`) translating uORB telemetry directly to ROS 2.
- **ROS 2 Autonomy**: Interactive keyboard teleoperation (`px4-teleop`) and scripted trajectory tracking (`offboard_control.py`).

### Milestone 2: Modular Drone Architecture (Completed)
- **`Parts_library/` Structure**:
  - `chassis`: Structural carbon fiber sandwich decks, standoffs, battery bay, and integrated avionics (IMU, Baro, GPS, Mag).
  - `t_motor_f60`: Stator link, midnight-blue bell rotor, tri-blade propeller, and aerodynamic `MulticopterMotorModel` plugin.
  - `livox_mid360`: Heat-dissipating aluminum housing, sapphire optical dome, and 360° $\times$ 59° GPU ray-tracing LiDAR tilted 10° down.
  - `modular_drone`: Top-level assembly integrating sub-models via SDF includes, relative-to frame offsets, and fixed joint bonds.

### Milestone 3: Portable System Tooling & Knowledge Base (Completed)
- **Portable Linux Setup Doctor (`setup_modular_drone.sh`)**: 42-point automated verification, relative symlink generator, and auto-fixer for Arch Linux and Ubuntu/Debian.
- **Obsidian Documentation Vault (`Drone Club DC Vault/`)**: Self-contained markdown vault with relative links and complete step-by-step guides.
