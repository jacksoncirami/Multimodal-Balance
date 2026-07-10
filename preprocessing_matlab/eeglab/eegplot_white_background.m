% Purpose:
% Fixes EEGLAB 'Channel data (scroll)' plot visibility issue

fig = gcf;
set(fig,'Color','w')
set(findall(fig,'Type','axes'),'Color','w','XColor','k','YColor','k')
set(findall(fig,'Type','text'),'Color','k')
set(findall(fig,'Type','line'),'Color','k')
drawnow
