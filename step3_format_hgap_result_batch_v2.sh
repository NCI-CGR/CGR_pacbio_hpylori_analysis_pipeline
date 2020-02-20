#!/bin/bash
. ./global_bash_config.rc

MANIFEST=$1


for i in  $(awk -F "\t" '{if(NR>1){print $1"_"$2"_"$3}}' $MANIFEST);do
	VIAL_ID=$(echo $i | cut -f1 -d_)
	HGAP_ANALYSISID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $3}}' $MANIFEST)
	CGR_ID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $2}}' $MANIFEST)
	LOG_DIR=${ROOT_DIR}/${i}/logs
	STEP3_WORKING_FLAG=${LOG_DIR}/step3_format_hgap.working
	STEP3_DONE_FLAG=${LOG_DIR}/step3_format_hgap.done
	rm -f $LOG_DIR/step3_format_hgap_*.std* 2>/dev/null	
	#mkdir $LOG_DIR 2>/dev/null
	mkdir -p ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Report/temp 2>/dev/null
	
	#OUT_HGAP=${ROOT_DIR}/HGAP_file${BARCODING_JOB}_${i}_${i}
	
	#HAS_CIRLULARIZED=$(grep 'Circularized: yes' ${ROOT_DIR}/${i}/HGAP_run/circlator_${HGAP_ANALYSISID}/04.merge.circularise_details.log | wc -l);
	
	if [[ -f ${STEP3_WORKING_FLAG} || -f ${STEP3_DONE_FLAG} ]];then
		echo "${i} format hgap assembly job is still running or already done, skip..."
	else
		CMD="qsub -cwd -q $QUEUE -N Step3_format_hgap_${HGAP_ANALYSISID} -e ${LOG_DIR}/step3_format_hgap_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step3_format_hgap_${HGAP_ANALYSISID}.stdout -S /bin/sh step3_format_hgap_result_V2.sh ${ROOT_DIR}/${i}/HGAP_run/circlator_${HGAP_ANALYSISID}/05.clean.fasta"
		echo $CMD >>  NOHUPS/nohup_step3_$(date +\%Y\%m\%d).txt
        echo $CMD
        eval $CMD
	#else
	#	echo "Circlator doesn't successfully circularize the HGAP analysis${HGAP_ANALYSISID} result! Please mannual examine. "
	fi

done


