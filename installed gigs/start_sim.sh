#!/usr/bin/env bash
# ==============================================================================
# Drone Club - Optimized Autonomous PX4 + ROS 2 Simulation Stack Launcher
# Integrates Gazebo Harmonic, PX4 SITL, Micro XRCE-DDS Agent, and ROS 2
# ==============================================================================

set -eo pipefail

SESSION="drone_sim"
HEADLESS=false
LAUNCH_QGC=true
MODEL="gz_x500"

# ------------------------------------------------------------------------------
# Help & Usage
# ------------------------------------------------------------------------------
show_help() {
    cat << EOF
🛸 Drone Club Simulation Launcher (PX4 + ROS 2 Edition)

Usage: $(basename "$0") [OPTIONS]

Options:
  -h, --help         Show this help message and exit
  -s, --headless     Run Gazebo in headless mode (server physics only, no 3D GUI)
  --gui              Run Gazebo with interactive 3D GUI (default)
  -m, --model MODEL  PX4 SITL Gazebo model (default: gz_x500, options: gz_x500, gz_x500_depth, gz_x500_lidar, modular_drone)
  --no-qgc           Do not launch QGroundControl
  --kill, -k         Terminate all running simulation processes, agents, and tmux sessions
  --status           Display status of simulation background processes and network ports

Examples:
  ./start_sim.sh                        # Standard launch: MicroXRCEAgent + PX4 SITL + QGC
  ./start_sim.sh --headless             # Headless physics + MicroXRCEAgent + ROS 2 shell
  ./start_sim.sh -m gz_x500_depth       # Quadcopter with OakD depth camera
  ./start_sim.sh --kill                 # Stop and cleanup simulation stack
EOF
}

# ------------------------------------------------------------------------------
# Process Status & Cleanup
# ------------------------------------------------------------------------------
kill_sim() {
    echo "🛑 Terminating all Drone Club simulation processes..."
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    pkill -9 -f "MicroXRCEAgent" 2>/dev/null || true
    pkill -9 -f "px4" 2>/dev/null || true
    pkill -9 -f "gz sim" 2>/dev/null || true
    pkill -9 -i -f "qgroundcontrol" 2>/dev/null || true
    sleep 1
    echo "✅ Simulation stack stopped and ports released."
}

show_status() {
    echo "======================================================"
    echo "🛸 Drone Club Simulation Process Status (PX4 + ROS 2):"
    echo "======================================================"
    local dds_pids=$(pgrep -f "MicroXRCEAgent" || true)
    local px4_pids=$(pgrep -f "px4" || true)
    local gz_pids=$(pgrep -f "gz sim" || true)
    local qgc_pids=$(pgrep -i -f "qgroundcontrol" || true)
    local tmux_active=$(tmux has-session -t "$SESSION" 2>/dev/null && echo "Active" || echo "Inactive")

    echo "Tmux Session ($SESSION): $tmux_active"
    echo "Micro XRCE-DDS Agent:    ${dds_pids:-Not running}"
    echo "PX4 Autopilot SITL:      ${px4_pids:-Not running}"
    echo "Gazebo Sim:              ${gz_pids:-Not running}"
    echo "QGroundControl:          ${qgc_pids:-Not running}"
    echo "------------------------------------------------------"
    echo "Listening Ports Check:"
    ss -tulpn 2>/dev/null | grep -E "8888|14550|14540" || echo "No simulation ports currently bound."
    echo "======================================================"
}

# ------------------------------------------------------------------------------
# Parse CLI Arguments
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--headless)
            HEADLESS=true
            LAUNCH_QGC=false
            shift
            ;;
        --gui)
            HEADLESS=false
            shift
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        --no-qgc)
            LAUNCH_QGC=false
            shift
            ;;
        -k|--kill)
            kill_sim
            exit 0
            ;;
        --status)
            show_status
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Environment Validation
# ------------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"

if ! command -v tmux &> /dev/null; then
    echo "❌ tmux is required for multi-pane execution."
    exit 1
fi

if ! command -v gz &> /dev/null; then
    echo "❌ Gazebo (gz) not found in PATH."
    exit 1
fi

if ! command -v MicroXRCEAgent &> /dev/null; then
    echo "⚠️ MicroXRCEAgent not found in PATH ($PATH)."
    echo "   Ensure Micro-XRCE-DDS-Agent is installed in ~/.local/bin or /usr/local/bin."
fi

# Clean up any lingering processes
kill_sim >/dev/null 2>&1 || true

echo "======================================================"
echo "🛸 Drone Club: Starting PX4 + ROS 2 Simulation Stack..."
echo "Model: $MODEL"
echo "Mode:  $([ "$HEADLESS" = true ] && echo "HEADLESS (Physics Server)" || echo "GUI (Interactive 3D)")"
echo "======================================================"

# Determine headless environment variable
HEADLESS_ENV=""
if [ "$HEADLESS" = true ]; then
    HEADLESS_ENV="HEADLESS=1"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROS2_WS="${ROS2_WS:-$HOME/px4_ros2_ws}"
PX4_DIR="${PX4_DIR:-$HOME/PX4-Autopilot}"

# Resolve SITL target and spawn pose
if [[ "$MODEL" == *"modular"* ]]; then
    SITL_TARGET="gz_modular_drone"
    SPAWN_POSE="0,0,0.24,0,0,0"
elif [[ "$MODEL" != gz_* ]]; then
    SITL_TARGET="gz_${MODEL}"
    SPAWN_POSE="0,0,0.24,0,0,-1.5707963"
else
    SITL_TARGET="$MODEL"
    SPAWN_POSE="0,0,0.24,0,0,-1.5707963"
fi

# Environment exports for tmux panes (North-aligned spawn, camera follow, physics engine, modular library paths)
ENV_EXPORTS="export PATH=$HOME/.local/bin:\$PATH && export LD_LIBRARY_PATH=$HOME/.local/lib:\${LD_LIBRARY_PATH:-} && export DISPLAY=${DISPLAY} && export WAYLAND_DISPLAY=${WAYLAND_DISPLAY} && export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR} && export QT_QPA_PLATFORM=xcb && export GZ_SIM_PHYSICS_ENGINE_PATH=/usr/lib/gz-physics-7/engine-plugins:\${GZ_SIM_PHYSICS_ENGINE_PATH:-} && export PX4_GZ_PHYSICS_ENGINE=gz-physics-bullet-featherstone-plugin && export GZ_SIM_RESOURCE_PATH=\"$PROJECT_DIR/Parts_library:\${GZ_SIM_RESOURCE_PATH:-}\" && export SDF_PATH=\"$PROJECT_DIR/Parts_library:\${SDF_PATH:-}\" && export PX4_GZ_MODEL_POSE=\"$SPAWN_POSE\" && export PX4_GZ_FOLLOW=1 && export PX4_GZ_FOLLOW_OFFSET_X=0.0 && export PX4_GZ_FOLLOW_OFFSET_Y=2.5 && export PX4_GZ_FOLLOW_OFFSET_Z=1.2"

# ------------------------------------------------------------------------------
# Create Structured Tmux Layout
# ------------------------------------------------------------------------------
# Layout:
# +---------------------------+---------------------------+
# |                           | Pane 1: PX4 SITL & Gazebo |
# | Pane 0: Micro XRCE Agent  | make px4_sitl $MODEL      |
# | (UDP 8888 uORB bridge)    +---------------------------+
# |                           | Pane 2: ROS 2 Autonomy    |
# |                           | (px4_ros_com offboard)    |
# +---------------------------+---------------------------+

tmux set-environment -g DISPLAY "$DISPLAY" 2>/dev/null || true
tmux set-environment -g WAYLAND_DISPLAY "$WAYLAND_DISPLAY" 2>/dev/null || true
tmux set-environment -g XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR" 2>/dev/null || true

# 1. Pane 0: Launch Micro XRCE-DDS Agent
tmux new-session -d -s "$SESSION" -n "Simulation" \
    "bash -c '$ENV_EXPORTS && echo \"[DDS] Starting Micro XRCE-DDS Agent on UDP port 8888...\" && MicroXRCEAgent udp4 -p 8888; exec bash'"

# 2. Pane 1: Launch PX4 SITL with Gazebo Harmonic
tmux split-window -h -t "$SESSION:0.0" \
    "bash -c '$ENV_EXPORTS && sleep 2 && cd \"$PX4_DIR\" && echo \"[PX4] Launching SITL ($SITL_TARGET)...\" && $HEADLESS_ENV make px4_sitl $SITL_TARGET; exec bash'"

# 3. Pane 2: ROS 2 Autonomy Workspace Shell
tmux split-window -v -t "$SESSION:0.1" \
    "bash -c '$ENV_EXPORTS && cd \"$ROS2_WS\"; echo \"======================================================\" && echo \"🛸 Drone Club ROS 2 Autonomy Shell Ready!\" && echo \"- Fly with Keyboard:   px4-teleop\" && echo \"- Auto Takeoff & Land: ros2 run px4_ros_com offboard_control.py\" && echo \"- Check live topics:   ros2 topic list\" && echo \"- Interactive shell:   ros2-shell\" && echo \"======================================================\" && exec bash'"

# Adjust pane split proportions (40% left for DDS agent, 60% right for PX4 & ROS2)
tmux resize-pane -t "$SESSION:0.0" -x 40%

# 4. Launch QGroundControl as detached background GUI application if enabled
if [ "$LAUNCH_QGC" = true ] && [ -n "${DISPLAY:-$WAYLAND_DISPLAY}" ]; then
    if [ -x "$HOME/QGroundControl.AppImage" ]; then
        nohup setsid bash -c "$ENV_EXPORTS && sleep 5 && '$HOME/QGroundControl.AppImage'" </dev/null >/tmp/qgc.log 2>&1 &
        echo "📡 QGroundControl launched in background."
    else
        echo "⚠️ QGroundControl.AppImage not found at ~/QGroundControl.AppImage"
    fi
fi

echo "✅ Simulation successfully initialized!"
if [ -t 0 ] && [ "$TERM" != "dumb" ] && [ -n "$TERM" ]; then
    echo "Attaching to tmux session (Press 'Ctrl + B' then 'D' to detach)..."
    sleep 1
    tmux attach-session -t "$SESSION" || true
else
    echo "Launched in background. To attach to the simulation session, run:"
    echo "  tmux attach -t $SESSION"
fi
