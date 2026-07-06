% Purpose:
% Load a LabRecorder .xdf file containing EEG, EMG, force plate, and marker streams.
% Organize all streams into one synchronized MATLAB structure.
% Save the organized data as a .mat file and save markers as a .csv file.
%
% Workflow:
% 1. Record EEG, EMG, Bertec force plate, and marker streams in LabRecorder.
% 2. Save the recording as a .xdf file.
% 3. Run this script.
% 4. Select the .xdf file.
% 5. Enter the stream numbers when prompted.
% 6. The script saves an organized MultiModal structure.

clear; clc;

%% 0. Make Sure load_xdf is Available

if exist('load_xdf', 'file') ~= 2

    fprintf('\nload_xdf was not found on the MATLAB path.\n');
    fprintf('Searching common folders...\n');

    userHome = char(java.lang.System.getProperty('user.home'));

    possibleRoots = {
        pwd
        userpath
        fullfile(userHome, 'Documents', 'MATLAB')
        fullfile(userHome, 'Downloads')
        fullfile(userHome, 'Desktop')
    };

    foundXDF = '';

    for r = 1:length(possibleRoots)
        rootFolder = possibleRoots{r};

        if isempty(rootFolder)
            continue
        end

        % Userpath can sometimes contain multiple folders separated by pathsep
        splitRoots = strsplit(rootFolder, pathsep);

        for sr = 1:length(splitRoots)
            thisRoot = splitRoots{sr};

            if isempty(thisRoot) || ~isfolder(thisRoot)
                continue
            end

            matches = dir(fullfile(thisRoot, '**', 'load_xdf.m'));

            if ~isempty(matches)
                foundXDF = matches(1).folder;
                break
            end
        end

        if ~isempty(foundXDF)
            break
        end
    end

    if isempty(foundXDF)
        fprintf('\nCould not automatically find load_xdf.m.\n');
        foundXDF = uigetdir('', 'Select the folder that contains load_xdf.m');
    end

    if isequal(foundXDF, 0) || isempty(foundXDF)
        error('No XDF folder selected. Cannot continue without load_xdf.m.');
    end

    addpath(genpath(foundXDF));

    try
        savepath;
    catch
        warning('Path added for this MATLAB session, but MATLAB could not permanently save the path.');
    end
end

if exist('load_xdf', 'file') ~= 2
    error('load_xdf is still not available. Check that the XDF importer folder exists.');
else
    fprintf('\nUsing load_xdf from:\n%s\n', which('load_xdf'));
end

%% 1. Select the XDF File

[file, path] = uigetfile('*.xdf', 'Select your LabRecorder XDF file');

if isequal(file, 0)
    error('No file selected.');
end

fullFile = fullfile(path, file);
fprintf('\nSelected file:\n%s\n', fullFile);

%% 2. Load the XDF File

[streams, fileheader] = load_xdf(fullFile);

%% 3. Print Stream Information

fprintf('\n===== Streams found in this XDF file =====\n');

for i = 1:length(streams)
    name = get_xdf_info(streams{i}, 'name');
    type = get_xdf_info(streams{i}, 'type');
    chanCount = get_xdf_info(streams{i}, 'channel_count');
    srate = get_xdf_info(streams{i}, 'nominal_srate');

    nSamples = length(streams{i}.time_stamps);
    dataSize = size(streams{i}.time_series);

    fprintf('\nSTREAM %d\n', i);
    fprintf('Name: %s\n', name);
    fprintf('Type: %s\n', type);
    fprintf('Channels: %s\n', chanCount);
    fprintf('Nominal srate: %s\n', srate);
    fprintf('Samples: %d\n', nSamples);
    fprintf('Data size: %s\n', mat2str(dataSize));

    if nSamples == 0
        fprintf('WARNING: This stream has 0 samples.\n');
    end
end

%% 4. Enter Stream Numbers

fprintf('\nEnter the stream numbers based on the list above.\n');

eegIdx = input('EEG stream number: ');
emgIdx = input('EMG stream number: ');
forceIdx = input('Force plate stream number: ');
markerIdx = input('Marker stream number: ');

%% 5. Assign Streams

eegStream = streams{eegIdx};
emgStream = streams{emgIdx};
forceStream = streams{forceIdx};
markerStream = streams{markerIdx};

%% 6. Extract Data and Timestamps

EEG_data = double(eegStream.time_series);
EMG_data = double(emgStream.time_series);
Force_data = double(forceStream.time_series);

EEG_time = eegStream.time_stamps;
EMG_time = emgStream.time_stamps;
Force_time = forceStream.time_stamps;
Marker_time = markerStream.time_stamps;
Marker_labels = markerStream.time_series;

%% 7. Make Sure Data is Channels x Samples

EEG_data = make_channels_by_samples(EEG_data, EEG_time);
EMG_data = make_channels_by_samples(EMG_data, EMG_time);
Force_data = make_channels_by_samples(Force_data, Force_time);

%% 8. Check Selected Streams

fprintf('\n===== Selected stream sample counts =====\n');
fprintf('EEG samples:         %d\n', length(EEG_time));
fprintf('EMG samples:         %d\n', length(EMG_time));
fprintf('Force plate samples: %d\n', length(Force_time));
fprintf('Marker samples:      %d\n', length(Marker_time));

if isempty(EEG_time)
    error('Selected EEG stream has 0 samples. Choose a different EEG stream or re-record EEG.');
end

if isempty(EMG_time)
    error('Selected EMG stream has 0 samples. Choose a different EMG stream or re-record EMG.');
end

if isempty(Force_time)
    warning('Selected force plate stream has 0 samples. Continuing without force plate data.');
end

if isempty(Marker_time)
    warning('Selected marker stream has 0 events.');
end

%% 9. Convert All Timestamps to Seconds From Recording Start

startTimes = [];

if ~isempty(EEG_time)
    startTimes(end+1) = EEG_time(1);
end

if ~isempty(EMG_time)
    startTimes(end+1) = EMG_time(1);
end

if ~isempty(Force_time)
    startTimes(end+1) = Force_time(1);
end

if ~isempty(Marker_time)
    startTimes(end+1) = Marker_time(1);
end

if isempty(startTimes)
    error('No streams contain timestamps. Cannot continue.');
end

t0 = min(startTimes);

EEG_time_sec = EEG_time - t0;
EMG_time_sec = EMG_time - t0;
Force_time_sec = Force_time - t0;
Marker_time_sec = Marker_time - t0;

%% 10. Clean Marker Labels

Marker_labels_clean = clean_marker_labels(Marker_labels);

%% 11. Make Marker Table

nMarkers = min(numel(Marker_time_sec), numel(Marker_labels_clean));

if numel(Marker_time_sec) ~= numel(Marker_labels_clean)
    warning('Marker time count and marker label count do not match. Using the shortest length.');
end

MarkerTable = table( ...
    Marker_time_sec(1:nMarkers)', ...
    string(Marker_labels_clean(1:nMarkers)), ...
    'VariableNames', {'Time_seconds', 'Marker_Label'} ...
);

%% 12. Build Organized Multimodal Structure

MultiModal = struct();

MultiModal.Meta.source_file = fullFile;
MultiModal.Meta.original_filename = file;
MultiModal.Meta.import_date = datestr(now);
MultiModal.Meta.fileheader = fileheader;
MultiModal.Meta.time_zero_note = 'All time vectors are in seconds relative to the first available stream start time.';

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

if isempty(Force_time)
    MultiModal.ForcePlate.data = [];
    MultiModal.ForcePlate.time = [];
    MultiModal.ForcePlate.srate = [];
    MultiModal.ForcePlate.info = forceStream.info;
    MultiModal.ForcePlate.channel_labels = get_xdf_channel_labels(forceStream);
    MultiModal.ForcePlate.note = 'No force plate samples were recorded in this XDF file.';
else
    MultiModal.ForcePlate.data = Force_data;
    MultiModal.ForcePlate.time = Force_time_sec;
    MultiModal.ForcePlate.srate = str2double(get_xdf_info(forceStream, 'nominal_srate'));
    MultiModal.ForcePlate.info = forceStream.info;
    MultiModal.ForcePlate.channel_labels = get_xdf_channel_labels(forceStream);
end

MultiModal.Markers.labels = Marker_labels_clean;
MultiModal.Markers.time = Marker_time_sec;
MultiModal.Markers.info = markerStream.info;
MultiModal.Markers.table = MarkerTable;

%% 13. Print Basic Summary

fprintf('\n===== Organized data summary =====\n');

fprintf('EEG:         %d channels x %d samples, %.2f Hz\n', ...
    size(EEG_data, 1), size(EEG_data, 2), MultiModal.EEG.srate);

fprintf('EMG:         %d channels x %d samples, %.2f Hz\n', ...
    size(EMG_data, 1), size(EMG_data, 2), MultiModal.EMG.srate);

if isempty(Force_time)
    fprintf('Force Plate: no samples recorded\n');
else
    fprintf('Force Plate: %d channels x %d samples, %.2f Hz\n', ...
        size(Force_data, 1), size(Force_data, 2), MultiModal.ForcePlate.srate);
end

fprintf('Markers:     %d events\n', height(MarkerTable));

disp(MarkerTable);

%% 14. Create Output Folder

mainFolder = fileparts(path);
processedFolder = fullfile(mainFolder, 'processed_mat');

if ~exist(processedFolder, 'dir')
    mkdir(processedFolder);
end

%% 15. Create Output Filenames

[~, baseName, ~] = fileparts(file);

outputMatFile = fullfile(processedFolder, [baseName '_multimodal_raw.mat']);
outputMarkerFile = fullfile(processedFolder, [baseName '_markers.csv']);

%% 16. Save Organized Data

save(outputMatFile, 'MultiModal', '-v7.3');
writetable(MarkerTable, outputMarkerFile);

fprintf('\nSaved organized multimodal file:\n%s\n', outputMatFile);
fprintf('Saved marker table:\n%s\n', outputMarkerFile);

fprintf('\nDone. Your XDF is now organized into EEG, EMG, ForcePlate, and Markers.\n');

%% ===== Local helper functions =====

function value = get_xdf_info(stream, fieldname)
    if isfield(stream.info, fieldname)
        value = stream.info.(fieldname);

        if iscell(value)
            value = value{1};
        end

        if isnumeric(value)
            value = num2str(value);
        end
    else
        value = '';
    end
end

function dataOut = make_channels_by_samples(dataIn, timeVector)
    dataOut = dataIn;

    if isempty(dataOut) || isempty(timeVector)
        return
    end

    % This project stores data as channels x samples.
    % The number of samples should match length(timeVector).
    if size(dataOut, 2) ~= length(timeVector) && size(dataOut, 1) == length(timeVector)
        dataOut = dataOut';
    end
end

function labelsOut = clean_marker_labels(labelsIn)
    if isempty(labelsIn)
        labelsOut = strings(0, 1);
        return
    end

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
end

function labels = get_xdf_channel_labels(stream)
    labels = strings(0, 1);

    try
        if ~isfield(stream.info, 'desc')
            return
        end

        desc = stream.info.desc;

        if iscell(desc)
            desc = desc{1};
        end

        if ~isfield(desc, 'channels')
            return
        end

        channels = desc.channels;

        if iscell(channels)
            channels = channels{1};
        end

        if ~isfield(channels, 'channel')
            return
        end

        channelStruct = channels.channel;

        if ~iscell(channelStruct)
            channelStruct = num2cell(channelStruct);
        end

        labels = strings(length(channelStruct), 1);

        for c = 1:length(channelStruct)
            ch = channelStruct{c};

            if isfield(ch, 'label')
                label = ch.label;

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
