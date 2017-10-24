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

%% ************************** CDS CURVES OBJECTS **************************
% READING THE Investment Universe File, CDS_Curves Sheet to build CDS curves objects

clear CdsCurves;
historical_window.startDate = history_start_date;
historical_window.endDate = history_end_date;

% OPENING XLS CONNECTION TO READ ALL CURVES DATA FOR CDS CURVES THAT WILL
% NOT BE READ FROM BLOOMBERG
exl = actxserver('excel.application');
exlWkbk = exl.Workbooks;
% exlFile = exlWkbk.Open([cd,'\CDS_MarketData.xlsm']); % PARAMETRIZE this file name
exlFile = exlWkbk.Open(['C:\Users\' userId '\Documents\GitHub\AA_Project\AssetAllocation','\CDS_MarketData.xlsm']); % PARAMETRIZE this file name

% ********* CDS CURVES *********
CdsCurvesTable = readtable(InvestmentUniverse_fileName,'Sheet',curves2beRead.CDS_SheetName);
L = size(CdsCurvesTable,1);

eof = false(1);
rowNum = 0;

while ~eof
    params_curve = [];
    rowNum = rowNum + 1;
    if rowNum>L
        break;
    end
    
    curveName = cell2mat(table2cell(CdsCurvesTable(rowNum,'name')));
    
    % check if the curve is in cdsCurvesList
    im = ismember(AllCurvesToBeGenerated,curveName);
    if sum(im)==0
        continue
    end
    
    if ~isempty(curveName)
        params_curve.thresholdForInterpolating = cell2mat(table2cell(CdsCurvesTable(rowNum,'thresholdForInterpolating')));
        params_curve.extrapolate = (cell2mat(table2cell(CdsCurvesTable(rowNum,'extrapolate'))));
        params_curve.int_ext = cell2mat(table2cell(CdsCurvesTable(rowNum,'Internal_External_RF')));
        params_curve.RatesInputFormat = cell2mat(table2cell(CdsCurvesTable(rowNum,'rates_input_format')));
        params_curve.ToBeIncludedInInvariants = cell2mat(table2cell(CdsCurvesTable(rowNum,'ToBeIncludedInInvariants')));
        params_curve.tenorMapType = cell2mat(table2cell(CdsCurvesTable(rowNum,'tenors_key_mapping')));
        
        curveMaturities = table2cell(CdsCurvesTable(rowNum,'maturities'));
        curveMaturitiesIntoCell=regexp(curveMaturities,',','split');
        ticker = cell2mat(table2cell(CdsCurvesTable(rowNum,'ticker')));
        
        nmat = numel(curveMaturitiesIntoCell{1});
        % build the 'curve_tickers' fields: tickers of all points oin the curve
        % (the logic is the same as the one applied by Bloomberg)
        clear curve_tickers;
        for k=1:nmat
            curve_tickers{k,1} = [ticker,' ',cell2mat(curveMaturitiesIntoCell{1}(k)),' Corp'];
        end
        
        params_curve.excel_spread_input.flag = logical(cell2mat(table2cell(CdsCurvesTable(rowNum,'excel'))));
        
        if params_curve.excel_spread_input.flag % if data are in xls file
            ShName = cell2mat(table2cell(CdsCurvesTable(rowNum,'sheetname')));
            params_curve.excel_spread_input.manual_ticker = ShName;
            params_curve.excel_spread_input.firstCDScol = cell2mat(table2cell(CdsCurvesTable(rowNum,'firstColInXlsFile'))); % column where spreads vectors start in the input file
            params_curve.excel_spread_input.lastCDScol =  cell2mat(table2cell(CdsCurvesTable(rowNum,'lastColInXlsFile'))); % column where spreads vectors start in the input file
            sheetMain = exlFile.Sheets.Item(ShName); % name of the sheet in the xls file
            dat_range = GetXlsRange(sheetMain,cell2mat(table2cell(CdsCurvesTable(rowNum,'dat_range'))));
            params_curve.excel_spread_input.inputMatrix = sheetMain.Range(dat_range).value;
            price_used = [];
            
        else % data from Bloomberg
            price_used = cell2mat(table2cell(CdsCurvesTable(rowNum,'price_used')));
        end
        
        CdsCurves.(curveName) = CDS_Curve(ticker,DataFromBBG,curve_tickers,historical_window,price_used,params_curve)
    else
        eof = true(1); % assuming EOF when there is nothing in the field 'name'
    end
    
end % ~eof

Quit(exl);
delete(exl);
clear exlFile;

[taskstate, taskmsg] = system('tasklist|findstr "EXCEL.EXE"');
if ~isempty(taskmsg)
    status = system('taskkill /F /IM EXCEL.EXE');
end
% ***** END of CDS CURVES *****

%% ************************ IR CURVES OBJECTS  ****************************
% READING THE Investment Universe File, IR_Curves Sheet to build IR curves objects
% IRC_params.CurveID = ['YCGT0040 Index'];
% IRC_params.ctype = ['BBG_single'];

clear IRcurves;
IR_CurvesTable = readtable(InvestmentUniverse_fileName,'Sheet',curves2beRead.IR_SheetName);

L = size(IR_CurvesTable,1);

eof = false(1);
rowNum = 0;

while ~eof
    IRC_params = [];
    extCdataparams = [];
    rowNum = rowNum + 1;
    if rowNum>L
        break;
    end
    IRC_params.StartDate = history_start_date;
    IRC_params.EndDate = history_end_date;
    IRC_params.DataFromBBG = DataFromBBG;
    
    curveName = cell2mat(table2cell(IR_CurvesTable(rowNum,'name')));
    
    % check if the curve is in irCurvesList
    im = ismember(AllCurvesToBeGenerated,curveName);
    if sum(im)==0
        continue
    end
    
    if ~isempty(curveName)
        IRC_params.CurveID = cell2mat(table2cell(IR_CurvesTable(rowNum,'curve_id')));
        IRC_params.ctype = cell2mat(table2cell(IR_CurvesTable(rowNum,'ctype')));
        IRC_params.TenorsKeyMapping_choice = cell2mat(table2cell(IR_CurvesTable(rowNum,'tenors_key_mapping')));
        IRC_params.BBG_YellowKey = cell2mat(table2cell(IR_CurvesTable(rowNum,'bbg_yellowKey')));
        IRC_params.invertBbgSigns = logical(cell2mat(table2cell(IR_CurvesTable(rowNum,'invertBbgSigns'))));
        IRC_params.RatesInputFormat = (cell2mat(table2cell(IR_CurvesTable(rowNum,'rates_input_format'))));
        IRC_params.RatesType = (cell2mat(table2cell(IR_CurvesTable(rowNum,'rates_type'))));
        IRC_params.int_ext = cell2mat(table2cell(IR_CurvesTable(rowNum,'Internal_External_RF')));
        IRC_params.ToBeIncludedInInvariants = cell2mat(table2cell(IR_CurvesTable(rowNum,'ToBeIncludedInInvariants')));
        IRC_params.BBG_tickerRoot = cell2mat(table2cell(IR_CurvesTable(rowNum,'BBG_tickerRoot')));
        
        extCdataparams.XlsCurve.FileName = cell2mat(table2cell(IR_CurvesTable(rowNum,'xlsCurve_filename')));
        extCdataparams.XlsCurve.SheetName = cell2mat(table2cell(IR_CurvesTable(rowNum,'xlsCurve_sheetname')));
        
        % TODO: 'internalize into IR_Curve the 2 input alternatives below:
        % and also add the one related to the output from bootsstrapped
        % curves (see section below reading bootstrapped curve)
        if strcmp(IRC_params.ctype,'file') &  ~isempty(extCdataparams.XlsCurve.FileName) % need to read curve's data from xls file
            % if input is from file and there is an Excel file name ***
            % *** INPUT FROM XLS FILE ***
            U = Utilities(extCdataparams);
            U.ReadCurveDataFromXls;
            IRC_params.ExtSource = U.Output;
        elseif strcmp(IRC_params.ctype,'MDS')
            % *** INPUT from Mkt Data Server ***
            % as above here I put in IRC_params.ExtSource the data that I
            % want in the format produced by IR_Curves
            disp('check');
            uparams.startDate = history_start_date;
            uparams.endDate = history_end_date;
            uparams.curveName = curveName;
            uparams.dataType = 'BvalData';
            uparams.DataFromMDS.createLog = false(1);
            uparams.DataFromMDS = DataFromMDS;
            uparams.DataFromMDS.fileMap{1,1} = 'MDS_BVAL_Curve.xlsx';
            U = Utilities(uparams);
            U.GetMdsData;
            IRC_params.ExtSource = U.Output;
        end
        IRcurves.(curveName) = IR_Curve(IRC_params);
    else
        eof = true(1); % assuming EOF when there is nothing in the field 'name'
    end
    
end % ~eof

% ******************** END OF IR CURVES OBJECTS READING *******************

%% ********************** SINGLE INDICES OBJECTS  *************************
% READING THE Investment Universe File, Single_Indices Sheet to build
% 'SingleIndex' objects (mainly needed within the instance of class
% External_Risk_Factors' to model invariants

sc_params.DataFromBBG = DataFromBBG;
sc_params.start_dt = history_start_date;
sc_params.end_dt = history_end_date;

clear sIndices;
SingleIdxTable = readtable(InvestmentUniverse_fileName,'Sheet',curves2beRead.SingleIndices);

L = size(SingleIdxTable,1);

eof = false(1);
rowNum = 0;

eof = false(1);
rowNum = 0;

while ~eof
    sc_params.ticker  = [];
    sc_params.isRate  = [];
    sc_params.InputRatesFormat  = [];
    sc_params.rate_type  = [];
    
    rowNum = rowNum + 1;
    if rowNum>L
        break;
    end
    
    indexName = cell2mat(table2cell(SingleIdxTable(rowNum,'name')));
    
    % check if the curve is in cdsCurvesList
    im = ismember(AllCurvesToBeGenerated,indexName);
    if sum(im)==0
        continue
    end
    
    if ~isempty(indexName)
        sc_params.ticker = cell2mat(table2cell(SingleIdxTable(rowNum,'ticker')));
        sc_params.isRate = cell2mat(table2cell(SingleIdxTable(rowNum,'isRate')));
        sc_params.InputRatesFormat = cell2mat(table2cell(SingleIdxTable(rowNum,'InputRatesFormat')));
        sc_params.rate_type = cell2mat(table2cell(SingleIdxTable(rowNum,'rate_type')));
        sc_params.int_ext = cell2mat(table2cell(SingleIdxTable(rowNum,'Internal_External_RF')));
        sc_params.ToBeIncludedInInvariants = cell2mat(table2cell(SingleIdxTable(rowNum,'ToBeIncludedInInvariants')));
        
        sIndices.(indexName) = SingleIndex(sc_params);
        
    else
        eof = true(1); % assuming EOF when there is nothing in the field 'name'
    end
    
end % ~eof

% **************** END OF SINGLE INDICES OBJECTS READING  *****************


%% ************************ BOOTSTRAPPED CURVES  **************************
% builds all curves structures (to be used for bootstrappings)
% (this set must comprise all the curves used in the Investment Universe)
curveParam.configFile = configFile4IrCurvesBtStrap;
curveParam.valDate = [];

bparams.DataFromBBG = DataFromBBG;
bparams.StartDate = history_start_date;
bparams.EndDate = history_end_date;
bparams.historyPath = [cd,'\HistBstrappedCurves\']; % subdir where hist bootstrapped curves are stored

Curves2BeBtStrapped = readtable(InvestmentUniverse_fileName,'Sheet',curves2beRead.IRC2beBtStrapped);
L = size(Curves2BeBtStrapped,1);

eof = false(1);
rowNum = 0;

while ~eof
    
    rowNum = rowNum + 1;
    if rowNum>L
        break;
    end
    
    curveName = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'name')));
    
    % check if the curve is in AllCurvesToBeGenerated
    im = ismember(AllCurvesToBeGenerated,curveName);
    if sum(im)==0
        continue
    end
    
    if ~isempty(curveName)
        
        % IDENTIFY THE STRUCTURE OF THE CURVE TO BE BOOTSTRAPPED
        bparams.CurveID{1} = curveName;
        bparams.BBG_tickerRoot = [];
        bstrapParam.depoDC = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'depoDC')));
        bstrapParam.futureDC = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'futureDC')));
        swapDCtmp = (table2cell(Curves2BeBtStrapped(rowNum,'swapDC')));
        splitted = regexp(swapDCtmp,',','split');
        bstrapParam.swapDC(1,:) = str2num(cell2mat(splitted{1}(1)));
        bstrapParam.swapDC(1,2) = str2num(cell2mat(splitted{1}(2)));
        
        bparams.rates_type = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'rates_type')));
        bparams.rates_input_format = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'rates_input_format')));
        bparams.int_ext = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'Internal_External_RF')));
        bparams.ToBeIncludedInInvariants = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'ToBeIncludedInInvariants')));
        bparams.tenors_key_mapping = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'tenors_key_mapping')));
        bparams.invertBbgSigns = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'invertBbgSigns')));
        bparams.bootPillChoice = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'PillarsStructure')));
        
        R = HistoricalRateCurve(bparams, curveParam, bstrapParam);
        
        SWAP_curves.(curveName) = R.rateCurve.(curveName);
        % *******
        % *******
        
    else
        eof = true(1); % assuming EOF when there is nothing in the field 'name'
    end
    
    
end % ~eof
% ********************** END OF BOOTSTRAPPED CURVES NEW  ******************

%% ************************* VOLATILITY  OBJECTS **************************
clear VolaSurfaces;
VolaEquityOptTable = readtable(InvestmentUniverse_fileName,'Sheet',curves2beRead.VolaEquity);

L = size(VolaEquityOptTable,1);

eof = false(1);
rowNum = 0;

eof = false(1);
rowNum = 0;

while ~eof
    underlying_ticker  = [];
    optionRootTicker = [];
    min_strike_increase = [];
    dec_digits = [];
    rfr = [];
    divYield = [];
    volaData_source = [];
    Internal_External_RF = [];
    ToBeIncludedInInvariants = [];
    
    rowNum = rowNum + 1;
    if rowNum>L
        break;
    end
    
    volaName = cell2mat(table2cell(VolaEquityOptTable(rowNum,'name')));
    
    % check if the curve is in cdsCurvesList
    im = ismember(AllCurvesToBeGenerated,volaName);
    if sum(im)==0
        continue
    end
    
    % temp to exclude items already in VolaSurfaces after an error
    % however can be left here since it will simple exclude already modeled
    % objects)
    % VolaSNames = fieldnames(VolaSurfaces);
    % im = ismember(VolaSNames,volaName);
    % if sum(im)>0
    %    continue
    %end
    
    
    if ~isempty(volaName)
        underlying_ticker = cell2mat(table2cell(VolaEquityOptTable(rowNum,'underlying_ticker')));
        optionRootTicker = cell2mat(table2cell(VolaEquityOptTable(rowNum,'optionRootTicker')));
        
        min_strike_increase = cell2mat(table2cell(VolaEquityOptTable(rowNum,'min_strike_increase')));
        dec_digits = cell2mat(table2cell(VolaEquityOptTable(rowNum,'dec_digits')));
        rfr = cell2mat(table2cell(VolaEquityOptTable(rowNum,'rfr')));
        divYield = cell2mat(table2cell(VolaEquityOptTable(rowNum,'yield')));
        volaData_source = cell2mat(table2cell(VolaEquityOptTable(rowNum,'volaData_source')));
        Internal_External_RF = cell2mat(table2cell(VolaEquityOptTable(rowNum,'Internal_External_RF')));
        ToBeIncludedInInvariants = cell2mat(table2cell(VolaEquityOptTable(rowNum,'ToBeIncludedInInvariants')));
        
        % for MDS surfaces the range of hist date is the same as the one
        % used to generate the price history for all of the assets. For BBG
        % tyoe vola we model the shape of the surface using a few days of
        % data (as defined in Initial parameters 'IV_hdate' struct array)
        % otherwise it would take too much time and risk to exceed the
        % daily limit for BBG data
        if strcmp(volaData_source,'BBG')
            ImpliedVolaDatesRange = IV_hdate;
        elseif strcmp(volaData_source,'MDS')
            ImpliedVolaDatesRange.start = history_start_date;
            ImpliedVolaDatesRange.end = history_end_date;
        end
        VolaSurfaces.(volaName) = ...
            ImpliedVola_Surface(DataFromBBG,DataFromMDS,underlying_ticker,optionRootTicker,ImpliedVolaDatesRange,min_strike_increase,dec_digits,rfr,divYield,volaData_source);
        VolaSurfaces.(volaName).CalibrateSkewParams(1);
        VolaSurfaces.(volaName).intext = Internal_External_RF;
        VolaSurfaces.(volaName).ToBeIncludedInInvariants = ToBeIncludedInInvariants;
        % to plot the surface based on estimated skew/ttm parameters
        % underlyingATMsVolas = 0.20
        % VolaSurfaces.V_SX5E.DrawEstimatedSurface(underlyingATMsVolas,3000);
    else
        eof = true(1); % assuming EOF when there is nothing in the field 'name'
    end
    
end % ~eof

% % ******************** END OF VOLA SURFACES READING  ********************


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








