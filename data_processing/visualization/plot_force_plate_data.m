%% plot_force_plate_data
% Plot selected force-plate channels over a chosen time range with optional
% normalization, vertical offsets, event markers, and marker labels.
%
% Required workspace variables:
%   - ForcePlate_data
%   - ForcePlate_time
%
% Optional workspace variables:
%   - ForcePlate_channel_labels
%   - MarkerTable
%
% Output:
%   - One force-plate figure with vertically offset channels
%   - Optional event-marker lines and labels
%
% Usage:
%   Load the organized multimodal MAT file, adjust the settings below, and
%   run the script.

%% User Settings

% Adjust the time range, channels, marker display, and vertical scale for
% the recording being viewed.
tStart = [];
tEnd = [];

chToPlot = 1:size(ForcePlate_data, 1);
showMarkerLabels = true;

% true = normalize each channel for visualization
% false = preserve signal amplitude after removing the channel median
normalizeChannels = true;

% Visible range around each channel baseline when amplitude is preserved.
yScale = 100;
signalUnit = 'N';

%% Validate the Selected Channels

if isempty(chToPlot) || ...
        min(chToPlot) < 1 || ...
        max(chToPlot) > size(ForcePlate_data, 1)

    error('chToPlot contains an invalid force plate channel number.');
end

%% Build Channel Labels

lineLabels = strings(1, numel(chToPlot));

for k = 1:numel(chToPlot)

    thisCh = chToPlot(k);

    if exist('ForcePlate_channel_labels', 'var') && ...
            numel(ForcePlate_channel_labels) >= thisCh

        thisLabel = string(ForcePlate_channel_labels(thisCh));

    else
        thisLabel = "";
    end

    if strlength(thisLabel) == 0
        thisLabel = "Force Ch " + string(thisCh);
    end

    lineLabels(k) = thisLabel;
end

%% Select the Time Window

% Empty start or end values use the full available recording range.

if isempty(tStart)
    tStart = ForcePlate_time(1);
end

if isempty(tEnd)
    tEnd = ForcePlate_time(end);
end

idx = ForcePlate_time >= tStart & ForcePlate_time <= tEnd;

if ~any(idx)
    error('No force plate data found in the selected time window.');
end

plotTime = ForcePlate_time(idx);
plotData = ForcePlate_data(chToPlot, idx);

%% Prepare the Display Data

if normalizeChannels

    displayData = zeros(size(plotData));

    for ch = 1:size(plotData, 1)

        sig = plotData(ch, :);
        sig = sig - median(sig, 'omitnan');

        scaleVal = max(abs(sig), [], 'omitnan');

        if isempty(scaleVal) || scaleVal == 0 || isnan(scaleVal)
            scaleVal = 1;
        end

        displayData(ch, :) = sig ./ scaleVal;
    end

    displayScale = 1;
    offsetAmount = 2.5;

    yAxisText = 'Force plate channels, normalized and offset';
    titleText = 'Force Plate Data With Markers — Normalized';

else

    channelBaselines = median(plotData, 2, 'omitnan');
    displayData = plotData - channelBaselines;

    displayScale = yScale;
    offsetAmount = 2.5 * yScale;

    yAxisText = sprintf( ...
        'Force plate channels, amplitude preserved and offset (%s)', ...
        signalUnit);

    titleText = sprintf( ...
        'Force Plate Data With Markers — Scale: %s%g %s', ...
        char(177), yScale, signalUnit);

    maximumAmplitudeByChannel = ...
        max(abs(displayData), [], 2, 'omitnan');

    if any(maximumAmplitudeByChannel > yScale)

        warning([ ...
            'One or more channels exceed the selected +/- %g %s ' ...
            'display scale. Increase yScale to view a larger range.' ...
            ], ...
            yScale, signalUnit);
    end
end

%% Apply Vertical Offsets

nChannels = size(displayData, 1);

offsets = ...
    (nChannels - (1:nChannels))' * offsetAmount;

displayWithOffset = displayData + offsets;

%% Create the Figure

figure( ...
    'Name', 'Force Plate Data With Markers', ...
    'NumberTitle', 'off');

hold on;

%% Plot the Force-Plate Channels

for ch = 1:nChannels
    plot(plotTime, displayWithOffset(ch, :));
end

%% Set Plot Limits

yMin = -displayScale;

yMax = ...
    (nChannels - 1) * offsetAmount + displayScale;

%% Add Event Markers

markerHandles = gobjects(0);

if exist('MarkerTable', 'var') && ...
        istable(MarkerTable) && ...
        height(MarkerTable) > 0

    markerIdx = ...
        MarkerTable.Time_seconds >= tStart & ...
        MarkerTable.Time_seconds <= tEnd;

    markerTimes = ...
        MarkerTable.Time_seconds(markerIdx);

    markerLabels = string( ...
        MarkerTable.Marker_Label(markerIdx));

    markerTextY = yMax - 0.2 * displayScale;

    for m = 1:length(markerTimes)

        hLine = xline(markerTimes(m), '--');
        markerHandles(end+1) = hLine;

        if showMarkerLabels

            hText = text( ...
                markerTimes(m), ...
                markerTextY, ...
                markerLabels(m), ...
                'Rotation', 90, ...
                'FontSize', 8, ...
                'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'top');

            markerHandles(end+1) = hText;
        end
    end
end

%% Add a Vertical Scale Bar

xRange = tEnd - tStart;
scaleBarX = tEnd - 0.025 * xRange;

scaleBarBottom = -0.5 * displayScale;
scaleBarTop = 0.5 * displayScale;

plot( ...
    [scaleBarX scaleBarX], ...
    [scaleBarBottom scaleBarTop], ...
    'k', ...
    'LineWidth', 3);

if normalizeChannels

    scaleBarLabel = '1 normalized unit';

else

    scaleBarLabel = sprintf( ...
        '%g %s', ...
        yScale, signalUnit);
end

text( ...
    scaleBarX - 0.01 * xRange, ...
    mean([scaleBarBottom scaleBarTop]), ...
    scaleBarLabel, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'middle');

%% Format the Plot

hold off;
grid on;

xlabel('Time (s)');
ylabel(yAxisText);
title(titleText);

xlim([tStart tEnd]);
ylim([yMin yMax]);

%% Add Channel Labels

ytickPositions = offsets;

[ytickPositionsSorted, sortIdx] = ...
    sort(ytickPositions);

lineLabelsSorted = lineLabels(sortIdx);

yticks(ytickPositionsSorted);
yticklabels(lineLabelsSorted);

%% Add the Marker Visibility Checkbox

% The checkbox controls all marker lines and text objects created above.

uicontrol( ...
    'Style', 'checkbox', ...
    'String', 'Show markers', ...
    'Value', 1, ...
    'Units', 'normalized', ...
    'Position', [0.82 0.94 0.15 0.04], ...
    'UserData', markerHandles, ...
    'Callback', ...
    ['h=get(gcbo,''UserData''); ' ...
     'if ~isempty(h), ' ...
     'if get(gcbo,''Value''), ' ...
     'set(h,''Visible'',''on''); ' ...
     'else, ' ...
     'set(h,''Visible'',''off''); ' ...
     'end; end']);

%% Display Plot Information

fprintf('\nForce plate plot created.\n');
fprintf('Displayed time range: %.3f to %.3f seconds\n', ...
    tStart, tEnd);

fprintf('Samples plotted per channel: %d\n', ...
    numel(plotTime));

if normalizeChannels
    fprintf('Display mode: normalized\n');
else
    fprintf('Display mode: amplitude preserved\n');
    fprintf('Display scale: +/- %g %s\n', ...
        yScale, signalUnit);
end
