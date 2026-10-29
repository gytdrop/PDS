---
title: "Step 9: Modular Drone & Parts Library Architecture"
aliases: [Modular Drone, Parts Library, Gazebo SDF Modular Architecture, Modular Drone Setup]
tags: [simulation, gazebo, gz-harmonic, sdf, modular, robotics, setup, parts-library, px4, ros2]
created: 2026-10-28
updated: 2026-10-28
status: stable
---

# Step 9: Modular Drone & Parts Library Architecture

[[08 - Performance & Troubleshooting Guide|← Previous: Step 8 - Performance Tuning & Troubleshooting]] | [[Robotics Simulation Pipeline|Pipeline MOC]] | [[Quick Reference & Launch Script|Launch Script Cheat Sheet →]]

---

## 📌 Architectural Overview

In this modular architecture, every folder in the parts library is an **independent, self-contained Gazebo model entity**. Breaking the vehicle into discrete libraries isolates structural airframe meshes, physical mass parameters, propulsion dynamics, and sensor optics so that swapping a motor or perception payload does not require rewriting the core vehicle description.

```text
Parts_library/
├── chassis/                 # Central airframe, arms, landing skids, battery, avionics, & sensors
├── t_motor_f60/             # Single actuator module (stator link + rotor link + joint + motor plugin)
├── livox_mid360/            # Perception sensor module (housing link + optical center link + GPU ray sensor)
└── modular_drone/           # Top-level assembly integrating all sub-models via SDF includes and joints
```

---

## 🏛️ Industry Architectural Lineage & Benchmarks

Our modular simulation stack is built upon the engineering principles of the four canonical UAV simulation repositories:

1. **[PX4/PX4-gazebo-models](https://github.com/PX4/PX4-gazebo-models) (Modern Gazebo / gz-sim)**:
   - *Key Pattern*: Transitioned away from legacy monolithic SDF files to modular base frames (`x500_base`) overlaid with discrete payloads (`OakD-Lite`, `lidar_2d`, `mono_cam`).
   - *Application*: `Parts_library/` implements native SDF 1.8+ includes and scoped namespaces (`::`), eliminating Xacro/URDF compile steps while maintaining seamless compatibility with PX4 SITL.
2. **[ctu-mrs/mrs_uav_gazebo_simulation](https://github.com/ctu-mrs/mrs_uav_gazebo_simulation) (CTU Multi-Robot Systems)**:
   - *Key Pattern*: Battle-tested modular snippets for airframes (f450, f550, t650), pluggable motor thrust ($k_T$) and moment ($k_M$) definitions, and interchangeable sensor payloads.
   - *Application*: Actuator physics and aerodynamic coefficients are completely encapsulated inside `t_motor_f60/model.sdf`, allowing instant swapping between agile freestyle quad motors and high-efficiency endurance propulsion.
3. **[Livox-SDK/livox_laser_simulation](https://github.com/Livox-SDK/livox_laser_simulation) & ROS 2 Ports**:
   - *Key Pattern*: Discrete sensor housing models with dedicated optical center links and custom ray-tracing optics for non-repetitive scan patterns.
   - *Application*: The `livox_mid360` entity encapsulates the physical aluminum housing, optical sapphire glass dome, 10° nose tilt, and high-rate 360° × 59° FOV GPU LiDAR outputting directly to `/livox/points`.
4. **[ethz-asl/rotors_simulator](https://github.com/ethz-asl/rotors_simulator) (ETH Zürich ASL)**:
   - *Key Pattern*: The gold standard for multirotor dynamics modeling (`component_snippets.xacro`, quadratic motor speed scaling, first-order lag filter time constants).
   - *Application*: Accurate mass distributions, first-principles inertia tensors ($I_{xx}, I_{yy}, I_{zz}$), rotor drag coefficients ($c_{\text{drag}}$), and time constants ($\tau_{\text{up}} = 0.0125\text{s}$, $\tau_{\text{down}} = 0.025\text{s}$).

---

## 🧩 Component Roles & File Responsibilities

| Directory | Core Purpose | `model.config` Role | `model.sdf` Contents |
| :--- | :--- | :--- | :--- |
| **`chassis/`** | Structural core, landing geometry, baseline mass distribution, and core avionics. | Declares model name, version (1.8+), and points Gazebo to `model.sdf`. | Defines `base_link` geometry, carbon fiber PBR materials, red anodized standoffs, battery pack, principal inertia tensor ($I_{xx}, I_{yy}, I_{zz}$), contact landing hulls, and avionics sensor suite (IMU, Barometer, Magnetometer, NavSat GPS). |
| **`t_motor_f60/`** | Reusable propulsion unit (instantiated 4× for a quadrotor airframe). | Metadata defining author, email, and minimum SDF version (1.8 recommended). | Defines two links (`motor_base` and `rotor`), a continuous revolute `shaft_joint`, and tri-blade propeller geometry. Aerodynamic `MulticopterMotorModel` plugins are integrated at the top-level assembly (`modular_drone/model.sdf`) for 0..3 actuator indexing. |
| **`livox_mid360/`** | Modular perception payload. | Enables Gazebo model indexing across `GZ_SIM_RESOURCE_PATH`. | Defines sensor casing mass, heatsink fins, sapphire optical mounting link, and the `<sensor type="gpu_lidar">` ray-tracing block (360° × 59° FOV, 40m range). |
| **`modular_drone/`** | The complete vehicle definition passed to the world/SITL simulator. | Entry point loaded by `<include><uri>model://modular_drone</uri></include>` inside a `.world` file or launch script. | Imports instances of the components using `<include>`, positions them with 3D coordinate offsets, bonds them with fixed `<joint>` elements, and attaches odometry and sensor manager plugins. |

---

## 🌳 Rigid-Body Kinematic Hierarchy

When Gazebo parses `modular_drone/model.sdf`, it flattens the nested inclusions into a single kinematic tree using scoped namespacing (`::`).

```text
                                 [World Origin]
                                       │
                      (6-DOF Free-Floating Translation & Rotation)
                                       ▼
                       modular_drone::chassis::base_link
                         (Parent Root of Entire Vehicle)
       ┌───────────────────────┬───────┴───────────────────────┬───────────────────────┐
       │ (Fixed Joint)         │ (Fixed Joint)                 │ (Fixed Joint)         │ (Fixed Joint)
       ▼                       ▼                               ▼                       ▼
motor_fl::motor_base    motor_fr::motor_base            motor_rl::motor_base    motor_rr::motor_base
       │ (Revolute)            │ (Revolute)                    │ (Revolute)            │ (Revolute)
       ▼                       ▼                               ▼                       ▼
 motor_fl::rotor         motor_fr::rotor                 motor_rl::rotor         motor_rr::rotor
                                       │
                                       │ (Fixed Joint: 10° Downward Pitch)
                                       ▼
                              lidar::livox_base
                                       │ (Internal Optical Transform)
                                       ▼
                              lidar::livox_sensor_frame
                                 [GPU Lidar Raycast]
```

### Dynamic Mass & Coordinate Frame Resolution

1. **Root Coordinate Frame**: All sub-model `<pose>` tags inside `modular_drone/model.sdf` use `relative_to="chassis::base_link"`. This positions front motors at $+X, \pm Y$, rear motors at $-X, \pm Y$, and the LiDAR at $+X, +Z$.
2. **Dynamic Mass Aggregation**: The physics solver (Bullet Featherstone or DART) sums link masses and computes the combined Center of Mass ($\mathbf{r}_{\text{CoM}}$):
   $$M_{\text{total}} = m_{\text{chassis}} + \sum_{i=1}^4 \left(m_{\text{motor\_base}, i} + m_{\text{rotor}, i}\right) + m_{\text{lidar}} \approx 1.355\text{ kg}$$
3. **Fixed Joint Lumping**: The physics engine merges links connected by fixed joints (`base_link`, `motor_base`, and `livox_base`) into a single equivalent rigid body with aggregated inertia to eliminate numerical solver jitter. Only the four rotor links remain dynamic child joints with angular degrees of freedom.

---

## ⚡ First-Time Setup Instructions

### 🚀 Recommended: Automated 1-Click Setup & Doctor (`setup_modular_drone.sh`)

An automated system verification script is provided in the repository root. It dynamically detects your workspace location and Linux distribution (Arch Linux vs. Ubuntu/Debian), checks Gazebo, PX4, ROS 2, and MicroXRCEAgent, validates all model files, links symlinks, and configures your shell environment portably:

```bash
# Navigate to the project root (relative to this vault):
cd ../..

# Run full diagnostics and auto-fix symlinks/shell exports:
./setup_modular_drone.sh --fix

# Open standalone 3D Gazebo preview:
./setup_modular_drone.sh --preview
```

---

### Manual Setup Instructions

#### 1. Environment Variable Configuration

Add the `Parts_library` search paths to your `~/.bashrc` (works anywhere the project is cloned):

```bash
# In your ~/.bashrc or terminal:
export PARTS_LIB="$(pwd)/Parts_library"
export GZ_SIM_RESOURCE_PATH="$PARTS_LIB:$HOME/PX4-Autopilot/Tools/simulation/gz/models:$HOME/PX4-Autopilot/Tools/simulation/gz/worlds:${GZ_SIM_RESOURCE_PATH:-}"
export SDF_PATH="$PARTS_LIB:${SDF_PATH:-}"
export GZ_SIM_PHYSICS_ENGINE_PATH="/usr/lib/gz-physics-7/engine-plugins:${GZ_SIM_PHYSICS_ENGINE_PATH:-}"
export PX4_GZ_PHYSICS_ENGINE="gz-physics-bullet-featherstone-plugin"
```

Then reload your environment:
```bash
source ~/.bashrc
```

### 2. Verify SDFormat Semantic Validity

Run the `gz sdf` utility from the project root:

```bash
cd ../..
gz sdf -k Parts_library/modular_drone/model.sdf
```

*Expected output:*
```text
Valid.
```

### 3. Standalone 3D Preview in Gazebo Harmonic

To visually inspect the vehicle geometry, PBR materials, and sensor raycasts before launching full flight autonomy:

```bash
gz sim -v 4 Parts_library/modular_drone/model.sdf
```

---

## 🔌 The Modules Connection Architecture (PX4 + MicroXRCE + Gazebo + ROS 2)

The connection between PX4, Micro XRCE-DDS, Gazebo Harmonic, and the discrete modular entities operates across a unified 4-tier simulation runtime stack:

```mermaid
flowchart TD
    subgraph Tier1 ["Tier 1: Gazebo Harmonic Simulation Engine (Server Process: gz-sim / gz-server)"]
        Physics["Bullet Featherstone Physics Engine<br/>(6-DOF vehicle dynamics, gravity, contact restitution)"]
        Rendering["Ogre 2.x Rendering Engine<br/>(GPU raycaster & depth buffer for LiDAR)"]
    end

    subgraph Tier2 ["Tier 2: Entity-Component System (ECS) Model Assembly"]
        ModularDrone["modular_drone (Master Entity)"]
        Chassis["chassis::base_link<br/>(Parent root: carbon frame, avionics, battery)"]
        Motors["4x t_motor_f60 Actuators<br/>(motor_fl, motor_fr, motor_rl, motor_rr)"]
        LiDAR["livox_mid360 Perception<br/>(livox_base + livox_sensor_frame)"]
        
        ModularDrone --> Chassis
        Chassis -->|"joint_mount_fl..rr (Fixed)"| Motors
        Chassis -->|"joint_mount_lidar (Fixed, 10° pitch)"| LiDAR
    end

    subgraph Tier3 ["Tier 3: Actuator & Sensor Processing Pipelines"]
        MotorSystem["MulticopterMotorModel Plugins<br/>F_thrust = k_T * omega^2<br/>Tau_drag = k_M * F_thrust"]
        SensorsSystem["gz-sim-sensors-system<br/>IMU (250Hz), Baro (50Hz), Mag (100Hz), NavSat (30Hz)<br/>GPU Ray LiDAR (10Hz, 360°x59° FOV)"]
        OdomSystem["gz-sim-odometry-publisher-system<br/>Ground truth & body-frame odometry"]
    end

    subgraph Tier4 ["Tier 4: Autopilot SITL & ROS 2 Middleware Bridge"]
        PX4["PX4 Autopilot SITL (v1.17)<br/>EKF2 State Estimator & PID Flight Controllers"]
        XRCEAgent["Micro XRCE-DDS Agent<br/>(High-speed UDP port 8888 bridge)"]
        ROS2["ROS 2 Autonomy Stack (Humble)<br/>px4-teleop / offboard_control"]
        ROSGZBridge["ros_gz_bridge<br/>Maps Gazebo sensor streams to ROS 2 topics"]
    end

    %% Kinematic and Data Connections
    Physics <--> Tier2
    Motors <--> MotorSystem
    LiDAR <--> SensorsSystem
    Chassis <--> SensorsSystem
    
    MotorSystem <==|"command/motor_speed"| PX4
    SensorsSystem ==>|"Raw Sensor Readings"| PX4
    OdomSystem ==>|"/model/modular_drone/odometry"| ROSGZBridge
    SensorsSystem ==>|"/model/modular_drone/livox_lidar/scan"| ROSGZBridge
    
    PX4 <==|"uORB Serialized Packets (UDP 8888)"| XRCEAgent
    XRCEAgent <==|"FastDDS (/fmu/in/* & /fmu/out/*)"| ROS2
    ROSGZBridge ==>|"/livox/points (PointCloud2) & /odom"| ROS2
```

### 1. Actuator Dynamics & Signal Flow
- **Control Input:** In ROS 2, `px4-teleop` or `offboard_control` streams position/velocity targets to `/fmu/in/trajectory_setpoint`.
- **Flight Controller:** PX4's EKF2 estimates state, runs position and attitude PID loops, and passes mixer outputs to `actuator_motors`.
- **SITL Bridge:** PX4's `gz_bridge` converts uORB motor commands into `gz.msgs.Actuators` published to `/command/motor_speed`.
- **Aerodynamics Plugin:** In each `t_motor_f60` module, the `MulticopterMotorModel` system calculates motor speed $\omega$ using first-order lag filters ($\tau_{\text{up}}, \tau_{\text{down}}$), generating quadratic vertical lift and reaction torque:
  $$F_{\text{thrust}} = k_T \cdot \omega^2, \quad \tau_{\text{yaw}} = k_M \cdot F_{\text{thrust}}$$

### 2. Sensor Perception & Odometry Flow
- **Avionics Sensors:** The `chassis` module houses an IMU (`250 Hz`), Barometer (`50 Hz`), Magnetometer (`100 Hz`), and NavSat GPS (`30 Hz`) defined directly on `base_link`. PX4 ingests these via lockstep clock (`/clock`) to compute EKF2 attitude and position estimates.
- **Perception Payload:** The `livox_mid360` raycaster generates pointclouds published to `/model/modular_drone/livox_lidar/scan`. The `ros_gz_bridge` transforms this stream into standard ROS 2 `sensor_msgs/msg/PointCloud2` on `/livox/points`.
- **Ground Truth Odometry:** The `gz-sim-odometry-publisher-system` plugin attached to `modular_drone` broadcasts `/model/modular_drone/odometry`, mapped by `ros_gz_bridge` to `/odom`.

---

## 🎨 Visual Aesthetics & PBR Materials

The modular library replaces basic grey CAD primitives with production-grade visual materials:

- **Carbon Fiber Decks**: Multi-layer sandwich plates featuring dark graphite matte twill texture (`#18191c`, roughness: 0.35, metalness: 0.20).
- **Anodized Standoffs**: CNC aluminum hex standoffs finished in race-spec crimson red (`#b32424`).
- **LiPo Battery Pack**: Centrally secured 6S battery with high-visibility hazard yellow racing decals (`#ffaa00`) and XT60 lead.
- **Avionics Bay**: Central flight controller housing with active cyan status indicator beacon (`#00e5ff` emissive glow).
- **Brushless Actuators (T-Motor F60)**: Midnight-blue anodized bell (`#102244`), copper winding stator core (`#c87a32`), and smoke-tinted aerodynamic tri-blade propellers.
- **Livox Mid-360**: Anodized gunmetal heat dissipation ribs and an anti-reflective sapphire glass optical dome.

---

## 🔄 Customization Runbook: Swapping Components

### Swapping Actuators (e.g., 5" Agile Quad to 8" Endurance Quad)

1. Create a copy of the actuator module:
   ```bash
   cp -r Parts_library/t_motor_f60 Parts_library/t_motor_u8
   ```
2. Adjust `motorConstant` and propeller dimensions in `Parts_library/t_motor_u8/model.sdf`.
3. In `Parts_library/modular_drone/model.sdf`, update the `<uri>` tag:
   ```xml
   <include>
     <uri>model://t_motor_u8</uri>
     <name>motor_fl</name>
     <pose relative_to="chassis::base_link">0.22 0.22 0.03 0 0 0</pose>
   </include>
   ```

### Adjusting Perception Payload (e.g., Pitch Angle or Camera Swap)

To adjust the downward pitch of the Livox Mid-360:
```xml
<!-- Tilted 15 degrees down (0.2618 rad) instead of 10 degrees -->
<pose relative_to="chassis::base_link">0.12 0 0.05 0 0.261799 0</pose>
```
To swap the LiDAR for an OakD-Lite stereo camera, update the `<uri>` to `model://OakD-Lite` and joint child to `camera::camera_link`.

---

## 🚀 Running Flight Simulation

Launch the complete stack with a single command from the project root (or `../../` relative to this note):

```bash
# Standard Launch (PX4 SITL + Gazebo Harmonic + MicroXRCEAgent + ROS 2 + QGroundControl)
./"installed gigs"/start_sim.sh -m modular_drone

# Headless Physics Server (High Performance / Low CPU usage)
./"installed gigs"/start_sim.sh -m modular_drone --headless
```

Fly the modular drone using the interactive keyboard teleoperation node:
```bash
px4-teleop
```
Press **`T`** to arm and auto-takeoff, fly with **`W/A/S/D`**, and land with **`L`**.

---

## 🔗 Related Notes
- [[Welcome|Vault Index]]
- [[Robotics Simulation Pipeline|Simulation Pipeline MOC]]
- [[Installed Gigs & Simulation Tooling|Installed Gigs & Tooling Reference]]
- [[02 - Gazebo Harmonic Setup|Step 2: Gazebo Sim & Physics]]
- [[03 - Micro XRCE-DDS & ROS 2 Setup|Step 3: Micro XRCE-DDS Middleware]]
- [[07 - Sample Drone Flight|Step 7: Flight & Teleop]]
- [[08 - Performance & Troubleshooting Guide|Step 8: Troubleshooting]]
- [[Quick Reference & Launch Script|Launch Script Cheat Sheet]]
- [`../../Parts_library/README.md`](../../Parts_library/README.md)
