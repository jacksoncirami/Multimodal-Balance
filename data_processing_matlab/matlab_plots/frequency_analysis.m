%% EEG and EMG Frequency Analysis

close all;
clc;

% ===== Adjustable settings =====
eegChannel = 3;
emgChannel = 1;

% Use equal-length windows for a fair comparison
cleanWindow = [250 300];
noisyWindow = [350 400];

% EEG FFT comparison
plot_fft_comparison( ...
    EEG_data(eegChannel, :), ...
    EEG_time, ...
    EEG_srate, ...
    cleanWindow, ...
    noisyWindow, ...
    sprintf('EEG Channel %d', eegChannel), ...
    EEG_srate / 2);

% EMG FFT comparison
plot_fft_comparison( ...
    EMG_data(emgChannel, :), ...
    EMG_time, ...
    EMG_srate, ...
    cleanWindow, ...
    noisyWindow, ...
    sprintf('EMG Channel %d', emgChannel), ...
    min(500, EMG_srate / 2));

disp('FFT comparison complete.');

% Local function
function plot_fft_comparison(signal, time, sampleRate, ...
    cleanWindow, noisyWindow, signalName, maximumFrequency)

    signal = double(signal(:));
    time = double(time(:));

    % Extract clean and noisy periods
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

    % Replace invalid samples
    cleanSignal(~isfinite(cleanSignal)) = 0;
    noisySignal(~isfinite(noisySignal)) = 0;

    % Remove the mean
    cleanSignal = cleanSignal - mean(cleanSignal);
    noisySignal = noisySignal - mean(noisySignal);

    % Compute amplitude spectra
    [cleanFrequency, cleanAmplitude] = ...
        calculate_fft(cleanSignal, sampleRate);

    [noisyFrequency, noisyAmplitude] = ...
        calculate_fft(noisySignal, sampleRate);

    % Plot
    figure('Name', [signalName ' Frequency Comparison']);

    plot(cleanFrequency, ...
        20 * log10(cleanAmplitude + eps), ...
        'LineWidth', 1.2);

    hold on;

    plot(noisyFrequency, ...
        20 * log10(noisyAmplitude + eps), ...
        'LineWidth', 1.2);

    % Mark expected US electrical interference frequencies
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

    numberOfSamples = numel(signal);

    % Manually create a Hann window without using hann()
    sampleNumbers = (0:numberOfSamples - 1)';

    if numberOfSamples > 1
        window = 0.5 - 0.5 * cos( ...
            2 * pi * sampleNumbers / (numberOfSamples - 1));
    else
        window = 1;
    end

    windowedSignal = signal .* window;

    transformedSignal = fft(windowedSignal);

    % Normalize using the window amplitude
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
