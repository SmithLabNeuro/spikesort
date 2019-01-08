function snr = getSNR(W)
% function snr = getSNR(W)
%
% Compute the SNR of the waveforms

W = double(W);

W_bar = mean(W);

A = max(W_bar) - min(W_bar);

if ~isempty(W)
    e = W - repmat(W_bar,size(W,1),1);
    e = reshape(e,size(e,1)*size(e,2),1);
    snr = A/(2*std(e));
else
    snr = nan;
end