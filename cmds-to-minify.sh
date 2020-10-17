#!/usr/bin/env bash

set -e

if [ ! -d /mnt/BIDS ]; then
    echo "error: directory not found: /mnt/BIDS"
    echo ""
    echo "Be sure to mount the data directory to /mnt"
    exit 1
fi

# Run tests to capture external software dependencies
5ttgen fsl /mnt/BIDS/sub-01/anat/sub-01_T1w.nii.gz /tmp/5ttgen_fsl.mif -force
rm -f /tmp/5ttgen_fsl.mif

5ttgen hsvs /mnt/freesurfer/sub-01 /tmp/5ttgen_hsvs.mif -force
rm -f /tmp/5ttgen_hsvs.mif

dwibiascorrect ants /mnt/BIDS/sub-01/dwi/sub-01_dwi.nii.gz \
    -fslgrad /mnt/BIDS/sub-01/dwi/sub-01_dwi.bvec /mnt/BIDS/sub-01/dwi/sub-01_dwi.bval /tmp/dwibiascorrect_ants.mif -force
rm -f /tmp/dwibiascorrect_ants.mif

dwibiascorrect fsl /mnt/BIDS/sub-01/dwi/sub-01_dwi.nii.gz \
    -fslgrad /mnt/BIDS/sub-01/dwi/sub-01_dwi.bvec /mnt/BIDS/sub-01/dwi/sub-01_dwi.bval /tmp/dwibiascorrect_fsl.mif -force
rm -f /tmp/dwibiascorrect_fsl.mif

mrconvert /mnt/BIDS/sub-04/fmap/sub-04_dir-1_epi.nii.gz \
    -json_import /mnt/BIDS/sub-04/fmap/sub-04_dir-1_epi.json /tmp/dir-1_epi.mif -force
mrconvert /mnt/BIDS/sub-04/fmap/sub-04_dir-2_epi.nii.gz \
    -json_import /mnt/BIDS/sub-04/fmap/sub-04_dir-2_epi.json /tmp/dir-2_epi.mif -force
mrcat /tmp/dir-1_epi.mif /tmp/dir-2_epi.mif /tmp/seepi.mif -axis 3 -force
rm -f /tmp/dir-1_epi.mif /tmp/dir-2_epi.mif
dwifslpreproc /mnt/BIDS/sub-04/dwi/sub-04_dwi.nii.gz \
    -fslgrad /mnt/BIDS/sub-04/dwi/sub-04_dwi.bvec /mnt/BIDS/sub-04/dwi/sub-04_dwi.bval /tmp/dwifslpreproc.mif \
    -pe_dir ap -readout_time 0.1 -rpe_pair -se_epi /tmp/seepi.mif \
    -eddyqc_all /tmp/eddyqc -force
rm -rf /tmp/seepi.mif /tmp/dwifslpreproc.mif /tmp/eddyqc

labelsgmfix /mnt/BIDS/sub-01/anat/aparc+aseg.mgz /mnt/BIDS/sub-01/anat/sub-01_T1w.nii.gz \
    /mnt/labelsgmfix/FreeSurferColorLUT.txt /tmp/labelsgmfix.mif -force
rm -f /tmp/labelsgmfix.mif

