table=load('affine_4D.mat','-ascii');

rows=length(table);
out_table=zeros(4,4);
count=1;
for i=1:4:rows
        out_table=table(1*i:1*(i+3),:);
        save(sprintf('aff_%d.mat',count),'out_table','-ascii');
        count=count+1;
end