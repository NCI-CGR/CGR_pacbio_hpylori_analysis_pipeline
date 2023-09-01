#!/bin/bash
. ./global_bash_config.rc

ORIGINAL_FASTQ=$1
shift
echo $1
if [[ $# == 1 ]]; then
    # no chr, plasmid only mode
    noChr=$1
fi	

ORIGINAL_FASTQ_DIR=$(dirname $ORIGINAL_FASTQ)
RESEQUENCE_FASTQ_DIR=${ORIGINAL_FASTQ_DIR}/../Resequence/circlator
PROCESSED_HGAP_DIR=${ORIGINAL_FASTQ_DIR}/../processed_hgap
FINAL_FASTA_NAME=$(dirname $ORIGINAL_FASTQ_DIR | xargs dirname | xargs basename | cut -f1 -d_)
SAMPLE_NAME=$(dirname $ORIGINAL_FASTQ_DIR | xargs dirname | xargs basename)
HGAP_ANALYSISID=$(echo $ORIGINAL_FASTQ_DIR | rev | cut -f3 -d/ | cut -f1 -d_ | rev)
FIXSTART_SEQ=nusBx_rev.fa

echo $HGAP_ANALYSISID
#pacbio job path is always changing, get the length of jobid and append correct number of 0s to the job id to locate the file path
NUM=$(echo -n $HGAP_ANALYSISID | wc -c)
DOT=""
for j in `seq 1 $NUM`;do DOT="${DOT}.";done
HGAP_ANALYSISID_PART2=$(echo $JOB_PATH_LEN | sed "s/$DOT$/$HGAP_ANALYSISID/")
echo $HGAP_ANALYSISID_PART2
HGAP_ANALYSISID_PART1=$(echo $HGAP_ANALYSISID_PART2 | cut -c1-7)
echo $HGAP_ANALYSISID_PART1
REAL_JOB_DIR=$(readlink ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/cromwell-job)


STEP3_WORKING_FLAG=${ORIGINAL_FASTQ_DIR}/../../logs/step3_format_hifiasm.working
STEP3_DONE_FLAG=${ORIGINAL_FASTQ_DIR}/../../logs/step3_format_hifiasm.done

touch $STEP3_WORKING_FLAG
#rm -r ${PROCESSED_HGAP_DIR}/ 
mkdir -p ${PROCESSED_HGAP_DIR}/../../Report/temp/ 2>/dev/null


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
	echo "$ORIGINAL_FASTQ is not circularized by circlator. Padding 100 N bases to the break point."
	
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


COV=$(grep ${BAC_CHR} ${ORIGINAL_FASTQ_DIR}/../hifiasm_out/${FINAL_FASTA_NAME}*.asm.p_ctg.gfa | head -1 | awk '{print $5}' | cut -f3 -d:)
echo -e "${BAC_CHR}\t${COV}" > ${PROCESSED_HGAP_DIR}/../../Report/temp/ccs_coverage.txt
#elif [[ -s ${PROCESSED_HGAP_DIR}/0\|arrow.fa ]];then
#	mv ${PROCESSED_HGAP_DIR}/0\|arrow.fa ${PROCESSED_HGAP_DIR}/000000Farrow.fa
#	cp COVP_DIR/coverage_plot_0.png ${PROCESSED_HGAP_DIR}/../../Report
#fi

#split contigs into separate file
CMD="python split_ref_fasta.py ${ORIGINAL_FASTQ} ${PROCESSED_HGAP_DIR}"
echo $CMD
eval $CMD
	
if [[ -z ${noChr} ]]; then 

	mv ${PROCESSED_HGAP_DIR}/${BAC_CHR}*.fa ${PROCESSED_HGAP_DIR}/000000Farrow.fa
	
	run_fixstart ${PROCESSED_HGAP_DIR}/000000Farrow.fa ${PROCESSED_HGAP_DIR} $CIRCULAR_CHROMOSOMAL
	repeat_check ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta ${PROCESSED_HGAP_DIR}/

	#compare 26695 to the chr contig
	dnadiff ${PROCESSED_HGAP_DIR}/../../HGAP_run/processed_hgap/000000F.fixstart.fasta ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta -p ${PROCESSED_HGAP_DIR}/raw_vs_hifi
	mummerplot --png -p ${PROCESSED_HGAP_DIR}/raw_vs_hifi_mummerplot ${PROCESSED_HGAP_DIR}/raw_vs_hifi.delta -R ${PROCESSED_HGAP_DIR}/../../HGAP_run/processed_hgap/000000F.fixstart.fasta -Q ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta

	#mv the last 12 letters to the head
	CMD="python3 ./fixformat.py ${PROCESSED_HGAP_DIR}/000000F.fixstart.fasta 60 > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta"
	echo $CMD
	eval $CMD
	sed -i "s/>/>${SAMPLE_NAME}_/" ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta #add sample name to fasta contig name
	sed -i "s/|/_/" ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta


	#samtools faidx ${PROCESSED_HGAP_DIR}/000000F.final.fasta
	#CMD="/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/fasta-to-reference ${PROCESSED_HGAP_DIR}/000000F.final.fasta ${PROCESSED_HGAP_DIR} ${FINAL_FASTA_NAME}_chromosomal"
	#echo $CMD
	#eval $CMD

	cp ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta ${PROCESSED_HGAP_DIR}/basecall_ref.fasta

    echo "#####################Starting annotation for sample ${SAMPLE_NAME}#####################"
	
	run_prokka ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta ${SAMPLE_NAME} ${ROOT_DIR}/${SAMPLE_NAME}/deepconsensus/prokka_protein
    echo -e "${gene}\t${cds}\t${rRNA}\t${tRNA}\t${psuedoFrac}\t${vacA}" > ${ROOT_DIR}/${SAMPLE_NAME}/Report/temp/hifi_assemble_annotation.txt
	
	run_busco ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta
	grep 'C:' ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal/short_summary.specific.campylobacterales_odb10.${FINAL_FASTA_NAME}_chromosomal.txt >> ${ROOT_DIR}/${SAMPLE_NAME}/Report/temp/hifi_assemble_annotation.txt

	
	if [[ $CIRCULAR_CHROMOSOMAL -eq 0 ]];then 
		mv ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal.fasta ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_chromosomal_NC.fasta
	fi
else
	echo "No Chromosomal Contig!"
fi




echo "###########################"
echo "Reformatting plasmid contig."
echo "###########################"


#Check if Reseq pipeline has more plasmid circularized than normal pipeline. If yes, use plasmid fastq from reseq pipeline. 
if [[ -d "${RESEQUENCE_FASTQ_DIR}" ]]; then
	RESEQ_CIRCULAR_PLASMID=$(grep 'Circularized: yes' ${RESEQUENCE_FASTQ_DIR}/04.merge.circularise_details.log | wc -l)
else
	RESEQ_CIRCULAR_PLASMID=0
fi

ORIGINAL_CIRCULAR_PLASMID=$(cat ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: yes' | wc -l)
DIFF_RESEQ_ORIGINAL=$(echo "${RESEQ_CIRCULAR_PLASMID}-${ORIGINAL_CIRCULAR_PLASMID}" | bc )


if [[ ${DIFF_RESEQ_ORIGINAL} -gt 1 ]];then
	echo "${FINAL_FASTA_NAME} has a circular plasmid through reseq pipeline process."
	COVP_DIR=${RESEQUENCE_FASTQ_DIR}/../resequence_run/html/images/pbreports.tasks.coverage_report
	for i in ${RESEQUENCE_FASTQ_DIR}/*\|arrow.fa;do
		#echo $i
		NAME=$(basename $i .fa)
		IMAGE_NAME=$(echo $NAME | cut -f1 -d\|)
		#echo $NAME
	
		CIRCULAR_PLASMID=$(grep "$IMAGE_NAME" ${RESEQUENCE_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: yes' | wc -l)
		UNCIRCULAR_PLASMID=$(grep "$NAME" ${RESEQUENCE_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: no-include' | wc -l)
		
		if [[ $CIRCULAR_PLASMID -gt 0 ]];then 
			echo "$i from reseq pipeline is circularized plasmid and included."
			sed "s/>/>${SAMPLE_NAME}_/" $i > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid.fasta
			COV=$(grep ${NAME} ${ORIGINAL_FASTQ_DIR}/../hifiasm_out/${FINAL_FASTA_NAME}*.asm.p_ctg.gfa | head -1 | awk '{print $5}' | cut -f3 -d:)
            echo -e "${NAME}\t${COV}" >> ${PROCESSED_HGAP_DIR}/../../Report/temp/ccs_coverage.txt
		elif [[ $UNCIRCULAR_PLASMID -gt 0 ]];then 
			echo "$i is uncircularized plasmid to include mannualy."
			sed "s/>/>${SAMPLE_NAME}_/" $i > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${IMAGE_NAME}_plasmid_NC.fasta
			COV=$(grep ${NAME} ${ORIGINAL_FASTQ_DIR}/../hifiasm_out/${FINAL_FASTA_NAME}*.asm.p_ctg.gfa | head -1 | awk '{print $5}' | cut -f3 -d:)
            echo -e "${NAME}\t${COV}" >> ${PROCESSED_HGAP_DIR}/../../Report/temp/ccs_coverage.txt

		fi 
		
	done	
elif [[ $(ls ${PROCESSED_HGAP_DIR}/ptg*.fa | wc -l) -gt 0 ]];then
	
	for i in ${PROCESSED_HGAP_DIR}/ptg*.fa;do
		echo "${FINAL_FASTA_NAME} has a small contig $i for plasmid checking. "
		NAME=$(basename $i .fa)
		IMAGE_NAME=$(echo $NAME | cut -f1 -d\|)

		CIRCULAR_PLASMID=$(grep "$NAME" ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: yes' | wc -l)
		UNCIRCULAR_PLASMID=$(grep "$NAME" ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log | grep 'Circularized: no-include' | wc -l)
		
		echo -e $NAME "\tcircluarized?\t" $CIRCULAR_PLASMID
		echo $CIRCULAR_PLASMID
		if [[ $CIRCULAR_PLASMID -gt 0 ]];then 
			echo "$i is circularized plasmid and included."
			sed "s/>/>${SAMPLE_NAME}_/" $i > ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${NAME}_plasmid.fasta
			COV=$(grep ${NAME} ${ORIGINAL_FASTQ_DIR}/../hifiasm_out/${FINAL_FASTA_NAME}*.asm.p_ctg.gfa | head -1 | awk '{print $5}' | cut -f3 -d:)
            echo -e "${NAME}\t${COV}" >> ${PROCESSED_HGAP_DIR}/../../Report/temp/ccs_coverage.txt
			repeat_check ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${NAME}_plasmid.fasta
			cat $i >> ${PROCESSED_HGAP_DIR}/basecall_ref.fasta

		elif [[ $UNCIRCULAR_PLASMID -gt 0 ]];then 
			echo "$i is uncircularized plasmid to include mannualy."
			sed "s/>/>${SAMPLE_NAME}_/" $i >  ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${NAME}_plasmid_NC.fasta
			COV=$(grep ${NAME} ${ORIGINAL_FASTQ_DIR}/../hifiasm_out/${FINAL_FASTA_NAME}*.asm.p_ctg.gfa | head -1 | awk '{print $5}' | cut -f3 -d:)
            echo -e "${NAME}\t${COV}" >> ${PROCESSED_HGAP_DIR}/../../Report/temp/ccs_coverage.txt
			repeat_check ${PROCESSED_HGAP_DIR}/${FINAL_FASTA_NAME}_${NAME}_plasmid_NC.fasta
			cat $i >> ${PROCESSED_HGAP_DIR}/basecall_ref.fasta
			
		fi
		
		run_blastn $i ${PROCESSED_HGAP_DIR}/${NAME}_blast.out 	
		blastn -query $i -db /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/Manifest/DoriC_db -out ${PROCESSED_HGAP_DIR}/${IMAGE_NAME}_blastDoriC.txt -max_hsps 5 -outfmt 7
	done
else
	echo "${FINAL_FASTA_NAME} has no small contig for plasmid checking." 
	
fi
	
${SMRTCMDS10}/pbmm2 align ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${ORIGINAL_FASTQ_DIR}/../${SAMPLE_NAME}_deepconsensus.fastq --preset HIFI | samtools sort > ${PROCESSED_HGAP_DIR}/basecall_ref_deepconsensus.bam
samtools index ${PROCESSED_HGAP_DIR}/basecall_ref_deepconsensus.bam
for i in $(grep '>' ${PROCESSED_HGAP_DIR}/basecall_ref.fasta | sed 's/>//g' );do
	samtools depth -r "${i}" ${PROCESSED_HGAP_DIR}/basecall_ref_deepconsensus.bam > ${PROCESSED_HGAP_DIR}/${i}.depth 
	Rscript ./coverage_plot.R ${PROCESSED_HGAP_DIR}/${i}.depth 
	cp -l ${PROCESSED_HGAP_DIR}/coverage_plot_${i}.png ${PROCESSED_HGAP_DIR}/../../Report/temp
done
	
#get plasmid circular fasta
#will not be able to include the plasmid contig if circlator remove it for some reason, e.x contig contained in other contig. 
for i in $(grep 'Circularized: no-include' ${ORIGINAL_FASTQ_DIR}/04.merge.circularise_details.log  | awk '{print $3}' | sed 's/|arrow//g');do
	MANNUAL_INCLUDE=`ls ${PROCESSED_HGAP_DIR}/${i}*.fa`
	if [[ ! -f ${MANNUAL_INCLUDE} ]]; then
		echo "mannual included plasmid contig ${PROCESSED_HGAP_DIR}/${i}*.fa not present, did circlator delete it?"
		exit 1
	fi
done

gene=$(cat ${ROOT_DIR}/${SAMPLE_NAME}/Report/temp/hifi_assemble_annotation.txt | awk '{print $1}')
vacA=$(grep 'product=Vacuolating cytotoxin VacA' ${ROOT_DIR}/${SAMPLE_NAME}/hifiasm_run/prokka_protein/${SAMPLE_NAME}.gff | wc -l )
if  [[ ${vacA} > 1 ]] && [[ ${gene} < 1800 ]] && [[ ${gene} > 1400 ]]; then
	echo "Hifi assembly of ${SAMPLE_NAME} has truncated VacA gene!"
	#run_resequence ${PROCESSED_HGAP_DIR} ${PROCESSED_HGAP_DIR}/basecall_ref.fasta ${HGAP_ANALYSISID}
	run_prokka ${PROCESSED_HGAP_DIR}/../Resequence/outputs/consensus.fasta ${SAMPLE_NAME} ${PROCESSED_HGAP_DIR}/../Resequence/prokka_protein/
	oldPsuedoFrac=$(head -1 ${PROCESSED_HGAP_DIR}/../../Report/temp/hifi_assemble_annotation.txt | cut -f5)
	echo -e "${gene}\t${cds}\t${rRNA}\t${tRNA}\t${psuedoFrac}\t${vacA}" >> ${PROCESSED_HGAP_DIR}/../../Report/temp/hifi_assemble_annotation.txt
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
mv $STEP3_WORKING_FLAG  $STEP3_DONE_FLAG

