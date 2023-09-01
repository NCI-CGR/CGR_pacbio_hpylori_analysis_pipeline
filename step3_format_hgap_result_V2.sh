#!/bin/bash
. ./global_bash_config.rc


ORIGINAL_FASTQ=$1
shift
if [[ $# == 1 ]]; then
    # no chr, plasmid only mode
    noChr=$1
fi	

ORIGINAL_FASTQ_DIR=$(dirname $ORIGINAL_FASTQ)
RESEQUENCE_FASTQ_DIR=${ORIGINAL_FASTQ_DIR}/../Resequence/circlator
PROCESSED_HGAP_DIR=${ORIGINAL_FASTQ_DIR}/../processed_hgap
FINAL_FASTA_NAME=$(dirname $ORIGINAL_FASTQ_DIR | xargs dirname | xargs basename | cut -f1 -d_)
SAMPLE_NAME=$(dirname $ORIGINAL_FASTQ_DIR | xargs dirname | xargs basename)
HGAP_ANALYSISID=$(echo $ORIGINAL_FASTQ_DIR | rev | cut -f1 -d_ | rev)

#pacbio job path is always changing, get the length of jobid and append correct number of 0s to the job id to locate the file path
NUM=$(echo -n $HGAP_ANALYSISID | wc -c)
DOT=""
for j in `seq 1 $NUM`;do DOT="${DOT}.";done
HGAP_ANALYSISID_PART2=$(echo $JOB_PATH_LEN | sed "s/$DOT$/$HGAP_ANALYSISID/")
echo $HGAP_ANALYSISID_PART2
HGAP_ANALYSISID_PART1=$(echo $HGAP_ANALYSISID_PART2 | cut -c1-7)
echo $HGAP_ANALYSISID_PART1
REAL_JOB_DIR=$(readlink ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/cromwell-job)
#get the coverage plot directory
ANALYSIS_TYPE=$(dirname ${REAL_JOB_DIR} | xargs basename)
if [[ $ANALYSIS_TYPE == pb_assembly_microbial ]]; then
	COVP_DIR=$(find ${REAL_JOB_DIR} -name "coverage_plot_*.png" | tail -1 | xargs dirname)
elif [[ $ANALYSIS_TYPE == pb_hgap4 ]]; then
	COVP_DIR=${REAL_JOB_DIR}/call-coverage_report/execution/
elif [[ $ANALYSIS_TYPE == pb_microbial_analysis ]]; then
	COVP_DIR=$(find ${REAL_JOB_DIR} -name "coverage_plot_*.png" | tail -1 | xargs dirname)
fi

STEP3_WORKING_FLAG=${ORIGINAL_FASTQ_DIR}/../../logs/step3_format_hgap.working
STEP3_DONE_FLAG=${ORIGINAL_FASTQ_DIR}/../../logs/step3_format_hgap.done

touch $STEP3_WORKING_FLAG

echo "###########################"
echo "Reformatting chromosomal contig."
echo "###########################"

#assume the largest contig is the bacteria contig
#for cases bacteria contig not in 1 piece, mannual lable the smaller piece as chr instead of plasmid
#sed 's/\(.*\)|arrow/\1/ remove last occurence of |arrow in case of 2 or more contig merged by circlator
BAC_CHR=$(cat $ORIGINAL_FASTQ | awk '/^>/ {if(N>0) printf("\n"); printf("%s\t",$0);N++;next;} {printf("%s",$0);} END {if(N>0) printf("\n");}' |awk -F "\t" '{printf("%s\t%d\n",$1,length($2));}' |sort -n -k2 | tail -1 | cut -f1 |  sed s'/>//'| sed 's/\(.*\)|arrow/\1/' )


#check if chromosomal contig is circularized, otherwise, use the chromosomal contig from reseq pipeline. 
CIRCULAR_CHROMOSOMAL=$(grep "${BAC_CHR}" ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: yes' | wc -l)
if [[ $CIRCULAR_CHROMOSOMAL -eq 0 ]];then 

	RESEQ_BAC_CHR=$(awk '/^>/ {if(N>0) printf("\n"); printf("%s\t",$0);N++;next;} {printf("%s",$0);} END {if(N>0) printf("\n");}' ${RESEQUENCE_FASTQ_DIR}/05.clean.fasta|awk -F "\t" '{printf("%s\t%d\n",$1,length($2));}' |sort -n -k2 | tail -1 | cut -f1 |  sed s'/>//'| sed 's/\(.*\)|arrow/\1/')
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
		mv ${RESEQUENCE_FASTQ_DIR}/${BAC_CHR}\|arrow*.fa ${PROCESSED_HGAP_DIR}/000000Farrow.fa
		
		echo "${RESEQUENCE_FASTQ_DIR}/05.clean.fasta is circularized."
	else
		echo "${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta is not circularized."
		
	fi
	
else 
    echo "$ORIGINAL_FASTQ is circularized. "

fi


cp -l ${COVP_DIR}/coverage_plot_*.png ${PROCESSED_HGAP_DIR}/
mv ${PROCESSED_HGAP_DIR}/coverage_plot_${BAC_CHR}.png ${PROCESSED_HGAP_DIR}/../../Report/temp

#split contigs into separate file
CMD="python split_ref_fasta.py ${ORIGINAL_FASTQ} ${PROCESSED_HGAP_DIR}"
echo $CMD
eval $CMD
	
if [[ -z ${noChr} ]]; then 

	mv ${PROCESSED_HGAP_DIR}/${BAC_CHR}*.fa ${PROCESSED_HGAP_DIR}/000000Farrow.fa
	
	echo $CIRCULAR_CHROMOSOMAL
	run_fixstart ${PROCESSED_HGAP_DIR}/000000Farrow.fa ${PROCESSED_HGAP_DIR} $CIRCULAR_CHROMOSOMAL
	repeat_check ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta ${PROCESSED_HGAP_DIR}/

	#compare 26695 to the chr contig
	dnadiff NCBI_26695/h-pylori-26695-NC_000915-1_fix.fasta ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta -p ${PROCESSED_HGAP_DIR}/26695_vs_${SAMPLE_NAME}
	mummerplot --png -p ${PROCESSED_HGAP_DIR}/26695_vs_${SAMPLE_NAME}_mummerplot ${PROCESSED_HGAP_DIR}/26695_vs_${SAMPLE_NAME}.delta -R NCBI_26695/h-pylori-26695-NC_000915-1_fix.fasta -Q ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta

	#mv the last 12 letters to the head
	CMD="python3 ./fixformat.py ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta 60 > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta"
	echo $CMD
	eval $CMD
	sed -i "s/>/>${SAMPLE_NAME}_/" ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta #add sample name to fasta contig name

	#samtools faidx ${PROCESSED_HGAP_DIR}/000000F.final.fasta
	#CMD="/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/fasta-to-reference ${PROCESSED_HGAP_DIR}/000000F.final.fasta ${PROCESSED_HGAP_DIR} ${FINAL_FASTA_NAME}_chromosomal"
	#echo $CMD
	#eval $CMD
	echo "#####################Starting annotation for sample ${SAMPLE_NAME}#####################"
		
	run_prokka ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta ${SAMPLE_NAME} ${ROOT_DIR}/${SAMPLE_NAME}/HGAP_run/prokka_protein
	echo -e "${gene}\t${cds}\t${rRNA}\t${tRNA}\t${psuedoFrac}\t${vacA}" > ${ROOT_DIR}/${SAMPLE_NAME}/Report/temp/raw_assemble_annotation.txt
		
	run_busco ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta
	grep 'C:' ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal/short_summary.specific.campylobacterales_odb10.${FINAL_FASTA_NAME}_chromosomal.txt >> ${ROOT_DIR}/${SAMPLE_NAME}/Report/temp/raw_assemble_annotation.txt
	
	cp ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta

	if [[ $CIRCULAR_CHROMOSOMAL -eq 0 ]] ;then 
		mv ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal_NC.fasta
	fi

fi


echo "###########################"
echo "Reformatting plasmid contig."
echo "###########################"

#Check which pipeline has circular plasmid contig
if [[ -d "${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid" ]]; then
	FOLLOWUP_CIRCULAR_PLASMID=$(grep 'Circularized: yes' ${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid/*/circlator/04.merge.circularise_details.log | wc -l)
fi

#Check if Reseq pipeline has more plasmid circularized than normal pipeline. If yes, use plasmid fastq from reseq pipeline. 
if [[ -d "${RESEQUENCE_FASTQ_DIR}" ]]; then
	RESEQ_CIRCULAR_PLASMID=$(grep 'Circularized: yes' ${RESEQUENCE_FASTQ_DIR}/04.merge.circularise_details.log | wc -l)
else
	RESEQ_CIRCULAR_PLASMID=0
fi

ORIGINAL_CIRCULAR_PLASMID=$(cat ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: yes' | wc -l)
DIFF_RESEQ_ORIGINAL=$(echo "${RESEQ_CIRCULAR_PLASMID}-${ORIGINAL_CIRCULAR_PLASMID}" | bc )

if [[ $FOLLOWUP_CIRCULAR_PLASMID -gt 0 ]];then
	echo "${FINAL_FASTA_NAME} has a circular plasmid through plasmid followup process."
	#choose the follow up directory that has most circularized contig
	#CIRCULAR_DIR=$(grep 'Circularized: yes' ${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid/*/circlator/04.merge.circularise_details.log | awk -F":" '{print $1}' | uniq -c | tail -1 | awk '{print $2}' | xargs dirname )
	#grep -Hc print both file name and number of pattern occurence
	CIRCULAR_DIR=$(grep -Hc 'Circularized: yes' ${ROOT_DIR}/plasmid_test/${SAMPLE_NAME}_plasmid/*/circlator/04.merge.circularise_details.log | sort -nr -t ':' -k2 | head -1 | cut -f1 -d: | xargs dirname )
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
	
	UNCIR_NAMES=`grep 'Circularized: no-include' ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | awk -F "\t" '{print $2}' | cut -f1 -d\|`

	for i in ${UNCIR_NAMES};do
		echo "use uncircular plasmid contig from regular pipeline."
		cp ${PROCESSED_HGAP_DIR}/${i}\|arrow.fa ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${i}_plasmid_NC.fasta
		cp ${PROCESSED_HGAP_DIR}/coverage_plot_${i}.png ${PROCESSED_HGAP_DIR}/../../Report/temp
		cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${i}_plasmid_NC.fasta > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
		mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
	done	

elif [[ ${DIFF_RESEQ_ORIGINAL} -gt 1 ]];then
	echo "${FINAL_FASTA_NAME} has a circular plasmid through reseq pipeline process."
	COVP_DIR=${RESEQUENCE_FASTQ_DIR}/../resequence_run/html/images/pbreports.tasks.coverage_report
	for i in ${RESEQUENCE_FASTQ_DIR}/ctg*.fa;do
		#echo $i
		NAME=$(basename $i .fa)
		IMAGE_NAME=$(echo $NAME | cut -f1 -d\|)
		#echo $NAME
	
		CIRCULAR_PLASMID=$(grep "$IMAGE_NAME" ${RESEQUENCE_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: yes' | wc -l)
		UNCIRCULAR_PLASMID=$(grep "$NAME" ${RESEQUENCE_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: no-include' | wc -l)
		
		if [[ $CIRCULAR_PLASMID -gt 0 ]];then 
			echo "$i from reseq pipeline is circularized plasmid and included."
			sed "s/>/>${SAMPLE_NAME}_/" $i > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid.fasta
			cp ${COVP_DIR}/coverage_plot_${IMAGE_NAME}_arrow.png ${PROCESSED_HGAP_DIR}/../../Report/temp
			cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta $i > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
			mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
		elif [[ $UNCIRCULAR_PLASMID -gt 0 ]];then 
			echo "$i is uncircularized plasmid to include manualy."
			sed "s/>/>${SAMPLE_NAME}_/" $i >  ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid_NC.fasta
			cp ${COVP_DIR}/coverage_plot_${IMAGE_NAME}_arrow.png ${PROCESSED_HGAP_DIR}/../../Report/temp
			cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta $i > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
			mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta

		fi 
		
	done	
elif [[ $(ls ${PROCESSED_HGAP_DIR}/ctg*.fa | wc -l) -gt 0 ]];then
	#echo "${FINAL_FASTA_NAME} has a circular plasmid through regular process."
	for i in ${PROCESSED_HGAP_DIR}/ctg*.fa;do
		echo "${FINAL_FASTA_NAME} has a small contig $i for plasmid checking." 
		NAME=$(basename $i .fa)
		IMAGE_NAME=$(echo $NAME | cut -f1 -d\|)
		
		CIRCULAR_PLASMID=$(grep "$NAME" ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: yes' | wc -l)
		UNCIRCULAR_PLASMID=$(grep "$NAME" ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: no-include' | wc -l)
		echo -e $NAME "\tcircluarized?\t" $CIRCULAR_PLASMID
		
		if [[ $CIRCULAR_PLASMID -gt 0 ]];then 
			echo "$i is circularized plasmid and included."
			sed "s/>/>${SAMPLE_NAME}_/" $i >  ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid.fasta
			cp ${COVP_DIR}/coverage_plot_${IMAGE_NAME}.png ${PROCESSED_HGAP_DIR}/../../Report/temp
			cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta $i > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
			mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
			repeat_check ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid.fasta
		elif [[ $UNCIRCULAR_PLASMID -gt 0 ]];then 
			echo "$i is uncircularized plasmid to include mannualy."
			sed "s/>/>${SAMPLE_NAME}_/" $i >  ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid_NC.fasta
			cp ${COVP_DIR}/coverage_plot_${IMAGE_NAME}.png ${PROCESSED_HGAP_DIR}/../../Report/temp
			cat ${PROCESSED_HGAP_DIR}/basecall_ref.fasta $i > ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta
			mv ${PROCESSED_HGAP_DIR}/basecall_ref.tmp.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
			repeat_check ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid_NC.fasta
		fi 
		run_blastn $i ${PROCESSED_HGAP_DIR}/${IMAGE_NAME}_blast.out 
		blastn -query $i -db /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/Manifest/DoriC_db -out ${PROCESSED_HGAP_DIR}/${IMAGE_NAME}_blastDoriC.txt -max_hsps 5 -outfmt 7
	done
else
	echo "${FINAL_FASTA_NAME} has no small contig for plasmid checking." 
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


psuedoFrac=$(cat ${ROOT_DIR}/${SAMPLE_NAME}/Report/temp/raw_assemble_annotation.txt | awk '{print $5}')
vacA=$(grep 'product=Vacuolating cytotoxin VacA' ${ROOT_DIR}/${SAMPLE_NAME}/HGAP_run/prokka_protein/${SAMPLE_NAME}.gff | wc -l )
if [[ ${psuedoFrac} > 0.05 ]] || [[ ${gene} > 1650 ]] || [[ ${vacA} > 1 ]]; then
	echo "Raw assembly of ${SAMPLE_NAME} has psuedogene fraction higher than 0.05 or total gene more than 1650! Polishing for one more round!"
	#run_resequence ${PROCESSED_HGAP_DIR} ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${HGAP_ANALYSISID}
	run_prokka ${PROCESSED_HGAP_DIR}/../Resequence/outputs/consensus.fasta ${SAMPLE_NAME} ${PROCESSED_HGAP_DIR}/../Resequence/prokka_protein/
	oldPsuedoFrac=$(head -1 ${PROCESSED_HGAP_DIR}/../../Report/temp/raw_assemble_annotation.txt | cut -f5)
	echo -e "${gene}\t${cds}\t${rRNA}\t${tRNA}\t${psuedoFrac}\t${vacA}" >> ${PROCESSED_HGAP_DIR}/../../Report/temp/raw_assemble_annotation.txt
	if [[ ${psuedoFrac} < ${oldPsuedoFrac} ]] || [[ ${vacA} < 2 ]];then
		
		CMD="python split_ref_fasta.py ${PROCESSED_HGAP_DIR}/../Resequence/outputs/consensus.fasta $PROCESSED_HGAP_DIR"
		echo $CMD
		eval $CMD
		mv ${PROCESSED_HGAP_DIR}/${BAC_CHR}\|arrow*.fa ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta 
		if [[ $CIRCULAR_CHROMOSOMAL -eq 0 ]] && [[ $RESEQ_CIRCULAR_CHROMOSOMAL -eq 0 ]];then 
			mv ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal_NC.fasta
		fi
	fi
fi

# CMD="${SMRTCMDS7}/fasta-to-reference ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${PROCESSED_HGAP_DIR} ${FINAL_FASTA_NAME}_basecall_ref"
# echo $CMD
# eval $CMD

mv $STEP3_WORKING_FLAG  $STEP3_DONE_FLAG

