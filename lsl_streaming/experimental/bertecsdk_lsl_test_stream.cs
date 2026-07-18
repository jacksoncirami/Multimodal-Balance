#nullable disable

using System;
using System.Threading;

/*
 * Bertec/LSL Test Stream
 *
 * Creates a simulated single-channel force stream for confirming that
 * Lab Streaming Layer is configured correctly in a Visual Studio C#
 * project before testing the full Bertec force-plate bridge.
 *
 * This script does not connect to a Bertec force plate and does not use
 * the Bertec SDK. It continuously broadcasts an increasing numerical
 * value through LSL.
 *
 * LSL stream:
 *   Name:        FakeForceTest
 *   Type:        Force
 *   Channels:    1
 *   Sample rate: 100 Hz
 *   Format:      float32
 *   Source ID:   fake_force_test_001
 *
 * Project setup requirements:
 *
 * This source file must be used inside a compatible Visual Studio C#
 * project. The project must also include:
 *
 *   - The LSL C# wrapper file, such as LSL.cs
 *   - The native lsl.dll file available to the built application
 *   - The correct x86 or x64 build configuration for the installed
 *     LSL libraries
 *
 * These dependencies are configured through the Visual Studio project
 * and Solution Explorer. They are not contained inside this source file.
 *
 * The Bertec SDK and Bertec DLLs are not required for this test because
 * the script generates simulated data rather than reading force-plate
 * hardware.
 *
 * Usage:
 *   1. Add this file and the LSL C# wrapper to a Visual Studio project.
 *   2. Ensure that lsl.dll is available to the built application.
 *   3. Build and run the project.
 *   4. Open LabRecorder and select Refresh.
 *   5. Confirm that FakeForceTest appears and receives data.
 *   6. Press Ctrl+C in the console to stop the program.
 */

class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("==============================================");
        Console.WriteLine("Starting simulated LSL force test stream...");
        Console.WriteLine("Open LabRecorder and look for: FakeForceTest");
        Console.WriteLine("Press Ctrl+C to stop.");
        Console.WriteLine("==============================================\n");

        // Create a single-channel, regularly sampled LSL stream.
        LSL.StreamInfo info = new LSL.StreamInfo(
            "FakeForceTest",
            "Force",
            1,
            100.0,
            LSL.channel_format_t.cf_float32,
            "fake_force_test_001"
        );

        LSL.StreamOutlet outlet = new LSL.StreamOutlet(info);

        // Reuse one sample array throughout the streaming loop.
        float[] sample = new float[1];
        int counter = 0;

        while (true)
        {
            sample[0] = counter;

            outlet.push_sample(sample);

            Console.WriteLine("Sent sample: " + sample[0]);

            counter++;

            // A 10 ms interval corresponds to approximately 100 samples/s.
            Thread.Sleep(10);
        }
    }
}
