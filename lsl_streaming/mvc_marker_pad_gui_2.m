%% 1. Configuration & Setup
clear; clc;

% UPDATE THIS: Path to your LSL library folder
lsl_path = 'C:\Users\hpuminds\Downloads\liblsl-Matlab-1.14.0-Win_amd64_R2020b\liblsl-Matlab';

if ~exist('lsl_loadlib', 'file')
    addpath(genpath(lsl_path));
end

try
    lib = lsl_loadlib();
catch
    error('CRITICAL ERROR: Could not load LSL library. Please verify your lsl_path is correct!');
end

%% 2. Register the Stream With the Network
% Creates a stream named 'MVCMarkers' of type 'Markers' that LabRecorder looks for
info = lsl_streaminfo(lib, 'MVCMarkers', 'Markers', 1, 0, 'cf_string', 'mvc_marker_pad_001');
outlet = lsl_outlet(info);

clc;
disp('======================================================');
disp(' SUCCESS: MVC LSL Marker Stream is live and broadcasting! ');
disp(' -> Open LabRecorder, hit Refresh, and check "MVCMarkers".');
disp('======================================================');

%% 3. Define Interface Coordinates & Scaling

winWidth = 320;
winHeight = 620;

fig = figure('Name', 'MVC LSL Marker Dashboard', ...
             'MenuBar', 'none', ...
             'NumberTitle', 'off');

set(fig, 'Position', [100, 100, winWidth, winHeight]);

% Gray buttons with solid black text
gray_color = [0.92, 0.92, 0.92];
text_color = [0, 0, 0];

% Shared button layout measurements
btnWidth = 280;
btnHeight = 40;
startX = 20;
startY = 550;
spacing = 50;
sectionGap = 20;

%% 4. Build the Live Interface Buttons

% Button 1: Impedance Test Start
b1 = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
               'String', 'Impedance Test Start', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Impedance Test Start'));
set(b1, 'Position', [startX, startY, btnWidth, btnHeight]);

% Button 2: Impedance Test End
b2 = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
               'String', 'Impedance Test End', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Impedance Test End'));
set(b2, 'Position', [startX, startY - 1*spacing, btnWidth, btnHeight]);

% Button 3: MVC Start
b3 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'MVC Start', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'MVC Start'));
set(b3, 'Position', ...
    [startX, startY - 2*spacing - sectionGap, btnWidth, btnHeight]);

% Button 4: MVC End
b4 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'MVC End', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'MVC End'));
set(b4, 'Position', ...
    [startX, startY - 3*spacing - sectionGap, btnWidth, btnHeight]);

% Button 5: Rest Start
b5 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Rest Start', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Rest Start'));
set(b5, 'Position', ...
    [startX, startY - 4*spacing - sectionGap, btnWidth, btnHeight]);

% Button 6: Rest End
b6 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Rest End', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Rest End'));
set(b6, 'Position', ...
    [startX, startY - 5*spacing - sectionGap, btnWidth, btnHeight]);

% Button 7: TA
b7 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'TA', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'TA'));
set(b7, 'Position', ...
    [startX, startY - 6*spacing - sectionGap, btnWidth, btnHeight]);

% Button 8: PL
b8 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'PL', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'PL'));
set(b8, 'Position', ...
    [startX, startY - 7*spacing - sectionGap, btnWidth, btnHeight]);

% Button 9: GM
b9 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'GM', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'GM'));
set(b9, 'Position', ...
    [startX, startY - 8*spacing - sectionGap, btnWidth, btnHeight]);

% Button 10: GL
b10 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'GL', ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
                'Callback', @(~,~) send_live_marker(outlet, 'GL'));
set(b10, 'Position', ...
    [startX, startY - 9*spacing - sectionGap, btnWidth, btnHeight]);

%% 5. Helper Function to Push Samples Into the Recording Stream

function send_live_marker(outlet, marker_text)
    % Transmits the marker instantly over the network to LabRecorder
    outlet.push_sample({marker_text});

    % Prints local terminal feedback with a timestamp
    timestamp = char(datetime("now", "Format", "HH:mm:ss.SSS"));

    fprintf('[%s] LSL Broadcast -> Recorded MVC Event: "%s"\n', ...
            timestamp, marker_text);
end
