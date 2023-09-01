#!/bin/bash
. ./global_bash_config.rc

MANIFEST=$1


for i in  $(awk -F "\t" '{if(NR>1){print $1"_"$2"_"$3}}' $MANIFEST);do
	VIAL_ID=$(echo $i | cut -f1 -d_)
	#HGAP_ANALYSISID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $3}}' $MANIFEST)
	#CGR_ID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $2}}' $MANIFEST)
	HGAP_ANALYSISID=$(echo $i | cut -f3 -d_)
	CGR_ID=$(echo $i | cut -f2 -d_)
	LOG_DIR=${ROOT_DIR}/${i}/logs
	STEP3_WORKING_FLAG=${LOG_DIR}/step3_format_hgap.working
	STEP3_DONE_FLAG=${LOG_DIR}/step3_format_hgap.done
	#rm -f $LOG_DIR/step3_format_hgap_*.std* 2>/dev/null	
	#mkdir $LOG_DIR 2>/dev/null

	
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

	#OUT_HGAP=${ROOT_DIR}/HGAP_file${BARCODING_JOB}_${i}_${i}
	
	#HAS_CIRLULARIZED=$(grep 'Circularized: yes' ${ROOT_DIR}/${i}/HGAP_run/circlator_${HGAP_ANALYSISID}/04.merge.circularise_details.log | wc -l);
	
	if [[ -f ${STEP3_WORKING_FLAG} ]] || [[ -f ${STEP3_DONE_FLAG} ]];then
		echo "${i} format hgap assembly job is still running or already done, skip..."
	else
		rm -f $LOG_DIR/step3_format_hgap_*.std* 2>/dev/null
 
		CMD="qsub -cwd -q $QUEUE -N Step3_format_hgap_${HGAP_ANALYSISID} -e ${LOG_DIR}/step3_format_hgap_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step3_format_hgap_${HGAP_ANALYSISID}.stdout -S /bin/sh step3_format_hgap_result_V2.sh ${ROOT_DIR}/${i}/HGAP_run/circlator_${HGAP_ANALYSISID}/05.clean.fasta"
		#CMD="sbatch -e ${LOG_DIR}/step3_format_hgap_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step3_format_hgap_${HGAP_ANALYSISID}.stdout step3_format_hgap_result_V2.sh ${ROOT_DIR}/${i}/HGAP_run/circlator_${HGAP_ANALYSISID}/05.clean.fasta"
		echo $CMD >>  NOHUPS/nohup_step3_$(date +\%Y\%m\%d).txt
		echo $CMD
		eval $CMD

	fi
	
	if [[ -f ${LOG_DIR}/step3_format_hifiasm.working ]] || [[ -f ${LOG_DIR}/step3_format_hifiasm.done ]];then
		echo "${i} format hifiasm assembly job is still running or already done, skip..."
	else			
		rm -f $LOG_DIR/step3_format_hifiasm_*.std* 2>/dev/null
		CMD="qsub -cwd -q $QUEUE -N Step3_format_hifiasm_${HGAP_ANALYSISID} -e ${LOG_DIR}/step3_format_hifiasm_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step3_format_hifiasm_${HGAP_ANALYSISID}.stdout -S /bin/sh step3_format_hgap_result_hifiasm.sh ${ROOT_DIR}/${i}/deepconsensus/circlator/05.clean.fasta"
		#CMD="sbatch -e ${LOG_DIR}/step3_format_hifiasm_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step3_format_hifiasm_${HGAP_ANALYSISID}.stdout step3_format_hgap_result_hifiasm.sh ${ROOT_DIR}/${i}/deepconsensus/circlator/05.clean.fasta"
		echo $CMD >>  NOHUPS/nohup_step3_$(date +\%Y\%m\%d).txt
		echo $CMD
		eval $CMD
		
	
	#else
	#	echo "Circlator doesn't successfully circularize the HGAP analysis${HGAP_ANALYSISID} result! Please mannual examine. "
	fi

done


