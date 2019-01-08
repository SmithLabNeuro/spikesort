% plxSortFromNEV(plxfilename)
%
% Takes a NEV file that was converted from PLX with plx2nev and writes the 
% sort codes back into the PLX file
%
% INPUT
%     plxfilename: string containing the PLX file (assumes same name with
%     .nev extension for the NEV file)

function plxSortFromNEV(plxfilename)

disp('plxSortFromNEV:');
disp(' ***WARNING: This writes to the PLX file and could corrupt it.');
disp('             Make sure you have a backup.');

% reply = input('             Do you want to continue? [Y/N]:','s');
% if ~strcmpi(reply,'y')
%     return
% end
    
%% Generate string for nevfilename
[pathstr, nevfilename]=fileparts(plxfilename);
nevfilename = strcat(pathstr,filesep,nevfilename, '.nev');

%% First, read the NEV and get all the sort codes
disp('Reading NEV file - ');

%Header Basic Information
fidRead = fopen(nevfilename,'r','l');
identifier = fscanf(fidRead,'%8s',1); %File Type Indentifier = 'NEURALEV'
filespec = fread(fidRead,2,'uchar'); %File specification major and minor 
version = sprintf('%d.%d',filespec(1),filespec(2)); %revision number
fileformat = fread(fidRead,2,'uchar'); %File format additional flags
headersize = fread(fidRead,1,'ulong'); 
%Number of bytes in header (standard  and extended)--index for data
datapacketsize = fread(fidRead,1,'ulong'); 
%Number of bytes per data packet (-8b for samples per waveform)
stampfreq = fread(fidRead,1,'ulong'); %Frequency of the global clock
samplefreq = fread(fidRead,1,'ulong'); %Sampling Frequency

BytesPerSample = 2; % technically this should be read in the extended header for each channel
samples = (datapacketsize - 8)/BytesPerSample;

%Windows SYSTEMTIME
time = fread(fidRead,8,'uint16');
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
application = fread(fidRead,32,'uchar')';

%Additional Information (and Extended Header Information)
comments = fread(fidRead,256,'uchar')';
extheadersize = fread(fidRead,1,'ulong');

fseek(fidRead,0,'eof');
nBytesInFile = ftell(fidRead);
nPacketsInFile = (nBytesInFile-headersize)/datapacketsize;
fseek(fidRead,0,'bof'); % rewind to beginning of file

%-------------------------------------------------------------------------------
%Read DATA
%Header Basic Information (skip over)
%fid = fopen(nevfile,'r','l');
fread(fidRead,headersize,'uchar');

%Data Packets
%---------------------
%indexing
x = 0;
m = 1;

increment = ceil(nBytesInFile * .10); % print a status message every 10% of file
nextthresh = increment;

spike = zeros(nPacketsInFile,3); 

fprintf('%% Complete: ');
while x == 0
    % read the full packet, which is the same size for digital
    % events or spikes. Then parse it up into the separate
    % variables. Doing this is faster than many reads
    [tempData,c] = fread(fidRead,datapacketsize,'uint8=>uint8');
    if c == 0 x = 1; %disp('Finished reading file'); 
        break; end
    
    timestamp = double(typecast(tempData(1:4),'uint32'));
    electrode = typecast(tempData(5:6),'uint16');
    class = tempData(7);
    %future = tempData(8);
   
    if (electrode == 0)
        % skip digital packets, only count spikes
%         dig = typecast(tempData(7:8),'uint16');
%         
%         spike(m,3) = (timestamp/samplefreq);
%         spike(m,2) = dig; % value on the digital port
%         spike(m,1) = 0; % zero indicates digital event
%         m = m + 1;
    else
     
        % store the spike times and channels in spike array
        spike(m,3) = timestamp/samplefreq; %global time (msec)
        spike(m,2) = class; %spike classification
        spike(m,1) = electrode;	%electrode number
        m = m+1;
    end
    
    % status message as data blocks are written
    if ftell(fidRead) > nextthresh
        fprintf('%d, ',floor((ftell(fidRead)/nBytesInFile)*100));
        nextthresh = nextthresh+increment;
    end

end %while loop

spikeend=find(sum(spike,2)==0);

if ~isempty(spikeend)
    if(spikeend(1)==1)
        cutind=spikeend(2);
        spike = spike(1:cutind-1,:);
    else
        cutind=spikeend(1);
        spike = spike(1:cutind-1,:);
    end
end

fprintf('\n Finished reading NEV file\n');
numSpkInNev = size(spike,1);

fclose(fidRead);
% Now, the NEV file is closed and we have the spike matrix, which is all we
% need

%% Now switch to the PLX file and read up to the point where you know the #spikes
fidWrite = fopen(plxfilename,'r');
disp('plxSortFromNEV: Reading PLX file header');

% File Header
magicNumber = fread(fidWrite, 1, 'uint32'); %magic num
versionNum = fread(fidWrite, 1, 'int32');
comment = fread(fidWrite, 128, 'char'); %user comment
adFreq = fread(fidWrite, 1, 'int32');
numDSPChan = fread(fidWrite, 1, 'int32');
numEventChan = fread(fidWrite, 1, 'int32');
numSlowChan = fread(fidWrite, 1, 'int32');
numPointsWave = fread(fidWrite, 1, 'int32');
numPtsPreThresh = fread(fidWrite, 1, 'int32');
yearStamp = fread(fidWrite, 1, 'int32');   %year
monthStamp = fread(fidWrite, 1, 'int32');  %month
dayStamp = fread(fidWrite, 1, 'int32');    %day
hourStamp = fread(fidWrite, 1, 'int32');
minStamp = fread(fidWrite, 1, 'int32');
secStamp = fread(fidWrite, 1, 'int32');
fastRead = fread(fidWrite, 1, 'int32');    %reserved
waveformFreq = fread(fidWrite, 1, 'int32');
lastTimeStamp = fread(fidWrite, 1, 'double');

%read in the next items if version >= 103
if versionNum >= 103
    trodalness = fread(fidWrite, 1, 'char');
    dataTrodalness = fread(fidWrite, 1, 'char');
    bitsPerSpikeSample = fread(fidWrite, 1, 'char');
    bytesPerSpikeSample = bitsPerSpikeSample / 8; % get bytes per spike sample
    bitsPerSlowSample = fread(fidWrite, 1, 'char');
    spikeMaxMagMV = fread(fidWrite, 1, 'ushort');
    slowMaxMagMV = fread(fidWrite, 1, 'ushort');
end

%Read in the next item if version >= 105
if versionNum >= 105
    spikePreAmpGain = fread(fidWrite, 1, 'ushort');
else
    spikePreAmpGain = 1000;
end

% Figure out the number of padding bytes based on what you've read so far
% if versionNum >= 105
%     paddingBytes = 46;
% elseif versionNum >= 103
%     paddingBytes = 44;
% else
%     paddingBytes = 38;
% end
% paddingJunk = fread(fidWrite, paddingBytes, 'char');   %padding so this part of header is 256 bytes

% Better solution - just seek to 256 bytes
fseek(fidWrite,256,'bof');

%Counters for number of timestamps, waveforms in each channel
tsCounts = fread(fidWrite, [130, 5], 'int32');
wfCounts = fread(fidWrite, [130, 5], 'int32');
evCounts = fread(fidWrite, [1, 512], 'int32');

spikesAccordingToHeader = sum(sum(tsCounts));
%contAccordingToHeader = sum(sum(wfCounts));
eventsAccordingToHeader = sum(evCounts);

fileHeaderSize = ftell(fidWrite);

%% Error check - NEV file spikes and PLX file spikes must match!
if numSpkInNev~=spikesAccordingToHeader
    error(sprintf('Spike count mismatch: %d NEV and %d PLX\n',numSpkInNev,spikesAccordingToHeader));
end

%% Spike Header

voltageConversion = nan(numDSPChan,1);

% Spike Channel Headers
for iHeader = 1:numDSPChan
    nameDSP = fread(fidWrite, 32, 'char'); % Name given to the DSP channel
    %disp(char(nameDSP'));
    sigName = fread(fidWrite, 32, 'char'); % Name given to the corresponding SIG channel
    channelNum = fread(fidWrite, 1, 'int32');  %DSP channel number, 1 based
    wfRate = fread(fidWrite, 1, 'int32');
    sigChan = fread(fidWrite, 1, 'int32'); %SIG channel associated with this DSP channel
    sigRefChan = fread(fidWrite, 1, 'int32'); %SIG channel used as a reference signal
    channelGain = fread(fidWrite, 1, 'int32'); % actual gain divided by SpikePreAmpGain
    filter = fread(fidWrite, 1, 'int32'); %either 0 or 1
    threshold = fread(fidWrite, 1, 'int32');  %threshold for spike detection in a/d values
    method = fread(fidWrite, 1, 'int32'); % Method used for sorting units, 1 - boxes, 2 - templates
    nUnits = fread(fidWrite, 1, 'int32');  %number of sorted units
    template = fread(fidWrite, 320, 'short');  %Templates used for template sorting, in a/d values [5][64]
    fit = fread(fidWrite, 5, 'int32'); %template fit
    sortWidth = fread(fidWrite, 1, 'int32');   %how many points to use in template sorting
    boxes = fread(fidWrite, 40, 'short');  %the boxes used in boxes sorting
    sortBeginning = fread(fidWrite, 1, 'int32');   %the beginning of the sorting window to use in template sorting
    comment = fread(fidWrite, 128, 'char');
    paddingJunk = fread(fidWrite, 11, 'int32');
    
    if versionNum >= 105
        voltageConversion(iHeader) = spikeMaxMagMV / (0.5 * (2^bitsPerSpikeSample) * (channelGain) * (spikePreAmpGain));
    elseif versionNum >= 103
        voltageConversion(iHeader) = spikeMaxMagMV / (0.5 * (2^bitsPerSpikeSample) * (channelGain) * (1000));
    else
        voltageConversion(iHeader) = 3000 / (2048 * channelGain * 1000);
    end  
end

%% Event Header

for iHeader = 1:numEventChan
    nameEvent = fread(fidWrite, 32, 'char'); % name given to this event
    %disp(char(nameEvent'));
    channelNum = fread(fidWrite, 1, 'int32'); % event number, 1-based
    comment = fread(fidWrite, 128, 'char');
    paddingJunk = fread(fidWrite, 33, 'int32');
end

%% Slow Channel Header
for iHeader = 1:numSlowChan
    nameSlow = fread(fidWrite, 32, 'char');
    %disp(char(nameSlow'));
    channelNum = fread(fidWrite, 1, 'int32'); % channel number, 0-based
    slowADFreq = fread(fidWrite,1,'int32'); % digitization frequency
    slowGain = fread(fidWrite,1,'int32'); % gain at the adc card
    slowEnabled = fread(fidWrite,1,'int32'); % whether this channel is enabled for taking data, 0 or 1
    slowPreAmpGain = fread(fidWrite,1,'int32');
    if versionNum >= 104
        % indicates the spike channel corresponding to this continuous data channel
        slowSpikeChannel = fread(fidWrite,1,'int32');
    end
    comment = fread(fidWrite, 128, 'char');
    paddingJunk = fread(fidWrite, 28, 'int32');
end

%% Skip all headers to get to data blocks
nBytesinDSPHeader = 1020;  %number of bytes in DSP channel header
nBytesinEventHeader = 296;
nBytesinSlowHeader = 296;

DSPSkip = nBytesinDSPHeader * numDSPChan;
eventSkip = nBytesinEventHeader * numEventChan;
slowSkip = nBytesinSlowHeader * numSlowChan;
fseek(fidWrite, fileHeaderSize + DSPSkip + eventSkip + slowSkip, 'bof'); %skip to first data block from beginning of file

%% Read a sample of spikes to determine packet size
spikesToRead = 1000;
minPacketFreq = 0.9; % if > this portion of packets are same size, use that

fprintf('plxSortFromNEV: Determining packet size ... ');
nWordsVec = zeros(1, spikesToRead);
nWordsCount = 0;

while nWordsCount < spikesToRead
    
    if feof(fidWrite) == 1
        if nWordsCount+1 <= spikesToRead
            nWordsVec(nWordsCount+1:end)=[];
        end
        break;
    end
    
    dataType = fread(fidWrite, 1, 'int16');
    upperByte = fread(fidWrite, 1, 'uint16');
    timestamp = fread(fidWrite, 1, 'uint32');
    channelNum = fread(fidWrite, 1, 'int16'); %%
    
    sortCode = fread(fidWrite, 1, 'int16'); %%
    numWaveforms = fread(fidWrite, 1, 'int16'); % number of waveforms in following data block
    nWordsinWave = fread(fidWrite, 1, 'int16');
    
    if ~isempty(numWaveforms) && ~isempty(nWordsinWave)   % check for empty numWaveforms/nWordsinWave arrays
        if numWaveforms > 0 && dataType > 0 && nWordsinWave > 0 % Get all events
            waveform = fread(fidWrite, [nWordsinWave, 1], 'int16'); %Read in wave (as junk)
            if dataType == 1 % Spike
                nWordsCount = nWordsCount + 1;
                nWordsVec(:, nWordsCount) = nWordsinWave;
            end
        end
    end % End of loops to read in wave as junk and store nWordsinWave for spikes
    if nWordsCount > spikesToRead
        break
    end
    
end % End of loop to determine packet size
fprintf('read %d spikes ... ', nWordsCount);

%% Determine what packet size to use

if size(unique(nWordsVec), 2) > 1
    
    % Find frequency of each of the packet lengths found
    [modeWords, freqWords] = mode(nWordsVec);
    
    if freqWords / size(nWordsVec, 2) > minPacketFreq
        nWordsinWave = modeWords;
    else
        uniqueWords = unique(nWordsVec);    %already sorted
        maxChoice = numel(uniqueWords) + 1;
        
        fprintf('\nThe plx file has a variable packet length.\n');
        fprintf('Please select a packet length to proceed:\n');
        
        for iChoice = 1:numel(uniqueWords)
            fprintf('%d. Packet length is %d\n', iChoice, uniqueWords(iChoice));
        end
        fprintf('%d. Quit plx to nev conversion', maxChoice);
        
        userChoice = input('\n\nEnter your choice: ');
        
        while userChoice > maxChoice || userChoice < 0
            userChoice = input('Enter your choice: ');
        end
        
        % if statements for each choice
        if userChoice < numel(uniqueWords)
            nWordsinWave = uniqueWords(userChoice);
        else
            fprintf('\nplxSortFromNEV: Quitting...');
            fprintf('\nplxSortFromNEV: ERROR: was not able to convert waves');
            return
            % Stop conversion, print error
        end % End of implementing user's choice
        
    end
    
else
    nWordsinWave = unique(nWordsVec);
end% End of nWordsVec loop

fprintf('using %d words per packet\n', nWordsinWave);

fclose(fidWrite);

%% Writing sort codes to the PLX file

% Open and seek to location of first data packet in plx file
fidWrite = fopen(plxfilename,'r+','l'); % use 'r+' here to not discard file
fseek(fidWrite, fileHeaderSize + DSPSkip + eventSkip + slowSkip, 'bof');

spikeCount = 0;
printFreq = ceil(spikesAccordingToHeader/10); % print a status message every 10 percent

fprintf('plxSortFromNEV: Writing sort codes into PLX ... ');

while feof(fidWrite) == 0 %read until the end of file
    
    % Read in data block header - 16 bytes
    dataType = fread(fidWrite, 1, 'int16'); % 1 = spike, 4 = event, 5 = continuous
    upperByte = fread(fidWrite, 1, 'uint16');
    timestamp = fread(fidWrite, 1, 'uint32');
    channelNum = fread(fidWrite, 1, 'int16');

    if dataType == 1
        % If it's a spike dataType (1) write the value from the NEV file 
        % (in "spikes") matrix. If it's anything else, go ahead and read
        % the sort code and move on
        spikeCount = spikeCount + 1;
        fseek(fidWrite,0,0); % stupid thing needed here
        fwrite(fidWrite,int16(spike(spikeCount,2)),'int16');
    else
        fseek(fidWrite,0,0); % stupid thing needed here
        sortCode = fread(fidWrite, 1, 'int16');
    end
    
    numWaveforms = fread(fidWrite, 1, 'int16'); % number of waveforms in following data block
    sampleNWordsinWave = fread(fidWrite, 1, 'int16');

    if numWaveforms > 0 % continuous data follows
        waveform = fread(fidWrite, [sampleNWordsinWave*numWaveforms, 1], 'int16'); %Read in wave
    end
    
    % convert time stamp to seconds - seems to work fine
    ts = cast(bitshift(upperByte,32),'uint64') + cast(timestamp,'uint64');
    ts = cast(ts,'uint32');

    % status message as sort codes are written
    if rem(spikeCount,printFreq)==0
        fprintf('%d%%, ',floor((spikeCount/spikesAccordingToHeader)*100));
    end

    % break out of loop if you reach end of file
    if feof(fidWrite) == 1
        break
    end
    
end % End of while loop to read/write waves

fclose(fidWrite);

%% Print final status, and note if there were any problems
fprintf('\nplxSortFromNEV:   %d sortCodes were written to the nev file.\n',spikeCount);

if spikeCount ~= spikesAccordingToHeader
    fprintf('plxSortFromNEV: *** Warning: Header said %d spikes but only %d were written to the nev file! ***',spikesAccordingToHeader,spikeCount);
end

fprintf('\n');

