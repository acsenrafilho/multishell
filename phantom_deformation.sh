#!/bin/bash
# Script to split the DTI volume and apply a deformation motion artifact from a .mat file (eddy_correct)

usage(){
  echo "  Script to apply a eddy current distortion in a DTI data."
  echo "  Usage: phantom_deformation <Input image> <Bval file> <Bvec file> <Distortion matrix> <Number of B0> <Spatial resolution (mm)>"
  echo ""
  echo "   Input image          = The DTI volume which you want to apply eddy current distortions."
  echo "   Bval file            = Bval file from the input image (.bval)."
  echo "   Bvec file            = Bvec file from the input image (.bvec)."
  echo "   Distortion matrix    = A textfile which informs a 4x4 affine matrix in order to apply in each volume of the DTI input data. Tip: Use FSL-eddy-correct ecclog file."
  echo "   Number of B0         = Inform how many B0 volumes your output DTI data should have."
  echo "   Spatial resolution   = Choose a desirable final spatial resolution to your data. For instance, 2 mm."
  echo ""
}

if [[ $# -eq 0 ]]; then
  usage
  exit
elif [[ $# -lt 6 ]]; then
  usage
  exit
fi

INPUT_IMG=$1
BVAL=$2
BVEC=$3
MATRIX=$4
NUM_B0=$5
RESOLUTION=$6

FILENAME=$(basename ${INPUT_IMG})
FILENAME=${FILENAME%.*}

echo ""
echo "***** Phantom reconstruction *****"
echo ""

echo "    ==> Resampling the gold standard data with Spherical Harmonics..."
matlab nohup -nodesktop -nodisplay -nosplash << EOF
 addpath(genpath('/home/k1510868/Documents/multishell/'));
 addpath(genpath('/home/k1510868/Documents/MATLAB/NBL_functions/'));

 addpath(genpath('/home/antonio/Documents/GitProjects/multishell'));
 addpath(genpath('/home/antonio/Documents/NBL/spherical_resamp/'));

 multishell_resemp('$INPUT_IMG','$BVAL','$BVEC',$NUM_B0,60,8);

EOF

echo ""
# Downsample to 2mm spatial resolution
echo "    ==> Downsampling the data to $RESOLUTION mm..."
INPUT_IMG=`ls *_resamp.nii`
flirt -in $INPUT_IMG -ref $INPUT_IMG -out tmp_dti_${RESOLUTION}mm.nii -applyisoxfm $RESOLUTION

# Decompress the 2 mm image
 gzip -d tmp_dti_${RESOLUTION}mm.nii.gz

# Resetting the input image variable
INPUT_IMG=tmp_dti_${RESOLUTION}mm.nii

# Reducing the b0 volumes
fslroi $INPUT_IMG tmp_cropDTI $((18-$NUM_B0)) -1
INPUT_IMG=tmp_cropDTI.nii.gz

# Split the DTI volume in 3D volumes
echo "    ==> Spliting 4D DTI volume to a series of 3D volumes... "
fslsplit ${INPUT_IMG}.nii.gz tmp_vol_

# Cleaning eddy_correct matrix file to only matrix data
echo "    ==> Formating matrix file..."
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
echo "    ==> Applying affine transformation on each 3D volume"
sizem=4
count=1
while read line; do
  ((count++))
done < affine_4D.mat

numMat=`echo $(($count/$sizem))`
for (( i = 0; i < $numMat; i++ )); do
  if [[ $i -lt 10 ]]; then
    echo "--> Applying transformation in volume $i"
    flirt -in tmp_vol_000$i.nii.gz -ref tmp_vol_000$i.nii.gz -init aff_$i.mat -out tmp_vol_000${i}_aff.nii.gz -applyxfm
  elif [[ $i -lt 100 && $i -ge 10 ]]; then
    echo "--> Applying transformation in volume $i"
    flirt -in tmp_vol_00$i.nii.gz -ref tmp_vol_00$i.nii.gz -init aff_$i.mat -out tmp_vol_00${i}_aff.nii.gz -applyxfm
  elif [[ $i -lt 1000 && $i -ge 100 ]]; then
    echo "--> Applying transformation in volume $i"
    flirt -in tmp_vol_0$i.nii.gz -ref tmp_vol_0$i.nii.gz -init aff_$i.mat -out tmp_vol_0${i}_aff.nii.gz -applyxfm
  fi
done

#Reconstructing the resampled+distorted volume
echo "    ==> Reconstructing the final DTI volume with eddy current distortions..."
for (( i = 0; i < $numMat; i++ )); do
  if [[ $i -lt 10 ]]; then
    echo "tmp_vol_000${i}_aff.nii.gz " >> tmp_filelist.txt
  elif [[ $i -lt 100 && $i -ge 10 ]]; then
    echo "tmp_vol_00${i}_aff.nii.gz " >> tmp_filelist.txt
  elif [[ $i -lt 1000 && $i -ge 100 ]]; then
    echo "tmp_vol_0${i}_aff.nii.gz " >> tmp_filelist.txt
  fi
done

# Create the final volume with ec distortions
 fslmerge -t ${FILENAME}_ec.nii.gz `cat tmp_filelist.txt`

#Removing unncessary files
echo "    ==> Removing unncessary files (tmp, aff, brain_mask downsampled and resampled nii files)"
 rm aff* tmp* brain_mask.nii

echo ""
echo "***** Phantom reconstruction finished with success *****"
