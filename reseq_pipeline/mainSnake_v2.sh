#!/bin/bash
. ../global_bash_config.rc
module load python3 sge samtools

SAMPLE_NAME=$1

JOB_NUM=$(echo $SAMPLE_NAME | cut -f3 -d_)
WORKING_DIR=/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/${SAMPLE_NAME}/HGAP_run/Resequence
#pacbio job path is always changing, get the length of jobid and append correct number of 0s to the job id to locate the file path
NUM=$(echo -n $JOB_NUM | wc -c)
DOT=""
for j in seq 1 $NUM;do DOT="${DOT}.";done
HGAP_ANALYSISID_PART2=$(echo 000000000 | sed "s/$DOT$/$JOB_NUM/")
echo $HGAP_ANALYSISID_PART2
HGAP_ANALYSISID_PART1=$(echo $HGAP_ANALYSISID_PART2 | cut -c1-7)
echo $HGAP_ANALYSISID_PART1
REAL_JOB_DIR=$(readlink ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/cromwell-job)
echo ${REAL_JOB_DIR}
#if the subreads comes from multiple smrtcell, it will be the eid_subread_merged.subreadset.xml
if [[ -f /CGF/Resources/PacBio/jobs/0000/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/eid_subread_merged.subreadset.xml ]]; then 
	SUBREADS_XML=/CGF/Resources/PacBio/jobs/0000/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/eid_subread_merged.subreadset.xml
else
	SUBREADS_XML=$(ls /CGF/Resources/PacBio/jobs/0000/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/entry-points/*.subreadset.xml)
fi

CHR_FASTA=$(find ${REAL_JOB_DIR} -name "preads4falcon.fasta" | tail -1)
echo ${CHR_FASTA}
if [[ ! -s ${WORKING_DIR}/file${JOB_NUM}.subreadset.xml ||  ! -s ${WORKING_DIR}/preads4falcon.fasta ]];then
	mkdir ${WORKING_DIR}
#	mkdir HGAP_filter${FILTER_LEN}_GL10000

	cp ${SUBREADS_XML} ${WORKING_DIR}/file${JOB_NUM}.subreadset.xml
	
	cp -l ${CHR_FASTA} ${WORKING_DIR}/preads4falcon.fasta
#	cp -l /CGF/Resources/PacBio/jobs/*/*${JOB_NUM}/tasks/falcon_ns.tasks.task_falcon2_run_asm-0/preads4falcon.fasta ${WORKING_DIR}/preads4falcon.fasta
fi

CONF_CMD="--config JOB_NUM=${JOB_NUM} SAMPLE_NAME=${SAMPLE_NAME}"
sbcmd="qsub -cwd -q seq-gvcf.q -o ${WORKING_DIR}/../../logs/ -e ${WORKING_DIR}/../../logs/"
snakemake -pr --keep-going --rerun-incomplete --local-cores 1 --jobs 6000 ${CONF_CMD} --cluster "${sbcmd}" --latency-wait 120 all

