---
title: "Step 4: Shell Environment & Paths"
aliases: [Shell Environment, Environment Paths, Gazebo Paths Setup, PX4 Environment Variables]
tags: [simulation, environment, bash, zsh, configuration, px4, ros2, gazebo]
created: 2026-09-30
updated: 2026-10-16
status: stable
---

# Step 4: Configure Shell Environment & Launch Automation

[[03 - Micro XRCE-DDS & ROS 2 Setup|← Previous: Step 3 - Micro XRCE-DDS & ROS 2 Setup]] | [[Robotics Simulation Pipeline|Pipeline MOC]] | [[05 - QGroundControl Setup|Next: Step 5 - QGroundControl Setup →]]

---

## 📌 Overview

The **PX4 + Gazebo Harmonic + ROS 2** simulation stack requires specific environment variables to discover:
- Physics engine plugins (Bullet Featherstone on Arch Linux).
- Model and world definitions for Gazebo Sim.
- Vehicle spawn orientation (ground elevation and heading alignment).
- Viewport camera tracking behavior (`PX4_GZ_FOLLOW`).
- Autonomous CLI utilities in `~/.local/bin` (`MicroXRCEAgent`, `px4-teleop`, `ros2-shell`).

> [!note] Automated vs Manual Configuration
> The unified launcher script [`../../installed gigs/start_sim.sh`](../../installed%20gigs/start_sim.sh) (documented in [[Quick Reference & Launch Script]]) automatically sets and exports all required environment variables within each `tmux` pane. Adding them to your `~/.bashrc` or `~/.zshrc` is recommended if you wish to run components individually from standalone terminals.

---

## ⚙️ Environment Variables Reference

| Variable | Recommended Value | Purpose |
| :--- | :--- | :--- |
| **`PATH`** | `$HOME/.local/bin:$PATH` | Grants global access to `MicroXRCEAgent`, `px4-teleop`, and `ros2-shell`. |
| **`GZ_SIM_PHYSICS_ENGINE_PATH`** | `/usr/lib/gz-physics-7/engine-plugins` | Enables Bullet Featherstone (`gz-physics-bullet-featherstone-plugin`) on Arch Linux. |
| **`PX4_GZ_MODEL_POSE`** | `"0,0,0.24,0,0,-1.5707963"` | Spawns vehicle with 0.24m ground clearance and -90° yaw (facing North). |
| **`PX4_GZ_FOLLOW`** | `1` | Enables dynamic camera chase follow mode in Gazebo Harmonic. |
| **`GZ_SIM_RESOURCE_PATH`** | `$HOME/PX4-Autopilot/Tools/simulation/gz/models:...` | Discovers PX4 airframes (`x500`) and custom worlds (`default.sdf`). |

---

## 📝 Shell Profile Configuration

Append the following configuration block to your shell profile (`~/.bashrc` or `~/.zshrc`):

### For Bash users:
```bash
cat << 'EOF' >> ~/.bashrc

# ========================================================
# --- PX4 Autopilot + Gazebo Harmonic + ROS 2 Paths ---
# ========================================================
# 1. Custom robotics binaries and utility scripts
export PATH=$HOME/.local/bin:$PATH

# 2. Gazebo Harmonic physics engine (Bullet Featherstone for Arch Linux)
export GZ_SIM_PHYSICS_ENGINE_PATH=/usr/lib/gz-physics-7/engine-plugins:${GZ_SIM_PHYSICS_ENGINE_PATH}

# 3. Gazebo model and world discovery paths (including Modular Parts Library)
export PARTS_LIB="$HOME/Documents/PROJECTS/DC- Drone Club/Parts_library"
export GZ_SIM_RESOURCE_PATH="$PARTS_LIB:$HOME/PX4-Autopilot/Tools/simulation/gz/models:$HOME/PX4-Autopilot/Tools/simulation/gz/worlds:${GZ_SIM_RESOURCE_PATH}"
export SDF_PATH="$PARTS_LIB:${SDF_PATH:-}"

# 4. Model spawn pose: 0.24m altitude clearance, -90° yaw to align nose with Gazebo North (+Y)
export PX4_GZ_MODEL_POSE="0,0,0.24,0,0,-1.5707963"

# 5. Enable dynamic camera chase tracking
export PX4_GZ_FOLLOW=1

# 6. ROS 2 Workspace & Environment (Ubuntu Native Users)
# If running native ROS 2 on Ubuntu 22.04:
# source /opt/ros/humble/setup.bash
# if [ -f $HOME/px4_ros2_ws/install/setup.bash ]; then
#     source $HOME/px4_ros2_ws/install/setup.bash
# fi

# Note for Arch Linux users:
# ROS 2 runs via containerized wrappers in ~/.local/bin (ros2, colcon, ros2-shell)
# using host networking. Sourcing native /opt/ros is not needed on Arch.
EOF

# Reload environment immediately
source ~/.bashrc
```

### For Zsh users:
```zsh
cat << 'EOF' >> ~/.zshrc

# ========================================================
# --- PX4 Autopilot + Gazebo Harmonic + ROS 2 Paths ---
# ========================================================
export PATH=$HOME/.local/bin:$PATH
export GZ_SIM_PHYSICS_ENGINE_PATH=/usr/lib/gz-physics-7/engine-plugins:${GZ_SIM_PHYSICS_ENGINE_PATH}
export PARTS_LIB="$HOME/Documents/PROJECTS/DC- Drone Club/Parts_library"
export GZ_SIM_RESOURCE_PATH="$PARTS_LIB:$HOME/PX4-Autopilot/Tools/simulation/gz/models:$HOME/PX4-Autopilot/Tools/simulation/gz/worlds:${GZ_SIM_RESOURCE_PATH}"
export SDF_PATH="$PARTS_LIB:${SDF_PATH:-}"
export PX4_GZ_MODEL_POSE="0,0,0.24,0,0,-1.5707963"
export PX4_GZ_FOLLOW=1
EOF

# Reload environment immediately
source ~/.zshrc
```

---

## ✅ Path & Environment Validation Check

Verify that your current shell environment has registered the variables and binaries correctly:

```bash
echo "Physics Path: $GZ_SIM_PHYSICS_ENGINE_PATH"
echo "Model Pose:   $PX4_GZ_MODEL_POSE"
echo "Follow Mode:  $PX4_GZ_FOLLOW"
which MicroXRCEAgent px4-teleop
```

**Expected output:**
```plaintext
Physics Path: /usr/lib/gz-physics-7/engine-plugins:
Model Pose:   0,0,0.24,0,0,-1.5707963
Follow Mode:  1
/home/<user>/.local/bin/MicroXRCEAgent
/home/<user>/.local/bin/px4-teleop
```

---

## ⏭️ Next Step

Proceed to [[05 - QGroundControl Setup|Step 5: Install QGroundControl (Virtual Telemetry & RC)]].
