% ===== Adjustable settings =====
tStart = [];
tEnd   = [];
chToPlot = 1:size(EMG_data,1);
maxPlotPoints = 20000;
showMarkerLabels = true;

plotRMS = false;                 % false = raw EMG, true = RMS envelope
rmsWindowSeconds = 0.050;        % 50 ms RMS window if plotRMS = true
normalizeChannels = true;        % true = normalized view, false = raw values with vertical offsets

% ===== Check selected channels =====
if isempty(chToPlot) || min(chToPlot) < 1 || max(chToPlot) > size(EMG_data,1)
    error('chToPlot contains an invalid EMG channel number.');
end

% ===== Channel labels =====
lineLabels = strings(1, numel(chToPlot));

for k = 1:numel(chToPlot)
    thisCh = chToPlot(k);

    if exist('EMG_channel_labels','var') && numel(EMG_channel_labels) >= thisCh
        thisLabel = string(EMG_channel_labels(thisCh));
    else
        thisLabel = "";
    end

    if strlength(thisLabel) == 0
        thisLabel = "EMG Ch " + string(thisCh);
    end

    lineLabels(k) = thisLabel;
end

% ===== Time window =====
if isempty(tStart)
    tStart = EMG_time(1);
end

if isempty(tEnd)
    tEnd = EMG_time(end);
end

idx = EMG_time >= tStart & EMG_time <= tEnd;

if ~any(idx)
    error('No EMG data found in the selected time window.');
end

plotTime = EMG_time(idx);
plotData = EMG_data(chToPlot, idx);

% ===== Optional RMS envelope =====
if plotRMS
    dt = median(diff(EMG_time), 'omitnan');
    EMG_srate_est = 1 / dt;
    rmsWindowSamples = max(1, round(rmsWindowSeconds * EMG_srate_est));

    for ch = 1:size(plotData,1)
        plotData(ch,:) = sqrt(movmean(plotData(ch,:).^2, rmsWindowSamples));
    end
end

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

    if plotRMS
        yAxisText = 'EMG RMS channels, normalized and offset';
    else
        yAxisText = 'Raw EMG channels, normalized and offset';
    end

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

    if plotRMS
        yAxisText = 'EMG RMS channels, raw values with vertical offsets';
    else
        yAxisText = 'Raw EMG channels, raw values with vertical offsets';
    end
end

% ===== Apply vertical offsets =====
nChannels = size(displayData,1);
offsets = (nChannels - (1:nChannels))' * offsetAmount;
displayWithOffset = displayData + offsets;

figure('Name','EMG Data With Markers','NumberTitle','off');
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

if plotRMS
    title('EMG RMS Data With Markers');
else
    title('Raw EMG Data With Markers');
end

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
