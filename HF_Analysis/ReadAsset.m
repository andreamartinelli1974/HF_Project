classdef ReadAsset < handle
    % this class extract the assets data from Bloomberg or MDS.
    % INPUT:
    % RAparams collect the input params needed
    % RAparams.AL = struct with the list og asset to be extracted:
    %               AL.cdsList  = list of CDS obj names
    %               AL.irList   = list of IR obj names
    %               AL.ircbList = list of IRC to be Boostrapped obj names
    %               AL.sindList = list of Single Indices obj names
    %               AL.VolaList = list of Volatility obj names
    %               AL.AllCurvesToBeGenerated = list of all names
    %
    % RAparams.filename = usual xls file with assets details
    % RAparams.path = path to save bootstrapped curves
    % RAparams.configFile4IRCB = file for IRCB configuration
    % RAparams.history_start_date = start date for the data extractions
    % RAparams.history_end_date = end date
    % RAparams.DataFromBBG = struct with BBG details
    % RAparams.DataFromMDS = struct with MDS details
    % RAparams.useVolaSaved = struct with flag and path to use saved vola
 
    
    
    properties
        InputParams;
        DataFromBBG;
        DataFromMDS;
        Dates;
        Path;
        Assets;
        filename;
        File4IRCB;
        useVolaSaved;
    end
    
    methods
        %% CONSTRUCTOR %%
        function RA = ReadAsset(RAparams)
            RA.InputParams = RAparams.AL; 
            RA.filename = RAparams.filename;
            RA.DataFromBBG = RAparams.DataFromBBG;
            RA.DataFromMDS = RAparams.DataFromMDS;
            RA.Dates.startDate = RAparams.history_start_date;
            RA.Dates.endDate = RAparams.history_end_date;
            RA.Path = RAparams.path;
            RA.File4IRCB = RAparams.configFile4IRCB;
            RA.useVolaSaved = RAparams.useVolaSaved;
            
            RA.getAssets;
            
        end %constructor
        
        
        %% READING FUNCTIONS %%
        
        function getAssets(RA)
            RA.getCDS;
            RA.getIRCurves;
            RA.getSingleIDX;
            RA.getBTSRCurve;
            RA.getVolaObj;
        end
        
        function getCDS(RA)
            % ************************** CDS CURVES OBJECTS *************************
            clear CDS_curves;
            
            CDS_Curves.sheetName   = 'CDS_Curves';
            CDS_Curves.table       = readtable(RA.filename ,'Sheet',CDS_Curves.sheetName);
            
            l = size(CDS_Curves.table,1);
            eof = false(1);
            rowNum = 0;
            
            while ~eof
                
                paramsCDS = [];
                rowNum = rowNum + 1;
                if rowNum>l
                    break;
                end
                
                % check if the curve is in RA.InputParams.cdsList
                curveName = cell2mat(table2cell(CDS_Curves.table(rowNum,'name')));
                im = ismember(RA.InputParams.AllCurvesToBeGenerated,curveName);
                if sum(im)==0
                    continue
                end
                
                if ~isempty(curveName)
                    
                    paramsCDS.thresholdForInterpolating = cell2mat(table2cell(CDS_Curves.table(rowNum,'thresholdForInterpolating')));
                    
                    paramsCDS.int_ext = cell2mat(table2cell(CDS_Curves.table(rowNum,'Internal_External_RF')));
                    paramsCDS.RatesInputFormat = cell2mat(table2cell(CDS_Curves.table(rowNum,'rates_input_format')));
                    paramsCDS.ToBeIncludedInInvariants = cell2mat(table2cell(CDS_Curves.table(rowNum,'ToBeIncludedInInvariants')));
                    paramsCDS.tenorMapType = cell2mat(table2cell(CDS_Curves.table(rowNum,'tenors_key_mapping')));
                    
                    curveMaturities = table2cell(CDS_Curves.table(rowNum,'maturities'));
                    curveMaturitiesIntoCell=regexp(curveMaturities,',','split');
                    ticker = cell2mat(table2cell(CDS_Curves.table(rowNum,'ticker')));
                    
                    nmat = numel(curveMaturitiesIntoCell{1});
                    % build the 'curve_tickers' fields: tickers of all points in the curve
                    % (the logic is the same as the one applied by Bloomberg)
                    clear curve_tickers;
                    for k=1:nmat
                        curve_tickers{k,1} = [ticker,' ',cell2mat(curveMaturitiesIntoCell{1}(k)),' Corp'];
                    end
                    
                    paramsCDS.excel_spread_input.flag = (cell2mat(table2cell(CDS_Curves.table(rowNum,'excel'))));
                    
                    if paramsCDS.excel_spread_input.flag == 1 % if data are in xls file
                        
                        fname = cell2mat(table2cell(CDS_Curves.table(rowNum,'fileName')));
                        
                        ShName = cell2mat(table2cell(CDS_Curves.table(rowNum,'sheetname')));
                        paramsCDS.extrapolate = logical(cell2mat(table2cell(CDS_Curves.table(rowNum,'extrapolate'))));
                        paramsCDS.excel_spread_input.manual_ticker = ShName;
                        paramsCDS.excel_spread_input.firstCDScol = cell2mat(table2cell(CDS_Curves.table(rowNum,'firstColInXlsFile'))); % column where spreads vectors start in the input file
                        paramsCDS.excel_spread_input.lastCDScol =  cell2mat(table2cell(CDS_Curves.table(rowNum,'lastColInXlsFile'))); % column where spreads vectors start in the input file
                        sheetMain = exlFile(name2Num(fname)).Sheets.Item(ShName); % name of the sheet in the xls file
                        dat_range = GetXlsRange(sheetMain,cell2mat(table2cell(CDS_Curves.table(rowNum,'dat_range'))));
                        paramsCDS.excel_spread_input.inputMatrix = sheetMain.Range(dat_range).value;
                        cdsPriceType = [];
                        
                    elseif paramsCDS.excel_spread_input.flag == 0 % data from Bloomberg
                        paramsCDS.extrapolate = logical(cell2mat(table2cell(CDS_Curves.table(rowNum,'extrapolate'))));
                        cdsPriceType = cell2mat(table2cell(CDS_Curves.table(rowNum,'price_used')));
                        
                    else %data from MDS
                        ticker = cell2mat(table2cell(CDS_Curves.table(rowNum,'tickerMDS')));
                        paramsCDS.extrapolate = logical(cell2mat(table2cell(CDS_Curves.table(rowNum,'extrapolate'))));
                        clear curve_tickers;
                        curve_tickers = {ticker};
                        paramsCDS.tickerMDS = ticker;
                        paramsCDS.docclause = cell2mat(table2cell(CDS_Curves.table(rowNum,'MDS_DOCCLAUSE')));
                        paramsCDS.curveMaturities = curveMaturitiesIntoCell{1};
                        paramsCDS.DataFromMDS = RA.DataFromMDS;
                        cdsPriceType = [];
                    end
                    
                    RA.Assets.CDS_curves.(curveName) = CDS_Curve(ticker,RA.DataFromBBG,curve_tickers,RA.Dates,cdsPriceType,paramsCDS);
                else
                    eof = true(1); % assuming EOF when there is nothing in the field 'name'
                end
                
            end % ~eof
            
            % Quit(exl);
            % delete(exl);
            % clear exlFile;
            
            [taskstate, taskmsg] = system('tasklist|findstr "EXCEL.EXE"');
            if ~isempty(taskmsg)
                status = system('taskkill /F /IM EXCEL.EXE');
            end
            
            clear CDS_curves;
        end %function getCDS
        
        function getIRCurves(RA)
            % ************************ IR CURVES OBJECTS  ****************************
            clear IR_Curves;
            
            IR_Curves.sheetName = 'IR_Curves';
            IR_Curves.table = readtable(RA.filename ,'Sheet',IR_Curves.sheetName);
            
            l = size(IR_Curves.table,1);
            
            eof = false(1);
            rowNum = 0;
            
            while ~eof
                
                paramsIR = [];
                extCdataparams = [];
                rowNum = rowNum + 1;
                if rowNum>l
                    break;
                end
                paramsIR.StartDate = RA.Dates.startDate;
                paramsIR.EndDate = RA.Dates.endDate;
                paramsIR.DataFromBBG = RA.DataFromBBG;
                
                curveName = cell2mat(table2cell(IR_Curves.table(rowNum,'name')));
                
                % check if the curve is in irList
                im = ismember(RA.InputParams.AllCurvesToBeGenerated,curveName);
                if sum(im)==0
                    continue
                end
                
                if ~isempty(curveName)
                    paramsIR.CurveID = cell2mat(table2cell(IR_Curves.table(rowNum,'curve_id')));
                    paramsIR.ctype = cell2mat(table2cell(IR_Curves.table(rowNum,'ctype')));
                    paramsIR.TenorsKeyMapping_choice = cell2mat(table2cell(IR_Curves.table(rowNum,'tenors_key_mapping')));
                    paramsIR.BBG_YellowKey = cell2mat(table2cell(IR_Curves.table(rowNum,'bbg_yellowKey')));
                    paramsIR.invertBbgSigns = logical(cell2mat(table2cell(IR_Curves.table(rowNum,'invertBbgSigns'))));
                    paramsIR.RatesInputFormat = (cell2mat(table2cell(IR_Curves.table(rowNum,'rates_input_format'))));
                    paramsIR.RatesType = (cell2mat(table2cell(IR_Curves.table(rowNum,'rates_type'))));
                    paramsIR.int_ext = cell2mat(table2cell(IR_Curves.table(rowNum,'Internal_External_RF')));
                    paramsIR.ToBeIncludedInInvariants = cell2mat(table2cell(IR_Curves.table(rowNum,'ToBeIncludedInInvariants')));
                    paramsIR.BBG_tickerRoot = cell2mat(table2cell(IR_Curves.table(rowNum,'BBG_tickerRoot')));
                    
                    extCdataparams.XlsCurve.FileName = cell2mat(table2cell(IR_Curves.table(rowNum,'xlsCurve_filename')));
                    extCdataparams.XlsCurve.SheetName = cell2mat(table2cell(IR_Curves.table(rowNum,'xlsCurve_sheetname')));
                    
                    if strcmp(paramsIR.ctype,'file') &~isempty(extCdataparams.XlsCurve.FileName) % need to read curve's data from xls file
                        U = Utilities(extCdataparams);
                        U.ReadCurveDataFromXls;
                        paramsIR.ExtSource = U.Output;
                    elseif strcmp(paramsIR.ctype,'MDS')
                        % *** INPUT from Mkt Data Server ***
                        % as above here I put in IRC_params.ExtSource the data that I
                        % want in the format produced by IR_Curves
                        disp('check');
                        uparams.startDate = history_start_date;
                        uparams.endDate = history_end_date;
                        uparams.curveName = curveName;
                        uparams.dataType = 'BvalData';
                        uparams.DataFromMDS.createLog = false(1);
                        uparams.DataFromMDS = RA.DataFromMDS;
                        uparams.DataFromMDS.fileMap{1,1} = 'MDS_BVAL_Curve.xlsx';
                        U = Utilities(uparams);
                        U.GetMdsData;
                        paramsIR.ExtSource = U.Output;
                    end
                    RA.Assets.IR_Curves.(curveName) = IR_Curve(paramsIR);
                    RA.Assets.IR_Curves.(curveName).Curve.tenors_yf = RA.Assets.IR_Curves.(curveName).Curve.tenors_yf';
                else
                    eof = true(1); % assuming EOF when there is nothing in the field 'name'
                end
                
                
            end % ~eof
            clear IR_Curves;
        end %function getIRCurves
        
        function getSingleIDX(RA)
            % ********************** SINGLE INDICES OBJECTS  *************************
            paramsSI.DataFromBBG = RA.DataFromBBG;
            paramsSI.start_dt = RA.Dates.startDate;
            paramsSI.end_dt = RA.Dates.endDate;
            
            clear Single_Indices;
            Single_Indices.sheetName = 'Single_Indices';
            Single_Indices.table = readtable(RA.filename ,'Sheet', Single_Indices.sheetName);
            
            l = size(Single_Indices.table,1);
            
            eof = false(1);
            rowNum = 0;
            
            eof = false(1);
            rowNum = 0;
            
            while ~eof
                paramsSI.ticker  = [];
                paramsSI.isRate  = [];
                paramsSI.InputRatesFormat  = [];
                paramsSI.rate_type  = [];
                
                rowNum = rowNum + 1;
                if rowNum>l
                    break;
                end
                
                indexName = cell2mat(table2cell(Single_Indices.table(rowNum,'name')));
                
                % check if the curve is in sindList
                im = ismember(RA.InputParams.AllCurvesToBeGenerated,indexName);
                if sum(im)==0
                    continue
                end
                
                if ~isempty(indexName)
                    paramsSI.ticker = cell2mat(table2cell(Single_Indices.table(rowNum,'ticker')));
                    paramsSI.isRate = cell2mat(table2cell(Single_Indices.table(rowNum,'isRate')));
                    paramsSI.InputRatesFormat = cell2mat(table2cell(Single_Indices.table(rowNum,'InputRatesFormat')));
                    paramsSI.rate_type = cell2mat(table2cell(Single_Indices.table(rowNum,'rate_type')));
                    paramsSI.int_ext = cell2mat(table2cell(Single_Indices.table(rowNum,'Internal_External_RF')));
                    paramsSI.ToBeIncludedInInvariants = cell2mat(table2cell(Single_Indices.table(rowNum,'ToBeIncludedInInvariants')));
                    
                    RA.Assets.Single_Indices.(indexName) = SingleIndex(paramsSI);
                    
                else
                    eof = true(1); % assuming EOF when there is nothing in the field 'name'
                end
                
            end % ~eof
            clear Single_Indices;
        end %function getSingleIDX
        
        function getBTSRCurve(RA)
            % ************************ BOOTSTRAPPED CURVES  **************************
            % builds all curves structures (to be used for bootstrappings)
            % (this set must comprise all the curves used)
            
            curveParam.configFile = RA.File4IRCB;
            curveParam.valDate = [];
            
            paramsBTS.DataFromBBG = RA.DataFromBBG;
            paramsBTS.StartDate = RA.Dates.startDate;
            paramsBTS.EndDate = RA.Dates.endDate;
            paramsBTS.historyPath = RA.Path;
            
            IRC2beBtStrapped.sheetName= 'IRC2beBtStrapped';
            Curves2BeBtStrapped = readtable(RA.filename ,'Sheet',IRC2beBtStrapped.sheetName);
            l = size(Curves2BeBtStrapped,1);
            
            eof = false(1);
            rowNum = 0;
            
            while ~eof
                
                rowNum = rowNum + 1;
                if rowNum>l
                    break;
                end
                
                curveName = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'name')));
                
                % check if the curve is in ircbList
                im = ismember(RA.InputParams.AllCurvesToBeGenerated,curveName);
                if sum(im)==0
                    continue
                end
                
                if ~isempty(curveName)
                    
                    % IDENTIFY THE STRUCTURE OF THE CURVE TO BE BOOTSTRAPPED
                    paramsBTS.CurveID{1} = curveName;
                    paramsBTS.BBG_tickerRoot = [];
                    bstrapParam.depoDC = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'depoDC')));
                    bstrapParam.futureDC = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'futureDC')));
                    swapDCtmp = (table2cell(Curves2BeBtStrapped(rowNum,'swapDC')));
                    splitted = regexp(swapDCtmp,',','split');
                    bstrapParam.swapDC(1,:) = str2double(cell2mat(splitted{1}(1)));
                    bstrapParam.swapDC(1,2) = str2double(cell2mat(splitted{1}(2)));
                    
                    paramsBTS.rates_type = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'rates_type')));
                    paramsBTS.rates_input_format = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'rates_input_format')));
                    paramsBTS.int_ext = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'Internal_External_RF')));
                    paramsBTS.ToBeIncludedInInvariants = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'ToBeIncludedInInvariants')));
                    paramsBTS.tenors_key_mapping = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'tenors_key_mapping')));
                    paramsBTS.invertBbgSigns = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'invertBbgSigns')));
                    paramsBTS.bootPillChoice = cell2mat(table2cell(Curves2BeBtStrapped(rowNum,'PillarsStructure')));
                    
                    R = HistoricalRateCurve(paramsBTS, curveParam, bstrapParam);
                    
                    RA.Assets.IRC2beBtStrapped.(curveName) = R.rateCurve.(curveName);
                    RA.Assets.IRC2beBtStrapped.(curveName).Curve.tenors_yf = RA.Assets.IRC2beBtStrapped.(curveName).Curve.tenors_yf';
                else
                    
                    eof = true(1); % assuming EOF when there is nothing in the field 'name'
                end
                
            end % ~eof
            
        end %function getBTSRCurve
        
        function getVolaObj(RA)
            
            clear VolaSurfaces;
            VolaEquityOpt.Sheet = 'VolaEquity';
            VolaEquityOpt.Table = readtable(RA.filename,'Sheet',VolaEquityOpt.Sheet);
            
            L = size(VolaEquityOpt.Table,1);
            
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
                
                volaName = cell2mat(table2cell(VolaEquityOpt.Table(rowNum,'name')));
                
                % check if the curve is in cdsCurvesList
                im = ismember(RA.InputParams.AllCurvesToBeGenerated,volaName);
                if sum(im)==0
                    continue
                end
                
                
                if ~isempty(volaName)
                    underlying_ticker = cell2mat(table2cell(VolaEquityOpt.Table(rowNum,'underlying_ticker')));
                    optionRootTicker = cell2mat(table2cell(VolaEquityOpt.Table(rowNum,'optionRootTicker')));
                    
                    min_strike_increase = cell2mat(table2cell(VolaEquityOpt.Table(rowNum,'min_strike_increase')));
                    dec_digits = cell2mat(table2cell(VolaEquityOpt.Table(rowNum,'dec_digits')));
                    rfr = cell2mat(table2cell(VolaEquityOpt.Table(rowNum,'rfr')));
                    divYield = cell2mat(table2cell(VolaEquityOpt.Table(rowNum,'yield')));
                    volaData_source = cell2mat(table2cell(VolaEquityOpt.Table(rowNum,'volaData_source')));
                    Internal_External_RF = cell2mat(table2cell(VolaEquityOpt.Table(rowNum,'Internal_External_RF')));
                    ToBeIncludedInInvariants = cell2mat(table2cell(VolaEquityOpt.Table(rowNum,'ToBeIncludedInInvariants')));
                    
                    % for MDS surfaces the range of hist date is the same as the one
                    % used to generate the price history for all of the assets. For BBG
                    % tyoe vola we model the shape of the surface using a few days of
                    % data (as defined in Initial parameters 'IV_hdate' struct array)
                    % otherwise it would take too much time and risk to exceed the
                    % daily limit for BBG data
                    if strcmp(volaData_source,'BBG')
                        ImpliedVolaDatesRange = IV_hdate;
                    elseif strcmp(volaData_source,'MDS')
                        ImpliedVolaDatesRange.start = RA.Dates.startDate;
                        ImpliedVolaDatesRange.end = RA.Dates.endDate;
                    end
                    RA.Assets.VolaSurfaces.(volaName) = ...
                        ImpliedVola_Surface(RA.DataFromBBG,RA.DataFromMDS,underlying_ticker,optionRootTicker,ImpliedVolaDatesRange, ...
                        min_strike_increase,dec_digits,rfr,divYield,volaData_source, RA.useVolaSaved);
                    RA.Assets.VolaSurfaces.(volaName).CalibrateSkewParams(1);
                    RA.Assets.VolaSurfaces.(volaName).IntExt = Internal_External_RF;
                    RA.Assets.VolaSurfaces.(volaName).ToBeIncludedInInvariants = ToBeIncludedInInvariants;
                    % to plot the surface based on estimated skew/ttm parameters
                    % underlyingATMsVolas = 0.20
                    % VolaSurfaces.V_SX5E.DrawEstimatedSurface(underlyingATMsVolas,3000);
                else
                    eof = true(1); % assuming EOF when there is nothing in the field 'name'
                end
                
            end % ~eof
            
            
        end %function getVolaObj
        
%       
    end %methods
end

