%% 1. Configuration & Setup
clear; clc;

% UPDATE THIS: Path to your LSL library folder
addpath(genpath('C:\Users\hpuminds\Downloads\liblsl-Matlab-1.14.0-Win_amd64_R2020b\liblsl-Matlab'));

% Bertec/Kinamoto network settings
bertec_ip = '127.0.0.1';   % Localhost
bertec_port = 5000;        % Update if Kinamoto/Bertec uses a different port

% Bertec/Kinamoto force plate channel order
channel_names = { ...
    'Time_s', 'AUX', 'SYNC', ...
    'FZR', 'MXR', 'MYR', ...
    'FZL', 'MXL', 'MYL', ...
    'FZ', 'MX', 'MY', ...
    'COPXR', 'COPYR', ...
    'COPXL', 'COPYL', ...
    'COPX', 'COPY'};

num_channels = numel(channel_names);

% Sampling rate shown by the Bertec/Kinamoto stream
sample_rate = 1000;

fprintf('Connecting to Bertec/Kinamoto stream at %s:%d...\n', bertec_ip, bertec_port);

try
    bertec_client = tcpclient(bertec_ip, bertec_port, 'Timeout', 10);
    fprintf('Connected to Bertec/Kinamoto stream successfully.\n');
catch ME
    error('Could not connect to Bertec/Kinamoto stream. Make sure the software is open and streaming. Original error: %s', ME.message);
end

%% 2. Setup LSL Outlet
fprintf('Loading LSL library...\n');
lib = lsl_loadlib();

stream_name = 'BertecForcePlate';
stream_type = 'Force';
source_id = 'Bertec_FP_01';

info = lsl_streaminfo( ...
    lib, ...
    stream_name, ...
    stream_type, ...
    num_channels, ...
    sample_rate, ...
    'cf_float32', ...
    source_id);

% Add channel labels to LSL metadata
channels = info.desc().append_child('channels');

for c = 1:num_channels
    ch = channels.append_child('channel');
    ch.append_child_value('label', channel_names{c});
    ch.append_child_value('type', stream_type);
    ch.append_child_value('unit', 'unknown');
end

outlet = lsl_outlet(info);

fprintf('LSL stream "%s" is broadcasting.\n', stream_name);
fprintf('Channel count: %d\n', num_channels);
fprintf('Sample rate: %.1f Hz\n', sample_rate);

%% 3. Stop Window
stop_fig = figure( ...
    'Name', 'Stop Bertec LSL Stream', ...
    'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
    'Position', [100 100 350 110], ...
    'Menu', 'none', ...
    'ToolBar', 'none');

uicontrol( ...
    'Style', 'text', ...
    'String', 'Press ANY KEY in this window to stop streaming.', ...
    'Position', [25 35 300 40], ...
    'FontSize', 10);

%% 4. Data Streaming Loop
bytes_per_value = 4;                         % float32 = 4 bytes
bytes_per_sample = bytes_per_value * num_channels;

disp('Streaming Bertec/Kinamoto data to LSL...');
disp('Keep this script running while LabRecorder records the .xdf file.');
disp('Select the popup window and press any key to stop.');

sample_count = 0;

try
    while ishandle(stop_fig) && ~strcmp(get(stop_fig, 'Tag'), 'stop')

        bytes_available = bertec_client.NumBytesAvailable;

        if bytes_available >= bytes_per_sample

            samples_to_read = floor(bytes_available / bytes_per_sample);
            total_bytes = samples_to_read * bytes_per_sample;

            % Read raw binary data from Bertec/Kinamoto TCP stream
            raw_data = read(bertec_client, total_bytes, 'uint8');

            % Convert bytes into float32 values
            float_data = typecast(uint8(raw_data), 'single');

            % Organize as channels x samples
            formatted_data = reshape(float_data, num_channels, samples_to_read);

            % Push samples to LSL one sample at a time
            for i = 1:samples_to_read
                outlet.push_sample(formatted_data(:, i));
            end

            sample_count = sample_count + samples_to_read;
        end

        pause(0.001);
    end

catch ME
    warning('Streaming interrupted: %s', ME.message);
end

%% 5. Cleanup
fprintf('\nClosing Bertec/Kinamoto stream...\n');
fprintf('Total samples pushed to LSL: %d\n', sample_count);

clear bertec_client;

if exist('stop_fig', 'var') && ishandle(stop_fig)
    close(stop_fig);
end

disp('Bertec/Kinamoto LSL stream closed cleanly.');
