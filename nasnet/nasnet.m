function sortcodes = nasnet(inputWave,varargin)
% input could be nev file or waveforms

p = inputParser;

p.addOptional('gm',[0 0.2 1],@isnumeric);
p.addOptional('net','UberNet_N50_L1_',@ischar);
p.addOptional('sortCode',[255 0],@isnumeric);
%p.addOptional('sortCodeToKeep',[],@isnumeric);

p.parse(varargin{:});
netName = p.Results.net;
sortCode = p.Results.sortCode;
gamma = p.Results.gm;
%sortCodeToKeep = p.Results.sortCodeToKeep;

% gamma/sortCode needs to be vector
assert(size(gamma,1)==1 || size(gamma,2)==1,'Error:gamma cannot be a matrix');
assert(isempty(find(gamma<0, 1)) && isempty(find(gamma>1, 1)),'Error:gamma is not valid');
gamma = gamma(:);
assert(size(gamma,1)>=2,'Error:length of gamma has to be bigger or equal than 2');
assert(isempty(find(sort(gamma) ~= gamma, 1)),'Error: gamma has to be increasing');

assert(size(sortCode,1) == 1 || size(sortCode,2) ==1,'Error:sort code cannot be a matrix');
sortCode = sortCode(:);
assert(sum(ismember(sortCode,0:255))==size(sortCode,1),'Error:sort code is not valid');

assert(size(gamma,1)-size(sortCode,1) == 1,'Error:gamma and sort code do not match');


nSamples = 52;
%% load file to classify
if ischar(inputWave)
    [spikes,waves] = read_nev(inputWave);
    if size(waves{1},1)~=nSamples
        error('Number of samples in waveforms does not match to the net');
    end
    %for digital info channels, create waveform of 1s with the label 256
    if any(spikes(:,1)==0)
        waves(spikes(:,1)==0) = {ones(nSamples,1,'int16')};
    end
    
    waveforms = [waves{:}]; %convert from a cell to an array
    clear waves;
else % waveform format
    if size(inputWave,1)~=nSamples
        error('Number of samples in waveforms does not match to the net');
    end
    waveforms = inputWave;
end

%% load network params
w1 = load(strcat(netName,'w1'));
b1 = load(strcat(netName,'b1'));
w2 = load(strcat(netName,'w2'));
b2 = load(strcat(netName,'b2'));

%% classify waveforms
nwaves = length(waveforms);
n_per_it = 1000; %number of waves per iteration
counter = 0;
nend = 0;

net_labels = zeros(1,nwaves);

while nend~=nwaves
    nstart = 1 + counter*n_per_it;
    nend = nstart + n_per_it - 1;
    
    if nend>nwaves %at the end of the file
        nend = nwaves;
    end
    
    n_loop = length(nstart:nend);
    
    % generate classifications
    wave_in = double(waveforms(:,nstart:nend))';
    
    %*****Layer 1******
    layer1_raw = wave_in*w1 + repmat(b1',n_loop,1);
    
    %***ReLU activation****
    %layer1_out = log(1+exp(layer1_raw)); %faster ReLU
    layer1_out = max(0,layer1_raw); %more accurate ReLU
    % layer1_out = layer1_raw; layer1_out(layer1_raw<=0) = 0; %alternate to using max but still slower than log method
    
    %***Layer 2*******
    layer2_raw = layer1_out*w2 + repmat(b2',n_loop,1);
    
    %***Softmax******
    layer2_out = 1./(1+exp(-1*(layer2_raw))); %apply sigmoid
    
    net_labels(nstart:nend) = layer2_out;
    counter = counter + 1;
end

%% sort NEV file
spikelogical = true(nwaves,1); %spike logical list
if ischar(inputWave)
    diglist = find(spikes(:,1)==0);
    spikelogical(diglist)=false;
end
spikelabel = nan(nwaves,1);
for i = 1:length(sortCode)
    idx = find(net_labels>=gamma(i) & net_labels<gamma(i+1));
    spikelabel(idx) = sortCode(i);
end
if ischar(inputWave)
    moveToSortCode(inputWave,spikelogical,spikelabel);
end
sortcodes = uint8(spikelabel);
