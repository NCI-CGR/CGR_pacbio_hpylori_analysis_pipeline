#!/bin/bash
. ./global_bash_config.rc
module load bwa/0.7.15 canu/1.5 prodigal/2.6.3 SPAdes/3.10.1 MUMmer/3.23 python python3


IN_FASTA=$1
PROCESSED_HGAP_DIR=$(dirname $IN_FASTA)
FINAL_FASTA_NAME=$(echo $PROCESSED_HGAP_DIR | cut -f7 -d/ | cut -f1 -d_)

CMD="circlator fixstart --genes_fa nusBx_rev.fa ${PROCESSED_HGAP_DIR}/000000Farrow.fa ${PROCESSED_HGAP_DIR}/000000F.fixstart"
echo $CMD
eval $CMD

#check if fixstart finish successfully

FIXSTART_LOG=$(grep 'No sequences left for which to look for genes using prodigal' ${PROCESSED_HGAP_DIR}/000000F.fixstart.detailed.log | wc -l)

if [[ $FIXSTART_LOG -gt 0 ]];then
	echo "fixstart of ${IN_FASTA} finished!"
else
	echo "fixstart of ${IN_FASTA} failed!"
	exit 1
fi

#mv the last 12 letters to the head
CMD="python3 ./fixformat.py ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta 60 > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta"
echo $CMD
eval $CMD

cat ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}*_plasmid*.fasta > ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
samtools faidx ${PROCESSED_HGAP_DIR}/basecall_ref.fasta

rm -R ${PROCESSED_HGAP_DIR}/*_basecall_ref 2>/dev/null
CMD="/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/fasta-to-reference ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${PROCESSED_HGAP_DIR} ${FINAL_FASTA_NAME}_basecall_ref"
echo $CMD
eval $CMD
