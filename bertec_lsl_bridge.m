%% 1. Clear MATLAB Memory and Setup Paths
clear; clc;

% UPDATE THESE: Put the exact paths to your Bertec files here
bertec_dll_path = 'C:\Users\YOUR_USERNAME\Downloads\BertecDevice.dll'; 
bertec_h_path   = 'C:\Users\YOUR_USERNAME\Downloads\BertecDevice.h'; 

fprintf('Opening the Bertec file inside MATLAB...\n');
try
    % This is the native MATLAB command to open this type of file
    if ~libisloaded('BertecDevice')
        loadlibrary(bertec_dll_path, bertec_h_path);
    end
    
    % Tell the file to initialize through MATLAB
    calllib('BertecDevice', 'Initialize'); 
    fprintf('Bertec hardware initialized successfully!\n');
catch ME
    error('MATLAB could not load the file. Error details: %s', ME.message);
end

%% 2. Setup the LSL Network Outlet in MATLAB
fprintf('Loading LSL library...\n');
lib = lsl_loadlib();

% Define stream parameters (6 channels: Fx, Fy, Fz, Mx, My, Mz)
stream_name = 'BertecForcePlate';
stream_type = 'Force';
num_channels = 6; 
sample_rate = 1000; 
source_id = 'Bertec_FP_01';

info = lsl_streaminfo(lib, stream_name, stream_type, num_channels, sample_rate, 'cf_float32', source_id);
outlet = lsl_outlet(info);
fprintf('LSL stream "%s" is now broadcasting.\n', stream_name);

%% 3. Data Streaming Loop
% Create a figure window in MATLAB to catch a keypress to stop the loop safely
stop_fig = figure('Name', 'Stop Bertec Stream', 'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
                  'Position', [100 100 300 100], 'Menu', 'none', 'ToolBar', 'none');
uicontrol('Style', 'text', 'String', 'Press ANY KEY in this window to stop streaming.', ...
          'Position', [20 30 260 40], 'FontSize', 10);

% Pre-allocate a 1x6 MATLAB array to hold the incoming data
forceData = zeros(1, num_channels, 'single');

disp('Streaming Bertec data... Select the popup window and press any key to stop.');

try
    while ~strcmp(get(stop_fig, 'Tag'), 'stop')
        
        % Request the live data matrix from the file using MATLAB's engine
        [~, forceData] = calllib('BertecDevice', 'GetLatestData', forceData);
        
        % If MATLAB receives data, push it out to the LSL network
        if any(forceData)
            outlet.push_sample(forceData);
        end
        
        pause(0.001); 
    end
catch ME
    warning('Streaming interrupted: %s', ME.message);
end

%% 4. Clean Up and Close Connections
fprintf('Closing hardware connections...\n');
calllib('BertecDevice', 'Close'); 
unloadlibrary('BertecDevice'); % Safely remove the file from MATLAB's memory
if ishandle(stop_fig); close(stop_fig); end
