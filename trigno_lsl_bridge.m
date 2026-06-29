%% 1. Configuration & Setup
clear; clc;


% UPDATE THIS: Path to your pre-compiled Win64 LSL folder
addpath(genpath('C:\Users\YOUR_USERNAME\Downloads\liblsl-Matlab-Win64')); 

% UPDATE THIS: Path to your Trigno Discover installation directory assembly file
delsys_dll_path = 'C:\Program Files\Delsys, Inc\Trigno Discover\DelsysAPI.dll'; 

fprintf('Loading Delsys .NET Assembly framework...\n');
try
    % Load the native 64-bit library file straight into MATLAB memory
    asm = NET.addAssembly(delsys_dll_path);
    
    % Initialize the primary Delsys background hardware pipeline manager
    delsysManager = Delsys.API.TrignoSystemManager();
    delsysManager.Initialize();
    fprintf('Delsys base station initialized successfully via DLL!\n');
catch ME
    error('Failed to load Delsys DLL. Verify file path or ensure Trigno Discover is closed. Error: %s', ME.message);
end

%% 2. Setup the LSL Network Outlet
fprintf('Loading LSL library...\n');
lib = lsl_loadlib();

stream_name = 'Delsys_Trigno_EMG';
stream_type = 'EMG';
num_channels = 4;        % MATCHES YOUR 4 ACTIVE SENSORS EXACTLY
sample_rate = 2000;      % Fixed Delsys EMG sampling rate (Hz)
source_id = 'Delsys_Trigno_01';

info = lsl_streaminfo(lib, stream_name, stream_type, num_channels, sample_rate, 'cf_float32', source_id);
outlet = lsl_outlet(info);
fprintf('LSL stream "%s" is now broadcasting on your network.\n', stream_name);

%% 3. Data Streaming Loop
stop_fig = figure('Name', 'Stop Delsys Stream', 'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
                  'Position', [450 100 300 100], 'Menu', 'none', 'ToolBar', 'none');
uicontrol('Style', 'text', 'String', 'Press ANY KEY in this window to stop streaming.', ...
          'Position', [20 30 260 40], 'FontSize', 10);

disp('Streaming Delsys data... Select the popup window and press any key to stop.');

try
    while ~strcmp(get(stop_fig, 'Tag'), 'stop')
        
        % Fetch raw array matrix data values directly from the USB pipeline
        emgData = delsysManager.GetLatestData();
        
        % If data rows are captured, forward them out to the LSL network
        if ~isempty(emgData)
            outlet.push_sample(emgData(1:num_channels));
        end
        
        pause(0.001); 
    end
catch ME
    warning('Streaming interrupted: %s', ME.message);
end

%% 4. Cleanup Connection
fprintf('Closing hardware connections cleanly...\n');
delsysManager.Close();
if ishandle(stop_fig); close(stop_fig); end
disp('Delsys stream closed cleanly.');
