function [spike, waves] = read_nev(nevfile)
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

if nargin < 2
    readAllChannels = true;
else
    readAllChannels = false;
end

%assert(isnumeric(ch),'');

disp('Reading NEV file - ');

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
if dayweek == 1 
    dw = 'Sunday';
elseif dayweek == 2 
    dw = 'Monday';
elseif dayweek == 3 
    dw = 'Tuesday';
elseif dayweek == 4 
    dw = 'Wednesday';
elseif dayweek == 5 
    dw = 'Thursday';
elseif dayweek == 6 
    dw = 'Friday';
elseif dayweek == 7 
    dw = 'Saturday';
else
    dw = '';
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

%-------------------------------------------------------------------------------
%Read DATA starting after header
fseek(fid,headersize,'bof'); 

% read extended headers

%Data Packets
%---------------------
%indexing
x = 0;
m = 1;

increment = ceil(nBytesInFile * .10); % print a status message every 10% of file
nextthresh = increment;

spike = zeros(nPacketsInFile,3);

if waveson
    waves = cell(nPacketsInFile,1);
end

fprintf('%% Complete: ');
while x == 0
    % read the full packet, which is the same size for digital
    % events or spikes. Then parse it up into the separate
    % variables. Doing this is faster than many reads
    [tempData,c] = fread(fid,datapacketsize,'uint8=>uint8');
    if c == 0 x = 1; %disp('Finished reading file'); 
        break; end
    
    timestamp = double(typecast(tempData(1:4),'uint32'));
    electrode = typecast(tempData(5:6),'uint16');
    class = tempData(7);
    %future = tempData(8);
   
    if readAllChannels == true || ismember(electrode,ch)
    
    if (electrode == 0)
        dig = typecast(tempData(9:10),'uint16');
        
        spike(m,3) = (timestamp/samplefreq);
        spike(m,2) = dig; % value on the digital port
        spike(m,1) = 0; % zero indicates digital event
        m = m + 1;
    else       
        if (waveson)
            uvolt = double(nVperBit(electrode))*.001;
            % convert to uV!!!!!
% MATT 20180731 - this is wrong, needs to be a double first
%            waves{m} = typecast(tempData(9:datapacketsize),'int16').*uvolt;
            waves{m} = double(typecast(tempData(9:datapacketsize),'int16')).*uvolt;
        end
        
        % store the spike times and channels in spike array
        spike(m,3) = timestamp/samplefreq; %global time (msec)
        spike(m,2) = class; %spike classification
        spike(m,1) = electrode;	%electrode number
        m = m+1;
    end
    end
    
    % status message as data blocks are written
    if ftell(fid) > nextthresh
        fprintf('%d, ',floor((ftell(fid)/nBytesInFile)*100));
        nextthresh = nextthresh+increment;
    end

end %while loop

fprintf('\n Finished reading NEV file\n');

% truncate the arrays where they should end - they may have been made too large

spikeend=find(sum(spike,2)==0);

if ~isempty(spikeend)
    if(spikeend(1)==1)
        cutind=spikeend(2);
        spike = spike(1:cutind-1,:);
        if (waveson)
            waves = waves(1:cutind-1);
        end
    else
        cutind=spikeend(1);
        spike = spike(1:cutind-1,:);
        if (waveson)
            waves = waves(1:cutind-1);
        end
    end
end
fclose(fid);

