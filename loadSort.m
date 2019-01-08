function loadSort(src,fname)
global WaveformInfo
global FileInfo
global Handles
global ssDat
%
% src = -1 load tempsort | src ~= -1 load saved sort

%navigate to the file if a user is loading...
if src~=-1
    [~,name,~] = fileparts(FileInfo(1).filename);
    [fname,path] = uigetfile('savedSort_*.mat','Spikesort: load saved sort...');
    if fname==0
        return;
    end %don't continue if the user cancels (i.e., don't erase the current sort!)
    fname = fullfile(path,fname);
    load(fname,'fileSet');
    [~,sortname,~] = fileparts(fileSet{1});
    if ~strcmp(name,sortname)
        fileStr = sprintf('Current loaded file set:%s',name);
        sortStr = sprintf('Saved sort you choose:%s',sortname);
        warndlg({'Saved sort you choose does not match current loaded file set.';...
            fileStr;...
            sortStr;},'Warning');
        return;
    end    
else
    if isempty(fname)
        return; %don't continue if there's no file to load...
    else
        WaveformInfo.tempSortName = fname;
    end
end

%first, clear the history files from the temporary directory:
if src~=-1
    d = dir([fullfile(WaveformInfo.sortFileLocation,'spikesortunits'),filesep,'hist*']);
    sortfiles = {d.name};
    sortfiles = cellfun(@strcat,repmat({[WaveformInfo.sortFileLocation,filesep,'spikesortunits',filesep]},size(sortfiles)),sortfiles,'uniformoutput',0);
    
    ansr = questdlg({'Spikesort is attempting to load a sort.';...
        'This will overwrite the sort history in progress (but does not yet write to the NEV file).';...
        'What would you like to do?';...
        '(Choose cancel to go back and save your current sort first)';},...
        'Spikesort',...
        'Cancel loading','Proceed with overwriting my sort','Cancel loading');
    if isempty(ansr)
        ansr='Cancel loading';
    end
    switch lower(ansr(1))
        case 'p'
            if ~isempty(sortfiles)
                delete(sortfiles{:});
            end
            load(fname,'sort');
            for i = 1:length(sort)
                chanNum = str2double(regexp(sort{i}.filename,'\d+','match','once'));
                if ~isempty(sort{i}.String) && ~exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',chanNum)),'file')==2
                    readSampleWaveforms(chanNum,'off',ssDat.doTimer,ssDat.doSparse);
                end
            end
        otherwise
            return; %cancel load sort operation
    end
end

%load the sort
load(fname,'sort','nSpikesToReadPerChannel');
for h = 1:length(FileInfo)
    FileInfo(h).nSpikesToReadPerChannel = nSpikesToReadPerChannel;
end
s_all = Handles.ChannelString;
for f = 1:length(sort)
    fields = fieldnames(sort{f});
    for v = 1:numel(fields)
        eval(sprintf('%s=sort{f}.%s;',fields{v},fields{v}));
    end
    save(fullfile(WaveformInfo.sortFileLocation,'spikesortunits',sort{f}.filename),fields{:});
    chanNum = str2double(regexp(sort{f}.filename,'\d+','match','once'));
    loc = find(chanNum == get(Handles.channel,'UserData'));
    if ~isempty(loc)
        s = s_all{loc};
        %s = s(1:strfind(s,')'));    
        if ~isempty(sort{f}.String)
            s_all{loc} = [s ' *'];
        else
            s_all{loc} = s;
        end
    end
end
set(Handles.channel,'String',s_all);
if src~=-1
    WaveformInfo.ChannelNumber = 0; %setting this to 0 will reload this history files, rather than overwrite them...
    spikesort_gui('load'); %first time loads the history...
end