# Bertec Force Plate to LSL Bridge

This folder contains the C# bridge used to acquire force-plate data through
the Bertec SDK and broadcast the data through Lab Streaming Layer (LSL).

The bridge:

- Connects to the Bertec SDK
- Detects the required Bertec force and moment channels
- Performs a software tare before acquisition
- Computes right, left, and combined center-of-pressure (COP) values
- Estimates center-of-gravity (COG) position
- Creates an LSL stream named `BertecForcePlate`
- Continuously streams synchronized force-plate data through LSL

This bridge was developed as part of the multimodal EEG–EMG–force plate
synchronization workflow included in this repository.

---

## Included Files

| File | Description |
|------|-------------|
| `bertecsdk_lsl_bridge.cs` | Streams Bertec force-plate data through Lab Streaming Layer. |

---

## Important Notice

This repository contains only the custom Bertec-to-LSL bridge developed for
this project.

It does **not** include proprietary Bertec software components such as:

- Bertec SDK libraries
- `BertecDeviceNET`
- Visual Studio project files supplied by Bertec
- License-protected Bertec components

These materials must be obtained directly from Bertec and configured locally
before the bridge can be compiled or executed.

---

## Requirements

- Windows
- Microsoft Visual Studio
- Bertec SDK
- `BertecDeviceNET`
- LSL C# library (`LSL.cs`)
- `lsl.dll`
- Lab Streaming Layer (LSL)
- LabRecorder (used for validation)

---

## Tested Software Versions

| Component | Version |
|---|---|
| Windows | |
| Visual Studio | |
| Bertec SDK | |
| .NET Framework / Runtime | |
| liblsl | |
| LabRecorder | |

---

## Configuration

The bridge expects the following Bertec SDK channels to be available:

- FZR
- MXR
- MYR
- FZL
- MXL
- MYL
- FZ
- MX
- MY

The default LSL stream properties are:

| Property | Value |
|---|---|
| Stream Name | `BertecForcePlate` |
| Stream Type | `Force` |
| Source ID | `bertec_force_plate_001` |
| Sampling Rate | 1000 Hz |

Before data collection:

- Keep the force plate unloaded during the software-tare period.
- Enter the participant height when prompted.
- Verify that the `BertecForcePlate` stream appears in LabRecorder.

---

## Output Channels

The bridge streams the following channels in order:

1. FZR
2. MXR
3. MYR
4. FZL
5. MXL
6. MYL
7. FZ
8. MX
9. MY
10. COPXR
11. COPYR
12. COPXL
13. COPYL
14. COPX
15. COPY
16. COGX_est
17. COGY_est
18. COG_est

The estimated COG channels are derived from the measured force-plate data and
are not direct measurements.

---

## Running

Compile the Visual Studio project containing the bridge and the required
Bertec and LSL dependencies.

Run the executable.

A successful startup should:

- Connect to the Bertec SDK
- Detect the required channels
- Perform the software tare
- Create the `BertecForcePlate` LSL stream
- Begin streaming data

Verify that the stream appears in LabRecorder before beginning data
collection.

---

## Notes

The bridge currently streams data from the first detected Bertec device.

The output channel order is fixed and should remain synchronized with any
downstream analysis scripts that consume the recorded LSL stream.
