function FilledPrices = GetFilledPrices(OriginalPrices,DatePrices,Betas,DateBetas,Regressors,DateRegressors)
    % this function fills the gap in a price series using the Betas, got 
    % using some kind of regression, and the Regressors. 
    % obviously the regressors must have a thicker granularity than the 
    % price series that must be filled
    
    %TO DO: performe some checks to be sure that all the data are
    %compatible
    
    firstdate = DatePrices(1);
    lastdate = DateRegressors(end);
    referenceDates = firstdate:1:lastdate';
    
    [p,datesidxRgs,idx2] = intersect(referenceDates,DateRegressors,'stable');
    extendedRgs = zeros(size(referenceDates,2),size(Regressors,2));
    extendedRgs(datesidxRgs,:) = Regressors(idx2,:);
    
    Regressors = extendedRgs;
    DateRegressors = referenceDates';
    
%     RawReturns = cell(size(Regressors,2),1);
%     
%     for i = 1:size(Regressors,2)
%         RawReturns{i} = [DateRegressors,Regressors(:,i)];
%     end
%     
%     utilParams.inputTS = RawReturns;
%     utilParams.referenceDatesVector = referenceDates'; 
%     utilParams.op_type = 'fillUsingNearest';
%     U = Utilities(utilParams);
%     U.GetCommonDataSet;
%     Regressors = U.Output.DataSet.data;
%     DateRegressors = U.Output.DataSet.dates;
    
    nofdates = size(DateRegressors,1);
    
    [p,datesidxPrice] = intersect(DateRegressors,DatePrices,'stable');
    extendedPrice = NaN(size(DateRegressors));
    extendedPrice(datesidxPrice,:) = OriginalPrices;
    
    extendedBetas = NaN(size(Regressors));
    [b,datesidxBetas] = intersect(DateRegressors,DateBetas,'stable');
    extendedBetas(datesidxBetas,:) = Betas;
    
    if isnan(extendedBetas(1))
        extendedBetas(1,:) = Betas(1,:);
    end
    
    for i = 2:nofdates
        if isnan(extendedBetas(i,1))
            extendedBetas(i,:) = extendedBetas(i-1,:);
        end
    end
     
    EstReturn =  NaN(size(DateRegressors));
    for i = 2:nofdates
            EstimatedReturn = (extendedBetas(i,:)*Regressors(i,:)')/100;
            EstReturn(i) = EstimatedReturn;
        if isnan(extendedPrice(i))
            extendedPrice(i)=extendedPrice(i-1)*(1+EstimatedReturn);
        end
    end
    output.ExtndTrack = [DateRegressors,extendedPrice];
    output.ExtndBetas = [DateRegressors,extendedBetas];
    output.Regressors = [DateRegressors,Regressors];
    output.EstReturns = [DateRegressors,EstReturn];
   
    FilledPrices = output;
end