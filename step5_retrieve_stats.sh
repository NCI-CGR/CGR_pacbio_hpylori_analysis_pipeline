#!/bin/bash
. ./global_bash_config.rc

MANIFEST=$1

for i in  $(awk -F "\t" '{if(NR>1){print $1"_"$2"_"$3}}' $MANIFEST);do
	VIAL_ID=$(echo $i | cut -f1 -d_)
	#CGR_ID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $2}}' $MANIFEST)
	#HGAP_ANALYSISID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $3}}' $MANIFEST)
	CGR_ID=$(echo $i | cut -f2 -d_)
	HGAP_ANALYSISID=$(echo $i | cut -f3 -d_)
	REFERENCE_VIAL=$(echo $i | cut -f1 -d_ |sed -e 's/-/_/g')
	LOG_DIR=${ROOT_DIR}/${i}/logs
	
	rm ${LOG_DIR}/step5_retrieve_stats_${HGAP_ANALYSISID}.std*
	#CMD="sbatch -e ${LOG_DIR}/step5_retrieve_stats_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step5_retrieve_stats_${HGAP_ANALYSISID}.stdout step5_retrieve_stats_single_v3.sh $HGAP_ANALYSISID $VIAL_ID $CGR_ID"
	CMD="qsub -cwd -q $QUEUE -N Step5_retrieve_stats_${HGAP_ANALYSISID} -e ${LOG_DIR}/step5_retrieve_stats_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step5_retrieve_stats_${HGAP_ANALYSISID}.stdout -S /bin/sh step5_retrieve_stats_single_v2.sh $HGAP_ANALYSISID $VIAL_ID $CGR_ID"	
	echo $CMD >> NOHUPS/nohup_step5_$(date +\%Y\%m\%d).txt
        echo $CMD
        eval $CMD

done

