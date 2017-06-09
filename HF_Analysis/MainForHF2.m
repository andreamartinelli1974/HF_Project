clear all;
close all;
clc;

%% importing data

% import the predictor indexes daily NAVs, including any non business calendar
% day, including a date vector for any index

[c,d] = xlsread('databaseFondi3.xls','INDICI');

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

[e,f] = xlsread('databaseFondi11.xls','INDICI');

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

[g,h] = xlsread('databaseFondi.xls');

[nr,nc] = size(g);

clear allFunds;

for k=2:3:nc
    name = h{1,k};
    name = strrep(name,' ','_');
    name = strrep(name,'-','_');

    allFunds.(name).data = g(1:nr,k-1:k);
    allFunds.(name).univocode=h{1,k-1};
    
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
    
    params.fund=hedgefund1(i);
    params.Indices=index1;
    
%   regressionTest=HFRegression(params);
    rollingperiod=idivide(size(hedgefund1(i).TrackROR,1)-2,int32(24));
    if rollingperiod>=10
        rollingperiod=10*12;
    else
        rollingperiod=rollingperiod*12;
    end
%     rollingTest.RollingReg;
    rollingTest=HFRollingReg(params,rollingperiod);
    MTX=rollingTest.getMtxPredictors(rollingTest,1000,'correlation');
    rollingTest.ConRollReg(MTX);
    
    parameters.fund=hedgefund2(i);
    parameters.indices=index2;
    parameters.rolling=rollingperiod*2/3;
    parameters.rolling2=rollingperiod/3;
    
    optregressiontest2=OptModelReg(parameters);
    optregressiontest2.OpRegression;
    
    hedgefund1(i).CreateTrackEst(rollingTest);
    hedgefund2(i).CreateTrackEst(optregressiontest2.Output);
    
end

for i=1:size(FundNames,1);
    i
    prms.fundName = FundNames{i};
    prms.univocode = allFunds.(FundNames{i}).univocode;
    prms.fundStrategy = 'N/A';
    prms.fundCcy = 'N/A';
    prms.fundTrack = allFunds.(FundNames{i}).data;
    
    hedgefund3(i) = HedgeFund(prms);
    hedgefund4(i) = HedgeFund(prms);
    
    params.fund=hedgefund3(i);
    params.Indices=index2;
    
%   regressionTest=HFRegression(params);
    rollingperiod=idivide(size(hedgefund3(i).TrackROR,1)-2,int32(24));
    if rollingperiod>=10
        rollingperiod=10*12;
    else
        rollingperiod=rollingperiod*12;
    end
%     rollingTest.RollingReg;
    hfstepwise=HFOddRegressions(params,rollingperiod);
    hfstepwise.LassoRollReg;;
    
    parameters.fund=hedgefund4(i);
    parameters.indices=index2;
    parameters.rolling=rollingperiod*2/3;
    parameters.rolling2=rollingperiod/3;
    
    optregressiontest4=OptModelReg(parameters);
    optregressiontest4.OpRegression;
    
    hedgefund3(i).CreateTrackEst(hfstepwise);
    hedgefund4(i).CreateTrackEst(optregressiontest4.Output);
    
    
    %% ATTENZIONE INTERVENTO DIRETTO SUL TRACK DI BACKTEST DEI FONDI
    % TENDENZIALMENTE DA NON FARE
    [date,first,second]=intersect(hedgefund1(i).TrackEst(:,1),hedgefund2(i).TrackEst(:,1),'rows');
    concat=cat(2,hedgefund1(i).TrackEst(first,:),hedgefund2(i).TrackEst(second,3));
    cumcat=cat(2,hedgefund1(i).BackTest(first,:),hedgefund2(i).BackTest(second,3));
    
    [date,first,second]=intersect(concat(:,1),hedgefund3(i).TrackEst(:,1),'rows');
    concat=cat(2,concat(first,:),hedgefund3(i).TrackEst(second,2));
    concat=cat(2,concat(first,:),hedgefund3(i).TrackEst(second,3));
    cumcat=cat(2,cumcat(first,:),hedgefund3(i).BackTest(second,2));
    cumcat=cat(2,cumcat(first,:),hedgefund3(i).BackTest(second,3));
    
    [date,first,second]=intersect(concat(:,1),hedgefund4(i).TrackEst(:,1),'rows');
    concat=cat(2,concat(first,:),hedgefund4(i).TrackEst(second,3));
    cumcat=cat(2,cumcat(first,:),hedgefund4(i).BackTest(second,3));
    hedgefund1(i).TrackEst=concat;
    hedgefund1(i).BackTest=cumcat;
    
    hedgefund1(i).TestReg=corrcoef(concat(:,2:end));
    
end


%% test the HFregresssion Class & subclasses


