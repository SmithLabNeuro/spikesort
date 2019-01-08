function manageTempFiles
    %MANAGETEMPFILES Subfunction to handle temporary spikesort files.
    
    global WaveformInfo
    
    %delete channel files here.
    tempSortFiles = dir(fullfile(WaveformInfo.sortFileLocation,'spikesortunits'));
    tempSortFiles([tempSortFiles.isdir]) = []; %strip off directories
    tempSortFiles = {tempSortFiles.name};
    tempSortFiles = cellfun(@strcat,repmat({[WaveformInfo.sortFileLocation,filesep,'spikesortunits',filesep]},size(tempSortFiles)),tempSortFiles,'uniformoutput',0);
    if ~isempty(tempSortFiles)
        if ~WaveformInfo.written
            %NEVs have not been written yet:
            if isfield(WaveformInfo,'tempSortName')
                tempfile = WaveformInfo.tempSortName; %keep using the same temp file
            else
                [~,tempfile,~] = fileparts(tempname);
                tempfile = fullfile(WaveformInfo.sortFileLocation,strcat('tempsort_',tempfile));
            end
            saveSort(-1,tempfile); %<---- need to handle the temporary file names here...
            delete(tempSortFiles{:});
        else
            delete(tempSortFiles{:});
            if isfield(WaveformInfo,'tempSortName')
                if exist(WaveformInfo.tempSortName,'file')
                    delete(WaveformInfo.tempSortName); %remove the temp sort file
                end
            end
        end
        
    end

    
end

