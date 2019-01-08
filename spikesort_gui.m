function spikesort_gui(operation,callbackEvent)

global Handles;
global FileInfo;
global WaveformInfo;
global ssDat;
global guiVals;

ChannelString = Handles.ChannelString;

if (strcmp(operation,'load') == 0)
    if WaveformInfo.ChannelNumber == 0
        return
    end
elseif ~ishandle(Handles.mainFigure)
    return
end

if nargin<2, callbackEvent = []; end
chanStr = get(Handles.channel,'string');
ActiveChannelList = get(Handles.channel,'UserData');
cachedList = false(size(chanStr));
for i = 1:size(chanStr,1)
    cachedList(i) = exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ActiveChannelList(i))),'file');
end
if strfind(chanStr{get(Handles.channel,'value')},'-')
    return;
end %ignore unloaded channels...

if isfield(Handles,'mainWindow')
    figHandle = Handles.mainWindow; %Ver. 2
    if ~isfield(WaveformInfo,'sortFileLocation') 
        WaveformInfo.sortFileLocation = evalin('base','cd'); %Version 1 is supposed to be run in the directory containing the spikesortunits folder...
    end
else
    figHandle = Handles.mainFigure; %Ver. 1
    WaveformInfo.sortFileLocation = evalin('base','cd'); %Version 1 is supposed to be run in the directory containing the spikesortunits folder...
end
noRedrawFlags = get(findobj(figHandle,'tag','noRedraw'),'userdata');
if iscell(noRedrawFlags),noRedrawFlags = cell2mat(noRedrawFlags); end
WaveformInfo.noRedraw = any(noRedrawFlags);


key = get(figHandle,'currentcharacter');
charNum = double(key);

set(figHandle,'Pointer','watch');
switch(operation) %alphabetize the cases some time...
    case 'drawpca'
        drawPca;
    case 'drawthreshold'
        drawThreshold;
    case 'keyfcn'
        if ~isempty(charNum)
            switch charNum
                case 26 %Ctrl+z
                    %step back through history
                    if ~isfield(Handles,'mainWindow') %for backwards-compatability...
                        undoHistory;
                    end
                case num2cell([28,29]) %left or right arrows
                    disp(gcf)
                    %move sort code
                    ChannelInfo = get(Handles.channel,'UserData');
                    cachedList = false(size(chanStr));
                    for i = 1:size(chanStr,1)
                        cachedList(i) = exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ChannelInfo(i))),'file');
                    end
                    channelIndex = get(Handles.channel,'Value');
                    if cachedList(channelIndex) % ignore unloaded channel
                        currentCode = get(Handles.sortCodes,'value');
                        if charNum==28
                            moveCode = min(currentCode)-1;
                            if moveCode<1, moveCode = 1; end
                        else
                            moveCode = max(currentCode)+1;
                            if moveCode > numel(get(Handles.sortCodes,'string'))
                                moveCode = numel(get(Handles.sortCodes,'string'));
                            end
                        end
                        set(Handles.sortCodes,'value',moveCode);
                        spikesort_gui('update');
                    end
                case 32 %spacebar
                    %Resample waveforms:
                    spikesort_gui('sample');
                case num2cell([48:57,127,96]) %the number keys (0-9) or the delete key %...or the '`' key (moves to 0) 
                    %Move the spikes to the indicated sort code:
                    if isempty(callbackEvent)||isempty(callbackEvent.Modifier)
                        switch charNum
                            case 96
                                match = find(ismember(get(Handles.toMove,'string'),'0'));
                                set(Handles.toMove,'value',match); %i.e., when '`' move to code 0
                            case 127
                                match = find(ismember(get(Handles.toMove,'string'),'255'));
                                set(Handles.toMove,'value',match); %i.e., move to sort code 255
                            otherwise
                                match = find(ismember(get(Handles.toMove,'string'),key));
                                if isempty(match)
                                    set(Handles.toMove,'value',numel(get(Handles.toMove,'string')));
                                else
                                    set(Handles.toMove,'value',match);
                                end
                        end
                        spikesort_gui('moveSelected'); %move the selected spikes to the sort code indicated
                    end
                case 105 %'i'
                    invertSpikeSelection;
                    set(Handles.history,'String',[get(Handles.history,'String'); {'Invert selection'}]);
                    set(Handles.history,'Value',length(get(Handles.history,'String')));
                    set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'invert',{}}]);
                    drawSpikes;
                otherwise
            end
        end
    case 'undo' 
        undoHistory;
    case 'selectAll' 
        sortCodeArray = cellfun(@str2doubleParen,get(Handles.sortCodes,'String'));
        p = find(ismember(WaveformInfo.Unit,sortCodeArray(WaveformInfo.sortCodes)));
        maxPoint =double(max(reshape(WaveformInfo.WaveformsAsShown(p,:),[],1)))+1; %greater than the greatest...
        minPoint = double(min(reshape(WaveformInfo.WaveformsAsShown(p,:),[],1)))-1; %lesser than the least...
        
        status = 'normal'; %status might as well be normal for 'select all';
        point1 = [WaveformInfo.x1,maxPoint];
        point2 = [WaveformInfo.x2,minPoint];
        selectSpikes(point1,point2,status);
        
        set(Handles.history,'String',[get(Handles.history,'String'); {['Select spikes for ' status ' between ' num2str(point1) ' and ' num2str(point2)]}]);
        set(Handles.history,'Value',length(get(Handles.history,'String')));
        set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'box',{point1,point2,status}}]);
        
        drawSpikes();
        drawRasters();
    case 'load'
        ChannelInfo = get(Handles.channel,'UserData');
        channelIndex = get(Handles.channel,'Value');
        ChannelNumber = ChannelInfo(channelIndex);
        %         load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',ChannelNumber)));
        if  strcmp(get(gcf,'selectiontype'),'open')
            if ~cachedList(channelIndex)
                msg = sprintf('Loading channel %i ...',ChannelNumber);
                set(Handles.notifications,'String',msg,guiVals.noteString,guiVals.noteVals(1,:));
                readSampleWaveforms(ChannelNumber,'off',ssDat.doTimer,ssDat.doSparse);
                load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ChannelNumber)),'Sparse');
                updateString = get(Handles.channel,'string');
                switch Sparse
                    case 1
                        updateString{channelIndex} = ['<HTML><FONT color=' guiVals.chanColor{2} '>' ChannelString{channelIndex} '</FONT></HTML>'];
                    case 2
                        updateString{channelIndex} = ['<HTML><FONT color=' guiVals.chanColor{3} '>' ChannelString{channelIndex} '</FONT></HTML>'];
                end
                set(Handles.channel,'string',updateString);
                fprintf('Channel %i has just been loaded\n',ChannelNumber);
                set(Handles.notifications,'String','Ready to sort!',guiVals.noteString,guiVals.noteVals(2,:));
            elseif cachedList(channelIndex)
                load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ChannelNumber)),'Sparse');
                if Sparse == 2 && ssDat.doSparse == false
                    msg = sprintf('Reloading channel %i ...',ChannelNumber);
                    set(Handles.notifications,'String',msg,guiVals.noteString,guiVals.noteVals(1,:));
                    readSampleWaveforms(ChannelNumber,'off',ssDat.doTimer,ssDat.doSparse);
                    updateString = get(Handles.channel,'string');
                    switch Sparse
                        case 1
                            updateString{channelIndex} = ['<HTML><FONT color=' guiVals.chanColor{2} '>' ChannelString{channelIndex} '</FONT></HTML>'];
                        case 2
                            updateString{channelIndex} = ['<HTML><FONT color=' guiVals.chanColor{3} '>' ChannelString{channelIndex} '</FONT></HTML>'];
                    end
                    set(Handles.channel,'string',updateString);
                    fprintf('Channel %i has been loaded again\n',ChannelNumber);
                    set(Handles.notifications,'String','Ready to sort!',guiVals.noteString,guiVals.noteVals(2,:));
                end
            end
            set(gcf,'selectiontype','normal');
            cachedList(channelIndex) = true;
        end
        if strcmp(get(gcf,'selectiontype'),'normal')
            if cachedList(channelIndex)
                loadWaveforms(ChannelNumber);
                %Figure out what the unit codes were in the original file (then we
                %will add/remove unit codes when we call performHistory
                possibleUnits = [];
                for i = find(cellfun(@ismember,repmat({ChannelNumber},size(FileInfo)),{FileInfo.ActiveChannels})) 
                    possibleUnits = unique([possibleUnits(:); ...
                        find(FileInfo(i).units{ChannelNumber})-1]); 
                end
                WaveformInfo.possibleUnits = [{255} {0} num2cell(setdiff(possibleUnits',[0 255]))]; 
                unitmap = WaveformInfo.possibleUnits;
                
                set(Handles.sortCodes,'String',unitmap,'Value',2:length(unitmap));
                unitmap{end+1} = 'new';
                set(Handles.toMove,'String',unitmap);
                
                WaveformInfo.sortCodes = get(Handles.sortCodes,'Value');
                if exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',ChannelNumber)),'file') == 2
                    load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',ChannelNumber)))
                    if ~isempty(String)
                        set(Handles.history,'UserData',UserData);
                        set(Handles.history,'String',String);
                        set(Handles.history,'Value',Value);
                        
                        performHistory(UserData);
                    else
                        set(Handles.history,'Value',0);
                        set(Handles.history,'UserData',[]);
                        set(Handles.history,'String',[]);
                    end
                end
                
                WaveformInfo.historyValue = -1;
                switch get(figHandle,'beingdeleted')
                    case 'off'
                        drawHists();
                        drawSpikes();
                        drawRasters();
                    otherwise
                        if ~isempty(timerfind('tag','freadTimer'))
                            set(timerfind('tag','freadTimer'),'stopfcn',''); %remove the stop function so we don't start new timers...
                            stop(timerfind('tag','freadTimer')); %stop any timers
                            delete(timerfind('tag','freadTimer')); %delete timers
                        end
                        manageTempFiles;
                end
                
                
            else
                Handles.history.String = [];
                Handles.sortCodes.String = [];
                Handles.toMove.String = [];
                drawnow;
                axes(Handles.ISINoise);
                cla;
                set(Handles.ISINoise,'XTickLabel',[]);
                set(Handles.ISINoise,'YTickLabel',[]);
                axes(Handles.ISI1);
                cla;
                set(Handles.ISI1,'XTickLabel',[]);
                set(Handles.ISI1,'YTickLabel',[]);
                axes(Handles.ISI2);
                cla;
                set(Handles.ISI2,'XTickLabel',[]);
                set(Handles.ISI2,'YTickLabel',[]);
                axes(Handles.ISI3);
                cla;
                set(Handles.ISI3,'XTickLabel',[]);
                set(Handles.ISI3,'YTickLabel',[]);
                axes(Handles.ISI4);
                cla;
                set(Handles.ISI4,'YTickLabel',[]);
                axes(Handles.rasterHandle);
                cla;
                axes(Handles.plotHandle);
                cla reset;
                text(0.5,0.5,{'This channel', 'has not been', 'loaded!'},'horizontalAlignment','center','Color','red','FontSize',72);
                if isfield(Handles,'pcaHandle')&&ishandle(Handles.pcaHandle)
                    delete(Handles.pcaHandle);
                end
                lineObjects = findobj(Handles.plotHandle, 'Type', 'line');
                if ~isempty(lineObjects)
                    delete(lineObjects);
                end
            end
        end
    case 'setMax'
        [~, maxY, ~] = ginput(1);
        set(Handles.maxMV,'String',maxY);
        spikesort_gui load;
    case 'setMin'
        [~, minY, ~] = ginput(1);
        set(Handles.minMV,'String',minY);
        spikesort_gui load;
    case 'load_plus'
        load_plus();
    case 'netsort'
        netSort(); 
        drawSpikes();
        spikesort_gui load;
    case 'mogsort'
        mogSort();
        drawSpikes();
        spikesort_gui load;
    case 'clear_history'
        set(Handles.history,'Value',0);
        set(Handles.history,'UserData',[]);
        set(Handles.history,'String',[]);
        loc = find(WaveformInfo.ChannelNumber == get(Handles.channel,'UserData'));
        s_all = get(Handles.channel,'String');
        s = s_all{loc};
        s = strrep(s,' *','');
        s_all{loc} = s;
        set(Handles.channel,'String',s_all);
        Value = 0;
        UserData = [];
        String = [];
        if exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits')),'file') == 7
            save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',ActiveChannelList(get(Handles.channel,'Value')))),'UserData','Value','String','-append');
        end
        spikesort_gui load;
        for i = 1:length(FileInfo)
            FileInfo(i).units{1,WaveformInfo.ChannelNumber} = zeros(256,1);
            FileInfo(i).units{1,WaveformInfo.ChannelNumber}(unique(double(WaveformInfo.Unit))+1) = 1;
        end
        spikesort_gui load;
    case 'sample'
        WaveformInfo.display = [];
        drawSpikes();
    case 'update'
        g =get(Handles.sortCodes,'String');
        if isempty(g)
            return;
        end
        WaveformInfo.sortCodes = get(Handles.sortCodes,'Value');
        drawSpikes();
        
        chanStrings = get(Handles.sortCodes,'String');
        chanString = '';
        for i = 1:length(WaveformInfo.sortCodes)
            chanString = [chanString num2str(str2doubleParen(chanStrings{WaveformInfo.sortCodes(i)})) ', ']; %#ok<AGROW>
        end
        set(Handles.history,'String',[get(Handles.history,'String'); {['Selected channels: ' chanString]}]);
        set(Handles.history,'Value',length(get(Handles.history,'String')));
        set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'channels',WaveformInfo.sortCodes}]);
    case 'moveSelected'
        code = get(Handles.toMove,'Value');
        
        moveSpikes(code);
        
        set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'move',code}]);
        
        drawSpikes();
        
        chanStrings = get(Handles.toMove,'String');
        set(Handles.history,'String',[get(Handles.history,'String'); {['Move selected spikes to ' chanStrings{code}]}]);
        set(Handles.history,'Value',length(get(Handles.history,'String')));
        UserData = get(Handles.history,'UserData');
        Value = get(Handles.history,'Value');
        String = get(Handles.history,'String');
        save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',ActiveChannelList(get(Handles.channel,'Value')))),'UserData','Value','String','-append');
        
        drawHists();
        drawRasters();
        
    case 'box'
        [point1, point2, status] = rubberbandbox3(Handles.plotHandle);
        
        switch (status)
            case 'normal'
                set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'box',{point1,point2,status}}]); 
            case 'extend'
                set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'box',{point1,point2,status}}]); 
            case 'alt'
                oldSelected = WaveformInfo.selected;
                if isempty(oldSelected)
                    set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'box',{point1,point2,status}}]); 
                else
                    % here we should flag that this is a "subtract" type of
                    % alternate selection (i.e., some spikes are selected and
                    % we're removing from that set)
                    set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'box',{point1,point2,'altRight'}}]);
                end
        end
        
        selectSpikes(point1,point2,status);
        
        set(Handles.history,'String',[get(Handles.history,'String'); {['Select spikes for ' status ' between ' num2str(point1) ' and ' num2str(point2)]}]);
        set(Handles.history,'Value',length(get(Handles.history,'String')));
        
        drawSpikes();
        drawRasters();
        
    case 'rasterLim'
        switch get(gcbo,'type')
            case 'image' % a click in the raster image
                [x, ~, button] = ginput(1);
                changed = true;
                if button == 1
                    restrictToSpikes(x,WaveformInfo.right);
                elseif button == 3
                    restrictToSpikes(WaveformInfo.left,x);
                elseif button == 8 %backspace to reset
                    resetWaveformBounds();
                else
                    changed = false;
                end
            case 'uimenu'
                switch get(gcbo,'label')
                    case 'Reset raster limits'
                        resetWaveformBounds();
                        changed = true;
                    otherwise
                        changed = false;
                end
            case 'uicontrol'
                switch get(gcbo,'string')
                    case 'Reset Raster Limits'
                        resetWaveformBounds();
                        changed = true;
                    otherwise
                        changed = false;
                end
            otherwise
                changed = false;
        end
        if changed
            drawSpikes();
            drawHists();
            drawRasters();
            
            set(Handles.history,'String',[get(Handles.history,'String'); {['Restrict to between ' num2str(WaveformInfo.left) ' and ' num2str(WaveformInfo.right)]}]);
            set(Handles.history,'Value',length(get(Handles.history,'String')));
            set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'restrict',{WaveformInfo.left,WaveformInfo.right}}]);
        end
    case 'threshold'
        [x,y]=ginput(1);
        
        setThreshold(x,y);
        
        drawSpikes();
        
        set(Handles.history,'String',[get(Handles.history,'String'); {['Set threshold to ' num2str(x) ', ' num2str(y)]}]);
        set(Handles.history,'Value',length(get(Handles.history,'String')));
        set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'set',{x,y}}]);
    case 'clear_threshold'
        clearThresholds();
        
        drawSpikes();
        
        set(Handles.history,'String',[get(Handles.history,'String'); {'Clear thresholds'}]);
        set(Handles.history,'Value',length(get(Handles.history,'String')));
        set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'clear',{}}]);
        
    case 'changeHistory'
        if strcmp(get(gcf,'SelectionType'),'open')
            WaveformInfo.historyValue = get(Handles.history,'Value');
            checkHistoryChange;
            UserData = get(Handles.history,'UserData');
            
            loadWaveforms(WaveformInfo.ChannelNumber);
            performHistory(UserData(1:WaveformInfo.historyValue,:));
            WaveformInfo.historyValue = -1;
            
            drawSpikes();
            drawHists();
            drawRasters();
            
        end
    case 'write'
        button = questdlg('Are you sure?',...
            'Write all files','Yes','Yes(and save sort)','No','No');
        
        %%% Initialize spikeSortModel struct 
        %spikeSortModel = struct();
        %spikeSortModel(1).allSnr = [];
        
        if strcmp(button,'Yes') || strcmp(button,'Yes(and save sort)')
            if strcmp(button,'Yes(and save sort)')
                [~,filename,~]=fileparts(FileInfo(1).filename);
                dftname = strcat('savedSort_',filename);
                filter = [WaveformInfo.sortFileLocation,filesep,'*.mat'];
                titlename = 'Save Sort';
                [file,path] = uiputfile(filter,titlename,dftname);
                if file == 0
                    return;
                end
                fname = strcat(path,file);
                saveSort(-1,fname);
            end
            spikesort_gui load
            
            ud = get(Handles.channel,'UserData');
            
            changedChannels = [];
            for i = 1:length(ud)
                % only if history is not empty
                if exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',ud(i))),'file') == 2
                    load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',ud(i))));
                    
                    if ~isempty(String) %#ok<NODEF>
                        changedChannels = [changedChannels ud(i)]; %#ok<AGROW>
                    end
                end
            end
            warning('off','MATLAB:hg:uicontrol:ListboxTopMustBeWithinStringRange'); %turn off this warning so that it doesn't blow up the command window
            
            set(Handles.notifications,'String','Writing files ...',guiVals.noteString,guiVals.noteVals(1,:));
            
            for i = 1:length(changedChannels)
                set(Handles.channel,'Value',find(ud == changedChannels(i)));
                possibleUnits = [];
                for j = find(cellfun(@ismember,repmat({changedChannels(i)},size(FileInfo)),{FileInfo.ActiveChannels})) 
                    possibleUnits = unique([possibleUnits(:); ...
                        find(FileInfo(j).units{changedChannels(i)})-1]);
                end
                
                WaveformInfo.possibleUnits = [{255} {0} num2cell(setdiff(possibleUnits(:)',[0 255]))]; 
                histFile = fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',changedChannels(i))); 
                
                Unit = [];
                Times = [];
                Waveforms = [];
                for k = find(cellfun(@ismember,repmat({changedChannels(i)},size(FileInfo)),{FileInfo.ActiveChannels})) 
                    
                    load(histFile); 
                    getWaveforms(changedChannels(i),k); % re-read everything from the NEV before writing
                    unitmap = WaveformInfo.possibleUnits;
                    
                    set(Handles.sortCodes,'String',unitmap,'Value',2:length(unitmap));
                    unitmap{end+1} = 'new'; %#ok<AGROW>
                    set(Handles.toMove,'String',unitmap);
                    WaveformInfo.sortCodes = get(Handles.sortCodes,'Value');
                    set(Handles.history,'Value',0);
                    set(Handles.history,'UserData',UserData);
                    set(Handles.history,'String',String);
                    
                    if true 
                        pcaSteps = find(ismember(UserData(:,1),{'pca'}));
                        if any(pcaSteps)
                            centeredWaves = bsxfun(@minus,double(WaveformInfo.Waveforms),origSampleMeans); 
                            components = centeredWaves*WaveformInfo.ComponentLoadings; 
                            components = mat2cell(components,size(components,1),ones(size(components,2),1));
                            for step = 1:numel(pcaSteps)
                                origScatterPoints = UserData{pcaSteps(step),2}{1};
                                compsToPlot = [];
                                try
                                    [~,compsToPlot(1)] = max(cellfun(@sum,cellfun(@ismember,repmat({origScatterPoints(:,1)},size(components)),components,'uni',0)));
                                    [~,compsToPlot(2)] = max(cellfun(@sum,cellfun(@ismember,repmat({origScatterPoints(:,2)},size(components)),components,'uni',0)));
                                    newScatterPoints = cell2mat(components(compsToPlot));
                                catch %#ok<CTCH>
                                    error('spikesort_sparse:badComps:Argh','Cannot match re-read waves to components used for sorting'); 
                                end
                                UserData{pcaSteps(step),2}{1} = newScatterPoints; %#ok<AGROW> 
                            end
                        end
                    end
                    
                    performHistory(UserData);
                    
                    Unit = vertcat(Unit,WaveformInfo.Unit); %#ok<AGROW>
                    Times = vertcat(Times,WaveformInfo.Times); %#ok<AGROW>
                    Waveforms = vertcat(Waveforms,WaveformInfo.Waveforms); %#ok<AGROW>
                    spikesort_write2(k);
                    
                    set(Handles.notifications,'String',sprintf('Writing files. Channel %d.',changedChannels(i)),guiVals.noteString,guiVals.noteVals(1,:));
                    
                end
                Sparse = 1;
                nSpikesToRead = 0;
                save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',changedChannels(i))),'Waveforms','Unit','Times','Sparse','nSpikesToRead','-append'); %update the ch file with the new (written) sort codes. (saves having to reread) -ACS 29Oct2014

                loadWaveforms(changedChannels(i));
                
                loc = find(WaveformInfo.ChannelNumber == get(Handles.channel,'UserData'));
                
                s_all = get(Handles.channel,'String');
                s = s_all{loc};
                s = strrep(s,' *','');
                
                s_all{loc} = s;
                set(Handles.channel,'String',s_all);
                String = [];
                UserData = [];
                Value = 0;
                
                save(histFile,'UserData','String','Value','filenames');
            end
            set(Handles.notifications,'String','Writing Complete!',guiVals.noteString,guiVals.noteVals(2,:));
            
            set(Handles.history,'Value',0);
            set(Handles.history,'UserData',[]);
            set(Handles.history,'String',[]);
            
            set(Handles.channel,'Value',1);
            
            if isfield(WaveformInfo,'written')
                WaveformInfo.written = true;
            end %mark the file as written
            
            % delete related tempsort
            currentNevSet = {FileInfo.filename};
            d = dir([WaveformInfo.sortFileLocation,filesep,'tempsort*']);
            if ~isempty(d)
                tempSortFiles = {d.name};
                tempSortFiles = cellfun(@fullfile,repmat({WaveformInfo.sortFileLocation},size(tempSortFiles)),tempSortFiles,'uniformoutput',0);
                matchFiles = false(size(tempSortFiles));
                for tsf = 1:numel(tempSortFiles)
                    load(tempSortFiles{tsf},'fileSet');
                    matchFiles(tsf) = all(ismember(fileSet,currentNevSet))&&all(ismember(currentNevSet,fileSet)); 
                end
                tempSort = tempSortFiles(matchFiles);
                if ~isempty(tempSort)
                    delete(tempSort{:});
                end
            end
            
            spikesort_gui load
        end
end

UserData = get(Handles.history,'UserData');
Value = get(Handles.history,'Value');
String = get(Handles.history,'String');
if exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits')),'file') == 7
    save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',ActiveChannelList(get(Handles.channel,'Value')))),'UserData','Value','String','-append');
end

updateString = get(Handles.channel,'String');
for i = 1:size(updateString,1)
    cachedList(i) = exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ActiveChannelList(i))),'file');
end
for i  = 1:size(ActiveChannelList,1)
    if exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',ActiveChannelList(i))),'file') == 2
        
        load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',ActiveChannelList(i))))
        if ~isempty(String)
            ChannelString{i} = [ChannelString{i} ' *'];
        end
    end
end
for j = 1:size(updateString,1)
    if cachedList(j)
        load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ActiveChannelList(j))),'Sparse');
        switch Sparse
            case 1
                updateString{j} = ['<HTML><FONT color=' guiVals.chanColor{2} '>' ChannelString{j} '</FONT></HTML>'];
            case 2
                updateString{j} = ['<HTML><FONT color=' guiVals.chanColor{3} '>' ChannelString{j} '</FONT></HTML>'];
        end
    else
        updateString{j} = ['<HTML><FONT color=' guiVals.chanColor{1} '>' ChannelString{j} '</FONT></HTML>'];
    end
end
set(Handles.channel,'string',updateString);
if numel(get(Handles.history,'string'))>0
    set(findobj('tag','undo'),'enable','on'); %if there's any history, enable undo if supported...
    if isfield(WaveformInfo,'written')
        WaveformInfo.written = false;
    end %once a change has been made, mark 'written' as false so the temp files will be saved. 
else
    set(findobj('tag','undo'),'enable','off');
end
set(figHandle,'Pointer','arrow');



function load_plus()
global Handles;
global FileInfo;
global WaveformInfo;
global ssDat;
global guiVals;

ChannelString = Handles.ChannelString;

ActiveChannelList = [];
for i = 1:length(FileInfo)
    ActiveChannelList = union(ActiveChannelList,FileInfo(i).ActiveChannels);
end
cachedList = false(size(ActiveChannelList));
for i = 1:numel(ActiveChannelList)
    cachedList(i) = exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ActiveChannelList(i))),'file');
end

sChannel = ActiveChannelList(1);
eChannel = ActiveChannelList(end);
msg = {sprintf('[%s:%s]',num2str(sChannel),num2str(eChannel))};
LoadAnswer = inputdlg('Channels you want to load:(matlab format)','Load Channels',1,msg);
if isempty(LoadAnswer) % cancel condition
    return
end
try
    ch = eval(LoadAnswer{1});
    if size(ch,1) > 1 && size(ch,2) >1
        uiwait(warndlg('Your input format is not correct!','Warning'));
        error('Your input format is not correct');
    end
    ch = unique(ch);
    if max(ch)>eChannel || min(ch)<sChannel
        uiwait(warndlg('The channels you want to load is unaccepted!','Warning'));
        error('The channels you want to load is unaccepted!');
    end
catch
    count = 0;error_count= 0;
    while count == error_count
        msg = {sprintf('[%s:%s]',num2str(sChannel),num2str(eChannel))};
        LoadAnswer = inputdlg('Channels you want to load:(matlab format)','Load Channels',1,msg);
        if isempty(LoadAnswer) % cancel condition
            return
        end
        try
            ch = eval(LoadAnswer{1});
            if size(ch,1) > 1 && size(ch,2) >1
                uiwait(warndlg('Your input format is not correct!','Warning'));
                error('Your input format is not correct');
            end
            ch = unique(ch);
            if max(ch)>eChannel || min(ch)<sChannel
                uiwait(warndlg('The channels you want to load is unaccepted!','Warning'));
                error('The channels you want to load is unaccepted!');
            end
        catch
            error_count = error_count+1;
        end
        count = count +1;
    end
end

set(Handles.notifications,'String','Start loading channels ...',guiVals.noteString,guiVals.noteVals(1,:));
for j = ch
    if ismember(j,ActiveChannelList(~cachedList))
        msg = sprintf('Loading channel %i ...',j);
        set(Handles.notifications,'String',msg,guiVals.noteString,guiVals.noteVals(1,:));
        readSampleWaveforms(j,'off',ssDat.doTimer,ssDat.doSparse);
        load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',j)),'Sparse');
        updateString = get(Handles.channel,'string');
        switch Sparse
            case 1
                updateString{(ActiveChannelList==j)} = ['<HTML><FONT color=' guiVals.chanColor{2} '>' ChannelString{(ActiveChannelList==j)} '</FONT></HTML>'];
            case 2
                updateString{(ActiveChannelList==j)} = ['<HTML><FONT color=' guiVals.chanColor{3} '>' ChannelString{(ActiveChannelList==j)} '</FONT></HTML>'];
        end
        set(Handles.channel,'string',updateString);
        dispMsg = sprintf('Channel %i has just been loaded',j);
    elseif ismember(j,ActiveChannelList(cachedList))
        load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',j)),'Sparse');
        if Sparse == 2 && ssDat.doSparse == false
            msg = sprintf('Reloading channel %i ...',j);
            set(Handles.notifications,'String',msg,guiVals.noteString,guiVals.noteVals(1,:));
            readSampleWaveforms(j,'off',ssDat.doTimer,ssDat.doSparse);
            updateString = get(Handles.channel,'string');
            switch Sparse
                case 1
                    updateString{(ActiveChannelList==j)} = ['<HTML><FONT color=' guiVals.chanColor{2} '>' ChannelString{(ActiveChannelList==j)} '</FONT></HTML>'];
                case 2
                    updateString{(ActiveChannelList==j)} = ['<HTML><FONT color=' guiVals.chanColor{3} '>' ChannelString{(ActiveChannelList==j)} '</FONT></HTML>'];
            end
            set(Handles.channel,'string',updateString);
            fprintf('Channel %i has been loaded again\n',j);
            set(Handles.notifications,'String','Ready to sort!',guiVals.noteString,guiVals.noteVals(2,:));
            dispMsg = sprintf('Channel %i has been loaded again',j);
        else
            dispMsg = sprintf('Channel %i has already been loaded',j);
        end
        
    else
        dispMsg = sprintf('Channel %i does not exist',j);
    end
    disp(dispMsg);
end
disp('Loading finished!');
spikesort_gui('load');
set(Handles.notifications,'String','Ready to sort!',guiVals.noteString,guiVals.noteVals(2,:));

function selectSpikes(point1, point2, status)
global Handles;
global WaveformInfo;

leftSide = max(0,min(point1(1),point2(1)));
rightSide = min(WaveformInfo.x2-.001,max(point1(1),point2(1)));
topSide = max(point1(2),point2(2));
bottomSide = min(point1(2),point2(2));

leftSide = leftSide*WaveformInfo.NumSamples/WaveformInfo.x2+1;
rightSide = rightSide*WaveformInfo.NumSamples/WaveformInfo.x2+1;

sortCodeArray = cellfun(@str2doubleParen,get(Handles.sortCodes,'String'));

p = find(ismember(WaveformInfo.Unit,sortCodeArray(WaveformInfo.sortCodes)));

within = zeros(size(WaveformInfo.Waveforms,1),floor(rightSide)-ceil(leftSide)+1);
within(p,:) = WaveformInfo.WaveformsAsShown(p,ceil(leftSide):floor(rightSide)) < topSide & WaveformInfo.WaveformsAsShown(p,ceil(leftSide):floor(rightSide)) > bottomSide;

within = sum(within,2)';
switch (status)
    case 'normal'
        within = intersect(p,find(within));
        WaveformInfo.selected = within;
        WaveformInfo.selected = intersect(WaveformInfo.selected,find(WaveformInfo.restrictedSet));
    case 'extend'
        within = intersect(p,find(within));
        within = intersect(within,find(WaveformInfo.restrictedSet));
        WaveformInfo.selected = union(WaveformInfo.selected,within);
    case 'alt'
        oldSelected = WaveformInfo.selected;
        
        if isempty(oldSelected)
            within = intersect(p,find(within==0));
            WaveformInfo.selected = within;
            WaveformInfo.selected = intersect(WaveformInfo.selected,find(WaveformInfo.restrictedSet));
        else
            % here we should flag that this is a "subtract" type of
            % alternate selection (i.e., some spikes are selected and
            % we're removing from that set)
            within = intersect(p,find(within));
            within = intersect(within,find(WaveformInfo.restrictedSet));
            WaveformInfo.selected = setdiff(WaveformInfo.selected,within);
        end
    case 'altRight' %"subtract" type of right click
        %to account for many small nev files sorts where no spikes are
        %selected and then a right click is made
        within = intersect(p,find(within));
        within = intersect(within,find(WaveformInfo.restrictedSet));
        WaveformInfo.selected = setdiff(WaveformInfo.selected,within);
end

function invertSpikeSelection
global Handles;
global WaveformInfo;

sortCodeArray = cellfun(@str2doubleParen,get(Handles.sortCodes,'String'));

p = find(ismember(WaveformInfo.Unit,sortCodeArray(WaveformInfo.sortCodes)));

WaveformInfo.selected = setdiff(p,WaveformInfo.selected);


function moveSpikes(code)
global Handles;
global WaveformInfo;

moveStrings = get(Handles.toMove,'String');
newCode = moveStrings{code};

if strcmp(newCode,'new')
    moveInts = cellfun(@str2double,moveStrings(1:end-1));
    
    possibilities = setdiff(0:255, moveInts);
    
    moveStrings{end} = num2str(possibilities(1));
    set(Handles.sortCodes,'String',moveStrings);
    set(Handles.sortCodes,'Value',[get(Handles.sortCodes,'Value') length(moveStrings)]);
    WaveformInfo.sortCodes = [WaveformInfo.sortCodes length(moveStrings)];
    
    moveStrings{end+1} = 'new';
    
    set(Handles.toMove,'String',moveStrings);
    newCode = possibilities(1);
else
    newCode = str2double(newCode);
end

WaveformInfo.Unit(WaveformInfo.selected) = newCode;

function performHistory(history)
global Handles;
global WaveformInfo;

for i = 1:size(history,1)
    set(Handles.history,'Value',i);
    switch(history{i,1})
        case 'move'
            moveSpikes(history{i,2});
        case 'box'
            selectSpikes(history{i,2}{1},history{i,2}{2},history{i,2}{3});
        case 'set'
            setThreshold(history{i,2}{1},history{i,2}{2});
        case 'clear'
            clearThresholds();
        case 'channels'
            set(Handles.sortCodes,'Value',history{i,2});
            WaveformInfo.sortCodes = history{i,2};
        case 'restrict'
            restrictToSpikes(history{i,2}{1},history{i,2}{2});
        case 'invert'
            invertSpikeSelection;
        case 'pca'
            selectPca(history{i,2}{1},history{i,2}{2});
        case 'deselect'
            deselectAll;
        case 'netsort'
            sortRecover;
        case 'mogsort'
            sortRecover;
    end
end


function clearThresholds()
global Handles;
global WaveformInfo;

sortCodeArray = cellfun(@str2doubleParen,get(Handles.sortCodes,'String'));

p = find(WaveformInfo.restrictedSet & ismember(WaveformInfo.Unit, ...
    sortCodeArray(WaveformInfo.sortCodes)));

WaveformInfo.Align(p) = 0;
WaveformInfo.WaveformsAsShown(p,:) = WaveformInfo.Waveforms(p,:);

function setThreshold(x,y)
global Handles;
global WaveformInfo;
global FileInfo;

x = ceil((x/FileInfo(1).PacketTime)*WaveformInfo.NumSamples);
if x<=0
    x=1;
elseif x>= WaveformInfo.NumSamples
    x = WaveformInfo.NumSamples;
end

sortCodeArray = cellfun(@str2doubleParen,get(Handles.sortCodes,'String'));

p = find(WaveformInfo.restrictedSet & ismember(WaveformInfo.Unit,sortCodeArray(WaveformInfo.sortCodes)));
if (y < 0)
    temp = y > WaveformInfo.Waveforms(p,x:end);
else
    temp = y < WaveformInfo.Waveforms(p,x:end);
end

temp = [zeros(length(p),x-1) temp];

for i=1:length(p)
    newAlign = find(temp(i,:));
    
    if ~isempty(newAlign)
        WaveformInfo.Align(p(i)) = newAlign(1)-FileInfo(1).ThresholdLocation;
        
        WaveformInfo.WaveformsAsShown(p(i),:) = zeros(1,WaveformInfo.NumSamples);
        if WaveformInfo.Align(p(i)) < 0
            WaveformInfo.WaveformsAsShown(p(i),-WaveformInfo.Align(p(i))+1:end) = WaveformInfo.Waveforms(p(i),1:WaveformInfo.Align(p(i))+end);
        else
            WaveformInfo.WaveformsAsShown(p(i),1:end-WaveformInfo.Align(p(i))) = WaveformInfo.Waveforms(p(i),WaveformInfo.Align(p(i))+1:end);
        end
    end
end

function getWaveforms(ChannelNumber, fileIndex)
global Handles;
global WaveformInfo;
global FileInfo;

set(Handles.toMove,'Value',1);
WaveformInfo.ChannelNumber = ChannelNumber;

PacketNumbers = FileInfo(fileIndex).PacketOrder == ChannelNumber;

WaveformInfo.Waveforms = [];
WaveformInfo.Unit = [];
WaveformInfo.Times = [];

load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ChannelNumber)),'Breaks','Unit');
WaveformInfo.Breaks = Breaks;

loc = FileInfo(fileIndex).HeaderSize + FileInfo(fileIndex).Locations(PacketNumbers);
[wav,tim,uni] = readWaveforms2(loc,WaveformInfo.NumSamples, ...
    FileInfo(fileIndex).filename);

wav = int16(double(wav) / 1000 * FileInfo(fileIndex).nVperBit(ChannelNumber));
WaveformInfo.Waveforms = wav';
WaveformInfo.Times = WaveformInfo.Breaks(fileIndex)+double(tim)/FileInfo(fileIndex).TimeResolutionTimeStamps*1000;
WaveformInfo.Unit = uni;

WaveformInfo.WaveformsAsShown = WaveformInfo.Waveforms;
WaveformInfo.Align = zeros(size(WaveformInfo.Waveforms,1),1);
WaveformInfo.selected = [];
[WaveformInfo.ComponentLoadings,WaveformInfo.Comp] = pca(double(WaveformInfo.Waveforms)); 
resetWaveformBounds();

function loadWaveforms(ChannelNumber)
global Handles;
global WaveformInfo;

set(Handles.toMove,'Value',1);
WaveformInfo.ChannelNumber = ChannelNumber;

load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ChannelNumber)));

WaveformInfo.Waveforms = Waveforms;
WaveformInfo.Unit = Unit;
WaveformInfo.Times = Times;
WaveformInfo.Breaks = Breaks;

WaveformInfo.WaveformsAsShown = WaveformInfo.Waveforms;
WaveformInfo.Align = zeros(size(WaveformInfo.Waveforms,1),1);
WaveformInfo.selected = [];

[WaveformInfo.ComponentLoadings,WaveformInfo.Comp] = pca(double(WaveformInfo.Waveforms)); 

resetWaveformBounds();

function drawSpikes()
global Handles;
global WaveformInfo;
global guiVals;

if WaveformInfo.noRedraw
    return;
else
    g = get(Handles.sortCodes,'String');
    if isempty(g)
        return;
    end
    sortCodeArray = cellfun(@str2doubleParen,g);
    
    sortCodes = get(Handles.sortCodes,'Value');
    
    p = find(ismember(WaveformInfo.Unit,sortCodeArray(sortCodes)) & WaveformInfo.restrictedSet);
    
    blockSize = str2double(get(Handles.blockSize,'String'));
    
    if blockSize ~= length(WaveformInfo.display)
        s = sum(WaveformInfo.restrictedSet);
        
        r = randperm(s);
        restrictedIndices = find(WaveformInfo.restrictedSet);
        WaveformInfo.display = restrictedIndices(r(1:min(blockSize,s)));
    end
    
    set(Handles.plotHandle,'Nextplot','replaceChildren','FontSize',10);
    Handles.plot = [];
    
    if (get(Handles.holdTheLine,'Value') == 0)
        y1 = double(min(min(WaveformInfo.Waveforms(p,:))));
        y2 = double(max(max(WaveformInfo.Waveforms(p,:))));
    else
        y1 = double(min(min(WaveformInfo.Waveforms)));
        y2 = double(max(max(WaveformInfo.Waveforms)));
    end
    
    if get(Handles.holdTheLine,'Value') == 1
        maxMV = str2double(get(Handles.maxMV,'String'));
        minMV = str2double(get(Handles.minMV,'String'));
    else
        maxMV = NaN;
        minMV = NaN;
    end
    
    if ~isnan(maxMV) && ~isnan(minMV) && maxMV >= minMV
        y2 = min(y2,maxMV);
        y1 = max(y1,minMV);
    elseif ~isnan(maxMV) && isnan(minMV)
        y2 = min(y2,maxMV);
    elseif isnan(maxMV) && ~isnan(minMV) && minMV < 0
        y1 = max(y1,minMV);
    end
    if ~isempty(WaveformInfo.selected)
        sel = intersect(WaveformInfo.display,intersect(p,WaveformInfo.selected));
        unsel=intersect(WaveformInfo.display,setdiff(p,sel));
        if ~isempty(sel)
            im = genSpikeMapColor(WaveformInfo.WaveformsAsShown(sel,:), ...
                WaveformInfo.Unit(sel),400,400,y1,y2,guiVals.colors,max(1,round(log10(length(sel)/10))));
        else
            im = zeros(400,400,3);
        end
        
        if ~isempty(unsel)
            im2 = genSpikeMapColor(WaveformInfo.WaveformsAsShown(unsel,:), WaveformInfo.Unit(unsel),400,400,y1,y2,guiVals.colors,max(1,round(log10(length(unsel)/10))))/2;
            
        else
            im2 = zeros(400,400,3);
        end
        im(im==0) = im2(im==0);
    else
        p = intersect(WaveformInfo.display,p);
        if ~isempty(p)
            im = genSpikeMapColor(WaveformInfo.WaveformsAsShown(p,:), ...
                WaveformInfo.Unit(p),800,800,y1,y2,guiVals.colors,max(1,round(log10(length(p)/10))));
        else
            im = zeros(800,800,3);
        end
    end
    
    if sum(sum(sum(abs(im)))) == 0
        y1 = -1;
        y2 = 1;
    end
    
    i = imagesc([WaveformInfo.x1 WaveformInfo.x2],[y1 y2],1-im,'parent',Handles.plotHandle);
    set(i,'ButtonDownFcn','spikesort_gui box');
    set(gcf,'WindowButtonUpFcn','uiresume(gcf)');
          
    text((WaveformInfo.x2-WaveformInfo.x1)*.85+WaveformInfo.x1,(y2-y1)*.95+y1,num2str(length(WaveformInfo.selected)),'parent',Handles.plotHandle);
    
    xlim(Handles.plotHandle,[WaveformInfo.x1 WaveformInfo.x2]);
    ylim(Handles.plotHandle,[y1 y2]);
    drawPca();
    drawThreshold();
end
%%

function drawThreshold()
global Handles;
global WaveformInfo;
global FileInfo

if WaveformInfo.noRedraw
    return;
elseif isfield(Handles,'showThreshold')
    switch get(Handles.showThreshold,'checked')
        case 'off'
            lineObjects = findobj(Handles.plotHandle, 'Type', 'line');
            if ~isempty(lineObjects)
                delete(lineObjects);
            end
        case 'on'
            axes(Handles.plotHandle);
            xtick = FileInfo(1).ThresholdLocation/FileInfo(1).NumSamples*FileInfo(1).PacketTime;
            xLim = get(Handles.plotHandle,'XLim');
            yLim = get(Handles.plotHandle,'YLim');
            
            line([xtick xtick],yLim,'LineStyle','-.','Color','[0.5 0.5 0.5]');
            
            ytickLow = FileInfo(1).LowThresh(get(Handles.channel,'Value'));
            ytickHigh = FileInfo(1).HighThresh(get(Handles.channel,'Value'));
            if ytickLow >= yLim(1) && ytickLow <=yLim(2)
                line(xLim,[ytickLow ytickLow],'LineStyle','-.','Color','[0.5 0.5 0.5]');
            end
            if ytickHigh >= yLim(1) && ytickHigh <=yLim(2)
                line(xLim,[ytickHigh ytickHigh],'LineStyle','-.','Color','[0.5 0.5 0.5]');
            end
    end
end

function drawPca()
global Handles;
global WaveformInfo;
global guiVals;

if WaveformInfo.noRedraw
    return;
elseif isfield(Handles,'showPca')
    switch get(Handles.showPca,'checked')
        case 'off'
            if isfield(Handles,'pcaHandle')&&ishandle(Handles.pcaHandle)
                delete(Handles.pcaHandle);
            end
        case 'on'
            sortCodeArray = cellfun(@str2doubleParen,get(Handles.sortCodes,'String'));
            
            sortCodes = get(Handles.sortCodes,'Value');
            p = find(ismember(WaveformInfo.Unit,sortCodeArray(sortCodes)) & WaveformInfo.restrictedSet);
            
            blockSize = str2double(get(Handles.blockSize,'String'));
            if blockSize ~= length(WaveformInfo.display)
                s = sum(WaveformInfo.restrictedSet);
                
                r = randperm(s);
                restrictedIndices = find(WaveformInfo.restrictedSet);
                WaveformInfo.display = restrictedIndices(r(1:min(blockSize,s)));
            end
            
            %Creation of the PCA figure window:
            if isfield(Handles,'pcaHandle')&&ishandle(Handles.pcaHandle), delete(Handles.pcaHandle); end %clear this and remake it so it stays on top...
            plotPosition = get(Handles.plotHandle,'position');
            
            pcaDimensions = [0.33 0.33];
            Handles.pcaHandle = uipanel('parent',get(Handles.plotHandle,'parent'),...
                'units','normalized',...
                'position',[plotPosition(1)+plotPosition(3)-pcaDimensions(1),plotPosition(2),pcaDimensions]);
            pcaAxes = axes('buttondownfcn',@lassoPca,'parent',Handles.pcaHandle);
            
            compSelectMenu = uicontextmenu('Parent',ancestor(get(Handles.plotHandle,'parent'), 'figure' ));
            for c = 1:5 %make first five components plottable
                uimenu(compSelectMenu,'label',sprintf('Component %d',c),'callback',@componentSelectionCallback);
            end
            
            set(pcaAxes,'Nextplot','replaceChildren','FontSize',10);
            Handles.plot = [];
            
            compsToPlot = get(Handles.showPca,'userdata');
            if size(WaveformInfo.Comp,2)<size(compsToPlot,2)
                return;
            end
            comp = WaveformInfo.Comp(:,compsToPlot);
            set(pcaAxes,'userdata',comp);
            set(ancestor(pcaAxes,'figure'),'renderer','opengl');
            if ~isempty(WaveformInfo.selected)
                sel = intersect(WaveformInfo.display,intersect(p,WaveformInfo.selected));
                unsel=intersect(WaveformInfo.display,setdiff(p,sel));
                scatter(pcaAxes,comp(sel,1),comp(sel,2),[],1-guiVals.colors(double(WaveformInfo.Unit(sel,:)+1),:),'.'); hold on;
                scatter(pcaAxes,comp(unsel,1),comp(unsel,2),[],(1-guiVals.colors(double(WaveformInfo.Unit(unsel,:)+1),:)/2),'.'); hold off;
            else
                p = intersect(p,WaveformInfo.display);
                scatter(pcaAxes,comp(p,1),comp(p,2),[],1-guiVals.colors(double(WaveformInfo.Unit(p,:)+1),:),'.');
            end
            currentXlim = get(pcaAxes,'xlim'); currentYlim = get(pcaAxes,'ylim');
            xlim(pcaAxes,currentXlim+[-10 10]); ylim(pcaAxes,currentYlim+[-10 10]); %add a little bit of margin to the plot area.
            axis(pcaAxes,'equal');
            title(pcaAxes,'Principal components scatterplot');
            xlabel(pcaAxes,sprintf('Component %d (right-click to change)',compsToPlot(1)));
            ylabel(pcaAxes,sprintf('Component %d (right-click to change)',compsToPlot(2)));
            set(get(pcaAxes,'xlabel'),'uicontextmenu',compSelectMenu);
            set(get(pcaAxes,'ylabel'),'uicontextmenu',compSelectMenu);
    end
end

%%
function drawHists()
global Handles;
global WaveformInfo;
global guiVals;

if WaveformInfo.noRedraw
    return;
else
    histLength = 50;
    
    isiHandles = [Handles.ISINoise Handles.ISI1 Handles.ISI2 Handles.ISI3 Handles.ISI4];
    
    snr = zeros(256,1);
    for i = 1:length(WaveformInfo.possibleUnits)
        snr(WaveformInfo.possibleUnits{i}+1) = getSNR(WaveformInfo.Waveforms(WaveformInfo.Unit == WaveformInfo.possibleUnits{i}));
    end
    
    waves = cell(5,1);
    waves{1} = WaveformInfo.Unit == 0 | WaveformInfo.Unit==255;
    waves{2} = WaveformInfo.Unit == 1;
    waves{3} = WaveformInfo.Unit == 2;
    waves{4} = WaveformInfo.Unit == 3;
    waves{5} = WaveformInfo.Unit == 4;
    
    col = [256 2 3 4 5];
    
    for i = 1:5
        waves{i} = waves{i} & WaveformInfo.restrictedSet;
        
        d = diff(WaveformInfo.Times(waves{i}));
        snr = length(find(waves{i}));
        
        cla(isiHandles(i),'reset');
        hist(isiHandles(i),d(d<histLength),(1:histLength)-.5);
        set(findobj(isiHandles(i),'type','patch'),'FaceColor',1-guiVals.colors(col(i),:)); 
        axis(isiHandles(i),'tight');
        xlim(isiHandles(i),[0 histLength]);
        
        x = get(isiHandles(i),'xlim');
        x = (x(2)-x(1))*.75+x(1);
        y = get(isiHandles(i),'ylim');
        y = (y(2)-y(1))*.88+y(1);
        
        text(x,y,num2str(snr),'parent',isiHandles(i));
    end
    g =length(get(Handles.sortCodes,'String'));
    if g <= 5
        for i = g:5
            cla(isiHandles(i));
            set(isiHandles(i),'YTickLabel',[]);
        end
    end
    set(isiHandles(1:4),'XTickLabel',[]);
    addSNRValues();
end

function addSNRValues()
global Handles;
global WaveformInfo;

codes = get(Handles.sortCodes,'String');

for i = 1:length(codes)
    code = str2doubleParen(codes{i});
    
    snr = getSNR(WaveformInfo.Waveforms(WaveformInfo.Unit == code,:));
    
    codes{i} = [num2str(code) ' (' num2str(snr,'%0.02f') ')'];
end

set(Handles.sortCodes,'String',codes);

function drawRasters()
global Handles;
global WaveformInfo;

if WaveformInfo.noRedraw
    return;
else
    possible = cellfun(@str2doubleParen,get(Handles.sortCodes,'String'));
    im = makeRasterImage();
    maxTime = max(WaveformInfo.Times);
    
    if ~isempty(WaveformInfo.selected)
        imSel = makeRasterImage(WaveformInfo.selected);
        
        im2 = zeros(size(im,1)*3,size(im,2),3);
        
        for i = 1:3
            im2(1:3:end,:,i) = imSel(:,:,i);
            im2(2:3:end,:,i) = im(:,:,i);
            im2(3:3:end,:,i) = imSel(:,:,i);
        end
        im = im2;
        
        cla(Handles.rasterHandle);
        
        i = imagesc([0 maxTime/1000],1:3*length(possible),flip(1-im,1),'parent',Handles.rasterHandle);
        set(Handles.rasterHandle,'YTick',2:3:3*length(possible));
        
        pos = 3*length(possible);
    else
        cla(Handles.rasterHandle);
        
        i = imagesc([0 maxTime/1000],1:length(possible),flip(1-im,1),'parent',Handles.rasterHandle);
        
        set(Handles.rasterHandle,'YTick',1:length(possible));
        
        pos = length(possible);
    end
    
    set(i,'ButtonDownFcn','spikesort_gui rasterLim');
    
    line([WaveformInfo.left WaveformInfo.left],[.5 pos+.5],'parent',Handles.rasterHandle,'LineWidth',0.75);
    line([WaveformInfo.right WaveformInfo.right],[.5 pos+.5],'parent',Handles.rasterHandle,'LineWidth',0.75);
    
    for i = 2:length(WaveformInfo.Breaks)
        l = line([WaveformInfo.Breaks(i) WaveformInfo.Breaks(i)]/1000,[.5 length(possible)+.5],'parent',Handles.rasterHandle);
        set(l,'Color','k');
    end
    
    axis(Handles.rasterHandle,'tight');
end

function im = makeRasterImage(spikeSubset)
global WaveformInfo;
global Handles;
global guiVals;

possible = cellfun(@str2doubleParen,get(Handles.sortCodes,'String'));

times = cell(1,length(possible));
for i = 1:length(possible)
    if nargin == 0
        t = WaveformInfo.Unit==possible(i);
    else
        t = intersect(spikeSubset,find(WaveformInfo.Unit==possible(i)));
    end
    times{i} = WaveformInfo.Times(t);
end

maxTime = max(WaveformInfo.Times);

rows = zeros(length(times),WaveformInfo.rasterRes);
for i = 1:length(times)
    rows(i,:) = hist(round(times{i}/(maxTime/WaveformInfo.rasterRes)),(1:WaveformInfo.rasterRes)-.5);
end

im = zeros(size(rows,1),size(rows,2),3);
for i = 1:size(rows,1)
    im(i,:,:) = permute(guiVals.colors(possible(i)+1,:)'*rows(i,:),[3 2 1]);
end

im = (im ./ max(rows(:))).^.25;

function restrictToSpikes(x1, x2)
global WaveformInfo;

if (x1 < x2)
    WaveformInfo.left = x1;
    WaveformInfo.right = x2;
end

machinePrecisionAdjustmentFactor = 0.1; %in milliseconds - for 30000Hz sampling, the real precision error is 1.81e-12 msec 
%add small adjustment factor to avoid weird rounding errors keeping the first or last spike from being in the restricted set
WaveformInfo.restrictedSet = WaveformInfo.Times <= WaveformInfo.right*1000+machinePrecisionAdjustmentFactor & WaveformInfo.Times >= WaveformInfo.left*1000-machinePrecisionAdjustmentFactor; 
WaveformInfo.display = [];

function resetWaveformBounds()
global WaveformInfo;

restrictToSpikes(0,max(WaveformInfo.Times)/1000);

function checkHistoryChange()
global WaveformInfo;
global Handles;

if WaveformInfo.historyValue ~= -1
    UserData = get(Handles.history,'UserData');
    String = get(Handles.history,'String');
    set(Handles.history,'UserData',UserData(1:WaveformInfo.historyValue,:));
    set(Handles.history,'String',String(1:WaveformInfo.historyValue));
end

function s = str2doubleParen(s)
index = strfind(s,' (');

if isempty(index)
    s = str2double(s);
else
    s = str2double(s(1:index));
end

function undoHistory
global Handles
if numel(get(Handles.history,'string'))>1
    set(Handles.history,'Value',get(Handles.history,'Value')-1);
    set(gcf,'selectiontype','open'); %needed to get the callback to evaluate
    spikesort_gui('changeHistory');
elseif numel(get(Handles.history,'string'))==1
    spikesort_gui('clear_history');
end

function lassoPca(src,~)
global Handles
switch get(ancestor(src,'figure'),'selectiontype')
    case 'normal' %left click
        try
            axesList = findobj(gcf,'type','axes');
            [polygonPoints(:,1),polygonPoints(:,2)] = getline(src,'closed');
            scatterPoints = get(gca,'userdata');
            selectPca(scatterPoints,polygonPoints);
            set(Handles.history,'String',[get(Handles.history,'String'); {'Select spikes in PCA space'}]);
            set(Handles.history,'Value',length(get(Handles.history,'String')));
            set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'pca',{scatterPoints,polygonPoints}}]);
        catch ME
            switch ME.identifier
                case 'images:getline:interruptedMouseSelection'
                    delete(setdiff(findobj(gcf,'type','axes'),axesList));
                    %ignore this error (means someone clicked outside the
                    %figure window while the polygon was 'on'...
                otherwise
                    delete(setdiff(findobj(gcf,'type','axes'),axesList));
                    display(ME.identifier);
                    rethrow(ME);
            end
        end
    case 'alt' %right click -clear selection
        deselectAll;
        set(Handles.history,'String',[get(Handles.history,'String'); {'Deselect all'}]);
        set(Handles.history,'Value',length(get(Handles.history,'String')));
        set(Handles.history,'UserData',[get(Handles.history,'UserData'); {'deselect',{[]}}]);
end
drawSpikes();
drawRasters();

function selectPca(scatterPoints,polygonPoints)
global Handles WaveformInfo
sortCodeArray = cellfun(@str2doubleParen,get(Handles.sortCodes,'String'));
p = find(ismember(WaveformInfo.Unit,sortCodeArray(WaveformInfo.sortCodes)));
within = inpolygon(scatterPoints(:,1),scatterPoints(:,2),polygonPoints(:,1),polygonPoints(:,2));
within = intersect(p,find(within));
WaveformInfo.selected = within;
WaveformInfo.selected = intersect(WaveformInfo.selected,find(WaveformInfo.restrictedSet));

function deselectAll
global WaveformInfo
WaveformInfo.selected = [];

function sortRecover
global Handles
global WaveformInfo
global FileInfo
chanList = get(Handles.channel,'UserData');
load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',chanList(get(Handles.channel,'Value')))),'sortcodes');
WaveformInfo.Unit = sortcodes;
possibleUnits = unique(sortcodes);

WaveformInfo.possibleUnits = [{255} {0} num2cell(setdiff(possibleUnits',[0 255]))];
unitmap = WaveformInfo.possibleUnits;

set(Handles.sortCodes,'String',unitmap,'Value',2:length(unitmap));
unitmap{end+1} = 'new';
set(Handles.toMove,'String',unitmap);

WaveformInfo.sortCodes = get(Handles.sortCodes,'Value');
for i = 1:length(FileInfo)
    FileInfo(i).units{1,WaveformInfo.ChannelNumber} = zeros(256,1);
    FileInfo(i).units{1,WaveformInfo.ChannelNumber}(unique(double(WaveformInfo.Unit))+1) = 1;
end

function componentSelectionCallback(src,~)
pnt = mean(get(gca,'currentpoint'));
left = min(get(gca,'xlim')); bottom = min(get(gca,'ylim'));
if pnt(1)<left
    selectionAxis = 2;
elseif pnt(2)<bottom
    selectionAxis = 1;
end
axisLabels = {'xlabel','ylabel'};
set(get(gca,axisLabels{selectionAxis}),'string',get(src,'label'));
ph = findobj(ancestor(src,'figure'),'label','Show PCA scatter');
compSel = get(ph,'userdata');
compSel(selectionAxis) = str2double(cell2mat(regexp(get(src,'label'),'\d+','match')));
set(ph,'userdata',compSel);
spikesort_gui drawpca;
spikesort_gui drawthreshold;

function netSort(~,~)
global WaveformInfo
global Handles
global guiVals
global FileInfo
ChannelString = Handles.ChannelString;
ActiveChannelList = get(Handles.channel,'UserData');
cachedList = false(size(ActiveChannelList));
for i = 1:size(ActiveChannelList,1)
    cachedList(i) = exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ActiveChannelList(i))),'file');
end
[ch,gamma,sc] = netsortOption();
if isempty(ch) || isempty(gamma) || isempty(sc)
    return;
end
for i = ch
    if ismember(i,ActiveChannelList)
        set(Handles.channel,'Value',find(ActiveChannelList==i));
        spikesort_gui load;
        if ismember(i,ActiveChannelList(~cachedList))
            msg = sprintf('Load and sorting channel %i ...',i);
            set(Handles.notifications,'String',msg,guiVals.noteString,guiVals.noteVals(1,:));drawnow;
            readSampleWaveforms(i,'off',false,false);
            updateString = get(Handles.channel,'string');
            updateString{ActiveChannelList==i} = ['<HTML><FONT color=' guiVals.chanColor{2} '>' ChannelString{ActiveChannelList==i} '</FONT></HTML>'];
            set(Handles.channel,'string',updateString);
            load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',i)),'Waveforms','Unit');
            try
                if isfield(WaveformInfo,'NeuralNet')
                    Unit = nasnet(Waveforms','gm',gamma,'sortCode',sc,'net',WaveformInfo.NeuralNet);
                else
                    Unit = nasnet(Waveforms','gm',gamma,'sortCode',sc);
                end
            catch ME
                fprintf('Channel %i can not be sorted\n',i);
                warndlg(ME.message,'Warning');
                set(Handles.notifications,'String','Neural net sort failed',guiVals.noteString,guiVals.noteVals(2,:));
                return;
            end
            WaveformInfo.Unit = Unit;
            sortcodes = WaveformInfo.Unit;
            save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',i)),'sortcodes','-append');
            fprintf('Channel %i has been loaded and sorted\n',i);
            set(Handles.notifications,'String','Load and neural net sort finished!',guiVals.noteString,guiVals.noteVals(2,:));
        elseif ismember(i,ActiveChannelList(cachedList))
            load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',i)),'Sparse');
            switch Sparse
                case 1
                    msg = sprintf('Sorting channel %i ...',i);
                    set(Handles.notifications,'String',msg,guiVals.noteString,guiVals.noteVals(1,:));drawnow;
                    load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',i)),'Waveforms','Unit');
                    try
                        if isfield(WaveformInfo,'NeuralNet')
                            Unit = nasnet(Waveforms','gm',gamma,'sortCode',sc,'net',WaveformInfo.NeuralNet);
                        else
                            Unit = nasnet(Waveforms','gm',gamma,'sortCode',sc);
                        end
                    catch ME
                        fprintf('Channel %i can not be sorted\n',i);
                        warndlg(ME.message,'Warning');
                        set(Handles.notifications,'String','Neural net sort failed',guiVals.noteString,guiVals.noteVals(2,:));
                        return;
                    end
                    WaveformInfo.Unit = Unit;
                    sortcodes = WaveformInfo.Unit;
                    save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',i)),'sortcodes','-append');
                    fprintf('Channel %i has been sorted\n',i);
                    set(Handles.notifications,'String','Neural net sort finished!',guiVals.noteString,guiVals.noteVals(2,:));
                case 2
                    msg = sprintf('Reload and sorting channel %i ...',i);
                    set(Handles.notifications,'String',msg,guiVals.noteString,guiVals.noteVals(1,:));drawnow;
                    readSampleWaveforms(i,'off',false,false);
                    updateString = get(Handles.channel,'string');
                    updateString{ActiveChannelList==i} = ['<HTML><FONT color=' guiVals.chanColor{2} '>' ChannelString{ActiveChannelList==i} '</FONT></HTML>'];
                    set(Handles.channel,'string',updateString);
                    load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',i)),'Waveforms','Unit');
                    try
                        if isfield(WaveformInfo,'NeuralNet')
                            Unit = nasnet(Waveforms','gm',gamma,'sortCode',sc,'net',WaveformInfo.NeuralNet);
                        else
                            Unit = nasnet(Waveforms','gm',gamma,'sortCode',sc);
                        end
                    catch ME
                        fprintf('Channel %i can not be sorted\n',i);
                        warndlg(ME.message,'Warning');
                        set(Handles.notifications,'String','Neural net sort failed',guiVals.noteString,guiVals.noteVals(2,:));
                        return;
                    end
                    WaveformInfo.Unit = Unit;
                    sortcodes = WaveformInfo.Unit;
                    save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',i)),'sortcodes','-append');
                    fprintf('Channel %i has been reloaded and sorted\n',i);
                    set(Handles.notifications,'String','Reload and neural net sort finished!',guiVals.noteString,guiVals.noteVals(2,:));
            end
        end
        
        possibleUnits = unique(sortcodes);

        WaveformInfo.possibleUnits = [{255} {0} num2cell(setdiff(possibleUnits',[0 255]))];
        unitmap = WaveformInfo.possibleUnits;
        
        set(Handles.sortCodes,'String',unitmap,'Value',2:length(unitmap));
        unitmap{end+1} = 'new';
        set(Handles.toMove,'String',unitmap);
        
        WaveformInfo.sortCodes = get(Handles.sortCodes,'Value');
        for j = 1:length(FileInfo)
            FileInfo(j).units{1,i} = zeros(256,1);
            FileInfo(j).units{1,i}(unique(double(WaveformInfo.Unit))+1) = 1;
        end
        set(Handles.history,'String',{'Sort - neural net sort'});
        set(Handles.history,'Value',length(get(Handles.history,'String')));
        set(Handles.history,'UserData',{'netsort',{[]}});
        UserData = get(Handles.history,'UserData');
        Value = get(Handles.history,'Value');
        String = get(Handles.history,'String');
        save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',i)),'String','Value','UserData','-append');
    end
end

function mogSort(~,~)
global WaveformInfo
global Handles
global guiVals
global FileInfo
ChannelString = Handles.ChannelString;
ActiveChannelList = get(Handles.channel,'UserData');
cachedList = false(size(ActiveChannelList));
for i = 1:size(ActiveChannelList,1)
    cachedList(i) = exist(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',ActiveChannelList(i))),'file');
end
[ch,scignore] = mogsortOption();
if isempty(ch)
    return;
end
for i = ch
    if ismember(i,ActiveChannelList)
        set(Handles.channel,'Value',find(ActiveChannelList==i));
        spikesort_gui load;
        if ismember(i,ActiveChannelList(~cachedList))
            msg = sprintf('Load and sorting channel %i ...',i);
            set(Handles.notifications,'String',msg,guiVals.noteString,guiVals.noteVals(1,:));drawnow;
            readSampleWaveforms(i,'off',false,false);
            updateString = get(Handles.channel,'string');
            updateString{ActiveChannelList==i} = ['<HTML><FONT color=' guiVals.chanColor{2} '>' ChannelString{ActiveChannelList==i} '</FONT></HTML>'];
            set(Handles.channel,'string',updateString);
            load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',i)),'Waveforms','Unit');
            try
                mogopt = mogSortOptions;
                mogopt.sortcodeToIgnore = scignore;
                mogopt.WaveformInfoUnits = WaveformInfo.Unit;
                Unit = mogSorter(Waveforms',mogopt);
                assert(~isempty(Unit),sprintf('Error:Channel %i can not been sorted\n',i));
            catch ME
                fprintf('Channel %i can not be sorted\n',i);
                warndlg(ME.message,'Warning');
                set(Handles.notifications,'String','MoG sort failed',guiVals.noteString,guiVals.noteVals(2,:));
                return;
            end
            WaveformInfo.Unit = Unit;
            sortcodes = WaveformInfo.Unit;
            save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',i)),'sortcodes','-append');
            fprintf('Channel %i has been loaded and sorted\n',i);
            set(Handles.notifications,'String','Load and MoG sort finished!',guiVals.noteString,guiVals.noteVals(2,:));
        elseif ismember(i,ActiveChannelList(cachedList))
            load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',i)),'Sparse');
            switch Sparse
                case 1
                    msg = sprintf('Sorting channel %i with mogSort ...',i);
                    set(Handles.notifications,'String',msg,guiVals.noteString,guiVals.noteVals(1,:));drawnow;
                    load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',i)),'Waveforms','Unit');
                    try
                        mogopt = mogSortOptions;
                        mogopt.sortcodeToIgnore = scignore;
                        mogopt.WaveformInfoUnits = WaveformInfo.Unit;
                        Unit = mogSorter(Waveforms',mogopt);
                        assert(~isempty(Unit),sprintf('Error:Channel %i can not been sorted\n',i));
                    catch ME
                        fprintf('Channel %i can not be sorted\n',i);
                        warndlg(ME.message,'Warning');
                        set(Handles.notifications,'String','MoG sort failed',guiVals.noteString,guiVals.noteVals(2,:));
                        return;
                    end
                    WaveformInfo.Unit = Unit;
                    sortcodes = WaveformInfo.Unit;
                    save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',i)),'sortcodes','-append');
                    fprintf('Channel %i has been sorted\n',i);
                    set(Handles.notifications,'String','MoG sort finished!',guiVals.noteString,guiVals.noteVals(2,:));
                case 2
                    msg = sprintf('Reload and sorting channel %i ...',i);
                    set(Handles.notifications,'String',msg,guiVals.noteString,guiVals.noteVals(1,:));drawnow;
                    readSampleWaveforms(i,'off',false,false);
                    updateString = get(Handles.channel,'string');
                    updateString{ActiveChannelList==i} = ['<HTML><FONT color=' guiVals.chanColor{2} '>' ChannelString{ActiveChannelList==i} '</FONT></HTML>'];
                    set(Handles.channel,'string',updateString);
                    load(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/ch%i.mat',i)),'Waveforms','Unit');
                    try
                        mogopt = mogSortOptions;
                        mogopt.sortcodeToIgnore = scignore;
                        mogopt.WaveformInfoUnits = WaveformInfo.Unit;
                        Unit = mogSorter(Waveforms',mogopt);
                        assert(~isempty(Unit),sprintf('Error:Channel %i can not been sorted\n',i));
                    catch ME
                        fprintf('Channel %i can not be sorted\n',i);
                        warndlg(ME.message,'Warning');
                        set(Handles.notifications,'String','MoG sort failed',guiVals.noteString,guiVals.noteVals(2,:));
                        return;
                    end
                    WaveformInfo.Unit = Unit;
                    sortcodes = WaveformInfo.Unit;
                    save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',i)),'sortcodes','-append');
                    fprintf('Channel %i has been reloaded and sorted\n',i);
                    set(Handles.notifications,'String','Reload and MoG sort finished!',guiVals.noteString,guiVals.noteVals(2,:));
            end
        end
        
        possibleUnits = unique(sortcodes);
        
        WaveformInfo.possibleUnits = [{255} {0} num2cell(setdiff(possibleUnits',[0 255]))];
        unitmap = WaveformInfo.possibleUnits;
        
        set(Handles.sortCodes,'String',unitmap,'Value',2:length(unitmap));
        unitmap{end+1} = 'new';
        set(Handles.toMove,'String',unitmap);
        
        WaveformInfo.sortCodes = get(Handles.sortCodes,'Value');
        for j = 1:length(FileInfo)
            FileInfo(j).units{1,i} = zeros(256,1);
            FileInfo(j).units{1,i}(unique(double(WaveformInfo.Unit))+1) = 1;
        end
        set(Handles.history,'String',{'Sort - MoG sort'});
        set(Handles.history,'Value',length(get(Handles.history,'String')));
        set(Handles.history,'UserData',{'mogsort',{[]}});
        UserData = get(Handles.history,'UserData');
        Value = get(Handles.history,'Value');
        String = get(Handles.history,'String');
        save(fullfile(WaveformInfo.sortFileLocation,sprintf('spikesortunits/hist%i.mat',i)),'String','Value','UserData','-append');
    end
end

function [ch,gamma,sc] = netsortOption()
global Handles

ActiveChannelList = get(Handles.channel,'UserData');
chanNum = ActiveChannelList(get(Handles.channel,'Value'));

sChannel = ActiveChannelList(1);
eChannel = ActiveChannelList(end);
msg = {sprintf('[%s]',num2str(chanNum)),'[0 0.2 1]','[255 0]'};
SortAnswer = inputdlg({'Enter the channels:','gamma:','sort code'},'NASNET',1,msg);
if isempty(SortAnswer) % cancel condition
    ch = [];gamma = [];sc= [];
    return
end
try
    try
        ch = eval(SortAnswer{1});
        assert(size(ch,1) == 1 || size(ch,2) ==1,'Error:Your input format is not correct');
        ch = unique(ch);
        assert(max(ch)<=eChannel && min(ch)>=sChannel,'Error:The channels you want to sort is unaccepted!');
    catch
        uiwait(warndlg('The channel you entered is not valid!','Warning'));
        error('The channel you entered is not valid!');
    end
    try
        gamma = eval(SortAnswer{2});
        assert(size(gamma,1)==1 || size(gamma,2)==1,'Error:gamma cannot be a matrix');
        assert(isempty(find(gamma<0, 1)) && isempty(find(gamma>1, 1)),'Error:gamma is not valid');
        gamma = gamma(:);
        assert(size(gamma,1)>=2,'Error:length of gamma has to be bigger or equal than 2');
        assert(isempty(find(sort(gamma) ~= gamma, 1)),'Error: gamma has to be increasing');
    catch
        uiwait(warndlg('The gamma you entered is not valid!','Warning'));
        error('The gamma you entered is not valid!');
    end
    try
        sc = eval(SortAnswer{3});
        assert(size(sc,1) == 1 || size(sc,2) ==1,'Error:sort code cannot be a matrix');
        sc = sc(:);
        assert(sum(ismember(sc,0:255))==size(sc,1),'Error:sort code is not valid');
        assert(size(gamma,1)-size(sc,1) == 1,'Error:gamma and sort code do not match');
    catch
        uiwait(warndlg('The sort code you entered is not valid!','Warning'));
        error('The sort code you entered is not valid!');
    end
catch
    count = 0;error_count= 0;
    while count == error_count
        msg = {sprintf('[%s]',num2str(chanNum)),'[0 0.2 1]','[255 0]'};
        SortAnswer = inputdlg({'Enter the channels:','gamma:','sort code'},'NASNET',1,msg);
        if isempty(SortAnswer) % cancel condition
            ch = [];gamma = [];sc= [];
            return
        end
        try
            try
                ch = eval(SortAnswer{1});
                assert(size(ch,1) == 1 || size(ch,2) ==1,'Error:Your input format is not correct');
                ch = unique(ch);
                assert(max(ch)<=eChannel && min(ch)>=sChannel,'Error:The channels you want to sort is unaccepted!');
            catch
                uiwait(warndlg('The channel you entered is not valid!','Warning'));
                error('The channel you entered is not valid!');
            end
            try
                gamma = eval(SortAnswer{2});
                assert(size(gamma,1)==1 || size(gamma,2)==1,'Error:gamma cannot be a matrix');
                assert(isempty(find(gamma<0, 1)) && isempty(find(gamma>1, 1)),'Error:gamma is not valid');
                gamma = gamma(:);
                assert(size(gamma,1)>=2,'Error:length of gamma has to be bigger or equal than 2');
                assert(isempty(find(sort(gamma) ~= gamma, 1)),'Error: gamma has to be increasing');
            catch
                uiwait(warndlg('The gamma you entered is not valid!','Warning'));
                error('The gamma you entered is not valid!');
            end
            try
                sc = eval(SortAnswer{3});
                assert(size(sc,1) == 1 || size(sc,2) ==1,'Error:sort code cannot be a matrix');
                sc = sc(:);
                assert(sum(ismember(sc,0:255))==size(sc,1),'Error:sort code is not valid');
                assert(size(gamma,1)-size(sc,1) == 1,'Error:gamma and sort code do not match');
            catch
                uiwait(warndlg('The sort code you entered is not valid!','Warning'));
                error('The sort code you entered is not valid!');
            end
        catch
            error_count = error_count+1;
        end
        count = count +1;
    end
end

function [ch,scignore] = mogsortOption()
global Handles

ActiveChannelList = get(Handles.channel,'UserData');
chanNum = ActiveChannelList(get(Handles.channel,'Value'));

sChannel = ActiveChannelList(1);
eChannel = ActiveChannelList(end);
msg = {sprintf('[%s]',num2str(chanNum)),'[255]'};
SortAnswer = inputdlg({'Enter the channels:','Sort codes to ignore:'},'MoG',1,msg);
if isempty(SortAnswer) % cancel condition
    ch = [];
    scignore = [];
    return
end
try
    try
        ch = eval(SortAnswer{1});
        assert(size(ch,1) == 1 || size(ch,2) ==1,'Error:Your input format is not correct');
        ch = unique(ch);
        assert(max(ch)<=eChannel && min(ch)>=sChannel,'Error:The channels you want to sort are invalid!');
    catch
        uiwait(warndlg('The channel you entered is not valid!','Warning'));
        error('The channel you entered is not valid!');
    end
    try
        if isempty(SortAnswer{2})
            scignore = [];
        else
            scignore = eval(SortAnswer{2});
        end
        assert(isempty(scignore) || size(scignore,1) == 1 || size(scignore,2) == 1,'Error: sort codes to ignore cannot be a matrix');
        scignore = scignore(:);
        assert(sum(ismember(scignore,0:255))==size(scignore,1),'Error:sort code is not valid');
    catch
        uiwait(warndlg('The sort code to ignore you entered is not valid!','Warning'));
        error('The sort code to ignore you entered is not valid!');
    end
catch
    count = 0;error_count= 0;
    while count == error_count
        msg = {sprintf('[%s]',num2str(chanNum)),''};
        SortAnswer = inputdlg({'Enter the channels:','Sort codes to ignore:'},'MoG',1,msg);
        if isempty(SortAnswer) % cancel condition
            ch = [];scignore = [];
            return
        end
        try
            try
                ch = eval(SortAnswer{1});
                assert(size(ch,1) == 1 || size(ch,2) ==1,'Error:Your input format is not correct');
                ch = unique(ch);
                assert(max(ch)<=eChannel && min(ch)>=sChannel,'Error:The channels you want to sort are invalid!');
            catch
                uiwait(warndlg('The channel you entered is not valid!','Warning'));
                error('The channel you entered is not valid!');
            end
            try
                if isempty(SortAnswer{2})
                    scignore = [];
                else
                    scignore = eval(SortAnswer{2});
                end
                assert(isempty(scignore) || size(scignore,1) == 1 || size(scignore,2) == 1,'Error: sort codes to ignore cannot be a matrix');
                scignore = scignore(:);
                assert(sum(ismember(scignore,0:255))==size(scignore,1),'Error:sort code is not valid');
            catch
                uiwait(warndlg('The sort code to ignore you entered is not valid!','Warning'));
                error('The sort code to ignore you entered is not valid!');
            end
        catch
            error_count = error_count+1;
        end
        count = count +1;
    end
end