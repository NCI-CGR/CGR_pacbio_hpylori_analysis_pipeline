#!/bin/bash
. ./global_bash_config.rc

MANIFEST=$1
rm step4_basemod_call_submit.std*
CMD="qsub -cwd -q $QUEUE -N Step4_basemod_call_submit -e step4_basemod_call_submit.stderr -o step4_basemod_call_submit.stdout -S /bin/sh step4_running_basemod.sh $MANIFEST"
echo $CMD
eval $CMD
