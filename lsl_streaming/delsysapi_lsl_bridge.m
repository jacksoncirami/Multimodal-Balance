%% 1. Configuration & Setup
clear; clc;

% UPDATE THIS: Path to your LSL library folder
addpath(genpath('C:\Users\hpuminds\Downloads\liblsl-Matlab-1.14.0-Win_amd64_R2020b\liblsl-Matlab'));

% UPDATE THIS: Path to the folder where your downloaded Delsys API .dll files are stored
delsys_api_path = 'C:\DelsysAPI\'; 

% Initialize & Load Delsys .NET Assembly files into MATLAB
NET.addAssembly(fullfile(delsys_api_path, 'DelsysAPI.dll'));
NET.addAssembly(fullfile(delsys_api_path, 'DelsysComponents.dll'));

% Fixed hardware parameters matching your experimental setup
num_channels = 4;        % Fixed # of Sensors
sample_rate = 2000;      % Fixed Delsys EMG Sampling Rate (Hz)

%% 2. Establish Delsys API Handshake (Bypasses Local TCP Ports)
fprintf('Initializing Delsys API Master Pipeline Objects...\n');
try
    % Instantiate the primary API pipeline control object
    pipeline = DelsysAPI.RfPipeline();
    
    % UPDATE THIS: Set your official validation strings received from Delsys
    pipeline.Key = 'YOUR_ACTUAL_KEY_STRING_HERE';
    pipeline.License = 'YOUR_ACTUAL_LICENSE_STRING_HERE';
    
    % Scan for your physical Trigno Base Station via USB connection
    fprintf('Scanning for connected Trigno Base Station and 4 active sensors...\n');
    pipeline.Scan();
    
    % Map and arm all connected wireless data nodes programmatically
    pipeline.ConfigurePipelineForAllSensors();
    pipeline.ArmPipeline();
    
    % Spin up the hardware RF transmitter collection engine
    pipeline.Start();
    fprintf('Connected to Delsys API hardware successfully!\n');
catch ME
    error('API Initialization failure. Verify license string and USB connection. Error: %s', ME.message);
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

disp('Streaming Delsys data directly from API to LSL fabric...');

try
    while ~strcmp(get(stop_fig, 'Tag'), 'stop')
        
        % Check if the API background queue has fresh data frames waiting
        if pipeline.IsDataAvailable()
            
            % Pull the raw multi-channel matrix directly out of the API queue
            % The modern API delivers clean matrices, completely skipping manual typecasting!
            api_raw_matrix = pipeline.GetLatestData(); 
            
            % Cast to standard single precision array for LSL engine processing
            float_data = single(api_raw_matrix);
            
            % If multiple frames accumulated, push them sequentially out to LSL network
            [num_chans, total_samples] = size(float_data);
            for s = 1:total_samples
                outlet.push_sample(float_data(:, s));
            end
        end
        pause(0.0005); % 0.5 ms high-speed pause to balance CPU overhead
    end
catch ME
    warning('Streaming execution sequence interrupted: %s', ME.message);
end

%% 5. Cleanup Connection & Disarm Hardware
fprintf('Safely disarming Delsys RF Pipeline hardware components...\n');

if exist('pipeline', 'var')
    % Explicitly halt data capture commands
    pipeline.Stop();
    
    % Release base station hardware locks for other scripts
    pipeline.DisarmPipeline();
end

if ishandle(stop_fig); close(stop_fig); end
clear outlet info lib;
disp('Delsys API stream cleanly disconnected.');
