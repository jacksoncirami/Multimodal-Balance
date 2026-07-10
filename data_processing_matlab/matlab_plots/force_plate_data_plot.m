% ===== Adjustable settings =====
tStart = [];
tEnd   = [];
chToPlot = 1:size(ForcePlate_data,1);
maxPlotPoints = 20000;
showMarkerLabels = true;

normalizeChannels = true;   % true = normalized view, false = raw values with vertical offsets

% ===== Check selected channels =====
if isempty(chToPlot) || min(chToPlot) < 1 || max(chToPlot) > size(ForcePlate_data,1)
    error('chToPlot contains an invalid force plate channel number.');
end

% ===== Channel labels =====
lineLabels = strings(1, numel(chToPlot));

for k = 1:numel(chToPlot)
    thisCh = chToPlot(k);

    if exist('ForcePlate_channel_labels','var') && numel(ForcePlate_channel_labels) >= thisCh
        thisLabel = string(ForcePlate_channel_labels(thisCh));
    else
        thisLabel = "";
    end

    if strlength(thisLabel) == 0
        thisLabel = "Force Ch " + string(thisCh);
    end

    lineLabels(k) = thisLabel;
end

% ===== Time window =====
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

% ===== Downsample for plotting only =====
step = max(1, ceil(length(plotTime) / maxPlotPoints));
plotTime = plotTime(1:step:end);
plotData = plotData(:, 1:step:end);

% ===== Normalize option =====
if normalizeChannels
    displayData = zeros(size(plotData));

    for ch = 1:size(plotData,1)
        sig = plotData(ch,:);
        sig = sig - mean(sig, 'omitnan');
        scaleVal = max(abs(sig), [], 'omitnan');

        if isempty(scaleVal) || scaleVal == 0 || isnan(scaleVal)
            scaleVal = 1;
        end

        displayData(ch,:) = sig ./ scaleVal;
    end

    offsetAmount = 3;
    yAxisText = 'Force plate channels, normalized and offset';

else
    displayData = plotData;

    channelRanges = max(plotData, [], 2, 'omitnan') - min(plotData, [], 2, 'omitnan');
    typicalRange = median(channelRanges, 'omitnan');

    if isempty(typicalRange) || typicalRange == 0 || isnan(typicalRange)
        typicalRange = max(abs(plotData(:)), [], 'omitnan');
    end

    if isempty(typicalRange) || typicalRange == 0 || isnan(typicalRange)
        typicalRange = 1;
    end

    offsetAmount = 1.25 * typicalRange;
    yAxisText = 'Force plate channels, raw values with vertical offsets';
end

% ===== Apply vertical offsets =====
nChannels = size(displayData,1);
offsets = (nChannels - (1:nChannels))' * offsetAmount;
displayWithOffset = displayData + offsets;

figure('Name','Force Plate Data With Markers','NumberTitle','off');
hold on;

for ch = 1:nChannels
    plot(plotTime, displayWithOffset(ch,:));
end

% ===== Add markers and save marker handles =====
markerHandles = gobjects(0);

if exist('MarkerTable','var') && height(MarkerTable) > 0
    markerIdx = MarkerTable.Time_seconds >= tStart & MarkerTable.Time_seconds <= tEnd;
    markerTimes = MarkerTable.Time_seconds(markerIdx);
    markerLabels = string(MarkerTable.Marker_Label(markerIdx));

    if normalizeChannels
        yMin = -offsetAmount;
        yMax = nChannels * offsetAmount;
        yRange = yMax - yMin;
        markerTextY = yMax - 0.5*offsetAmount;
    else
        yMin = min(displayWithOffset(:), [], 'omitnan');
        yMax = max(displayWithOffset(:), [], 'omitnan');
        yRange = yMax - yMin;

        if isempty(yRange) || yRange == 0 || isnan(yRange)
            yRange = 1;
        end

        markerTextY = yMax + 0.03*yRange;
    end

    for m = 1:length(markerTimes)
        hLine = xline(markerTimes(m), '--');
        markerHandles(end+1) = hLine;

        if showMarkerLabels
            hText = text(markerTimes(m), markerTextY, markerLabels(m), ...
                'Rotation', 90, ...
                'FontSize', 8, ...
                'HorizontalAlignment', 'right');
            markerHandles(end+1) = hText;
        end
    end

    if normalizeChannels
        ylim([-offsetAmount, nChannels * offsetAmount]);
    else
        ylim([yMin - 0.05*yRange, yMax + 0.20*yRange]);
    end
end

hold off;
grid on;
xlabel('Time (s)');
ylabel(yAxisText);
title('Force Plate Data With Markers');
xlim([tStart tEnd]);

% ===== Add y-axis channel labels =====
ytickPositions = offsets;

[ytickPositionsSorted, sortIdx] = sort(ytickPositions);
lineLabelsSorted = lineLabels(sortIdx);

yticks(ytickPositionsSorted);
yticklabels(lineLabelsSorted);

if normalizeChannels
    ylim([-offsetAmount, nChannels * offsetAmount]);
end

% ===== Marker visibility checkbox =====
uicontrol('Style','checkbox', ...
    'String','Show markers', ...
    'Value',1, ...
    'Units','normalized', ...
    'Position',[0.82 0.94 0.15 0.04], ...
    'UserData',markerHandles, ...
    'Callback','h=get(gcbo,''UserData''); if ~isempty(h), if get(gcbo,''Value''), set(h,''Visible'',''on''); else, set(h,''Visible'',''off''); end; end');
