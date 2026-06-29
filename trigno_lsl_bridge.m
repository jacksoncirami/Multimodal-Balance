%% 1. Configuration & Setup
clear; clc;

% UPDATE THIS: Path to your pre-compiled Win64 LSL folder
addpath(genpath('C:\Users\hpuminds\Downloads\liblsl-Matlab-1.14.0-Win_amd64_R2020b\liblsl-Matlab'));

% Default Trigno network parameters
delsys_ip = '127.0.0.1'; % Localhost loopback
cmd_port = 50040;        % Delsys Command Communication Port
emg_port = 50041;        % Delsys Raw EMG Data Port
num_channels = 4;        % MATCHES YOUR 4 SENSORS EXACTLY
sample_rate = 2000;      % Fixed Delsys EMG Sampling Rate (Hz)

%% 2. Establish Command Handshake (Forces Trigno Discover to Stream)
fprintf('Connecting to Delsys Command Channel on Port %d...\n', cmd_port);
try
    % Connect to command port using MATLAB's native network engine
    cmd_client = tcpclient(delsys_ip, cmd_port, 'Timeout', 5);
    
    % Send the mandatory Delsys text trigger strings to open the data pipeline
    write(cmd_client, uint8(['START' char(13) char(10)])); 
    pause(0.5); % Give the software a half-second to process commands
    
    fprintf('Handshake successful! Connecting to EMG Data Port %d...\n', emg_port);
    % Open the primary data reading client with Little-Endian byte formatting
    delsys_client = tcpclient(delsys_ip, emg_port, 'Timeout', 10, 'ByteOrder', 'little-endian');
    fprintf('Connected to Delsys hardware successfully!\n');
catch ME
    error('Connection refused. Ensure Trigno Discover is open, displaying moving live waves, and check firewall. Error: %s', ME.message);
end

%% 3. Setup the LSL Network Outlet
fprintf('Loading LSL library...\n');
lib = lsl_loadlib();

stream_name = 'Delsys_Trigno_EMG';
stream_type = 'EMG';
source_id = 'Delsys_Trigno_01';

info = lsl_streaminfo(lib, stream_name, stream_type, num_channels, sample_rate, 'cf_float32', source_id);
outlet = lsl_outlet(info);
fprintf('LSL stream "%s" is now broadcasting on your network.\n', stream_name);

%% 4. Data Streaming Loop
stop_fig = figure('Name', 'Stop Delsys Stream', 'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
                  'Position', [450 100 300 100], 'Menu', 'none', 'ToolBar', 'none');
uicontrol('Style', 'text', 'String', 'Press ANY KEY in this window to stop streaming.', ...
          'Position', [20 30 260 40], 'FontSize', 10);

bytes_per_sample = 4 * num_channels; % 4 bytes per float channel
disp('Streaming Delsys data... Keep Trigno Discover live preview running.');

try
    while ~strcmp(get(stop_fig, 'Tag'), 'stop')
        bytes_available = delsys_client.NumBytesAvailable;
        
        if bytes_available >= bytes_per_sample
            samples_to_read = floor(bytes_available / bytes_per_sample);
            total_bytes = samples_to_read * bytes_per_sample;
            
            % Pull raw bytes and cast directly to single precision floats
            raw_bytes = read(delsys_client, total_bytes, 'uint8');
            float_data = typecast(raw_bytes, 'single');
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

%% 5. Cleanup Connection
fprintf('Closing network sockets cleanly...\n');
if exist('cmd_client', 'var')
    write(cmd_client, uint8(['STOP' char(13) char(10)]));
    clear cmd_client;
end
clear delsys_client;
if ishandle(stop_fig); close(stop_fig); end
disp('Delsys stream closed.');
