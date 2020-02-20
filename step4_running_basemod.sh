#!/bin/bash
. ./global_bash_config.rc

MANIFEST=$1


for i in  $(awk -F "\t" '{if(NR>1){print $1"_"$2"_"$3}}' $MANIFEST);do
	VIAL_ID=$(echo $i | cut -f1 -d_)
	CGR_ID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $2}}' $MANIFEST)
	HGAP_ANALYSISID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $3}}' $MANIFEST)
	# HGAP_ANALYSISID_PART1_PRE=$(echo $HGAP_ANALYSISID | rev | cut -c4- | rev )
	# HGAP_ANALYSISID_PART1=$(printf "%03d\n" $HGAP_ANALYSISID_PART1_PRE)
	# HGAP_ANALYSISID_PART2=$(echo $HGAP_ANALYSISID | rev | cut -c1-3 | rev)

	LOG_DIR=${ROOT_DIR}/${i}/logs
	OUT_BASEMOD=${ROOT_DIR}/${i}/BASEMOD_run
	STEP4_WORKING_FLAG=${LOG_DIR}/step4_basemod_call.working
	STEP4_DONE_FLAG=${LOG_DIR}/step4_basemod_call.done
	
	#HAS_RUN=$(grep '40/40 completed/total tasks' ${LOG_DIR}/step4_basemod_call_${HGAP_ANALYSISID}.stdout | wc -l)
	RUNNING_JOBS=$(qstat | grep Step4_base | wc -l )

	if [[ -f ${STEP4_DONE_FLAG} ]];then
		echo "${i} Base modification job is still running or already done, skip..."
	
	elif [[ $RUNNING_JOBS -gt 6 ]];then
		sleep 1h
		rm $OUT_BASEMOD 2>/dev/null	
		mkdir $OUT_BASEMOD 2>/dev/null
		
		rm ${LOG_DIR}/step4_basemod_call_${HGAP_ANALYSISID}.std* 2>/dev/null
	
		CMD="qsub -cwd -q $QUEUE -N Step4_basemod_call_${HGAP_ANALYSISID} -e ${LOG_DIR}/step4_basemod_call_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step4_basemod_call_${HGAP_ANALYSISID}.stdout -S /bin/sh ./step4_running_basemod_single_v2.sh $i"
		touch ${STEP4_WORKING_FLAG};
		echo $CMD >> NOHUPS/nohup_step4_$(date +\%Y\%m\%d).txt
		eval $CMD
	else	
		rm $OUT_BASEMOD 2>/dev/null	
		mkdir $OUT_BASEMOD 2>/dev/null
		
		rm ${LOG_DIR}/step4_basemod_call_${HGAP_ANALYSISID}.std* 2>/dev/null
	
		CMD="qsub -cwd -q $QUEUE -N Step4_basemod_call_${HGAP_ANALYSISID} -e ${LOG_DIR}/step4_basemod_call_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step4_basemod_call_${HGAP_ANALYSISID}.stdout -S /bin/sh ./step4_running_basemod_single_v2.sh $i"
		
		touch ${STEP4_WORKING_FLAG};
		echo $CMD >> NOHUPS/nohup_step4_$(date +\%Y\%m\%d).txt
		eval $CMD
	#else
	#	echo "basemod_call_${HGAP_ANALYSISID} has already done! skip!"
	fi

done

