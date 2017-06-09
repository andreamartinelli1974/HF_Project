
function matrix=getMtxPredictors(IndiceObj,numberOfTry,method)
    if strcmp(method,'strategy')
        assetclass=cell(2,size(IndiceObj,2));
        for i = 1:size(IndiceObj,2)
            IndiceObj(i).GetName;
            assetclass(1,i) = cellstr(IndiceObj(i).Output);
            IndiceObj(i).GetAssetClass;
            assetclass(2,i) = cellstr(IndiceObj(i).Output);
        end
        step=1;
        mtxstep=1;
        matrix=zeros(1,size(IndiceObj,2));
        test=assetclass(2,step);
        matrix(mtxstep,:)=strcmp(test,assetclass(2,:));
        step=step+1;
        mtxstep=mtxstep+1;
        while step<=size(IndiceObj,2)
            test=assetclass(2,step);
            if sum(strcmp(test,assetclass(2,1:step-1)))==0
                matrix(mtxstep,:)=strcmp(test,assetclass(2,:));
                mtxstep=mtxstep+1;
            end
            while step<=size(IndiceObj,2) & strcmp(test,assetclass(2,step))
                step=step+1;
            end
        end
        % matrix=round(rand(1,size(IndiceObj,2))); %this must be deleted

    elseif strcmp(method,'random')
        matrix=round(rand(numberOfTry,size(IndiceObj,2)));
    else
        % to be implemented

        matrix=ones(1,size(IndiceObj,2)); %this may be deleted
    end
end