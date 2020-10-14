function labels = simOnlineNASNet(waveforms, gamma, nasnet)
% This function classifies waveforms using a trained neural
% network and outputs a binary list indicating whether the network assigned
% each waveform to the spike (1) or noise (0) class.  
% INPUTS: 
%        waveforms: DOUBLE array of N waveforms (N rows)
%        gamma: minimum P(spike) value for a waveform to be classified as a spike
%        nasnet: structure that contains trained network's weights and biases
% OUTPUTS:
%        labels: 1xN array assigning each input waveform to the spike (1)
%                or noise(0) class


%% run waveforms through the network
nwaves = size(waveforms,1);

%*****Layer 1******
layer1_raw = waveforms*nasnet.w1 + repmat(nasnet.b1',nwaves,1);

%***ReLU activation****
%layer1_out = log(1+exp(layer1_raw)); %faster ReLU
layer1_out = max(0,layer1_raw); %more accurate ReLU
% layer1_out = layer1_raw; layer1_out(layer1_raw<=0) = 0; %alternate to using max but still slower than log method

%***Layer 2*******
layer2_raw = layer1_out*nasnet.w2 + repmat(nasnet.b2',nwaves,1);

%***Sigmoid******
layer2_out = 1./(1+exp(-1*(layer2_raw))); %apply sigmoid

net_labels = layer2_out; 


%% classify waveforms
%gamma is the sort stringency between 0 and 1. if you want a
%more lenient sort (i.e. allows for more noise), then choose a smaller gamma

labels = zeros(size(net_labels)); %spike classification
labels(net_labels>=gamma) = 1;


