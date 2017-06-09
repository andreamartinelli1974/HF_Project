classdef HFRegression < handle
    %% Class to perform regression on a single hedge fund using many regressors
    
    % the class has different subclasses to perform different type of
    % regresson and quality controls on the output.
    
    % the class is also the repository for some functions that are used for
    % any kind of regression (static methods)
    
    % Functions:
    
    % SimpleRegression(obj): performs a simple multilinear regression on
    % the whole available track record of the hedge fund
    
    % GetTableRet: set Output = TableRet
    % GetRegResult: set Output = RegResult
    % GetRegTests: set Output = RegTests
    % GetMTXofRegressors: set Output = MtxOfRegressors
    % GetBetas: Output=obj.RegResult.Coefficients(:,1) (beta of the simple
    % regression) this function i needed to have the same function with the
    % same kind of output for any regression class & subclass. This
    % function is used by the HedgeFund.m class to build the estimated
    % track record.
    
    % Static Methods:
    
    % matrix = getMtxPredictors(obj,numberOfTry,method): create a logical matrix
    % to chose from the regressors set the subset on wich the regression
    % will be performed. 3 different way to select the regressors:
    % 1) 'random' create numberOfTry rows with a random array of 1 & 0. no
    % constraints on the number of 1.
    % 2) 'strategy' create a matrix with a row for any strategy of the
    % indexes. E.g: a row including any "Equity" index, a row with any
    % "Credit" index and so on for any different strategy in the set
    % 3) 'correlation' for any row of the matrix, the index with the max
    % number of cross correlation over 0.75 is eliminated.
    
    % RTest = RegressionTest(LRObject): this function create a struct with
    % the main statistical tests for the regression LRObject. The imput is
    % a fitlm object.
    
    properties 
        
        HFund; % Hedge Fund (the X of the regression). It'an HedgeFund object
        Regressors; % the Ys of the regression. It's an array of Indice objects
        TableRet; %input table for fitlm(table) predictors + dependent var in last column
        MtxOfRegressors; %the logical matrix that specify wich regressors are effectively used in the regression
        RegResult; % the result of the regression. It's a LinearModel object
        RegTests; %TO BE WELL DEFINED include the result of different test of the regression quality
        Output; %generic output for the GET methods
        
    end
    
    methods
        
        function obj = HFRegression(params); %constructor
            
            obj.HFund = params.fund;
            obj.Regressors = params.Indices;
            
            % allign the track record of the fund and the indices 
            % create the TableRet
            
            nrindex=size(obj.Regressors,2);
            indexnames=cell(1,nrindex);
            mintrack=100000000000000000000000000;
            for j=1:nrindex
                % for any regressor it gets the name and the Track and
                % intersect it with the fund Track to find the shorter
                % itersection
                obj.Regressors(1,j).GetName;
                indexnames{1,j}=obj.Regressors(1,j).Output;
                obj.Regressors(1,j).GetTrack;
                obj.HFund.GetTrack;
                [fdate,ifund,iindex]=intersect(obj.HFund.Output(:,1),obj.Regressors(1,j).Output(:,1),'rows');
                mindatei(j,1)=size(fdate,1);
                [M,I]=min(mindatei);
                
                if M<mintrack
                    seltrack=zeros(M,2);
                    % this is the shortest intersection between the fund and the regressors
                    % seltrak is the track od the fund shortened 
                    seltrack=obj.HFund.Output(ifund,:); 
                    mintrack=M;
                end
            end
            
            mindex=zeros(min(M,size(seltrack,1)),nrindex);
            mtxOfReg=zeros(size(mindex,1)-1,nrindex);
            
            %it intersect any regressors with the shortened fund track
            clear fdate;
            for j=1:nrindex
                [fdate,ifund,iindex]=intersect(seltrack(:,1),obj.Regressors(1,j).Output(:,1),'rows');
                mindex(:,j)=obj.Regressors(1,j).Output(iindex,2);
                mtxOfReg(:,j)=mindex(2:end,j)./mindex(1:end-1,j)-1;
            end
            
            indexzeros=find(~mtxOfReg);
            mtxOfReg(indexzeros)=0.00000000001;
            selectTrackROR=zeros(size(seltrack,1)-1,2);
            selectTrackROR(:,1)=seltrack(2:end,1);
            selectTrackROR(:,2)=seltrack(2:end,2)./seltrack(1:end-1,2)-1;
            obj.HFund.GetRecords;
            records=obj.HFund.Output{1};
            % creates the TableRet, with: 
            % first column: dates
            % second -> second to last: regressors RORs
            % last: fund RORs
            obj.TableRet=array2table([fdate(2:end,1),mtxOfReg,selectTrackROR(:,2)],'VariableNames',['date',indexnames,records]);
            
        end
        
        function SimpleRegression(obj);
            
            obj.RegResult = fitlm(obj.TableRet(:,2:end));
            obj.RegTests = obj.RegressionTest(obj.RegResult);
            obj.MtxOfRegressors = ones(1,size(obj.TableRet,2)-2);
            
        end
        
        
        % Get Functions, to access different properties of the class
        function GetTableRet(obj)
            obj.Output = obj.TableRet;
        end
        
        function GetRegResult(obj)
            obj.Output = obj.RegResult;
        end
        
        function GetRegTests(obj)
            obj.Output = obj.RegTests;
        end
        
        function GetMtxOfRegressors(obj)
            obj.Output = obj.MtxOfRegressors;
        end
        
        function GetBetas(obj)
            betas=obj.RegResult.Coefficients.Estimate';
            k=find(abs(betas)<1e-9);
            betas(k)=0;
            betas=array2table(betas,'VariableNames',['Dates','Intercept',{obj.TableRet.Properties.VariableNames{2:end-1}}]);
            obj.Output=betas;        
        end
    end
        
    methods (Static)
        
        %% this function Create a logical mtx to choose some regressors using different criteria
        function matrix=getMtxPredictors(obj,numberOfTry,method)
            
            % ******************************************************
            %
            % THIS IS THE MAXIMUM CORRELATION ALLOWED BETWEEN REGRESSORS
            THRESHOLD = 0.75;
            %
            % ******************************************************
            
            if strcmp(method,'strategy')
                % in this case the matrix group the index of the same asset
                % class (e.g. all the equity indexes, credit indexes etc)
                assetclass=cell(2,size(obj.Regressors,2));
                for i = 1:size(obj.Regressors,2)
                    obj.Regressors(i).GetName;
                    assetclass(1,i) = cellstr(obj.Regressors(i).Output);
                    obj.Regressors(i).GetAssetClass;
                    assetclass(2,i) = cellstr(obj.Regressors(i).Output);
                end
                step=1;
                mtxstep=1;
                matrix=zeros(1,size(obj.Regressors,2));
                test=assetclass(2,step);
                matrix(mtxstep,:)=strcmp(test,assetclass(2,:));
                step=step+1;
                mtxstep=mtxstep+1;
                while step<=size(obj.Regressors,2)
                    test=assetclass(2,step);
                    if sum(strcmp(test,assetclass(2,1:step-1)))==0
                        matrix(mtxstep,:)=strcmp(test,assetclass(2,:));
                        mtxstep=mtxstep+1;
                    end
                    while step<=size(obj.Regressors,2) & strcmp(test,assetclass(2,step))
                        step=step+1;
                    end
                end
                
            elseif strcmp(method,'random')
                % in this case the mtx is random 
                % any row conmtains a random vector of 1 and 0
                % no constraints on the numeber of 1s
                % the matrix has numberOfTry rows
                matrix=round(rand(numberOfTry,size(obj.Regressors,2)));
                
            elseif strcmp(method,'correlation')        
                % this finction select a subset of regressors with
                % correlation < gate (first try gate=0.75) step by step
                % (any row has a regressor deleted
                
                indexcorr=corrcoef(table2array(obj.TableRet(:,2:end-1)));
                gate=abs(indexcorr)> THRESHOLD;
                gateswitch=sum(gate,1);
                [A,I]=sort(gateswitch,'descend');
                H=ones(size(I,2),size(I,2));
                counter=0;
                riga=2;
                while A(1,1)>1
                    H(riga:end,I(1,1))=0;
                    gate(I(1,1),:)=0;
                    gate(:,I(1,1))=0;
                    gateswitch=sum(gate,1);
                    riga=riga+1;
                    [A,I]=sort(gateswitch,'descend');
                    if counter>size(obj.TableRet,2)*5
                        break
                    end
                end
                H(riga:end,:)=[];
                matrix=H;
            else
                % to be implemented
                
                matrix=ones(1,size(obj.Regressors,2)); %this may be deleted
            end
        end
        
        %% this function create a struct with many quality test for the regression
        function RTest=RegressionTest(LRObject)
            RTest.OrdRSquared=LRObject.Rsquared.Ordinary;
            RTest.AdjRSquared=LRObject.Rsquared.Adjusted;
            RTest.MSE=LRObject.MSE;
            Anova=anova(LRObject,'summary');
            RTest.FTest=table2array(Anova(2,4));
            RTest.PValue=table2array(Anova(2,5));
        end
    end
    
    
end

