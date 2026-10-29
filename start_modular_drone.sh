#!/usr/bin/env bash
set -eo pipefail

echo "==> [Preflight] Validating Simulation Stack Dependencies..."

MISSING_DEPS=()

# Binary checks
command -v gz >/dev/null 2>&1 || command -v ign >/dev/null 2>&1 || MISSING_DEPS+=("gazebo-sim (gz/ign)")
command -v cmake >/dev/null 2>&1 || MISSING_DEPS+=("cmake")
command -v g++ >/dev/null 2>&1 || MISSING_DEPS+=("g++")

# Python trimesh check for CAD inertia calculation
python3 -c "import trimesh" >/dev/null 2>&1 || {
  echo "[-] Python 'trimesh' not detected. Installing user-level dependency..."
  pip install --user --break-system-packages trimesh numpy scipy 2>/dev/null || pip install --user trimesh numpy scipy || MISSING_DEPS+=("python-trimesh")
}

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
  echo "[-] ERROR: Critical missing dependencies: ${MISSING_DEPS[*]}"
  echo "    Install them via your package manager (e.g., pacman -S cmake gcc gz-harmonic or apt install cmake g++)"
  exit 1
fi

echo "[+] All system binaries verified."

# Paths and Environment Setup
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARTS_LIBRARY="$PROJECT_ROOT/parts_library"
PLUGIN_BUILD_DIR="$PROJECT_ROOT/plugins/custom_drone_plugin/build"

# Compile Custom C++ System Plugins if modified or unbuilt
if [ -d "$PROJECT_ROOT/plugins/custom_drone_plugin" ]; then
  echo "==> [Build] Checking C++ simulation plugins..."
  mkdir -p "$PLUGIN_BUILD_DIR"
  cmake -B "$PLUGIN_BUILD_DIR" -S "$PROJECT_ROOT/plugins/custom_drone_plugin"
  cmake --build "$PLUGIN_BUILD_DIR" -j"$(nproc)"
fi

# Export Gazebo Resource Paths
export GZ_SIM_RESOURCE_PATH="${PARTS_LIBRARY}:${PROJECT_ROOT}/Parts_library:${GZ_SIM_RESOURCE_PATH}"
export GAZEBO_MODEL_PATH="${PARTS_LIBRARY}:${PROJECT_ROOT}/Parts_library:${GAZEBO_MODEL_PATH}"
export GZ_SIM_SYSTEM_PLUGIN_PATH="${PLUGIN_BUILD_DIR}:${GZ_SIM_SYSTEM_PLUGIN_PATH}"

echo "[+] Environment Configured:"
echo "    GZ_SIM_RESOURCE_PATH: $GZ_SIM_RESOURCE_PATH"
echo "    GZ_SIM_SYSTEM_PLUGIN_PATH: $GZ_SIM_SYSTEM_PLUGIN_PATH"

# Launch Option
if [ "$1" == "--preview" ] || [ "$1" == "-p" ] || [ "$1" == "--run" ] || [ "$1" == "-r" ]; then
  WORLD_FILE="$PROJECT_ROOT/Parts_library/preview_world.sdf"
  echo "==> Launching Gazebo Sim preview with $WORLD_FILE..."
  gz sim -v 4 "$WORLD_FILE" --physics-engine gz-physics-bullet-featherstone-plugin
elif [ -n "$1" ]; then
  echo "==> Launching Gazebo Sim with $1..."
  gz sim -v 4 "$1" --physics-engine gz-physics-bullet-featherstone-plugin
else
  echo "[+] Setup complete. Usage:"
  echo "    ./start_modular_drone.sh --preview        # Launch 3D Gazebo modular drone preview"
  echo "    ./start_modular_drone.sh <world_file.sdf> # Launch specific world"
  echo "    source ./start_modular_drone.sh           # Export Gazebo environment variables to shell"
fi
