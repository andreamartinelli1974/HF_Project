classdef HFPortfolio < handle
    %class to handle a portfolio of heddge fund and to find a factor
    %decomposition for the whole portfolio starting from the factor
    %decomposition of any single fund.
    
    %the betas are summed to build the factor decomposition of the
    %portfolio. the set of the regressors is the same for any fund in the
    %portfolio
    
    % WARING: at the moment the classe build a track based on common funds
    % date. the Betas follows this assumption and only the common track
    % betas are considered.
    
    properties
        
        HFunds; %array of HedgeFund objects
        Weights; %struct with HF univocodes & related weights
        PTFtrack; %Hypotetical track of the portfolio
        PTFtrackEst; %Estimated track record
        PTFcumulative; % MAYBE NOT USEFULL cumulative track record
        Regressors; %common regressors for the analysis
        BackTest; %Cumulative Returns
        Betas; %array of the betas for the whole portfolio
        Output; %generic output
        TableRet; %TEMPORARY?
    end
    
    methods
        
        function obj=HFPortfolio(params) %constructor
            obj.HFunds=params.funds;
            obj.Weights=params.weights;
            obj.Regressors=params.regressors;
        end
        
        function BuildPTF(obj) %to allign the HF track records and build the PTFtrack
            
            % gets the track of the first fund of the funds array (just to
            % start from somewhere...
            obj.HFunds(1,1).GetTrack;
            obj.PTFtrack=zeros(size(obj.HFunds(1,1).Output,1),2);
            obj.PTFtrack(:,1)=obj.HFunds(1,1).Output(:,1);
            mintrack=100000000000000000000000000;
            
            for i=2:size(obj.HFunds,2)
                % for any fund it gets the name and the Track and
                % intersect it with the ptf Track to find the shorter
                % itersection
                obj.HFunds(1,i).GetTrack;
                [fdate,ifirst,isecond]=intersect(obj.HFunds(1,i).Output(:,1),obj.PTFtrack(:,1),'rows');
                mindatei(i-1,1)=size(fdate,1);
                [M,I]=min(mindatei);
                
                if M<mintrack
                    % choses the shorter intersaction
                    obj.PTFtrack=zeros(size(obj.HFunds(1,i).Output(ifirst,1),1),2);
                    obj.PTFtrack(:,1)=obj.HFunds(1,i).Output(ifirst,1);
                    mintrack=M;
                end
            end
            
            % creates a NAV array with the common dates navs for any fund
            % to calculate the ror on the common dates an then the ptf ror
            mtxnav=zeros(size(obj.PTFtrack,1),size(obj.HFunds,2));
            mtxror=zeros(size(obj.PTFtrack,1)-1,size(obj.HFunds,2));
            
            
            
            % using the dates obtained with the shortest funds intersection
            % build the portfolio Track record summing any weighted fund's ROR
            for i=1:size(obj.HFunds,2)
                
                % gets any fund's nav
                obj.HFunds(1,i).GetTrack;
                
                % intersect the fund track record dates with the ptf dates 
                [fdate,ifirst,isecond]=intersect(obj.HFunds(1,i).Output(:,1),obj.PTFtrack(:,1),'rows');
                
                % gets the fund code and gets the fund weight using the
                % code
                fundcode=obj.HFunds(1,i).UnivoCode;
                fundweight=obj.Weights.(fundcode);
                
                % creates aa array with the common dates track of any funds
                % on the columns, calculates the ror and weights them
                mtxnav(:,i)=obj.HFunds(1,i).Output(ifirst,2);
                mtxror(:,i)=(mtxnav(2:end,i)./mtxnav(1:end-1,i)-1)*fundweight;
            end
            
            % writes the ptf ror summing the weighted ror of any fund
            obj.PTFtrack(1,:)=[];
            obj.PTFtrack(:,2)=sum(mtxror,2);
            
            % creates the PTF cumulative return
            cumtrack=obj.PTFtrack;
            cumtrack(:,2:end)=1+cumtrack(:,2:end);
            cumtrack(:,2:end)=cumprod(cumtrack(:,2:end),1);
            obj.PTFcumulative=cumtrack;
        end
        
        function RegressPTF(obj,method,rolling) %this function create the estimated track and the betas set
            
            % create an object of type HedgeFund to use it as input for an
            % HFRegression object
            prms.fundName = 'ptf';
            prms.univocode= 'fakeptf';
            prms.fundStrategy = 'N/A';
            prms.fundCcy = 'N/A';
            prms.fundTrack = obj.PTFcumulative;
            
            ptfashf = HedgeFund(prms);
            
            % create an object of type HFRegression to create the TableRet:
            % a table with the dates in the first column, the ptf ror in
            % the last column and the regressors ror in between
            params.fund=ptfashf;
            params.Indices=obj.Regressors;
            
            ptsfakeregress=HFRegression(params);
            ptsfakeregress.GetTableRet;
            obj.TableRet=ptsfakeregress.Output;
            
            obj.Betas=zeros(size(obj.PTFtrack,1),size(obj.Regressors,2)+2);
            obj.Betas(:,1)=obj.PTFtrack(:,1);
            
            % here starts the real regression on any fund, subject to the
            % method chosed
            if strcmp(method,'bayesian')
                for i=1:size(obj.HFunds,2) % for any fund in the ptf
                    
                    %cut the rolling period chosed in case the track of the
                    %fund is too short
                    rollingshort=rolling;
                    if rollingshort>=size(obj.HFunds(1,i).TrackROR,1)*2/3
                        rollingshort=round(size(obj.HFunds(1,i).TrackROR,1)*2/3);
                    end
                    
                    % create the regression object
                    parameters.fund=obj.HFunds(1,i);
                    parameters.indices=obj.Regressors;
                    parameters.rolling=round(rollingshort*2/3);
                    parameters.rolling2=rollingshort-parameters.rolling;
                    
                    optregression(i)=OptModelReg(parameters);
                    optregression(i).OpRegression;
                    
                    % uses the output of the regression to create the
                    % estimated track record of the fund
                    obj.HFunds(1,i).CreateTrackEst(optregression(i).Output);
                    
                    % fills the betas array for the portfolio weighting the
                    % betas of any fund
                    fundcode=obj.HFunds(1,i).UnivoCode;
                    fundweight=obj.Weights.(fundcode);
                
                    obj.HFunds(1,i).GetTrackEst;
                    [ptfdate,iptf,ifund]=intersect(obj.Betas(:,1),obj.HFunds(1,i).Output(:,1),'rows');
                    obj.Betas=obj.Betas(iptf,:);
                    obj.Betas(:,2:end)=obj.Betas(:,2:end)+fundweight*table2array(obj.HFunds(1,i).Betas(ifund,2:end));
                end
            else
                for i=1:size(obj.HFunds,2)
                    
                    %cut the rolling period chosed in case the track of the
                    %fund is too short
                    params.fund=obj.HFunds(1,i);
                    params.Indices=obj.Regressors;
                    
                    rollingshort=rolling;
                    
                    %cut the rolling period chosed in case the track of the
                    %fund is too short
                    if rollingshort>=size(obj.HFunds(1,i).TrackROR,1)*2/3
                        rollingshort=round(size(obj.HFunds(1,i).TrackROR,1)*2/3);
                    end
                    
                    % creates the rolling regression object
                    hfrollingreg(i)=HFRollingReg(params,rollingshort);
                    
                    if strcmp(method,'rolling')
                        
                        % does the regression
                        hfrollingreg(i).RollingReg;
                        
                    elseif strcmp(method,'cond rolling')
                        
                        % creates the matrix to select the regressors (low
                        % correlation) then does the regression
                        LogicalMTX=hfrollingreg.getMtxPredictors(obj,100,'correlation');
                        hfrollingreg(i).ConRollReg(LogicalMTX);
                        
                    elseif strcmp(method,'random rolling')
                        
                        % creates the matrix to select the regressors
                        % (random) then does the regression
                        LogicalMTX=hfrollingreg.getMtxPredictors(obj,1000,'random');
                        hfrollingreg(i).ConRollReg(LogicalMTX);
                        
                    else
                        ME=MException('myComponent:dateError','metodo sconosciuto');
                        throw(ME)
                    end
                    
                    % use the output of the regression to create the
                    % estimated track record of the fund
                    obj.HFunds(1,i).CreateTrackEst(hfrollingreg(i));
                    
                    % fills the betas array for the portfolio weighting the
                    % betas of any fund
                    fundcode=obj.HFunds(1,i).UnivoCode;
                    fundweight=obj.Weights.(fundcode);
                    
                    obj.HFunds(1,i).GetTrackEst;
                    [ptfdate,iptf,ifund]=intersect(obj.Betas(:,1),obj.HFunds(1,i).Output(:,1),'rows');
                    obj.Betas=obj.Betas(iptf,:);
                    obj.Betas(:,2:end)=obj.Betas(:,2:end)+fundweight*table2array(obj.HFunds(1,i).Betas(ifund,2:end));
                end
            end
            obj.Betas=array2table(obj.Betas,'VariableNames',['Dates','Intercept',{obj.TableRet.Properties.VariableNames{2:end-1}}]);
            
            % creates a HFOptReg object to use its methods to obtain the
            % estimated track record and backtest cumulative track record
            % for the PTF starting from his main data (eg Betas, rolling period, TableRet etc)
            roll=size(obj.TableRet,1)-size(obj.Betas,1)+1;
            ptffake=HFOptReg(params,roll,obj.Betas,obj.TableRet);
            ptfashf.CreateTrackEst(ptffake);
            ptfashf.GetTrackEst;
            obj.PTFtrackEst=ptfashf.Output;
            ptfashf.GetBackTest;
            obj.BackTest=ptfashf.Output;
        end
    end
    
end

%         function RegressPTF(obj,method,rolling) %this function create the estimated track and the betas set
%             prms.fundName = 'ptf';
%             prms.fundStrategy = 'N/A';
%             prms.fundCcy = 'N/A';
%             prms.fundTrack = obj.PTFcumulative;
%             
%             ptfashf = HedgeFund(prms);
%             
%             params.fund=ptfashf;
%             params.Indices=obj.Regressors;
%             
%             ptsfakeregress=HFRegression(params);
%             ptsfakeregress.GetTableRet;
%             obj.TableRet=ptsfakeregress.Output;
%             
%             obj.Betas=zeros(size(obj.PTFtrack,1),size(obj.Regressors,2)+2);
%             obj.Betas(:,1)=obj.PTFtrack(:,1);
%             
%             if strcmp(method,'rolling')
%                 
%                 for i=1:size(obj.HFunds,2)
%                     
%                     params.fund=obj.HFunds(1,i);
%                     params.Indices=obj.Regressors;
%                     
%                     rollingshort=rolling;
%                     if rollingshort>=size(obj.HFunds(1,i).TrackROR,1)*2/3
%                        rollingshort=round(size(obj.HFunds(1,i).TrackROR,1)*2/3); 
%                     end
%                     size(obj.HFunds(1,i).TrackROR,1)-rollingshort
%                     hfrollingreg(i)=HFRollingReg(params,rollingshort);
%                     hfrollingreg(i).RollingReg;
%                     
%                     obj.HFunds(1,i).CreateTrackEst(hfrollingreg(i));
%                     
%                     obj.HFunds(1,i).GetTrackEst;
%                     [ptfdate,iptf,ifund]=intersect(obj.Betas(:,1),obj.HFunds(1,i).Output(:,1),'rows');
%                     obj.Betas=obj.Betas(iptf,:);
%                     obj.Betas(:,2:end)=obj.Betas(:,2:end)+obj.Weights(1,i)*table2array(obj.HFunds(1,i).Betas(ifund,2:end));
%                 end
%             elseif strcmp(method,'cond rolling')
%                 
%                 for i=1:size(obj.HFunds,2)
%                     
%                     params.fund=obj.HFunds(1,i);
%                     params.Indices=obj.Regressors;
%                     
%                     rollingshort=rolling;
%                     if rollingshort>=size(obj.HFunds(1,i).TrackROR,1)*2/3
%                        rollingshort=round(size(obj.HFunds(1,i).TrackROR,1)*2/3); 
%                     end
%                     
%                     hfrollingreg2(i)=HFRollingReg(params,rollingshort);
%                     LogicalMTX=hfrollingreg2.getMtxPredictors(obj,100,'correlation');
%                     hfrollingreg2(i).ConRollReg(LogicalMTX);
%                     
%                     obj.HFunds(1,i).CreateTrackEst(hfrollingreg2(i));
%                     
%                     obj.HFunds(1,i).GetTrackEst;
%                     [ptfdate,iptf,ifund]=intersect(obj.Betas(:,1),obj.HFunds(1,i).Output(:,1),'rows');
%                     obj.Betas=obj.Betas(iptf,:);
%                     obj.Betas(:,2:end)=obj.Betas(:,2:end)+obj.Weights(1,i)*table2array(obj.HFunds(1,i).Betas(ifund,2:end));
%                 end
%                 elseif strcmp(method,'random rolling')
%                 
%                 for i=1:size(obj.HFunds,2)
%                     
%                     params.fund=obj.HFunds(1,i);
%                     params.Indices=obj.Regressors;
%                     
%                     rollingshort=rolling;
%                     if rollingshort>=size(obj.HFunds(1,i).TrackROR,1)*2/3
%                        rollingshort=round(size(obj.HFunds(1,i).TrackROR,1)*2/3); 
%                     end
%                     
%                     hfrollingreg2(i)=HFRollingReg(params,rollingshort);
%                     LogicalMTX=hfrollingreg2.getMtxPredictors(obj,1000,'random');
%                     hfrollingreg2(i).ConRollReg(LogicalMTX);
%                     
%                     obj.HFunds(1,i).CreateTrackEst(hfrollingreg2(i));
%                     
%                     obj.HFunds(1,i).GetTrackEst;
%                     [ptfdate,iptf,ifund]=intersect(obj.Betas(:,1),obj.HFunds(1,i).Output(:,1),'rows');
%                     obj.Betas=obj.Betas(iptf,:);
%                     obj.Betas(:,2:end)=obj.Betas(:,2:end)+obj.Weights(1,i)*table2array(obj.HFunds(1,i).Betas(ifund,2:end));
%                 end
%             elseif strcmp(method,'bayesian')
%                 for i=1:size(obj.HFunds,2)
%                     
%                     rollingshort=rolling;
%                     if rollingshort>=size(obj.HFunds(1,i).TrackROR,1)*2/3
%                        rollingshort=round(size(obj.HFunds(1,i).TrackROR,1)*2/3); 
%                     end
%                     
%                     parameters.fund=obj.HFunds(1,i);
%                     parameters.indices=obj.Regressors;
%                     parameters.rolling=round(rollingshort*2/3);
%                     parameters.rolling2=rollingshort-parameters.rolling;
%                     
%                     optregression(i)=OptModelReg(parameters);
%                     optregression(i).OpRegression;
%                     
%                     obj.HFunds(1,i).CreateTrackEst(optregression(i).Output);
%                     
%                     obj.HFunds(1,i).GetTrackEst;
%                     [ptfdate,iptf,ifund]=intersect(obj.Betas(:,1),obj.HFunds(1,i).Output(:,1),'rows');
%                     obj.Betas=obj.Betas(iptf,:);
%                     obj.Betas(:,2:end)=obj.Betas(:,2:end)+obj.Weights(1,i)*table2array(obj.HFunds(1,i).Betas(ifund,2:end));   
%                 end
%             else
%                 ME=MException('myComponent:dateError','metodo sconosciuto');
%                 throw(ME)
%              end
% 
%             obj.Betas=array2table(obj.Betas,'VariableNames',['Dates','Intercept',{obj.TableRet.Properties.VariableNames{2:end-1}}]);
%             
%             roll=size(obj.TableRet,1)-size(obj.Betas,1)+1;
%             ptffake=HFOptReg(params,roll,obj.Betas,obj.TableRet);
%             ptfashf.CreateTrackEst(ptffake);
%             ptfashf.GetTrackEst;
%             obj.PTFtrackEst=ptfashf.Output;
%             ptfashf.GetBackTest;
%             obj.BackTest=ptfashf.Output;
%         end
        
   