% Purpose:
% Load your organized multimodal .mat file.
% Import EEG_data into EEGLAB.
% Add MarkerTable events.
% Save an EEGLAB .set file.

clear; clc;

%% 1. Select organized multimodal .mat file

[file, folder] = uigetfile('*.mat', 'Select organized multimodal .mat file');

if isequal(file, 0)
    error('No .mat file selected.');
end

matFile = fullfile(folder, file);
fprintf('\nSelected file:\n%s\n', matFile);

load(matFile);

%% 2. Check required variables

if ~exist('EEG_data', 'var')
    error('EEG_data was not found in the .mat file.');
end

if ~exist('EEG_time', 'var')
    error('EEG_time was not found in the .mat file.');
end

if ~exist('EEG_srate', 'var')
    error('EEG_srate was not found in the .mat file.');
end

if ~exist('MarkerTable', 'var')
    warning('MarkerTable was not found. EEG will be imported without events.');
    MarkerTable = table();
end

%% 3. Start EEGLAB

if exist('eeglab', 'file') ~= 2
    error('EEGLAB was not found on the MATLAB path. Add EEGLAB to the MATLAB path first.');
end

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

%% 4. Create EEGLAB EEG structure

EEG = eeg_emptyset;

EEG.data = double(EEG_data);
EEG.nbchan = size(EEG_data, 1);
EEG.pnts = size(EEG_data, 2);
EEG.trials = 1;
EEG.srate = EEG_srate;

% EEGLAB time starts at 0 seconds for this EEG dataset
EEG.xmin = 0;
EEG.xmax = (EEG.pnts - 1) / EEG.srate;

[~, baseName, ~] = fileparts(file);
EEG.setname = [baseName '_EEG'];

%% 5. Add EEG channel labels

if exist('EEG_channel_labels', 'var') && ~isempty(EEG_channel_labels)
    EEG_channel_labels = EEG_channel_labels(:);

    for ch = 1:min(length(EEG_channel_labels), EEG.nbchan)
        EEG.chanlocs(ch).labels = char(EEG_channel_labels(ch));
    end
else
    for ch = 1:EEG.nbchan
        EEG.chanlocs(ch).labels = ['Ch' num2str(ch)];
    end
end

%% 6. Add MarkerTable events to EEGLAB

EEG.event = [];

eventCount = 0;

if height(MarkerTable) > 0

    for i = 1:height(MarkerTable)

        eventTime = MarkerTable.Time_seconds(i);

        % Only keep markers that occur during the EEG recording
        if eventTime >= EEG_time(1) && eventTime <= EEG_time(end)

            eventCount = eventCount + 1;

            EEG.event(eventCount).type = char(MarkerTable.Marker_Label(i));

            % EEGLAB latency is in sample points, not seconds
            EEG.event(eventCount).latency = round((eventTime - EEG_time(1)) * EEG_srate) + 1;

            % Keep marker source if available, such as GuiMarkers or MVCMarkers
            if ismember('Marker_Source', MarkerTable.Properties.VariableNames)
                EEG.event(eventCount).source = char(MarkerTable.Marker_Source(i));
            end
        end
    end
end

%% 7. Check EEGLAB dataset

EEG = eeg_checkset(EEG, 'eventconsistency');

%% 8. Store dataset in EEGLAB

[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);
eeglab redraw;

fprintf('\nEEG imported into EEGLAB successfully.\n');
fprintf('Channels: %d\n', EEG.nbchan);
fprintf('Samples:  %d\n', EEG.pnts);
fprintf('Srate:    %.2f Hz\n', EEG.srate);
fprintf('Events:   %d\n', length(EEG.event));

%% 9. Save EEGLAB .set file

outputFolder = fullfile(folder, 'eeglab_sets');

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

EEG = pop_saveset(EEG, ...
    'filename', [baseName '_EEG.set'], ...
    'filepath', outputFolder);

fprintf('\nSaved EEGLAB dataset:\n%s\n', fullfile(outputFolder, [baseName '_EEG.set']));
