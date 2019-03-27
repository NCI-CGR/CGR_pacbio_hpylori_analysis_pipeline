#!/bin/bash

module load python3 sge

#SAMPLE_NAME=$1
#FILTER_LEN=$2
MANIFEST=$1

for i in $(awk -F"\t" '{print $1","$2}' $MANIFEST); do

	SAMPLE_NAME=$(echo $i |cut -f1 -d,)
	PLASMID_CONTIG=$(echo $i |cut -f2 -d,)
	CMD="qsub -cwd -q long.q -o logs/${SAMPLE_NAME}_reseq.stdout -e logs/${SAMPLE_NAME}_reseq.stderr -N ${SAMPLE_NAME}_reseq -S /bin/sh mainSnake_resequence.sh ${SAMPLE_NAME} ${PLASMID_CONTIG}"
	echo $CMD
	eval $CMD
done
