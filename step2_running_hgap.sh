#!/bin/bash
. ./global_bash_config.rc

MANIFEST=$1


for i in  $(awk -F "\t" '{if(NR>1){print $1"_"$2"_"$3}}' $MANIFEST );do
	VIAL_ID=$(echo $i | cut -f1 -d_)
	#HGAP_ANALYSISID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $3}}' $MANIFEST)
	HGAP_ANALYSISID=$(echo $i | cut -f3 -d_)
	LOG_DIR=${ROOT_DIR}/${i}/logs
	OUT_HGAP=${ROOT_DIR}/${i}/HGAP_run/processed_hgap
	OUT_HIFI=${ROOT_DIR}/${i}/deepconsensus/processed_hgap
	REPORT_DIR=${ROOT_DIR}/${i}/Report/temp
	STEP2_WORKING_FLAG=${LOG_DIR}/step2_circlator.working
	STEP2_DONE_FLAG=${LOG_DIR}/step2_circlator.done
	
	mkdir -p $OUT_HGAP 2>/dev/null
	mkdir -p $OUT_HIFI 2>/dev/null
	mkdir -p $LOG_DIR 2>/dev/null
	mkdir -p $REPORT_DIR 2>/dev/null
	mkdir -p ${ROOT_DIR}/${i}/HGAP_run/NUCMER 2>/dev/null
	rm ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}.std* 2>/dev/null
	
	
	if [[ -f ${STEP2_WORKING_FLAG} || -f ${STEP2_DONE_FLAG} ]];then
		echo "${i} Circlator job is still running or already done, skip..."
	
	else	
		touch ${STEP2_WORKING_FLAG}
		CMD="qsub -cwd -q $QUEUE -pe by_node 2 -N step2_circlator_${HGAP_ANALYSISID} -e ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}.stdout -S /bin/sh step2_running_hgap_single.sh $i $HGAP_ANALYSISID"
		echo $CMD >> NOHUPS/nohup_step2_$(date +\%Y\%m\%d).txt
		echo $CMD
		eval $CMD
		
	fi
done


