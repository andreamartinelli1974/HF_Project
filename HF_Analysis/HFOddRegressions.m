classdef HFOddRegressions < HFRegression
    % subclass of HFRegression to perform regressions on a rolling
    % timeframe using advanced regression methods like stepwise, ridge,
    % lasso
    
    properties
        RollingPeriod;
        Betas;
        RidgeBetas;
        RidgeEndBetas;
        
    end
    
    methods
        % constructor
        function obj = HFOddRegressions(params,rollingperiod)
            
            obj = obj@HFRegression(params);
            obj.RollingPeriod = rollingperiod;
            
        end
        
        function StepwiseRollReg(obj)
            % DANGER: AT THE MOMENT THE FUNCTION CREATE A ZEROS BETA SERIES
            % TO DO: IMPLEMENT THE BETA WRITING USING THE NAMES OF THE PREDICTORS EFFECTIVELY USED BY THE REGRESSION 
            
            if size(obj.TableRet,1)-obj.RollingPeriod<=0
                    ME=MException('myComponent:dateError','la finestra di rolling é troppo lunga',obj.HFund.Name);
                    throw(ME)
            end
            
            obj.MtxOfRegressors = ones(1,size(obj.TableRet,2)-2);    
                
            steps=size(obj.TableRet,1)-obj.RollingPeriod+1;
            % steps=number of total common data between dependent var and
            % regressors minus the rolling window
            obj.Betas=zeros(steps,size(obj.TableRet,2));
            
            for i=1:steps
                %sets the table to perform the regression on
                rollingTable=obj.TableRet(i:obj.RollingPeriod+i-1,2:end);
                
                % this is the regression
                obj.RegResult=stepwiselm(rollingTable,'linear');
                
                trackdate=obj.TableRet(obj.RollingPeriod+i-1,1).date;
                %coefficients=obj.RegResult.Coefficients.Estimate';
                coefficients=size(obj.RegResult.Coefficients.Estimate',2);
                
                % creates and fills the regression statistic structure
                RT=obj.RegressionTest(obj.RegResult);
                stats.OrdRS(i)=RT.OrdRSquared;
                stats.AdjRS(i)=RT.AdjRSquared;
                stats.MSE(i)=RT.MSE;
                stats.FTest(i)=RT.FTest;
                stats.PValue(i)=RT.PValue;
                
                % writes the betas matrix
                obj.Betas(i,1:2)=[trackdate,coefficients];
            end
            
            obj.RegTests=stats;
            k=find(abs(obj.Betas)<1e-9);
            obj.Betas(k)=0;
            obj.Betas=array2table(obj.Betas,'VariableNames',['Dates','Intercept',{obj.TableRet.Properties.VariableNames{2:end-1}}]);
            
        end
        
        function LassoRollReg(obj)
            
            if size(obj.TableRet,1)-obj.RollingPeriod<=0
                    ME=MException('myComponent:dateError','la finestra di rolling é troppo lunga',obj.HFund.Name);
                    throw(ME)
            end
            
            obj.MtxOfRegressors = ones(1,size(obj.TableRet,2)-2);    
                
            steps=size(obj.TableRet,1)-obj.RollingPeriod+1;
            % steps=number of total common data between dependent var and
            % regressors minus the rolling window
            obj.Betas=zeros(steps,size(obj.TableRet,2));
           
            for i=1:steps
                %sets the table to perform the regression on
                X=table2array(obj.TableRet(i:obj.RollingPeriod+i-1,2:end));
                Y=X(:,end);
                X=X(:,1:end-1);
                
                
                % this is the regression
                K=round(obj.RollingPeriod/12);
                K=double(K);
                if K<=1
                    K=2;
                end
                
                [B,FitInfo]=lasso(X,Y,'CV',K);
                LambdaMinPosition=find(FitInfo.Lambda==FitInfo.LambdaMinMSE);
                
                trackdate=obj.TableRet(obj.RollingPeriod+i-1,1).date;
                
                % h=lassoPlot(B,FitInfo,'PlotType','CV');
                coefficients=[FitInfo.Intercept(LambdaMinPosition),B(:,LambdaMinPosition)'];
                
%                 % creates and fills the regression statistic structure
%                 RT=obj.RegressionTest(obj.RegResult);
%                 stats.OrdRS(i)=RT.OrdRSquared;
%                 stats.AdjRS(i)=RT.AdjRSquared;
%                 stats.MSE(i)=RT.MSE;
%                 stats.FTest(i)=RT.FTest;
%                 stats.PValue(i)=RT.PValue;
                
                % writes the betas matrix
                obj.Betas(i,:)=[trackdate,coefficients];
            end
            
            %obj.RegTests=stats;
            k=find(abs(obj.Betas)<1e-9);
            obj.Betas(k)=0;
            obj.Betas=array2table(obj.Betas,'VariableNames',['Dates','Intercept',{obj.TableRet.Properties.VariableNames{2:end-1}}]);
            
        end
        
        function RidgeRollReg(obj,kappa)
            
            if size(obj.TableRet,1)-obj.RollingPeriod<=0
                    ME=MException('myComponent:dateError','la finestra di rolling é troppo lunga',obj.HFund.Name);
                    throw(ME)
            end
            
            obj.MtxOfRegressors = ones(1,size(obj.TableRet,2)-2);    
                
            steps=size(obj.TableRet,1)-obj.RollingPeriod+1;
            % steps=number of total common data between dependent var and
            % regressors minus the rolling window
            obj.Betas=zeros(steps,size(obj.TableRet,2));
            obj.RidgeBetas=cell(steps,2);
           
            for i=1:steps
                %sets the table to perform the regression on
                X=table2array(obj.TableRet(i:obj.RollingPeriod+i-1,2:end));
                Y=X(:,end);
                X=X(:,1:end-1);
                D=x2fx(X,'linear');
                
                
                % this is the regression
                K=0:1e-4:1e-1;
                
                B=ridge(Y,D,K);
                         
                trackdate=obj.TableRet(obj.RollingPeriod+i-1,1).date;
                
                % h=lassoPlot(B,FitInfo,'PlotType','CV');
                coefficients=B(:,round(size(K,2)/kappa));
                EndCoefficients=B(:,end);
%                 % creates and fills the regression statistic structure
%                 RT=obj.RegressionTest(obj.RegResult);
%                 stats.OrdRS(i)=RT.OrdRSquared;
%                 stats.AdjRS(i)=RT.AdjRSquared;
%                 stats.MSE(i)=RT.MSE;
%                 stats.FTest(i)=RT.FTest;
%                 stats.PValue(i)=RT.PValue;
                
                % writes the betas matrix
                obj.RidgeBetas(i,:)={trackdate,B};
                obj.Betas(i,:)=[trackdate,coefficients'];
                obj.RidgeEndBetas(i,:)= [trackdate,EndCoefficients'];
                % plot(K,B,'LineWidth',2);
            end
            
            %obj.RegTests=stats;
            k=find(abs(obj.Betas)<1e-9);
            obj.Betas(k)=0;
            obj.Betas=array2table(obj.Betas,'VariableNames',['Dates','Intercept',{obj.TableRet.Properties.VariableNames{2:end-1}}]);
            
        end
        
        function GetRolling(obj)
            obj.Output=obj.RollingPeriod;
        end
        
        function GetBetas(obj)
            obj.Output=obj.Betas;
        end
        
    end
    
end