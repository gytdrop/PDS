---
title: "Step 2: Gazebo Harmonic Setup & Physics Stabilization"
aliases: [Gazebo Harmonic Setup, Gazebo Sim, Gazebo Harmonic, Gazebo Physics Tuning, Gazebo Orientation]
tags: [simulation, gazebo, gz-harmonic, robotics, setup, physics, px4, bullet-featherstone]
created: 2026-09-30
updated: 2026-10-16
status: stable
---

# Step 2: Gazebo Sim (Harmonic) Setup & Physics Stabilization

[[01 - PX4 Autopilot SITL Setup|← Previous: Step 1 - PX4 Autopilot SITL Setup]] | [[Robotics Simulation Pipeline|Pipeline MOC]] | [[03 - Micro XRCE-DDS & ROS 2 Setup|Next: Step 3 - Micro XRCE-DDS & ROS 2 Setup →]]

---

## 📌 Overview

**Gazebo Harmonic** (`gz-harmonic`, release 8) is the modern LTS generation of the Open Source Robotics Foundation (OSRF) simulation suite. In our autonomous drone stack, Gazebo Harmonic acts as the physical environment simulation engine, providing:
- High-fidelity multi-body rigid physics via the **Bullet Featherstone** engine.
- Comprehensive simulated avionics sensor suite (IMU, barometer, GPS, magnetometer).
- Native lockstep clock synchronization directly with **PX4 Autopilot (v1.17)** via `gz-transport` (no third-party plugins required).
- Dynamic third-person chase camera tracking and viewport orientation.

---

## 📦 Distribution Installation

### On Ubuntu 22.04 LTS (Jammy) / 24.04 LTS (Noble)

Ubuntu packages are maintained in the official OSRF APT repositories:

```bash
# 1. Install repository prerequisites
sudo apt update && sudo apt install -y curl lsb-release gnupg

# 2. Add the official OSRF repository signing key
sudo curl https://packages.osrfoundation.org/gazebo.gpg \
    --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg

# 3. Add the OSRF APT source list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null

# 4. Update repository lists & install Gazebo Harmonic
sudo apt update
sudo apt install -y gz-harmonic libgz-sim8-dev rapidjson-dev \
    libopencv-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl
```

### On Arch Linux / Manjaro

On Arch Linux, core libraries are installed via `pacman`, and `gz-harmonic` is installed via AUR:

```bash
# 1. Install development tools and multimedia libraries
sudo pacman -S --needed base-devel cmake git rapidjson opencv gstreamer gst-plugins-base gst-plugins-bad

# 2. Install Gazebo Harmonic from the Arch User Repository (AUR)
yay -S gz-harmonic
```

---

## ⚙️ Physics Engine Configuration (Bullet Featherstone)

Gazebo Sim defaults to DART (`gz-physics-dartsim-plugin`), which is not bundled by default on Arch Linux. On Arch Linux, `gz-physics7` ships with **Bullet Featherstone** (`gz-physics-bullet-featherstone-plugin`), which provides superior multi-body kinematic stability for multirotors.

### 1. Export Plugin Discovery Path:
Add the engine plugin path to your shell environment or launch scripts:
```bash
export GZ_SIM_PHYSICS_ENGINE_PATH=/usr/lib/gz-physics-7/engine-plugins:${GZ_SIM_PHYSICS_ENGINE_PATH}
```

### 2. PX4 SITL Engine Loading:
PX4's startup script (`ROMFS/px4fmu_common/init.d-posix/px4-rc.gzsim`) automatically queries `GZ_SIM_PHYSICS_ENGINE_PATH` and loads `libgz-physics-bullet-featherstone-plugin.so` when starting `gz sim`.

---

## 🌍 World Ground Plane & Contact Physics Tuning

Unstable touchdowns, skid vibration, and landing bounce in Gazebo are caused by improper ground collision boundaries and elastic contact stiffness.

In `~/PX4-Autopilot/Tools/simulation/gz/worlds/default.sdf`, configure the ground plane as follows:

```xml
<model name="ground_plane">
  <static>true</static>
  <link name="link">
    <!-- Enlarged Collision Geometry to Match Visual Extents -->
    <collision name="collision">
      <geometry>
        <plane>
          <normal>0 0 1</normal>
          <size>500 500</size> <!-- Sized to 500x500m (replaces legacy 1x1m box) -->
        </plane>
      </geometry>
      <surface>
        <contact>
          <ode>
            <!-- High stiffness & minimal penetration tolerance prevent landing rebound -->
            <kp>100000000.0</kp>  <!-- 1e8 stiffness -->
            <kd>1.0</kd>          <!-- Damping -->
            <min_depth>0.005</min_depth>
          </ode>
        </contact>
        <friction>
          <ode>
            <mu>1.0</mu>
            <mu2>1.0</mu2>
          </ode>
        </friction>
      </surface>
    </collision>
    <visual name="visual">
      <geometry>
        <plane>
          <normal>0 0 1</normal>
          <size>500 500</size>
        </plane>
      </geometry>
      <material>
        <ambient>0.8 0.8 0.8 1</ambient>
        <diffuse>0.8 0.8 0.8 1</diffuse>
        <specular>0.8 0.8 0.8 1</specular>
      </material>
    </visual>
  </link>
</model>
```

> [!important] Why Ground Plane Tuning Matters
> - **Collision Boundary**: The default world visual plane was 500m $\times$ 500m, but the collision plane was set to `<size>1 1</size>`. Any landing or taxiing further than 0.5m from the origin fell off the physical edge, resulting in erratic physics impulses ($z \approx 0.74\text{m}$).
> - **Contact Stiffness (`kp=1e8`, `min_depth=0.005`)**: Eliminates micro-penetration into the ground, stopping skid jitter and flipping during landing.

---

## 🧭 Vehicle Spawn Orientation & Camera Tracking

### 1. Coordinate Frame Alignment (ENU vs NED)
- **Gazebo Sim** uses the standard East-North-Up (**ENU**) frame: $+X = \text{East}$, $+Y = \text{North}$, $+Z = \text{Up}$.
- **PX4 Autopilot** uses the standard North-East-Down (**NED**) aerospace frame: $+X = \text{North}$, $+Y = \text{East}$, $+Z = \text{Down}$.

To ensure the drone spawns facing **North** (along Gazebo's $+Y$ axis) with its skids resting squarely on the ground plane:
```bash
# Export vehicle spawn pose in start_sim.sh:
export PX4_GZ_MODEL_POSE="0,0,0.24,0,0,-1.5707963"
```
- Elevation `z = 0.24m`: Avoids intersecting the ground plane at spawn.
- Yaw $\psi = -1.5707963\text{ rad}$ ($-90^\circ$): Rotates the vehicle body nose directly towards compass North.

### 2. Base Model Default Pose
In `~/PX4-Autopilot/Tools/simulation/gz/models/x500_base/model.sdf`:
```xml
<model name="x500_base">
  <pose>0 0 .24 0 0 -1.5707963</pose>
  ...
</model>
```

### 3. Dynamic Camera Follow Mode (`PX4_GZ_FOLLOW`)
To have Gazebo's 3D viewport automatically track and follow the drone throughout its flight:
```bash
# Enable camera chase follow mode:
export PX4_GZ_FOLLOW=1
```
When enabled, Gazebo binds the viewport camera to the drone's position, maintaining a steady third-person perspective during climb, translation, and landing.

### 4. User Viewport Default Camera Pose
In `~/PX4-Autopilot/Tools/simulation/gz/worlds/default.sdf`, configure the default observer camera to look North from behind the spawn position:
```xml
<gui fullscreen='0'>
  <camera name='user_camera'>
    <!-- Positioned 5m South of drone, 2m high, pitched 0.2 rad down, facing North (+Y) -->
    <pose>0 -5 2 0 0.2 1.5707963</pose>
    <view_controller>orbit</view_controller>
    <projection_type>perspective</projection_type>
  </camera>
</gui>
```

---

## 🚫 Model Selection: Avoiding Collision Overlap

> [!caution] Do Not Use `gz_x500_depth` as the Default Model
> - In `x500_depth/model.sdf`, the `OakD-Lite` camera collision bounding box directly intersects the airframe `base_link` collision mesh.
> - Under Bullet Featherstone physics, overlapping collision bodies produce severe instantaneous contact forces on initial spawn, throwing the drone into the air and flipping it upside down (`Pose: RPY [3.14, 0.0, -0.93]`).
> - This triggers PX4's safety lock: `WARN [health_and_arming_checks] Preflight Fail: Attitude failure (roll)`.
> - **Standard model:** Always use **`gz_x500`**, which spawns perfectly level (`Roll: 0.0, Pitch: 0.0, Yaw: 0.0`).
> - **Modular Architecture:** Alternatively, use the discrete **`modular_drone`** from `Parts_library/`, which isolates the `chassis`, `t_motor_f60` actuators, and `livox_mid360` with proper physical offset clearances and zero collision overlap. See [[09 - Modular Drone & Parts Library Setup|Step 9: Modular Drone & Parts Library Architecture]].

---

## ✅ Verification: Run Standalone & SITL Tests

### 1. Test Standalone Gazebo GUI
Verify that Gazebo's rendering engine and graphical interface start cleanly:
```bash
gz sim -v4 shapes.sdf
```
*(A window will open rendering basic 3D shapes. Close it once verified.)*

### 2. Test Pure PX4 SITL + Gazebo Launch
Verify that PX4 and Gazebo boot together and report preflight health:
```bash
cd ~/PX4-Autopilot
make px4_sitl gz_x500
```
In the `pxh>` shell:
```text
pxh> commander check
INFO  [commander] Preflight check: OK
```
In a separate terminal, check the model pose:
```bash
gz model -m x500_0 -p
```
**Expected Pose Output:**
`Pose: [0.00, 0.00, 0.24] RPY: [0.00, 0.00, -1.57]` (Upright, level, facing North).

---

## ⏭️ Next Step

Proceed to [[03 - Micro XRCE-DDS & ROS 2 Setup|Step 3: Micro XRCE-DDS Middleware & ROS 2 Autonomy Setup]].
