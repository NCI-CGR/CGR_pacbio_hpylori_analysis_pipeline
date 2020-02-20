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
FIXSTART_SEQ=nusBx_rev.fa
#pacbio job path is always changing, get the length of jobid and append correct number of 0s to the job id to locate the file path
NUM=$(echo -n $HGAP_ANALYSISID | wc -c)
DOT=""
for j in seq 1 $NUM;do DOT="${DOT}.";done
HGAP_ANALYSISID_PART2=$(echo $JOB_PATH_LEN | sed "s/$DOT$/$HGAP_ANALYSISID/")
echo $HGAP_ANALYSISID_PART2
HGAP_ANALYSISID_PART1=$(echo $HGAP_ANALYSISID_PART2 | cut -c1-7)
echo $HGAP_ANALYSISID_PART1
REAL_JOB_DIR=$(readlink ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/cromwell-job)
#get the coverage plot directory
ANALYSIS_TYPE=$(dirname ${REAL_JOB_DIR} | xargs basename)
if [[ $ANALYSIS_TYPE == pb_assembly_microbial ]]; then
	COVP_DIR=$(ls -d ${REAL_JOB_DIR}/call-mapping_all/RaptorGraphMapping/*/call-coverage_report/execution/)
elif [[ $ANALYSIS_TYPE == pb_hgap4 ]]; then
	COVP_DIR=${REAL_JOB_DIR}/call-coverage_report/execution/
fi

STEP3_WORKING_FLAG=${ORIGINAL_FASTQ_DIR}/../../logs/step3_format_hgap.working
STEP3_DONE_FLAG=${ORIGINAL_FASTQ_DIR}/../../logs/step3_format_hgap.done

touch $STEP3_WORKING_FLAG
rm -r ${PROCESSED_HGAP_DIR}/ 
mkdir -p $PROCESSED_HGAP_DIR 2>/dev/null

#split contigs into separate file
CMD="python split_ref_fasta.py $ORIGINAL_FASTQ $PROCESSED_HGAP_DIR"
echo $CMD
eval $CMD


echo "###########################"
echo "Reformatting chromosomal contig."
echo "###########################"

#assume the largest contig is the bacteria contig
#for cases bacteria contig not in 1 piece, mannual lable the smaller piece as chr instead of plasmid
BAC_CHR=$(cat $ORIGINAL_FASTQ | awk '/^>/ {if(N>0) printf("\n"); printf("%s\t",$0);N++;next;} {printf("%s",$0);} END {if(N>0) printf("\n");}' |awk -F "\t" '{printf("%s\t%d\n",$1,length($2));}' |sort -n -k2 | tail -1 | cut -f1 |  sed s'/>//'| sed s'/|arrow//')

mv ${PROCESSED_HGAP_DIR}/${BAC_CHR}\|arrow*.fa ${PROCESSED_HGAP_DIR}/000000Farrow.fa
cp ${COVP_DIR}/coverage_plot_${BAC_CHR}.png ${PROCESSED_HGAP_DIR}/../../Report

#check if chromosomal contig is circularized, otherwise, use the chromosomal contig from reseq pipeline. 
CIRCULAR_CHROMOSOMAL=$(grep "${BAC_CHR}|arrow" ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: no' | wc -l)
if [[ $CIRCULAR_CHROMOSOMAL -gt 0 ]];then 

	RESEQ_BAC_CHR=$(awk '/^>/ {if(N>0) printf("\n"); printf("%s\t",$0);N++;next;} {printf("%s",$0);} END {if(N>0) printf("\n");}' ${RESEQUENCE_FASTQ_DIR}/05.clean.fasta|awk -F "\t" '{printf("%s\t%d\n",$1,length($2));}' |sort -n -k2 | tail -1 | cut -f1 |  sed s'/>//'| sed s'/|arrow//g')
	RESEQ_CIRCULAR_CHROMOSOMAL=$(grep "${RESEQ_BAC_CHR}|arrow" ${RESEQUENCE_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: yes' | wc -l)
	if [[ $RESEQ_CIRCULAR_CHROMOSOMAL -gt 0 ]];then 
		ORIGINAL_FASTQ=${RESEQUENCE_FASTQ_DIR}/05.clean.fasta
		BAC_CHR=$RESEQ_BAC_CHR
#if using plasmid from reseq assenble result, uncomment the following line to change fastq directory for plasmid format
#		ORIGINAL_FASTQ_DIR=${RESEQUENCE_FASTQ_DIR}
        CMD="python split_ref_fasta.py ${RESEQUENCE_FASTQ_DIR}/05.clean.fasta ${RESEQUENCE_FASTQ_DIR}"
		echo $CMD
		eval $CMD
		
		#use the bacteria chr contig in reseq pipeline to replace original uncircular chr contig.
		mv ${PROCESSED_HGAP_DIR}/${BAC_CHR}\|arrow*.fa ${PROCESSED_HGAP_DIR}/000000Farrow.fa
		
		echo "${RESEQUENCE_FASTQ_DIR}/05.clean.fasta is circularized."
	else
		echo "${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta is not circularized."
	fi
	
else 
    echo "$ORIGINAL_FASTQ is circularized. "

fi


sed -i "s/>/>${SAMPLE_NAME}_/" ${PROCESSED_HGAP_DIR}/000000Farrow.fa #add sample name to fasta contig name

#elif [[ -s ${PROCESSED_HGAP_DIR}/0\|arrow.fa ]];then
#	mv ${PROCESSED_HGAP_DIR}/0\|arrow.fa ${PROCESSED_HGAP_DIR}/000000Farrow.fa
#	cp COVP_DIR/coverage_plot_0.png ${PROCESSED_HGAP_DIR}/../../Report
#fi

#match species specific nuxB gene fasta file for non-hpylori
#VIAL_NAME=$(echo ${SAMPLE_NAME} | cut -f1 -d_)
#for i in *.fa;do NAME=$(basename $i .fa);if [[ $VIAL_NAME == ${NAME}* ]]; then FIXSTART_SEQ=${i};fi;done

CMD="circlator fixstart --genes_fa ${FIXSTART_SEQ} ${PROCESSED_HGAP_DIR}/000000Farrow.fa ${PROCESSED_HGAP_DIR}/000000F.fixstart"
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

echo "###########################"
echo "Reformatting plasmid contig."
echo "###########################"

if [[ -d "${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid" ]]; then
	FOLLOWUP_CIRCULAR_PLASMID=$(grep 'Circularized: yes' ${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid/*/circlator/04.merge.circularise_details.log | wc -l)
fi

if [[ $FOLLOWUP_CIRCULAR_PLASMID -gt 0 ]];then
	echo "${FINAL_FASTA_NAME} has a circular plasmid through plasmid followup process."
	#choose the follow up directory that has most circularized contig
	#CIRCULAR_DIR=$(grep 'Circularized: yes' ${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid/*/circlator/04.merge.circularise_details.log | awk -F":" '{print $1}' | uniq -c | tail -1 | awk '{print $2}' | xargs dirname )
	CIRCULAR_DIR=$(grep -c 'Circularized: yes' ${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid/*/circlator/04.merge.circularise_details.log | sort -nr | head -1 | cut -f1 -d: | xargs dirname )
	CIR_NAMES=$(grep 'Circularized: yes' ${CIRCULAR_DIR}/04.merge.circularise_details.log  | awk -F "\t" '{print $2}'| cut -f1 -d\|)
	echo "${CIRCULAR_DIR} contains plasmid contigs. "
	#sed -i 's/000000F/followup1/' ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup1_plasmid.fasta
	CIRCULAR_DIR_PART2=$(echo $CIRCULAR_DIR | cut -f2-3 -d_)
	for i in ${CIR_NAMES};do
		
		awk -v name=$i 'BEGIN {print ">followup"name"|arrow"} $0~name {flag=1;next}/>/{flag=0}flag'  ${CIRCULAR_DIR}/05.clean.fasta > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid.fasta 
		##in case there are ciruclarized contig that are deleted because it is duplicated with previous contig
		HAS_SEQ=$(wc -l ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid.fasta  | cut -f1 -d' ')
		#echo $HAS_SEQ
		if [[ ${HAS_SEQ} -gt 1 ]]; then
		    echo "Plasmid from ${CIRCULAR_DIR}/05.clean.fasta contig ${i} is circularized and included. "
			cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid.fasta > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
			mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
			#some follow up plasmid dont have this coverage plot, e.x cacu circularized plasmid contig. will not be able to provide coverage plot
			cp ${CIRCULAR_DIR}/../html/images/pbreports.tasks.coverage_report_hgap/coverage_plot_${i}.png ${PROCESSED_HGAP_DIR}/../../Report/coverage_plot_followup${i}.png
		else
			rm ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid.fasta
		fi
	done

	UNCIR_NAMES=`grep 'Circularized: no-include' ${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid/*/circlator/04.merge.circularise_details.log | awk -F "\t" '{print $2}' | cut -f1 -d\|`

	for i in ${UNCIR_NAMES};do
		echo "use uncircular plasmid contig from followup pipeline."
		cp ${CIRCULAR_DIR}/../html/images/pbreports.tasks.coverage_report_hgap/coverage_plot_${i}.png ${PROCESSED_HGAP_DIR}/../../Report/coverage_plot_followup${i}.png
		awk -v name=$i 'BEGIN {print ">followup"name"|arrow"} $0~name {flag=1;next}/>/{flag=0}flag' ${CIRCULAR_DIR}/05.clean.fasta > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid_NC.fasta 
		cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_followup${i}_plasmid_NC.fasta > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
		mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
	done	
else
	for i in ${PROCESSED_HGAP_DIR}/*\|arrow.fa;do
		#echo $i
		NAME=$(basename $i .fa)
		IMAGE_NAME=$(echo $NAME | cut -f1 -d\|)
		#echo $NAME
		CIRCULAR_PLASMID=$(grep "$NAME" ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: yes' | wc -l)
		UNCIRCULAR_PLASMID=$(grep "$NAME" ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: no-include' | wc -l)
		#echo $CIRCULAR_PLASMID
		if [[ $CIRCULAR_PLASMID -gt 0 ]];then 
			echo "$i is circularized plasmid and included."
			cp $i ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid.fasta
			cp ${COVP_DIR}/coverage_plot_${IMAGE_NAME}.png ${PROCESSED_HGAP_DIR}/../../Report
			cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta $i > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
			mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
		elif [[ $UNCIRCULAR_PLASMID -gt 0 ]];then 
			echo "$i is uncircularized plasmid to include mannualy."
			cp $i ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid_NC.fasta
			cp ${COVP_DIR}/coverage_plot_${IMAGE_NAME}.png ${PROCESSED_HGAP_DIR}/../../Report
			cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta $i > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
			mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta

		fi 
	done
fi	
	
#get plasmid circular fasta
#will not be able to include the plasmid contig if circlator remove it for some reason, e.x contig contained in other contig. 
for i in $(grep 'Circularized: no-include' ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log  | awk '{print $3}' | sed 's/|arrow//g');do
	MANNUAL_INCLUDE=`ls ${PROCESSED_HGAP_DIR}/${i}*.fa`
	if [[ ! -f ${MANNUAL_INCLUDE} ]]; then
		echo "mannual included plasmid contig ${PROCESSED_HGAP_DIR}/${i}*.fa not present, did circlator delete it?"
		exit 1
	fi
done




samtools faidx ${PROCESSED_HGAP_DIR}/basecall_ref.fasta

CMD="${SMRTCMDS7}/fasta-to-reference ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${PROCESSED_HGAP_DIR} ${FINAL_FASTA_NAME}_basecall_ref"
echo $CMD
eval $CMD

mv $STEP3_WORKING_FLAG  $STEP3_DONE_FLAG

