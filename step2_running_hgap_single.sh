#!/bin/bash
. ./global_bash_config.rc

SAMP=$1
HGAP_ANALYSISID=$2


run_ccs () {
    if [[ -f /CGF/Resources/PacBio/jobs/0000/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/merge-datasets/outputs/merged.subreadset.xml ]]; then 
	    SUBREADS_XML=/CGF/Resources/PacBio/jobs/0000/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/merge-datasets/outputs/merged.subreadset.xml
    else
	    SUBREADS_XML=$(ls /CGF/Resources/PacBio/jobs/0000/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/entry-points/*/*.consensusreadset.xml)
    fi
    mkdir -p ${1} 
    ${SMRTCMDS10}/dataset consolidate ${SUBREADS_XML} ${1}/ccs.bam ${1}/ccs.xml
	samtools fastq ${1}/ccs.bam | bgzip > ${1}/ccs.Q20.fastq.gz
}

run_hifiasm () {
    mkdir -p ${ROOT_DIR}/${SAMP}/hifiasm_run/2>/dev/null
    /home/luow2/tools/hifiasm/hifiasm -o ${ROOT_DIR}/${SAMP}/hifiasm_run/${SAMP}.asm -t 4 ${1}
	#only select contig with coverage higher than 15, depth in column 5
    awk '{if($1=="S" && int(substr($5,6))>15){print ">"$2"\t"$5"\n"$3}}' ${ROOT_DIR}/${SAMP}/hifiasm_run/${SAMP}.asm.p_ctg.gfa > ${ROOT_DIR}/${SAMP}/hifiasm_run/${SAMP}.asm.fasta
}




#pacbio job path is always changing, get the length of jobid and append correct number of 0s to the job id to locate the file path
NUM=$(echo -n $HGAP_ANALYSISID | wc -c)
DOT=""
for j in `seq 1 $NUM`;do DOT="${DOT}.";done
HGAP_ANALYSISID_PART2=$(echo $JOB_PATH_LEN | sed "s/$DOT$/$HGAP_ANALYSISID/")
echo $HGAP_ANALYSISID_PART2
HGAP_ANALYSISID_PART1=$(echo $HGAP_ANALYSISID_PART2 | cut -c1-7)
echo $HGAP_ANALYSISID_PART1
REAL_JOB_DIR=$(readlink ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/cromwell-job)
echo $REAL_JOB_DIR

ANALYSIS_TYPE=$(dirname ${REAL_JOB_DIR} | xargs basename)
echo $ANALYSIS_TYPE
repeat_check ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/polished_assembly.fasta ${ROOT_DIR}/${SAMP}/HGAP_run/NUCMER

# echo "#####################Starting CCS and hifiasm for sample ${SAMP}#####################"
run_ccs ${ROOT_DIR}/${SAMP}/pb_ccs
run_hifiasm ${ROOT_DIR}/${SAMP}/pb_ccs/ccs.Q20.fastq.gz
run_circlator ${ROOT_DIR}/${SAMP}/hifiasm_run/${SAMP}.asm.fasta ${ROOT_DIR}/${SAMP}/pb_ccs/ccs.Q20.fastq.gz ${ROOT_DIR}/${SAMP}/hifiasm_run/circlator 

echo "#####################Starting circlator for sample ${SAMP} raw reads assembly #####################"
	
if [[ $ANALYSIS_TYPE == pb_assembly_microbial ]]; then
    PLASMID_FASTA=$(find ${REAL_JOB_DIR} -name "preads4falcon.fasta" | grep call-asm_plasmid)
	CHR_FASTA=$(find ${REAL_JOB_DIR} -name "preads4falcon.fasta" | grep call-asm_chrom | head -1)
	BAC_CHR=$(cat ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/consensus.fasta | awk '/^>/ {if(N>0) printf("\n"); printf("%s\t",$0);N++;next;} {printf("%s",$0);} END {if(N>0) printf("\n");}' |awk -F "\t" '{printf("%s\t%d\n",$1,length($2));}' |sort -n -k2 | tail -1 | cut -f1 |  sed s'/>//' )
    python fasta_remove.py ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/consensus.fasta "${BAC_CHR}" ${ROOT_DIR}/${SAMP}/HGAP_run/plasmid_only.fasta 
	run_circlator ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/consensus.fasta ${PLASMID_FASTA} ${ROOT_DIR}/${SAMP}/HGAP_run/circlator_${HGAP_ANALYSISID}
	#run_circlator ${ROOT_DIR}/${SAMP}/HGAP_run/plasmid_only.fasta ${PLASMID_FASTA} ${ROOT_DIR}/${SAMP}/HGAP_run/circlator_${HGAP_ANALYSISID}_plasmid 

		
elif [[ $ANALYSIS_TYPE == pb_hgap4 ]]; then
    RAW_FASTA=$(find ${REAL_JOB_DIR} -name "preads4falcon.fasta" | tail -1)
	run_circlator ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/consensus.fasta ${RAW_FASTA} ${ROOT_DIR}/${SAMP}/HGAP_run/circlator_${HGAP_ANALYSISID}
elif [[ $ANALYSIS_TYPE == pb_microbial_analysis ]]; then
	BAC_CHR=$(cat ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/polished_assembly.fasta | awk '/^>/ {if(N>0) printf("\n"); printf("%s\t",$0);N++;next;} {printf("%s",$0);} END {if(N>0) printf("\n");}' |awk -F "\t" '{printf("%s\t%d\n",$1,length($2));}' |sort -n -k2 | tail -1 | cut -f1 |  sed s'/>//' )
    python fasta_remove.py ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/polished_assembly.fasta "${BAC_CHR}" ${ROOT_DIR}/${SAMP}/HGAP_run/plasmid_only.fasta 
	run_circlator ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/polished_assembly.fasta ${ROOT_DIR}/${SAMP}/pb_ccs/ccs.Q20.fastq.gz ${ROOT_DIR}/${SAMP}/HGAP_run/circlator_${HGAP_ANALYSISID}

else
	echo "$ANALYSIS_TYPE not found. Skip raw reads assembly!"
fi


echo "#####################Starting prokka annotation sample ${SAMP}#####################"


run_prokka ${ROOT_DIR}/${SAMP}/HGAP_run/circlator_${HGAP_ANALYSISID}/06.fixstart.fasta ${SAMP} ${ROOT_DIR}/${SAMP}/HGAP_run/prokka_protein
echo -e "${gene}\t${cds}\t${rRNA}\t${tRNA}\t${psuedoFrac}" > ${ROOT_DIR}/${SAMP}/Report/temp/raw_assemble_annotation.txt

run_prokka ${ROOT_DIR}/${SAMP}/hifiasm_run/circlator/06.fixstart.fasta ${SAMP} ${ROOT_DIR}/${SAMP}/hifiasm_run/prokka_protein
echo -e "${gene}\t${cds}\t${rRNA}\t${tRNA}\t${psuedoFrac}" > ${ROOT_DIR}/${SAMP}/Report/temp/hifi_assemble_annotation.txt


chmod 777 ${ROOT_DIR}/${SAMP}/logs/step2_circlator.working 	
mv ${ROOT_DIR}/${SAMP}/logs/step2_circlator.working ${ROOT_DIR}/${SAMP}/logs/step2_circlator.done

