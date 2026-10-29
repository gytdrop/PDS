---
title: "Step 4: Shell Environment & Paths"
aliases: [Shell Environment, Environment Paths, Gazebo Paths Setup]
tags: [simulation, environment, bash, zsh, configuration]
created: 2026-09-30
status: stable
---

# Step 4: Configure Shell Environment Paths

[[03 - ardupilot_gazebo Plugin|← Previous: Step 3 - ardupilot_gazebo Plugin]] | [[Robotics Simulation Pipeline|Pipeline MOC]] | [[05 - QGroundControl Setup|Next: Step 5 - QGroundControl Setup →]]

---

## 📌 Overview

Gazebo Sim discovers third-party plugins, SDF world definitions, and vehicle 3D mesh models via specific environment variables:
- `GZ_VERSION`: Declares the Gazebo generation (`harmonic`).
- `GZ_SIM_SYSTEM_PLUGIN_PATH`: Path where Gazebo looks for dynamic plugin libraries (`libArduPilotPlugin.so`).
- `GZ_SIM_RESOURCE_PATH`: Search directories for drone SDF models (e.g. `iris_with_ardupilot`, `gimbal_small_2d`) and simulation worlds (`iris_runway.sdf`, `runway.sdf`).

---

## ⚙️ Configuration Setup

Append the configuration block to your shell profile (`~/.bashrc` or `~/.zshrc`):

### For Bash users:
```bash
cat << 'EOF' >> ~/.bashrc

# ========================================================
# --- ArduPilot + Gazebo Harmonic Simulation Paths ---
# ========================================================
export GZ_VERSION=harmonic
export GZ_SIM_SYSTEM_PLUGIN_PATH=$HOME/ardupilot_gazebo/build:${GZ_SIM_SYSTEM_PLUGIN_PATH}
export GZ_SIM_RESOURCE_PATH=$HOME/ardupilot_gazebo/models:$HOME/ardupilot_gazebo/worlds:${GZ_SIM_RESOURCE_PATH}
EOF

# Reload environment immediately
source ~/.bashrc
```

### For Zsh users:
```zsh
cat << 'EOF' >> ~/.zshrc

# ========================================================
# --- ArduPilot + Gazebo Harmonic Simulation Paths ---
# ========================================================
export GZ_VERSION=harmonic
export GZ_SIM_SYSTEM_PLUGIN_PATH=$HOME/ardupilot_gazebo/build:${GZ_SIM_SYSTEM_PLUGIN_PATH}
export GZ_SIM_RESOURCE_PATH=$HOME/ardupilot_gazebo/models:$HOME/ardupilot_gazebo/worlds:${GZ_SIM_RESOURCE_PATH}
EOF

# Reload environment immediately
source ~/.zshrc
```

---

## ✅ Path Validation Check

Verify that your current shell environment has registered the variables correctly:

```bash
echo "Plugin Path:   $GZ_SIM_SYSTEM_PLUGIN_PATH"
echo "Resource Path: $GZ_SIM_RESOURCE_PATH"
```

**Expected output:**
```plaintext
Plugin Path:   /home/<user>/ardupilot_gazebo/build:
Resource Path: /home/<user>/ardupilot_gazebo/models:/home/<user>/ardupilot_gazebo/worlds:
```

> [!tip] New Terminals
> Any newly opened terminal tabs or windows will automatically inherit these settings.

---

## ⏭️ Next Step

Proceed to [[05 - QGroundControl Setup|Step 5: Install QGroundControl (Virtual Telemetry & RC)]].
