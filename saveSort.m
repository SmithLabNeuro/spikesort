function saveSort(src,fname)
global WaveformInfo
global FileInfo

chSort = dir([fullfile(WaveformInfo.sortFileLocation,'spikesortunits'),filesep,'ch*']);
if isempty(chSort) % no ch file
    return;
end

histSort =  dir([fullfile(WaveformInfo.sortFileLocation,'spikesortunits'),filesep,'hist*']);
histStatus = zeros(size(histSort));
for i = 1:length(histSort)
    load(fullfile(WaveformInfo.sortFileLocation,'spikesortunits',histSort(i).name));
    if ~isempty(String) % no history
        histStatus(i) = 1;
    end
end

% if sum(histStatus)==0
%     disp('No history to save!');
%     return;
% else
if src==-1 %to be used to save an unfinished sort to a default location (eventually)
    d = dir(fullfile(WaveformInfo.sortFileLocation,'spikesortunits'));
    d([d.isdir]) = []; %strip off '.' and '..'
    sort = cell(size(d));
    for dx = 1:numel(d)
        sort{dx} = load(fullfile(WaveformInfo.sortFileLocation,'spikesortunits',d(dx).name));
        sort{dx}.filename = d(dx).name;
    end
%     load(fullfile(WaveformInfo.sortFileLocation,'spikesortunits',histSort(1).name));
    for i =1:length(FileInfo)
        [~,name,ext] = fileparts(FileInfo(i).filename);
        fileSet{i} = [name,ext];
    end
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
    note = msgbox('Please wait to save tempsort!');
    try
        save(fname,'sort','fileSet','nSpikesToReadPerChannel','-v7.3');
    catch me
%         switch me.identifier
%             case 'MATLAB:save:sizeTooBigForMATFile'
%                 save(fname,'sort','fileSet','nSpikesToReadPerChannel','-v7.3');
%             otherwise
          rethrow(me); %an unknown error... stop the presses so the sort isn't deleted...
%         end
    end
    close(note);
else
    sort = cell(size(histSort));
    for dx = 1:numel(histSort)
        sort{dx} = load(fullfile(WaveformInfo.sortFileLocation,'spikesortunits',histSort(dx).name));
        sort{dx}.filename = histSort(dx).name;
    end
    for i =1:length(FileInfo)
        [~,name,ext] = fileparts(FileInfo(i).filename);
        fileSet{i} = [name,ext];
    end
    nSpikesToReadPerChannel = [];
    if src == 0
        save(fname,'sort','fileSet','nSpikesToReadPerChannel');
    else
        [~,filestem,~] = fileparts(FileInfo(1).filename); %take the stem of the first filename as a suggested name...
        
        uisave({'sort','fileSet','nSpikesToReadPerChannel'},['savedSort_' filestem]);
    end
    
end
% end