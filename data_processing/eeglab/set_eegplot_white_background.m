%% set_eegplot_white_background
% Change the active EEGLAB channel-data figure to a white background with
% black axes, text, and signal lines.
%
% This helper script is intended for use when the EEGLAB "Channel data
% (scroll)" window has poor visibility because of its current figure colors.
%
% Input:
%   - The currently active MATLAB figure
%
% Output:
%   - Updated colors for the active figure and its plotted contents
%
% Usage:
%   Click the EEGLAB channel-data figure to make it active, then run this
%   script from the MATLAB Command Window or Editor.

fig = gcf;

set(fig, 'Color', 'w');
set(findall(fig, 'Type', 'axes'), ...
    'Color', 'w', ...
    'XColor', 'k', ...
    'YColor', 'k');
set(findall(fig, 'Type', 'text'), 'Color', 'k');
set(findall(fig, 'Type', 'line'), 'Color', 'k');

drawnow;
