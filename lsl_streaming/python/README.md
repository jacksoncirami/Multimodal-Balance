# Delsys Trigno EMG to LSL Bridge

This folder contains the Python bridge used to acquire enabled Delsys Trigno
EMG channels through the manufacturer-provided Delsys API and broadcast the
data through Lab Streaming Layer (LSL).

## Included Script

- `delsysapi_lsl_bridge.py`

The script:

1. Connects to the Delsys Trigno system through the Delsys Python API.
2. Validates the connected base station using an authorized Delsys key and
   license.
3. Scans for available sensors.
4. Identifies enabled EMG channels.
5. Creates an LSL stream named `Delsys_Trigno_EMG`.
6. Continuously forwards acquired EMG samples to LSL.
7. Stops and resets the Delsys acquisition pipeline when the user presses
   `Ctrl+C`.

## Important Limitation

The Python script in this repository is not a standalone Delsys application.

It depends on manufacturer-provided Delsys API files, assemblies, packages,
and credentials that are not included in this repository. Future users must
obtain authorized access to those materials from Delsys.

Do not copy or redistribute proprietary Delsys API files, license files,
keys, or credentials through this repository.

## Requirements

The tested workflow requires:

- Windows
- A compatible Python installation
- A compatible .NET runtime
- The Delsys Trigno system and required Delsys software
- The Delsys Python Example Applications files
- The Delsys `Aero` and `AeroPy` Python packages
- The Delsys API assembly
- A valid Delsys key and license
- NumPy
- pylsl
- pythonnet
- LabRecorder or another compatible LSL recording application

## Tested Software Versions

Complete this section using the versions installed on the acquisition
computer.

| Component | Tested version |
|---|---|
| Windows | UPDATE WITH TESTED VERSION |
| Python | UPDATE WITH TESTED VERSION |
| Delsys API / Example Applications | UPDATE WITH TESTED VERSION |
| Delsys software | UPDATE WITH TESTED VERSION |
| pythonnet | UPDATE WITH TESTED VERSION |
| NumPy | UPDATE WITH TESTED VERSION |
| pylsl | UPDATE WITH TESTED VERSION |
| .NET runtime | UPDATE WITH TESTED VERSION |
| LabRecorder | UPDATE WITH TESTED VERSION |

## Required Delsys Folder Structure

The bridge was designed to run from the Python directory of the
manufacturer-provided Delsys Example Applications package, or from another
directory containing the same required structure.

The working directory must contain the Delsys packages and resource files
required by the following imports and assembly reference:

```python
from Aero import AeroPy
from AeroPy.TrignoBase import key, license
clr.AddReference("resources\\DelsysAPI")
