% ===== Adjustable settings =====
tStart = [];
tEnd   = [];
chToPlot = 1:size(EMG_data,1);
maxPlotPoints = 20000;           
showMarkerLabels = true;         
plotRMS = false;                 % false = raw EMG, true = RMS envelope
rmsWindowSeconds = 0.050;        % 50 ms RMS window if plotRMS = true

% ===== Time window =====
if isempty(tStart)
    tStart = EMG_time(1);
end

if isempty(tEnd)
    tEnd = EMG_time(end);
end

idx = EMG_time >= tStart & EMG_time <= tEnd;

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

% ===== Normalize and offset channels for viewing =====
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

figure;
hold on;

for ch = 1:size(displayData,1)
    yOffset = (size(displayData,1) - ch) * offsetAmount;
    plot(plotTime, displayData(ch,:) + yOffset);
end

% ===== Add markers =====
if exist('MarkerTable','var') && height(MarkerTable) > 0
    markerIdx = MarkerTable.Time_seconds >= tStart & MarkerTable.Time_seconds <= tEnd;
    markerTimes = MarkerTable.Time_seconds(markerIdx);
    markerLabels = string(MarkerTable.Marker_Label(markerIdx));

    for m = 1:length(markerTimes)
        xline(markerTimes(m), '--');

        if showMarkerLabels
            text(markerTimes(m), size(displayData,1)*offsetAmount, markerLabels(m), ...
                'Rotation', 90, 'FontSize', 8, 'HorizontalAlignment', 'right');
        end
    end
end

hold off;
grid on;
xlabel('Time (s)');

if plotRMS
    ylabel('EMG RMS channels, normalized and offset');
    title('EMG RMS Data With Markers');
else
    ylabel('Raw EMG channels, normalized and offset');
    title('Raw EMG Data With Markers');
end

xlim([tStart tEnd]);
