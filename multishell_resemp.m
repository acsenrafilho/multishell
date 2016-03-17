function multishell_resemp(img_nii,bval,bvec,out_bval_size,grad_dir_out,SH_order)

%function multishell_resemp(img_nii,bval,bvec,grad_dir_out,SH_order)
%
%Apply the Spherical Harmonics DWI resampling to reduce gradient order in DTI data.
%
%img_nii       = Input data filename path (.nii)
%bval          = Bval filename path (.bval)
%bvec          = Bvec filename path (.bvec)
%grad_dir_out  = Number of gradients in the bvec output file
%SH_order      = Spherical Harmonics order

% Spliting the input filename to get path, filename and extention
[path, filename, ext] = fileparts(img_nii);

% Creating the brain mask
system(sprintf('bet %s brain -f 0.1 -m',img_nii));

% untar the brain mask file and atribute brain_mask variable
system(sprintf('gzip -d brain_mask.nii.gz'));
brain_mask=strcat(path,'/brain_mask.nii');

% Remove unncessary files
system(sprintf('rm brain.nii.gz'));

%Determining the number of B0 in the DTI data
numBvals=0;
bval_list=load(bval);
for i=1:length(bval_list)
    if bval_list(i)<100
    numBvals=numBvals+1;
    end
end

% Removing bo volumes from bvec files
bvec_values=load(bvec);
bvec_values(:,1:numBvals)=[];
bvec_values=bvec_values';

% SH resample
NBL_SH_resample(img_nii,brain_mask,bvec_values,numBvals,strcat(path,'/',filename,'_resamp',ext),ndirez(grad_dir_out),SH_order);

% Save bvec and bval to the new resample data
bval=load(bval);
new_bval=zeros(1,out_bval_size+grad_dir_out);
for i=1:length(new_bval)
    if i <= out_bval_size
       new_bval(i)=bval(i);
    else
       new_bval(i)=bval(i+12);
    end
end
save(strcat(path,'/',filename,'_resamp.bval'),'new_bval','-ascii');
new_bvec=zeros(out_bval_size+grad_dir_out,3);
b1values=ndirez(grad_dir_out);
new_bvec(out_bval_size+1:length(new_bvec),:)=b1values;
new_bvec=new_bvec';
save(strcat(path,'/',filename,'_resamp.bvec'),'new_bvec','-ascii');

% Clear the variables
% delete bvec bvec_values bval
