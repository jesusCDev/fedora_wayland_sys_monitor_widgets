#!/usr/bin/env python3
"""
Diagnostic script for GPU sensor data pipeline.
Tests KSystemStats D-Bus GPU sensors and checks if values change.
"""

import subprocess
import time
import sys

def run(cmd):
    """Run a shell command, return (stdout, stderr, returncode)."""
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
    return r.stdout.strip(), r.stderr.strip(), r.returncode

def busctl_call(method, *args):
    """Call a KSystemStats D-Bus method."""
    base = "busctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 org.kde.ksystemstats1"
    if args:
        arg_str = " ".join(args)
        cmd = f"{base} {method} as {len(args)} {arg_str}"
    else:
        cmd = f"{base} {method}"
    return run(cmd)

def get_sensor_value(sensor_id):
    """Query a single sensor and return raw output."""
    out, err, rc = busctl_call("sensorData", sensor_id)
    return out, err, rc

def list_gpu_sensors():
    """Find all GPU-related sensors."""
    out, err, rc = run(
        "busctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 "
        "org.kde.ksystemstats1 allSensors | tr ',' '\\n' | grep -i gpu"
    )
    return out

def parse_dbus_value(raw):
    """Parse the D-Bus output to extract the value and type."""
    # Format: a(sv) 1 "sensor/id" <type> <value>
    parts = raw.split()
    if len(parts) >= 2:
        dtype = parts[-2]  # type indicator: i=int32, d=double, x=int64, etc
        value = parts[-1]
        return dtype, value
    return None, None

def main():
    print("=" * 60)
    print("GPU Sensor Diagnostic")
    print("=" * 60)

    # 1. List all GPU sensors
    print("\n[1] All GPU sensors available:")
    sensors = list_gpu_sensors()
    if sensors:
        for line in sensors.split("\n"):
            line = line.strip().strip('"')
            if line:
                print(f"    {line}")
    else:
        print("    (none found!)")

    # 2. Subscribe to gpu/gpu1/usage
    print("\n[2] Subscribing to gpu/gpu1/usage...")
    out, err, rc = busctl_call("subscribe", "gpu/gpu1/usage")
    print(f"    stdout: {out!r}")
    print(f"    stderr: {err!r}")
    print(f"    exit code: {rc}")

    # 3. Query each GPU sensor
    print("\n[3] Querying GPU sensors:")
    test_sensors = ["gpu/gpu1/usage", "gpu/gpu2/usage", "gpu/all/usage",
                    "gpu/gpu1/name", "gpu/gpu2/name"]
    for s in test_sensors:
        out, err, rc = get_sensor_value(s)
        dtype, value = parse_dbus_value(out)
        print(f"    {s}: raw={out!r}  type={dtype}  value={value}  rc={rc}")
        if err:
            print(f"        stderr: {err}")

    # 4. Test the exact command the widget uses (awk pipeline)
    print("\n[4] Testing exact widget command (sensorData | awk):")
    widget_cmd = (
        "sh -c 'busctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 "
        "org.kde.ksystemstats1 sensorData as 1 gpu/gpu1/usage 2>/dev/null "
        "| awk \"{print \\$NF}\"'"
    )
    out, err, rc = run(widget_cmd)
    print(f"    output: {out!r}")
    print(f"    parseFloat would give: {float(out) if out else 'NaN (empty)'}")

    # 5. Check GPU power state (nouveau)
    print("\n[5] GPU power state (nouveau/runtime PM):")
    gpu_power_paths = [
        "/sys/bus/pci/devices/0000:01:00.0/power/runtime_status",
        "/sys/class/drm/card1/device/power/runtime_status",
        "/sys/class/drm/card0/device/power/runtime_status",
    ]
    for p in gpu_power_paths:
        out, err, rc = run(f"cat {p} 2>/dev/null")
        if out:
            print(f"    {p}: {out}")

    # Also check which GPUs exist
    out, _, _ = run("ls -la /sys/class/drm/card*/device/driver 2>/dev/null")
    if out:
        print(f"    DRM drivers:\n    {out}")

    # 6. Monitor GPU sensor over 10 seconds
    print(f"\n[6] Monitoring gpu/gpu1/usage for 10 seconds (1 sample/sec):")
    print(f"    {'Time':>6s}  {'Raw':>8s}  {'Type':>6s}  {'Value':>8s}")
    print(f"    {'-'*6}  {'-'*8}  {'-'*6}  {'-'*8}")

    values_seen = set()
    for i in range(10):
        out, err, rc = get_sensor_value("gpu/gpu1/usage")
        dtype, value = parse_dbus_value(out)
        values_seen.add(value)
        print(f"    {i:>5}s  {out[-20:] if out else '(empty)':>8s}  {dtype or '?':>6s}  {value or '?':>8s}")
        time.sleep(1)

    # 7. Summary
    print(f"\n[7] Summary:")
    print(f"    Unique values seen: {values_seen}")
    dtype, _ = parse_dbus_value(out)
    if dtype == "i":
        print(f"    Sensor type: int32 (i) — can only return whole numbers (0, 1, 2, ...)")
        print(f"    NOTE: 0.1% or 0.3% is IMPOSSIBLE with int type. The sensor can only do 0%, 1%, 2%, etc.")
        print(f"    If you saw '0.1%' before, that was likely fmt() formatting 0 as '0.0' with decimals enabled.")
    elif dtype == "d":
        print(f"    Sensor type: double (d) — can return fractional values")
    else:
        print(f"    Sensor type: {dtype} — unknown")

    if values_seen == {"0"} or values_seen == {0}:
        print(f"\n    GPU usage is stuck at 0%. Possible causes:")
        print(f"    - dGPU is powered off (nouveau runtime PM) — this is normal on battery")
        print(f"    - No workload running on the discrete GPU")
        print(f"    - KSystemStats sensor not updating")

    # 8. Try to generate GPU load and see if sensor changes
    print(f"\n[8] Attempting to trigger GPU activity (glxinfo)...")
    out_glx, _, rc_glx = run("glxinfo -B 2>/dev/null | head -5")
    if out_glx:
        print(f"    {out_glx}")
    time.sleep(1)
    out, err, rc = get_sensor_value("gpu/gpu1/usage")
    dtype, value = parse_dbus_value(out)
    print(f"    GPU usage after glxinfo: {value}")

if __name__ == "__main__":
    main()
