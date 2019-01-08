function [p1,p2,status]=rubberbandbox3(varargin)
% Function to draw a rubberband box and return the start and end points
% Usage: [p1,p2]=rubberbox;     uses current axes
%        [p1,p2]=rubberbox(h);  uses axes refered to by handle, h
% Based on an idea of Sandra Martinka's Rubberline
% Written/Edited by Bob Hamans (B.C.Hamans@student.tue.nl) 
% 02-04-2003
%
% Modified for inclusion in Spikesort

%Check for optional argument
switch nargin
case 0
  h=gca;
case 1
  h=varargin{1};
  axes(h);
otherwise
  disp('Too many input arguments.');
end

% Get current user data
cudata=get(gcf,'UserData'); 
currentKeyFcn = get(gcf,'keypressfcn'); 
hold on;
% Wait for left mouse button to be pressed
%k=waitforbuttonpress;
p1=get(h,'CurrentPoint');       %get starting point
p1=p1(1,1:2);                   %extract x and y
lh=plot(p1(1),p1(2),'-r');      %plot starting point
% Save current point (p1) data in a structure to be passed
udata.p1=p1;
udata.h=h;
udata.lh=lh;
% Set gcf object properties 'UserData' and call function 'wbmf' on mouse motion. 
set(gcf,'UserData',udata,'WindowButtonMotionFcn','rubberBandMotionFunction');
set(gcf,'WindowButtonUpFcn','uiresume(gcf)');
set(gcf,'keypressfcn',''); 
%k=waitforbuttonpress;
uiwait(gcf);

status = get(gcf,'SelectionType');

% Get data for the end point
p2=get(h,'Currentpoint');       %get end point
p2=p2(1,1:2);                   %extract x and y
set(gcf,'UserData',cudata,'WindowButtonMotionFcn',''); %reset UserData, etc..
set(gcf,'keypressfcn',currentKeyFcn); %restore the original keypressfcn 
try
    delete(lh);
catch ME
    switch ME.identifier
        case 'MATLAB:hg:udd_interface:CannotDelete'
            %ignore error: rbbox already deleted.
        otherwise
            rethrow(ME);
    end;
end;
