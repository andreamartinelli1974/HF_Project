clc;
clear all;
close all;
rng('default');

pt = path;
userId = getenv('USERNAME');

addpath(['C:\Users\' userId '\Documents\GitHub\Utilities\'], ...
    ['C:\Users\' userId '\Documents\GitHub\Utilities\RatesUtilities\'], ...
    ['C:\Users\' userId '\Documents\GitHub\Utilities\Mds\'], ...
    ['C:\Users\' userId '\Documents\GitHub\Utilities\Pca\'], ...
    ['C:\Users\' userId '\Documents\GitHub\Utilities\Regressions\'], ...
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
    DataFromBBG.NOBBG = false(1); % if true (on machines with no BBG terminal), data are recovered from previously saved files (.save2disk option above)
end

% **************** STRUCTURE TO MARKET DATA SERVER DATA *******************
DataFromMDS.save2disk = false(1); % True to save Mds calls to disk for future retrieval
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


%% READ THE INPUT FILES & GET HEDGE FUND TRACK RECORDS

FundsPortfolio = readtable('FundsData.xls','Sheet','FUNDS');



%% GET THE VARIOUS REGRESSORS DATA


%% REGRESS ANY FUND - USING FLS













