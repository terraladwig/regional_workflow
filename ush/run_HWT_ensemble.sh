#!/bin/bash -l

source /contrib/harrop/ufs-srweather-app-nadomain-gefs/env/build_aws_intel.env
source /contrib/harrop/ufs-srweather-app-nadomain-gefs/env/wflow_aws.env
module use /contrib/apps/modules
module load rocoto


# Run GEFS01
rocotorun -w /lustre/GEFS01/FV3LAM_wflow.xml -d /lustre/GEFS01/FV3LAM_wflow.db -v 10

# Run GEFS02
rocotorun -w /lustre/GEFS02/FV3LAM_wflow.xml -d /lustre/GEFS02/FV3LAM_wflow.db -v 10

# Run GFS
rocotorun -w /lustre/GFS/FV3LAM_wflow.xml -d /lustre/GFS/FV3LAM_wflow.db -v 10
