#!/bin/bash

module load python3 sge

SAMPLE_NAME=$1
FILTER_LEN=$2

JOB_NUM=$(echo $SAMPLE_NAME | cut -f3 -d_)
WORKING_DIR=/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test

if [[ ! -s ${WORKING_DIR}/${SAMPLE_NAME}_plasmid/file.contigset_chromosomal.fasta ]];then
	mkdir ${WORKING_DIR}/${SAMPLE_NAME}_plasmid
	cd ${WORKING_DIR}/${SAMPLE_NAME}_plasmid
	
	mkdir logs
	cp /CGF/Resources/PacBio/jobs/001/00${JOB_NUM}/entry-points/*.subreadset.xml ./file${JOB_NUM}.subreadset.xml
	#cp consolidat_file1204.subreads.xml ./file${JOB_NUM}.subreadset.xml
	#created chromosomal only fasta file
	awk 'BEGIN {print ">000000F|arrow"} /000000F/{flag=1;next}/>/{flag=0}flag' /CGF/Resources/PacBio/jobs/001/00${JOB_NUM}/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta > file.contigset_chromosomal.fasta
fi

cd ${WORKING_DIR}/pipeline

CONF_CMD="--config JOB_NUM=${JOB_NUM} SAMPLE_NAME=${SAMPLE_NAME} FILTER_LENGTH=${FILTER_LEN}"
sbcmd="qsub -cwd -q all.q -o ${WORKING_DIR}/${SAMPLE_NAME}_plasmid/logs/ -e ${WORKING_DIR}/${SAMPLE_NAME}_plasmid/logs/"
snakemake -pr -s Snakefile_canu.py --keep-going --rerun-incomplete --local-cores 1 --jobs 6000 ${CONF_CMD} --cluster "${sbcmd}" --latency-wait 120 all
echo $CMD
eval $CMD

#check length distribution of non-chromosomal reads
#samtools view ${WORKING_DIR}/${SAMPLE_NAME}_plasmid/bamsieve_file${JOB_NUM}_nonchromosomal.subreads.bam | awk '{print length($10)}'  | sort | uniq -c > ${WORKING_DIR}/${SAMPLE_NAME}_plasmid/bamsieve_file${JOB_NUM}_nonchromosomal.subreads.length.txt


