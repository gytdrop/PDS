---
title: Quick Reference & Launch Script
aliases: [Launch Script, Simulation Cheat Sheet, Fast Reference]
tags: [simulation, script, bash, cheat-sheet, automation]
created: 2026-09-30
status: stable
---

# Simulation Pipeline: Quick Reference & Launch Automation

[[06 - Smoke Test & Flight Verification (ArduPilot)|Previous: Step 6 - Smoke Test (ArduPilot)]] | [[README|Old Stack Archive]] | [[Robotics Simulation Pipeline|Pipeline MOC]]

---

## ⚡ Fast Command Cheat Sheet

### Terminal 1: Physics World (Gazebo)
```bash
gz sim -v4 -r iris_runway.sdf
```

### Terminal 2: Autopilot (ArduPilot SITL)
```bash
cd ~/ardupilot/ArduCopter
sim_vehicle.py -v ArduCopter -f gazebo-iris --model JSON --map --console
```

### Terminal 3: Ground Station (QGroundControl)
```bash
~/QGroundControl.AppImage
```

### MAVProxy In-Flight Commands:
```plaintext
mode guided         # Switch to Guided autonomous mode
arm throttle        # Arm motors
takeoff 5           # Take off and hold at 5 meters altitude
mode rtl            # Return to Launch and land
mode land           # Land in place immediately
disarm              # Disarm motors (on ground)
```

---

## 📜 All-in-One Tmux Launch Script

Instead of manually configuring three terminal tabs each time, use this script (`start_sim.sh`) to launch the entire stack inside a structured `tmux` session:

```bash
#!/usr/bin/env bash
# ==============================================================================
# Drone Club - Autonomous Simulation Pipeline Launcher (Tmux)
# ==============================================================================

SESSION="drone_sim"

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "tmux is not installed. Install via: sudo apt install tmux (or sudo pacman -S tmux)"
    exit 1
fi

# Kill existing session if running
tmux kill-session -t $SESSION 2>/dev/null

# Create new detached tmux session running Gazebo
tmux new-session -d -s $SESSION -n "Gazebo" "gz sim -v4 -r iris_runway.sdf"

# Split window horizontally for ArduPilot SITL
tmux split-window -h -t $SESSION:0 "cd ~/ardupilot/ArduCopter && sim_vehicle.py -v ArduCopter -f gazebo-iris --model JSON --map --console"

# Split lower-right pane for QGroundControl
tmux split-window -v -t $SESSION:0.1 "~/QGroundControl.AppImage"

# Attach to tmux session
tmux attach-session -t $SESSION
```

### How to use the script:
1. Save the script to `~/start_sim.sh`
2. Make it executable: `chmod +x ~/start_sim.sh`
3. Launch with: `./start_sim.sh`
4. To detach from tmux: Press `Ctrl + B`, then press `D`.
5. To re-attach: Run `tmux attach -t drone_sim`.

---

## 🛠️ Common Troubleshooting

| Symptom | Cause | Solution |
| :--- | :--- | :--- |
| `sim_vehicle.py: command not found` | `$PATH` not updated | Add `export PATH=$HOME/ardupilot/Tools/autotest:$PATH` to `~/.bashrc` and run `source ~/.bashrc`. |
| Gazebo can't find `iris_runway.sdf` or Iris model | `GZ_SIM_RESOURCE_PATH` missing | Ensure `GZ_SIM_RESOURCE_PATH=$HOME/ardupilot_gazebo/models:$HOME/ardupilot_gazebo/worlds:$GZ_SIM_RESOURCE_PATH` is exported in your shell. |
| ArduPilot sits waiting for Gazebo connection | Port conflict or plugin not compiled | Check that `libArduPilotPlugin.so` is in `~/ardupilot_gazebo/build/` and `GZ_SIM_SYSTEM_PLUGIN_PATH` points there. |
| MAVLink fails to connect in QGC | `ModemManager` serial capture | Remove or stop ModemManager: `sudo apt remove modemmanager` or `sudo systemctl stop ModemManager`. |
| EKF fails to acquire GPS | Simulation paused or time not stepping | Ensure Gazebo is running unpaused (`gz sim -r ...`). Check Gazebo play button is active. |

---

## 🔗 Related Notes
- [[Robotics Simulation Pipeline|Simulation Pipeline MOC]]
- [[01 - ArduPilot SITL Setup]]
- [[02 - Gazebo Harmonic Setup]]
- [[03 - ardupilot_gazebo Plugin]]
- [[04 - Shell Environment & Paths]]
- [[05 - QGroundControl Setup]]
- [[06 - Smoke Test & Flight Verification]]
