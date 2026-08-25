"""Feed QGC a fake 8-motor vehicle with per-ESC telemetry over UDP 14550."""
import math, os, time
os.environ["MAVLINK20"] = "1"
os.environ["MAVLINK_DIALECT"] = "common"
from pymavlink import mavutil

m = mavutil.mavlink_connection('udpout:127.0.0.1:14550', source_system=1, source_component=1, dialect='common')
t0 = time.time()
n = 0
while True:
    t = time.time() - t0
    us = int(t * 1e6)

    m.mav.heartbeat_send(
        mavutil.mavlink.MAV_TYPE_OCTOROTOR, mavutil.mavlink.MAV_AUTOPILOT_PX4,
        mavutil.mavlink.MAV_MODE_FLAG_CUSTOM_MODE_ENABLED, 0,
        mavutil.mavlink.MAV_STATE_ACTIVE)

    # Eight discrete ESCs => two ESC_STATUS messages (indices 0-3 and 4-7)
    for base in (0, 4):
        rpm     = [int(4200 + 900 * math.sin(t * 0.9 + (base + i) * 0.7)) for i in range(4)]
        voltage = [22.2 + 0.6 * math.sin(t * 0.4 + (base + i) * 1.1) for i in range(4)]
        current = [11.0 + 4.0 * math.sin(t * 1.3 + (base + i) * 0.5) for i in range(4)]
        m.mav.esc_status_send(base, us, rpm, voltage, current)

    # ESC_INFO carries the real motor count (8) and the online bitmask
    if n % 5 == 0:
        for base in (0, 4):
            m.mav.esc_info_send(base, us, n, 8,
                                mavutil.mavlink.ESC_CONNECTION_TYPE_DSHOT,
                                0xFF, [0]*4, [0]*4, [3500]*4)
    n += 1
    time.sleep(0.1)
