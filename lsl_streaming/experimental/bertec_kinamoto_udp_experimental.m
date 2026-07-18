%% bertec_kinamoto_udp_experimental
% EXPERIMENTAL — UNSUCCESSFUL KINAMOTO UDP APPROACH
%
% Attempts to receive Bertec force-plate data from Kinamoto through UDP,
% interpret the incoming data as text-based numeric rows, and forward valid
% samples through Lab Streaming Layer.
%
% This approach did not produce a working Kinamoto-to-LSL bridge in the
% tested configuration.
%
% Kinamoto is intended to support continuous data output, but this script
% was not successfully validated as a method for accessing and streaming
% that output through MATLAB and LSL.
%
% The script is retained only to document the attempted integration method
% and the assumptions that were tested. It is not part of the working
% acquisition pipeline.
%
% See bertecsdk_lsl_bridge.cs for the functioning Bertec SDK and C# bridge.
%
% Assumptions made by this experiment:
%   - Kinamoto exposes force-plate data through UDP.
%   - The correct UDP port can be identified from the running application.
%   - Incoming data contain text or CSV-style numeric rows.
%   - Each row contains either:
%       17 force-plate channels, or
%       1 time column followed by 17 force-plate channels.
%   - The channel order matches channelNames below.
%   - The force-plate sampling rate is 1000 Hz.
%
% The UDP port, data format, channel structure, encoding, and parsing
% assumptions used by this experiment were not fully validated.
%
% Requirements:
%   - MATLAB with udpport support
%   - A compatible version of liblsl-Matlab
%   - LabRecorder or another compatible LSL recording application
%   - A Kinamoto configuration capable of providing compatible UDP output
%
% Before use:
%   - Set lslPath below if liblsl-Matlab is not already on the MATLAB path.
%   - Verify the Kinamoto UDP port.
%   - Confirm the transmitted data format, delimiter, channel count,
%     channel order, timestamp behavior, and sampling rate.
%
% Warning:
%   Opening a UDP listener successfully does not confirm that usable
%   Kinamoto force-plate data are being received.

clear;
clc;

%% User Settings

% Set this to the local liblsl-Matlab folder.
% This setting is used only when lsl_loadlib is not already available on
% the MATLAB path.
%
% Example:
% lslPath = 'C:\Users\YourName\Downloads\liblsl-Matlab';
lslPath = 'C:\path\to\liblsl-Matlab';

% Experimental Kinamoto UDP port used during testing.
kinamotoPort = 53191;

% Assumed force-plate channel order.
channelNames = { ...
    'AUX', 'SYNC', ...
    'FZR', 'MXR', 'MYR', ...
    'FZL', 'MXL', 'MYL', ...
    'FZ', 'MX', 'MY', ...
    'COPXR', 'COPYR', ...
    'COPXL', 'COPYL', ...
    'COPX', 'COPY'};

numChannels = numel(channelNames);

% Assumed force-plate sampling rate.
sampleRate = 1000;

% Experimental LSL stream metadata.
streamName = 'BertecForcePlate';
streamType = 'Force';
sourceId = 'Bertec_FP_01';

%% Load the LSL Library

if ~exist('lsl_loadlib', 'file')
    if ~isfolder(lslPath)
        error([ ...
            'liblsl-Matlab was not found on the MATLAB path, and ' ...
            'lslPath does not point to a valid folder. Update lslPath ' ...
            'in the User Settings section.']);
    end

    addpath(genpath(lslPath));
end

try
    lib = lsl_loadlib();
catch
    error([ ...
        'CRITICAL ERROR: Could not load the LSL library. Verify the ' ...
        'liblsl-Matlab installation and the lslPath setting.']);
end

%% Open the Experimental UDP Listener

fprintf( ...
    'Opening experimental Kinamoto/Bertec UDP listener on port %d...\n', ...
    kinamotoPort);

try
    bertecUdp = udpport( ...
        "byte", ...
        "IPV4", ...
        "LocalPort", ...
        kinamotoPort);

    fprintf( ...
        'UDP listener opened successfully on port %d.\n', ...
        kinamotoPort);
catch ME
    error([ ...
        'Could not open UDP port %d. The port may already be in use, ' ...
        'or it may not be the correct Kinamoto output port. Other ports ' ...
        'considered during testing included 50101 and 50102. Original ' ...
        'error: %s'], ...
        kinamotoPort, ...
        ME.message);
end

%% Create the Experimental LSL Outlet

info = lsl_streaminfo( ...
    lib, ...
    streamName, ...
    streamType, ...
    numChannels, ...
    sampleRate, ...
    'cf_float32', ...
    sourceId);

% Add the assumed channel labels to the LSL metadata.
channels = info.desc().append_child('channels');

for channelIndex = 1:numChannels
    channel = channels.append_child('channel');

    channel.append_child_value( ...
        'label', ...
        channelNames{channelIndex});

    channel.append_child_value( ...
        'type', ...
        streamType);

    channel.append_child_value( ...
        'unit', ...
        'unknown');
end

outlet = lsl_outlet(info);

fprintf( ...
    '\nExperimental LSL stream "%s" is now broadcasting.\n', ...
    streamName);

fprintf('Stream type: %s\n', streamType);
fprintf('Channel count: %d\n', numChannels);
fprintf('Assumed sample rate: %.1f Hz\n', sampleRate);

fprintf('\nAssumed channel labels sent to LSL:\n');

for channelIndex = 1:numChannels
    fprintf( ...
        '%2d: %s\n', ...
        channelIndex, ...
        channelNames{channelIndex});
end

fprintf( ...
    '\nOpen LabRecorder, select Refresh, and confirm the stream appears.\n');

%% Create the Stop Window

stopFigure = figure( ...
    'Name', ...
    'Stop Experimental Kinamoto Stream', ...
    'KeyPressFcn', ...
    'set(gcf,''Tag'',''stop'')', ...
    'Position', ...
    [100, 100, 380, 120], ...
    'Menu', ...
    'none', ...
    'ToolBar', ...
    'none');

uicontrol( ...
    'Parent', ...
    stopFigure, ...
    'Style', ...
    'text', ...
    'String', ...
    'Press ANY KEY in this window to stop streaming.', ...
    'Position', ...
    [30, 40, 320, 40], ...
    'FontSize', ...
    10);

disp('Attempting to stream Kinamoto/Bertec UDP data to LSL...');
disp('Start the appropriate live output in Kinamoto.');
disp('Select the popup window and press any key to stop.');

%% Read UDP Data and Push It to LSL

textBuffer = '';
sampleCount = 0;
skippedCount = 0;
statusTimer = tic;

try
    while ishandle(stopFigure) && ...
            ~strcmp(get(stopFigure, 'Tag'), 'stop')

        bytesAvailable = bertecUdp.NumBytesAvailable;

        if bytesAvailable > 0
            % Read all currently available UDP bytes.
            rawBytes = read( ...
                bertecUdp, ...
                bytesAvailable, ...
                'uint8');

            rawBytes = uint8(rawBytes(:)');

            % This experiment assumes that the UDP payload contains
            % text-based rows rather than a documented binary structure.
            textBuffer = [textBuffer, char(rawBytes)]; %#ok<AGROW>

            [rows, textBuffer] = parse_kinamoto_rows(textBuffer);

            for rowIndex = 1:length(rows)
                row = rows{rowIndex};

                % If 18 values are present, assume the first value is an
                % internal time column and remove it before sending to LSL.
                if numel(row) == numChannels + 1
                    row = row(2:end);
                end

                % Send rows only when they match the assumed channel count.
                if numel(row) == numChannels
                    sample = single(row(:));

                    outlet.push_sample(sample);
                    sampleCount = sampleCount + 1;
                else
                    skippedCount = skippedCount + 1;
                end
            end
        end

        % Print status approximately once per second.
        if toc(statusTimer) > 1
            fprintf( ...
                ['Bytes available: %d | Samples pushed to LSL: %d | ' ...
                 'Rows skipped: %d\n'], ...
                bertecUdp.NumBytesAvailable, ...
                sampleCount, ...
                skippedCount);

            statusTimer = tic;
        end

        pause(0.001);
    end
catch ME
    warning( ...
        'Experimental Kinamoto streaming interrupted: %s', ...
        ME.message);
end

%% Clean Up

fprintf('\nClosing the experimental Kinamoto/Bertec UDP stream...\n');
fprintf('Total samples pushed to LSL: %d\n', sampleCount);
fprintf('Total rows skipped: %d\n', skippedCount);

if sampleCount == 0
    warning([ ...
        'No samples were pushed to LSL. This experimental approach did ' ...
        'not receive and parse data in the assumed format. The exact ' ...
        'cause was not determined.']);
end

clear bertecUdp;

if exist('stopFigure', 'var') && ishandle(stopFigure)
    close(stopFigure);
end

disp('Experimental Kinamoto/Bertec UDP stream closed.');

%% Local Function

function [rows, remainder] = parse_kinamoto_rows(buffer)
%PARSE_KINAMOTO_ROWS Parse complete numeric text rows from a character buffer.

    rows = {};

    if isempty(buffer)
        remainder = '';
        return;
    end

    % Treat semicolons as comma delimiters.
    buffer = strrep(buffer, ';', ',');

    % Split the buffer into complete and potentially incomplete lines.
    lineParts = regexp(buffer, '\r\n|\n|\r', 'split');

    if buffer(end) == newline || buffer(end) == char(13)
        completeLines = lineParts;
        remainder = '';
    else
        completeLines = lineParts(1:end - 1);
        remainder = lineParts{end};
    end

    for lineIndex = 1:length(completeLines)
        line = strtrim(completeLines{lineIndex});

        if isempty(line)
            continue;
        end

        % Remove quotation marks before splitting the row.
        line = strrep(line, '"', '');

        % Accept commas, tabs, or spaces as delimiters.
        parts = regexp(line, '[,\t ]+', 'split');
        numericValues = str2double(parts);

        % Ignore headers and rows containing nonnumeric values.
        if isempty(numericValues) || any(isnan(numericValues))
            continue;
        end

        rows{end + 1} = numericValues(:); %#ok<AGROW>
    end
end
