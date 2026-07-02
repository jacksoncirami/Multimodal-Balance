% Purpose:
% Load a LabRecorder .xdf file with EEG, EMG, force plate, and marker streams
% Organize the streams into one synchronized MATLAB structure
% Save the organized data as a .mat file

clear; clc;

%% 1. Select the XDF File
[file, path] = uigetfile('*.xdf', 'Select your LabRecorder XDF file');

if isequal(file,0)
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
    samples = length(streams{i}.time_stamps);

    fprintf('\nSTREAM %d\n', i);
    fprintf('Name: %s\n', name);
    fprintf('Type: %s\n', type);
    fprintf('Channels: %s\n', chanCount);
    fprintf('Nominal srate: %s\n', srate);
    fprintf('Samples: %d\n', samples);
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

%% 7. Make Sure Data Is Channels x Samples
EEG_data = make_channels_by_samples(EEG_data, EEG_time);
EMG_data = make_channels_by_samples(EMG_data, EMG_time);
Force_data = make_channels_by_samples(Force_data, Force_time);

%% 8. Convert All Timestamps To Seconds From Recording Start
t0 = min([EEG_time(1), EMG_time(1), Force_time(1)]);

EEG_time_sec = EEG_time - t0;
EMG_time_sec = EMG_time - t0;
Force_time_sec = Force_time - t0;
Marker_time_sec = Marker_time - t0;

%% 9. Clean Marker Labels
Marker_labels_clean = clean_marker_labels(Marker_labels);

%% 10. Build Organized Multimodal Structure
MultiModal = struct();

MultiModal.Meta.source_file = fullFile;
MultiModal.Meta.original_filename = file;
MultiModal.Meta.import_date = datestr(now);
MultiModal.Meta.fileheader = fileheader;
MultiModal.Meta.time_zero_note = 'All time vectors are in seconds relative to the first stream start time.';

MultiModal.EEG.data = EEG_data;
MultiModal.EEG.time = EEG_time_sec;
MultiModal.EEG.srate = str2double(get_xdf_info(eegStream, 'nominal_srate'));
MultiModal.EEG.info = eegStream.info;

MultiModal.EMG.data = EMG_data;
MultiModal.EMG.time = EMG_time_sec;
MultiModal.EMG.srate = str2double(get_xdf_info(emgStream, 'nominal_srate'));
MultiModal.EMG.info = emgStream.info;

MultiModal.ForcePlate.data = Force_data;
MultiModal.ForcePlate.time = Force_time_sec;
MultiModal.ForcePlate.srate = str2double(get_xdf_info(forceStream, 'nominal_srate'));
MultiModal.ForcePlate.info = forceStream.info;

MultiModal.Markers.labels = Marker_labels_clean;
MultiModal.Markers.time = Marker_time_sec;
MultiModal.Markers.info = markerStream.info;

%% 11. Make Marker Table
MarkerTable = table( ...
    Marker_time_sec(:), ...
    string(Marker_labels_clean(:)), ...
    'VariableNames', {'Time_seconds', 'Marker_Label'} ...
);

MultiModal.Markers.table = MarkerTable;

%% 12. Print Basic Summary
fprintf('\n===== Organized data summary =====\n');
fprintf('EEG:         %d channels x %d samples, %.2f Hz\n', ...
    size(EEG_data,1), size(EEG_data,2), MultiModal.EEG.srate);

fprintf('EMG:         %d channels x %d samples, %.2f Hz\n', ...
    size(EMG_data,1), size(EMG_data,2), MultiModal.EMG.srate);

fprintf('Force Plate: %d channels x %d samples, %.2f Hz\n', ...
    size(Force_data,1), size(Force_data,2), MultiModal.ForcePlate.srate);

fprintf('Markers:     %d events\n', height(MarkerTable));

disp(MarkerTable);

%% 13. Create Output Folder
mainFolder = fileparts(path);
processedFolder = fullfile(mainFolder, 'processed_mat');

if ~exist(processedFolder, 'dir')
    mkdir(processedFolder);
end

%% 14. Create Output Filename
[~, baseName, ~] = fileparts(file);
outputMatFile = fullfile(processedFolder, [baseName '_multimodal_raw.mat']);
outputMarkerFile = fullfile(processedFolder, [baseName '_markers.csv']);

%% 15. Save Organized Data
save(outputMatFile, 'MultiModal', '-v7.3');
writetable(MarkerTable, outputMarkerFile);

fprintf('\nSaved organized multimodal file:\n%s\n', outputMatFile);
fprintf('\nSaved marker table:\n%s\n', outputMarkerFile);

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

    % EEGLAB/MATLAB workflow is easier if data is channels x samples.
    % The number of samples should match length(timeVector).
    if size(dataOut,2) ~= length(timeVector) && size(dataOut,1) == length(timeVector)
        dataOut = dataOut';
    end
end

function labelsOut = clean_marker_labels(labelsIn)
    labelsOut = strings(length(labelsIn),1);

    for i = 1:length(labelsIn)
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
