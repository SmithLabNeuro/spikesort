function cleanSpikesortCache

path = getpref('spikesort','cacheDirectory');

temp = dir(fullfile([path,filesep,'tempsort*']));
if length(temp) == 1
    fprintf('There is 1 tempfile in Cache,its name is:\n%s',temp(1).name);
elseif length(temp)>1
    fprintf('There are %d tempfiles in Cache,their names are:\n',length(temp));
    for i = 1:length(temp)
        disp(temp(i).name)
    end
else
    disp('No tempsort founded in Cache.');
end

ss = dir(fullfile([path,filesep,'savedSort*']));
if length(ss) == 1
    fprintf('There is 1 savedSort in Cache,its name is:\n%s',ss(1).name);
elseif length(ss)>1
    fprintf('There are %d savedSort in Cache,their names are:\n',length(ss));
    for i = 1:length(ss)
        disp(ss(i).name)
    end
else
    disp('No savedSort founded in Cache.');
end

if exist(fullfile([path,filesep,'spikesortunits']),'dir') == 7
    units = dir(fullfile([path,filesep,'spikesortunits']));
    units([units.isdir]) = [];
    if ~isempty(units)
        disp('There are files left in spikesortunits folder.');
    else
        disp('spikesortunits folder is empty.');
    end
else
    disp('spikesortunits folder not founder in Cache.');
end

x = input('Do you want to clean the Cache? (Enter y if you want)\n','s');
if x == 'y'
    allFiles = dir(path);
    allFiles([allFiles.isdir]) = [];
    for k = 1:length(allFiles)
        delete(fullfile([path,filesep,allFiles(k).name]));
    end
    if exist(fullfile([path,filesep,'spikesortunits']),'dir') == 7
        rmdir(fullfile([path,filesep,'spikesortunits']));
    end
end

