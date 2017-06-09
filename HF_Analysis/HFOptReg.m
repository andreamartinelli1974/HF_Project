classdef HFOptReg <HFRegression
    % Fake subclass to incorporate the result of the optimization performed
    % via the OptModelReg class and put this results into the HedgeFund
    % class
    
    % Functions:
    
    % just the constructor and the Gets functions for the 3 properties used
    % by the HedgeFund Class to create the backtest track record
    
    properties
        Rolling;
        Betas;
    end
    
    methods
        %constructor
        function obj=HFOptReg(inputs,roll,betas,tableret)
            obj = obj@HFRegression(inputs);
            obj.Rolling=roll;
            obj.Betas=betas;
            obj.TableRet=tableret;
        end
        
        %Get Functions
        function GetTableRet(obj)
            obj.Output = obj.TableRet;
        end
        function GetRolling(obj)
            obj.Output=obj.Rolling;
        end
        
        function GetBetas(obj)
            obj.Output=obj.Betas;
        end
    end
end