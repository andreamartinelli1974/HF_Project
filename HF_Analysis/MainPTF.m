clear all;
close all;
clc;

%% importing data

% import the predictor indexes daily NAVs, including any non business calendar
% day, including a date vector for any index

[c,d] = xlsread('databaseFondi11.xls','INDICI');

[nri,nci] = size(c);

clear allIndexes;

for i = 1:3:(nci-1)
    
    namei = d{1,i};
    assetclass = d(1,i+1);
    namei = strrep(namei,' ','_');
    namei = strrep(namei,'-','_');
    namei = strrep(namei,'.','');
    
    allIndexes.(namei).datai = c(1:nri,i:i+1);
    allIndexes.(namei).assetclass = assetclass;
    
    fnani = isnan(allIndexes.(namei).datai(:,1));
    fnani = find(fnani==1);    
    allIndexes.(namei).datai(fnani,:) = [];
    allIndexes.(namei).datai(:,1) = x2mdate(allIndexes.(namei).datai(:,1),0);
   
    
end

%% Create an array of Indice objs for any imported index

indexNames = fieldnames(allIndexes);

for i = 1:size(indexNames,1)
    
    iprms.indexName = indexNames{i};
    iprms.indexTicker = 'N/A';
    iprms.indexTrack = allIndexes.(indexNames{i}).datai;
    iprms.indexAssetCl = allIndexes.(indexNames{i}).assetclass;
    
    index(i) = Indice(iprms);
    
end

%% import the HFunds NAVs at any available date, including a date vector for
% any fund

[a,b] = xlsread('databaseFondiUCITS.xls');

[nr,nc] = size(a);

clear allFunds;

for k=2:3:nc
    name = b{1,k};
    name = strrep(name,' ','_');
    name = strrep(name,'-','_');

    allFunds.(name).data = a(1:nr,k-1:k);
    allFunds.(name).univocode=b{1,k-1};
    
    fnan = isnan(allFunds.(name).data(:,1));
    fnan = find(fnan==1);
    
    allFunds.(name).data(fnan,:) = [];
    allFunds.(name).data(:,1) = x2mdate(allFunds.(name).data(:,1),0);
end

%% Create an arrey of HedgeFund objs for any imported Fund

FundNames = fieldnames(allFunds);

for i=1:size(FundNames,1)
    i
    prms.fundName = FundNames{i};
    prms.univocode = allFunds.(FundNames{i}).univocode;
    prms.fundStrategy = 'N/A';
    prms.fundCcy = 'N/A';
    prms.fundTrack = allFunds.(FundNames{i}).data;
    
    
    hedgefund(i) = HedgeFund(prms);
    
end

%% Create a portfolio 
%(to test the HFPortfolio Class the first attempt is with an equal weighted ptf)
[e,f] = xlsread('databaseFondiUCITS.xls','Sheet5');
nfunds=size(e,2);

for i=1:nfunds
    name = f{2,i};
    name = strrep(name,' ','_');
    name = strrep(name,'-','_');
    
    weights.(name)=e(1,i);
end


params.funds=hedgefund;
params.weights=weights;
params.regressors=index;

hfportfolio=HFPortfolio(params);
hfportfolio.BuildPTF;
hfportfolio2=HFPortfolio(params);
hfportfolio2.BuildPTF;
hfportfolio3=HFPortfolio(params);
hfportfolio3.BuildPTF;
hfportfolio4=HFPortfolio(params);
hfportfolio4.BuildPTF;


hfportfolio.RegressPTF('bayesian',60);
hfportfolio2.RegressPTF('bayesian',80);
% hfportfolio2.RegressPTF('rolling',60);
hfportfolio3.RegressPTF('cond rolling',60);
hfportfolio4.RegressPTF('cond rolling',80);
% hfportfolio4.RegressPTF('random rolling',36);



