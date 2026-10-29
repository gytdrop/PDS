# 🛸 Modular Drone Architecture & Parts Library

This directory implements an independent, self-contained Gazebo Sim (Harmonic 8.15.0) model library. Breaking the airframe into discrete modules isolates structural carbon geometry, actuator dynamics, and sensor optics so that swapping a propulsion unit or perception sensor does not require modifying the base vehicle definition.

---

## 🏛️ Industry Architectural Lineage & Benchmarks

Our modular parts library synthesizes the proven architectural paradigms of the four canonical UAV simulation ecosystems:

| Ecosystem / Repository | Core Paradigm | Key Mechanism | How We Synthesize It in `Parts_library/` |
| :--- | :--- | :--- | :--- |
| **[PX4/PX4-gazebo-models](https://github.com/PX4/PX4-gazebo-models)** | Modern Gazebo Native SDF 1.8+ | Base frames (`x500_base`) + modular sensor overlays (`OakD-Lite`, `lidar_2d`) via `<include>` and fixed joints. | Native pure-SDF composition without external pre-processors; fully compliant with Gazebo Harmonic 8.x resource discovery (`GZ_SIM_RESOURCE_PATH`). |
| **[ctu-mrs/mrs_uav_gazebo_simulation](https://github.com/ctu-mrs/mrs_uav_gazebo_simulation)** | Modular ROS / ROS 2 Ecosystem | Dedicated modular snippet libraries for airframes (f450, f550), propulsion constants ($k_T, k_M$), and sensor payloads. | Parameterized motor dynamics ($k_T, k_M, \text{timeConstantUp/Down}$) isolated strictly inside `t_motor_f60` so airframe geometry remains decoupled from actuator physics. |
| **[Livox-SDK/livox_laser_simulation](https://github.com/Livox-SDK/livox_laser_simulation)** | Dedicated Solid-State / Hybrid LiDAR | Independent sensor housing link, optical transform link, and ray-tracing configuration for non-repetitive scan patterns. | Standalone `livox_mid360` entity featuring realistic 360° × 59° FOV, 10° downward chassis nose pitch, and high-rate `/livox/points` pointcloud generation. |
| **[ethz-asl/rotors_simulator](https://github.com/ethz-asl/rotors_simulator)** | Canonical Academic Dynamics Reference | First-principles multirotor dynamics (`component_snippets.xacro`), motor lag time constants, and diagonal inertia tensors. | Accurate diagonal inertia tensors ($I_{xx}, I_{yy}, I_{zz}$), lumped-mass rigid body solver stabilization under Bullet Featherstone, and quadratic thrust scaling ($F = k_T \omega^2$). |

---

## 📁 Directory Structure Breakdown

```text
Parts_library/
├── chassis/                 # Central airframe, arms, landing skids, battery, avionics, & sensors
│   ├── model.config         # Gazebo model metadata & entry point
│   └── model.sdf            # base_link geometry, carbon PBR materials, collision hulls, & IMU/GPS/Baro/Mag
├── t_motor_f60/             # Reusable propulsion unit (instantiated 4× for quadrotor)
│   ├── model.config         # Actuator metadata
│   └── model.sdf            # Stator link, rotor bell, continuous shaft_joint, & tri-blade propeller geometry
├── livox_mid360/            # Modular perception payload
│   ├── model.config         # Sensor metadata & GZ_SIM_RESOURCE_PATH discovery indexing
│   └── model.sdf            # Housing link, sapphire glass dome link, & 360°x59° GPU ray LiDAR sensor
├── modular_drone/           # Top-level assembly integrating all sub-models
│   ├── model.config         # Entry point loaded by <include><uri>model://modular_drone</uri></include>
│   └── model.sdf            # Master assembly tying sub-models via scoped includes, joints, 4x MulticopterMotorModel plugins, & odom plugins
├── preview_world.sdf        # Standalone inspection world with ground plane, sun lighting, & Featherstone physics
└── README.md                # This setup, modification, and first-time configuration guide
```

---

## ⚡ First-Time Setup Guide

Follow these steps when configuring the simulation workstation for the first time or after cloning the repository.

### 1. Configure Shell Environment Variables

Gazebo Sim resolves `model://<name>` URIs using `GZ_SIM_RESOURCE_PATH` and `SDF_PATH`. Add the `Parts_library` absolute path to your shell configuration (`~/.bashrc` or `~/.zshrc`):

```bash
# Add to ~/.bashrc or ~/.zshrc:
export PARTS_LIB="$HOME/Documents/PROJECTS/DC- Drone Club/Parts_library"
export GZ_SIM_RESOURCE_PATH="$PARTS_LIB:${GZ_SIM_RESOURCE_PATH:-}"
export SDF_PATH="$PARTS_LIB:${SDF_PATH:-}"
export GZ_SIM_PHYSICS_ENGINE_PATH="/usr/lib/gz-physics-7/engine-plugins:${GZ_SIM_PHYSICS_ENGINE_PATH:-}"
export PX4_GZ_PHYSICS_ENGINE="gz-physics-bullet-featherstone-plugin"
```

Apply immediately to your current terminal:
```bash
source ~/.bashrc
```

### 2. Verify SDFormat Semantic Validity

Run the built-in Gazebo SDFormat validator to confirm all nested model inclusions, relative frame references, and joint attachments resolve without errors:

```bash
cd "$HOME/Documents/PROJECTS/DC- Drone Club"

# Validate individual modules:
gz sdf -k Parts_library/chassis/model.sdf
gz sdf -k Parts_library/t_motor_f60/model.sdf
gz sdf -k Parts_library/livox_mid360/model.sdf

# Validate top-level integrated assembly:
gz sdf -k Parts_library/modular_drone/model.sdf
```

*Expected output for each:*
```text
Valid.
```

### 3. Inspect Physical Parameters & Flattened Hierarchy

Inspect the dynamic Center of Mass (CoM) and inertia tensor aggregated across all lumped links:

```bash
gz sdf --inertial-stats Parts_library/modular_drone/model.sdf
```

To view the fully resolved, namespace-flattened XML tree generated by Gazebo:
```bash
gz sdf -p Parts_library/modular_drone/model.sdf | less
```

### 4. Interactive Standalone 3D Preview

Launch the modular drone directly inside a standalone Gazebo Sim 3D viewport to inspect materials, lighting, and joint kinematics:

```bash
# Recommended: Standalone 3D inspection world with ground plane and sun:
./setup_modular_drone.sh --preview

# Or direct Gazebo CLI invocation:
gz sim -v 4 --physics-engine gz-physics-bullet-featherstone-plugin Parts_library/preview_world.sdf
```

---

## 🎨 Visual Design & High-Fidelity Aesthetic Specifications

Unlike standard primitive simulation models, this parts library features realistic aerospace surface finishes and physical properties:

| Component | Aesthetic Treatment | Physical / Functional Feature |
| :--- | :--- | :--- |
| **`chassis` Decks** | Matte 3K carbon fiber composite (`#18191c`, roughness 0.35, metalness 0.20) | Upper and lower sandwich decks isolating electronics from vibration. |
| **`chassis` Standoffs** | Red anodized CNC aluminum (`#b32424`, specular 0.90) | Rigid hex columns maintaining 35mm structural plate separation. |
| **`chassis` Battery** | Central 6S LiPo with high-contrast safety yellow wrap (`#ffaa00`) | Underbody mount keeping combined Center of Gravity (CoG) centered at `Z ≈ 0`. |
| **`chassis` Avionics** | Matte black flight stack with pulsing cyan LED beacon (`#00e5ff` emissive) | Encapsulates IMU (250Hz), Barometer (50Hz), Magnetometer (100Hz), and GPS (30Hz). |
| **Landing Skids** | High-density TPU landing bumpers with ground-friction contact ode surfaces | Prevents solver jitter and bouncing upon touchdown. |
| **`t_motor_f60` Base** | CNC titanium stator base with exposed copper armature coils (`#c87a32`) | Rigidly bonded via fixed joints to carbon boom arm ends. |
| **`t_motor_f60` Bell** | Deep anodized midnight-blue bell (`#102244`) with laser-beveled silver rim | Continuous revolute spindle joint (`shaft_joint`) along `Z`. |
| **`t_motor_f60` Prop** | 5-inch competition tri-blade propeller in semi-translucent smoked finish | Aerodynamic chord twist with `MulticopterMotorModel` thrust & drag. |
| **`livox_mid360` Base** | Gunmetal anodized cylindrical housing with CNC heatsink cooling ribs | Sits on nose mount tilted 10° forward/downward. |
| **`livox_mid360` Dome** | Anti-reflective deep sapphire blue optical glass dome (`#0f172a` translucent) | Houses 360° horizontal × 59° vertical GPU raycasting LiDAR core. |

---

## 🔄 Rigid-Body Kinematic Hierarchy

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
                                       │ (Fixed Optical Joint)
                                       ▼
                              lidar::livox_sensor_frame
                                 [GPU Lidar Raycast]
```

### Mass & Center of Gravity Breakdown

- **Chassis + Battery + Avionics**: ~0.950 kg
- **Motors (4× T-Motor F60)**: $4 \times (0.026 + 0.009)\text{ kg} = 0.140\text{ kg}$
- **Perception (Livox Mid-360)**: $0.250 + 0.015 = 0.265\text{ kg}$
- **Total Combined All-Up Weight (AUW)**: **1.355 kg**
- **CoM Position**: Centered within $\pm 0.01\text{m}$ along $X/Y$, slightly biased forward ($+0.018\text{m}$) by LiDAR counterbalanced by rearward battery offset ($-0.010\text{m}$).

---

## 🛠️ How to Swap Components (Modular Customization)

### Scenario A: Switching from 5" Agile Quad to 8" Long-Range Endurance Quad

1. Duplicate `Parts_library/t_motor_f60` to `Parts_library/t_motor_u8/`:
   ```bash
   cp -r Parts_library/t_motor_f60 Parts_library/t_motor_u8
   ```
2. In `Parts_library/t_motor_u8/model.sdf`:
   - Increase rotor collision radius and visual box scale to 8 inches ($0.101\text{m}$ radius).
   - Update `motorConstant` (e.g., from `8.54e-6` to `1.45e-5`) and reduce `maxRotVelocity` (e.g., to `1400.0`).
3. In `Parts_library/modular_drone/model.sdf`, update the motor includes:
   ```xml
   <include>
     <uri>model://t_motor_u8</uri>
     <name>motor_fl</name>
     <pose relative_to="chassis::base_link">0.22 0.22 0.03 0 0 0</pose>
   </include>
   ```
   *Result*: The drone is now an 8" endurance platform. Chassis, LiDAR, and bridge layers remain untouched.

### Scenario B: Adjusting LiDAR Mounting Angle or Switching Sensor Payload

To change the downward tilt angle of the Livox Mid-360:
1. Open `Parts_library/modular_drone/model.sdf`.
2. Locate the `<include>` block for `lidar`:
   ```xml
   <!-- Pitch is the 5th value in pose: roll pitch yaw (in radians) -->
   <!-- 0.174533 rad = 10 degrees down | 0.261799 rad = 15 degrees down -->
   <pose relative_to="chassis::base_link">0.12 0 0.05 0 0.261799 0</pose>
   ```
3. To replace LiDAR with an Oak-D Depth Camera, swap `model://livox_mid360` with `model://OakD-Lite` and update the mount joint child to `camera::camera_link`.

---

## 🚀 Integration with PX4 SITL & ROS 2 Pipeline

### Automated Launcher (`start_sim.sh`)

The workspace launcher automatically exports the `Parts_library` discovery paths:

```bash
# Launch modular drone with PX4 SITL, Micro XRCE-DDS Agent, ROS 2, and QGroundControl:
./installed\ gigs/start_sim.sh -m modular_drone

# Launch in headless physics mode (saving GPU resources):
./installed\ gigs/start_sim.sh -m modular_drone --headless
```

### ROS 2 Topics Published:

| Simulation Source Topic | ROS 2 Bridged Topic | Message Type |
| :--- | :--- | :--- |
| `/model/modular_drone/odometry` | `/odom` | `nav_msgs/msg/Odometry` |
| `/model/modular_drone/livox_lidar/scan` | `/livox/points` | `sensor_msgs/msg/PointCloud2` |
| `/world/default/clock` | `/clock` | `rosgraph_msgs/msg/Clock` |
| `/fmu/out/vehicle_odometry` | `/fmu/out/vehicle_odometry` | `px4_msgs/msg/VehicleOdometry` |
