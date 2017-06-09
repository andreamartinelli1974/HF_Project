classdef Indice < handle
    %Class to model a set of indices
    %   manage the indices track record 
    %   in case of daily index the imported track record must be include
    %   any non business day, including saturdays and sundays
    
    properties
        Output; %  output: array track record
    end
    
    properties (SetAccess = immutable)
        IndName; %index name
        IndBBGTicker; %index Bloomberg Ticker (if known)
        IndTrackNAV; %track record: matrix with 1st column=dates, 2nd column=NAVs 
        AssetClass; %asset class of the index: 'Equity','Credit','Govt','FX','Comdty'
    end
    
    methods
        function obj = Indice(iparams) %constructor with a Struct as input
            obj.IndName=iparams.indexName;
            obj.IndBBGTicker=iparams.indexTicker;
            obj.IndTrackNAV=iparams.indexTrack;
            obj.AssetClass=iparams.indexAssetCl;
        end   
        
        function GetTrack(obj)
            obj.Output = obj.IndTrackNAV;
        end
        function GetName(obj)
            obj.Output = obj.IndName;
        end
        function GetAssetClass(obj)
            obj.Output = obj.AssetClass;
        end
    end
    
end

