function [ pSpike ] = classifySpikes(filename)

% This function classifies spikes from an nev file using a trained neural
% network and returns the spike classifications

    %% load network params
    net_name = 'OldMonkey_Late_UberNet_'; %name of network
    %Wa_epoch_1_ was trained on two Wakko files from June 2017

    w1 = load(strcat(net_name,'w1'));
    b1 = load(strcat(net_name,'b1'));
    w2 = load(strcat(net_name,'w2'));
    b2 = load(strcat(net_name,'b2'));

    %% classify waveforms
    n_per_it = 1000000; %number of waves per iteration
    counter = 0; 
    keepGoing = true;

    nPackets = getNumPackets(filename);
    increment = ceil(nPackets*.05);
    nextthresh = increment;
    net_labels = zeros(1,floor(nPackets));

    fprintf('   0.0 percent complete\n');
    while keepGoing
        tic;
        %% which block of waveforms to read in
        nstart = 1 + counter*n_per_it;
        nend = nstart + n_per_it - 1;
        
        %% load waveforms to classify
        [spikes,waveforms] = read_nev_block(filename,nstart,nend); 
        if size(waveforms,2)<n_per_it % reached end of file
            keepGoing=false;
        end
        
        %for digital info channels, create waveform of 1s with the label 256
        digChanIdx = spikes(:,1)==0;
        if sum(digChanIdx)>0
            waveforms(:,digChanIdx) = ones(52,sum(digChanIdx));
        end

        n_loop = size(waveforms,2); 
    
        %% generate classifications 
        %*****Layer 1******
        layer1_raw = waveforms'*w1 + repmat(b1',n_loop,1);

        %***ReLU activation****
        %layer1_out = log(1+exp(layer1_raw)); %faster ReLU
        layer1_out = max(0,layer1_raw); %more accurate ReLU
        % layer1_out = layer1_raw; layer1_out(layer1_raw<=0) = 0; %alternate to using max but still slower than log method

        %***Layer 2*******
        layer2_raw = layer1_out*w2 + repmat(b2',n_loop,1);

        %***Softmax******
        layer2_out = 1./(1+exp(-1*(layer2_raw(:,1)-layer2_raw(:,2)))); %apply softmax

        net_labels(nstart:(nstart+n_loop-1)) = layer2_out;
        counter = counter + 1;
        
        %% print status messages
        if nend>nextthresh
            fprintf('   %.1f percent complete\n',(nend/nPackets)*100);
            nextthresh = nextthresh+increment;
        end
        fprintf('      Loop time is %.1f seconds\n',toc);
    end
    
    pSpike = net_labels';
    
    
end

