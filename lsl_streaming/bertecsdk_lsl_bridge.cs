using System;

namespace BertecExampleNET
{
    class SimpleFZReaderExample
    {
        BertecDeviceNET.BertecDevice theHandle = null;

        bool devicesAreaReady = false;
        bool demoImmediateDeviceDataHandler = false;

        // Bertec force-channel info
        string[] forceChannelNames = null;
        int forceChannelCount = 0;

        // LSL variables
        LSL.StreamOutlet lslOutlet = null;
        float[] lslSample = null;

        static void Main(string[] args)
        {
            SimpleFZReaderExample example = new SimpleFZReaderExample();
            example.Run();
        }

        public void Run()
        {
            Console.WriteLine("Bertec force plate to LSL bridge.");
            Console.WriteLine("Streaming ALL Bertec forceData channels to LabRecorder.");
            Console.WriteLine("LSL stream name: BertecForcePlate");
            Console.WriteLine("Press ESC or Space to exit.\n");

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

        int InitLibrary()
        {
            devicesAreaReady = false;
            forceChannelNames = null;
            forceChannelCount = 0;
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

            Console.WriteLine("\nBertec and LSL bridge closed.");
        }

        void SetupForceChannelsAndLSL()
        {
            forceChannelNames = theHandle.DeviceChannelNames(0);
            forceChannelCount = forceChannelNames.Length;

            if (forceChannelCount <= 0)
            {
                Console.WriteLine("WARNING: No Bertec force-data channels found.");
                return;
            }

            Console.WriteLine("\nBertec force channels found:");

            for (int i = 0; i < forceChannelCount; i++)
            {
                Console.WriteLine("Channel {0}: {1}", i, forceChannelNames[i]);
            }

            LSL.StreamInfo info = new LSL.StreamInfo(
                "BertecForcePlate",
                "Force",
                forceChannelCount,
                1000.0,
                LSL.channel_format_t.cf_float32,
                "bertec_force_plate_all_channels_001"
            );

            // Add labels to the LSL stream metadata.
            LSL.XMLElement channels = info.desc().append_child("channels");

            for (int i = 0; i < forceChannelCount; i++)
            {
                LSL.XMLElement ch = channels.append_child("channel");

                ch.append_child_value("label", forceChannelNames[i]);
                ch.append_child_value("type", "ForcePlate");

                string nameUpper = forceChannelNames[i].ToUpper();

                if (nameUpper.StartsWith("F"))
                    ch.append_child_value("unit", "N");
                else if (nameUpper.StartsWith("M"))
                    ch.append_child_value("unit", "Nm");
                else
                    ch.append_child_value("unit", "unknown");
            }

            lslSample = new float[forceChannelCount];
            lslOutlet = new LSL.StreamOutlet(info);

            Console.WriteLine("\nLSL stream created: BertecForcePlate");
            Console.WriteLine("Channel count: {0}", forceChannelCount);
            Console.WriteLine("Open LabRecorder and look for this stream.\n");
        }

        void StatusHandler(BertecDeviceNET.StatusErrors status)
        {
            switch (status)
            {
                case BertecDeviceNET.StatusErrors.LOOKING_FOR_DEVICES:
                    Console.WriteLine("\nSearching for connected devices");
                    devicesAreaReady = false;
                    forceChannelNames = null;
                    forceChannelCount = 0;
                    break;

                case BertecDeviceNET.StatusErrors.NO_DEVICES_FOUND:
                    Console.WriteLine("\nNo devices found");
                    devicesAreaReady = false;
                    forceChannelNames = null;
                    forceChannelCount = 0;
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

                        SetupForceChannelsAndLSL();

                        theHandle.AutoZeroing = true;

                        devicesAreaReady = true;
                    });

                    break;
                }

                case BertecDeviceNET.StatusErrors.NO_DATA_RECEIVED:
                    Console.WriteLine("\nNo data being received");
                    devicesAreaReady = false;
                    break;

                case BertecDeviceNET.StatusErrors.DEVICE_HAS_FAULTED:
                    Console.WriteLine("\nDevice has faulted");
                    devicesAreaReady = false;
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
            if (!devicesAreaReady)
                return;

            for (int deviceNumber = 0; deviceNumber < dataFrames.Length; ++deviceNumber)
            {
                if (deviceNumber != 0)
                    continue;

                BertecDeviceNET.DataFrame deviceData = dataFrames[deviceNumber];

                if (deviceData.forceData.Length <= 0)
                    return;

                if (lslOutlet == null || lslSample == null)
                    return;

                int channelsToCopy = Math.Min(forceChannelCount, deviceData.forceData.Length);

                for (int i = 0; i < channelsToCopy; i++)
                {
                    lslSample[i] = (float)deviceData.forceData[i];
                }

                lslOutlet.push_sample(lslSample);

                // Print timestamp and first few values so you know it is alive.
                Console.Write("\rTimestamp: {0}  ", deviceData.timestamp);

                for (int i = 0; i < Math.Min(6, channelsToCopy); i++)
                {
                    Console.Write("{0}: {1}  ", forceChannelNames[i], lslSample[i]);
                }

                Console.Out.Flush();
            }
        }

        void ImmediateDeviceDataHandler(
            int deviceIndex,
            string deviceUid,
            BertecDeviceNET.DataFrame deviceData)
        {
            if (!devicesAreaReady)
                return;

            if (deviceData.forceData.Length <= 0)
                return;

            if (lslOutlet == null || lslSample == null)
                return;

            int channelsToCopy = Math.Min(forceChannelCount, deviceData.forceData.Length);

            for (int i = 0; i < channelsToCopy; i++)
            {
                lslSample[i] = (float)deviceData.forceData[i];
            }

            lslOutlet.push_sample(lslSample);

            Console.Write("\r[I]{0}, {1}, {2}", deviceIndex, deviceUid, deviceData.timestamp);
            Console.Out.Flush();
        }
    }
}
