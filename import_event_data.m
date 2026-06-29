%Imports EEG event data ("Latency", "Type")

[file,path] = uigetfile('*.csv')
eventTable = readtable(fullfile(path,file));

EEG.event = struct('type',{},'latency',{});

for k = 1:height(eventTable)
  EEG.event(k).type = num2str(eventTable.Type(k));
  EEG.event(k).latency = eventTable.Latency(k);
end

EEG = eeg_checkset(EEG,'eventconsistency');
eeglab redraw
