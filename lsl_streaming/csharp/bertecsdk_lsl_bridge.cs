#nullable disable

using System;

namespace BertecExampleNET
{
    /*
     * Bertec Force Plate to Lab Streaming Layer Bridge
     *
     * Connects to the Bertec SDK, reads force and moment channels, performs
     * a software tare, calculates center-of-pressure values, estimates
     * center-of-gravity position, and streams the results through LSL.
     *
     * Project Setup Requirements:
     *
     * This source file must be used inside a compatible Visual Studio
     * C# project. The project must also include:
     *
     * - The LSL C# wrapper file, such as LSL.cs
     * - The native lsl.dll file available to the built application
     * - A reference to BertecDeviceNET
     * - The required Bertec SDK DLLs
     * - The correct x86 or x64 build configuration for the installed
     *   Bertec and LSL libraries
     *
     * These dependencies are configured through the Visual Studio project
     * and Solution Explorer. They are not contained inside this source file.
     *
     * Proprietary Bertec SDK files and license-protected components are not
     * included in this repository. Users must obtain them from Bertec.
     *
     * Before Use:
     *
     * - Confirm that the required Bertec channel names match the connected
     *   force-plate configuration.
     * - Confirm the expected sampling rate.
     * - Keep the force plate empty during the software-tare period.
     * - Enter the participant's height when prompted.
     * - Verify the LSL stream in LabRecorder before recording.
     *
     * Important:
     *
     * - COGX_est, COGY_est, and COG_est are estimated values.
     * - They are not direct force-plate measurements.
     */
    class SimpleFZReaderExample
    {
        // Bertec SDK connection.
        BertecDeviceNET.BertecDevice theHandle = null;

        bool devicesAreaReady = false;
        bool demoImmediateDeviceDataHandler = false;

        string[] sdkChannelNames = null;

        // Indices of the required right, left, and combined force channels.
        int idxFZR = -1, idxMXR = -1, idxMYR = -1;
        int idxFZL = -1, idxMXL = -1, idxMYL = -1;
        int idxFZ = -1, idxMX = -1, idxMY = -1;

        // LSL outlet and reusable output sample.
        LSL.StreamOutlet lslOutlet = null;
        float[] lslSample = null;

        /*
         * Study and acquisition settings.
         *
         * Future users should verify these values for their own hardware,
         * sampling configuration, and analysis requirements.
         */
        const int BASELINE_SAMPLE_COUNT = 2000;
        const double MIN_FORCE_FOR_COP = 20.0;
        const double SAMPLE_RATE_HZ = 1000.0;
        const double DT = 1.0 / SAMPLE_RATE_HZ;
        const double GRAVITY = 9.81;

        // Software-tare accumulation and baseline values.
        double[] baselineSums = new double[9];
        double[] baselineValues = new double[9];

        int baselineSamplesCollected = 0;
        bool baselineComplete = false;

        // Participant-specific values used in the estimated COG calculation.
        double participantHeightInches = 0.0;
        double participantHeightMeters = 0.0;
        double estimatedComHeightMeters = 0.0;

        // State variables for the estimated COG filter.
        double cogFilterAlpha = 0.0;
        double cogXEst = double.NaN;
        double cogYEst = double.NaN;
        bool cogInitialized = false;

        /*
         * LSL output channel order.
         *
         * Do not change this order without also updating BuildOutputSample()
         * and any downstream scripts that depend on the channel positions.
         */
        readonly string[] outputChannelNames =
        {
            "FZR", "MXR", "MYR",
            "FZL", "MXL", "MYL",
            "FZ",  "MX",  "MY",
            "COPXR", "COPYR",
            "COPXL", "COPYL",
            "COPX",  "COPY",
            "COGX_est", "COGY_est", "COG_est"
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
            Console.WriteLine("Streams baseline-corrected force/moment + COP + estimated COG.");
            Console.WriteLine("LSL stream name: BertecForcePlate");
            Console.WriteLine("LSL stream type: Force");
            Console.WriteLine("=================================================\n");

            SetupParticipantHeight();

            Console.WriteLine("\nIMPORTANT:");
            Console.WriteLine("Keep the force plate EMPTY during startup.");
            Console.WriteLine("The first ~2 seconds are used for software tare.");
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

        void SetupParticipantHeight()
        {
            while (true)
            {
                Console.Write("Enter participant height in inches: ");
                string input = Console.ReadLine();

                if (double.TryParse(input, out participantHeightInches) &&
                    participantHeightInches > 0)
                {
                    break;
                }

                Console.WriteLine("Invalid height. Example: 70.5");
            }

            participantHeightMeters = participantHeightInches * 0.0254;
            estimatedComHeightMeters = 0.55 * participantHeightMeters;

            double naturalFrequencyRadPerSec =
                Math.Sqrt(GRAVITY / estimatedComHeightMeters);

            cogFilterAlpha =
                1.0 - Math.Exp(-naturalFrequencyRadPerSec * DT);

            Console.WriteLine(
                "\nParticipant height: {0:F2} inches",
                participantHeightInches);

            Console.WriteLine(
                "Participant height: {0:F3} m",
                participantHeightMeters);

            Console.WriteLine(
                "Estimated COM height: {0:F3} m",
                estimatedComHeightMeters);
        }

        int InitLibrary()
        {
            devicesAreaReady = false;
            sdkChannelNames = null;
            lslOutlet = null;
            lslSample = null;

            ResetBaseline();
            ResetCogEstimate();

            try
            {
                theHandle = new BertecDeviceNET.BertecDevice();
            }
            catch (System.Exception)
            {
                Console.WriteLine("Unable to initialize the Bertec Device Library.");
                Console.WriteLine("Possible causes:");
                Console.WriteLine("- Missing FTD2XX driver");
                Console.WriteLine("- Missing BertecDevice.dll");
                Console.WriteLine("- Missing BertecDeviceNET.dll");
                Console.WriteLine("- Missing ftd2xx.dll");
                Console.WriteLine("- Wrong x86/x64 configuration");
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

        void ResetBaseline()
        {
            for (int i = 0; i < baselineSums.Length; i++)
            {
                baselineSums[i] = 0.0;
                baselineValues[i] = 0.0;
            }

            baselineSamplesCollected = 0;
            baselineComplete = false;
            printCounter = 0;
        }

        void ResetCogEstimate()
        {
            cogXEst = double.NaN;
            cogYEst = double.NaN;
            cogInitialized = false;
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
                Console.WriteLine("SDK channel {0}: {1}", i, sdkChannelNames[i]);

            /*
             * Match required channel names from the Bertec SDK.
             * Future users should confirm that their SDK exposes these exact
             * labels before running the bridge.
             */
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
                idxFZ < 0 || idxMX < 0 || idxMY < 0)
            {
                Console.WriteLine(
                    "\nERROR: One or more required raw channels were not found.");

                Console.WriteLine("Required raw channels:");
                Console.WriteLine("FZR, MXR, MYR, FZL, MXL, MYL, FZ, MX, MY");
                return false;
            }

            /*
             * LSL stream metadata.
             *
             * Future users may change the stream name, stream type, or source
             * ID if needed, but corresponding LabRecorder and processing
             * documentation should be updated as well.
             */
            LSL.StreamInfo info = new LSL.StreamInfo(
                "BertecForcePlate",
                "Force",
                outputChannelNames.Length,
                SAMPLE_RATE_HZ,
                LSL.channel_format_t.cf_float32,
                "bertec_force_plate_tared_cop_cog_est_001"
            );

            LSL.XMLElement channels =
                info.desc().append_child("channels");

            for (int i = 0; i < outputChannelNames.Length; i++)
            {
                string label = outputChannelNames[i];

                LSL.XMLElement ch =
                    channels.append_child("channel");

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
            Console.WriteLine(
                "Output channel count: {0}",
                outputChannelNames.Length);

            Console.WriteLine("\nOutput channels:");

            for (int i = 0; i < outputChannelNames.Length; i++)
            {
                Console.WriteLine(
                    "LSL channel {0}: {1}",
                    i,
                    outputChannelNames[i]);
            }

            Console.WriteLine(
                "\nKeep plate empty. Collecting software tare baseline...");

            Console.WriteLine("Do not step on the plate yet.\n");

            ResetBaseline();
            ResetCogEstimate();

            return true;
        }

        int FindChannelIndex(string targetName)
        {
            for (int i = 0; i < sdkChannelNames.Length; i++)
            {
                if (String.Equals(
                    sdkChannelNames[i],
                    targetName,
                    StringComparison.OrdinalIgnoreCase))
                {
                    return i;
                }
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
                return "m";

            if (upper.StartsWith("COG"))
                return "m_estimated";

            return "unknown";
        }

        void StatusHandler(BertecDeviceNET.StatusErrors status)
        {
            switch (status)
            {
                case BertecDeviceNET.StatusErrors.LOOKING_FOR_DEVICES:
                    Console.WriteLine(
                        "\nSearching for connected Bertec devices...");

                    devicesAreaReady = false;
                    break;

                case BertecDeviceNET.StatusErrors.NO_DEVICES_FOUND:
                    Console.WriteLine("\nNo Bertec devices found.");
                    devicesAreaReady = false;
                    break;

                case BertecDeviceNET.StatusErrors.DEVICES_READY:
                {
                    Console.WriteLine("\nDevices found and ready.");

                    for (int devNum = 0;
                         devNum < theHandle.DeviceCount;
                         ++devNum)
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
                            BertecDeviceNET.DataStreamControl
                                .SyncPinMode.NONE;

                        streamControl.auxPinMode =
                            BertecDeviceNET.DataStreamControl
                                .AuxPinMode.NONE;

                        streamControl.deviceFilterBitmask = 0;
                        streamControl.internalClockSource = 0;
                        streamControl.internalClockFrequency = 0;

                        Console.WriteLine(
                            "\nStarting Bertec data stream...");

                        theHandle.StartDataStream(streamControl);

                        Console.WriteLine(
                            "Bertec data stream started.");

                        bool setupWorked = SetupChannelsAndLSL();

                        if (setupWorked)
                        {
                            theHandle.AutoZeroing = true;
                            devicesAreaReady = true;

                            Console.WriteLine(
                                "\nBridge is running.");
                        }
                        else
                        {
                            devicesAreaReady = false;

                            Console.WriteLine(
                                "\nBridge setup failed.");
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

            for (int deviceNumber = 0;
                 deviceNumber < dataFrames.Length;
                 ++deviceNumber)
            {
                // The current implementation streams only device index 0.
                if (deviceNumber != 0)
                    continue;

                BertecDeviceNET.DataFrame deviceData =
                    dataFrames[deviceNumber];

                if (deviceData.forceData == null ||
                    deviceData.forceData.Length <= 0)
                {
                    return;
                }

                if (!baselineComplete)
                {
                    AccumulateBaseline(deviceData.forceData);
                    return;
                }

                BuildOutputSample(deviceData.forceData);

                lslOutlet.push_sample(lslSample);

                printCounter++;

                if (printCounter >= 100)
                {
                    printCounter = 0;

                    Console.Write(
                        "\rTimestamp: {0}  ",
                        deviceData.timestamp);

                    Console.Write(
                        "FZ: {0} N  COPX: {1} m  COPY: {2} m  " +
                        "COGX_est: {3} m  COGY_est: {4} m  " +
                        "COG_est: {5} m      ",
                        lslSample[6],
                        lslSample[13],
                        lslSample[14],
                        lslSample[15],
                        lslSample[16],
                        lslSample[17]);

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

            if (deviceData.forceData == null ||
                deviceData.forceData.Length <= 0)
            {
                return;
            }

            if (!baselineComplete)
            {
                AccumulateBaseline(deviceData.forceData);
                return;
            }

            BuildOutputSample(deviceData.forceData);

            lslOutlet.push_sample(lslSample);
        }

        void AccumulateBaseline(float[] forceData)
        {
            baselineSums[0] += forceData[idxFZR];
            baselineSums[1] += forceData[idxMXR];
            baselineSums[2] += forceData[idxMYR];

            baselineSums[3] += forceData[idxFZL];
            baselineSums[4] += forceData[idxMXL];
            baselineSums[5] += forceData[idxMYL];

            baselineSums[6] += forceData[idxFZ];
            baselineSums[7] += forceData[idxMX];
            baselineSums[8] += forceData[idxMY];

            baselineSamplesCollected++;

            if (baselineSamplesCollected % 100 == 0)
            {
                Console.Write(
                    "\rCollecting baseline: {0}/{1} samples",
                    baselineSamplesCollected,
                    BASELINE_SAMPLE_COUNT);

                Console.Out.Flush();
            }

            if (baselineSamplesCollected >= BASELINE_SAMPLE_COUNT)
            {
                for (int i = 0; i < baselineValues.Length; i++)
                {
                    baselineValues[i] =
                        baselineSums[i] / baselineSamplesCollected;
                }

                baselineComplete = true;

                Console.WriteLine("\n\nSoftware tare complete.");
                Console.WriteLine(
                    "Baseline values subtracted from future samples:");

                Console.WriteLine("FZR: {0}", baselineValues[0]);
                Console.WriteLine("MXR: {0}", baselineValues[1]);
                Console.WriteLine("MYR: {0}", baselineValues[2]);

                Console.WriteLine("FZL: {0}", baselineValues[3]);
                Console.WriteLine("MXL: {0}", baselineValues[4]);
                Console.WriteLine("MYL: {0}", baselineValues[5]);

                Console.WriteLine("FZ:  {0}", baselineValues[6]);
                Console.WriteLine("MX:  {0}", baselineValues[7]);
                Console.WriteLine("MY:  {0}", baselineValues[8]);

                Console.WriteLine(
                    "\nYou may now step on the plate and record in LabRecorder.\n");
            }
        }

        void BuildOutputSample(float[] forceData)
        {
            // Subtract the software-tare baseline from each raw channel.
            double FZR =
                forceData[idxFZR] - baselineValues[0];

            double MXR =
                forceData[idxMXR] - baselineValues[1];

            double MYR =
                forceData[idxMYR] - baselineValues[2];

            double FZL =
                forceData[idxFZL] - baselineValues[3];

            double MXL =
                forceData[idxMXL] - baselineValues[4];

            double MYL =
                forceData[idxMYL] - baselineValues[5];

            double FZ =
                forceData[idxFZ] - baselineValues[6];

            double MX =
                forceData[idxMX] - baselineValues[7];

            double MY =
                forceData[idxMY] - baselineValues[8];

            // Calculate right, left, and combined COP values.
            double COPXR = ComputeCopX(MYR, FZR);
            double COPYR = ComputeCopY(MXR, FZR);

            double COPXL = ComputeCopX(MYL, FZL);
            double COPYL = ComputeCopY(MXL, FZL);

            double COPX = ComputeCopX(MY, FZ);
            double COPY = ComputeCopY(MX, FZ);

            // Update the filtered estimated COG position.
            UpdateCogEstimate(COPX, COPY);

            double COG_est =
                ComputeCogMagnitude(cogXEst, cogYEst);

            /*
             * Populate the reusable LSL sample in the same order defined by
             * outputChannelNames.
             */
            lslSample[0] = (float)FZR;
            lslSample[1] = (float)MXR;
            lslSample[2] = (float)MYR;

            lslSample[3] = (float)FZL;
            lslSample[4] = (float)MXL;
            lslSample[5] = (float)MYL;

            lslSample[6] = (float)FZ;
            lslSample[7] = (float)MX;
            lslSample[8] = (float)MY;

            lslSample[9] = (float)COPXR;
            lslSample[10] = (float)COPYR;

            lslSample[11] = (float)COPXL;
            lslSample[12] = (float)COPYL;

            lslSample[13] = (float)COPX;
            lslSample[14] = (float)COPY;

            lslSample[15] = (float)cogXEst;
            lslSample[16] = (float)cogYEst;
            lslSample[17] = (float)COG_est;
        }

        void UpdateCogEstimate(double copX, double copY)
        {
            if (double.IsNaN(copX) || double.IsNaN(copY))
            {
                if (!cogInitialized)
                {
                    cogXEst = double.NaN;
                    cogYEst = double.NaN;
                }

                return;
            }

            if (!cogInitialized)
            {
                cogXEst = copX;
                cogYEst = copY;
                cogInitialized = true;
                return;
            }

            cogXEst =
                cogXEst + cogFilterAlpha * (copX - cogXEst);

            cogYEst =
                cogYEst + cogFilterAlpha * (copY - cogYEst);
        }

        double ComputeCogMagnitude(double cogX, double cogY)
        {
            if (double.IsNaN(cogX) || double.IsNaN(cogY))
                return double.NaN;

            return Math.Sqrt(
                (cogX * cogX) + (cogY * cogY));
        }

        double ComputeCopX(double momentY, double forceZ)
        {
            // COP is undefined when vertical force is below the threshold.
            if (Math.Abs(forceZ) < MIN_FORCE_FOR_COP)
                return double.NaN;

            return -momentY / forceZ;
        }

        double ComputeCopY(double momentX, double forceZ)
        {
            // COP is undefined when vertical force is below the threshold.
            if (Math.Abs(forceZ) < MIN_FORCE_FOR_COP)
                return double.NaN;

            return momentX / forceZ;
        }
    }
}
