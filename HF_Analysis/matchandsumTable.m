function [ aggregatedTables, table1, table2 ] = matchandsumTable(tableA,tableB, row, col)

% MATCHANDSUMTABLE function allows to match two table with different sizes
% and to sum the common fields value. In addition it is allowed to choose
% the rows and the columns you want to show in the final table.
% INPUT:
% - tableA: first table
% - tableA: second table
% - row: table rows to show
% - col: table columns to show
% OUTPUT:
% - aggregatedTable: final table built by the matching of TableA and TableB
% - table1: it correspond to tableA fitted in the final rows and columns
% - table2: it correspond to tableB fitted in the final rows and columns

if (isempty(row))
    R = unique([tableA.Properties.RowNames; tableB.Properties.RowNames]);
else
    R = row;
end
if (isempty(col))
    C = unique([tableA.Properties.VariableNames tableB.Properties.VariableNames]);
else
    C = col;
end

matrixA = cell(size(R,1),size(C,2));
matrixB = cell(size(R,1),size(C,2));

for i=1:size(R,1)
    
    for j=1:size(C,2)
        
        ffA=arrayfun(@(x) ismember(x(1,:),C{1,j}), tableA.Properties.VariableNames);
        ffsA=find(ffA);
        ggA=arrayfun(@(x) ismember(x(1,:),R{i,1}), tableA.Properties.RowNames);
        ggsA=find(ggA);
        ffB=arrayfun(@(x) ismember(x(1,:),C{1,j}), tableB.Properties.VariableNames);
        ffsB=find(ffB);
        ggB=arrayfun(@(x) ismember(x(1,:),R{i,1}), tableB.Properties.RowNames);
        ggsB=find(ggB);
        
        if(~isempty(ffsA))&&(~isempty(ggsA))
            matrixA(i,j) = table2cell(tableA(ggsA,ffsA));
            table1(i,j) = table([matrixA{i,j}], 'VariableNames', C(1,j), 'RowNames', R(i,1));
        else
            matrixA(i,j) = {0};
            table1(i,j) = table([matrixA{i,j}], 'VariableNames', C(1,j), 'RowNames', R(i,1));
        end
        
        if(~isempty(ffsB))&&(~isempty(ggsB))
            matrixB(i,j) = table2cell(tableB(ggsB,ffsB));
            %value = table2cell(B(ggs,ffs));
            table2(i,j) = table([matrixB{i,j}], 'VariableNames', C(1,j), 'RowNames', R(i,1));
        else
            matrixB(i,j) = {0};
            table2(i,j) = table([matrixB{i,j}], 'VariableNames', C(1,j), 'RowNames', R(i,1));
        end
        
        matrixC(i,j) = {table1{i,j}+table2{i,j}};
        aggregatedTables(i,j) = table([matrixC{i,j}], 'VariableNames', C(1,j), 'RowNames', R(i,1));
        
        table1.Properties.VariableNames(j)=C(1,j);
        table2.Properties.VariableNames(j)=C(1,j);
        aggregatedTables.Properties.VariableNames(j)=C(1,j);
        
    end
    
    table1.Properties.RowNames(i)=R(i,1);
    table2.Properties.RowNames(i)=R(i,1);
    aggregatedTables.Properties.RowNames(i)=R(i,1);
    
end

% dateRow = datetime(aggregatedTables.Properties.RowNames);
% [orderedDateRow,dateRowId]=sort(dateRow);
% orderedValue=table2cell(aggregatedTables(dateRowId(:,1),:));
% aggregatedTables.Properties.RowNames=cellstr(orderedDateRow);
% aggregatedTables(:,:)=orderedValue;

end



