% Purpose:
% Load a LabRecorder .xdf file containing EEG, EMG, force plate, and two LSL marker streams

clear; clc;

%% 1. Check That load_xdf is Available

if exist('load_xdf', 'file') ~= 2
    error(['load_xdf was not found on the MATLAB path.\n\n' ...
           'Add the xdf-Matlab folder to your MATLAB path first.']);
end

fprintf('\nUsing load_xdf from:\n%s\n', which('load_xdf'));

%% 2. Select XDF File

[file, folder] = uigetfile('*.xdf', 'Select your LabRecorder XDF file');

if isequal(file, 0)
    error('No XDF file selected.');
end

xdfFile = fullfile(folder, file);

fprintf('\nSelected XDF file:\n%s\n', xdfFile);

%% 3. Load XDF File

[streams, fileheader] = load_xdf(xdfFile);

if isempty(streams)
    error('No streams were found in this XDF file.');
end

%% 4. Print Stream Information

fprintf('\n===== Streams found in XDF file =====\n');

for i = 1:length(streams)
    name = get_xdf_info(streams{i}, 'name');
    type = get_xdf_info(streams{i}, 'type');
    chanCount = get_xdf_info(streams{i}, 'channel_count');
    srate = get_xdf_info(streams{i}, 'nominal_srate');

    if isfield(streams{i}, 'time_stamps')
        nSamples = length(streams{i}.time_stamps);
    else
        nSamples = 0;
    end

    if isfield(streams{i}, 'time_series')
        dataSize = size(streams{i}.time_series);
    else
        dataSize = [];
    end

    fprintf('\nSTREAM %d\n', i);
    fprintf('Name: %s\n', name);
    fprintf('Type: %s\n', type);
    fprintf('Channels: %s\n', chanCount);
    fprintf('Nominal srate: %s\n', srate);
    fprintf('Samples: %d\n', nSamples);
    fprintf('Data size: %s\n', mat2str(dataSize));
end

%% 5. Enter Stream Numbers

fprintf('\nEnter the stream numbers based on the list above.\n');
fprintf('For a marker stream that was not recorded, type [].\n');
fprintf('At least one marker stream should be selected.\n\n');

eegIdx = input('EEG stream number: ');
emgIdx = input('EMG stream number: ');
forceIdx = input('Force plate stream number: ');

marker1Idx = input('Marker stream 1 number, usually GuiMarkers ([] if not recorded): ');
marker2Idx = input('Marker stream 2 number, usually MVCMarkers ([] if not recorded): ');

check_required_stream_index(eegIdx, length(streams), 'EEG');
check_required_stream_index(emgIdx, length(streams), 'EMG');
check_required_stream_index(forceIdx, length(streams), 'Force plate');

check_optional_stream_index(marker1Idx, length(streams), 'Marker stream 1');
check_optional_stream_index(marker2Idx, length(streams), 'Marker stream 2');

if isempty(marker1Idx) && isempty(marker2Idx)
    error('At least one marker stream must be selected.');
end

%% 6. Assign Streams

eegStream = streams{eegIdx};
emgStream = streams{emgIdx};
forceStream = streams{forceIdx};

if isempty(marker1Idx)
    marker1Stream = [];
else
    marker1Stream = streams{marker1Idx};
end

if isempty(marker2Idx)
    marker2Stream = [];
else
    marker2Stream = streams{marker2Idx};
end

%% 7. Extract Data And Timestamps

EEG_data = double(eegStream.time_series);
EMG_data = double(emgStream.time_series);
ForcePlate_data = double(forceStream.time_series);

EEG_time_raw = eegStream.time_stamps;
EMG_time_raw = emgStream.time_stamps;
ForcePlate_time_raw = forceStream.time_stamps;

[Marker1_time_raw, Marker1_labels_raw, Marker1_source_name, Marker1_info] = extract_marker_stream(marker1Stream, "MarkerStream1");
[Marker2_time_raw, Marker2_labels_raw, Marker2_source_name, Marker2_info] = extract_marker_stream(marker2Stream, "MarkerStream2");

%% 8. Make Sure Required Data Streams Are Not Empty

if isempty(EEG_time_raw) || isempty(EEG_data)
    error('The selected EEG stream is empty. Check the EEG stream number.');
end

if isempty(EMG_time_raw) || isempty(EMG_data)
    error('The selected EMG stream is empty. Check the EMG stream number.');
end

if isempty(ForcePlate_time_raw) || isempty(ForcePlate_data)
    error('The selected force plate stream is empty. Check the force plate stream number.');
end

if ~isempty(marker1Idx)
    if isempty(Marker1_time_raw) || isempty(Marker1_labels_raw)
        warning('Marker stream 1 was selected, but it contains no markers.');
    end
end

if ~isempty(marker2Idx)
    if isempty(Marker2_time_raw) || isempty(Marker2_labels_raw)
        warning('Marker stream 2 was selected, but it contains no markers.');
    end
end

%% 9. Make All Data Channels x Samples

EEG_data = make_channels_by_samples(EEG_data, EEG_time_raw);
EMG_data = make_channels_by_samples(EMG_data, EMG_time_raw);
ForcePlate_data = make_channels_by_samples(ForcePlate_data, ForcePlate_time_raw);

%% 10. Convert Timestamps to Seconds From Recording Start

startTimes = [EEG_time_raw(1), EMG_time_raw(1), ForcePlate_time_raw(1)];

if ~isempty(Marker1_time_raw)
    startTimes(end+1) = Marker1_time_raw(1);
end

if ~isempty(Marker2_time_raw)
    startTimes(end+1) = Marker2_time_raw(1);
end

t0 = min(startTimes);

EEG_time = EEG_time_raw - t0;
EMG_time = EMG_time_raw - t0;
ForcePlate_time = ForcePlate_time_raw - t0;

if isempty(Marker1_time_raw)
    Marker1_time = [];
else
    Marker1_time = Marker1_time_raw - t0;
end

if isempty(Marker2_time_raw)
    Marker2_time = [];
else
    Marker2_time = Marker2_time_raw - t0;
end

%% 11. Clean Marker Labels And Build Marker Tables

Marker1_labels = clean_marker_labels(Marker1_labels_raw);
Marker2_labels = clean_marker_labels(Marker2_labels_raw);

MarkerStream1Table = make_marker_table(Marker1_time, Marker1_labels, Marker1_source_name);
MarkerStream2Table = make_marker_table(Marker2_time, Marker2_labels, Marker2_source_name);

MarkerTable = [MarkerStream1Table; MarkerStream2Table];

if height(MarkerTable) > 0
    MarkerTable = sortrows(MarkerTable, 'Time_seconds');
end

Marker_time = MarkerTable.Time_seconds;
Marker_labels = MarkerTable.Marker_Label;
Marker_source = MarkerTable.Marker_Source;

%% 12. Get Sample Rates And Channel Labels

EEG_srate = str2double(get_xdf_info(eegStream, 'nominal_srate'));
EMG_srate = str2double(get_xdf_info(emgStream, 'nominal_srate'));
ForcePlate_srate = str2double(get_xdf_info(forceStream, 'nominal_srate'));

EEG_channel_labels = get_xdf_channel_labels(eegStream);
EMG_channel_labels = get_xdf_channel_labels(emgStream);
ForcePlate_channel_labels = get_xdf_channel_labels(forceStream);

%% 13. Build Organized Multimodal Structure

MultiModal = struct();

MultiModal.Meta.source_file = xdfFile;
MultiModal.Meta.original_filename = file;
MultiModal.Meta.import_datetime = string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
MultiModal.Meta.fileheader = fileheader;
MultiModal.Meta.time_zero_note = ...
    'All time vectors are in seconds relative to the first stream start time.';

MultiModal.Meta.selected_stream_indices.EEG = eegIdx;
MultiModal.Meta.selected_stream_indices.EMG = emgIdx;
MultiModal.Meta.selected_stream_indices.ForcePlate = forceIdx;
MultiModal.Meta.selected_stream_indices.MarkerStream1 = marker1Idx;
MultiModal.Meta.selected_stream_indices.MarkerStream2 = marker2Idx;

MultiModal.EEG.data = EEG_data;
MultiModal.EEG.time = EEG_time;
MultiModal.EEG.srate = EEG_srate;
MultiModal.EEG.info = eegStream.info;
MultiModal.EEG.channel_labels = EEG_channel_labels;

MultiModal.EMG.data = EMG_data;
MultiModal.EMG.time = EMG_time;
MultiModal.EMG.srate = EMG_srate;
MultiModal.EMG.info = emgStream.info;
MultiModal.EMG.channel_labels = EMG_channel_labels;

MultiModal.ForcePlate.data = ForcePlate_data;
MultiModal.ForcePlate.time = ForcePlate_time;
MultiModal.ForcePlate.srate = ForcePlate_srate;
MultiModal.ForcePlate.info = forceStream.info;
MultiModal.ForcePlate.channel_labels = ForcePlate_channel_labels;

% Main combined marker output.
MultiModal.Markers.time = Marker_time;
MultiModal.Markers.labels = Marker_labels;
MultiModal.Markers.source = Marker_source;
MultiModal.Markers.table = MarkerTable;

% Marker stream 1.
MultiModal.Markers.Stream1.name = Marker1_source_name;
MultiModal.Markers.Stream1.time = Marker1_time(:);
MultiModal.Markers.Stream1.labels = Marker1_labels(:);
MultiModal.Markers.Stream1.table = MarkerStream1Table;
MultiModal.Markers.Stream1.info = Marker1_info;

% Marker stream 2.
MultiModal.Markers.Stream2.name = Marker2_source_name;
MultiModal.Markers.Stream2.time = Marker2_time(:);
MultiModal.Markers.Stream2.labels = Marker2_labels(:);
MultiModal.Markers.Stream2.table = MarkerStream2Table;
MultiModal.Markers.Stream2.info = Marker2_info;

%% 14. Print Summary

fprintf('\n===== Organized data summary =====\n');

fprintf('EEG:         %d channels x %d samples, %.2f Hz\n', ...
    size(EEG_data, 1), size(EEG_data, 2), EEG_srate);

fprintf('EMG:         %d channels x %d samples, %.2f Hz\n', ...
    size(EMG_data, 1), size(EMG_data, 2), EMG_srate);

fprintf('Force Plate: %d channels x %d samples, %.2f Hz\n', ...
    size(ForcePlate_data, 1), size(ForcePlate_data, 2), ForcePlate_srate);

fprintf('Marker stream 1 (%s): %d events\n', Marker1_source_name, height(MarkerStream1Table));
fprintf('Marker stream 2 (%s): %d events\n', Marker2_source_name, height(MarkerStream2Table));
fprintf('Combined MarkerTable: %d events\n', height(MarkerTable));

fprintf('\nCombined MarkerTable:\n');
disp(MarkerTable);

%% 15. Create Output Folder

processedFolder = fullfile(folder, 'processed_mat');

if ~exist(processedFolder, 'dir')
    mkdir(processedFolder);
end

%% 16. Save Files

[~, baseName, ~] = fileparts(file);

outputMatFile = fullfile(processedFolder, [baseName '_multimodal_raw.mat']);
outputMarkerFile = fullfile(processedFolder, [baseName '_markers.csv']);
outputMarker1File = fullfile(processedFolder, [baseName '_marker_stream_1.csv']);
outputMarker2File = fullfile(processedFolder, [baseName '_marker_stream_2.csv']);

save(outputMatFile, ...
    'MultiModal', ...
    'EEG_data', 'EEG_time', 'EEG_srate', 'EEG_channel_labels', ...
    'EMG_data', 'EMG_time', 'EMG_srate', 'EMG_channel_labels', ...
    'ForcePlate_data', 'ForcePlate_time', 'ForcePlate_srate', 'ForcePlate_channel_labels', ...
    'Marker_time', 'Marker_labels', 'Marker_source', 'MarkerTable', ...
    'MarkerStream1Table', 'MarkerStream2Table', ...
    '-v7.3');

writetable(MarkerTable, outputMarkerFile);
writetable(MarkerStream1Table, outputMarker1File);
writetable(MarkerStream2Table, outputMarker2File);

fprintf('\nSaved organized multimodal file:\n%s\n', outputMatFile);
fprintf('Saved combined marker table:\n%s\n', outputMarkerFile);
fprintf('Saved marker stream 1 table:\n%s\n', outputMarker1File);
fprintf('Saved marker stream 2 table:\n%s\n', outputMarker2File);

fprintf('\nDone. Your XDF is organized into EEG, EMG, ForcePlate, and combined Markers.\n');

fprintf('\nEasy workspace variables created:\n');
fprintf('EEG_data, EEG_time\n');
fprintf('EMG_data, EMG_time\n');
fprintf('ForcePlate_data, ForcePlate_time\n');
fprintf('MarkerTable\n');
fprintf('MarkerStream1Table\n');
fprintf('MarkerStream2Table\n');

%% ===== Helper Functions =====

function check_required_stream_index(idx, nStreams, streamName)
    if isempty(idx)
        error('%s stream number cannot be empty.', streamName);
    end

    if ~isscalar(idx) || idx < 1 || idx > nStreams || idx ~= round(idx)
        error('%s stream number must be an integer from 1 to %d.', streamName, nStreams);
    end
end

function check_optional_stream_index(idx, nStreams, streamName)
    if isempty(idx)
        return
    end

    if ~isscalar(idx) || idx < 1 || idx > nStreams || idx ~= round(idx)
        error('%s stream number must be [] or an integer from 1 to %d.', streamName, nStreams);
    end
end

function [markerTimeRaw, markerLabelsRaw, sourceName, streamInfo] = extract_marker_stream(markerStream, defaultName)
    if isempty(markerStream)
        markerTimeRaw = [];
        markerLabelsRaw = {};
        sourceName = defaultName + "_NotRecorded";
        streamInfo = [];
        return
    end

    if isfield(markerStream, 'time_stamps')
        markerTimeRaw = markerStream.time_stamps;
    else
        markerTimeRaw = [];
    end

    if isfield(markerStream, 'time_series')
        markerLabelsRaw = markerStream.time_series;
    else
        markerLabelsRaw = {};
    end

    sourceName = string(get_xdf_info(markerStream, 'name'));

    if strlength(sourceName) == 0
        sourceName = defaultName;
    end

    if isfield(markerStream, 'info')
        streamInfo = markerStream.info;
    else
        streamInfo = [];
    end
end

function value = get_xdf_info(stream, fieldname)
    value = '';

    if isfield(stream, 'info') && isfield(stream.info, fieldname)
        value = stream.info.(fieldname);

        if iscell(value)
            value = value{1};
        end

        if isnumeric(value)
            value = num2str(value);
        end
    end
end

function dataOut = make_channels_by_samples(dataIn, timeVector)
    dataOut = dataIn;

    nSamples = length(timeVector);

    if size(dataOut, 2) == nSamples
        return
    elseif size(dataOut, 1) == nSamples
        dataOut = dataOut';
    else
        warning('Data size does not clearly match timestamp length. Leaving orientation unchanged.');
    end
end

function labelsOut = clean_marker_labels(labelsIn)
    if isempty(labelsIn)
        labelsOut = strings(0, 1);
        return
    end

    if iscell(labelsIn)
        labelsOut = strings(numel(labelsIn), 1);

        for i = 1:numel(labelsIn)
            label = labelsIn{i};

            if iscell(label)
                label = label{1};
            end

            if isnumeric(label)
                label = num2str(label);
            end

            labelsOut(i) = string(label);
        end

    elseif isstring(labelsIn)
        labelsOut = labelsIn(:);

    elseif ischar(labelsIn)
        labelsOut = string(cellstr(labelsIn));
        labelsOut = labelsOut(:);

    elseif isnumeric(labelsIn)
        labelsOut = string(labelsIn(:));

    else
        labelsOut = string(labelsIn(:));
    end
end

function MarkerTableOut = make_marker_table(markerTime, markerLabels, sourceName)
    markerTime = markerTime(:);
    markerLabels = markerLabels(:);

    nMarkers = min(numel(markerTime), numel(markerLabels));

    markerSource = repmat(string(sourceName), nMarkers, 1);

    MarkerTableOut = table( ...
        markerTime(1:nMarkers), ...
        markerLabels(1:nMarkers), ...
        markerSource, ...
        'VariableNames', {'Time_seconds', 'Marker_Label', 'Marker_Source'} ...
    );
end

function labels = get_xdf_channel_labels(stream)
    try
        desc = stream.info.desc;

        if iscell(desc)
            desc = desc{1};
        end

        channels = desc.channels;

        if iscell(channels)
            channels = channels{1};
        end

        channelStruct = channels.channel;

        if ~iscell(channelStruct)
            channelStruct = num2cell(channelStruct);
        end

        labels = strings(length(channelStruct), 1);

        for c = 1:length(channelStruct)
            thisChannel = channelStruct{c};

            if isfield(thisChannel, 'label')
                label = thisChannel.label;

                if iscell(label)
                    label = label{1};
                end

                labels(c) = string(label);
            else
                labels(c) = "Ch" + c;
            end
        end

    catch
        labels = strings(0, 1);
    end
end
