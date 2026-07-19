# Delsys Trigno EMG to LSL Bridge

This folder contains the Python bridge used to stream Delsys Trigno EMG data
to Lab Streaming Layer (LSL) using the manufacturer-provided Delsys Python
API.

The included bridge automatically:

- Connects to a Delsys Trigno system
- Validates the connected base station using an authorized key and license
- Detects connected sensors
- Identifies enabled EMG channels
- Creates an LSL stream named `Delsys_Trigno_EMG`
- Continuously broadcasts synchronized EMG data through LSL
- Stops and resets the Delsys acquisition pipeline when the user exits the
  program

This bridge was developed and tested as part of the multimodal EEG–EMG–force
plate synchronization pipeline included in this repository.

---

## Included Files

| File | Description |
|------|-------------|
| `delsysapi_lsl_bridge.py` | Streams enabled Delsys Trigno EMG channels to Lab Streaming Layer. |

---

## Important Notice

This repository contains **only the custom LSL bridge** developed for this
project.

It does **not** include proprietary Delsys software components such as:

- Delsys Python Example Applications
- Aero and AeroPy packages
- Delsys API assemblies
- License files
- Authorization keys
- Other proprietary Delsys resources

These components must be obtained directly from Delsys and configured locally
before the bridge can be used.

---

## Requirements

The tested workflow requires:

- Windows
- Python
- Compatible .NET runtime
- Delsys Trigno hardware
- Delsys Python Example Applications
- Aero and AeroPy packages
- Delsys API assemblies
- Valid Delsys key and license
- NumPy
- pythonnet
- pylsl
- LabRecorder (or another LSL-compatible recorder)

---

## Tested Software Versions

| Component | Tested Version |
|------------|----------------|
| Windows | UPDATE WITH TESTED VERSION |
| Python | UPDATE WITH TESTED VERSION |
| Delsys API / Example Applications | UPDATE WITH TESTED VERSION |
| Delsys software | UPDATE WITH TESTED VERSION |
| pythonnet | UPDATE WITH TESTED VERSION |
| NumPy | UPDATE WITH TESTED VERSION |
| pylsl | UPDATE WITH TESTED VERSION |
| .NET runtime | UPDATE WITH TESTED VERSION |
| LabRecorder | UPDATE WITH TESTED VERSION |

---

## Folder Structure

The bridge is designed to run from the Python directory of the
manufacturer-provided Delsys Example Applications package (or another
environment containing the same required folder structure).

The working directory must provide the packages and resources referenced by:

```python
from Aero import AeroPy
from AeroPy.TrignoBase import key, license
clr.AddReference("resources\\DelsysAPI")
```
