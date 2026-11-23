#!/usr/bin/env python3
"""
ESP32-C6 heart rate link tester.

Watches the firmware over USB serial and over BLE at the same time, so wiring
and app-protocol problems show up in one place.

  python3 tools/ble_test.py --serial-only     # just watch the sensor pin
  python3 tools/ble_test.py                   # serial + BLE
  python3 tools/ble_test.py --port /dev/ttyACM0 --secs 30

Requires: pyserial, bleak   (pip install pyserial bleak)
"""

import argparse
import asyncio
import json
import sys

SVC = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
HR = "beb5483e-36e1-4688-b7f5-ea07361b26a8"
DEVICE_NAME = "ESP32-C6 HRM"

DC_VALID_MIN_MV = 900
DC_VALID_MAX_MV = 2600


def parse_kv(line):
    out = {}
    for tok in line.split():
        if "=" in tok:
            k, v = tok.split("=", 1)
            out[k] = v
    return out


def watch_serial(port, secs):
    import serial

    ser = serial.Serial()
    ser.port = port
    ser.baudrate = 115200
    ser.timeout = 0.4
    ser.open()

    import time

    deadline = time.time() + secs
    last = {}
    hint_shown = False
    try:
        while time.time() < deadline:
            raw = ser.read(512)
            if not raw:
                continue
            for line in raw.decode("utf-8", "replace").splitlines():
                line = line.strip()
                if line.startswith("SENSOR "):
                    kv = parse_kv(line)
                    last = kv
                    lead_off = kv.get("lead_off") == "1"
                    flag = "NO SIGNAL" if lead_off else "signal ok"
                    print(
                        f"  [pin] dc={kv.get('dc','?'):>8} "
                        f"ac={kv.get('ac','?'):>9} beats={kv.get('beats','?'):>2} "
                        f"bpm={kv.get('bpm','?'):>3}  {flag}",
                        flush=True,
                    )
                    if lead_off and not hint_shown:
                        hint_shown = True
                        try:
                            dc = float(kv.get("dc", "0").replace("mV", ""))
                        except ValueError:
                            dc = 0.0
                        if not (DC_VALID_MIN_MV <= dc <= DC_VALID_MAX_MV):
                            print(
                                "       ^ the signal pin is floating (~%.0f mV). A powered " % dc
                                + "pulse module idles near 1600 mV. Check that the "
                                + "SIGNAL wire is on header pin A3/D3 and the module "
                                + "has 3V3 + GND.",
                                flush=True,
                            )
                elif line.startswith(("BLE:", "STATUS", "WARNING")):
                    print(f"  [fw] {line}", flush=True)
    finally:
        ser.close()
    return last


async def watch_ble(secs, expect):
    from bleak import BleakClient, BleakScanner

    print(f"\n[BLE] scanning {secs}s for {DEVICE_NAME!r} ...", flush=True)
    dev = await BleakScanner.find_device_by_filter(
        lambda d, a: (a.local_name or d.name or "") == DEVICE_NAME, timeout=float(secs)
    )
    if not dev:
        print("  no advertisement seen")
        return False

    print(f"  found {dev.name} [{dev.address}]", flush=True)
    values = []

    async with BleakClient(dev) as client:
        print(f"  connected (mtu={client.mtu_size})", flush=True)

        svc = next((s for s in client.services if str(s.uuid).lower() == SVC), None)
        if not svc:
            print("  service UUID missing - firmware/app mismatch")
            return False
        have = {str(c.uuid).lower() for c in svc.characteristics}
        for label, uuid in (("heartRate", HR),):
            print(f"  {label} characteristic: {'present' if uuid in have else 'MISSING'}", flush=True)

        def on_hr(_c, data):
            text = bytes(data).decode("utf-8", "replace")
            try:
                bpm = json.loads(text).get("bpm", 0)
            except json.JSONDecodeError:
                print(f"    notify {text!r} -> NOT JSON", flush=True)
                return
            values.append(bpm)
            if len(values) <= 8 or bpm != values[-2]:
                print(f"    notify {text!r} -> bpm={bpm} ({len(text)}B)", flush=True)

        await client.start_notify(HR, on_hr)
        await asyncio.sleep(min(8.0, float(secs)))
        await client.stop_notify(HR)

    if not values:
        print("  connected but no notifications arrived")
        return False

    print(f"  received {len(values)} notifications", flush=True)
    if expect == "live" and all(v == 0 for v in values):
        print("  every reading was 0 - the link works but the sensor is not producing a pulse")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--secs", type=float, default=25)
    ap.add_argument("--serial-only", action="store_true")
    ap.add_argument(
        "--expect",
        choices=["live", "any"],
        default="any",
        help="'live' warns when only zero readings arrive",
    )
    args = ap.parse_args()

    print(f"[serial] {args.port} @115200 for {args.secs:.0f}s", flush=True)
    try:
        watch_serial(args.port, args.secs)
    except Exception as exc:  # noqa: BLE001 - surface the real error to the user
        print(f"  serial error: {exc}")
        if args.serial_only:
            sys.exit(1)

    if args.serial_only:
        return

    ok = asyncio.run(watch_ble(args.secs, args.expect))
    print("\nRESULT:", "link OK" if ok else "link FAILED")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
