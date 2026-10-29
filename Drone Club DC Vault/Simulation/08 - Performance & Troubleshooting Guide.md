---
title: "Step 8: Performance Tuning & Troubleshooting Guide"
aliases: [Performance Guide, Troubleshooting, Debug Guide, Simulation Tuning]
tags: [simulation, performance, troubleshooting, debugging, px4, gazebo, ros2]
created: 2026-09-30
updated: 2026-10-16
status: stable
---

# Step 8: Performance Tuning & Troubleshooting Guide

[[07 - Sample Drone Flight|← Previous: Step 7 - Sample Flight]] | [[Robotics Simulation Pipeline|Pipeline MOC]] | [[09 - Modular Drone & Parts Library Setup|Next: Step 9 - Modular Drone & Parts Library Setup →]]

---

## ⚡ Comprehensive Diagnostic Matrix

| Symptom / Error | Root Cause | Verified Resolution |
| :--- | :--- | :--- |
| **`Preflight Fail: Attitude failure (roll)`** | Vehicle flipped onto its back (`Roll ~ 3.14 rad`) on spawn. In `gz_x500_depth`, the OakD-Lite camera collision geometry overlaps `base_link`, causing contact solver repulsion impulses under Bullet Featherstone physics. | Use the standard quadcopter model `gz_x500` (set as default in `start_sim.sh`). Check `gz model -m x500_0 -p` to verify roll/pitch are 0.0. Run `commander check` in PX4 console. |
| **Drone flies sideways / controls disoriented** | Gazebo uses ENU ($+X$ = East) whereas PX4 uses NED ($+X$ = North). When the drone spawns East, commanding `vx` in NED moves North (to its left). | 1. In `px4-teleop`, velocities are automatically transformed dynamically into body frame using live heading: $v_{\text{north}} = v_{\text{fwd}}\cos\psi - v_{\text{lat}}\sin\psi$.<br/>2. Toggle between `BODY` and `WORLD` modes using key **`[M]`**.<br/>3. Airframe spawn yaw aligned with North (`PX4_GZ_MODEL_POSE="0,0,0.24,0,0,-1.5707963"`). |
| **Yaw wobbling or unconstrained heading drift** | In `TrajectorySetpoint`, setting `sp.yaw = float('nan')` leaves PX4 yaw unconstrained, allowing motor torque reaction to cause slow drift. | `px4-teleop` tracks `target_yaw`. When manual rotation keys (`[Q]`/`[E]`) are released, `sp.yaw = target_yaw` actively holds the heading. |
| **Drone bouncing, sliding, or glitching on ground** | Ground plane collision mesh in `default.sdf` was set to a tiny `<size>1 1</size>` (1m $\times$ 1m) with unconfigured contact stiffness. | Expand `<size>500 500</size>` in `default.sdf` and set contact damping (`kp=1e8`, `min_depth=0.005`, `mu=1.0`, zero restitution). |
| **Gazebo camera disoriented or stationary** | Default camera does not track vehicle altitude or position. | Export `PX4_GZ_FOLLOW=1` in `start_sim.sh` with chase camera offsets (`X=0.0`, `Y=2.5`, `Z=1.2`) to follow drone automatically. |
| **`WARN [health_and_arming_checks] Preflight Fail: No manual control input`** | PX4 expects physical RC transmitter input before arming. | In SITL, set `COM_RCL_EXCEPT 4` in `4001_gz_x500` ROMFS airframe defaults to permit offboard arming without RC sticks. |
| **`WARN [health_and_arming_checks] Preflight Fail: Data link lost`** | GCS MAVLink heartbeat lost or QGC not connected. | Set `NAV_DLL_ACT 0` in ROMFS to disable data link loss failsafe during pure ROS 2 autonomous runs. |
| **`Failed to find plugin [gz-physics-bullet-featherstone-plugin]`** | Gazebo cannot locate Bullet physics engine on Arch Linux. | Set `GZ_SIM_PHYSICS_ENGINE_PATH=/usr/lib/gz-physics-7/engine-plugins` and ensure `gz-physics-bullet-featherstone-plugin` is specified in `px4-rc.gzsim`. |
| **ROS 2 subscriber receives no data from PX4** | Topic suffix mismatch (PX4 v1.17 uXRCE-DDS) or QoS profile mismatch. | 1. Use versioned topics `/fmu/out/vehicle_local_position_v1` and `/fmu/out/vehicle_status_v1`.<br/>2. Configure ROS 2 QoS with `ReliabilityPolicy.BEST_EFFORT`. |
| **High CPU load or simulator stutter** | Intel integrated graphics processing full 3D Gazebo GUI alongside physics. | Launch in headless mode: `./start_sim.sh --headless`. Server physics runs at full real-time factor without rendering overhead. |
| **`MicroXRCEAgent: Address already in use`** | A previously running agent or process is holding UDP port `8888`. | Run `./start_sim.sh --kill` to purge stale agents, or check with `ss -ulnp \| grep 8888`. |
| **`Unable to find uri[model://chassis]` / `empty callback`** | Standalone `gz sdf` or Gazebo Sim could not find nested model entities. | Export `PARTS_LIB="$HOME/Documents/PROJECTS/DC- Drone Club/Parts_library"` and add to `SDF_PATH` and `GZ_SIM_RESOURCE_PATH`. See [[09 - Modular Drone & Parts Library Setup|Step 9]]. |

---

## 🛠️ Step-by-Step Diagnostic Runbooks

### Runbook 1: Verifying Vehicle Attitude & Ground Stability
When an arming command is rejected, check vehicle orientation in Gazebo:
```bash
gz model -m x500_0 -p
```
Look for:
```text
Pose [ XYZ (m) ] [ RPY (rad) ]:
  [0.000000 0.000000 -0.013000]
  [-0.000000 -0.000002 0.000001]
```
If Roll or Pitch exceeds $\pm 0.1\text{ rad}$, the model has tilted or flipped. Reset with:
```bash
./start_sim.sh --kill
./start_sim.sh -m gz_x500
```

### Runbook 2: Inspecting Live PX4 Health Checks
Inside Pane 1 of `start_sim.sh` (or any PX4 console):
```text
pxh> commander check
```
- **Healthy:** `INFO [commander] Preflight check: OK`
- **Degraded:** Details exactly which sensor or failsafe check failed (e.g., Mag, EKF, or Attitude).

### Runbook 3: Inspecting uORB & ROS 2 Telemetry
Check the active state directly inside PX4:
```text
pxh> listener vehicle_status
```
Verify `arming_state: 2` (ARMED) and `nav_state: 14` (OFFBOARD).

Check ROS 2 topic reception:
```bash
ros2 topic echo /fmu/out/vehicle_local_position_v1 --qos-reliability best_effort --once
```

### Runbook 4: Verifying Coordinate Alignment & Active Heading Lock
1. In `px4-teleop`, verify the HUD header:
   ```text
   [HUD] State: ARMED | Offboard: ACTIVE | Mode: BODY | Alt: 2.50m | Pos: (0.0, 0.0) | Heading: -86.0° | TgtYaw: -86.0°
   ```
2. Press **`M`** to switch between **`BODY`** (flies relative to vehicle nose) and **`WORLD`** (absolute North/East).
3. If heading drifts over time, verify that `TrajectorySetpoint.yaw` receives `target_yaw` rather than `NaN`:
   ```bash
   ros2 topic echo /fmu/in/trajectory_setpoint --once
   ```

---

## 🚀 Performance Optimization Best Practices

1. **Use Headless Mode for Automation & Training:**
   ```bash
   ./start_sim.sh --headless
   ```
   Headless mode bypasses Qt/Vulkan 3D rendering, reducing GPU and CPU utilization by up to 40% while preserving exact lockstep physics fidelity.

2. **Airframe ROMFS Tuning:**
   The airframe definition at `~/PX4-Autopilot/ROMFS/px4fmu_common/init.d-posix/airframes/4001_gz_x500` has been tuned with:
   ```bash
   param set-default NAV_DLL_ACT 0      # Prevent GCS disconnect preflight rejection
   param set-default COM_RCL_EXCEPT 4   # Allow offboard flight without RC controller
   ```

---

## 🔗 Related Notes
- [[Robotics Simulation Pipeline|Simulation Pipeline MOC]]
- [[06 - Smoke Test & Flight Verification]]
- [[07 - Sample Drone Flight]]
- [[Quick Reference & Launch Script]]
- [[Installed Gigs & Simulation Tooling|Installed Tools & Binaries Reference]] ([`../../installed gigs/`](../../installed%20gigs/))
