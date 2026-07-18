%% bertec_balance_advantage_tcp_experimental
% EXPERIMENTAL — NOT SUITABLE FOR CONTINUOUS LSL ACQUISITION
%
% Attempts to connect MATLAB directly to a presumed Bertec Balance
% Advantage TCP network stream, interpret the received bytes as force-plate
% measurements, and forward those samples through Lab Streaming Layer.
%
% This approach was not suitable for the present workflow because the
% tested Bertec Balance Advantage software did not provide the continuous
% real-time force-plate data stream required for synchronized recording
% through LSL.
%
% The script is retained only to document the attempted TCP-based
% integration route and the assumptions that were tested. It is not the
% working Bertec acquisition solution used by this repository.
%
% See bertecsdk_lsl_bridge.cs for the functioning bridge based on the
% Bertec SDK and C#.
%
% Assumptions made by this experiment:
%   - A Bertec application exposes continuous raw force-plate data through
%     a TCP connection.
%   - The TCP server is available at the configured IP address and port.
%   - Each sample contains six float32 values in this order:
%       Fx, Fy, Fz, Mx, My, Mz
%   - Samples are transmitted as uninterrupted binary float32 values.
%   - The force-plate sampling rate is 1000 Hz.
%
% These assumptions were not confirmed for the tested Balance Advantage
% configuration.
%
% Requirements:
%   - MATLAB with tcpclient support
%   - A compatible version of liblsl-Matlab
%   - LabRecorder or another compatible LSL recording application
%   - A functioning Bertec TCP server matching the assumptions above
%
% Before use:
%   - Set lslPath below if liblsl-Matlab is not already on the MATLAB path.
%   - Verify the actual Bertec server IP address and port.
%   - Confirm the transmitted channel count, byte order, data type, channel
%     order, and sample rate before interpreting any received data.
%
% Warning:
%   Establishing a TCP connection would not by itself confirm that the
%   received bytes represent valid or continuous Bertec force-plate data.

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

% Experimental Bertec network settings.
bertecIp = '127.0.0.1';
bertecPort = 5000;

% Assumed channel count:
% Fx, Fy, Fz, Mx, My, Mz
numChannels = 6;

% Assumed force-plate sampling rate.
sampleRate = 1000;

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

%% Attempt the Bertec TCP Connection

fprintf( ...
    ['Attempting connection to the experimental Bertec TCP stream ' ...
     'at %s:%d...\n'], ...
    bertecIp, ...
    bertecPort);

try
    % Open a native MATLAB TCP client using the assumed network settings.
    bertecClient = tcpclient( ...
        bertecIp, ...
        bertecPort, ...
        'Timeout', ...
        10);

    fprintf('TCP connection established.\n');
catch
    error([ ...
        'Could not connect to the configured TCP endpoint. Verify that ' ...
        'a compatible Bertec server is running and that the IP address ' ...
        'and port are correct.']);
end

%% Create the Experimental LSL Outlet

streamName = 'BertecForcePlate';
streamType = 'Force';
sourceId = 'Bertec_FP_01';

info = lsl_streaminfo( ...
    lib, ...
    streamName, ...
    streamType, ...
    numChannels, ...
    sampleRate, ...
    'cf_float32', ...
    sourceId);

outlet = lsl_outlet(info);

fprintf( ...
    'Experimental LSL stream "%s" is now broadcasting.\n', ...
    streamName);

%% Create the Stop Window

stopFigure = figure( ...
    'Name', ...
    'Stop Experimental Bertec Stream', ...
    'KeyPressFcn', ...
    'set(gcf,''Tag'',''stop'')', ...
    'Position', ...
    [100, 100, 300, 100], ...
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
    [20, 30, 260, 40], ...
    'FontSize', ...
    10);

disp([ ...
    'Attempting to stream experimental Bertec data. Select the popup ' ...
    'window and press any key to stop.']);

%% Read TCP Data and Push It to LSL

% Six assumed float32 channels require four bytes per channel.
bytesPerSample = 4 * numChannels;

try
    while ~strcmp(get(stopFigure, 'Tag'), 'stop')
        bytesAvailable = bertecClient.NumBytesAvailable;

        if bytesAvailable >= bytesPerSample
            samplesToRead = floor(bytesAvailable / bytesPerSample);
            totalBytes = samplesToRead * bytesPerSample;

            % Read the available binary data using the assumed format.
            rawData = read( ...
                bertecClient, ...
                totalBytes, ...
                'uint8');

            floatData = typecast(rawData, 'single');

            formattedData = reshape( ...
                floatData, ...
                numChannels, ...
                samplesToRead);

            % Push each assumed force-plate sample through LSL.
            for sampleIndex = 1:samplesToRead
                outlet.push_sample(formattedData(:, sampleIndex));
            end
        end

        pause(0.001);
    end
catch ME
    warning('Experimental streaming interrupted: %s', ME.message);
end

%% Clean Up

fprintf('Closing the experimental TCP connection...\n');

clear bertecClient;

if ishandle(stopFigure)
    close(stopFigure);
end

disp('Experimental Bertec stream closed.');
