% plot classified waveforms

% waveforms to plot (mat file containing the variable waveforms)
filename   = 'Pe160525_s96ax_fixAndMultistim_movie_0001';

% pahts
paths      = mypaths;
datapath   = paths{1};
labelspath = paths{2};
netpath    = paths{3};

% where to save the figures
savepath   = '~/googledrive/SmithYuSoldado/ustimfigs/movie/NASNet/';
savefig    = false;

% classification labels to load
netName    = 'uStimNet';
gamma      = '08';
% combine labels from network trained to remove artifacts
rm_artifacts = false;
agamma       = '02'; 

if rm_artifacts
    savename   = [netName '_artifact' '_g' gamma '_ga' agamma...
        '_' filename(10:14)];
else
    savename   = [netName '_g' gamma '_' filename(10:14)];
end

filepath   = [datapath filename '.mat'];

disp('loading classified data labels (spikes vs noise)...')
load(filepath,'waveforms')
load([labelspath filename '_' netName '_gamma' gamma],'spikes');

if rm_artifacts
    disp('loading additional labels for detected artifacts in data...')
    load([labelspath filename '_' netName '_artifact_gamma' agamma],...
        'artifacts');
    spikes(logical(artifacts(:,2)),2)=0;
end


%% Plotting

channellist = [1 5 10 15 20 30 35 40 45 50 60 70 80 85 90 95];
chs = sqrt(length(channellist));

h=figure;
pos = get(h,'position');
set(h,'position',[pos(1:2) pos(3)*chs pos(4)*chs])
set(0,'DefaultAxesFontSize',20)
fs = 24;

figure(h)
p = tiledlayout('flow');
p.TileSpacing = 'compact';
p.Padding = 'compact';


for ch=channellist
    
fprintf('Plotting example waveforms from channel %i \n', ch)

spidx = spikes(:,2);
chidx = spikes(:,1)==ch;

idx   = logical(spidx.*chidx);

spike = waveforms(idx,:);
noise = waveforms(~idx,:);

ss    = size(spike,1);
sn    = size(noise,1);

nexttile
hold on
if sn>0; h1=plot(noise(randi(sn,50),:)','k'); end
if ss>0; h2=plot(spike(randi(ss,50),:)','g'); end
title(['ch', num2str(ch)]);
axis tight
xlim([1,52]);

if ch==channellist(1)
    legend([h1(1) h2(1)],{'noise','spikes'})
end

end

if rm_artifacts
    title(p,['V4 waveforms classified with ' netName '-artifact' ...
        ', at \gamma = ' gamma ' and \gamma_a = ' agamma],'FontSize',fs)
else
    title(p,['V4 waveforms classified with ' netName ...
        ', at \gamma = ' gamma], 'FontSize',fs)
end
xlabel(p,'time','FontSize',fs)
ylabel(p,'uV','FontSize',fs)

if savefig
    print(gcf,'-depsc2','-painters',[savepath savename])
end