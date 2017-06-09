clear all;
close all;
clc;

%% importing data

% import the predictor indexes daily NAVs, including any non business calendar
% day, including a date vector for any index

[c,d] = xlsread('databaseFondiTEST2.xls','INDICI');

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
    
    index1(i) = Indice(iprms);
    
end

%% import the predictor indexes daily NAVs, including any non business calendar
% day, including a date vector for any index

[e,f] = xlsread('databaseFondiTEST2.xls','INDICI');

[nri,nci] = size(e);

clear allIndexes;

for i = 1:3:(nci-1)
    
    namei = f{1,i};
    assetclass = f(1,i+1);
    namei = strrep(namei,' ','_');
    namei = strrep(namei,'-','_');
    namei = strrep(namei,'.','');
    
    allIndexes.(namei).datai = e(1:nri,i:i+1);
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
    
    index2(i) = Indice(iprms);
    
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
    
    
    hedgefund1(i) = HedgeFund(prms);
    hedgefund2(i) = HedgeFund(prms);
    hedgefund3(i) = HedgeFund(prms);
    hedgefund4(i) = HedgeFund(prms);
    
    params.fund=hedgefund1(i);
    params.Indices=index2;
    
%   regressionTest=HFRegression(params);
    rollingperiod=idivide(size(hedgefund1(i).TrackROR,1)-2,int32(12));
    if rollingperiod>=5
        rollingperiod=5*12;
    else
        rollingperiod=rollingperiod*12;
    end
%     rollingTest.RollingReg;
    rollingTest=HFRollingReg(params,rollingperiod);
    MTX=rollingTest.getMtxPredictors(rollingTest,1000,'correlation');
    rollingTest.ConRollReg(MTX);
    
    parameters.fund=hedgefund2(i);
    parameters.indices=index2;
    parameters.rolling=rollingperiod/3;
    parameters.rolling2=rollingperiod*2/3;
    
    optregressiontest2=OptModelReg(parameters);
    optregressiontest2.OpRegression;
    
    parameters.fund=hedgefund3(i);
    parameters.indices=index2;
    
    hfstepwise=HFOddRegressions(params,rollingperiod);
    %hfstepwise.RidgeRollReg(1000);
    hfstepwise.LassoRollReg;
    
%     parameters.fund=hedgefund4(i);
%     parameters.indices=index2;
%     parameters.rolling=rollingperiod*2/3;
%     parameters.rolling2=rollingperiod/3;
%     
%     optregressiontest4=OptModelReg(parameters);
%     optregressiontest4.OpRegression;
  
    parameters.fund=hedgefund4(i);
    parameters.indices=index2;
    
    hfstepwise2=HFOddRegressions(params,rollingperiod);
    hfstepwise2.RidgeRollReg(1.1);
    %%
    
    hedgefund1(i).CreateTrackEst(rollingTest, false);
    hedgefund2(i).CreateTrackEst(optregressiontest2.Output,false);
    hedgefund3(i).CreateTrackEst(hfstepwise,false);
    hedgefund4(i).CreateTrackEst(hfstepwise2,false);
    
%     hedgefund1(i).CreateTrackEst(rollingTest, true);
%     hedgefund2(i).CreateTrackEst(optregressiontest2.Output,true);
%     hedgefund3(i).CreateTrackEst(hfstepwise,true);
%     hedgefund4(i).CreateTrackEst(hfstepwise2,true);
%     
    %% ATTENZIONE INTERVENTO DIRETTO SUL TRACK DI BACKTEST DEI FONDI
    % TENDENZIALMENTE DA NON FARE
    
    concat=cat(2,hedgefund1(i).TrackEst,hedgefund2(i).TrackEst(:,3));
    concat=cat(2,concat,hedgefund3(i).TrackEst(:,3));
    concat=cat(2,concat,hedgefund4(i).TrackEst(:,3));
    hedgefund1(i).TrackEst=concat;
    
    cumcat=cat(2,hedgefund1(i).BackTest,hedgefund2(i).BackTest(:,3));
    cumcat=cat(2,cumcat,hedgefund3(i).BackTest(:,3));
    cumcat=cat(2,cumcat,hedgefund4(i).BackTest(:,3));
    hedgefund1(i).BackTest=cumcat;
    
    hedgefund1(i).TestReg=corrcoef(concat(:,2:end));
    
end


%% test the HFregresssion Class & subclasses


