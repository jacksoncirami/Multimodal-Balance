#nullable disable

using System;
using System.Threading;

class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("Starting fake LSL test stream...");
        Console.WriteLine("Open LabRecorder and look for: FakeForceTest");
        Console.WriteLine("Press Ctrl+C to stop.\n");

        LSL.StreamInfo info = new LSL.StreamInfo(
            "FakeForceTest",
            "Force",
            1,
            100.0,
            LSL.channel_format_t.cf_float32,
            "fake_force_test_001"
        );

        LSL.StreamOutlet outlet = new LSL.StreamOutlet(info);

        float[] sample = new float[1];
        int counter = 0;

        while (true)
        {
            sample[0] = counter;

            outlet.push_sample(sample);

            Console.WriteLine("Sent sample: " + sample[0]);

            counter++;

            Thread.Sleep(10);
        }
    }
}
