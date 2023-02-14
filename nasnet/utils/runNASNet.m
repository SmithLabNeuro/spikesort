function [slabel,spikes,net_labels] = runNASNet(filenameOrNev,gamma,varargin)
%
% This script classifies waveforms using a trained neural network
% (see Issar et al (2020)). The file can either be an NEV or a .mat file 
% containing a variable named 'waveforms'
%
%INPUTS:
%       filenameOrNev- string filename of a .nev file OR a .mat file OR a
%           cell array containing the Nx3 nev data at the first index and
%           the Nx52 waveforms in the second index.
%                 IF it's a .mat file, MUST include a variable called
%                 "waveforms", waveforms is an Nx52 array, where N is the
%                 number of waveforms, and 52 is the number of samples in
%                 each waveform* (see NOTES below)
%       gamma- minimum P(spike) value for a waveform to be classified as a
%              spike (between 0 and 1). If you want a more lenient sort 
%              (i.e. allows for more noise), then choose a smaller gamma.
%
%OUTPUTS:
%       slabel- list of labels for each waveform (0 for noise, 1 for spike)
%       spikes- waveform information (channel, sortcode, time)
%
% OPTIONAL ARGUMENTS:
% 'channels'    - read all is default, or if a number list is specified 
%                 only those will be read
% 'writelabels' - false is default. If true, the classification labels will
%                 be written as sort codes into the nev file
% 'netname'     - string of network name (eg. 'UberNet_N50_L1', default). 
%                 Different networks are stored in the folder netFolder
%                 (defined below). All four NASNet output files must be
%                 available and saved as the network name followed by
%                 _w_hidden, _w_output, _b_hidden, _b_output.
% 'netFolder'   - string of the folder where the network is stored; can be
%                 an absolute or relative path. DEFAULT: '../networks'
% 'labelSpikesAsWithWrite' - controls whether spikes output has labels 0/1
%               for bad/good waveforms (DEFAULT), or whether it outputs
%               255/1 for bad/good waveforms, as happens when the NEV is
%               rewritten (if 'writelabels' is true)

%NOTES:
%****The number of samples in each waveform must match the number of
%    samples in the waveforms the network was trained on. The Issar et al
%    (2020) network was trained on waveforms with 52 samples.
%
% 02/2020: -Added channel selection functionality, as in read_nev
%          -Added clause to forbid overwritting digital codes (channel 0)
%           and uStim events (channels>512) to nev files.
%          -Writing into the nev file is optional now.

%%
% 512 is the highest available number of spike channels 
% (see Trellis NEV Spec manual)
maxspikech = 512;

% addpath(genpath('../../'))
% optional input arguments
p = inputParser;
p.addOptional('channels',[],@isnumeric);
p.addOptional('writelabels',false,@islogical);
p.addOptional('netname','UberNet_N50_L1',@ischar);
p.addOptional('netFolder','../networks',@ischar);
p.addOptional('labelSpikesAsWithWrite', false, @islogical);
p.parse(varargin{:});

ch          = p.Results.channels;
writelabels = p.Results.writelabels;
netname     = p.Results.netname;
netFolder     = p.Results.netFolder;
labelSpikesAsWithWrite = p.Results.labelSpikesAsWithWrite;

%% load trained network
% cd ../
try
    w1 = load(fullfile(netFolder,[netname,'_w_hidden']));
    b1 = load(fullfile(netFolder,[netname,'_b_hidden']));
    w2 = load(fullfile(netFolder,[netname,'_w_output']));
    b2 = load(fullfile(netFolder,[netname,'_b_output']));
catch
    error('The network you named does not exist or the files were not named appropriately.')
end

%% load file to classify

if ischar(filenameOrNev)
    [~,~,ext] = fileparts(filenameOrNev);

    % cd(datapath)
    switch ext
        case '.nev'
            if exist('readNEV', 'file') && isempty(ch) 
                [spikes,waveforms] = readNEV(filenameOrNev);
                waveforms = waveforms';
            else
                % if readNEV not on path or channels specified, use slower read_nev in repository
                addpath(genpath('../../'))
                [spikes,waveforms] = read_nev(filenameOrNev,'channels',ch);
                % this is necessary because read_nev outputs waves as a
                % cell array of waves, and the cell is empty if it's not
                % associated with a spike
                if any(spikes(:,1)==0)
                    %These are digital codes. There are no waveforms to classify for
                    %these indices so create placeholder in waveform list so indexing works
                    %for moveToSortCode.
                    waveforms(spikes(:,1)==0) = {ones(52,1)};
                end
                waveforms = [waveforms{:}]'; % convert from a cell to an array
            end
            
            
        case '.mat'
            if writelabels, error('can only write labels to nev if a .nev filename was passed.'); end
            disp('loading data...')
            load(filenameOrNev);
            if ~exist('waveforms'), error('waveforms must be stored in a variable named "waveforms".'); end
            clear filenameOrNev;
        otherwise
            error('file must be a .nev or Nx52 .mat');
    end
elseif iscell(filenameOrNev)
    if writelabels, error('can only write labels to nev if a .nev filename was passed.'); end
    spikes = filenameOrNev{1};
    waveforms = filenameOrNev{2}';
    clear filenameOrNev;
else
    error('input must be a .nev or Nx52 .mat or a cell with spikes and waves preloaded');
end

%check that the waveform size is appropriate for the network
if size(waveforms,2)~=size(w1,1), error(['This network can only classify waveforms that are ' num2str(size(w1,1)),' samples long']); end

%% classify waveforms
nwaves = size(waveforms,1);
n_per_it = 1000; %number of waves per iteration
counter = 0;
nend = 0;

net_labels = zeros(1,nwaves);

disp(['applying neural net classifier ' netname])
while nend~=nwaves
    nstart = 1 + counter*n_per_it;
    nend = nstart + n_per_it - 1;
    
    if nend>nwaves %at the end of the file
        nend = nwaves;
    end
    
    n_loop = length(nstart:nend);
    
    % generate classifications
    wave_in = double(waveforms(nstart:nend,:));
    
    %*****Layer 1******
    layer1_raw = wave_in*w1 + repmat(b1',n_loop,1);
    
    %***ReLU activation****
    %layer1_out = log(1+exp(layer1_raw)); %faster ReLU
    layer1_out = max(0,layer1_raw); %more accurate ReLU
    
    %***Layer 2*******
    layer2_raw = layer1_out*w2 + repmat(b2',n_loop,1);
    
    %***Sigmoid******
    layer2_out = 1./(1+exp(-1*(layer2_raw))); %apply sigmoid
    
    net_labels(nstart:nend) = layer2_out;
    counter = counter + 1;
end

%% assign waveforms spike/noise labels
slabel = zeros(size(net_labels)); %spike classification
slabel(net_labels>=gamma) = 1;

if labelSpikesAsWithWrite
    spikes(spikes(:,1)~=0,2) = slabel(spikes(:,1)~=0) + ~slabel(spikes(:,1)~=0)*255;
else
    spikes(spikes(:,1)~=0,2) = slabel(spikes(:,1)~=0);
end

%If applicable, modify NEV file
if writelabels && strcmp(ext,'.nev')

    % spikes and noise labels
    
    % move spikes to sort code 1 and noise to sort code 255
    sortcodes = slabel*1 + ~slabel*255;
    
    % which waveforms to overwrite
    spikesidx = ones(size(slabel));
    
    % set write=false for digital codes 
    % do the same for special channels which do not contain spiking data,
    % for example channels for uStim
    % (although moveToSortCode should already protect from doing that)
    spikesidx(spikes(:,1)==0)         = 0;
    sortcodes(spikes(:,1)==0)         = 0;
    spikesidx(spikes(:,1)>maxspikech) = 0;
    sortcodes(spikes(:,1)>maxspikech) = 0;
    
    moveToSortCode(filenameOrNev,spikesidx,sortcodes,'channels',ch);

end

