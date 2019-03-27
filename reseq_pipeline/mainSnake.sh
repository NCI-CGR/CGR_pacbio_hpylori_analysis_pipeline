#!/bin/bash

module load python3 sge samtools

SAMPLE_NAME=$1

JOB_NUM=$(echo $SAMPLE_NAME | cut -f3 -d_)
WORKING_DIR=/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/${SAMPLE_NAME}/HGAP_run/Resequence
HGAP_ANALYSISID_PART1_PRE=$(echo $JOB_NUM | rev | cut -c4- | rev )
[ "$HGAP_ANALYSISID_PART1_PRE" ] || HGAP_ANALYSISID_PART1_PRE=0
HGAP_ANALYSISID_PART1=$(printf "%03d\n" $HGAP_ANALYSISID_PART1_PRE)
HGAP_ANALYSISID_PART2=$(echo $JOB_NUM | rev | cut -c1-3 | rev)
ls -l /CGF/Resources/PacBio/jobs/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/entry-points/*.subreadset.xml
if [[ ! -s ${WORKING_DIR}/file${JOB_NUM}.subreadset.xml ||  ! -s ${WORKING_DIR}/preads4falcon.fasta ]];then
	mkdir ${WORKING_DIR}
#	mkdir HGAP_filter${FILTER_LEN}_GL10000

	cp /CGF/Resources/PacBio/jobs/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/entry-points/*.subreadset.xml ${WORKING_DIR}/file${JOB_NUM}.subreadset.xml
	cp -l /CGF/Resources/PacBio/jobs/*/*${JOB_NUM}/tasks/falcon_ns2.tasks.task_falcon1_run_db2falcon-0/preads4falcon.fasta ${WORKING_DIR}/preads4falcon.fasta
#	cp -l /CGF/Resources/PacBio/jobs/*/*${JOB_NUM}/tasks/falcon_ns.tasks.task_falcon2_run_asm-0/preads4falcon.fasta ${WORKING_DIR}/preads4falcon.fasta
fi

CONF_CMD="--config JOB_NUM=${JOB_NUM} SAMPLE_NAME=${SAMPLE_NAME}"
sbcmd="qsub -cwd -q seq-gvcf.q -o ${WORKING_DIR}/../../logs/ -e ${WORKING_DIR}/../../logs/"
snakemake -pr --keep-going --rerun-incomplete --local-cores 1 --jobs 6000 ${CONF_CMD} --cluster "${sbcmd}" --latency-wait 120 all

