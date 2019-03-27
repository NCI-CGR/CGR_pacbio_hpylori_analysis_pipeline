#!/bin/bash
. ./global_bash_config.rc

MANIFEST=$1

for i in  $(awk -F "\t" '{if(NR>1){print $1"_"$2"_"$3}}' $MANIFEST);do
	VIAL_ID=$(echo $i | cut -f1 -d_)
	HGAP_ANALYSISID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $3}}' $MANIFEST)
	CGR_ID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $2}}' $MANIFEST)
	REFERENCE_VIAL=$(echo $i | cut -f1 -d_ |sed -e 's/-/_/g')
	#echo $CGR_ID
	#chmod -R 777 ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}
	#chmod 774 ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Report
	echo $CGR_ID
	rm -R ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery 2>/dev/null
	#echo $CGR_ID

	mkdir -p ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery 2>/dev/null
	mkdir -p ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Assembly 2>/dev/null
	mkdir -p ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall 2>/dev/null
	mkdir -p ${DELIVERY_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}  2>/dev/null
	chmod -R 777 ${DELIVERY_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}
	cp -r ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Report ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery
	cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/HGAP_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Assembly
	cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/HGAP_run/processed_hgap/*_plasmid*.fasta ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Assembly
	cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_run/tasks/motif_maker.tasks.find_motifs-0/motifs.csv ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall
	cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_run/tasks/motif_maker.tasks.reprocess-0/motifs.gff ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall
	cp ${SCRIPT_DIR}/readme.txt ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery
	cp -r ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery ${DELIVERY_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}
	#cp -l -r ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery /DCEG/TempFileSwap/Wen/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}
	rm -r ${DELIVERY_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Report/temp 2>/dev/null
done
	
