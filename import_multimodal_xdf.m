% Purpose:
% Load a LabRecorder .xdf file containing EEG, EMG, force plate, and markers.
% Separate the streams into one organized MATLAB structure.
% Save the organized data as a .mat file and save markers as a .csv file.

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

eegIdx = input('EEG stream number: ');
emgIdx = input('EMG stream number: ');
forceIdx = input('Force plate stream number: ');
markerIdx = input('Marker stream number: ');

check_stream_index(eegIdx, length(streams), 'EEG');
check_stream_index(emgIdx, length(streams), 'EMG');
check_stream_index(forceIdx, length(streams), 'Force plate');
check_stream_index(markerIdx, length(streams), 'Marker');

%% 6. Assign Streams

eegStream = streams{eegIdx};
emgStream = streams{emgIdx};
forceStream = streams{forceIdx};
markerStream = streams{markerIdx};

%% 7. Extract Data and Timestamps

EEG_data = double(eegStream.time_series);
EMG_data = double(emgStream.time_series);
Force_data = double(forceStream.time_series);

EEG_time = eegStream.time_stamps;
EMG_time = emgStream.time_stamps;
Force_time = forceStream.time_stamps;
Marker_time = markerStream.time_stamps;
Marker_labels = markerStream.time_series;

%% 8. Make Sure Required Streams Are Not Empty

if isempty(EEG_time) || isempty(EEG_data)
    error('The selected EEG stream is empty. Check the EEG stream number.');
end

if isempty(EMG_time) || isempty(EMG_data)
    error('The selected EMG stream is empty. Check the EMG stream number.');
end

if isempty(Force_time) || isempty(Force_data)
    error('The selected force plate stream is empty. Check the force plate stream number.');
end

if isempty(Marker_time) || isempty(Marker_labels)
    error('The selected marker stream is empty. Check the marker stream number.');
end

%% 9. Make All Data Channels x Samples

EEG_data = make_channels_by_samples(EEG_data, EEG_time);
EMG_data = make_channels_by_samples(EMG_data, EMG_time);
Force_data = make_channels_by_samples(Force_data, Force_time);

%% 10. Convert Timestamps to Seconds From Recording Start

t0 = min([EEG_time(1), EMG_time(1), Force_time(1), Marker_time(1)]);

EEG_time_sec = EEG_time - t0;
EMG_time_sec = EMG_time - t0;
Force_time_sec = Force_time - t0;
Marker_time_sec = Marker_time - t0;

%% 11. Clean Marker Labels

Marker_labels_clean = clean_marker_labels(Marker_labels);

Marker_time_sec = Marker_time_sec(:);
Marker_labels_clean = Marker_labels_clean(:);

nMarkers = min(numel(Marker_time_sec), numel(Marker_labels_clean));

MarkerTable = table( ...
    Marker_time_sec(1:nMarkers), ...
    Marker_labels_clean(1:nMarkers), ...
    'VariableNames', {'Time_seconds', 'Marker_Label'} ...
);

%% 12. Build Organized Multimodal Structure

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
MultiModal.Meta.selected_stream_indices.Markers = markerIdx;

MultiModal.EEG.data = EEG_data;
MultiModal.EEG.time = EEG_time_sec;
MultiModal.EEG.srate = str2double(get_xdf_info(eegStream, 'nominal_srate'));
MultiModal.EEG.info = eegStream.info;
MultiModal.EEG.channel_labels = get_xdf_channel_labels(eegStream);

MultiModal.EMG.data = EMG_data;
MultiModal.EMG.time = EMG_time_sec;
MultiModal.EMG.srate = str2double(get_xdf_info(emgStream, 'nominal_srate'));
MultiModal.EMG.info = emgStream.info;
MultiModal.EMG.channel_labels = get_xdf_channel_labels(emgStream);

MultiModal.ForcePlate.data = Force_data;
MultiModal.ForcePlate.time = Force_time_sec;
MultiModal.ForcePlate.srate = str2double(get_xdf_info(forceStream, 'nominal_srate'));
MultiModal.ForcePlate.info = forceStream.info;
MultiModal.ForcePlate.channel_labels = get_xdf_channel_labels(forceStream);

MultiModal.Markers.time = Marker_time_sec;
MultiModal.Markers.labels = Marker_labels_clean;
MultiModal.Markers.table = MarkerTable;
MultiModal.Markers.info = markerStream.info;

%% 13. Print Summary

fprintf('\n===== Organized data summary =====\n');

fprintf('EEG:         %d channels x %d samples, %.2f Hz\n', ...
    size(EEG_data, 1), size(EEG_data, 2), MultiModal.EEG.srate);

fprintf('EMG:         %d channels x %d samples, %.2f Hz\n', ...
    size(EMG_data, 1), size(EMG_data, 2), MultiModal.EMG.srate);

fprintf('Force Plate: %d channels x %d samples, %.2f Hz\n', ...
    size(Force_data, 1), size(Force_data, 2), MultiModal.ForcePlate.srate);

fprintf('Markers:     %d events\n', height(MarkerTable));

disp(MarkerTable);

%% 14. Create Output Folder

processedFolder = fullfile(folder, 'processed_mat');

if ~exist(processedFolder, 'dir')
    mkdir(processedFolder);
end

%% 15. Save Files

[~, baseName, ~] = fileparts(file);

outputMatFile = fullfile(processedFolder, [baseName '_multimodal_raw.mat']);
outputMarkerFile = fullfile(processedFolder, [baseName '_markers.csv']);

save(outputMatFile, 'MultiModal', '-v7.3');
writetable(MarkerTable, outputMarkerFile);

fprintf('\nSaved organized multimodal file:\n%s\n', outputMatFile);
fprintf('Saved marker table:\n%s\n', outputMarkerFile);

fprintf('\nDone. Your XDF is organized into EEG, EMG, ForcePlate, and Markers.\n');

%% ===== Helper functions =====

function check_stream_index(idx, nStreams, streamName)
    if isempty(idx)
        error('%s stream number cannot be empty.', streamName);
    end

    if ~isscalar(idx) || idx < 1 || idx > nStreams || idx ~= round(idx)
        error('%s stream number must be an integer from 1 to %d.', streamName, nStreams);
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
    labelsOut = strings(numel(labelsIn), 1);

    for i = 1:numel(labelsIn)
        if iscell(labelsIn)
            label = labelsIn{i};
        elseif isstring(labelsIn)
            label = labelsIn(i);
        elseif ischar(labelsIn)
            label = labelsIn;
        elseif isnumeric(labelsIn)
            label = labelsIn(i);
        else
            label = labelsIn(i);
        end

        if iscell(label)
            label = label{1};
        end

        if isnumeric(label)
            label = num2str(label);
        end

        labelsOut(i) = string(label);
    end
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
