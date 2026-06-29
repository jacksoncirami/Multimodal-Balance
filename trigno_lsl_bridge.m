%% 1. Configuration & Network Setup
clear; clc;

delsys_ip = '127.0.0.1'; % Localhost (this PC)
emg_port = 50043;        % Default Delsys EMG server data port
num_channels = 16;       % Change to match the max slots or active sensors
sample_rate = 2000;      % Delsys EMG fixed sampling rate (Hz)

fprintf('Connecting to Delsys Trigno Server at %s:%d...\n', delsys_ip, emg_port);
try
    % Use MATLAB's native network engine to connect to the open Delsys port
    delsys_client = tcpclient(delsys_ip, emg_port, 'Timeout', 10);
    fprintf('Connected to Delsys hardware successfully!\n');
catch ME
    error('Could not connect. Is the Delsys Trigno Control Utility app running?');
end

%% 2. Setup the LSL Network Outlet
fprintf('Loading LSL library...\n');
lib = lsl_loadlib();

stream_name = 'Delsys_Trigno_EMG';
stream_type = 'EMG';
source_id = 'Delsys_Trigno_01';

info = lsl_streaminfo(lib, stream_name, stream_type, num_channels, sample_rate, 'cf_float32', source_id);
outlet = lsl_outlet(info);
fprintf('LSL stream "%s" is now broadcasting.\n', stream_name);

%% 3. Data Streaming Loop
% Create a popup stop figure window
stop_fig = figure('Name', 'Stop Delsys Stream', 'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
                  'Position', [450 100 300 100], 'Menu', 'none', 'ToolBar', 'none');
uicontrol('Style', 'text', 'String', 'Press ANY KEY in this window to stop streaming.', ...
          'Position', [20 30 260 40], 'FontSize', 10);

bytes_per_sample = 4 * num_channels; % 4 bytes per single-precision float channel
disp('Streaming Delsys data... Select the popup window and press any key to stop.');

try
    while ~strcmp(get(stop_fig, 'Tag'), 'stop')
        bytes_available = delsys_client.NumBytesAvailable;
        
        if bytes_available >= bytes_per_sample
            % Calculate how many multi-channel matrix packets are waiting in the network buffer
            samples_to_read = floor(bytes_available / bytes_per_sample);
            total_bytes = samples_to_read * bytes_per_sample;
            
            % Read raw binary data blocks directly through the network socket
            raw_data = read(delsys_client, total_bytes, 'uint8');
            
            % Convert raw bytes into single-precision float numbers
            float_data = typecast(raw_data, 'single');
            formatted_data = reshape(float_data, num_channels, samples_to_read);
            
            % Push samples sequentially out to LSL network
            for i = 1:samples_to_read
                outlet.push_sample(formatted_data(:, i));
            end
        end
        pause(0.001); 
    end
catch ME
    warning('Streaming interrupted: %s', ME.message);
end

%% 4. Cleanup Connection
fprintf('Closing network sockets...\n');
clear delsys_client;
if ishandle(stop_fig); close(stop_fig); end
disp('Delsys stream closed cleanly.');
