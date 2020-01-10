function [nPacketsInFile] = getNumPackets(nevfile)
%function [spike, waves] = read_nev(nevfile)
%
% read_nev takes an NEV file as input and returns the event codes
% and times. 
%
% The columns of "spike" are channel, spike class (or digital port
% value for digital events), and time (seconds). The channel is 0
% for a digital event, and 1:255 for spike channels. 1:128 are the
% array channels, and 129 is the first analog input.
%
% If "waves" are requested, the waveforms associated with each
% spike are returned as well
%

if (nargout > 1)
    waveson = true;
else
    waveson = false;
end

%Header Basic Information
fid = fopen(nevfile,'r','l');
identifier = fscanf(fid,'%8s',1); %File Type Indentifier = 'NEURALEV'
filespec = fread(fid,2,'uchar'); %File specification major and minor 
version = sprintf('%d.%d',filespec(1),filespec(2)); %revision number
fileformat = fread(fid,2,'uchar'); %File format additional flags
headersize = fread(fid,1,'ulong'); 
%Number of bytes in header (standard  and extended)--index for data
datapacketsize = fread(fid,1,'ulong'); 
%Number of bytes per data packet (-8b for samples per waveform)
stampfreq = fread(fid,1,'ulong'); %Frequency of the global clock
samplefreq = fread(fid,1,'ulong'); %Sampling Frequency

%BytesPerSample = 2; % technically this should be read in the extended header for each channel
%samples = (datapacketsize - 8)/BytesPerSample;

%Computer SYSTEMTIME
time = fread(fid,8,'uint16');
year = time(1);
month = time(2);
dayweek = time(3);
if dayweek == 0 
    dw = 'Sunday';
elseif dayweek == 1 
    dw = 'Monday';
elseif dayweek == 2 
    dw = 'Tuesday';
elseif dayweek == 3 
    dw = 'Wednesday';
elseif dayweek == 4 
    dw = 'Thursday';
elseif dayweek == 5 
    dw = 'Friday';
elseif dayweek == 6 
    dw = 'Saturday';
end
day = time(4);
date = sprintf('%s, %d/%d/%d',dw,month,day,year);
% disp(date);
hour = time(5);
minute = time(6);
second = time(7);
millisec = time(8);
time2 = sprintf('%d:%d:%d.%d',hour,minute,second,millisec);
% disp(time2);

%Data Acquisition System and Version
application = fread(fid,32,'uchar')';

%Additional Information (and Extended Header Information)
comments = fread(fid,256,'uchar')';
ExtendedHeaderNumber=fread(fid,1,'ulong');

%Read extended headers
for i=1:ExtendedHeaderNumber
    Identifier=char(fread(fid,8,'char'))';
    %modify this later
    switch Identifier
        case 'NEUEVWAV'
            ElecID=fread(fid,1,'uint16');
            PhysConnect=fread(fid,1,'uchar');
            PhysConnectPin=fread(fid,1,'uchar');
            nVperBit(ElecID)=fread(fid,1,'uint16');
            EnergyThresh=fread(fid,1,'uint16');
            HighThresh(ElecID)=fread(fid,1,'int16');
            LowThresh(ElecID)=fread(fid,1,'int16');
            SortedUnits=fread(fid,1,'uchar');
            BytesPerSample=((fread(fid,1,'uchar'))>1)+1;
            temp=fread(fid,10,'uchar');
        otherwise, % added26/7/05 after identifying bug in reading extended headers
            temp=fread(fid,24,'uchar');
    end
end

%Determine number of packets in file after the header
fseek(fid,0,'eof');
nBytesInFile = ftell(fid);
nPacketsInFile = (nBytesInFile-headersize)/datapacketsize;



