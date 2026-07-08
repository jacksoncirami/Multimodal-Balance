#nullable disable

using System;

namespace BertecExampleNET
{
    class SimpleFZReaderExample
    {
        BertecDeviceNET.BertecDevice theHandle = null;

        bool devicesAreaReady = false;
        bool demoImmediateDeviceDataHandler = false;

        string[] sdkChannelNames = null;

        int idxFZR = -1;
        int idxMXR = -1;
        int idxMYR = -1;
        int idxFZL = -1;
        int idxMXL = -1;
        int idxMYL = -1;
        int idxFZ  = -1;
        int idxMX  = -1;
        int idxMY  = -1;

        LSL.StreamOutlet lslOutlet = null;
        float[] lslSample = null;

        readonly string[] outputChannelNames =
        {
            "FZR", "MXR", "MYR",
            "FZL", "MXL", "MYL",
            "FZ",  "MX",  "MY",
            "COPXR", "COPYR",
            "COPXL", "COPYL",
            "COPX",  "COPY"
        };

        int printCounter = 0;

        static void Main(string[] args)
        {
            SimpleFZReaderExample example = new SimpleFZReaderExample();
            example.Run();
        }

        public void Run()
        {
            Console.WriteLine("=================================================");
            Console.WriteLine("Bertec Force Plate to LSL Bridge");
            Console.WriteLine("Streams raw force/moment channels + computed COP.");
            Console.WriteLine("LSL stream name: BertecForcePlate");
            Console.WriteLine("Press ESC or Space to stop.");
            Console.WriteLine("=================================================\n");

            if (InitLibrary() != 0)
            {
                Console.WriteLine("Bertec SDK initialization failed.");
                Console.WriteLine("Press any key to close.");
                Console.ReadKey();
                return;
            }

            int c = 0;

            while ((c = Console.ReadKey(true).KeyChar) != 3)
            {
                if (c == 27 || c == 32)
                    break;

                System.Threading.Thread.Sleep(15);
            }

            CloseLibrary();
        }

        int InitLibrary()
        {
            devicesAreaReady = false;
            sdkChannelNames = null;
            lslOutlet = null;
            lslSample = null;

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

                theHandle.Stop();
                theHandle.Dispose();
            }

            theHandle = null;
            lslOutlet = null;
            lslSample = null;

            Console.WriteLine("\nBertec-to-LSL bridge closed.");
        }

        bool SetupChannelsAndLSL()
        {
            sdkChannelNames = theHandle.DeviceChannelNames(0);

            if (sdkChannelNames == null || sdkChannelNames.Length == 0)
            {
                Console.WriteLine("WARNING: No Bertec SDK channels found.");
                return false;
            }

            Console.WriteLine("\nBertec SDK channels found:");

            for (int i = 0; i < sdkChannelNames.Length; i++)
            {
                Console.WriteLine("SDK channel {0}: {1}", i, sdkChannelNames[i]);
            }

            idxFZR = FindChannelIndex("FZR");
            idxMXR = FindChannelIndex("MXR");
            idxMYR = FindChannelIndex("MYR");

            idxFZL = FindChannelIndex("FZL");
            idxMXL = FindChannelIndex("MXL");
            idxMYL = FindChannelIndex("MYL");

            idxFZ = FindChannelIndex("FZ");
            idxMX = FindChannelIndex("MX");
            idxMY = FindChannelIndex("MY");

            if (idxFZR < 0 || idxMXR < 0 || idxMYR < 0 ||
                idxFZL < 0 || idxMXL < 0 || idxMYL < 0 ||
                idxFZ  < 0 || idxMX  < 0 || idxMY  < 0)
            {
                Console.WriteLine("\nERROR: One or more required raw channels were not found.");
                Console.WriteLine("Required: FZR, MXR, MYR, FZL, MXL, MYL, FZ, MX, MY");
                return false;
            }

            LSL.StreamInfo info = new LSL.StreamInfo(
                "BertecForcePlate",
                "Force",
                outputChannelNames.Length,
                1000.0,
                LSL.channel_format_t.cf_float32,
                "bertec_force_plate_raw_plus_cop_001"
            );

            LSL.XMLElement channels = info.desc().append_child("channels");

            for (int i = 0; i < outputChannelNames.Length; i++)
            {
                string label = outputChannelNames[i];

                LSL.XMLElement ch = channels.append_child("channel");
                ch.append_child_value("label", label);
                ch.append_child_value("type", "ForcePlate");
                ch.append_child_value("unit", GuessUnit(label));
            }

            lslSample = new float[outputChannelNames.Length];
            lslOutlet = new LSL.StreamOutlet(info);

            Console.WriteLine("\nLSL stream created.");
            Console.WriteLine("Name: BertecForcePlate");
            Console.WriteLine("Type: Force");
            Console.WriteLine("Sampling rate: 1000 Hz");
            Console.WriteLine("Output channel count: {0}", outputChannelNames.Length);

            Console.WriteLine("\nOutput channels:");
            for (int i = 0; i < outputChannelNames.Length; i++)
            {
                Console.WriteLine("LSL channel {0}: {1}", i, outputChannelNames[i]);
            }

            Console.WriteLine("\nOpen LabRecorder and select: BertecForcePlate\n");

            return true;
        }

        int FindChannelIndex(string targetName)
        {
            for (int i = 0; i < sdkChannelNames.Length; i++)
            {
                if (String.Equals(sdkChannelNames[i], targetName, StringComparison.OrdinalIgnoreCase))
                    return i;
            }

            return -1;
        }

        string GuessUnit(string channelName)
        {
            string upper = channelName.ToUpper();

            if (upper.StartsWith("F"))
                return "N";

            if (upper.StartsWith("M"))
                return "Nm";

            if (upper.StartsWith("COP"))
                return "computed";

            return "unknown";
        }

        void StatusHandler(BertecDeviceNET.StatusErrors status)
        {
            switch (status)
            {
                case BertecDeviceNET.StatusErrors.LOOKING_FOR_DEVICES:
                    Console.WriteLine("\nSearching for connected Bertec devices...");
                    devicesAreaReady = false;
                    break;

                case BertecDeviceNET.StatusErrors.NO_DEVICES_FOUND:
                    Console.WriteLine("\nNo Bertec devices found.");
                    devicesAreaReady = false;
                    break;

                case BertecDeviceNET.StatusErrors.DEVICES_READY:
                {
                    Console.WriteLine("\nDevices found and ready.");

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

                        bool setupWorked = SetupChannelsAndLSL();

                        if (setupWorked)
                        {
                            theHandle.AutoZeroing = true;
                            devicesAreaReady = true;

                            Console.WriteLine("\nBridge is running.");
                        }
                        else
                        {
                            devicesAreaReady = false;
                            Console.WriteLine("\nBridge setup failed.");
                        }
                    });

                    break;
                }

                case BertecDeviceNET.StatusErrors.NO_DATA_RECEIVED:
                    Console.WriteLine("\nNo data being received.");
                    devicesAreaReady = false;
                    break;

                case BertecDeviceNET.StatusErrors.DEVICE_HAS_FAULTED:
                    Console.WriteLine("\nBertec device has faulted.");
                    devicesAreaReady = false;
                    break;

                case BertecDeviceNET.StatusErrors.AUTOZEROSTATE_WORKING:
                    Console.WriteLine("\nDetermining autozero...");
                    break;

                case BertecDeviceNET.StatusErrors.AUTOZEROSTATE_ZEROFOUND:
                    Console.WriteLine("\nAutozero found.");
                    break;

                default:
                    Console.WriteLine("\nStatus: {0}", status);
                    break;
            }
        }

        void DataHandler(BertecDeviceNET.DataFrame[] dataFrames)
        {
            if (!devicesAreaReady)
                return;

            if (lslOutlet == null || lslSample == null)
                return;

            for (int deviceNumber = 0; deviceNumber < dataFrames.Length; ++deviceNumber)
            {
                if (deviceNumber != 0)
                    continue;

                BertecDeviceNET.DataFrame deviceData = dataFrames[deviceNumber];

                if (deviceData.forceData == null || deviceData.forceData.Length <= 0)
                    return;

                BuildOutputSample(deviceData.forceData);

                lslOutlet.push_sample(lslSample);

                printCounter++;

                if (printCounter >= 100)
                {
                    printCounter = 0;

                    Console.Write("\rTimestamp: {0}  ", deviceData.timestamp);
                    Console.Write("FZ: {0}  COPX: {1}  COPY: {2}      ",
                        lslSample[6], lslSample[13], lslSample[14]);

                    Console.Out.Flush();
                }
            }
        }

        void ImmediateDeviceDataHandler(
            int deviceIndex,
            string deviceUid,
            BertecDeviceNET.DataFrame deviceData)
        {
            if (!devicesAreaReady)
                return;

            if (lslOutlet == null || lslSample == null)
                return;

            if (deviceData.forceData == null || deviceData.forceData.Length <= 0)
                return;

            BuildOutputSample(deviceData.forceData);

            lslOutlet.push_sample(lslSample);
        }

        void BuildOutputSample(double[] forceData)
        {
            double FZR = forceData[idxFZR];
            double MXR = forceData[idxMXR];
            double MYR = forceData[idxMYR];

            double FZL = forceData[idxFZL];
            double MXL = forceData[idxMXL];
            double MYL = forceData[idxMYL];

            double FZ = forceData[idxFZ];
            double MX = forceData[idxMX];
            double MY = forceData[idxMY];

            double COPXR = ComputeCopX(MYR, FZR);
            double COPYR = ComputeCopY(MXR, FZR);

            double COPXL = ComputeCopX(MYL, FZL);
            double COPYL = ComputeCopY(MXL, FZL);

            double COPX = ComputeCopX(MY, FZ);
            double COPY = ComputeCopY(MX, FZ);

            lslSample[0]  = (float)FZR;
            lslSample[1]  = (float)MXR;
            lslSample[2]  = (float)MYR;

            lslSample[3]  = (float)FZL;
            lslSample[4]  = (float)MXL;
            lslSample[5]  = (float)MYL;

            lslSample[6]  = (float)FZ;
            lslSample[7]  = (float)MX;
            lslSample[8]  = (float)MY;

            lslSample[9]  = (float)COPXR;
            lslSample[10] = (float)COPYR;

            lslSample[11] = (float)COPXL;
            lslSample[12] = (float)COPYL;

            lslSample[13] = (float)COPX;
            lslSample[14] = (float)COPY;
        }

        double ComputeCopX(double momentY, double forceZ)
        {
            if (Math.Abs(forceZ) < 1e-6)
                return double.NaN;

            // Common force-plate convention: COPx = -My / Fz
            // Verify sign against Bertec CSV export.
            return -momentY / forceZ;
        }

        double ComputeCopY(double momentX, double forceZ)
        {
            if (Math.Abs(forceZ) < 1e-6)
                return double.NaN;

            // Common force-plate convention: COPy = Mx / Fz
            // Verify sign against Bertec CSV export.
            return momentX / forceZ;
        }
    }
}
