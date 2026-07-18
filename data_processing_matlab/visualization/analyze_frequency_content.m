%% analyze_frequency_content
% Compare the frequency content of selected clean and noisy EEG and EMG
% time windows using amplitude spectra calculated with the FFT.
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
%   - One EEG frequency-comparison figure
%   - One EMG frequency-comparison figure
%
% Usage:
%   Load the organized multimodal MAT file, adjust the channel and time
%   windows below if needed, and run the script.

close all;
clc;

%% User Settings

% Adjust the channel numbers and time windows for the recording being analyzed.
eegChannel = 1;
emgChannel = 1;

% Use equal-length time windows for a fair comparison.
cleanWindow = [200 250];
noisyWindow = [100 150];

%% Compare EEG Frequency Content

plot_fft_comparison( ...
    EEG_data(eegChannel, :), ...
    EEG_time, ...
    EEG_srate, ...
    cleanWindow, ...
    noisyWindow, ...
    sprintf('EEG Channel %d', eegChannel), ...
    EEG_srate / 2);

%% Compare EMG Frequency Content

plot_fft_comparison( ...
    EMG_data(emgChannel, :), ...
    EMG_time, ...
    EMG_srate, ...
    cleanWindow, ...
    noisyWindow, ...
    sprintf('EMG Channel %d', emgChannel), ...
    min(500, EMG_srate / 2));

disp('FFT comparison complete.');

%% Helper Functions

function plot_fft_comparison(signal, time, sampleRate, ...
    cleanWindow, noisyWindow, signalName, maximumFrequency)
% Compare FFT amplitude spectra from selected clean and noisy time periods.

    signal = double(signal(:));
    time = double(time(:));

    % Extract the selected clean and noisy periods.
    cleanIndex = time >= cleanWindow(1) & ...
                 time <= cleanWindow(2);

    noisyIndex = time >= noisyWindow(1) & ...
                 time <= noisyWindow(2);

    cleanSignal = signal(cleanIndex);
    noisySignal = signal(noisyIndex);

    if isempty(cleanSignal)
        error('The clean window does not contain any samples.');
    end

    if isempty(noisySignal)
        error('The noisy window does not contain any samples.');
    end

    % Replace invalid values and remove each segment mean.
    cleanSignal(~isfinite(cleanSignal)) = 0;
    noisySignal(~isfinite(noisySignal)) = 0;

    cleanSignal = cleanSignal - mean(cleanSignal);
    noisySignal = noisySignal - mean(noisySignal);

    [cleanFrequency, cleanAmplitude] = ...
        calculate_fft(cleanSignal, sampleRate);

    [noisyFrequency, noisyAmplitude] = ...
        calculate_fft(noisySignal, sampleRate);

    figure('Name', [signalName ' Frequency Comparison']);

    plot(cleanFrequency, ...
        20 * log10(cleanAmplitude + eps), ...
        'LineWidth', 1.2);

    hold on;

    plot(noisyFrequency, ...
        20 * log10(noisyAmplitude + eps), ...
        'LineWidth', 1.2);

    % Mark expected U.S. electrical interference frequencies.
    for frequency = 60:60:maximumFrequency
        xline(frequency, '--', sprintf('%d Hz', frequency));
    end

    xlim([0 maximumFrequency]);

    xlabel('Frequency (Hz)');
    ylabel('Relative amplitude (dB)');

    title([signalName ': Clean versus Noisy Period']);

    legend( ...
        sprintf('Clean: %.0f-%.0f s', ...
        cleanWindow(1), cleanWindow(2)), ...
        sprintf('Noisy: %.0f-%.0f s', ...
        noisyWindow(1), noisyWindow(2)), ...
        'Location', 'best');

    grid on;
end

function [frequency, amplitude] = calculate_fft(signal, sampleRate)
% Calculate a single-sided amplitude spectrum using a manual Hann window.

    numberOfSamples = numel(signal);

    % Create a Hann window without requiring the hann() function.
    sampleNumbers = (0:numberOfSamples - 1)';

    if numberOfSamples > 1
        window = 0.5 - 0.5 * cos( ...
            2 * pi * sampleNumbers / (numberOfSamples - 1));
    else
        window = 1;
    end

    windowedSignal = signal .* window;

    transformedSignal = fft(windowedSignal);

    % Normalize the spectrum using the summed window amplitude.
    twoSidedAmplitude = ...
        abs(transformedSignal) / sum(window);

    finalIndex = floor(numberOfSamples / 2) + 1;

    amplitude = twoSidedAmplitude(1:finalIndex);

    if numel(amplitude) > 2
        amplitude(2:end-1) = 2 * amplitude(2:end-1);
    end

    frequency = ...
        sampleRate * (0:finalIndex - 1)' / numberOfSamples;
end
