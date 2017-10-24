clear all;
clc;
close all;
rng('default');

%%

pt = path;
userId = getenv('USERNAME');

addpath(['C:\Users\' userId '\Documents\GitHub\Utilities\'], ...
    ['C:\Users\' userId '\Documents\GitHub\Utilities\RatesUtilities\'], ...
    ['C:\Users\' userId '\Documents\GitHub\Utilities\Mds\'], ...
    ['C:\Users\' userId '\Documents\GitHub\Utilities\Pca\'], ...
    ['C:\Users\' userId '\Documents\GitHub\Utilities\Regressions\'], ...
    ['C:\Users\' userId '\Documents\GitHub\AA_Project\AssetAllocation'], ...
    ['C:\Users\' userId '\Documents\GitHub\AA_Project\AssetAllocation\MdsCallData\'], ...
    ['C:\Users\' userId '\Documents\GitHub\AA_Project\AssetAllocation\HistBstrappedCurves\'], ...
    ['C:\Users\' userId '\Documents\GitHub\AA_Project\AssetAllocation\SwapClass\'], ...
    ['C:\Users\' userId '\Documents\GitHub\ReportsMgmt']);

% **************** STRUCTURE TO ACCESS BLOOMBERG DATA *********************
DataFromBBG.save2disk = true(1); % True to save all Bloomberg calls to disk for future retrieval
DataFromBBG.folder = [cd,'\BloombergCallsData\'];
%DataFromBBG.folder = ['C:\Users\u093799\Documents\MATLAB\AssetAllocationDVA\AssetAllocation\BloombergCallsData\'];

if DataFromBBG.save2disk
    if exist('BloombergCallsData','dir')==7
        rmdir(DataFromBBG.folder(1:end-1),'s');
    end
    mkdir(DataFromBBG.folder(1:end-1));
end
try
    javaaddpath('C:\blp\DAPI\blpapi3.jar')
    DataFromBBG.BBG_conn = blp;
    DataFromBBG.NOBBG = false(1); % True when Bloomberg is NOT available and to use previopusly saved data
catch ME
    DataFromBBG.BBG_conn = [];
    DataFromBBG.NOBBG = true(1); % if true (on machines with no BBG terminal), data are recovered from previously saved files (.save2disk option above)
end

% **************** STRUCTURE TO MARKET DATA SERVER DATA *******************
DataFromMDS.save2disk = true(1); % True to save Mds calls to disk for future retrieval
DataFromMDS.folder = [cd,'\MdsCallsData\'];
if DataFromMDS.save2disk
    if exist('MdsCallsData','dir')==7
        rmdir(DataFromMDS.folder(1:end-1),'s');
    end
    mkdir(DataFromMDS.folder(1:end-1));
end
DataFromMDS.server = 'cvai0apcf01rp:90';
DataFromMDS.createLog = false(1);
DataFromMDS.NOMDS = false(1); % if true (on machines with no MDS access), data are recovered from previously saved files (.save2disk option above)


%**************** END OF PATHS, BBG & MDS INITIALIZATION ******************

%% INITIAL PARAMETERS SETUP

[ DAA_params, InvestmentUniverse_fileName, InvestmentUniverse_sheetName, history_start_date,...
    history_end_date,history_start_date_YC, start_dt_num, end_dt, ...
    IV_hdate,MinAbsShort_Exposure,MaxAbsLong_Exposure, ...
    granularity,params_Equity_ret,params_cds_ret,additional_params,curves2beRead,configFile4IrCurvesBtStrap] = InitialParameters('HFunds');

hor = DAA_params.Horizon; % Investment horizon (in days)

useSavedVolaObj.flag = 1; % 0 to save vola surface obj; 1 to use previously saved vola objects
useSavedVolaObj.folder = [cd,'\VolaSurfacesObjects\']; % folder to save/load vola obj


%% GET THE VARIOUS REGRESSORS DATA

%% DEFINING ALL REQUIRED CURVES
% UniverseTable, containing the investment universe members that will be
% transposed into objects later, is read now to 'understand' which
% IR, CDS and Single Idx objects to read from the same xls file in the
% following sections

% WARNING: this is done to be able to have unique sheets 'CDS_Curves',
% 'IR_Curves' and 'Single_Indices' within Investment_Universe.xls and
% recognize, within them, which curves/indices are needed.
% The attributes 'internal'/'external' must be defined wrt the specific AA
% run since a given curve could be needed only as 'internal' in a setup,
% while required as 'external' in a different setup (e.g. if it is used for
% accruals)

% all the objects (of type IR, CDS and SingleIndex) to be instanciated will
% be put in AllCurvesToBeGenerated

UniverseTable = readtable(InvestmentUniverse_fileName,'Sheet',InvestmentUniverse_sheetName);

AllCurvesToBeGenerated = [];

% defining IR, CDS curves, vola surfaces, etc. to be created
cdsCurvesList = unique(ReadFromIU_inputFile.ParseMultipleObjInput(UniverseTable.CDS_cds_curve));
irCurvesList1 = unique(ReadFromIU_inputFile.ParseMultipleObjInput(UniverseTable.Bond_ref_curve));
irCurvesList2 = unique(ReadFromIU_inputFile.ParseMultipleObjInput(UniverseTable.CDS_dcurve));
irCurvesList3 = unique(ReadFromIU_inputFile.ParseMultipleObjInput(UniverseTable.Asset_synthetic_ts));
irc2beBtStrapped_List = unique(ReadFromIU_inputFile.ParseMultipleObjInput(UniverseTable.ForwardCurves));
irc2beBtStrapped_Disc = unique(ReadFromIU_inputFile.ParseMultipleObjInput(UniverseTable.DiscountCurves));
accrualsList = unique(ReadFromIU_inputFile.ParseMultipleObjInput(UniverseTable.FixingCurves));
fxCurves = unique(ReadFromIU_inputFile.ParseMultipleObjInput(UniverseTable.FxCurve));
irCurve4Options = unique(ReadFromIU_inputFile.ParseMultipleObjInput(UniverseTable.Option_curve_obj));
VolaEquity4Options = unique(ReadFromIU_inputFile.ParseMultipleObjInput(UniverseTable.Option_vola_surface_obj));

AllCurvesToBeGenerated = {};
AllCurvesToBeGenerated = ReadFromIU_inputFile.AppendAndClean(AllCurvesToBeGenerated,cdsCurvesList,irCurvesList1,irCurvesList2,irCurvesList3, ...
    irc2beBtStrapped_List,irc2beBtStrapped_Disc,accrualsList,fxCurves,irCurve4Options,VolaEquity4Options);


%% NEW CLASS ReadAsset.m TO BE TESTED

AL.cdsCurvesList          = cdsCurvesList;
AL.irCurvesList1          = irCurvesList1;
AL.irCurvesList2          = irCurvesList2;
AL.irCurvesList3          = irCurvesList3;
AL.irc2beBtStrapped_List  = irc2beBtStrapped_List;
AL.irc2beBtStrapped_Disc  = irc2beBtStrapped_Disc;
AL.accrualsList           = accrualsList;
AL.fxCurves               = fxCurves;
AL.irCurve4Options        = irCurve4Options;
AL.VolaEquity4Options     = VolaEquity4Options;
AL.AllCurvesToBeGenerated = AllCurvesToBeGenerated;

RAparams.AL = AL;
RAparams.filename = InvestmentUniverse_fileName;
RAparams.path = [cd,'\HistBstrappedCurves\'];
RAparams.configFile4IRCB = configFile4IrCurvesBtStrap;
RAparams.history_start_date = history_start_date;
RAparams.history_end_date = history_end_date;
RAparams.DataFromBBG = DataFromBBG;
RAparams.DataFromMDS = DataFromMDS;
RAparams.useVolaSaved = useSavedVolaObj;

ReadAssets = ReadAsset(RAparams);

try
IR_Curves    = ReadAssets.Assets.IR_Curves;
CdsCurves    = ReadAssets.Assets.CdsCurves;
sIndices     = ReadAssets.Assets.sIndices;
SWAP_curves  = ReadAssets.Assets.SWAP_curves;
VolaSurfaces = ReadAssets.Assets.VolaSurfaces;
catch mm
    
end

%% *********************  EXTERNAL RISK FACTORS **************************
% Here a set of external risk factors is created: these are risk factors
% that are not embedded in the construction of a specific asset (e.g. S&P
% future prices when equity('SPX Index', 'equity',.... is created or E(3), B(1),
% and V_SX5E when O(1) = Option_Vanilla('SX5E 03/18/16 P3000
% Index','equity', ... is created.
% External risk factors are created for the following reasons:
% -> e.g. yield curves or zeros curves: e.g. to produce invariants and price
% bonds whose pricing depends on several factors that may change over time
% (as it is for bonds with a given maturity)
% zero curves used to discount option prices
% CDS spreads curves for CDS with given maturity
% in future developments external risk factors could include factors
% related to the economy and used in a factors'model
% THESE INVARIANTS MUST BE MERGED WITHIN THE AllInvariants field in
% obj of class Universe

% 24.1.2017: added a field ("ToBeIncludedInInvariants") to the input sheets
% ("Investment_Universe.xls") to be able to discriminate (when invoking
% universe.GetInvariants_EmpiricalDistribution) between external risk
% factors that must be included within the set of invariants and those that
% must not be included. This is done since there are some external risk
% factors (like EURIBOR or LIBOR rates used to compute accruals) that are
% used only in their 'deterministic version' (when they are known) and do
% not neeed to be simulated over the investment horizon (because, for
% example, forward rates are used in the case of EURIBOR/LIBOR to project
% future accruals).

% TODO: when possible think about the opportunity to put all risk factors within
% one External_Risk_Factors class, eliminating the distinction
% between internal (provided direclty when building the security) and
% external risk factors

% TODO: some of the external factors added here are used as internal
% factors, so they don't need to be here. Add a field to them to be able to
% discriminate and put in Exf_RF only the risk factors that are really
% external (this can save a lot of calc time)

clear rf Ext_RF Obj_names;
Ext_RF = [];
sizeRF = 0;
if exist('IRcurves')
    fnames = fieldnames(IRcurves);
    nc = numel(fnames);
    for c=1:nc
        if strcmp(IRcurves.(fnames{c}).IntExt,'external')
            % include only the risk factors that are 'external' (that is not
            % already contained in the body of the objects that will be
            % instantiated to model assets)
            sizeRF = sizeRF + 1;
            rf(sizeRF).value = IRcurves.(fnames{c});
            obj_names{sizeRF,1} = fnames{c};
        end
    end
else
    IRcurves = [];
end

if exist('CdsCurves') & ~isempty(CdsCurves)
    fnames = fieldnames(CdsCurves);
    nc = numel(fnames);
    for c=1:nc
        if strcmp(CdsCurves.(fnames{c}).IntExt,'external')
            sizeRF = sizeRF + 1;
            rf(sizeRF).value = CdsCurves.(fnames{c});
            obj_names{sizeRF,1} = fnames{c};
        end
    end
else
    CdsCurves = [];
end

if exist('sIndices') & ~isempty(sIndices)
    fnames = fieldnames(sIndices);
    nc = numel(fnames);
    for c=1:nc
        if strcmp(sIndices.(fnames{c}).IntExt,'external')
            sizeRF = sizeRF + 1;
            rf(sizeRF).value = sIndices.(fnames{c});
            obj_names{sizeRF,1} = fnames{c};
        end
    end
else
    sIndices = [];
end

if exist('SWAP_curves') & ~isempty(SWAP_curves)
    fnames = fieldnames(SWAP_curves);
    nc = numel(fnames);
    for c=1:nc
        if strcmp(SWAP_curves.(fnames{c}).IntExt,'external')
            sizeRF = sizeRF + 1;
            rf(sizeRF).value = SWAP_curves.(fnames{c});
            obj_names{sizeRF,1} = fnames{c};
        end
    end
else
    SWAP_curves = [];
end

if exist('VolaSurfaces') & ~isempty(VolaSurfaces)
    fnames = fieldnames(VolaSurfaces);
    nc = numel(fnames);
    for c=1:nc
        if strcmp(VolaSurfaces.(fnames{c}).intext,'external')
            sizeRF = sizeRF + 1;
            rf(sizeRF).value = VolaSurfaces.(fnames{c});
            obj_names{sizeRF,1} = fnames{c};
        end
    end
else
    VolaSurfaces = [];
end

if exist('rf','var') && ~isempty(rf)
    erfParams.returnsLag = 1;
    erfParams.ExtendedLag = 5;
    Ext_RF = External_Risk_Factors(rf,obj_names,erfParams);
end

%% ASSETS OF THE INVESTMENT UNIVERSE DEFINITION
% ************************************************************************
% ******************** Loading Investment Universe ************************
% *************************************************************************
% instanciating an obj of class ReadFromIU_inputFile to read IU consituents
clear iu_params;
iu_params.UniverseTable = UniverseTable;
iu_params.history_start_date = history_start_date;
iu_params.history_end_date = history_end_date;
iu_params.DataFromBBG = DataFromBBG;
iu_params.hor = hor;
iu_params.Ext_RF = Ext_RF;
iu_params.granularity = granularity;
iu_params.params_Equity_ret = params_Equity_ret;
iu_params.IRcurves = IRcurves;
iu_params.CdsCurves = CdsCurves;
iu_params.sIndices = sIndices;
iu_params.SWAP_curves = SWAP_curves;
iu_params.VolaSurfaces = VolaSurfaces;
iu_params.additional_params = additional_params;
iu_params.params_cds_ret = params_cds_ret;
iu_params.scenarioAnalysisRun = DAA_params.scenarioAnalysisRun;
iu_params.MinDate4scenarioAnalysisRun = DAA_params.MinDate4scenarioAnalysisRun;
iu_params.MinHistDate4Assets = []; 

IU = ReadFromIU_inputFile(iu_params);

%% ************************************************************************
% INSTANCIATING AN OBJ OF CLASS UNIVERSE AND ADDING ASSETS TO IT
%  ************************************************************************
clear Universe_1;
Universe_1 = universe('FirstUniverse',DataFromBBG,Ext_RF,IU,[]);
% adding vectors of assets to the universe
if isvector(IU.E)
    Universe_1.AddAsset(IU.E);
end
if isvector(IU.B)
    Universe_1.AddAsset(IU.B);
end
if isvector(IU.C)
    Universe_1.AddAsset(IU.C);
end
if isvector(IU.F)
    Universe_1.AddAsset(IU.F);
end
if isvector(IU.O)
    Universe_1.AddAsset(IU.O);
end
if isvector(IU.CDS)
    Universe_1.AddAsset(IU.CDS);
end
if isvector(IU.SB)
    Universe_1.AddAsset(IU.SB);
end


% to get the latest date available for each invariant (property
% Universe_1.InvariantsLastDate): this is useful to understand which dates
% vector 'drives' the intersection on a common set of dates performed by
% the method Universe_1.GetInvariants_EmpiricalDistribution
Universe_1.GetLastDateAndSectorCountry;
% invoking method to get all invariants
Universe_1.GetInvariants_EmpiricalDistribution;

%% CREATES THE REGRESSORS SET
Regressors = Universe_1.AllInvariants;
nameset = Universe_1.AllInvariants.NamesSet;





%% GET HEDGE FUND DATA & PERFORM THE REGRESSION USING THE FLS METHOD

FundsPortfolio = readtable('FundsData.xls','Sheet','FUNDS');
TableNames = FundsPortfolio.Properties.VariableNames;
fundNames = FundsPortfolio.(TableNames{1}); 
fundNames = strrep(fundNames,' ','_');
fundNames = strrep(fundNames,'-','_');
Strategy = FundsPortfolio.(TableNames{2}); 
Currency = FundsPortfolio.(TableNames{3});
fundNavSheet = FundsPortfolio.(TableNames{4});
Periodicity = FundsPortfolio.(TableNames{5});
PTFweights = FundsPortfolio.(TableNames{6});

nrOfFunds = size(fundNames,1);

tic
for i = 1:nrOfFunds

    FundNav = readtable('FundsData.xls','Sheet',fundNavSheet{i});
    params.fundName = fundNames{i};
    params.fundStrategy = Strategy{i};
    params.fundCcy = Currency{i};
    params.Periodicity = Periodicity{i};
    params.fundTrack = table2array(FundNav);
    
    HFunds.(fundNames{i}) = HedgeFund(params);
    HFundsSR.(fundNames{i}) = HedgeFund(params);
    
    atscreen = ['now processing  ',fundNames{i}];
    disp(atscreen)
    
    params.Ydates = HFunds.(fundNames{i}).TrackNAV(:,1);
    params.Y = HFunds.(fundNames{i}).TrackNAV(:,2);
    params.Yname = fundNames{i};
    params.Xdates = Regressors.Dates;
    params.X = Regressors.X.*100; 
    params.Xnames = Regressors.NamesSet';
    params.WithPCA = true(1);
    
    U = Utilities(params);
    U.FillWeeklyWithDaily;

    HFunds.(fundNames{i}).BackTest = U.Output;
    
    params.WithPCA = false(1);
    
    U = Utilities(params);
    U.FillWeeklyWithDaily;
    
    HFundsSR.(fundNames{i}).BackTest = U.Output;
    
%     % RawReturns = Regressors.PCA.out.CellSelected;
%     RawReturns = Regressors.CellSelected; %% without PCA
%     
%     utilParams = [];
%     utilParams.inputTS = RawReturns';
%     utilParams.referenceDatesVector = HFunds.(fundNames{i}).TrackROR(:,1); 
%     utilParams.op_type = 'fillUsingNearest';
%     U = Utilities(utilParams);
%     U.GetCommonDataSet;
%     
%     Y = HFunds.(fundNames{i}).TrackROR(:,2) ;
%     X = U.Output.DataSet.data;
%     Dates = U.Output.DataSet.dates;
%     rgrs = [Dates,X];
%     
%     prm.inputdates = Dates; % inputdates;
%     prm.inputarray = [Y,X]./100;  % inparrayror;
%     %prm.inputnames = [fundNames{i},Regressors.PCA.out.selectedNames];
%     prm.inputnames = [fundNames{i},Universe_1.AllInvariants.NamesSet'];  %without pca
%     
%     switch HFunds.(fundNames{i}).Periodicity
%         case 'monthly'
%             prm.rollingperiod = 30;
%         case 'weekly'
%             prm.rollingperiod = 30*4;
%         case 'daily' 
%             prm.rollingperiod = 30*21;
%         otherwise
%             disp('Periodicity not found or wrong (only monthly, weekly ad daily available')
%             prm.rollingperiod = min(round(size(HFunds.(fundNames{i}).TrackROR,1)/2,0),30*21);
%     end
%     
%     RegressFLS30 = FLSregression(prm); % constructor
%     RegressFLS30.GetFLS(90,0);          % regression
%     betas = RegressFLS30.Betas;
%     RegressFLS30.GetFLSforecast(betas,rgrs,'Simple');
%     
%     
%     SimpleRegress = Regression(prm);
%     SimpleRegress.SimpleRegression;
%     
%     OriginalPrices = HFunds.(fundNames{i}).TrackNAV(:,2);
%     DatePrices = HFunds.(fundNames{i}).TrackNAV(:,1);
%     Betas = RegressFLS30.Betas(:,2:end);
%     DateBetas = RegressFLS30.Betas(:,1);
%     % regressors = Regressors.PCA.out.selected./100; %%% very important: regressors are expressed in %!!!
%     % DateRegressors = Regressors.PCA.out.dates;
%     regressors = Universe_1.AllInvariants.X./100; % without pca
%     DateRegressors = Universe_1.AllInvariants.Dates; % without pca
%     
%     HFunds.(fundNames{i}).BackTest = GetFilledPrices(OriginalPrices,DatePrices,Betas,DateBetas,regressors,DateRegressors);
%     HFunds.(fundNames{i}).Betas = RegressFLS30.Betas;
%     HFunds.(fundNames{i}).RegResult = RegressFLS30;
%     HFunds.(fundNames{i}).TrackEst =  RegressFLS30.Output;
%     
%     BetasSR = repmat(table2array(SimpleRegress.Betas(:,3:end)),size(Betas,1),1);
%     
%     HFundsSR.(fundNames{i}).BackTest = GetFilledPrices(OriginalPrices,DatePrices,BetasSR,DateBetas,regressors,DateRegressors);
%     HFundsSR.(fundNames{i}).Betas = BetasSR;
%     HFundsSR.(fundNames{i}).RegResult = SimpleRegress;
%    
%     RegressFLSR = FLSregression(prm) % constructor
%     RegressFLSR.GetFLSrolling(30);          % regression
%     betasR = RegressFLSR.Betas;
%     
%     RegressFLSR.GetHFfake(betasR);    % built a fake HFund obj
%     FakeHF.(fundName{i}) = RegressFLSR.Output;
%     RegressFLSR.GetFLSforecast(betasR,rgrs,'Rolling');
%     HFunds.(fundName{i}).TrackEst =  RegressFLSR.Output;
%     HFunds.(fundName{i}).RegResult =  RegressFLSR.RollingFLSdata;
%     HFunds.(fundName{i}).BackTest = [Y(prm.rollingperiod:end,:),RegressFLSR.Output(:,2)];
%     
%     insample=false(1);
%     HFunds.(fundName{i}).CreateTrackEst(FakeHF.(fundName{i}),insample);
%     insample=true(1);
%     HFundsInSample.(fundName{i}).CreateTrackEst(FakeHF.(fundName{i}),insample);
%     
    elapstime(i)=toc;
end
elapstime(i+1) = toc;

save testHF_FLS_EXTENDED.mat

% exit








