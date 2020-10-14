% Wrapper for using the network to classify waveforms with sample data.
filename = 'sampleData.mat'; %filename that contains the variable "waveforms", 
%                             waveforms is an Nx52 array, where N is the number
%                             of waveforms, and 52 is the number of samples in
%                             each waveform.
gamma = 0.2; %minimum P(spike) value for a waveform to be considered a spike
netName = 'Issar_et_al_2020'; %name of network
                              %the 4 outputs of the trained NASNet must
                              %exist. For this example they would be
                              %Issar_et_al_2020_w_hidden
                              %Issar_et_al_2020_b_hidden
                              %Issar_et_al_2020_w_output
                              %Issar_et_al_2020_b_output
slabel = runNASNet(filename,gamma,netName); %classify waveforms

%plot a selection of the labeled waveforms
load(filename);
spikes = waveforms(logical(slabel),:);
noise = waveforms(~logical(slabel),:);

figure;
h1=plot(noise(randi(size(noise,1),50),:)','k'); hold on;
h2=plot(spikes(randi(size(spikes,1),50),:)','g');
ylim([-500,500]); xlim([1,52]); 
ylabel('uV'); legend([h1(1),h2(1)],'noise','spike');