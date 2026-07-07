using System;
using LSL;

namespace BertecExampleNET
{
    class SimpleFZReaderExample
    {
        BertecDeviceNET.BertecDevice theHandle = null;

        int fzChannelIndex = -1;
        bool devicesAreaReady = false;
        bool demoImmediateDeviceDataHandler = false;

        // -----------------------------
        // LSL variables
        // -----------------------------
        liblsl.StreamOutlet lslOutlet = null;
        float[] lslSample = new float[1];

        static void Main(string[] args)
        {
            SimpleFZReaderExample example = new SimpleFZReaderExample();
            example.Run();
        }

        public void Run()
        {
            Console.WriteLine("Bertec force plate to LSL bridge.");
            Console.WriteLine("Streaming Fz to LabRecorder as: BertecForcePlate");
            Console.WriteLine("Press ESC or Space to exit.\n");

            InitLSL();

            if (InitLibrary() != 0)
                return;

            int c = 0;
            while ((c = Console.ReadKey().KeyChar) != 3)
            {
                if (c == 27 || c == 32)
                    break;

                System.Threading.Thread.Sleep(15);
            }

            CloseLibrary();
        }

        // -----------------------------
        // Initialize LSL stream
        // -----------------------------
        void InitLSL()
        {
            liblsl.StreamInfo info = new liblsl.StreamInfo(
                "BertecForcePlate",                  // stream name
                "Force",                             // stream type
                1,                                   // channel count: only Fz for now
                1000.0,                              // Bertec hardware rate
                liblsl.channel_format_t.cf_float32,  // data type
                "bertec_force_plate_fz_001"          // unique source ID
            );

            liblsl.XMLElement channels = info.desc().append_child("channels");
            liblsl.XMLElement ch = channels.append_child("channel");

            ch.append_child_value("label", "Fz");
            ch.append_child_value("unit", "N");
            ch.append_child_value("type", "ForcePlate");

            lslOutlet = new liblsl.StreamOutlet(info);

            Console.WriteLine("LSL stream created: BertecForcePlate");
            Console.WriteLine("Open LabRecorder and look for this stream.\n");
        }

        int InitLibrary()
        {
            devicesAreaReady = false;
            fzChannelIndex = -1;

            try
            {
                theHandle = new BertecDeviceNET.BertecDevice();
            }
            catch (System.Exception)
            {
                Console.WriteLine("Unable to initialize the Bertec Device Library.");
                Console.WriteLine("Possible missing FTD2XX install or missing DLLs.");
                return -1;
            }

            theHandle.OnStatus += StatusHandler;

            if (demoImmediateDeviceDataHandler)
                theHandle.OnImmediateDeviceData += ImmediateDeviceDataHandler;
            else
                theHandle.OnDataStream += DataHandler;

            theHandle.Start();

            return 0;
        }

        void CloseLibrary()
        {
            devicesAreaReady = false;

            if (theHandle != null)
            {
                theHandle.OnStatus -= StatusHandler;
                theHandle.OnDataStream -= DataHandler;
                theHandle.OnImmediateDeviceData -= ImmediateDeviceDataHandler;

                try
                {
                    theHandle.StopDataStream();
                }
                catch
                {
                    // Ignore if stream is already stopped
                }

                theHandle.Stop();
                theHandle.Dispose();
            }

            theHandle = null;
            lslOutlet = null;

            Console.WriteLine("\nBertec and LSL bridge closed.");
        }

        void RedetectDevices()
        {
            theHandle.RedetectConnectedDevices();
        }

        void ChangeResamplingRate(int resampleRate)
        {
            int numDevices = theHandle.DeviceCount;

            for (int devIndex = 0; devIndex < numDevices; ++devIndex)
                theHandle.SetDataRateResampling(devIndex, resampleRate);
        }

        void FindFzIndex()
        {
            int deviceCount = theHandle.DeviceCount;

            string[] channelNamesForDevice0 = theHandle.DeviceChannelNames(0);
            int channelCountForDevice0 = channelNamesForDevice0.Length;

            fzChannelIndex = -1;

            for (int channelIndex = 0; channelIndex < channelCountForDevice0; ++channelIndex)
            {
                if (String.Equals(channelNamesForDevice0[channelIndex], "FZ", StringComparison.OrdinalIgnoreCase))
                {
                    fzChannelIndex = channelIndex;
                    break;
                }
            }

            if (fzChannelIndex >= 0)
                Console.WriteLine("FZ channel found at index: {0}", fzChannelIndex);
            else
                Console.WriteLine("WARNING: FZ channel was not found.");
        }

        void StatusHandler(BertecDeviceNET.StatusErrors status)
        {
            switch (status)
            {
                case BertecDeviceNET.StatusErrors.LOOKING_FOR_DEVICES:
                    Console.WriteLine("\nSearching for connected devices");
                    devicesAreaReady = false;
                    fzChannelIndex = -1;
                    break;

                case BertecDeviceNET.StatusErrors.NO_DEVICES_FOUND:
                    Console.WriteLine("\nNo devices found");
                    devicesAreaReady = false;
                    fzChannelIndex = -1;
                    break;

                case BertecDeviceNET.StatusErrors.DEVICES_READY:
                    {
                        Console.WriteLine("\nDevices found and ready");

                        for (int devNum = 0; devNum < theHandle.DeviceCount; ++devNum)
                        {
                            Console.WriteLine(
                                "Plate serial {0}, {1}",
                                theHandle.DeviceSerialNumber(devNum),
                                theHandle.DeviceIDString(devNum)
                            );
                        }

                        System.Threading.Tasks.Task.Run(() =>
                        {
                            BertecDeviceNET.DataStreamControl streamControl =
                                new BertecDeviceNET.DataStreamControl();

                            streamControl.syncPinMode =
                                BertecDeviceNET.DataStreamControl.SyncPinMode.NONE;

                            streamControl.auxPinMode =
                                BertecDeviceNET.DataStreamControl.AuxPinMode.NONE;

                            streamControl.deviceFilterBitmask = 0;
                            streamControl.internalClockSource = 0;
                            streamControl.internalClockFrequency = 0;

                            Console.WriteLine("\nStarting Bertec data stream...");

                            theHandle.StartDataStream(streamControl);

                            Console.WriteLine("Bertec data stream started.");

                            FindFzIndex();

                            theHandle.AutoZeroing = true;

                            devicesAreaReady = true;
                        });

                        break;
                    }

                case BertecDeviceNET.StatusErrors.NO_DATA_RECEIVED:
                    Console.WriteLine("\nNo data being received");
                    devicesAreaReady = false;
                    fzChannelIndex = -1;
                    break;

                case BertecDeviceNET.StatusErrors.DEVICE_HAS_FAULTED:
                    Console.WriteLine("\nDevice has faulted");
                    devicesAreaReady = false;
                    fzChannelIndex = -1;
                    break;

                case BertecDeviceNET.StatusErrors.AUTOZEROSTATE_WORKING:
                    Console.WriteLine("\nDetermining autozero");
                    break;

                case BertecDeviceNET.StatusErrors.AUTOZEROSTATE_ZEROFOUND:
                    Console.WriteLine("\nAutozero found");
                    break;

                default:
                    Console.WriteLine("\nStatus: {0}", status);
                    break;
            }
        }

        void DataHandler(BertecDeviceNET.DataFrame[] dataFrames)
        {
            if (devicesAreaReady)
            {
                for (int deviceNumber = 0; deviceNumber < dataFrames.Length; ++deviceNumber)
                {
                    if (deviceNumber == 0)
                    {
                        BertecDeviceNET.DataFrame deviceData = dataFrames[deviceNumber];

                        if (deviceData.forceData.Length > 0)
                        {
                            Console.Write("\rTimestamp: {0}  ", deviceData.timestamp);

                            if (fzChannelIndex >= 0 && fzChannelIndex < deviceData.forceData.Length)
                            {
                                double fz = deviceData.forceData[fzChannelIndex];

                                Console.Write("Fz: {0}                  ", fz);

                                // -----------------------------
                                // Push Fz to LSL
                                // -----------------------------
                                if (lslOutlet != null)
                                {
                                    lslSample[0] = (float)fz;
                                    lslOutlet.push_sample(lslSample);
                                }
                            }

                            Console.Out.Flush();
                        }
                    }
                }
            }
        }

        void ImmediateDeviceDataHandler(
            int deviceIndex,
            string deviceUid,
            BertecDeviceNET.DataFrame deviceData
        )
        {
            if (devicesAreaReady)
            {
                Console.Write("\r[I]{0}, {1}, {2}", deviceIndex, deviceUid, deviceData.timestamp);

                if (fzChannelIndex >= 0 && fzChannelIndex < deviceData.forceData.Length)
                {
                    double fz = deviceData.forceData[fzChannelIndex];

                    Console.Write(": Fz {0}                  ", fz);

                    if (lslOutlet != null)
                    {
                        lslSample[0] = (float)fz;
                        lslOutlet.push_sample(lslSample);
                    }
                }

                Console.Out.Flush();
            }
        }
    }
}
