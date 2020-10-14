%Test how long the network takes to classify 20 ms bins of real data to
%simulate how much time classifying waveforms with the network might add to
%a BCI pipeline.

%load network paramters
net_name = 'Issar_et_al_2020_'; %name of network
nasnet.w1 = load(strcat(net_name,'w_hidden'));
nasnet.b1 = load(strcat(net_name,'b_hidden'));
nasnet.w2 = load(strcat(net_name,'w_output'));
nasnet.b2 = load(strcat(net_name,'b_output'));

% load 5 minutes of waveform data
load('sampleData.mat');
disp('Loaded data...'); pause(1); 
%segment waveform into 20 ms bins
tbin = 20/1000; % bin length (seconds)
endtime = spikes(end,3); %last waveform's time stamp
starttime = spikes(1,3); %first waveform's time stamp

wavebin = cell(1,floor((endtime-starttime)/tbin)-1);

tstart = starttime;
tend = tstart+tbin;
counter = 1;
while((tend+tbin)<endtime)
    binind = find(spikes(:,3)>=tstart & spikes(:,3)<tend);
    wavebin{counter} = waveforms(binind,:);
    counter = counter + 1;
    tstart = tstart+tbin;
    tend = tend+tbin;
end

clearvars -except wavebin nasnet
disp('Starting timing analysis...');

gamma = 0.20;
nbins = length(wavebin);
runTime = nan(1,nbins);
 
for ii = 1:nbins
tic
%call nasnet
labels = simOnlineNASNet(wavebin{ii}, gamma, nasnet);
runTime(ii) = toc;
end
disp('End of timing analysis...');
disp(['Average classification time for 20ms spike bins: ',num2str(mean(runTime)*1000),' +/- ',num2str(std(runTime)*1000),' ms']);
