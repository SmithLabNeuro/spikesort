function readSampleWaveforms(ch,verbose,doTimer,doSparse)
%function readSampleWaveforms(ch,verbose,doTimer,doSparse)
% 
% This can load a subset of spikes for sorting, using a field of FileInfo 
% called maskedPacketOrder, where it replaced all but X (X usually is 50,000)
% of the values with an index that isn't in the active channel list. Since we
% read packet locations matching active channels, the masked events
% will never be read. When writing, all events are read in again, so
% the sorting steps will be applied to all spikes, including those that
% were masked for reading purposes.

global FileInfo;
global Handles;
global WaveformInfo;
global guiVals;

ChannelString = Handles.ChannelString;
ActiveChannelList =get(Handles.channel,'UserData');
set(Handles.readSize,'enable','off');
nSpikesToReadPerChannel = str2double(get(Handles.readSize,'String'));
totalSpikes = 0;
for h = 1:length(FileInfo)
    FileInfo(h).nSpikesToReadPerChannel = nSpikesToReadPerChannel;
    if ismember(ch,FileInfo(h).ActiveChannels) 
        totalSpikes=totalSpikes + FileInfo(h).SpikesNumber(ch);
    end
end
if doSparse && totalSpikes > nSpikesToReadPerChannel
    Sparse = 2;
    nSpikesToRead = nSpikesToReadPerChannel;
else
    Sparse = 1;
    nSpikesToRead = 0;
end

if nargin<2,verbose='on';end 
if nargin<3,doTimer=true;end


for j = 1:numel(ch)
    if ishandle(Handles.channel)&&(find(get(Handles.channel,'userdata')==ch(j))==1||~doTimer) 
        PacketNumbers = [];
        
        for i=1:length(FileInfo)
            if Sparse == 2
                nums = find(FileInfo(i).maskedPacketOrder == ch(j));
            else
                nums = find(FileInfo(i).PacketOrder == ch(j));
            end
            PacketNumbers = [PacketNumbers; ones(length(nums),1)*i nums]; %#ok<*AGROW>
        end
        
        Waveforms = [];
        Unit = [];
        Times = [];
        Breaks = zeros(length(FileInfo),1);
        
        for i = find(cellfun(@ismember,repmat({ch(j)},size(FileInfo)),{FileInfo.ActiveChannels})), 
            PN = PacketNumbers(PacketNumbers(:,1)==i,2);
            loc = FileInfo(i).HeaderSize + FileInfo(i).Locations(PN);
            
            [wav,tim,uni] = readWaveforms2(loc,WaveformInfo.NumSamples,FileInfo(i).filename);
            wav = int16(double(wav) / 1000 * FileInfo(i).nVperBit(ch(j))); 
            
            Waveforms = [Waveforms; wav'];
            
            newTimes = double(tim)/FileInfo(i).TimeResolutionTimeStamps*1000;
            
            if i < length(FileInfo)
                if isempty(newTimes)
                    Breaks(i+1) = Breaks(i);
                else
                    Breaks(i+1) = Breaks(i)+max(newTimes);
                end
            end
            
            newTimes = newTimes + Breaks(i);
            
            Times = [Times; newTimes];
            Unit = [Unit; uni];
            
            FileInfo(i).units{ch(j)} = zeros(256,1);
            FileInfo(i).units{ch(j)}(unique(double(Unit))+1) = 1;
        end
        if exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ch(j))),'file') == 2
            save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ch(j))),'Waveforms','Times','Unit','Breaks','Sparse','nSpikesToRead','-append');
        else
            ComponentLoadings = [];
            me = [];
            save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ch(j))),'Waveforms','Times','Unit','Breaks','Sparse','nSpikesToRead','ComponentLoadings','me');
        end
        updateString = get(Handles.channel,'string');
        switch Sparse
            case 1
                updateString{(ActiveChannelList==ch(j))} = ['<HTML><FONT color=' guiVals.chanColor{2} '>' ChannelString{(ActiveChannelList==ch)} '</FONT></HTML>'];
            case 2
                updateString{(ActiveChannelList==ch(j))} = ['<HTML><FONT color=' guiVals.chanColor{3} '>' ChannelString{(ActiveChannelList==ch)} '</FONT></HTML>'];
        end
        set(Handles.channel,'value',find(ActiveChannelList==ch(j)));
        set(Handles.channel,'string',updateString);
   
        spikesort_gui('load');
    elseif ishandle(Handles.mainFigure) %i.e., it hasn't been closed yet...
        if Sparse == 2
            readWaveforms2_timer_sparse(ch(j));
        else
            readWaveforms2_timer(ch(j));
        end
        save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ch(j))),'Sparse','nSpikesToRead','-append');
        if j==1
            spikesort_gui('load');
        end
    end
end
set(Handles.readSize,'enable','off');


