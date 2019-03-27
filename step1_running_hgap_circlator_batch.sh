#!/bin/bash
. ./global_bash_config.rc

MANIFEST=$1

for i in  $(awk -F "\t" '{if(NR>1){print $1"_"$2"_"$4"_"$5}}' $MANIFEST);do
	VIAL_ID=$(echo $i | cut -f1 -d_)
	BARCODING_ANALYSISID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $4}}' $MANIFEST)
	CGR_ID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $2}}' $MANIFEST)
	BARCODE_NAME=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $5}}' $MANIFEST)

	LOG_DIR=${ROOT_DIR}/${i}/logs
	OUT_HGAP=${ROOT_DIR}/${i}/HGAP_run

	mkdir -p $OUT_HGAP 2>/dev/null
	chmod 777 $OUT_HGAP
	mkdir -p $LOG_DIR 2>/dev/null
	rm ${LOG_DIR}/step1_running_hgap_circlator_${BARCODING_ANALYSISID}.std*
	
	CMD="qsub -cwd -q $QUEUE -N Step1_running_hgap_circlator_${BARCODING_ANALYSISID} -e ${LOG_DIR}/step1_running_hgap_circlator_${BARCODING_ANALYSISID}.stderr -o ${LOG_DIR}/step1_running_hgap_circlator_${BARCODING_ANALYSISID}.stdout -S /bin/sh step1_running_hgap_circlator.sh $BARCODING_ANALYSISID $BARCODE_NAME $OUT_HGAP"
	echo $CMD
	eval $CMD
done
