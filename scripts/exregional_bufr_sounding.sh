#!/bin/bash
#
#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHDIR/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
# adding modules here
module purge
module use ~rtrr/RRFS/sorc/EMC_post/modulefiles
module load post/v8.0.0-jet
module list
#
{ save_shell_opts; set -u +x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located 
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Print message indicating entry into script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Entering script:  \"${scrfunc_fn}\"
In directory:     \"${scrfunc_dir}\"

This is the ex-script for the task that generates bufr soundings for
the output files corresponding to a specified forecast hour.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.  
# Then process the arguments provided to this script/function (which 
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( \
"EXECDIR" \
"DATADIR" \
"FIXSAR" \
"COMOUT" \
)
process_args valid_args "$@"
#
#-----------------------------------------------------------------------
#
# For debugging purposes, print out values of arguments passed to this
# script.  Note that these will be printed out only if VERBOSE is set to
# TRUE.
#
#-----------------------------------------------------------------------
#
print_input_args valid_args
#
#
#-----------------------------------------------------------------------
#
# Get the cycle date and hour (in formats of yyyymmdd and hh, respect-
# ively) from CDATE.
#
#-----------------------------------------------------------------------
#
yyyymmdd=${CDATE:0:8}
hh=${CDATE:8:2}
cyc=${hh}
tmmark="tm${hh}"
#
#
BUFREXEC=${EXECDIR}/regional_bufr.x
# This fix files is designed for GSL RRFS output grid in real-time runs as of April 2021.
cp_vrfy ${FIXSAR}/conusfv3sar_lambert_profdat_rrfs_1746x1014_nstat1850 hiresw_profdat

OUTTYP=netcdf

model=FV3S

POST_TIME=$( date --utc --date "${yyyymmdd} ${hh} UTC + ${cyc} hours" "+%Y%m%d%H" )
POST_YYYY=${POST_TIME:0:4}
POST_MM=${POST_TIME:4:2}
POST_DD=${POST_TIME:6:2}
POST_HH=${POST_TIME:8:2}

STARTDATE=${POST_YYYY}-${POST_MM}-${POST_DD}_${POST_HH}:00:00

FHRLIM=${FCST_LEN_HRS}
INCR=01
NFILE=1
forecast_hour=00

echo "Generate BUFR soundings for $FHRLIM"
while [ $forecast_hour -le $FHRLIM ]
do

fhrstr=$(printf "%03d" ${forecast_hour#0})

dyn_file="${CYCLE_DIR}/fcst_fv3lam/dynf0${forecast_hour}.nc"
phy_file="${CYCLE_DIR}/fcst_fv3lam/phyf0${forecast_hour}.nc"

# check for existence of sndpostdone files

echo $DATADIR
cd ${DATADIR}
pwd

echo "Processing forecast hour $forecast_hour"

cat > itag <<EOF
$dyn_file
$phy_file
$model
$OUTTYP
$STARTDATE
$NFILE
$INCR
$forecast_hour
$dyn_file
$phy_file
EOF

ln -sfn ${DATADIR}/hiresw_profdat fort.19
ln -sfn ${DATADIR}/profilm.c1.${tmmark} fort.79
ln -sfn ${DATADIR}/itag fort.11

#For Jet
APRUN="srun"

#${APRUN} ${BUFREXEC} || print_err_msg_exit "\
${BUFREXEC} || print_err_msg_exit "\
Call to executable to run bufr for forecast hour $forecast_hour returned with non-
zero exit code."

ls -ltr

mv ${DATADIR}/profilm.c1.${tmmark} ${DATADIR}/profilm.c1.${tmmark}.f${fhrstr}

echo DONE $forecast_hour at `date`

forecast_hour=`expr $forecast_hour + $INCR`

if [ $forecast_hour -lt 10 ]
then
forecast_hour=0$forecast_hour
fi

done

forecast_hour=00

while [ $forecast_hour -le $FHRLIM ]
do

fhrstr=$(printf "%03d" ${forecast_hour#0})

if [[ $forecast_hour -eq 0 ]]; then
  cat ${DATADIR}/profilm.c1.${tmmark}.f${fhrstr} > ${DATADIR}/profilm.c1.${tmmark}
  echo "cat ${DATADIR}/profilm.c1.${tmmark}.f${fhrstr} > ${DATADIR}/profilm.c1.${tmmark}"
else
  cat ${DATADIR}/profilm.c1.${tmmark}  ${DATADIR}/profilm.c1.${tmmark}.f${fhrstr} > ${DATADIR}/profilm_int
  echo "cat ${DATADIR}/profilm.c1.${tmmark}  ${DATADIR}/profilm.c1.${tmmark}.f${fhrstr} > ${DATADIR}/profilm_int"
  mv_vrfy ${DATADIR}/profilm_int ${DATADIR}/profilm.c1.${tmmark}
  echo "mv_vrfy ${DATADIR}/profilm_int ${DATADIR}/profilm.c1.${tmmark}"
fi

forecast_hour=`expr $forecast_hour + $INCR`

if [ $forecast_hour -lt 10 ]
then
forecast_hour=0$forecast_hour
fi

done

########################################################
############### SNDP code
########################################################

SNDPEXEC=${EXECDIR}/regional_sndp.x

cp_vrfy ${FIXSAR}/hiresw_sndp.parm.mono ${DATADIR}/hiresw_sndp.parm.mono
cp_vrfy ${FIXSAR}/hiresw_bufr.tbl ${DATADIR}/hiresw_bufr.tbl

rm fort.11
rm itag

ln -s ${DATADIR}/hiresw_sndp.parm.mono fort.11
ln -s ${DATADIR}/hiresw_bufr.tbl fort.32
ln -s ${DATADIR}/profilm.c1.${tmmark} fort.66
ln -s ${DATADIR}/class1.bufr fort.78

nlev=64

echo "${model} ${nlev}" > itag
#${APRUN} ${SNDPEXEC} < itag || print_err_msg_exit "\
${SNDPEXEC} < itag || print_err_msg_exit "\
Call to executable to run SNDP for forecast hour $forecast_hour returned with non-
zero exit code."

############### Convert BUFR output into format directly readable by GEMPAK namsnd

rm -f ${DATADIR}/bufr.CONUS_${model}_${cyc}

rm -f ${DATADIR}/stnmlist_input

mkdir_vrfy -p ${DATADIR}/bufr.CONUS_${model}_${cyc}

cat <<EOF > stnmlist_input
1
${DATADIR}/class1.bufr
${DATADIR}/bufr.CONUS_${model}_${cyc}/CONUS_${model}_bufr
EOF

STNMEXEC=${EXECDIR}/regional_stnmlist.x

ln -s ${DATADIR}/class1.bufr fort.20
DIRD=${DATADIR}/bufr.CONUS_${model}_${cyc}/CONUS_${model}_bufr

#${APRUN} ${STNMEXEC} < stnmlist_input || print_err_msg_exit "\
${STNMEXEC} < stnmlist_input || print_err_msg_exit "\
Call to executable to run STNM for forecast hour $forecast_hour returned with non-
zero exit code."

echo ${DATADIR}/bufr.CONUS_${model}_${cyc} > ${DATADIR}/bufr.CONUS_${model}_${cyc}/bufrloc

cd ${DATADIR}/bufr.CONUS_${model}_${cyc}

# Tar and gzip the individual bufr files and send them to /com
tar -cf - . | /usr/bin/gzip > ../${RUN}.t${cyc}z.bufrsnd.tar.gz


#copy final file to com
cp_vrfy ../${RUN}.t${cyc}z.bufrsnd.tar.gz ${COMOUT}/${RUN}.t${cyc}z.bufrsnd.tar.gz

#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Task to create bufr sounding for forecast hour $forecast_hour completed successfully.

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

