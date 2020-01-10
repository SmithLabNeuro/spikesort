% This script classifies spikes from an nev file using a trained neural
% network and updates the NEV file with the new sort codes

% NOTE: this script will modify the NEV file you load!

%% load file to classify
filename = '/Users/smithlab/Desktop/data spikesort test/Wa171129_s185a_dirmem_bci_0002.nev';

[spikes,waves] = read_nev(filename); 

%for digital info channels, create waveform of 1s with the label 256
if any(spikes(:,1)==0)
    waves(spikes(:,1)==0) = {ones(52,1,'int16')};
end

waveforms = [waves{:}]; %convert from a cell to an array
clear waves;
%% load network params
net_name = 'Wa_epoch_1_'; %name of network
%Wa_epoch_1_ was trained on two Wakko files from June 2017

w1 = load(strcat(net_name,'w1'));
b1 = load(strcat(net_name,'b1'));
w2 = load(strcat(net_name,'w2'));
b2 = load(strcat(net_name,'b2'));

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
layer2_out = 1./(1+exp(-1*(layer2_raw(:,1)-layer2_raw(:,2)))); %apply softmax

net_labels(nstart:nend) = layer2_out; 
counter = counter + 1;
end

%% sort NEV file
gamma = 0.2; %this is the sort stringency between 0 and 1. if you want a
%more lenient sort (i.e. allows for more noise), then choose a smaller gamma

slabel = zeros(size(net_labels)); %spike classification
slabel(net_labels>=gamma) = 1;

slabel(spikes(:,1)==0) = 0; %set logical to 0 for digital codes so we don't change them

moveToSortCode(filename,slabel,1); %moves spikes to sort code 1

%move noise to sort code 0 (this is only necessary if file had
%previously been sorted and has non-zero sort codes)
nlabel = ~slabel;
nlabel(spikes(:,1)==0) = 0; %again, don't touch digital codes

moveToSortCode(filename, nlabel, 0);

