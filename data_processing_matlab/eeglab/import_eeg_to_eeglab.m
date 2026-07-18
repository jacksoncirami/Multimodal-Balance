%% import_eeg_to_eeglab
% Import organized EEG data into EEGLAB using timing information from the
% original LabRecorder XDF file.
%
% The script loads EEG_data from an organized multimodal MAT file, finds
% the matching EEG stream in the original XDF recording, calculates the
% effective sampling rate from the original EEG timestamps, imports all XDF
% marker streams as EEGLAB events, and saves the completed dataset as a
% .set file.
%
% Inputs:
%   - Organized multimodal MAT file containing EEG_data
%   - Original LabRecorder XDF file used to create the MAT file
%
% Outputs:
%   - EEGLAB EEG structure in the MATLAB workspace
%   - Timing-corrected EEGLAB .set file
%
% Requirements:
%   - MATLAB
%   - EEGLAB available on the MATLAB path
%   - load_xdf available on the MATLAB path
%
% Usage:
%   Run the script and select the organized MAT file followed by its
%   corresponding original XDF recording.

clear;
clc;

%% 1. Select the Organized Multimodal MAT File

[matFileName, matFolder] = uigetfile( ...
    '*.mat', ...
    'Select organized multimodal MAT file');

if isequal(matFileName, 0)
    error('No organized MAT file was selected.');
end

matFile = fullfile(matFolder, matFileName);

fprintf('\nSelected organized MAT file:\n%s\n', matFile);

load(matFile);

%% 2. Confirm That EEG Data Exists

if ~exist('EEG_data', 'var')
    error('EEG_data was not found in the organized MAT file.');
end

EEG_data = double(EEG_data);

fprintf('\nEEG_data size in MAT file: %d x %d\n', ...
    size(EEG_data, 1), size(EEG_data, 2));

%% 3. Select the Original XDF File

[xdfFileName, xdfFolder] = uigetfile( ...
    '*.xdf', ...
    'Select the original XDF file used to create the MAT file');

if isequal(xdfFileName, 0)
    error('No original XDF file was selected.');
end

xdfFile = fullfile(xdfFolder, xdfFileName);

fprintf('\nSelected original XDF file:\n%s\n', xdfFile);

%% 4. Load the Original XDF File

if exist('load_xdf', 'file') ~= 2
    error([ ...
        'The load_xdf function was not found on the MATLAB path. ' ...
        'Add the XDF importer or liblsl-MATLAB folder to the MATLAB path.']);
end

[streams, ~] = load_xdf(xdfFile);

if isempty(streams)
    error('No streams were found in the selected XDF file.');
end

%% 5. Find the EEG Stream Matching EEG_data

% A stream is considered a possible EEG match when its name or type looks
% like EEG and its sample count matches one dimension of EEG_data.

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

        % Prefer the known OpenBCI stream name when it is available.
        if strcmpi(streamName, 'obci_eeg1')
            break;
        end
    end
end

if isempty(eegStreamIndex)

    fprintf('\nStreams found in the XDF:\n');

    for k = 1:numel(streams)

        streamNameValue = streams{k}.info.name;
        streamTypeValue = streams{k}.info
