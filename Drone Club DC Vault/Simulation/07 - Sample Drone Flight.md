---
title: "Step 7: Sample Drone Flight & ROS 2 Autonomy"
aliases: [Sample Flight, ROS2 Flight, Drone Autonomy, Keyboard Teleop, Offboard Control]
tags: [simulation, flight, ros2, teleop, offboard, px4, python]
created: 2026-09-30
updated: 2026-10-16
status: stable
---

# Step 7: Sample Drone Flight & ROS 2 Autonomy

[[06 - Smoke Test & Flight Verification|← Previous: Step 6 - Smoke Test]] | [[Robotics Simulation Pipeline|Pipeline MOC]] | [[08 - Performance & Troubleshooting Guide|Next: Step 8 - Diagnostics & Tuning →]]

---

## 📌 Overview

This guide details two methods for flying the simulated drone in PX4 + Gazebo Harmonic via ROS 2:
1. **Interactive Keyboard Flight (`px4-teleop`)**: Real-time velocity vector steering from your keyboard with a live terminal HUD.
2. **Autonomous Trajectory Node (`offboard_control.py`)**: Fully scripted ROS 2 node that streams 10Hz offboard setpoints, arms, and executes a precision hover profile.

---

## 🎮 Flight Method 1: Interactive Keyboard Teleoperation (`px4-teleop`)

The teleoperation node is located in the ROS 2 workspace at `~/px4_ros2_ws/src/px4_ros_com/src/examples/offboard_py/px4_teleop_key.py` and wrapped into a convenient CLI utility `px4-teleop`. It controls both standard airframes (`gz_x500`) and custom modular airframes (`modular_drone` from `Parts_library/`).

### Launching Teleop:
From Pane 2 of `start_sim.sh` (or any terminal):
```bash
# Standard simulation:
./start_sim.sh
# Or with modular drone:
./start_sim.sh -m modular_drone

# Then inside the ROS 2 pane:
px4-teleop
```

### Live Terminal HUD:
The node renders an ASCII dashboard directly in your terminal at 10 Hz:
```text
[HUD] State: ARMED | Offboard: ACTIVE | Mode: BODY | Alt: 2.50m | Pos: ( 0.0, -0.0) | Vel: [+0.0, +0.0, -0.0] m/s | Heading: -86.0° | TgtYaw: -86.0° | Speed: 1.5m/s | Action: HOVER
```

### Key Controls Reference:

| Flight Action | Key(s) | Description |
| :--- | :--- | :--- |
| **Auto-Takeoff** | `T` | Arms the vehicle, engages `OFFBOARD` mode, climbs to 2.5m, and stabilizes |
| **Hover / Brake** | `Space` / `H` | Immediately zeros all velocity setpoints and actively locks target yaw |
| **Land** | `L` | Commands landing descent and disarms on ground touchdown |
| **Mode Toggle** | `M` | Toggles between **`BODY-RELATIVE`** (nose-aligned) and `WORLD-RELATIVE` (compass North) |
| **Pitch (Forward / Back)** | `W` / `S` | Drives forward along the drone's nose direction / reverses backward |
| **Roll (Strafe Left / Right)** | `A` / `D` | Strafes sideways left / right relative to vehicle orientation |
| **Altitude (Climb / Descend)**| `Up` / `R` / `I` & `Down` / `F` / `K` | Vertical ascent ($-Z$ NED) / Descent ($+Z$ NED) |
| **Yaw (Turn Left / Right)** | `Left` / `Q` & `Right` / `E` | Rotates yaw heading counter-clockwise / clockwise (actively holds angle when released) |
| **Arm / Disarm** | `O` (Arm) / `P` (Disarm) | Manual motor arm and emergency kill switch |
| **Speed Presets** | `1` (0.5 m/s) / `2` (1.5 m/s) / `3` (3.0 m/s) | Adjusts flight speed scaling dynamically |

---

## 🤖 Flight Method 2: Autonomous Offboard Control (`offboard_control.py`)

For automated mission execution without keyboard input, use the compiled ROS 2 offboard control node:

```bash
ros2 run px4_ros_com offboard_control.py
```

### Node Architecture:
1. **Pre-flight Stream (100 cycles at 10 Hz)**: Streams `/fmu/in/offboard_control_mode` and `/fmu/in/trajectory_setpoint` prior to mode switch to satisfy PX4 offboard watchdog rules.
2. **Mode Switch & Arming**: Publishes `VEHICLE_CMD_DO_SET_MODE` (Mode: Offboard) and `VEHICLE_CMD_COMPONENT_ARM_DISARM` (Arm: 1.0) over `/fmu/in/vehicle_command`.
3. **Climb & Altitude Lock**: Commands $z = -5.0\text{ m}$ in NED coordinate frame.
4. **Position Hold**: Maintains precision position lock using local odometry feedback.

---

## 📡 Underlying ROS 2 Setpoint Specification

Offboard control in PX4 requires publishing to two essential input topics:

### 1. Offboard Control Mode (`/fmu/in/offboard_control_mode`)
```python
from px4_msgs.msg import OffboardControlMode

mode = OffboardControlMode()
mode.position = False
mode.velocity = True
mode.acceleration = False
mode.attitude = False
mode.body_rate = False
mode.timestamp = int(node.get_clock().now().nanoseconds / 1000)
offboard_pub.publish(mode)
```

### 2. Trajectory Setpoint (`/fmu/in/trajectory_setpoint`)
```python
from px4_msgs.msg import TrajectorySetpoint
import math

# Dynamic Body-Frame to World NED Transformation:
psi = heading if not math.isnan(heading) else target_yaw
cos_psi = math.cos(psi)
sin_psi = math.sin(psi)
world_vx = cmd_forward * cos_psi - cmd_lateral * sin_psi
world_vy = cmd_forward * sin_psi + cmd_lateral * cos_psi

sp = TrajectorySetpoint()
sp.position = [float('nan'), float('nan'), float('nan')]
sp.velocity = [float(world_vx), float(world_vy), float(cmd_vz)]
sp.yaw = float(target_yaw)       # Actively locks orientation (no yaw drift)
sp.yawspeed = float(cmd_yawspeed)
sp.timestamp = int(node.get_clock().now().nanoseconds / 1000)
trajectory_pub.publish(sp)
```

---

## 🔗 Related Notes
- [[Robotics Simulation Pipeline|Simulation Pipeline MOC]]
- [[06 - Smoke Test & Flight Verification]]
- [[08 - Performance & Troubleshooting Guide]]
- [[Quick Reference & Launch Script]]
- [[Installed Gigs & Simulation Tooling|Installed Tools & Binaries Reference]] ([`../../installed gigs/`](../../installed%20gigs/))
