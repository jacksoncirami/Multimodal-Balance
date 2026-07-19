# MATLAB LSL Marker Interfaces

This folder contains the MATLAB graphical interfaces used to broadcast event
markers through Lab Streaming Layer (LSL) during multimodal physiological
data collection.

Two independent marker interfaces are included:

- **Task Marker GUI** — used during experimental trials to record task and
  artifact events.
- **MVC Marker GUI** — used during impedance testing, maximum voluntary
  contraction (MVC) trials, rest periods, and muscle identification.

Both interfaces broadcast user-selected markers as LSL string events and
were developed as part of the multimodal EEG–EMG–force plate synchronization
workflow included in this repository.

---

## Included Files

| File | Description |
|------|-------------|
| `task_marker_gui.m` | Broadcasts task and artifact markers through the `TaskMarkers` LSL stream. |
| `mvc_marker_gui.m` | Broadcasts impedance, MVC, rest, and muscle-label markers through the `MVCMarkers` LSL stream. |

---

## Requirements

- MATLAB
- liblsl-Matlab
- Lab Streaming Layer (LSL)
- LabRecorder

---

## Tested Software Versions

| Component | Version |
|---|---|
| MATLAB | UPDATE WITH TESTED VERSION |
| liblsl-Matlab | UPDATE WITH TESTED VERSION |
| LabRecorder | UPDATE WITH TESTED VERSION |

---

## Configuration

If `liblsl-Matlab` is not already available on the MATLAB path, update the
following variable near the top of each script:

```matlab
lslPath = 'C:\path\to\liblsl-Matlab';
```

When `lsl_loadlib` is already available on the MATLAB path, this setting is
not used.

---

## Marker Streams

### Task Marker GUI

| Property | Value |
|---|---|
| Stream Name | `TaskMarkers` |
| Stream Type | `Markers` |
| Channels | `1` |
| Data Format | `cf_string` |
| Source ID | `task_marker_gui_001` |

Available markers:

- Trial Start
- Trial End
- Blinking
- Jaw Clench
- Talking
- Bad Movement
- Eyes Open
- Eyes Closed
- One Leg
- Dual Task
- Step Initiation

---

### MVC Marker GUI

| Property | Value |
|---|---|
| Stream Name | `MVCMarkers` |
| Stream Type | `Markers` |
| Channels | `1` |
| Data Format | `cf_string` |
| Source ID | `mvc_marker_gui_001` |

Available markers:

- Impedance Test Start
- Impedance Test End
- MVC Start
- MVC End
- Rest Start
- Rest End
- TA
- PL
- GM
- GL

---

## Running

Run either script from the MATLAB Editor or Command Window:

```matlab
task_marker_gui
```

or

```matlab
mvc_marker_gui
```

After the interface opens:

1. Verify that the corresponding LSL stream appears in LabRecorder.
2. Confirm that button presses generate marker events.
3. Begin data collection.

---

## Notes

These interfaces broadcast only event markers and do not acquire
physiological data directly.

The marker streams are intended to be recorded simultaneously with the EEG,
EMG, and force plate streams using LabRecorder or another LSL-compatible
recording application.

Both marker interfaces use separate stream names and source IDs so they can
operate independently during the same recording session.
