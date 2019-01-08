function spikesort_nevscan(j, feedback)

global FileInfo;
fid=fopen([FileInfo(j).filename],'r','l');

if nargin<2, feedback = true; end

%read general header
FileType=fread(fid,8,'char');
Version=fread(fid,2,'uchar');
FileFormatAdditional=fread(fid,2,'char');
HeaderSize=fread(fid,1,'uint32');
PacketSize=fread(fid,1,'uint32');
FileInfo(j).TimeResolutionTimeStamps=fread(fid,1,'uint32');
FileInfo(j).TimeResolutionSamples=fread(fid,1,'uint32');
TimeOrigin=fread(fid,8,'uint16'); %unsure about actualtype of TimeOrigin
Application=fread(fid,32,'char');
Comment=fread(fid,256,'uchar');
ExtendedHeaderNumber=fread(fid,1,'ulong');

BytesPerSample = 2;

%read extended headers
for i=1:ExtendedHeaderNumber
    Identifier=char(fread(fid,8,'char'))';
    switch Identifier
        case 'NEUEVWAV'
            ElecID=fread(fid,1,'uint16');
            PhysConnect=fread(fid,1,'uchar');
            PhysConnectPin=fread(fid,1,'uchar');
            FileInfo(j).nVperBit(ElecID)=fread(fid,1,'uint16');
            EnergyThresh=fread(fid,1,'uint16');
            FileInfo(j).HighThresh(ElecID)=fread(fid,1,'int16');
            FileInfo(j).LowThresh(ElecID)=fread(fid,1,'int16');
            SortedUnits=fread(fid,1,'uchar');
            BytesPerSample=((fread(fid,1,'uchar'))>1)+1;
            temp=fread(fid,10,'uchar');
        otherwise
            temp=fread(fid,24,'uchar');
    end
end

% Calculate number of packets
fseek(fid,0,1);
FileSize=ftell(fid);
PacketNumber=(FileSize-HeaderSize)/PacketSize;

%initialization
fseek(fid,HeaderSize,-1);
fread(fid,1,'uint32');

%read the data
FileInfo(j).PacketOrder=fread(fid,PacketNumber,'uint16=>uint16',PacketSize-2);
fseek(fid,HeaderSize,-1);
fclose(fid);
FileInfo(j).Locations=(0:PacketSize:PacketSize*(PacketNumber-1))';%The location of packets.

%accumarray is fast for this
FileInfo(j).SpikesNumber = accumarray(FileInfo(j).PacketOrder(FileInfo(j).PacketOrder>0),1);

% The next section deals with finding and purging amplifier pops - not used
%
%ShockThreshold=round(0.9*length(FileInfo(j).ActiveChannels));
%if ShockThreshold>30
%    suspects=find((Times(ShockThreshold:end)-Times(1:end-ShockThreshold+1))<=2);
%    for i2=suspects'
%        ShockPackets=find(abs(Times-Times(i2))<2);
%        FileInfo(j).PacketOrder(ShockPackets)=0;
%    end
%    for i1=1:max( FileInfo(j).ActiveChannels)
%        FileInfo(j).SpikesNumber(i1)=sum(FileInfo(j).PacketOrder==i1);
%    end
%end

%Set file information global
FileInfo(j).SamplingRate=FileInfo(j).TimeResolutionSamples/1000; % in kHz
FileInfo(j).ActiveChannels=find(FileInfo(j).SpikesNumber);
FileInfo(j).HeaderSize=HeaderSize;
FileInfo(j).PacketSize=PacketSize;
FileInfo(j).BytesPerSample=BytesPerSample; %This can have electrode dependent values, but here only set once
FileInfo(j).NumSamples = (PacketSize - 8)/BytesPerSample;
FileInfo(j).PacketTime = FileInfo(j).NumSamples/FileInfo(j).TimeResolutionSamples*1000; % in ms

try %Figure out threshold location
    nWavesToCheck=1000;
    WavesToCheck = find(FileInfo(j).PacketOrder>0,nWavesToCheck,'first');ix =[];
    loc = HeaderSize + FileInfo(j).Locations(WavesToCheck);
    [wav,~,~] = readWaveforms2(loc,FileInfo(j).NumSamples,FileInfo(j).filename);
    wav = int16(double(wav)./1000*FileInfo(j).nVperBit(1));
    [~,mi]=min(mean(double(wav),2)); % an attempt at figuring the likely location
    
    try
        hval = FileInfo(j).HighThresh(FileInfo(j).ActiveChannels);
        lval = FileInfo(j).LowThresh(FileInfo(j).ActiveChannels);
        dummyVal = [0 6554];
        if min(ismember([hval lval],dummyVal))==1
            % if there are no valid threshold values
            FileInfo(j).ThresholdLocation=mi-1;
        elseif (min(ismember(hval,dummyVal))==1 || min(ismember(hval - lval,0))==1) && mean(lval)<0
            % if there's a low thresh but no high thresh
            for i = 1:nWavesToCheck
                % find first value exceeding the low thresh
                ix1 = find(wav(:,i) <= FileInfo(j).LowThresh(FileInfo(j).PacketOrder(WavesToCheck(i))), 1, 'first');
                if isempty(ix1)
                    ix1=Inf;
                end
                ix= cat(1,ix,ix1);
            end
            [tm,~] = mode(ix(ix<Inf));
            FileInfo(j).ThresholdLocation=tm;
        elseif (min(ismember(lval,dummyVal))==1 || min(ismember(hval - lval,0))==1) && mean(hval)>0
            % if there's a high thresh but no low thresh
            for i = 1:nWavesToCheck
                % find first value exceeding the high thresh
                ix2 = find(wav(:,i) >= FileInfo(j).HighThresh(FileInfo(j).PacketOrder(WavesToCheck(i))), 1, 'first');
                if isempty(ix2)
                    ix2=Inf;
                end
                ix= cat(1,ix,ix2);
            end
            [tm,~] = mode(ix(ix<Inf));
            FileInfo(j).ThresholdLocation=tm;
        else
            FileInfo(j).ThresholdLocation=mi-1;
        end
    catch
        disp('Error finding ThresholdLocation - guessing the threshold based on a mean waveform');
        FileInfo(j).ThresholdLocation=mi-1;
    end
catch
    disp('Error finding ThresholdLocation - using default of .3 * NumSamples');
    FileInfo(j).ThresholdLocation=ceil(FileInfo(j).NumSamples * .3); % Set the default threshold location
end

% make sure the threshold location is valid
if isempty(intersect(FileInfo(j).ThresholdLocation,1:FileInfo(j).NumSamples))
    disp('Invalid ThresholdLocation - using a value of 1');
    FileInfo(j).ThresholdLocation = 1;
end

disp(['spikesort_nevscan: Using a threshold of ',num2str(FileInfo(j).ThresholdLocation),' samples']);
