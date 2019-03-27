#!/bin/bash

module load python3 sge

#SAMPLE_NAME=$1
#FILTER_LEN=$2
MANIFEST=$1

for i in $(awk -F"\t" '{print $1","$2}' $MANIFEST); do

	SAMPLE_NAME=$(echo $i |cut -f1 -d,)
	FILTER_LEN=$(echo $i |cut -f2 -d,)
	CMD="qsub -cwd -q long.q -o logs/${SAMPLE_NAME}_${FILTER_LEN}_canu.stdout -e logs/${SAMPLE_NAME}_${FILTER_LEN}_canu.stderr -N ${SAMPLE_NAME}_${FILTER_LEN}_canu -S /bin/sh mainSnake_canu.sh ${SAMPLE_NAME} ${FILTER_LEN}"
	echo $CMD
	eval $CMD
done
