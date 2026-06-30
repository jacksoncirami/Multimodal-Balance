%Imports .csv file to MATLAB and transposes data

[file,path] = uigetfile('.csv');

data = readmatrix(fullfile(path,file));

data = data';

%Following line should read something along the lines of "6   20000"
size(data)

%Now continue in EEGLAB
