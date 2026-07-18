%% Track 60-Hz interference over time
% Requires EEG_data, EEG_time, EEG_srate,
% EMG_data, EMG_time, and EMG_srate in the workspace.

close all;
clc;

eegChannel = 3;
emgChannel = 1;

% ===== Adjustable settings =====
windowSeconds = 2;
stepSeconds = 0.5;

% EEG: track 60 and 120 Hz
[eegTrackTime, eeg60] = track_frequency_amplitude( ...
    EEG_data(eegChannel,:), EEG_time, EEG_srate, ...
    60, windowSeconds, stepSeconds);

[~, eeg120] = track_frequency_amplitude( ...
    EEG_data(eegChannel,:), EEG_time, EEG_srate, ...
    120, windowSeconds, stepSeconds);

figure;

plot(eegTrackTime, 20*log10(eeg60 + eps), ...
    'LineWidth', 1.2);

hold on;

plot(eegTrackTime, 20*log10(eeg120 + eps), ...
    'LineWidth', 1.2);

xlabel('Time (s)');
ylabel('Relative amplitude (dB)');
title(sprintf('EEG Channel %d: Electrical Interference Over Time', ...
    eegChannel));

legend('60 Hz', '120 Hz', 'Location', 'best');
grid on;

% EMG: track 60, 120, and 180 Hz
[emgTrackTime, emg60] = track_frequency_amplitude( ...
    EMG_data(emgChannel,:), EMG_time, EMG_srate, ...
    60, windowSeconds, stepSeconds);

[~, emg120] = track_frequency_amplitude( ...
    EMG_data(emgChannel,:), EMG_time, EMG_srate, ...
    120, windowSeconds, stepSeconds);

[~, emg180] = track_frequency_amplitude( ...
    EMG_data(emgChannel,:), EMG_time, EMG_srate, ...
    180, windowSeconds, stepSeconds);

figure;

plot(emgTrackTime, 20*log10(emg60 + eps), ...
    'LineWidth', 1.2);

hold on;

plot(emgTrackTime, 20*log10(emg120 + eps), ...
    'LineWidth', 1.2);

plot(emgTrackTime, 20*log10(emg180 + eps), ...
    'LineWidth', 1.2);

xlabel('Time (s)');
ylabel('Relative amplitude (dB)');
title(sprintf('EMG Channel %d: Electrical Interference Over Time', ...
    emgChannel));

legend('60 Hz', '120 Hz', '180 Hz', ...
    'Location', 'best');

grid on;

% Local function
function [centerTimes, frequencyAmplitude] = ...
    track_frequency_amplitude(signal, time, sampleRate, ...
    targetFrequency, windowSeconds, stepSeconds)

    signal = double(signal(:));
    time = double(time(:));

    windowSamples = round(windowSeconds * sampleRate);
    stepSamples = round(stepSeconds * sampleRate);

    startSamples = 1:stepSamples: ...
        (numel(signal) - windowSamples + 1);

    numberOfWindows = numel(startSamples);

    centerTimes = zeros(numberOfWindows, 1);
    frequencyAmplitude = zeros(numberOfWindows, 1);

    for k = 1:numberOfWindows

        indices = startSamples(k): ...
            startSamples(k) + windowSamples - 1;

        segment = signal(indices);

        segment(~isfinite(segment)) = 0;
        segment = segment - mean(segment);

        % Manually generated Hann window
        n = (0:windowSamples-1)';

        window = 0.5 - ...
            0.5*cos(2*pi*n/(windowSamples-1));

        segment = segment .* window;

        % Directly measure the selected frequency
        complexReference = exp( ...
            -1i*2*pi*targetFrequency*n/sampleRate);

        frequencyAmplitude(k) = ...
            2*abs(sum(segment .* complexReference)) / ...
            sum(window);

        centerTimes(k) = mean(time(indices));
    end
end
