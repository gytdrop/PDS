#!/usr/bin/env bash
# ==============================================================================
# 🛸 Drone Club: Automated Linux Environment & Modular Drone Setup / Doctor
# Supports: Arch Linux, Manjaro, Ubuntu 22.04 / 24.04 LTS, Debian
# ==============================================================================

set -eo pipefail

# ------------------------------------------------------------------------------
# Terminal Color Formatting & Icons
# ------------------------------------------------------------------------------
BOLD="\033[1m"
RESET="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
MAGENTA="\033[1;35m"

log_info()    { echo -e "${CYAN}ℹ [INFO]${RESET} $*"; }
log_ok()      { echo -e "${GREEN}✔ [OK]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}⚠ [WARN]${RESET} $*"; }
log_fail()    { echo -e "${RED}✖ [FAIL]${RESET} $*"; }
log_step()    { echo -e "\n${BOLD}${MAGENTA}==>${RESET} ${BOLD}$*${RESET}"; }
log_section() { echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n${BOLD}$*${RESET}\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

# ------------------------------------------------------------------------------
# Default Flags & Paths
# ------------------------------------------------------------------------------
AUTO_FIX=false
INSTALL_DEPS=false
VALIDATE_ONLY=false
LAUNCH_PREVIEW=false
LAUNCH_FULL_SIM=false

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARTS_LIB="$PROJECT_ROOT/Parts_library"
VAULT_DIR="$PROJECT_ROOT/Drone Club DC Vault"
GIGS_DIR="$PROJECT_ROOT/installed gigs"
PX4_DIR="$HOME/PX4-Autopilot"
QGC_APPIMAGE="$HOME/QGroundControl.AppImage"

# ------------------------------------------------------------------------------
# Help & Usage
# ------------------------------------------------------------------------------
show_help() {
    echo -e "${BOLD}🛸 Drone Club: Linux System & Modular Drone Setup Tool${RESET}

Usage: $(basename "$0") [OPTIONS]

Options:
  -h, --help           Show this help message and exit
  -i, --install-deps   Install missing system dependencies via OS package manager (APT/Pacman/AUR)
  -f, --fix            Automatically fix missing symlinks, directories, airframes, and environment variables
  -a, --all            Complete end-to-end setup (runs --install-deps and --fix)
  --validate-only      Run diagnostics and exit with code 0 (pass) or 1 (fail) without prompting
  -p, --preview        Open modular drone inside standalone Gazebo Sim 3D GUI
  -l, --launch         Start full simulation stack (PX4 SITL + Gazebo Harmonic + ROS 2 + QGC)

Examples:
  ./setup_modular_drone.sh              # Run diagnostic doctor (non-destructive)
  ./setup_modular_drone.sh --fix        # Automatically fix all paths, links, airframe, and shell exports
  ./setup_modular_drone.sh --install-deps # Install OS packages for your distro (Ubuntu/Arch)
  ./setup_modular_drone.sh --all        # Turnkey install + auto-fix configuration on a fresh PC
  ./setup_modular_drone.sh --preview    # Verify and launch standalone 3D Gazebo preview"
}

# Parse Arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--install-deps)
            INSTALL_DEPS=true
            shift
            ;;
        -f|--fix)
            AUTO_FIX=true
            shift
            ;;
        -a|--all)
            INSTALL_DEPS=true
            AUTO_FIX=true
            shift
            ;;
        --validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        -p|--preview)
            LAUNCH_PREVIEW=true
            shift
            ;;
        -l|--launch)
            LAUNCH_FULL_SIM=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Tracking issue counter
TOTAL_CHECKS=0
TOTAL_PASSED=0
TOTAL_WARNINGS=0
TOTAL_ERRORS=0

check_passed() { TOTAL_CHECKS=$((TOTAL_CHECKS + 1)); TOTAL_PASSED=$((TOTAL_PASSED + 1)); log_ok "$1"; }
check_warn()   { TOTAL_CHECKS=$((TOTAL_CHECKS + 1)); TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1)); log_warn "$1"; }
check_fail()   { TOTAL_CHECKS=$((TOTAL_CHECKS + 1)); TOTAL_ERRORS=$((TOTAL_ERRORS + 1)); log_fail "$1"; }

# ------------------------------------------------------------------------------
# 1. OS & Distribution Detection
# ------------------------------------------------------------------------------
log_section "🐧 1. Linux Operating System & Host Environment"

OS_ID="unknown"
OS_NAME="Linux"
OS_VERSION=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-$NAME}"
    OS_VERSION="${VERSION_ID:-}"
fi

log_info "Detected OS: ${BOLD}$OS_NAME${RESET} (Family: $OS_ID, Kernel: $(uname -r), Arch: $(uname -m))"
log_info "Working Directory: ${BOLD}$PROJECT_ROOT${RESET}"

case "$OS_ID" in
    arch|manjaro|endeavouros)
        check_passed "Supported distribution detected (Arch Linux family)"
        PKG_INSTALL_CMD="yay -S --needed"
        PHYSICS_PLUGIN_PATH="/usr/lib/gz-physics-7/engine-plugins/libgz-physics-bullet-featherstone-plugin.so"
        RECOMMENDED_PHYSICS="gz-physics-bullet-featherstone-plugin"
        ;;
    ubuntu|debian|pop)
        check_passed "Supported distribution detected (Debian/Ubuntu family: $OS_NAME)"
        PKG_INSTALL_CMD="sudo apt update && sudo apt install -y"
        PHYSICS_PLUGIN_PATH="/usr/lib/x86_64-linux-gnu/gz-physics-7/engine-plugins/libgz-physics-bullet-featherstone-plugin.so"
        RECOMMENDED_PHYSICS="gz-physics-bullet-featherstone-plugin"
        ;;
    *)
        check_warn "Generic Linux ($OS_NAME). Core checks will proceed, but automated package suggestions may vary."
        PKG_INSTALL_CMD="echo 'Please install via your package manager:'"
        PHYSICS_PLUGIN_PATH=""
        RECOMMENDED_PHYSICS="gz-physics-bullet-featherstone-plugin"
        ;;
esac

# ------------------------------------------------------------------------------
# 1.1 Automated Package & Prerequisite Installation (Triggered via --install-deps / --all)
# ------------------------------------------------------------------------------
install_system_deps() {
    log_step "Installing system packages and simulation tools for $OS_NAME..."
    case "$OS_ID" in
        ubuntu|debian|pop)
            log_info "Updating APT packages and installing core development toolchain..."
            sudo apt update
            sudo apt install -y git build-essential cmake ninja-build ccache \
                python3-dev python3-pip python3-venv tmux curl lsb-release gnupg libfuse2

            if ! command -v gz &> /dev/null; then
                log_info "Adding official Open Robotics Gazebo repository for Ubuntu..."
                sudo curl -fsSL https://packages.osrfoundation.org/gazebo.gpg --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null
                sudo apt update
                sudo apt install -y gz-harmonic
            fi
            ;;
        arch|manjaro|endeavouros)
            log_info "Installing core toolchain via pacman..."
            sudo pacman -S --needed git base-devel cmake ninja ccache python python-pip tmux curl

            if ! command -v gz &> /dev/null; then
                if command -v yay &> /dev/null; then
                    log_info "Installing gz-harmonic from AUR via yay..."
                    yay -S --needed gz-harmonic
                elif command -v paru &> /dev/null; then
                    log_info "Installing gz-harmonic from AUR via paru..."
                    paru -S --needed gz-harmonic
                else
                    log_warn "AUR helper (yay/paru) not found. Please install 'gz-harmonic' from AUR."
                fi
            fi
            ;;
        *)
            log_warn "Automated package installation not implemented for generic OS '$OS_NAME'. Please install dependencies manually."
            ;;
    esac

    # Download QGroundControl if missing
    if [ ! -f "$QGC_APPIMAGE" ]; then
        log_info "Downloading QGroundControl AppImage to $QGC_APPIMAGE..."
        curl -L "https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl.AppImage" -o "$QGC_APPIMAGE"
        chmod +x "$QGC_APPIMAGE"
    fi

    # Clone PX4 if missing
    if [ ! -d "$PX4_DIR" ]; then
        log_info "Cloning PX4-Autopilot repository to $PX4_DIR..."
        git clone https://github.com/PX4/PX4-Autopilot.git "$PX4_DIR" --recursive
    fi
}

if [ "$INSTALL_DEPS" = true ]; then
    install_system_deps
fi

# ------------------------------------------------------------------------------
# 2. Core Tooling & Simulation Binaries
# ------------------------------------------------------------------------------
log_section "🛠️ 2. Core Tooling & Simulation Binaries"

# Gazebo Sim Check
if command -v gz &> /dev/null; then
    GZ_VER=$(gz sim --versions 2>/dev/null | head -n 1 || gz sim --version 2>/dev/null | head -n 1 || echo "unknown")
    if echo "$GZ_VER" | grep -E "8\.|Harmonic" &> /dev/null; then
        check_passed "Gazebo Sim Harmonic installed: ${BOLD}$GZ_VER${RESET}"
    else
        check_warn "Gazebo Sim found ($GZ_VER), recommended LTS is Gazebo Harmonic (gz-sim8)."
    fi
else
    check_fail "Gazebo CLI (gz) not found in PATH."
    log_info "  Install via: ${CYAN}$PKG_INSTALL_CMD gz-harmonic${RESET}"
fi

# Physics Engine Plugin Check
if [ -n "$PHYSICS_PLUGIN_PATH" ] && [ -f "$PHYSICS_PLUGIN_PATH" ]; then
    check_passed "Bullet Featherstone physics plugin found: $(basename "$PHYSICS_PLUGIN_PATH")"
else
    # Fallback search
    FOUND_BULLET=$(find /usr/lib -name "libgz-physics-bullet-featherstone-plugin.so" 2>/dev/null | head -n 1 || true)
    if [ -n "$FOUND_BULLET" ]; then
        check_passed "Bullet Featherstone physics plugin located at: $FOUND_BULLET"
    else
        check_warn "Bullet Featherstone plugin not found at default location. DART or system default will be used."
    fi
fi

# PX4 Autopilot Source Tree Check
if [ -d "$PX4_DIR" ]; then
    check_passed "PX4-Autopilot repository found at: ${BOLD}$PX4_DIR${RESET}"
    if [ -d "$PX4_DIR/Tools/simulation/gz/models" ]; then
        check_passed "PX4 Gazebo model directory verified."
    fi
else
    check_fail "PX4-Autopilot directory not found at $PX4_DIR"
    log_info "  Clone via: ${CYAN}git clone https://github.com/PX4/PX4-Autopilot.git ~/PX4-Autopilot --recursive${RESET}"
fi

# Micro XRCE-DDS Agent Check
if command -v MicroXRCEAgent &> /dev/null || [ -x "$HOME/.local/bin/MicroXRCEAgent" ]; then
    check_passed "MicroXRCEAgent binary detected in PATH / ~/.local/bin"
else
    check_fail "MicroXRCEAgent not found. Required for uORB <-> ROS 2 communication (UDP port 8888)."
fi

# ------------------------------------------------------------------------------
# Auto-Provision ~/.local/bin Wrappers (ros2, px4-teleop, ros2-shell)
# ------------------------------------------------------------------------------
provision_local_bin_wrappers() {
    mkdir -p "$HOME/.local/bin"

    # 1. Provision ~/.local/bin/ros2 if missing
    if [ ! -f "$HOME/.local/bin/ros2" ]; then
        cat << 'EOF_ROS2' > "$HOME/.local/bin/ros2"
#!/usr/bin/env bash
# ==============================================================================
# ROS 2 Command Wrapper (Auto-detects Native Ubuntu Jazzy/Humble or Docker Fallback)
# ==============================================================================
set -e
WORKSPACE="${ROS2_WS:-$HOME/px4_ros2_ws}"

# Check for native ROS 2 installations (Ubuntu / Debian / Native Linux)
if [ -f /opt/ros/jazzy/setup.bash ]; then
    source /opt/ros/jazzy/setup.bash >/dev/null 2>&1
    [ -f "$WORKSPACE/install/setup.bash" ] && source "$WORKSPACE/install/setup.bash" >/dev/null 2>&1
    exec /opt/ros/jazzy/bin/ros2 "$@"
elif [ -f /opt/ros/humble/setup.bash ]; then
    source /opt/ros/humble/setup.bash >/dev/null 2>&1
    [ -f "$WORKSPACE/install/setup.bash" ] && source "$WORKSPACE/install/setup.bash" >/dev/null 2>&1
    exec /opt/ros/humble/bin/ros2 "$@"
elif [ -f /opt/ros/rolling/setup.bash ]; then
    source /opt/ros/rolling/setup.bash >/dev/null 2>&1
    [ -f "$WORKSPACE/install/setup.bash" ] && source "$WORKSPACE/install/setup.bash" >/dev/null 2>&1
    exec /opt/ros/rolling/bin/ros2 "$@"
elif [ -f /opt/ros/iron/setup.bash ]; then
    source /opt/ros/iron/setup.bash >/dev/null 2>&1
    [ -f "$WORKSPACE/install/setup.bash" ] && source "$WORKSPACE/install/setup.bash" >/dev/null 2>&1
    exec /opt/ros/iron/bin/ros2 "$@"
elif command -v /usr/bin/ros2 &> /dev/null; then
    [ -f "$WORKSPACE/install/setup.bash" ] && source "$WORKSPACE/install/setup.bash" >/dev/null 2>&1
    exec /usr/bin/ros2 "$@"
else
    # Fallback to Docker containerized ROS 2 Humble (Arch Linux / Container mode)
    DOCKER_TTY=""
    if [ -t 0 ] && [ -t 1 ]; then
        DOCKER_TTY="-t"
    fi
    exec docker run --rm -i $DOCKER_TTY \
        --net=host \
        --ipc=host \
        -u "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        -e ROS_HOME=/tmp/.ros \
        -e ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}" \
        -v "$WORKSPACE:$WORKSPACE" \
        -w "$WORKSPACE" \
        ros:humble-ros-base \
        bash -c 'source /opt/ros/humble/setup.bash >/dev/null 2>&1 && if [ -f "'"$WORKSPACE"'/install/setup.bash" ]; then source "'"$WORKSPACE"'/install/setup.bash" >/dev/null 2>&1; fi && exec ros2 "$@"' -- "$@"
fi
EOF_ROS2
        chmod +x "$HOME/.local/bin/ros2"
        log_ok "Auto-provisioned ROS 2 wrapper in ~/.local/bin/ros2"
    fi

    # 2. Provision ~/.local/bin/px4-teleop if missing
    if [ ! -f "$HOME/.local/bin/px4-teleop" ]; then
        cat << 'EOF_TELEOP' > "$HOME/.local/bin/px4-teleop"
#!/usr/bin/env bash
# ==============================================================================
# PX4 Interactive Keyboard Teleoperation Launcher
# Auto-detects native ROS 2 or containerized environment
# ==============================================================================
WORKSPACE="${ROS2_WS:-$HOME/px4_ros2_ws}"

# Source native ROS 2 if present
if [ -f /opt/ros/jazzy/setup.bash ]; then
    source /opt/ros/jazzy/setup.bash >/dev/null 2>&1
elif [ -f /opt/ros/humble/setup.bash ]; then
    source /opt/ros/humble/setup.bash >/dev/null 2>&1
elif [ -f /opt/ros/rolling/setup.bash ]; then
    source /opt/ros/rolling/setup.bash >/dev/null 2>&1
elif [ -f /opt/ros/iron/setup.bash ]; then
    source /opt/ros/iron/setup.bash >/dev/null 2>&1
fi

if [ -f "$WORKSPACE/install/setup.bash" ]; then
    source "$WORKSPACE/install/setup.bash" >/dev/null 2>&1
fi

if command -v ros2 &> /dev/null; then
    exec ros2 run px4_ros_com px4_teleop_key.py "$@"
elif [ -x "$HOME/.local/bin/ros2" ]; then
    exec "$HOME/.local/bin/ros2" run px4_ros_com px4_teleop_key.py "$@"
else
    echo "Error: Neither native ros2 nor ~/.local/bin/ros2 found." >&2
    exit 1
fi
EOF_TELEOP
        chmod +x "$HOME/.local/bin/px4-teleop"
        log_ok "Auto-provisioned px4-teleop launcher in ~/.local/bin/px4-teleop"
    fi

    # 3. Provision ~/.local/bin/ros2-shell if missing
    if [ ! -f "$HOME/.local/bin/ros2-shell" ]; then
        cat << 'EOF_SHELL' > "$HOME/.local/bin/ros2-shell"
#!/usr/bin/env bash
# ==============================================================================
# Interactive ROS 2 Shell for Drone Club
# ==============================================================================
WORKSPACE="${ROS2_WS:-$HOME/px4_ros2_ws}"

echo "======================================================"
echo "🛸 Drone Club: Entering Interactive ROS 2 Shell"
echo "Workspace: $WORKSPACE"
echo "Type 'exit' to return to host."
echo "======================================================"

if [ -f /opt/ros/jazzy/setup.bash ] || [ -f /opt/ros/humble/setup.bash ]; then
    cat << 'SHELLRC' > /tmp/.ros2_rc
if [ -f /opt/ros/jazzy/setup.bash ]; then
    source /opt/ros/jazzy/setup.bash
elif [ -f /opt/ros/humble/setup.bash ]; then
    source /opt/ros/humble/setup.bash
fi
if [ -f "$HOME/px4_ros2_ws/install/setup.bash" ]; then
    source "$HOME/px4_ros2_ws/install/setup.bash"
fi
export PS1="\[\033[01;32m\][ROS 2]\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\]\$ "
echo "✅ Native ROS 2 & workspace sourced successfully!"
SHELLRC
    exec bash --rcfile /tmp/.ros2_rc
else
    exec docker run --rm -it \
        --net=host \
        --ipc=host \
        -u "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        -e ROS_HOME=/tmp/.ros \
        -e ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}" \
        -v "$WORKSPACE:$WORKSPACE" \
        -w "$WORKSPACE" \
        ros:humble-ros-base \
        bash -c '
cat << "SHELLRC" > /tmp/.ros2_rc
source /opt/ros/humble/setup.bash
if [ -f install/setup.bash ]; then
    source install/setup.bash
fi
export PS1="\[\033[01;32m\][ROS 2]\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\]\$ "
echo "✅ ROS 2 Humble (Container) & workspace sourced successfully!"
echo "Commands available: ros2, colcon"
SHELLRC
exec bash --rcfile /tmp/.ros2_rc
'
fi
EOF_SHELL
        chmod +x "$HOME/.local/bin/ros2-shell"
        log_ok "Auto-provisioned ros2-shell in ~/.local/bin/ros2-shell"
    fi
}

if [ "$AUTO_FIX" = true ] || [ "$INSTALL_DEPS" = true ]; then
    provision_local_bin_wrappers
fi

# ROS 2 Tooling & Wrappers Check
if command -v ros2 &> /dev/null || [ -x "$HOME/.local/bin/ros2" ]; then
    check_passed "ROS 2 command-line interface detected"
else
    check_warn "ROS 2 CLI not detected in PATH or ~/.local/bin (Run with --fix to auto-generate)"
fi

if command -v px4-teleop &> /dev/null || [ -x "$HOME/.local/bin/px4-teleop" ]; then
    check_passed "Interactive flight teleop node (px4-teleop) available in PATH"
else
    check_warn "px4-teleop launcher not found in ~/.local/bin (Run with --fix to auto-generate)"
fi

# QGroundControl
if [ -x "$QGC_APPIMAGE" ]; then
    check_passed "QGroundControl AppImage executable found at ~/QGroundControl.AppImage"
else
    check_warn "QGroundControl AppImage not found at ~/QGroundControl.AppImage (Telemetry GUI will be skipped)"
fi

# Auxiliary CLI utilities
for tool in tmux python3 curl; do
    if command -v "$tool" &> /dev/null; then
        check_passed "System utility '$tool' is installed"
    else
        check_warn "System utility '$tool' is missing"
    fi
done

# ------------------------------------------------------------------------------
# 3. Modular Parts Library Verification & Provisioning
# ------------------------------------------------------------------------------
log_section "🧩 3. Modular Parts Library & Model Entities"

MODELS=("chassis" "t_motor_f60" "livox_mid360" "modular_drone")
MISSING_MODELS=()

for model in "${MODELS[@]}"; do
    MODEL_DIR="$PARTS_LIB/$model"
    CONFIG_FILE="$MODEL_DIR/model.config"
    SDF_FILE="$MODEL_DIR/model.sdf"

    if [ -d "$MODEL_DIR" ] && [ -f "$CONFIG_FILE" ] && [ -f "$SDF_FILE" ]; then
        check_passed "Model entity '$model' intact (model.config & model.sdf verified)"
    else
        check_fail "Model entity '$model' incomplete or missing at $MODEL_DIR"
        MISSING_MODELS+=("$model")
    fi
done

# README Verification
if [ -f "$PARTS_LIB/README.md" ]; then
    check_passed "Parts library documentation verified at Parts_library/README.md"
else
    check_warn "Parts_library/README.md missing"
fi

# ------------------------------------------------------------------------------
# 4. Model Symlinks Verification & Auto-Linking
# ------------------------------------------------------------------------------
log_section "🔗 4. Inter-Directory Symlink Resolution"

# 4.1 installed gigs/Model symlinks (Relative links for portability)
mkdir -p "$GIGS_DIR/Model"
for model in "${MODELS[@]}"; do
    TARGET_LINK="$GIGS_DIR/Model/$model"
    RELATIVE_SRC="../../Parts_library/$model"
    if [ -L "$TARGET_LINK" ] && [ -e "$TARGET_LINK" ]; then
        check_passed "Gigs Model link: $model -> $(readlink "$TARGET_LINK")"
    else
        if [ "$AUTO_FIX" = true ]; then
            ln -sfn "$RELATIVE_SRC" "$TARGET_LINK"
            check_passed "Auto-linked '$model' into 'installed gigs/Model/' (relative)"
        else
            check_warn "Missing symlink in 'installed gigs/Model/$model' (Run with --fix to resolve)"
        fi
    fi
done

# Also ensure t_motor alias exists
if [ ! -L "$GIGS_DIR/Model/t_motor" ] || [ ! -e "$GIGS_DIR/Model/t_motor" ]; then
    if [ "$AUTO_FIX" = true ]; then
        ln -sfn "../../Parts_library/t_motor_f60" "$GIGS_DIR/Model/t_motor"
        check_passed "Created relative alias 't_motor' -> 't_motor_f60' in installed gigs/Model"
    fi
fi

# 4.2 PX4-Autopilot Gazebo Models symlinks
if [ -d "$PX4_DIR/Tools/simulation/gz/models" ]; then
    for model in "${MODELS[@]}"; do
        PX4_LINK="$PX4_DIR/Tools/simulation/gz/models/$model"
        EXPECTED_SRC="$PARTS_LIB/$model"
        if [ -L "$PX4_LINK" ] && [ -e "$PX4_LINK" ]; then
            check_passed "PX4 Model link: $model -> $EXPECTED_SRC"
        else
            if [ "$AUTO_FIX" = true ]; then
                ln -sfn "$EXPECTED_SRC" "$PX4_LINK"
                check_passed "Auto-linked '$model' into '$PX4_DIR/Tools/simulation/gz/models/'"
            else
                check_warn "Missing symlink in PX4 models for '$model' (Run with --fix to resolve)"
            fi
        fi
    done
fi

# 4.3 PX4-Autopilot Airframe & SITL Target Verification
if [ -d "$PX4_DIR/ROMFS/px4fmu_common/init.d-posix/airframes" ]; then
    PX4_AIRFRAME_FILE="$PX4_DIR/ROMFS/px4fmu_common/init.d-posix/airframes/4025_gz_modular_drone"
    PX4_AIRFRAME_CMAKE="$PX4_DIR/ROMFS/px4fmu_common/init.d-posix/airframes/CMakeLists.txt"
    if [ -f "$PX4_AIRFRAME_FILE" ]; then
        check_passed "PX4 SITL Airframe verified at: 4025_gz_modular_drone"
    else
        if [ "$AUTO_FIX" = true ]; then
            cat << 'AIRFRAME_EOF' > "$PX4_AIRFRAME_FILE"
#!/bin/sh
#
# @name Gazebo Modular Drone
#
# @type Quadrotor
#

. ${R}etc/init.d/rc.mc_defaults

PX4_SIMULATOR=${PX4_SIMULATOR:=gz}
PX4_GZ_WORLD=${PX4_GZ_WORLD:=default}
PX4_SIM_MODEL=${PX4_SIM_MODEL:=modular_drone}

param set-default SIM_GZ_EN 1

param set-default CA_AIRFRAME 0
param set-default CA_ROTOR_COUNT 4

param set-default CA_ROTOR0_PX 0.15
param set-default CA_ROTOR0_PY 0.15
param set-default CA_ROTOR0_KM  0.05

param set-default CA_ROTOR1_PX -0.15
param set-default CA_ROTOR1_PY -0.15
param set-default CA_ROTOR1_KM  0.05

param set-default CA_ROTOR2_PX 0.15
param set-default CA_ROTOR2_PY -0.15
param set-default CA_ROTOR2_KM -0.05

param set-default CA_ROTOR3_PX -0.15
param set-default CA_ROTOR3_PY 0.15
param set-default CA_ROTOR3_KM -0.05

param set-default SIM_GZ_EC_FUNC1 101
param set-default SIM_GZ_EC_FUNC2 102
param set-default SIM_GZ_EC_FUNC3 103
param set-default SIM_GZ_EC_FUNC4 104

param set-default SIM_GZ_EC_MIN1 150
param set-default SIM_GZ_EC_MIN2 150
param set-default SIM_GZ_EC_MIN3 150
param set-default SIM_GZ_EC_MIN4 150

param set-default SIM_GZ_EC_MAX1 2200
param set-default SIM_GZ_EC_MAX2 2200
param set-default SIM_GZ_EC_MAX3 2200
param set-default SIM_GZ_EC_MAX4 2200

param set-default MPC_THR_HOVER 0.50
AIRFRAME_EOF
            chmod +x "$PX4_AIRFRAME_FILE"
            if [ -f "$PX4_AIRFRAME_CMAKE" ] && ! grep -q "4025_gz_modular_drone" "$PX4_AIRFRAME_CMAKE"; then
                sed -i '/4021_gz_x500_flow/a \\t4025_gz_modular_drone' "$PX4_AIRFRAME_CMAKE"
            fi
            check_passed "Auto-provisioned PX4 SITL Airframe '4025_gz_modular_drone'"
        else
            check_warn "PX4 SITL Airframe '4025_gz_modular_drone' missing (Run with --fix to resolve)"
        fi
    fi
fi

# 4.4 installed gigs Tooling Symlinks Verification & Repair
GIGS_TOOL_TARGETS=(
    "px4-teleop:$HOME/.local/bin/px4-teleop"
    "ros2:$HOME/.local/bin/ros2"
    "ros2-shell:$HOME/.local/bin/ros2-shell"
    "MicroXRCEAgent:$HOME/.local/bin/MicroXRCEAgent"
    "PX4-Autopilot:$PX4_DIR"
    "px4_ros2_ws:$HOME/px4_ros2_ws"
    "QGroundControl.AppImage:$QGC_APPIMAGE"
)

for entry in "${GIGS_TOOL_TARGETS[@]}"; do
    tool_name="${entry%%:*}"
    target_path="${entry#*:}"
    link_path="$GIGS_DIR/$tool_name"
    if [ -L "$link_path" ] && [ -e "$link_path" ]; then
        check_passed "Tooling link verified: installed gigs/$tool_name"
    else
        if [ "$AUTO_FIX" = true ] && [ -e "$target_path" ]; then
            ln -sfn "$target_path" "$link_path"
            check_passed "Auto-linked 'installed gigs/$tool_name' -> '$target_path'"
        elif [ -e "$target_path" ]; then
            check_warn "Tooling link 'installed gigs/$tool_name' needs repair (Run with --fix)"
        fi
    fi
done

# ------------------------------------------------------------------------------
# 5. SDFormat Semantic Verification (gz sdf -k)
# ------------------------------------------------------------------------------
log_section "📐 5. SDFormat Semantic & Kinematic Validation"

export SDF_PATH="$PARTS_LIB:${SDF_PATH:-}"
export GZ_SIM_RESOURCE_PATH="$PARTS_LIB:${GZ_SIM_RESOURCE_PATH:-}"
export GZ_SIM_PHYSICS_ENGINE_PATH="/usr/lib/gz-physics-7/engine-plugins:${GZ_SIM_PHYSICS_ENGINE_PATH:-}"

if command -v gz &> /dev/null; then
    for model in "${MODELS[@]}"; do
        SDF_PATH_FILE="$PARTS_LIB/$model/model.sdf"
        if [ -f "$SDF_PATH_FILE" ]; then
            VALIDATION_OUTPUT=$(gz sdf -k "$SDF_PATH_FILE" 2>&1 || true)
            if echo "$VALIDATION_OUTPUT" | grep -q "Valid."; then
                check_passed "SDFormat verification passed for '$model' (gz sdf -k: Valid)"
            else
                check_fail "SDFormat semantic error in '$model':\n$VALIDATION_OUTPUT"
            fi
        fi
    done
else
    check_warn "Skipping 'gz sdf -k' check: Gazebo CLI not found in PATH."
fi

# ------------------------------------------------------------------------------
# 6. Shell Environment Variable Verification & Auto-Configuration
# ------------------------------------------------------------------------------
log_section "🐚 6. Shell Environment Profile Configuration"

ENV_EXPORT_SNIPPET="
# ==============================================================================
# --- Drone Club Modular Parts Library & Gazebo Harmonic Environment ---
# ==============================================================================
export PATH=\"\$HOME/.local/bin:\$PATH\"
export PARTS_LIB=\"$PARTS_LIB\"
export GZ_SIM_RESOURCE_PATH=\"\$PARTS_LIB:\$HOME/PX4-Autopilot/Tools/simulation/gz/models:\$HOME/PX4-Autopilot/Tools/simulation/gz/worlds:\${GZ_SIM_RESOURCE_PATH:-}\"
export SDF_PATH=\"\$PARTS_LIB:\${SDF_PATH:-}\"
export GZ_SIM_PHYSICS_ENGINE_PATH=\"/usr/lib/gz-physics-7/engine-plugins:\${GZ_SIM_PHYSICS_ENGINE_PATH:-}\"
export PX4_GZ_PHYSICS_ENGINE=\"gz-physics-bullet-featherstone-plugin\"
"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

check_shell_rc() {
    local rc_file="$1"
    local shell_name="$2"

    if [ -f "$rc_file" ]; then
        if grep -q "PARTS_LIB" "$rc_file"; then
            check_passed "$shell_name profile ($rc_file) contains PARTS_LIB exports."
        else
            if [ "$AUTO_FIX" = true ]; then
                echo "$ENV_EXPORT_SNIPPET" >> "$rc_file"
                check_passed "Appended Modular Parts Library exports to $rc_file"
            else
                check_warn "$shell_name profile ($rc_file) missing PARTS_LIB exports. Run with --fix to append automatically."
            fi
        fi
    fi
}

check_shell_rc "$HOME/.bashrc" "Bash"
check_shell_rc "$HOME/.zshrc" "Zsh"

# ------------------------------------------------------------------------------
# 7. Obsidian Engineering Knowledge Base Verification
# ------------------------------------------------------------------------------
log_section "📚 7. Obsidian Documentation Vault & Pipeline Notes"

VAULT_NOTES=(
    "Welcome.md"
    "Robotics Simulation Pipeline.md"
    "README.md"
    "Simulation/00 - Day One Zero-to-Hero Quickstart.md"
    "Simulation/01 - PX4 Autopilot SITL Setup.md"
    "Simulation/02 - Gazebo Harmonic Setup.md"
    "Simulation/03 - Micro XRCE-DDS & ROS 2 Setup.md"
    "Simulation/04 - Shell Environment & Launch Automation.md"
    "Simulation/05 - QGroundControl Setup.md"
    "Simulation/06 - Smoke Test & Flight Verification.md"
    "Simulation/07 - Sample Drone Flight.md"
    "Simulation/08 - Performance & Troubleshooting Guide.md"
    "Simulation/09 - Modular Drone & Parts Library Setup.md"
    "Simulation/Installed Gigs & Simulation Tooling.md"
    "Simulation/Quick Reference & Launch Script.md"
    "Simulation/PX4 ROS2 Migration Ledger.md"
    "Simulation/implementationplan.md"
)

for note in "${VAULT_NOTES[@]}"; do
    NOTE_PATH="$VAULT_DIR/$note"
    if [ -f "$NOTE_PATH" ]; then
        check_passed "Obsidian note verified: $note"
    else
        check_warn "Obsidian note missing: $note"
    fi
done

# ------------------------------------------------------------------------------
# 8. Diagnostic Summary & Action Execution
# ------------------------------------------------------------------------------
log_section "📊 8. System Readiness Diagnostic Summary"

echo -e "Total Checks Executed : ${BOLD}$TOTAL_CHECKS${RESET}"
echo -e "Checks Passed         : ${GREEN}${BOLD}$TOTAL_PASSED${RESET}"
echo -e "Warnings Logged       : ${YELLOW}${BOLD}$TOTAL_WARNINGS${RESET}"
echo -e "Failures Encountered  : $([ $TOTAL_ERRORS -gt 0 ] && echo -e "${RED}${BOLD}$TOTAL_ERRORS${RESET}" || echo -e "${GREEN}${BOLD}0${RESET}")"

if [ $TOTAL_ERRORS -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}🎉 EXCELLENT: All core requirements and modular model entities are fully verified!${RESET}"
else
    echo -e "\n${RED}${BOLD}⚠ ATTENTION: $TOTAL_ERRORS critical issue(s) detected. Review logs above or rerun with: ./setup_modular_drone.sh --fix${RESET}"
fi

# Preview or Full Sim Launch actions
if [ "$LAUNCH_PREVIEW" = true ]; then
    log_step "Launching Standalone 3D Gazebo Sim Preview for modular_drone..."
    export GZ_SIM_RESOURCE_PATH="$PARTS_LIB:$PX4_DIR/Tools/simulation/gz/models:$PX4_DIR/Tools/simulation/gz/worlds:${GZ_SIM_RESOURCE_PATH:-}"
    export SDF_PATH="$PARTS_LIB:${SDF_PATH:-}"
    export GZ_SIM_PHYSICS_ENGINE_PATH="/usr/lib/gz-physics-7/engine-plugins:${GZ_SIM_PHYSICS_ENGINE_PATH:-}"
    exec gz sim -v 4 --physics-engine gz-physics-bullet-featherstone-plugin "$PARTS_LIB/preview_world.sdf"
elif [ "$LAUNCH_FULL_SIM" = true ]; then
    log_step "Launching Full Simulation Stack via start_sim.sh (-m modular_drone)..."
    exec "$GIGS_DIR/start_sim.sh" -m modular_drone
fi

if [ "$VALIDATE_ONLY" = true ]; then
    [ $TOTAL_ERRORS -eq 0 ] && exit 0 || exit 1
fi
