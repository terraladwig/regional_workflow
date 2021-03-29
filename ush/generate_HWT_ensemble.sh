#!/bin/env bash

# Generate the GEFS01
cp config.sh.gefs01 config.sh
./generate_FV3LAM_wflow.sh

# Generate the GEFS02
sed -i -e 's/GEFS01/GEFS02/g' config.sh
sed -i -e 's/GEFS_MEMBER=01/GEFS_MEMBER=02/g' config.sh
./generate_FV3LAM_wflow.sh

# Generate the GFS
cp config.sh.gfs config.sh
./generate_FV3LAM_wflow.sh

