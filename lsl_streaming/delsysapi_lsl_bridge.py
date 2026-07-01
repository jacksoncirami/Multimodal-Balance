from pathlib import Path
import time
import numpy as np

from pylsl import StreamInfo, StreamOutlet

from pythonnet import load
load("coreclr")

import clr
clr.AddReference("resources\\DelsysAPI")
clr.AddReference("System.Collections")

from Aero import AeroPy


# ------------------------------------------------------------
# 1. Load key/license files
# ------------------------------------------------------------

key = Path("DelsysAPI.key").read_text(encoding="utf-8").strip()
license = Path("DelsysAPI.lic").read_text(encoding="utf-8").strip()


# ------------------------------------------------------------
# 2. LSL settings
# ------------------------------------------------------------

LSL_STREAM_NAME = "Delsys_Trigno_EMG"
LSL_STREAM_TYPE = "EMG"
LSL_SOURCE_ID = "Delsys_Trigno_01"

ONLY_EMG = True


# ------------------------------------------------------------
# 3. Connect to Delsys API
# ------------------------------------------------------------

print("Creating Delsys API object...")
trig = AeroPy()

print("Validating base with key/license...")
trig.ValidateBase(key, license)

receiver_type = trig.GetTrignoReceiverType()
print(f"Connected receiver type: {receiver_type}")

print("Scanning sensors...")

try:
    # Common scan call used by the Delsys example style
    trig.ScanSensors(False, []).Result
except Exception as e:
    print("First scan method failed, trying alternate scan...")
    try:
        trig.ScanSensors().Result
    except Exception as e2:
        raise RuntimeError(f"Sensor scan failed: {e2}")

trig.SelectAllSensors()

sensors = trig.GetSensors()

if len(sensors) == 0:
    raise RuntimeError("No sensors found. Turn sensors on and make sure they are paired/nearby.")

print(f"Found {len(sensors)} sensor(s).")


# ------------------------------------------------------------
# 4. Print sensors/channels and collect EMG channel GUIDs
# ------------------------------------------------------------

channel_guids = []
channel_names = []
sample_rates = []

for sensor_index in range(len(sensors)):
    sensor_name = sensors[sensor_index].FriendlyName
    mode = trig.GetCurrentSensorMode(sensor_index)

    print(f"\nSensor {sensor_index}: {sensor_name}")
    print(f"Mode: {mode}")

    channel_info = trig.GetSensorChannelInfo(sensor_index)

    for c in channel_info:
        channel_name = str(c["Name"])
        enabled = str(c["Enabled"]) == "True"
        channel_type = str(c["Type"])
        sample_rate = float(c["Sample Rate"])
        guid = str(c["Guid"])

        print(f"  {channel_name} | {channel_type} | enabled={enabled} | {sample_rate} Hz")

        if not enabled:
            continue

        if ONLY_EMG:
            if channel_type.upper() != "EMG" and "EMG" not in channel_name.upper():
                continue

        channel_guids.append(guid)
        channel_names.append(channel_name)
        sample_rates.append(sample_rate)

if len(channel_guids) == 0:
    raise RuntimeError("No EMG channels selected. Try setting ONLY_EMG = False.")

num_channels = len(channel_guids)
lsl_sample_rate = sample_rates[0] if len(sample_rates) > 0 else 0

print("\nSelected channels for LSL:")
for i, name in enumerate(channel_names):
    print(f"{i + 1}: {name} | {sample_rates[i]} Hz")


# ------------------------------------------------------------
# 5. Configure Delsys collection
# ------------------------------------------------------------

print("\nConfiguring Delsys pipeline...")

try:
    trig.Configure()
except Exception as e:
    raise RuntimeError(f"Configure failed: {e}")

if not trig.IsPipelineConfigured():
    raise RuntimeError("Pipeline did not configure correctly.")

print("Delsys pipeline configured.")


# ------------------------------------------------------------
# 6. Create LSL outlet
# ------------------------------------------------------------

info = StreamInfo(
    LSL_STREAM_NAME,
    LSL_STREAM_TYPE,
    num_channels,
    lsl_sample_rate,
    "float32",
    LSL_SOURCE_ID
)

desc = info.desc()
desc.append_child_value("manufacturer", "Delsys")
desc.append_child_value("source", "Delsys API Python")
desc.append_child_value("receiver_type", str(receiver_type))

channels = desc.append_child("channels")

for i, name in enumerate(channel_names):
    ch = channels.append_child("channel")
    ch.append_child_value("label", name)
    ch.append_child_value("type", "EMG")
    ch.append_child_value("unit", "unknown")
    ch.append_child_value("channel_index", str(i + 1))

outlet = StreamOutlet(info)

print(f'\nLSL stream "{LSL_STREAM_NAME}" is now broadcasting.')
print("Open LabRecorder and look for Delsys_Trigno_EMG.")


# ------------------------------------------------------------
# 7. Start streaming
# ------------------------------------------------------------

print("\nStarting Delsys stream...")
trig.Start(False)

print("Streaming Delsys EMG to LSL.")
print("Press Ctrl+C to stop.\n")

samples_sent = 0
last_print_time = time.time()

try:
    while True:
        if trig.CheckDataQueue():
            data_out = trig.PollDataByString()

            if len(list(data_out.Keys)) == 0:
                continue

            channel_arrays = []

            for guid in channel_guids:
                values = np.asarray(data_out[guid], dtype=np.float32)
                channel_arrays.append(values)

            min_len = min(len(arr) for arr in channel_arrays)

            if min_len == 0:
                continue

            chunk = []

            for sample_index in range(min_len):
                sample = [float(channel_arrays[ch][sample_index]) for ch in range(num_channels)]
                chunk.append(sample)

            outlet.push_chunk(chunk)
            samples_sent += len(chunk)

        else:
            time.sleep(0.001)

        if time.time() - last_print_time > 5:
            print(f"Samples sent to LSL: {samples_sent}")
            last_print_time = time.time()

except KeyboardInterrupt:
    print("\nStopping...")

finally:
    try:
        trig.Stop()
        print("Delsys stream stopped.")
    except Exception as e:
        print(f"Could not stop cleanly: {e}")

    try:
        trig.ResetPipeline()
        print("Pipeline reset.")
    except Exception as e:
        print(f"Could not reset pipeline: {e}")
