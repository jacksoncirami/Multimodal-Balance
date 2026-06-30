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
% Creates a stream named 'GuiMarkers' of type 'Markers' that LabRecorder looks for
info = lsl_streaminfo(lib, 'GuiMarkers', 'Markers', 1, 0, 'cf_string', 'gui_marker_pad_999');
outlet = lsl_outlet(info);

clc;
disp('======================================================');
disp(' SUCCESS: LSL GUI Marker Stream is live and broadcasting! ');
disp(' -> Open LabRecorder, hit Refresh, and check "GuiMarkers".');
disp('======================================================');

%% 3. Define Interface Coordinates & Scaling
winWidth = 320;
winHeight = 600;

% Build a dedicated, clean graphic frame
fig = figure('Name', 'LSL Marker Dashboard', ...
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
startY = 540;
spacing = 50;

%% 4. Build the Live Interface Buttons

% Button 1: Trial Start
b1 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Trial Start', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Trial Start'));
set(b1, 'Position', [startX, startY, btnWidth, btnHeight]);

% Button 2: Trial End
b2 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Trial End', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Trial End'));
set(b2, 'Position', [startX, startY - 1*spacing, btnWidth, btnHeight]);

% Button 3: Eyes Open
b3 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Eyes Open', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Eyes Open'));
set(b3, 'Position', [startX, startY - 2*spacing, btnWidth, btnHeight]);

% Button 4: Eyes Closed
b4 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Eyes Closed', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Eyes Closed'));
set(b4, 'Position', [startX, startY - 3*spacing, btnWidth, btnHeight]);

% Button 5: Blinking
b5 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Blinking', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Blinking'));
set(b5, 'Position', [startX, startY - 4*spacing, btnWidth, btnHeight]);

% Button 6: Jaw Clench
b6 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Jaw Clench', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Jaw Clench'));
set(b6, 'Position', [startX, startY - 5*spacing, btnWidth, btnHeight]);

% Button 7: Talking
b7 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Talking', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Talking'));
set(b7, 'Position', [startX, startY - 6*spacing, btnWidth, btnHeight]);

% Button 8: Bad Movement
b8 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Bad Movement', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'Bad Movement'));
set(b8, 'Position', [startX, startY - 7*spacing, btnWidth, btnHeight]);

% Button 9: One Leg
b9 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'One Leg', ...
               'FontSize', 11, 'FontWeight', 'bold', ...
               'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
               'Callback', @(~,~) send_live_marker(outlet, 'One Leg'));
set(b9, 'Position', [startX, startY - 8*spacing, btnWidth, btnHeight]);

% Button 10: Step Initiation
b10 = uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Step Initiation', ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'BackgroundColor', gray_color, 'ForegroundColor', text_color, ...
                'Callback', @(~,~) send_live_marker(outlet, 'Step Initiation'));
set(b10, 'Position', [startX, startY - 9*spacing, btnWidth, btnHeight]);

%% 5. Helper Function to Push Samples Into the Recording Stream
function send_live_marker(outlet, marker_text)
    % Transmits the marker instantly over the network to LabRecorder
    outlet.push_sample({marker_text});

    % Prints local terminal feedback with a timestamp
    fprintf('[%s] LSL Broadcast -> Recorded Event: "%s"\n', ...
            datestr(now, 'HH:MM:SS.FFF'), marker_text);
end
