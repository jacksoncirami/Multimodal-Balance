%% 1. Configuration & Setup
clear; clc;

% UPDATE THIS: Path to your LSL library folder
addpath(genpath('C:\Users\hpuminds\Downloads\liblsl-Matlab-1.14.0-Win_amd64_R2020b\liblsl-Matlab'));

% Kinamoto/Bertec Network Settings
bertec_ip = '127.0.0.1';   % Localhost
bertec_port = 5000;        % Update if Kinamoto uses a different port

% Expected Kinamoto/Bertec channel order
default_channel_names = { ...
    'Time_s', 'AUX', 'SYNC', ...
    'FZR', 'MXR', 'MYR', ...
    'FZL', 'MXL', 'MYL', ...
    'FZ', 'MX', 'MY', ...
    'COPXR', 'COPYR', ...
    'COPXL', 'COPYL', ...
    'COPX', 'COPY'};

% Expected sample rate
sample_rate = 1000;

% Stream identity for LabRecorder
stream_name = 'BertecForcePlate';
stream_type = 'Force';
source_id = 'Bertec_FP_01';

fprintf('Connecting to Kinamoto/Bertec stream at %s:%d...\n', bertec_ip, bertec_port);

try
    bertec_client = tcpclient(bertec_ip, bertec_port, 'Timeout', 10);
    fprintf('Connected to Kinamoto/Bertec TCP server.\n');
catch ME
    error(['Could not connect to Kinamoto/Bertec TCP server. ', ...
           'Make sure Kinamoto is open, live output is enabled, and the port is correct. ', ...
           'Original error: %s'], ME.message);
end

%% 2. Wait for Live Data and Detect Format

fprintf('\nWaiting for live Kinamoto/Bertec data...\n');
fprintf('Start the force plate collection/live output in Kinamoto now if it is not already running.\n');

byte_buffer = uint8([]);
text_buffer = '';
data_format = '';
first_rows = {};
channel_names = default_channel_names;
num_channels = numel(channel_names);

wait_timeout_sec = 30;
status_timer = tic;
wait_timer = tic;

while isempty(data_format)

    bytes_available = bertec_client.NumBytesAvailable;

    if bytes_available > 0
        new_bytes = read(bertec_client, bytes_available, 'uint8');
        new_bytes = uint8(new_bytes(:)');
        byte_buffer = [byte_buffer, new_bytes];

        % Try text/CSV-style detection first
        if looks_like_text(byte_buffer) && contains_newline(byte_buffer)
            text_buffer = char(byte_buffer);
            [rows, remainder] = parse_text_rows(text_buffer);

            if ~isempty(rows)
                data_format = 'text';
                first_rows = rows;
                text_buffer = remainder;

                detected_channels = numel(first_rows{1});
                channel_names = choose_channel_names(detected_channels, default_channel_names);
                num_channels = numel(channel_names);

                fprintf('\nDetected TEXT/CSV-style Kinamoto stream.\n');
                fprintf('Detected channels per row: %d\n', detected_channels);
            end
        end

        % If it does not look like text, assume raw binary float32
        if isempty(data_format)
            bytes_per_sample_default = 4 * numel(default_channel_names);

            if ~looks_like_text(byte_buffer) && numel(byte_buffer) >= bytes_per_sample_default
                data_format = 'binary_float32';
                channel_names = default_channel_names;
                num_channels = numel(channel_names);

                fprintf('\nDetected BINARY float32 Kinamoto stream.\n');
                fprintf('Assuming %d channels.\n', num_channels);
            end
        end
    end

    if toc(status_timer) > 1
        fprintf('Waiting... bytes available: %d | buffered bytes: %d\n', ...
            bertec_client.NumBytesAvailable, numel(byte_buffer));
        status_timer = tic;
    end

    if toc(wait_timer) > wait_timeout_sec
        error(['Connected to Kinamoto/Bertec, but no usable live data was received. ', ...
               'This means Kinamoto may be saving CSV data internally but not sending live TCP data to MATLAB. ', ...
               'Check Kinamoto live/network output settings and the port number.']);
    end

    pause(0.01);
end

%% 3. Setup LSL Outlet

fprintf('\nLoading LSL library...\n');
lib = lsl_loadlib();

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

fprintf('\nLSL stream "%s" is broadcasting.\n', stream_name);
fprintf('Stream type: %s\n', stream_type);
fprintf('Channel count: %d\n', num_channels);
fprintf('Sample rate: %.1f Hz\n', sample_rate);
fprintf('Detected input format: %s\n', data_format);

fprintf('\nChannel labels:\n');
for c = 1:num_channels
    fprintf('%2d: %s\n', c, channel_names{c});
end

fprintf('\nNow open LabRecorder, click Update, and confirm this stream appears.\n');

%% 4. Stop Window

stop_fig = figure( ...
    'Name', 'Stop Bertec LSL Stream', ...
    'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
    'Position', [100 100 380 120], ...
    'Menu', 'none', ...
    'ToolBar', 'none');

uicontrol( ...
    'Style', 'text', ...
    'String', 'Press ANY KEY in this window to stop streaming.', ...
    'Position', [30 40 320 40], ...
    'FontSize', 10);

%% 5. Data Streaming Loop

disp('Streaming Kinamoto/Bertec data to LSL...');
disp('Keep this script running while LabRecorder records the .xdf file.');
disp('Select the popup window and press any key to stop.');

sample_count = 0;
status_timer = tic;

try
    % Push any first rows already detected for text mode
    if strcmp(data_format, 'text') && ~isempty(first_rows)
        sample_count = sample_count + push_text_rows(outlet, first_rows, num_channels);
    end

    % For binary mode, byte_buffer already contains data waiting to be pushed
    binary_buffer = byte_buffer;

    while ishandle(stop_fig) && ~strcmp(get(stop_fig, 'Tag'), 'stop')

        bytes_available = bertec_client.NumBytesAvailable;

        if bytes_available > 0
            new_bytes = read(bertec_client, bytes_available, 'uint8');
            new_bytes = uint8(new_bytes(:)');

            if strcmp(data_format, 'text')
                text_buffer = [text_buffer, char(new_bytes)];
                [rows, text_buffer] = parse_text_rows(text_buffer);

                if ~isempty(rows)
                    sample_count = sample_count + push_text_rows(outlet, rows, num_channels);
                end

            elseif strcmp(data_format, 'binary_float32')
                binary_buffer = [binary_buffer, new_bytes];

                [samples_pushed, binary_buffer] = push_binary_float32( ...
                    outlet, binary_buffer, num_channels);

                sample_count = sample_count + samples_pushed;
            end
        end

        if toc(status_timer) > 1
            fprintf('Bytes available: %d | Samples pushed to LSL: %d\n', ...
                bertec_client.NumBytesAvailable, sample_count);
            status_timer = tic;
        end

        pause(0.001);
    end

catch ME
    warning('Streaming interrupted: %s', ME.message);
end

%% 6. Cleanup

fprintf('\nClosing Kinamoto/Bertec stream...\n');
fprintf('Total samples pushed to LSL: %d\n', sample_count);

clear bertec_client;

if exist('stop_fig', 'var') && ishandle(stop_fig)
    close(stop_fig);
end

disp('Kinamoto/Bertec LSL stream closed cleanly.');

%% ===== Local Helper Functions =====

function tf = contains_newline(bytes)
    tf = any(bytes == 10) || any(bytes == 13);
end

function tf = looks_like_text(bytes)
    if isempty(bytes)
        tf = false;
        return
    end

    bytes = uint8(bytes);

    printable = ...
        (bytes >= 32 & bytes <= 126) | ...  % regular printable ASCII
        bytes == 9 | ...                    % tab
        bytes == 10 | ...                   % newline
        bytes == 13;                        % carriage return

    ratio_printable = sum(printable) / numel(bytes);

    tf = ratio_printable > 0.85;
end

function [rows, remainder] = parse_text_rows(buffer)
    rows = {};

    if isempty(buffer)
        remainder = '';
        return
    end

    % Normalize semicolons to commas just in case
    buffer = strrep(buffer, ';', ',');

    % Split into lines
    line_parts = regexp(buffer, '\r\n|\n|\r', 'split');

    % If buffer does not end with newline, last part may be incomplete
    ends_with_newline = ~isempty(buffer) && any(buffer(end) == sprintf('\n\r'));

    if ends_with_newline
        complete_lines = line_parts;
        remainder = '';
    else
        complete_lines = line_parts(1:end-1);
        remainder = line_parts{end};
    end

    for i = 1:length(complete_lines)
        line = strtrim(complete_lines{i});

        if isempty(line)
            continue
        end

        % Remove quotes if present
        line = strrep(line, '"', '');

        % Split by comma, tab, or spaces
        parts = regexp(line, '[,\t ]+', 'split');

        % Convert to numbers
        nums = str2double(parts);

        % Skip header lines or non-numeric lines
        if isempty(nums) || any(isnan(nums))
            continue
        end

        rows{end+1} = nums(:); %#ok<AGROW>
    end
end

function channel_names = choose_channel_names(detected_channels, default_channel_names)

    if detected_channels == numel(default_channel_names)
        channel_names = default_channel_names;

    elseif detected_channels == numel(default_channel_names) - 1
        % Live stream may omit Time_s because LSL already supplies timestamps
        channel_names = default_channel_names(2:end);

        warning(['Detected 17 channels instead of 18. ', ...
                 'Assuming live stream omits Time_s and starts at AUX.']);

    else
        warning(['Detected %d channels, which does not match expected 18 or 17. ', ...
                 'Using generic Bertec channel labels.'], detected_channels);

        channel_names = cell(1, detected_channels);

        for c = 1:detected_channels
            channel_names{c} = sprintf('Bertec_Ch%d', c);
        end
    end
end

function nPushed = push_text_rows(outlet, rows, num_channels)
    nPushed = 0;

    for i = 1:length(rows)
        row = rows{i};

        if numel(row) < num_channels
            continue
        end

        sample = single(row(1:num_channels));
        sample = sample(:);

        outlet.push_sample(sample);
        nPushed = nPushed + 1;
    end
end

function [nPushed, remaining_buffer] = push_binary_float32(outlet, buffer, num_channels)

    bytes_per_value = 4;
    bytes_per_sample = bytes_per_value * num_channels;

    nSamples = floor(numel(buffer) / bytes_per_sample);

    if nSamples <= 0
        nPushed = 0;
        remaining_buffer = buffer;
        return
    end

    nBytesToUse = nSamples * bytes_per_sample;

    bytes_to_use = buffer(1:nBytesToUse);
    remaining_buffer = buffer(nBytesToUse+1:end);

    float_data = typecast(uint8(bytes_to_use), 'single');
    formatted_data = reshape(float_data, num_channels, nSamples);

    for s = 1:nSamples
        outlet.push_sample(formatted_data(:, s));
    end

    nPushed = nSamples;
end
