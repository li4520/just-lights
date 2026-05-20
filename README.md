# Just Lights

Just Lights is an unofficial Garmin Connect IQ data field for controlling compatible paired ANT+ bike lights from a full-page Edge activity screen.

It only sends bike-light mode commands through the Connect IQ ANT+ light APIs. It does not provide radar alerts, vehicle detection, incident detection, proximity warnings, or any other safety-awareness feature.

## Status

- Project type: Garmin Connect IQ data field
- App name: `Just Lights`
- Version: `0.1.0`
- Minimum SDK: `3.3.0`
- Permission: `Ant`
- Store status: not listed in the Connect IQ Store
- Distribution: source code and unofficial sideload builds from GitHub Releases

This project is not affiliated with, sponsored by, or approved by Garmin.

## Supported Targets

Release builds are prepared for these touchscreen Edge targets:

- `edge1050`
- `edge1040`
- `edge850`
- `edge840`
- `edgeexplore2` - experimental until more layout/tap comfort testing is done

Button-only Edge devices are out of scope for the current touchscreen-first build.

## Compatibility

Just Lights is intended for compatible ANT+ bike lights that report the standard light modes used by this app:

- `Off`
- `Solid`
- `Peloton`
- `Night Flash`
- `Day Flash`

Other lights may work if they expose the same compatible ANT+ light-mode capability shape. The app fails closed when the current primary tail light does not report a compatible mode profile.

## Install A Sideload Build

1. Download the `.prg` file for your exact Edge device from GitHub Releases.
2. Connect the Edge to your computer by USB.
3. Copy the `.prg` file into the device's `GARMIN/APPS` folder.
4. Disconnect/eject the Edge safely.
5. Pair your ANT+ bike light using the normal device sensor/light setup.
6. Add `Just Lights` as the only field on an activity data page.

Use the build that matches your device model. A `.prg` compiled for one target may not run correctly on another target.

## Build From Source

Install the Garmin Connect IQ SDK with Garmin SDK Manager, then create or point to a local Connect IQ developer key.

Build the default target:

```bash
CIQ_DEVELOPER_KEY=/path/to/developer_key scripts/build.sh
```

Build a specific target:

```bash
CIQ_DEVELOPER_KEY=/path/to/developer_key scripts/build.sh edge1040
```

Build every supported target:

```bash
CIQ_DEVELOPER_KEY=/path/to/developer_key scripts/build.sh all
```

Compiled files are written to `build/bin/`.

## Test

Build the unit-test app:

```bash
CIQ_DEVELOPER_KEY=/path/to/developer_key scripts/test.sh --build-only edge1050
```

Run unit tests in the Connect IQ simulator:

```bash
CIQ_DEVELOPER_KEY=/path/to/developer_key scripts/test.sh edge1050
```

Tests are pure Monkey C logic tests. They do not contact real ANT+ hardware or any network service.

## Package Release Assets

```bash
CIQ_DEVELOPER_KEY=/path/to/developer_key scripts/package-release.sh 0.1.0
```

The package helper builds all supported targets, stages renamed `.prg` files under `build/release/v0.1.0/`, and writes `SHA256SUMS.txt`.

## Safety And Responsibility

Use this project at your own risk. Always confirm your light behavior directly and follow local traffic laws and riding-safety practices. This app is a convenience light-mode controller, not a safety system.
