# Delsys Trigno EMG to LSL Bridge

This folder contains the Python bridge used to acquire enabled Delsys Trigno
EMG channels through the manufacturer-provided Delsys Python API and broadcast
the data through Lab Streaming Layer (LSL).

The bridge:

- Connects to a Delsys Trigno system
- Detects enabled EMG channels
- Creates an LSL stream (`Delsys_Trigno_EMG`)
- Streams synchronized EMG data to any LSL-compatible application
- Cleans up the Delsys pipeline when the program exits

This bridge was developed as part of the multimodal EEG–EMG–force plate
synchronization workflow included in this repository.

---

## Included File

| File | Description |
|------|-------------|
| `delsysapi_lsl_bridge.py` | Streams enabled Delsys Trigno EMG channels to LSL. |

---

## Important Notice

This repository contains only the custom LSL bridge.

The proprietary Delsys API, Python packages, assemblies, license files, and
credentials are **not** included and must be obtained through an authorized
Delsys installation.

---

## Requirements

- Windows
- Python
- Delsys Trigno hardware
- Delsys Python Example Applications
- Aero / AeroPy
- Delsys API assembly
- Valid Delsys key and license
- NumPy
- pythonnet
- pylsl
- LabRecorder

---

## Tested Software Versions

| Component | Version |
|---|---|
| Windows | Windows 11 |
| Python | |
| Delsys API | |
| Delsys software | |
| pythonnet | |
| NumPy | |
| pylsl | |
| .NET runtime | |
| LabRecorder | |

---

## Folder Structure

The bridge is intended to run from the Python directory of the Delsys Example
Applications package (or an equivalent directory containing the required
packages and resources).

Required imports:

```python
from Aero import AeroPy
from AeroPy.TrignoBase import key, license

clr.AddReference("resources\\DelsysAPI")
```

---

## Configuration

The primary user-adjustable settings are:

```python
LSL_STREAM_NAME = "Delsys_Trigno_EMG"
LSL_STREAM_TYPE = "EMG"
LSL_SOURCE_ID = "Delsys_Trigno_01"

ONLY_EMG = True
```

The bridge automatically discovers enabled sensors and streams enabled EMG
channels. Channel indices do not normally need to be edited.

---

## Running

```text
python delsysapi_lsl_bridge.py
```

A successful startup should:

- Detect connected sensors
- List selected EMG channels
- Create the `Delsys_Trigno_EMG` LSL stream
- Begin streaming data

Verify that the stream appears in LabRecorder before beginning data collection.
