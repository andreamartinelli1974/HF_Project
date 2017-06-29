function [ DAA_params, InvestmentUniverse_fileName, InvestmentUniverse_sheetName, history_start_date,...
    history_end_date,history_start_date_YC, start_dt_num, end_dt, ...
    IV_hdate,MinAbsShort_Exposure,MaxAbsLong_Exposure, ...
    granularity,params_Equity_ret,params_cds_ret,additional_params,curves2beRead,configFile4IrCurvesBtStrap] = InitialParameters( desiredSetup )


% lists of CDD/IR curves and Single indices available
curves2beRead.CDS_SheetName = ['CDS_Curves']; % Sheet of Investment_Universe (empty if no CDS curves are needed)
curves2beRead.IR_SheetName = ['IR_Curves'];   % same for IR curves
curves2beRead.SingleIndices = ['Single_Indices']; % ... and single indices
curves2beRead.IRC2beBtStrapped = ['IRC2beBtStrapped']; % ... and curves to be used for bootstrapping
curves2beRead.VolaEquity = ['VolaEquity']; % ... and implied vola surfaces for equity options

configFile4IrCurvesBtStrap = ['Curve_Structure.xlsx'];

DAA_params.SetUpName = desiredSetup;

switch desiredSetup
 
case 'HFunds'
        
        InvestmentUniverse_fileName = ['Regressors.xls'];
        InvestmentUniverse_sheetName = ['Regressors'];
        
        % when the BackTestOnly flag is true no optimization takes place and the
        % allocation is assumed to be the one setup by the upper bound limit
        DAA_params.BackTestOnly = false(1); % false(1);
         
        % Dynamic AA1 params
        
        % the 'scenarioAnalysisRun' flag is usually activated when the
        % backtesting history is short, since the idea is to compare just
        % the most recent allocation under the prior with the most recent
        % allocation under the posterior probability. When the backtesting
        % hiostory is long adding this computetiuon can be a significant
        % burden in terms of total comupational times
        DAA_params.scenarioAnalysisRun = false(1); % true(1) to include an instance of the class RiskAnalytics in the 'log' of each optimization
        DAA_params.MinDate4scenarioAnalysisRun = []; % date in mm/dd/yyyy format: all the assets having an history starting after this date will be excluded when the previous flag is set to True
        DAA_params.SubjectiveViewsScenarios = [];
        
        % *********  UPDATE HIST DATES SETTINGS  BEFORE RUNNING  **********
        % dates for the historical dataset for assets in Universe
        history_start_date = '01/01/2000';
        history_end_date =  datestr(today-1,'mm/dd/yyyy'); %['06/07/2017']; % **** DA AGGIORNARE AD OGNI RE-RUN ****
        % Yield curves historical dataset start date
        history_start_date_YC = '06/30/2006';
        % dates for the hist windows used with drivers of quant signals
        start_dt_num = datenum(['01/01/1995']);
        end_dt = datestr(today-1,'mm/dd/yyyy'); % datenum(['06/07/2017']);   % **** DA AGGIORNARE AD OGNI RE-RUN ****
        % Implied Vola Surface params estimation window
        IV_hdate.start = datestr(today-2,'mm/dd/yy');
        IV_hdate.end = datestr(today-1,'mm/dd/yy');
        % *****************************************************************
        
        DAA_params.StartDay =  ['01/10/2011']; % date of the first investment decision (or the scenario analysis / single subj view optim)
        DAA_params.Horizon = 5./252; % expressed in years
        DAA_params.NumPortf = 50;
        DAA_params.Budget = 100000000;
        DAA_params.use_rank_corr = 0;
        DAA_params.Hcharts = 0; % = 1 to have prices and invariants returns distrib at horizon plotted
        DAA_params.tails_modelling_charts = 0;
        DAA_params.calibrateTails = true(1); % True for tails'thresholds calibration; if set to False then the value set in ConstantTailsThreshold is used to set the 2 thresholds
        DAA_params.CentralValuesModel = ['kernel']; % 'kernel' or 'ecdf' to model the central piece of the invariants marginal distributions
        DAA_params.ConstantTailsThreshold = 0.07;
        DAA_params.ConfLevel4TailCutoffOptim = 0.90; % confidence level to be used within singleES_left and singleES_right function to optimize the threshold level in GPD modeling
        DAA_params.copula_sim = 1; % 0 to completely jump the EVT estimation and simulation process
        DAA_params.simbound = 50; % cap and floor the simulations to the simbound times the maximum and minimum of realized data
        DAA_params.ProbThreshold4MC = 1./10000; % probability threshold used to exclude simulated outcomes (to prevent instability when the variance is not finite)
         % no of simulations when projecting to the investment horizon (values haigher then 10000 can create problems to the linearized
        % in M-ES optim (due to the growing size of the constraints matrix, BUT, on the other side, when implementing views (extreme) it is important
        % to have enough density in the tails for stability of results. Heuristically 100k would be good, but requires much more computational timne)
        
        % IMPORTANT: the 2 parameters 'copula_NoSim' and
        % 'ProjectionResampling_numsim' must be chosen together. It is
        % important the ratio between the 2s. 'copula_NoSim' is the total
        % number of simulated jolint scenarios.
        % 'ProjectionResampling_numsim' is how they no of simulation
        % resemapled from the simulations above for each day within the
        % inmvestment horizon. If ProjectionResampling_numsim is too small compared to copula_NoSim
        % this will obviously increase the variance of all stats estimated
        % on the sample (e.g. projected mean return)
        DAA_params.copula_NoSim = 50000;
        DAA_params.ProjectionResampling_numsim = 49000; 
        
        DAA_params.InvariantBackwardsProxy = false(1); % to extend backwards in time the invariants history when the data are too short
        DAA_params.StartDayInvariantsBackwards = ['01/01/2007']; % if InvariantBackwardsProxy = true. this is the date to check if an invariant is too short
        
        DAA_params.FullHist4TailsEstimation = false(1); % to use always the full available history (at each time) to model the tails
        % length of the hist distrib to be used at each point in time (0 to use the full past dataset).
        % When using QuantViews they are based on full available history up to the
        % current time anyway
        DAA_params.Priori_MovWin = 0; %500; %0; %250;
        % 'UseBackWardInvariants4Modeling' must be set to true(1) when we
        % want to use the extended invartiants dataset (including backward
        % estimated invariants) for modeling purposes. In this case any
        % 'Priori_MovWin' different than zero will be ignored and the whole
        % dataset will be used for modeling/simulation purposes. 
        % Obviously this option can work only if the
        % 'InvariantBackwardsProxy' has been set to true(1). The use of the
        % extended dataset is limited to modeling/simulation purposes and
        % will not affect the backtested history that will always be based
        % on realizedc mkt prices
        % WARNING: *** FORWARD BIAS INTRODUCED HERE: USE WITH CARE ***
        DAA_params.UseBackWardInvariants4Modeling = false(1);
        % Priori_IntialLookback is used only when Priori_MovWin = 0 and
        % sets up the t0: the first point in time fro, ehich the expanding
        % window will start (always)
        DAA_params.Priori_IntialLookback = 300;
        DAA_params.MinFreqOfPriorUpdate = 11; % ******  min frequency for updating  Hist Info
        DAA_params.min_interval_changes = 10;
        
        % ****** VIEWS WEIGHTS *****
        DAA_params.QuantSignals = false(1); %false(1); %     ;    ;   =  to take into account signals generated through QuantSignals class (simplified version for now))
        DAA_params.QuantStrategyName = ['Signal_Gen_1']; %['EG_Coint']; %  used only if .QuantSignals is True
        DAA_params.SubjectiveViews = false(1); % true(1); % at the moment this flag is alternative to DAA_params.QuantSignals
        % weights for subjective, quant and prior (obviously must be consistent
        % with the flags above (enforce checks). They must sum up to 1
        DAA_params.SubjectiveViewsWeight = 0.00;
        DAA_params.QViewsWeight = 0;
        DAA_params.PriorWeight = 1; % weight ([0 to 1]) assigned to the historical distribution of risk factors (the remainder is assigned to the views)
        
        % 1 to use the copula simulated corr matrix; 0 to use the original corr matrix when performing
        % inverse CDF calc from  the copula space
        DAA_params.copula_rho = 1;
        DAA_params.MaxRisk4FullFrontier_MV = 0.03; % used in MV eff frontier when the problem is unbounded
        DAA_params.resampling_EffFront.flag = false(1); %true(1);  % for EF resampling (to reduce estimation risk): true or false. If true the estimation horizon must be > 1
        DAA_params.resampling_EffFront.nsim = 200; % used if the flag above = 1: this is the no of 'resampled' efficient frontiers
        DAA_params.ExpectedShortfall_EF = 0; % = 1 to use ES Eff Front (NOT WITH RESAMPLING FOR NOW) - 0 for the traditional MV space
        % the fields below are taken into account only when DAA_params.ExpectedShortfall_EF == 1
        % (only one of them can be 'active', that is not empty). Keep all the
        % fields below empty to get the full EF in Mean-ES space
        DAA_params.ExpectedShortfall_EF_options.SingleRet = []; % to optimize ES given a single return expectation (put here the given return)
        DAA_params.ExpectedShortfall_EF_options.SingleES = [];  % to optimize expected return given a single ES limit (put here gicen ES)
        DAA_params.ExpectedShortfall_EF_options.GMES = [];      % to get the Global minimum ES portfolio (=1 to get GMES portfolio)
        DAA_params.ExpectedShortfall_EF_options.ConfLevel = 0.95;
        DAA_params.ExpectedShortfall_EF_options.LinearizedOptimizer = true(1); % only for .GMES=1: true(1) to use the linearized version of the optimizer (see doc)
        DAA_params.ExpectedShortfall_EF_options.LinProgAlgo = 'dual-simplex'; % 'dual-simplex' or 'interior-point' (used only when .LinearizedOptimizer is True)
        DAA_params.ExpectedShortfall_EF_options.MaxRisk4FullES_Frontier = 0.03; % to be used for Full Efficient Frontier optim. This value will be used as the highest risk  target (must be consistent with the definition - e.g. STD or ES of risk at horizon)
        DAA_params.ExpectedShortfall_EF_options.onFullHistDataSet = false(1); % not used systematically for now: the idea is to give the option to calc ES on an hist dataset that ius the one used for regulatory purposes
        
        % constrain sum of the weights in the optim process to be 'TotWgt'
        DAA_params.ConstrainedTotWgts = []; % a number that will represent the sum of all weights (e.g. 1 for 100%); [] for no constraint on tot weights
        DAA_params.MaxLongShortExposure = [4,-4]; % to constrain max long/short exposure (e.g. [4,-4] for +/- 400%)
        
        % absolute long/short limits (active when no limits are set within single
        % assets)
        MinAbsShort_Exposure = -2;
        MaxAbsLong_Exposure = 2;
        
        DAA_params.AA_OptimChangeTarget.flag  = true(1);
        DAA_params.AA_OptimChangeTarget.limit = 2;
        DAA_params.AA_OptimChangeTarget.step = 0.01;
        
        granularity = 'DAILY';
        
        params_Equity_ret.lag = 1;
        params_Equity_ret.pct = 1;
        params_Equity_ret.logret = 1;
        params_Equity_ret.EliminateFlag = 0;
        params_Equity_ret.last_roll = 0;
        params_Equity_ret.ExtendedLag = 3;
        
        
        params_cds_ret.lag = 1;
        params_cds_ret.pct = 0;
        params_cds_ret.logret = 0;
        params_cds_ret.EliminateFlag = 0;
        params_cds_ret.last_roll = 1; % to remove rolling dates returns (stored in CDS.CDS_RollDates)
        params_cds_ret.ExtendedLag = 3;
        
        % **********
        additional_params.quickCDS = true(1); % IMPORTANT: set to TRUE to perfoprm quick repricing on hist horizon (see notes to the Bloomberg_GetHistory method)
        additional_params.quickCDS_SDV01_recalcFreq = 100; % freq of the SDV01 recalc when quickCDSis True (e.g. 10 means that every 10 days it is recalculated to reduce the impact of  convexity)
       
end
end % function 