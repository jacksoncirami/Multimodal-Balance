% Purpose:
% Load your organized multimodal .mat file.
% Import EEG_data into EEGLAB.
% Add MarkerTable events.
% Save an EEGLAB .set file.

clear;
clc;

%% 1. Select the organized multimodal MAT file

[matFileName, matFolder] = uigetfile( ...
    '*.mat', ...
    'Select organized multimodal MAT file');

if isequal(matFileName, 0)
    error('No organized MAT file was selected.');
end

matFile = fullfile(matFolder, matFileName);

fprintf('\nSelected organized MAT file:\n%s\n', matFile);

load(matFile);

%% 2. Confirm that EEG data exists

if ~exist('EEG_data', 'var')
    error('EEG_data was not found in the organized MAT file.');
end

EEG_data = double(EEG_data);

fprintf('\nEEG_data size in MAT file: %d x %d\n', ...
    size(EEG_data, 1), size(EEG_data, 2));

%% 3. Select the original XDF file

[xdfFileName, xdfFolder] = uigetfile( ...
    '*.xdf', ...
    'Select the original XDF file used to create the MAT file');

if isequal(xdfFileName, 0)
    error('No original XDF file was selected.');
end

xdfFile = fullfile(xdfFolder, xdfFileName);

fprintf('\nSelected original XDF file:\n%s\n', xdfFile);

%% 4. Load the original XDF

if exist('load_xdf', 'file') ~= 2
    error([ ...
        'The load_xdf function was not found on the MATLAB path. ' ...
        'Add the XDF importer or liblsl-MATLAB folder to the MATLAB path.']);
end

[streams, ~] = load_xdf(xdfFile);

if isempty(streams)
    error('No streams were found in the selected XDF file.');
end

%% 5. Find the EEG stream that matches EEG_data

eegStreamIndex = [];

for k = 1:numel(streams)

    streamNameValue = streams{k}.info.name;
    streamTypeValue = streams{k}.info.type;

    if iscell(streamNameValue)
        streamNameValue = streamNameValue{1};
    end

    if iscell(streamTypeValue)
        streamTypeValue = streamTypeValue{1};
    end

    streamName = char(string(streamNameValue));
    streamType = char(string(streamTypeValue));

    numberOfStreamSamples = numel(streams{k}.time_stamps);

    sampleCountMatches = ...
        numberOfStreamSamples == size(EEG_data, 1) || ...
        numberOfStreamSamples == size(EEG_data, 2);

    looksLikeEEG = ...
        strcmpi(streamType, 'EEG') || ...
        contains(lower(streamName), 'eeg') || ...
        contains(lower(streamName), 'obci');

    if looksLikeEEG && sampleCountMatches
        eegStreamIndex = k;

        % Prefer the known OpenBCI stream name when available
        if strcmpi(streamName, 'obci_eeg1')
            break;
        end
    end
end

if isempty(eegStreamIndex)

    fprintf('\nStreams found in the XDF:\n');

    for k = 1:numel(streams)

        streamNameValue = streams{k}.info.name;
        streamTypeValue = streams{k}.info.type;

        if iscell(streamNameValue)
            streamNameValue = streamNameValue{1};
        end

        if iscell(streamTypeValue)
            streamTypeValue = streamTypeValue{1};
        end

        fprintf( ...
            'Stream %d: Name = %s, Type = %s, Samples = %d\n', ...
            k, ...
            char(string(streamNameValue)), ...
            char(string(streamTypeValue)), ...
            numel(streams{k}.time_stamps));
    end

    error([ ...
        'No EEG stream matched the number of samples in EEG_data. ' ...
        'Confirm that the MAT and XDF files belong to the same recording.']);
end

%% 6. Read information from the selected EEG stream

selectedNameValue = streams{eegStreamIndex}.info.name;
selectedTypeValue = streams{eegStreamIndex}.info.type;

if iscell(selectedNameValue)
    selectedNameValue = selectedNameValue{1};
end

if iscell(selectedTypeValue)
    selectedTypeValue = selectedTypeValue{1};
end

selectedEEGName = char(string(selectedNameValue));
selectedEEGType = char(string(selectedTypeValue));

EEG_xdf_time = double( ...
    streams{eegStreamIndex}.time_stamps(:)');

numberOfEEGSamples = numel(EEG_xdf_time);

fprintf('\nSelected EEG stream:\n');
fprintf('Name:    %s\n', selectedEEGName);
fprintf('Type:    %s\n', selectedEEGType);
fprintf('Samples: %d\n', numberOfEEGSamples);

%% 7. Orient EEG_data as channels x samples

if size(EEG_data, 2) == numberOfEEGSamples

    % Already channels x samples

elseif size(EEG_data, 1) == numberOfEEGSamples

    warning([ ...
        'EEG_data appears to be samples x channels. ' ...
        'Transposing it to channels x samples.']);

    EEG_data = EEG_data';

else

    error([ ...
        'The EEG sample count does not match EEG_data.\n' ...
        'XDF EEG samples: %d\n' ...
        'EEG_data size: %d x %d'], ...
        numberOfEEGSamples, ...
        size(EEG_data, 1), ...
        size(EEG_data, 2));
end

%% 8. Validate the EEG timestamps

if numberOfEEGSamples < 2
    error('The EEG stream contains fewer than two timestamps.');
end

if any(~isfinite(EEG_xdf_time))
    error('The EEG timestamp vector contains NaN or infinite values.');
end

if any(diff(EEG_xdf_time) <= 0)
    error('The EEG timestamps are not strictly increasing.');
end

%% 9. Calculate the effective EEG sampling rate

EEG_timestamp_duration = ...
    EEG_xdf_time(end) - EEG_xdf_time(1);

EEG_effective_srate = ...
    (numberOfEEGSamples - 1) / EEG_timestamp_duration;

EEG_median_srate = ...
    1 / median(diff(EEG_xdf_time));

nominalSrate = NaN;

if isfield(streams{eegStreamIndex}.info, 'nominal_srate')

    nominalValue = ...
        streams{eegStreamIndex}.info.nominal_srate;

    if iscell(nominalValue)
        nominalValue = nominalValue{1};
    end

    nominalSrate = ...
        str2double(char(string(nominalValue)));
end

fprintf('\nEEG TIMING INFORMATION\n');
fprintf('====================================================\n');
fprintf('EEG samples:                  %d\n', numberOfEEGSamples);
fprintf('XDF timestamp duration:       %.6f seconds\n', ...
    EEG_timestamp_duration);
fprintf('Effective sampling rate:      %.6f Hz\n', ...
    EEG_effective_srate);
fprintf('Median timestamp sample rate: %.6f Hz\n', ...
    EEG_median_srate);

if isfinite(nominalSrate)
    fprintf('Nominal sampling rate:        %.6f Hz\n', ...
        nominalSrate);
end

%% 10. Start EEGLAB

if exist('eeglab', 'file') ~= 2
    error([ ...
        'EEGLAB was not found on the MATLAB path. ' ...
        'Add the EEGLAB folder to the MATLAB path first.']);
end

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

%% 11. Create the EEGLAB EEG structure

EEG = eeg_emptyset;

EEG.data = EEG_data;
EEG.nbchan = size(EEG_data, 1);
EEG.pnts = size(EEG_data, 2);
EEG.trials = 1;

% Use the rate calculated from the actual XDF timestamp duration
EEG.srate = EEG_effective_srate;

EEG.xmin = 0;
EEG.xmax = (EEG.pnts - 1) / EEG.srate;

EEG.times = ...
    ((0:EEG.pnts - 1) / EEG.srate) * 1000;

[~, baseName, ~] = fileparts(matFileName);

EEG.setname = [baseName '_EEG_TimingCorrected'];

%% 12. Preserve original XDF timing information

EEG.etc.xdf.eeg_stream_name = selectedEEGName;
EEG.etc.xdf.eeg_stream_type = selectedEEGType;

% Preserve the exact original timestamp of every EEG sample
EEG.etc.xdf.eeg_time_stamps = EEG_xdf_time;

EEG.etc.xdf.eeg_start_timestamp = EEG_xdf_time(1);
EEG.etc.xdf.eeg_end_timestamp = EEG_xdf_time(end);

EEG.etc.xdf.effective_srate = EEG_effective_srate;
EEG.etc.xdf.median_srate = EEG_median_srate;

if isfinite(nominalSrate)
    EEG.etc.xdf.nominal_srate = nominalSrate;
end

%% 13. Add EEG channel labels

if exist('EEG_channel_labels', 'var') && ...
        ~isempty(EEG_channel_labels)

    numberOfLabels = min( ...
        numel(EEG_channel_labels), ...
        EEG.nbchan);

    for ch = 1:numberOfLabels

        if iscell(EEG_channel_labels)

            labelValue = EEG_channel_labels{ch};

        elseif ischar(EEG_channel_labels) && ...
                size(EEG_channel_labels, 1) >= ch

            labelValue = strtrim(EEG_channel_labels(ch, :));

        else

            labelValue = EEG_channel_labels(ch);
        end

        EEG.chanlocs(ch).labels = ...
            char(string(labelValue));
    end

    for ch = numberOfLabels + 1:EEG.nbchan
        EEG.chanlocs(ch).labels = ...
            ['Ch' num2str(ch)];
    end

else

    for ch = 1:EEG.nbchan
        EEG.chanlocs(ch).labels = ...
            ['Ch' num2str(ch)];
    end
end

%% 14. Import all marker streams directly from the XDF

events = struct( ...
    'type', {}, ...
    'latency', {}, ...
    'duration', {}, ...
    'source', {}, ...
    'xdf_timestamp', {}, ...
    'time_from_eeg_start', {}, ...
    'timing_error_ms', {});

eventCount = 0;
skippedEventCount = 0;
markerStreamCount = 0;

for k = 1:numel(streams)

    streamNameValue = streams{k}.info.name;
    streamTypeValue = streams{k}.info.type;

    if iscell(streamNameValue)
        streamNameValue = streamNameValue{1};
    end

    if iscell(streamTypeValue)
        streamTypeValue = streamTypeValue{1};
    end

    markerStreamName = char(string(streamNameValue));
    markerStreamType = char(string(streamTypeValue));

    isMarkerStream = ...
        strcmpi(markerStreamType, 'Markers') || ...
        strcmpi(markerStreamType, 'Events');

    if ~isMarkerStream
        continue;
    end

    markerStreamCount = markerStreamCount + 1;

    markerTimes = double( ...
        streams{k}.time_stamps(:));

    markerValues = streams{k}.time_series;

    if iscell(markerValues)
        markerValues = markerValues(:);
    end

    fprintf('\nImporting marker stream: %s\n', markerStreamName);
    fprintf('Markers in stream: %d\n', numel(markerTimes));

    for markerIndex = 1:numel(markerTimes)

        markerTimestamp = markerTimes(markerIndex);

        % Do not import markers outside the EEG recording
        if markerTimestamp < EEG_xdf_time(1) || ...
                markerTimestamp > EEG_xdf_time(end)

            skippedEventCount = skippedEventCount + 1;
            continue;
        end

        %% Find the actual EEG sample nearest to this marker

        [~, nearestEEGSample] = ...
            min(abs(EEG_xdf_time - markerTimestamp));

        %% Read marker text safely

        if iscell(markerValues)

            if markerIndex > numel(markerValues)
                markerText = 'Unknown Marker';
            else
                markerText = markerValues{markerIndex};

                while iscell(markerText) && ~isempty(markerText)
                    markerText = markerText{1};
                end
            end

        elseif ischar(markerValues)

            if size(markerValues, 1) == numel(markerTimes)
                markerText = strtrim(markerValues(markerIndex, :));

            elseif size(markerValues, 2) == numel(markerTimes)
                markerText = strtrim(markerValues(:, markerIndex)');

            else
                markerText = 'Unknown Marker';
            end

        elseif isnumeric(markerValues)

            if isvector(markerValues)
                markerText = markerValues(markerIndex);

            elseif size(markerValues, 2) == numel(markerTimes)
                markerText = markerValues(:, markerIndex);

            else
                markerText = markerValues(markerIndex, :);
            end

        else

            markerText = 'Unknown Marker';
        end

        markerText = char(string(markerText));

        %% Store event

        eventCount = eventCount + 1;

        events(eventCount).type = markerText;

        % EEGLAB event latency is the 1-based EEG sample number
        events(eventCount).latency = nearestEEGSample;

        events(eventCount).duration = 0;

        events(eventCount).source = markerStreamName;

        events(eventCount).xdf_timestamp = markerTimestamp;

        events(eventCount).time_from_eeg_start = ...
            markerTimestamp - EEG_xdf_time(1);

        events(eventCount).timing_error_ms = ...
            1000 * ...
            (EEG_xdf_time(nearestEEGSample) - markerTimestamp);
    end
end

if markerStreamCount == 0
    warning('No marker or event streams were found in the XDF.');
end

%% 15. Sort events and add them to EEGLAB

if ~isempty(events)

    [~, eventOrder] = sort([events.latency]);

    EEG.event = events(eventOrder);

else

    EEG.event = struct([]);
end

EEG.urevent = [];

EEG = eeg_checkset(EEG, 'eventconsistency');
EEG = eeg_checkset(EEG);

%% 16. Store the dataset in EEGLAB

[ALLEEG, EEG, CURRENTSET] = ...
    eeg_store(ALLEEG, EEG, 0);

eeglab redraw;

%% 17. Print import summary

fprintf('\nEEGLAB IMPORT COMPLETED\n');
fprintf('====================================================\n');
fprintf('Channels:             %d\n', EEG.nbchan);
fprintf('Samples:              %d\n', EEG.pnts);
fprintf('EEGLAB sampling rate: %.6f Hz\n', EEG.srate);
fprintf('EEGLAB duration:      %.6f seconds\n', EEG.xmax);
fprintf('Marker streams:       %d\n', markerStreamCount);
fprintf('Imported events:      %d\n', numel(EEG.event));
fprintf('Skipped events:       %d\n', skippedEventCount);

%% 18. Display the final five markers for verification

if ~isempty(EEG.event)

    fprintf('\nFINAL MARKERS\n');
    fprintf('====================================================\n');

    firstEventToShow = max(1, numel(EEG.event) - 4);

    for eventIndex = firstEventToShow:numel(EEG.event)

        displayedTime = ...
            (EEG.event(eventIndex).latency - 1) / EEG.srate;

        fprintf( ...
            '%-25s | XDF-relative: %9.3f s | EEGLAB: %9.3f s\n', ...
            char(string(EEG.event(eventIndex).type)), ...
            EEG.event(eventIndex).time_from_eeg_start, ...
            displayedTime);
    end
end

%% 19. Save the correctly timed EEGLAB dataset

outputFolder = fullfile(matFolder, 'eeglab_sets');

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

outputFileName = ...
    [baseName '_EEG_TimingCorrected.set'];

EEG = pop_saveset( ...
    EEG, ...
    'filename', outputFileName, ...
    'filepath', outputFolder);

fprintf('\nSaved corrected EEGLAB dataset:\n%s\n', ...
    fullfile(outputFolder, outputFileName));
