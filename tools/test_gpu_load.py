#!/usr/bin/env python3
"""
GPU load test — taxes each GPU with glxgears while monitoring KSystemStats sensors.
Runs for max 60 seconds. Requires: glxgears (mesa-demos).
"""

import subprocess
import time
import signal
import sys
import os

def query_sensor(sensor_id):
    """Query a KSystemStats sensor, return the raw value string."""
    cmd = (
        f"busctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 "
        f"org.kde.ksystemstats1 sensorData as 1 {sensor_id}"
    )
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=3)
        parts = r.stdout.strip().split()
        if len(parts) >= 2:
            return parts[-2], parts[-1]  # (type, value)
    except Exception:
        pass
    return "?", "?"

def subscribe(sensor_id):
    cmd = (
        f"busctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 "
        f"org.kde.ksystemstats1 subscribe as 1 {sensor_id}"
    )
    subprocess.run(cmd, shell=True, capture_output=True, timeout=3)

def check_command(cmd):
    """Check if a command exists."""
    return subprocess.run(f"which {cmd}", shell=True, capture_output=True).returncode == 0

def run_gpu_test(label, env, duration=25):
    """Run glxgears with given env, monitor sensors, return results."""
    print(f"\n{'='*60}")
    print(f"  Phase: {label}")
    print(f"{'='*60}")

    # Subscribe to sensors first
    subscribe("gpu/gpu1/usage")
    subscribe("gpu/gpu2/usage")

    # Start glxgears
    full_env = {**os.environ, **env}
    try:
        proc = subprocess.Popen(
            ["glxgears", "-fullscreen"],
            env=full_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError:
        # Try without fullscreen
        try:
            proc = subprocess.Popen(
                ["glxgears"],
                env=full_env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except FileNotFoundError:
            print("  glxgears not found! Install with: sudo dnf install mesa-demos")
            return []

    print(f"  glxgears PID: {proc.pid}")
    time.sleep(1)  # Let it warm up

    results = []
    print(f"  {'Sec':>4s}  {'gpu1 (Intel)':>14s}  {'gpu2 (NVIDIA)':>14s}")
    print(f"  {'-'*4}  {'-'*14}  {'-'*14}")

    for i in range(duration):
        t1, v1 = query_sensor("gpu/gpu1/usage")
        t2, v2 = query_sensor("gpu/gpu2/usage")
        marker1 = " <--" if v1 != "0" else ""
        marker2 = " <--" if v2 != "0" else ""
        print(f"  {i:>4d}  {v1:>10s} ({t1}){marker1}  {v2:>10s} ({t2}){marker2}")
        results.append((v1, v2))
        time.sleep(1)

    proc.terminate()
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        proc.kill()

    return results

def main():
    print("GPU Load Test — monitoring KSystemStats sensors under load")
    print("Max runtime: ~60 seconds\n")

    if not check_command("glxgears"):
        print("ERROR: glxgears not found. Install with:")
        print("  sudo dnf install mesa-demos")
        sys.exit(1)

    # Show GPU info
    print("GPU info:")
    for sensor in ["gpu/gpu1/name", "gpu/gpu2/name"]:
        _, val = query_sensor(sensor)
        print(f"  {sensor}: {val}")

    # Check GPU power states
    for path in [
        "/sys/bus/pci/devices/0000:01:00.0/power/runtime_status",
        "/sys/class/drm/card1/device/power/runtime_status",
        "/sys/class/drm/card2/device/power/runtime_status",
    ]:
        try:
            with open(path) as f:
                print(f"  {path}: {f.read().strip()}")
        except (FileNotFoundError, PermissionError):
            pass

    all_results = {}

    # Phase 1: Default GPU (Intel)
    r = run_gpu_test("Default GPU (Intel i915)", env={}, duration=20)
    all_results["intel"] = r

    # Phase 2: NVIDIA via DRI_PRIME=1
    print("\n  Checking NVIDIA power state before DRI_PRIME test...")
    try:
        with open("/sys/bus/pci/devices/0000:01:00.0/power/runtime_status") as f:
            print(f"  NVIDIA runtime_status: {f.read().strip()}")
    except Exception:
        pass

    r = run_gpu_test("NVIDIA GPU (DRI_PRIME=1)", env={"DRI_PRIME": "1"}, duration=20)
    all_results["nvidia"] = r

    # Summary
    print(f"\n{'='*60}")
    print("  SUMMARY")
    print(f"{'='*60}")

    for name, results in all_results.items():
        if not results:
            print(f"\n  {name}: no data (glxgears failed)")
            continue
        gpu1_vals = set(v1 for v1, v2 in results)
        gpu2_vals = set(v2 for v1, v2 in results)
        gpu1_nonzero = [v1 for v1, v2 in results if v1 != "0"]
        gpu2_nonzero = [v2 for v1, v2 in results if v2 != "0"]
        print(f"\n  {name} test:")
        print(f"    gpu/gpu1 unique values: {gpu1_vals}  (non-zero samples: {len(gpu1_nonzero)}/{len(results)})")
        print(f"    gpu/gpu2 unique values: {gpu2_vals}  (non-zero samples: {len(gpu2_nonzero)}/{len(results)})")

    any_nonzero = False
    for results in all_results.values():
        for v1, v2 in (results or []):
            if v1 != "0" or v2 != "0":
                any_nonzero = True

    if any_nonzero:
        print("\n  RESULT: GPU sensor IS reporting usage under load.")
        print("  The widget should show non-zero GPU values when the GPU is active.")
    else:
        print("\n  RESULT: GPU sensor stuck at 0 even under load.")
        print("  KSystemStats may not support usage reporting for your GPU drivers.")
        print("  This is a known limitation with nouveau and some i915 configurations.")

if __name__ == "__main__":
    main()
