#!/bin/bash

module load python3 sge samtools

SAMPLE_NAME=$1
FILTER_LEN=$2

JOB_NUM=$(echo $SAMPLE_NAME | cut -f3 -d_)
WORKING_DIR=/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test
HGAP_ANALYSISID_PART1_PRE=$(echo $JOB_NUM | rev | cut -c4- | rev )
[ "$HGAP_ANALYSISID_PART1_PRE" ] || HGAP_ANALYSISID_PART1_PRE=0
HGAP_ANALYSISID_PART1=$(printf "%03d\n" $HGAP_ANALYSISID_PART1_PRE)
HGAP_ANALYSISID_PART2=$(echo $JOB_NUM | rev | cut -c1-3 | rev)
ls -l /CGF/Resources/PacBio/jobs/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/entry-points/*.subreadset.xml
if [[ ! -s ${WORKING_DIR}/${SAMPLE_NAME}_plasmid/file.contigset_chromosomal.fasta ]];then
	mkdir ${WORKING_DIR}/${SAMPLE_NAME}_plasmid
	cd ${WORKING_DIR}/${SAMPLE_NAME}_plasmid
#	mkdir HGAP_filter${FILTER_LEN}_GL10000
	mkdir logs
	cp /CGF/Resources/PacBio/jobs/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/entry-points/*.subreadset.xml ./file${JOB_NUM}.subreadset.xml
	#cp consolidat_file1204.subreads.xml ./file${JOB_NUM}.subreadset.xml
	#created chromosomal only fasta file
	BAC_CHR=$(cat /CGF/Resources/PacBio/jobs/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta | awk '/^>/ {if(N>0) printf("\n"); printf("%s\t",$0);N++;next;} {printf("%s",$0);} END {if(N>0) printf("\n");}' |awk -F "\t" '{printf("%s\t%d\n",$1,length($2));}' |sort -n -k2 | tail -1 | cut -f1 |  sed s'/>//'| sed s'/|arrow//')
	awk -v chr=$BAC_CHR 'BEGIN {print ">chr|arrow"} /chr/{flag=1;next}/>/{flag=0}flag' /CGF/Resources/PacBio/jobs/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta > file.contigset_chromosomal.fasta
	#awk 'BEGIN {print ">3|arrow"} /3/{flag=1;next}/>/{flag=0}flag' /CGF/Resources/PacBio/jobs/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta > file.contigset_chromosomal.fasta
fi

mkdir ${WORKING_DIR}/${SAMPLE_NAME}_plasmid/HGAP_filter${FILTER_LEN}_GL10000
cd ${WORKING_DIR}/pipeline

CONF_CMD="--config JOB_NUM=${JOB_NUM} SAMPLE_NAME=${SAMPLE_NAME} FILTER_LENGTH=${FILTER_LEN}"
sbcmd="qsub -cwd -q all.q -o ${WORKING_DIR}/${SAMPLE_NAME}_plasmid/logs/ -e ${WORKING_DIR}/${SAMPLE_NAME}_plasmid/logs/"
snakemake -pr --keep-going --rerun-incomplete --local-cores 1 --jobs 6000 ${CONF_CMD} --cluster "${sbcmd}" --latency-wait 120 all
#echo $CMD
#eval $CMD

#check length distribution of non-chromosomal reads
samtools view ${WORKING_DIR}/${SAMPLE_NAME}_plasmid/bamsieve_file${JOB_NUM}_nonchromosomal.subreads.bam | awk '{print length($10)}'  | sort | uniq -c > ${WORKING_DIR}/${SAMPLE_NAME}_plasmid/bamsieve_file${JOB_NUM}_nonchromosomal.subreads.length.txt


