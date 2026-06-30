%% 1. Configuration & Setup (.NET Method)
clear; clc;

% UPDATE THIS: Path to your pre-compiled Win64 LSL folder
addpath(genpath('C:\Users\hpuminds\Downloads\liblsl-Matlab-1.14.0-Win_amd64_R2020b\liblsl-Matlab'));

% UPDATE THIS: Path to your Trigno Discover directory where the DLL lives
delsys_dll_path = 'C:\Program Files (x86)\Delsys, Inc\Trigno Discover\DelsysAPI.dll';

fprintf('Loading Delsys .NET Assembly directly into MATLAB...\n');
try
    % Force MATLAB to open the file assembly
    asm = NET.addAssembly(delsys_dll_path);
    
    % Initialize the primary Delsys background hardware pipeline manager
    delsysManager = Delsys.API.TrignoSystemManager();
    delsysManager.Initialize();
    fprintf('Delsys base station initialized successfully via DLL!\n');
catch ME
    error('Failed to load Delsys DLL. Ensure Trigno Discover is CLOSED so the USB line is free. Error: %s', ME.message);
end

%% 2. Setup the LSL Network Outlet
fprintf('Loading LSL library...\n');
lib = lsl_loadlib();

stream_name = 'Delsys_Trigno_EMG';
stream_type = 'EMG';
num_channels = 4;        % MATCHES YOUR 4 SENSORS EXACTLY
sample_rate = 2000;      % Fixed Delsys EMG sampling rate (Hz)
source_id = 'Delsys_Trigno_01';

info = lsl_streaminfo(lib, stream_name, stream_type, num_channels, sample_rate, 'cf_float32', source_id);
outlet = lsl_outlet(info);
fprintf('LSL stream "%s" is now broadcasting.\n', stream_name);

%% 3. Data Streaming Loop
stop_fig = figure('Name', 'Stop Delsys Stream', 'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
                  'Position', [450 100 300 100], 'Menu', 'none', 'ToolBar', 'none');
uicontrol('Style', 'text', 'String', 'Press ANY KEY in this window to stop streaming.', ...
          'Position', [20 30 260 40], 'FontSize', 10);

disp('Streaming Delsys data... Select the popup window and press any key to stop.');

try
    while ~strcmp(get(stop_fig, 'Tag'), 'stop')
        
        % Fetch raw data rows directly out of the file layout
        emgData = delsysManager.GetLatestData();
        
        % If data exists, pull the 4 sensor channels and push to LSL
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
