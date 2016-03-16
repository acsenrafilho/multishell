#!/bin/bash
# Script to split the DTI volume and apply a deformation motion artifact from a .mat file (eddy_correct)

INPUT_IMG=$1
MATRIX=$2
RESOLUTION=$3

# Downsample to 2mm spatial resolution
# flirt -in $INPUT_IMG -ref $INPUT_IMG -out ${INPUT_IMG}_2mm.nii -applyisoxfm $RESOLUTION

# Decompress the 2 mm image
 # gzip -d ${INPUT_IMG}_${RESOLUTION}mm.nii.gz

# Resetting the input image variable
INPUT_IMG=${INPUT_IMG}_${RESOLUTION}mm.nii

# Split the DTI volume in 3D volumes
fslsplit ${INPUT_IMG}.nii tmp_

# Cleaning eddy_correct matrix file to only matrix data
 cat $MATRIX | grep -v processing | grep -v Final | grep [[:alnum:]] > affine_4D.mat

#MATLAB: split the affine_4D.mat file into several small affine matrix for each volumes
matlab nohup -nodesktop -nodisplay -nosplash << EOF
table=load('affine_4D.mat','-ascii');

rows=length(table);
out_table=zeros(4,4);
count=0;
for i=1:4:rows
        out_table=table(1*i:1*(i+3),:);
        save(sprintf('aff_%d.mat',count),'out_table','-ascii');
        count=count+1;
end
EOF
echo ""

#Apply transformation on each tmp volume
sizem=4
count=1
while read line; do
  ((count++))
done < affine_4D.mat

numMat=`echo $(($count/$sizem))`
for (( i = 0; i < $numMat; i++ )); do
  if [[ $i -lt 10 ]]; then
    echo "--> Applying transformation in volume $i"
    flirt -in tmp_000$i.nii.gz -ref tmp_000$i.nii.gz -init aff_$i.mat -out tmp_000${i}_aff.nii.gz -applyxfm
  elif [[ $i -lt 100 && $i -ge 10 ]]; then
    echo "--> Applying transformation in volume $i"
    flirt -in tmp_00$i.nii.gz -ref tmp_00$i.nii.gz -init aff_$i.mat -out tmp_00${i}_aff.nii.gz -applyxfm
  elif [[ $i -lt 1000 && $i -ge 100 ]]; then
    echo "--> Applying transformation in volume $i"
    flirt -in tmp_0$i.nii.gz -ref tmp_0$i.nii.gz -init aff_$i.mat -out tmp_0${i}_aff.nii.gz -applyxfm
  fi
done

#Reconstructing the resampled+distorted volume
for (( i = 0; i < $numMat; i++ )); do
  if [[ $i -lt 10 ]]; then
    echo "tmp_000${i}_aff.nii.gz " >> tmp_filelist.txt
  elif [[ $i -lt 100 && $i -ge 10 ]]; then
    echo "tmp_00${i}_aff.nii.gz " >> tmp_filelist.txt
  elif [[ $i -lt 1000 && $i -ge 100 ]]; then
    echo "tmp_0${i}_aff.nii.gz " >> tmp_filelist.txt
  fi
done

# Create the final volume with ec distortions
 fslmerge -t dti_resamp_ec.nii.gz `cat tmp_filelist.txt`

#Removing unncessary files
 rm aff* tmp*

 # TODO FAZER REAJUSTE PARA QUE O VOLUME DTI TENHA O MEMSO NUMERO DE B0 - NESTE CASO TEM 18 MAS O SAGAPILOT TEM SO 6!!!!!!!!!!
