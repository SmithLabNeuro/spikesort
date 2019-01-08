function saveSort(src,fname)
global WaveformInfo
global FileInfo

chSort = dir([fullfile(WaveformInfo.sortFileLocation,'spikesortunits'),filesep,'ch*']);
if isempty(chSort) % no ch file
    return;
end

if src==-1 %to be used to save an unfinished sort to a default location (eventually)
    d = dir(fullfile(WaveformInfo.sortFileLocation,'spikesortunits'));
    d([d.isdir]) = []; %strip off '.' and '..'
    sort = cell(size(d));
    for dx = 1:numel(d)
        sort{dx} = load(fullfile(WaveformInfo.sortFileLocation,'spikesortunits',d(dx).name));
        sort{dx}.filename = d(dx).name;
    end
    histSort = dir([fullfile(WaveformInfo.sortFileLocation,'spikesortunits'),filesep,'hist*']);
    load(fullfile(WaveformInfo.sortFileLocation,'spikesortunits',histSort(1).name));
    fileSet = filenames;
    for i = 1:numel(chSort)
        load(fullfile(WaveformInfo.sortFileLocation,'spikesortunits',chSort(i).name));
        nSpikesToReadAllChannel(i) = nSpikesToRead;
    end
    if length(unique(nSpikesToReadAllChannel))>2
        error('Number of spikes to read is not consistency when sparse loading.');
    end
    nSpikesToReadAllChannel = unique(nSpikesToReadAllChannel);
    if isempty(find(nSpikesToReadAllChannel))
        nSpikesToReadPerChannel = 50000;
    else
        nSpikesToReadPerChannel = nSpikesToReadAllChannel(find(nSpikesToReadAllChannel));
    end
    %warning('error','MATLAB:save:sizeTooBigForMATFile'); %#ok<CTPCT> 
    try
        save(fname,'sort','fileSet','nSpikesToReadPerChannel');
    catch me
        switch me.identifier
            case 'MATLAB:save:sizeTooBigForMATFile'
                save(fname,'sort','fileSet','nSpikesToReadPerChannel','-v7.3');
            otherwise
                rethrow(me); %an unknown error... stop the presses so the sort isn't deleted...
        end
    end
    warning('on','MATLAB:save:sizeTooBigForMATFile');
else
    spikesort_gui('load');
    d = dir(fullfile(WaveformInfo.sortFileLocation,['spikesortunits' filesep 'hist*'])); %only save the history (no waveforms) when the user requests to save
    d([d.isdir]) = []; %strip off '.' and '..'
    sort = cell(size(d));
    for dx = 1:numel(d)
        sort{dx} = load(fullfile(WaveformInfo.sortFileLocation,'spikesortunits',d(dx).name));
        sort{dx}.filename = d(dx).name;
    end
    fileSet = {FileInfo.filename}; %#ok<NASGU>
    [~,filestem,~] = fileparts(FileInfo(1).filename); %take the stem of the first filename as a suggested name...
    uisave({'sort','fileSet'},['savedSort_' filestem]);
end