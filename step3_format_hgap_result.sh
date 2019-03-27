#!/bin/bash
. ./global_bash_config.rc
module load bwa/0.7.15 canu/1.5 prodigal/2.6.3 SPAdes/3.10.1 MUMmer/3.23 python python3

ORIGINAL_FASTQ=$1
ORIGINAL_FASTQ_DIR=$(dirname $ORIGINAL_FASTQ)
RESEQUENCE_FASTQ_DIR=${ORIGINAL_FASTQ_DIR}/../Resequence/circlator
PROCESSED_HGAP_DIR=${ORIGINAL_FASTQ_DIR}/../processed_hgap
FINAL_FASTA_NAME=$(echo $PROCESSED_HGAP_DIR |cut -f7 -d/ | cut -f1 -d_)
SAMPLE_NAME=$(echo $PROCESSED_HGAP_DIR |cut -f7 -d/ | cut -f1-3 -d_)
HGAP_ANALYSISID=$(echo $ORIGINAL_FASTQ_DIR | rev | cut -f1 -d_ | rev)
HGAP_ANALYSISID_PART1_PRE=$(echo $HGAP_ANALYSISID | rev | cut -c4- | rev )
HGAP_ANALYSISID_PART1=$(printf "%03d\n" $HGAP_ANALYSISID_PART1_PRE)
HGAP_ANALYSISID_PART2=$(echo $HGAP_ANALYSISID | rev | cut -c1-3 | rev)
STEP3_WORKING_FLAG=${ORIGINAL_FASTQ_DIR}/../../logs/step3_format_hgap.working
STEP3_DONE_FLAG=${ORIGINAL_FASTQ_DIR}/../../logs/step3_format_hgap.done

touch $STEP3_WORKING_FLAG
rm -r ${PROCESSED_HGAP_DIR}/ 
mkdir -p $PROCESSED_HGAP_DIR 2>/dev/null


#assume the largest contig is the bacteria contig
BAC_CHR=$(cat $ORIGINAL_FASTQ | awk '/^>/ {if(N>0) printf("\n"); printf("%s\t",$0);N++;next;} {printf("%s",$0);} END {if(N>0) printf("\n");}' |awk -F "\t" '{printf("%s\t%d\n",$1,length($2));}' |sort -n -k2 | tail -1 | cut -f1 |  sed s'/>//'| sed s'/|arrow//')
#assume the first contig  000000F or 0(if HGAP circular)is the largest one and we ll do start fix for it
#if [[ -s ${PROCESSED_HGAP_DIR}/${BAC_CHR}.fa ]];then

#if chromosomal contig is not circularized, label NC. 
CIRCULAR_CHROMOSOMAL=$(grep "${BAC_CHR}|arrow" ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: no' | wc -l)
if [[ $CIRCULAR_CHROMOSOMAL -gt 0 ]];then 
	RESEQ_BAC_CHR=$(awk '/^>/ {if(N>0) printf("\n"); printf("%s\t",$0);N++;next;} {printf("%s",$0);} END {if(N>0) printf("\n");}' ${RESEQUENCE_FASTQ_DIR}/05.clean.fasta|awk -F "\t" '{printf("%s\t%d\n",$1,length($2));}' |sort -n -k2 | tail -1 | cut -f1 |  sed s'/>//'| sed s'/|arrow//')
	RESEQ_CIRCULAR_CHROMOSOMAL=$(grep "${RESEQ_BAC_CHR}|arrow" ${RESEQUENCE_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: yes' | wc -l)
	if [[ $RESEQ_CIRCULAR_CHROMOSOMAL -gt 0 ]];then 
		ORIGINAL_FASTQ=${RESEQUENCE_FASTQ_DIR}/05.clean.fasta
		BAC_CHR=$RESEQ_BAC_CHR
		ORIGINAL_FASTQ_DIR=${RESEQUENCE_FASTQ_DIR}
		echo "${RESEQUENCE_FASTQ_DIR}/05.clean.fasta is circularized."
	else
		echo "${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta is not circularized."
	fi

fi


#split contigs into separate file
CMD="python split_ref_fasta.py $ORIGINAL_FASTQ $PROCESSED_HGAP_DIR"
echo $CMD
eval $CMD

mv ${PROCESSED_HGAP_DIR}/${BAC_CHR}\|arrow.fa ${PROCESSED_HGAP_DIR}/000000Farrow.fa
cp ${PACBIO_JOB_DIR}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/html/images/pbreports.tasks.coverage_report_hgap/coverage_plot_${BAC_CHR}.png ${PROCESSED_HGAP_DIR}/../../Report
#elif [[ -s ${PROCESSED_HGAP_DIR}/0\|arrow.fa ]];then
#	mv ${PROCESSED_HGAP_DIR}/0\|arrow.fa ${PROCESSED_HGAP_DIR}/000000Farrow.fa
#	cp ${PACBIO_JOB_DIR}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/html/images/pbreports.tasks.coverage_report_hgap/coverage_plot_0.png ${PROCESSED_HGAP_DIR}/../../Report
#fi

CMD="circlator fixstart --genes_fa nusBx_rev.fa ${PROCESSED_HGAP_DIR}/000000Farrow.fa ${PROCESSED_HGAP_DIR}/000000F.fixstart"
echo $CMD
eval $CMD

#check if fixstart finish successfully

FIXSTART_LOG=$(grep 'No sequences left for which to look for genes using prodigal' ${PROCESSED_HGAP_DIR}/000000F.fixstart.detailed.log | wc -l)

if [[ $FIXSTART_LOG -gt 0 ]];then
	echo "fixstart of ${ORIGINAL_FASTQ} finished!"
else
	echo "fixstart of ${ORIGINAL_FASTQ} failed!"
	exit 1
fi

#compare 26695 to the chr contig
dnadiff NCBI_26695/h-pylori-26695-NC_000915-1_fix.fasta ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta -p ${PROCESSED_HGAP_DIR}/26695_vs_${SAMPLE_NAME}
 mummerplot --png -p ${PROCESSED_HGAP_DIR}/26695_vs_${SAMPLE_NAME}_mummerplot ${PROCESSED_HGAP_DIR}/26695_vs_${SAMPLE_NAME}.delta -R NCBI_26695/h-pylori-26695-NC_000915-1_fix.fasta -Q ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta

#mv the last 12 letters to the head
CMD="python3 ./fixformat.py ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta 60 > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta"
echo $CMD
eval $CMD

#samtools faidx ${PROCESSED_HGAP_DIR}/000000F.final.fasta
#CMD="/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/fasta-to-reference ${PROCESSED_HGAP_DIR}/000000F.final.fasta ${PROCESSED_HGAP_DIR} ${FINAL_FASTA_NAME}_chromosomal"
#echo $CMD
#eval $CMD

cp ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta

if [[ $CIRCULAR_CHROMOSOMAL -gt 0 ]] && [[ $RESEQ_CIRCULAR_CHROMOSOMAL -eq 0 ]];then 
	mv ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal_NC.fasta
fi

if [[ -d "${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid" ]]; then
	FOLLOWUP_CIRCULAR_PLASMID=$(grep 'Circularized: yes' ${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid/*/circlator/04.merge.circularise_details.log | wc -l)
fi

if [[ $FOLLOWUP_CIRCULAR_PLASMID -gt 0 ]];then
	echo "${FINAL_FASTA_NAME} has a circular plasmid through plasmid followup process."
	CIRCULAR_DIR=$(grep -l 'Circularized: yes' ${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid/*/circlator/04.merge.circularise_details.log | head -1 | xargs dirname )
	CIR_NAMES=$(grep 'Circularized: yes' ${CIRCULAR_DIR}/04.merge.circularise_details.log  | awk -F "\t" '{print $2}'| cut -f1 -d\|)
	echo ${CIRCULAR_DIR}
	#sed -i 's/000000F/followup1/' ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup1_plasmid.fasta
	CIRCULAR_DIR_PART2=$(echo $CIRCULAR_DIR | cut -f2-3 -d_)
	for i in ${CIR_NAMES};do
		
		awk -v name=$i 'BEGIN {print ">followup"name"|arrow"} $0~name {flag=1;next}/>/{flag=0}flag'  ${CIRCULAR_DIR}/05.clean.fasta > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid.fasta 
		##in case there are ciruclarized contig that are deleted because it is duplicated with previous contig
		HAS_SEQ=$(wc -l ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid.fasta  | cut -f1 -d' ')
		#echo $HAS_SEQ
		if [[ ${HAS_SEQ} -gt 1 ]]; then
			cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid.fasta > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
			mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
			cp ${CIRCULAR_DIR}/../html/images/pbreports.tasks.coverage_report_hgap/coverage_plot_${i}.png ${PROCESSED_HGAP_DIR}/../../Report/coverage_plot_followup${i}.png
		else
			rm ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid.fasta
		fi
	done

	UNCIR_NAMES=`grep 'Circularized: no-include' ${CIRCULAR_DIR}/04.merge.circularise_details.log | awk -F "\t" '{print $2}' | cut -f1 -d\|`

	for i in ${UNCIR_NAMES};do
		echo "use uncircular plasmid contig from followup pipeline."
		cp ${CIRCULAR_DIR}/../html/images/pbreports.tasks.coverage_report_hgap/coverage_plot_${i}.png ${PROCESSED_HGAP_DIR}/../../Report/coverage_plot_followup${i}.png
		awk -v name=$i 'BEGIN {print ">followup"name"|arrow"} $0~name {flag=1;next}/>/{flag=0}flag' ${CIRCULAR_DIR}/05.clean.fasta > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid_NC.fasta 
		cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid_NC.fasta > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
		mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
	done	
fi	
	
#get plasmid circular fasta
for i in ${PROCESSED_HGAP_DIR}/*\|arrow.fa;do
	#echo $i
	NAME=$(basename $i .fa)
	IMAGE_NAME=$(echo $NAME | cut -f1 -d\|)
	#echo $NAME
	CIRCULAR_PLASMID=$(grep "$NAME" ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: yes' | wc -l)
	UNCIRCULAR_PLASMID=$(grep "$NAME" ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: no-include' | wc -l)
	echo $CIRCULAR_PLASMID
	if [[ $CIRCULAR_PLASMID -gt 0 ]];then 
		echo "$i is circularized plasmid."
		cp $i ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid.fasta
		cp ${PACBIO_JOB_DIR}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/html/images/pbreports.tasks.coverage_report_hgap/coverage_plot_${IMAGE_NAME}.png ${PROCESSED_HGAP_DIR}/../../Report
		cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta $i > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
		mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
	elif [[ $UNCIRCULAR_PLASMID -gt 0 ]];then 
		echo "$i is uncircularized plasmid to include mannualy."
		cp $i ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid_NC.fasta
		cp ${PACBIO_JOB_DIR}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/html/images/pbreports.tasks.coverage_report_hgap/coverage_plot_${IMAGE_NAME}.png ${PROCESSED_HGAP_DIR}/../../Report
		cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta $i > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
		mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta

	fi 
done


samtools faidx ${PROCESSED_HGAP_DIR}/basecall_ref.fasta

CMD="/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/fasta-to-reference ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${PROCESSED_HGAP_DIR} ${FINAL_FASTA_NAME}_basecall_ref"
echo $CMD
eval $CMD

mv $STEP3_WORKING_FLAG  $STEP3_DONE_FLAG

