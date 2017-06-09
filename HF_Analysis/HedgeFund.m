classdef HedgeFund < handle
    % Class to model hedge funds returns
    % assuming the fund has monthly data
    
    % Functions:
    
    % CreateTrackEst(obj,RegressObj): create the estimated track record using
    % the beta of a regression. MUST BE IMPLEMENTED
    
    % SetTableRet(obj,input): import TableRet
    % SetRegResult(obj,inputReg,recordReg): import RegResult and TestReg
    
    % GetRecords(obj): Output = {obj.Name,obj.Strategy,obj.Currency}
    % GetTrack(obj): Output = TrackNAV
    % GetROR(obj): Output = TrackROR
    % GetTrackEst(obj): Output = TrackEst
    % GetBackTest(obj): Output = BackTest
    % GetMtxOfRegressors(obj): Output = MtxOfRegressors 
    
    properties
        Name; %name of the fund
        UnivoCode; %Univocal code of the fund (internal code)
        Strategy; %strategy of the fund (if known)
        TrackNAV; %track record: matrix with 1st column=dates, 2nd column=NAVs
        TrackROR; %same as TrackNAV with 2nd column=RORs
        TrackEst; %same as TrackROR but with estimated ROR from the regression
        Currency; %currency of the fund (if known)
        RegResult; %struct with the regression result 
        Betas; %betas of the regression
        TestReg; %include the main info about teh type and quality of the performed regression
        BackTest; %Comparison between the cumulative original track record and the estimated one
        Output; %generic output for some function (to be better described)
    end
    
    %%%%%%%%%%%%%%%%%%%        Here starts the class methods
    methods
        
        function obj = HedgeFund(params)  %constructor
            
            obj.Name = params.fundName;
            obj.UnivoCode = params.univocode;
            obj.Strategy = params.fundStrategy;
            obj.TrackNAV = params.fundTrack;
            obj.TrackNAV(:,1)=x2mdate(obj.TrackNAV(:,1));
            obj.Currency = params.fundCcy;
            obj.TrackROR(:,2) = (obj.TrackNAV(2:end,2)./obj.TrackNAV(1:end-1,2)-1);
            obj.TrackROR(:,1) = obj.TrackNAV(2:end,1);   
            
        end
        
        function CreateTrackEst(obj,RegressObj,InSample)
            
            % gets all the main data from the Object of type HFRegression
            %obj.TrackEst=[];
            RegressObj.GetBetas;
            obj.Betas=RegressObj.Output;
            RegressObj.GetTableRet;
            tableret=RegressObj.Output;
            RegressObj.GetRolling;
            roll=RegressObj.Output;
            selected=size(obj.TrackROR,1)-size(tableret,1);
            
            obj.TrackEst = zeros(size(obj.Betas,1)-1,3);
            
            if InSample == false
                
                if size(obj.Betas,1)>1
                    
                    % calculatess the expected track record using the betas and
                    % the regressors ROR
                    for i=1:size(obj.Betas,1)-1
%                         if(i==size(obj.Betas,1)-1)
%                             disp('press any key')
%                             pause
%                         end
                            
                        obj.TrackEst(i,1:2)=obj.TrackROR(selected+roll+i,1:2);
                        obj.TrackEst(i,3)=table2array(tableret(i+roll,2:end-1))*table2array(obj.Betas(i,3:end))'+table2array(obj.Betas(i,2));
                    end
                end
            else
                if size(obj.Betas,1)>1
                    
                    % calculatess the expected track record using the betas and
                    % the regressors ROR
                    for i=1:size(obj.Betas,1)-1
                        obj.TrackEst(i,1:2)=obj.TrackROR(selected+roll+i-1,1:2);
                        obj.TrackEst(i,3)=table2array(tableret(i+roll-1,2:end-1))*table2array(obj.Betas(i,3:end))'+table2array(obj.Betas(i,2));
                    end
                end
            end
            % calculates the cumulative returns of the original fund track and of
            % the estimated track
            backtest=obj.TrackEst;
            backtest(:,2:end)=1+backtest(:,2:end);
            backtest(:,2:end)=cumprod(backtest(:,2:end),1);
            obj.BackTest=backtest;
            
            
        end
       
        
        % Set Functions, to set different properties of the class from
        % outside (e.g. the result of a regression)
        
        function SetRegResult(obj,inputReg,recordReg)
            obj.RegResult = inputReg;
            obj.TestReg = recordReg;
        end
        
        % Get Functions, to access different properties of the class
        function GetRecords(obj)
            obj.Output = {obj.Name,obj.Strategy,obj.Currency};
        end
        
        function GetTrack(obj)
            obj.Output = obj.TrackNAV;
        end
        
        function GetROR(obj)
            obj.Output = obj.TrackROR;
        end
        
        function GetTrackEst(obj)
            obj.Output = obj.TrackEst;
        end
        
        function GetBackTest(obj)
            obj.Output = obj.BackTest;
        end
        
        function GetMtxOfRegressors(obj)
            obj.Output = obj.MtxOfRegressors;
        end
    end
        
end        