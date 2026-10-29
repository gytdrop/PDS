#!/usr/bin/env python3
"""
Drone Club DC - Robust Autonomous Drone Flight Controller
Connects to ArduPilot SITL via MAVLink, performs pre-flight EKF/GPS verification,
arms motors, takes off, executes a closed-loop NED square flight mission,
and triggers Return-to-Launch (RTL).
"""

import argparse
import math
import sys
import time

try:
    sys.stdout.reconfigure(line_buffering=True)
except Exception:
    pass

try:
    from pymavlink import mavutil
except ImportError:
    print("[DC ERROR] pymavlink is not installed in the active Python environment.")
    print("           Please run with ~/venv-ardupilot/bin/python3 or run:")
    print("           source ~/venv-ardupilot/bin/activate")
    sys.exit(1)


def connect_drone(connection_str=None, timeout=5):
    """
    Connects to the vehicle. If no connection string is provided,
    attempts default MAVProxy API port (14551), then GCS port (14550),
    and finally SITL direct TCP (5760).
    """
    candidate_ports = [connection_str] if connection_str else [
        "udpin:localhost:14551",
        "udpin:localhost:14550",
        "tcp:127.0.0.1:5760"
    ]

    for conn in candidate_ports:
        print(f"[DC] Attempting connection to vehicle on {conn} (timeout {timeout}s)...", flush=True)
        try:
            master = mavutil.mavlink_connection(conn)
            t_start = time.time()
            while time.time() - t_start < timeout:
                heartbeat = master.wait_heartbeat(timeout=1)
                if heartbeat and heartbeat.get_srcComponent() == 1:
                    master.target_system = heartbeat.get_srcSystem()
                    master.target_component = heartbeat.get_srcComponent()
                    print(f"[DC] ✅ Heartbeat received from Autopilot System {master.target_system}, Component {master.target_component}!", flush=True)
                    return master
            print(f"[DC] ⚠️ No autopilot heartbeat on {conn}.", flush=True)
        except Exception as e:
            print(f"[DC] ⚠️ Connection to {conn} failed: {e}", flush=True)

    print("[DC ERROR] Failed to connect to vehicle on any MAVLink port.", flush=True)
    print("           Ensure Gazebo Harmonic and ArduPilot SITL are running.", flush=True)
    sys.exit(1)


def wait_for_ekf_and_arm(master, timeout=60):
    """
    Waits for GPS lock and EKF3 position certainty, switches to GUIDED mode,
    and arms the vehicle with pre-arm diagnostic reporting.
    """
    print("[DC] Pre-flight: Waiting for EKF3 to acquire GPS position lock...", flush=True)
    start_time = time.time()
    gps_locked = False
    ekf_locked = False

    while time.time() - start_time < timeout:
        while True:
            msg = master.recv_match(blocking=False)
            if msg is None:
                break
            mtype = msg.get_type()
            if mtype == 'STATUSTEXT':
                text = msg.text.strip('\x00')
                if text:
                    print(f"[AP STAT] {text}", flush=True)
            elif mtype == 'GPS_RAW_INT':
                if msg.fix_type >= 3 and not gps_locked:
                    print(f"[DC] GPS 3D Fix established! Satellites: {msg.satellites_visible}", flush=True)
                    gps_locked = True
            elif mtype == 'EKF_STATUS_REPORT':
                if msg.flags & mavutil.mavlink.EKF_POS_HORIZ_ABS:
                    ekf_locked = True
                    print("[DC] ✅ EKF3 horizontal absolute position lock confirmed!", flush=True)
                    break
        if ekf_locked:
            break
        time.sleep(0.1)

    if not ekf_locked:
        print("[DC ERROR] EKF3 position lock timed out. Check GPS and simulation clock.", flush=True)
        sys.exit(1)

    # Set Mode to GUIDED
    print("[DC] Commanding mode switch to GUIDED...", flush=True)
    master.set_mode('GUIDED')
    time.sleep(1)

    # Arm motors
    print("[DC] Arming motors...", flush=True)
    master.arducopter_arm()

    try:
        master.motors_armed_wait(timeout=10)
        print("[DC] 🚀 Motors ARMED successfully!", flush=True)
    except Exception:
        print("[DC ERROR] Motors failed to arm within 10 seconds.", flush=True)
        # Drain status messages to print pre-arm failure reason
        time.sleep(1)
        while True:
            stat = master.recv_match(type='STATUSTEXT', blocking=False)
            if stat:
                print(f"[AP PRE-ARM FAIL] {stat.text.strip(chr(0))}", flush=True)
            else:
                break
        sys.exit(1)


def takeoff(master, target_alt=10.0, timeout=30):
    """
    Commands vehicle takeoff to target_alt and monitors climb rate.
    """
    print(f"[DC] Commanding takeoff to {target_alt:.1f} meters AGL...", flush=True)
    master.mav.command_long_send(
        master.target_system,
        master.target_component,
        mavutil.mavlink.MAV_CMD_NAV_TAKEOFF,
        0,
        0, 0, 0, 0, 0, 0,
        target_alt
    )

    start_time = time.time()
    while time.time() - start_time < timeout:
        msg = master.recv_match(type='GLOBAL_POSITION_INT', blocking=True, timeout=2)
        if msg:
            alt = msg.relative_alt / 1000.0  # mm to meters
            print(f"[DC] Climbing... Altitude: {alt:5.2f} m / {target_alt:.1f} m", end="\r", flush=True)
            if alt >= target_alt * 0.95:
                print(f"\n[DC] ✅ Reached target altitude of {target_alt:.1f}m (Current: {alt:.2f}m)!", flush=True)
                time.sleep(1)
                return True
        time.sleep(0.2)

    print(f"\n[DC WARNING] Takeoff climb timed out after {timeout} seconds.", flush=True)
    return False


def move_local_ned_closed_loop(master, north, east, down, leg_name="Waypoint", tolerance=0.8, timeout=40):
    """
    Navigates to local NED position with closed-loop telemetry feedback.
    Continuously streams setpoints at 2 Hz and calculates Euclidean distance to target.
    """
    print(f"\n[DC] ▶️ Starting {leg_name}: Target NED -> North={north:+.1f}m, East={east:+.1f}m, Down={down:+.1f}m", flush=True)
    start_time = time.time()
    last_send = 0

    while time.time() - start_time < timeout:
        now = time.time()
        # Stream position target at 2 Hz (prevents autopilot failsafe timeout)
        if now - last_send >= 0.5:
            master.mav.set_position_target_local_ned_send(
                0,
                master.target_system,
                master.target_component,
                mavutil.mavlink.MAV_FRAME_LOCAL_NED,
                0b0000111111111000,  # Position bitmask
                north, east, down,
                0, 0, 0,            # Velocity
                0, 0, 0,            # Acceleration
                0, 0                # Yaw, Yaw rate
            )
            last_send = now

        # Read current local position
        pos = master.recv_match(type='LOCAL_POSITION_NED', blocking=True, timeout=1)
        if pos:
            dx = north - pos.x
            dy = east - pos.y
            dz = down - pos.z
            dist_horiz = math.hypot(dx, dy)
            dist_3d = math.sqrt(dx*dx + dy*dy + dz*dz)

            print(f"[DC] {leg_name} | Pos: N={pos.x:5.1f}m, E={pos.y:5.1f}m, Alt={-pos.z:5.1f}m | Dist: {dist_3d:4.1f}m ", end="\r", flush=True)

            if dist_3d <= tolerance:
                print(f"\n[DC] 🎯 {leg_name} reached! (Final distance: {dist_3d:.2f}m <= {tolerance}m)", flush=True)
                time.sleep(1.5)  # Stabilize at waypoint
                return True

        time.sleep(0.1)

    print(f"\n[DC WARNING] {leg_name} timed out after {timeout}s.", flush=True)
    return False


def return_and_land(master, timeout=90):
    """
    Commands Return-to-Launch (RTL) mode and monitors automated descent until touchdown.
    """
    print("\n[DC] 🛬 Mission pattern completed. Commanding Return-to-Launch (RTL)...", flush=True)
    master.set_mode('RTL')
    print("[DC] Vehicle returning to home origin. Monitoring landing and disarm...", flush=True)

    start_time = time.time()
    while time.time() - start_time < timeout:
        while True:
            msg = master.recv_match(blocking=False)
            if msg is None:
                break
            mtype = msg.get_type()
            if mtype == 'GLOBAL_POSITION_INT':
                alt = msg.relative_alt / 1000.0
                print(f"[DC] RTL Descent... Altitude: {alt:5.2f}m", end="\r", flush=True)
            elif mtype == 'HEARTBEAT':
                is_armed = msg.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED
                if not is_armed:
                    print("\n[DC] 🏁 Touchdown confirmed! Motors disarmed. Flight mission complete!", flush=True)
                    return True
        time.sleep(0.2)

    print("\n[DC WARNING] Landing monitoring timed out.", flush=True)
    return False


def main():
    parser = argparse.ArgumentParser(description="Drone Club Autonomous Flight Controller")
    parser.add_argument("--connect", type=str, default=None,
                        help="MAVLink connection URI (default auto-tries udpin:localhost:14551, 14550, tcp:127.0.0.1:5760)")
    parser.add_argument("--alt", type=float, default=10.0,
                        help="Target cruise altitude in meters (default: 10.0m)")
    parser.add_argument("--size", type=float, default=15.0,
                        help="Square pattern leg length in meters (default: 15.0m)")
    parser.add_argument("--timeout", type=int, default=45,
                        help="Per-waypoint navigation timeout in seconds (default: 45s)")
    args = parser.parse_args()

    master = connect_drone(args.connect)

    try:
        wait_for_ekf_and_arm(master)
        takeoff(master, target_alt=args.alt)

        s = args.size
        d = -args.alt  # NED down is negative altitude

        print(f"\n--- Executing {s:.0f}m x {s:.0f}m Closed-Loop Square Mission ---")
        move_local_ned_closed_loop(master, north=s, east=0.0, down=d, leg_name="Leg 1 (North)", timeout=args.timeout)
        move_local_ned_closed_loop(master, north=s, east=s, down=d, leg_name="Leg 2 (East)", timeout=args.timeout)
        move_local_ned_closed_loop(master, north=0.0, east=s, down=d, leg_name="Leg 3 (South)", timeout=args.timeout)
        move_local_ned_closed_loop(master, north=0.0, east=0.0, down=d, leg_name="Leg 4 (Home Return)", timeout=args.timeout)

        return_and_land(master)
    except KeyboardInterrupt:
        print("\n[DC EMERGENCY] Keyboard interrupt detected! Commanding immediate RTL for safety...")
        try:
            master.set_mode('RTL')
        except Exception:
            pass
        sys.exit(0)


if __name__ == "__main__":
    main()
