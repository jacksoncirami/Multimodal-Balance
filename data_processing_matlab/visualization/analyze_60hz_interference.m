%% analyze_60hz_interference
% Track 60 Hz electrical interference and selected harmonics over time in
% one EEG channel and one EMG channel.
%
% The script applies a moving analysis window to the selected signals and
% measures the relative amplitude of specific frequencies. EEG is examined
% at 60 and 120 Hz, while EMG is examined at 60, 120, and 180 Hz.
%
% Required workspace variables:
%   - EEG_data
%   - EEG_time
%   - EEG_srate
%   - EMG_data
%   - EMG_time
%   - EMG_srate
%
% Output:
%   - One EEG interference plot
%   - One EMG interference plot
%
% Usage:
%   Load the organized multimodal MAT file, adjust the channel and window
%   settings below if needed, and run the script.

close all;
clc;

%% User Settings

% Adjust the channel numbers and moving-window settings for the recording
% being analyzed.
eegChannel = 1;
emgChannel = 1;

windowSeconds = 2;
stepSeconds = 0.5;

%% Track EEG Interference

% Track the 60 Hz fundamental and its 120 Hz harmonic.

[eegTrackTime, eeg60] = track_frequency_amplitude( ...
    EEG_data(eegChannel, :), EEG_time, EEG_srate, ...
    60, windowSeconds, stepSeconds);

[~, eeg120] = track_frequency_amplitude( ...
    EEG_data(eegChannel, :), EEG_time, EEG_srate, ...
    120, windowSeconds, stepSeconds);

figure;

plot(eegTrackTime, 20 * log10(eeg60 + eps), ...
    'LineWidth', 1.2);

hold on;

plot(eegTrackTime, 20 * log10(eeg120 + eps), ...
    'LineWidth', 1.2);

xlabel('Time (s)');
ylabel('Relative amplitude (dB)');
title(sprintf( ...
    'EEG Channel %d: Electrical Interference Over Time', ...
    eegChannel));

legend('60 Hz', '120 Hz', 'Location', 'best');
grid on;

%% Track EMG Interference

% Track the 60 Hz fundamental and its 120 Hz and 180 Hz harmonics.

[emgTrackTime, emg60] = track_frequency_amplitude( ...
    EMG_data(emgChannel, :), EMG_time, EMG_srate, ...
    60, windowSeconds, stepSeconds);

[~, emg120] = track_frequency_amplitude( ...
    EMG_data(emgChannel, :), EMG_time, EMG_srate, ...
    120, windowSeconds, stepSeconds);

[~, emg180] = track_frequency_amplitude( ...
    EMG_data(emgChannel, :), EMG_time, EMG_srate, ...
    180, windowSeconds, stepSeconds);

figure;

plot(emgTrackTime, 20 * log10(emg60 + eps), ...
    'LineWidth', 1.2);

hold on;

plot(emgTrackTime, 20 * log10(emg120 + eps), ...
    'LineWidth', 1.2);

plot(emgTrackTime, 20 * log10(emg180 + eps), ...
    'LineWidth', 1.2);

xlabel('Time (s)');
ylabel('Relative amplitude (dB)');
title(sprintf( ...
    'EMG Channel %d: Electrical Interference Over Time', ...
    emgChannel));

legend('60 Hz', '120 Hz', '180 Hz', ...
    'Location', 'best');

grid on;

%% Helper Function

function [centerTimes, frequencyAmplitude] = ...
    track_frequency_amplitude(signal, time, sampleRate, ...
    targetFrequency, windowSeconds, stepSeconds)
% Measure the amplitude of one frequency across overlapping time windows.

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

        % Generate a Hann window without requiring an additional toolbox.
        n = (0:windowSamples - 1)';

        window = 0.5 - ...
            0.5 * cos(2 * pi * n / (windowSamples - 1));

        segment = segment .* window;

        % Measure the selected frequency directly using a complex reference.
        complexReference = exp( ...
            -1i * 2 * pi * targetFrequency * n / sampleRate);

        frequencyAmplitude(k) = ...
            2 * abs(sum(segment .* complexReference)) / ...
            sum(window);

        centerTimes(k) = mean(time(indices));
    end
end
