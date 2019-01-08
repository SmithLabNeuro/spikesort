function moveToSortCode(nevfile, spikeidx, sortcode)
%function moveToSortCode(nevfile, spikeidx, sortcode)
%
% Takes a nev file, a list of logicals, and a sort code. All events where
% the logical list (spikeidx) is true should be moved to 'sortcode'
%
% This function is useful if you want to 'clear' a spikesort from a
% file. You could send in a logical true for all the spikes and
% sort code '0' and it would clear all the sort codes to '0'
%
% This is also useful if you want to process the spikes with some
% external sorter/filter. Run it on the NEV file and have it return
% what should be done with each spike, and this function will write
% the appropriate sort code for those spikes into the file.
%

disp('Moving Sort Codes ...');

assert(unique(ismember(sortcode,0:255)),'Sort Code must be 0 to 255');
assert(numel(sortcode)==1 || numel(sortcode)==numel(spikeidx),['Must specify a single value for Sort Code or specify a sort code for each spike']);

% if only one sort code was provided, use it for all spikes
if numel(sortcode)==1
    sortcode = sortcode .* ones(numel(spikeidx),1);
end

%Header Basic Information
fid = fopen(nevfile,'r');
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

%Windows SYSTEMTIME
time = fread(fid,8,'uint16');
% year = time(1);
% month = time(2);
% dayweek = time(3);
% if dayweek == 1
%     dw = 'Sunday';
% elseif dayweek == 2
%     dw = 'Monday';
% elseif dayweek == 3
%     dw = 'Tuesday';
% elseif dayweek == 4
%     dw = 'Wednesday';
% elseif dayweek == 5
%     dw = 'Thursday';
% elseif dayweek == 6
%     dw = 'Friday';
% elseif dayweek == 7
%     dw = 'Saturday';
% else
%     dw = '';
% end
% day = time(4);
% date = sprintf('%s, %d/%d/%d',dw,month,day,year);
% %disp(date);
% hour = time(5);
% minute = time(6);
% second = time(7);
% millisec = time(8);
% sprintf('%d:%d:%d.%d',hour,minute,second,millisec);
% %disp(time2);

%Data Acquisition System and Version
application = fread(fid,32,'uchar')';

%Additional Information (and Extended Header Information)
comments = fread(fid,256,'uchar')';
extheadersize = fread(fid,1,'ulong');

fclose(fid);

%-------------------------------------------------------------------------------

finfo = dir(nevfile);
mb = 1024*1024;
fsize = finfo.bytes/mb;
fprintf('File Size: %0.2f MB\n',fsize);

%-------------------------------------------------------------------------------
%Read data to check the number of packets
fid = fopen(nevfile,'r');

%Determine number of packets in file after the header
fseek(fid,0,'eof');
nBytesInFile = ftell(fid);
nPacketsInFile = (nBytesInFile-headersize)/datapacketsize;

%Reset where we are in file
fseek(fid,0,'bof');
fseek(fid,headersize,0); % skip over header

%Data Packets
%---------------------
%indexing
m = 0;

ninc = 10;
increment = mb*ninc; % ninc megabytes
nextthresh = increment;

while true
    
    [tempData,c] = fread(fid,datapacketsize,'uint8=>uint8');
    if c == 0; %disp('Finished reading file');
        break; end
    m = m + 1;
    
    % could assert here to double-check the file is reasonable
    %    if (0)
    %        timestamp = double(typecast(tempData(1:4),'uint32'));
    %    electrode = typecast(tempData(5:6),'uint16');
    %    end
    
%    [~,c] = fread(fid,1,'ulong');
%    if c == 0, x=1; disp('Finished reading file'); break; end
%
%    electrode = fread(fid,1,'int16');
%    %class = fread(fid,1,'uchar'); % Read the sort code here
%    fseek(fid,2,0); % seek past 'future' value
%
%    if electrode == 0 %signals experimental information
%        fseek(fid,(datapacketsize-8),0);
%    else
%        fseek(fid,(datapacketsize-8),0); % seek past waveform info
%    end
    
    if ftell(fid) > nextthresh
        fprintf('Reading File Position: %i of %0.2f MB\n',(nextthresh/increment)*ninc,fsize);
        nextthresh = nextthresh + increment;
    end
end %while loop

fclose(fid);

assert(nPacketsInFile==m,'Projected packets does not match measured packets');

% There must be a match between the packets in the file and the input list
assert(numel(spikeidx)==m,'# of packets in file does not match input value spikeidx'); 

%-------------------------------------------------------------------------------
%Write Sort Codes
fid = fopen(nevfile,'r+');
fseek(fid,headersize,0); % skip over header

%Data Packets
%---------------------
%indexing
m = 0;
x = 0;
nextthresh = increment;

while x == 0
    [~,c] = fread(fid,1,'ulong');
    if c == 0, x=1; disp('Finished writing file'); break; end
    m = m + 1;
    
    electrode = fread(fid,1,'int16');

    % not sure why this fixes it but it does
    fseek(fid,-2,0);
    fwrite(fid,electrode,'int16');
    % Or this might be OK?
    %fseek(fid,0,0);
    
    if spikeidx(m)==true
        fwrite(fid,sortcode(m),'uint8');
        fseek(fid,1,0); % seek past 'future' value
    else
        fseek(fid,2,0);
    end
    
%     if electrode == 0 %signals experimental information
%         fseek(fid,(datapacketsize-8),0);
%     else
%         fseek(fid,(datapacketsize-8),0); % seek past waveform info
%     end
     
    fseek(fid,(datapacketsize-8),0); % seek past the rest of the packet (where waveform is)
    
    if ftell(fid) > nextthresh
        fprintf('Writing File Position: %i of %0.2f MB\n',(nextthresh/increment)*ninc,fsize);
        nextthresh = nextthresh + increment;
    end
end %while loop

fclose(fid);

