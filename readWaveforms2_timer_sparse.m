function readWaveforms2_timer_sparse(chan)

    try 
        initializeTimer(chan)        
    catch ME
        switch lower(ME.stack(1).name(1:5))
            case 'timer' %I think these errors are caused by a timer object getting deleted in the middle of the call to timerfind, so in that case, just ignore it and start the timer...
                warning('spikesort:timerfindError','readWaveforms2_timer: If you see this warning, please inform Adam (adam@adamcsnyder.com) and check that all your channels were loaded properly.');
            case 'start'
                %matlab thinks the timer was deleted?
                %trying to load a channel that was already loaded?
                warning('spikesort:startDeletedLoadTimer','Spikesort tried to start a timer for channel %d, but it looks like that channel was already loaded.',chan); 
            otherwise
                rethrow(ME);
        end
    end
    
function initializeTimer(chan)

    u.maxRunningTimers = 1;
    u.fileInd = 1;
    u.spkInd = 1;
    u.chan = chan;
    u.chunkSize = 100; %number of spikes to be read on each timer call...
    readTimer = timer('timerfcn',@freadTimer,...
        'tag','freadTimer',...
        'executionmode','fixedrate',...
        'period',0.001,...
        'busymode','drop',...
        'userdata',u,...
        'startfcn',@freadTimerStart,...
        'stopfcn',@freadTimerStop,...
        'errorfcn',@freadTimerError);
    
    if length(timerfind('tag','freadTimer','running','on'))<u.maxRunningTimers
        start(readTimer);
    end
    
function freadTimerStart(src,~)
    %initialize data
    global FileInfo
    u = get(src,'userdata');
    ch = u.chan;
    PacketNumbers = [];
    for i=1:length(FileInfo)
        nums = find(FileInfo(i).maskedPacketOrder == ch);
        PacketNumbers = [PacketNumbers; ones(length(nums),1)*i nums]; %#ok<AGROW>
    end
    u.PacketNumbers = PacketNumbers;
    u.Waveforms = [];
    u.Unit = [];
    u.Times = [];
    u.Breaks = zeros(length(FileInfo),1);
    
    set(src,'userdata',u);
    
function freadTimer(src,~)
    global FileInfo WaveformInfo Handles
    u = get(src,'userdata');
    ch = u.chan;
    f = u.fileInd;
    chunkSize = u.chunkSize;

    if ismember(ch,FileInfo(f).ActiveChannels)
        I = u.spkInd;
        PacketNumbers = u.PacketNumbers;
        if I==1 %first spike of the file, do some setup...
            u.fid = fopen(FileInfo(f).filename,'r');
            assert(u.fid>-1,'File %s not found',FileInfo(f).filename);
            u.PN = PacketNumbers(PacketNumbers(:,1)==f,2);
            u.packetLocations = FileInfo(f).HeaderSize + FileInfo(f).Locations(u.PN);
            u.spikeCount = numel(u.packetLocations);
            u.packetSize = FileInfo(f).PacketSize;
            u.tempData = zeros(u.packetSize,u.spikeCount,'uint8');
            u.pl2 = diff(u.packetLocations);
            u.readStr = [num2str(u.packetSize),'*uint8=>uint8'];
        end
        tempData = u.tempData;
        fid = u.fid;
        packetLocations = u.packetLocations;
        spikeCount = u.spikeCount;
        packetSize = u.packetSize;
        pl2 = u.pl2;
        readStr = u.readStr;
        fseek(fid,packetLocations(I),'bof');
        if I<spikeCount 
            for i = 0:(chunkSize-1)
                if (I+i)==spikeCount
                    u.spkInd = I+i;
                    break;
                else
                    try
                        currentString = get(Handles.channel,'string');
                        updateString = currentString;
                        updateString{get(Handles.channel,'userdata')==u.chan} = repmat('-',1,ceil(10.*(I+i)./spikeCount)); 
 
                        set(Handles.channel, 'string', updateString);
                        drawnow;
                    catch ME
                        switch ME.identifier
                            case 'MATLAB:class:InvalidHandle'                                
                                stop(src);                                 
                                return
                            otherwise
                                rethrow(ME);
                        end
                    end                       
                    tempData(:,I+i) = fread(fid,packetSize,readStr,pl2(I+i)-packetSize);
                    u.spkInd = I+i;
                end
            end
        else %last spike for this file and channel
            tempData(:,I) = fread(fid,packetSize,'uint8=>uint8');
            tim = typecast(reshape(tempData(1:4,:),numel(tempData(1:4,:)),1),'uint32');
            uni = tempData(7,:)';
            wav = typecast(reshape(tempData(9:packetSize,:),numel(tempData(9:packetSize,:)),1),'int16');
            wav = reshape(wav,WaveformInfo.NumSamples,spikeCount);
            wav = int16(double(wav) / 1000 * FileInfo(f).nVperBit(ch)); 
            Waveforms = [u.Waveforms; wav'];
            newTimes = double(tim)/FileInfo(f).TimeResolutionTimeStamps*1000;
            Breaks = u.Breaks;
            if f < length(FileInfo)
                if isempty(newTimes)
                    Breaks(f+1) = Breaks(f);
                else
                    Breaks(f+1) = Breaks(f)+max(newTimes);
                end
            end
            newTimes = newTimes + u.Breaks(f);
            Times = [u.Times; newTimes];
            Unit = [u.Unit; uni];
            FileInfo(f).units{ch} = zeros(256,1);
            FileInfo(f).units{ch}(unique(double(Unit))+1) = 1;
            u.fileInd = f+1; %increment file index
            u.spkInd = 1; %start at first spike of next file
            fclose(fid); %close the current file 
            if u.fileInd>numel(FileInfo) %this channel is completely read
                save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ch)),'Waveforms','Times','Unit','Breaks');
            end
            u.Waveforms = Waveforms;
            u.Unit = Unit;
            u.Times = Times;
            u.Breaks = Breaks;
        end
        u.tempData = tempData;
        set(src,'userdata',u);   
        if u.fileInd>numel(FileInfo) %this channel is completely read
            stop(src); %stop the timer
        end
    else %the channel is not active in this file...
        u.fileInd = f+1; %increment file index
        u.spkInd = 1; %start at first spike of next file
        if u.fileInd>numel(FileInfo) %this channel is completely read
            Waveforms = u.Waveforms; %#ok<*NASGU>
            Breaks = u.Breaks;
            Times = u.Times;
            Unit = u.Unit;
            save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ch)),'Waveforms','Times','Unit','Breaks');
        end
        set(src,'userdata',u);
        if u.fileInd>numel(FileInfo) %this channel is completely read
            stop(src); %stop the timer
        end
    end
    
    
function freadTimerStop(src,~)
    global Handles    
    u = get(src,'userdata');
    fprintf('Timer for channel %d: avg. per. = %.3f, tasks exec. = %d\n',u.chan,get(src,'averageperiod'),get(src,'tasksexecuted'));
    set(src,'tag','beingdeleted'); %change the tag, so we don't accidentally 'find' it again...
    
    try
        thisChanInd = find(get(Handles.channel,'userdata')==u.chan);
        updateString = get(Handles.channel,'string');
        updateString(thisChanInd) = Handles.ChannelString(thisChanInd);
             
        set(Handles.channel,'string',updateString); 
        drawnow;
    catch ME
        switch ME.identifier
            case 'MATLAB:class:InvalidHandle'   
                delete(src)
                return
            otherwise
                rethrow(ME);
        end
    end   
    delete(src);
    %start timers that are waiting:
    while length(timerfind('tag','freadTimer','running','on'))<u.maxRunningTimers && ~isempty(timerfind('tag','freadTimer','running','off'))>0,
        waitingTimers = timerfind('tag','freadTimer','running','off');
        start(waitingTimers(1)); 
    end
    
function freadTimerError(~,evt)
    display(evt.Data);
    
    
    
