function [sortCode] = NasOnMog(sc,sortCode)
% sc: sortcodes from nasnet
% sortCode: sortcodes from mogSort
if isempty(sortCode)
    sortCode = sc;
    return
end

sortCode(sc == 255) = 255;
% scNumber = unique(sortCode);
% scNumber_no255 = scNumber(scNumber<255);
% for m = 1:length(scNumber_no255)
%     if sum(sortCode == scNumber_no255(m)) < 0.05*length(sc)
%         sortCode(sortCode == scNumber_no255(m)) = 255;
%     end
% end

scList = unique(sortCode);
scList_no255 = scList(scList<255);
for m = 1:length(scList_no255)
   sortCode(sortCode == scList_no255(m)) = m;
end