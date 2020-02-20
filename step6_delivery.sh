#!/bin/bash
module load python
. ./global_bash_config.rc

MANIFEST=$1
MANIFEST_NAME=$(basename $MANIFEST .txt)
SUMMARY=/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/summary_${MANIFEST_NAME}.txt
echo -e "SAMPLE\tNUM_CHR_CONTIGS\tNUM_PLA_CONTIGS\tNUM_CHR_NC\tNUM_PLA_NC\tLEN_CHR_CONTIGS\tLEN_PLA_CONTIGS" > $SUMMARY

for REPORT in $(awk -F"\t" 'NR>1{print "/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/"$1"_"$2"_"$3"/Report/temp/polished_assembly_report.txt"}' $MANIFEST);do
	echo $REPORT
	SAMPLE=$(echo $REPORT| cut -f7 -d/)
	# grep -c will only count once for two occurence in the same line
	NUM_CHR_CONTIGS=$(grep -o _chromosomal $REPORT | wc -l)
	NUM_PLA_CONTIGS=$(grep -o _plasmid $REPORT | wc -l)
	NUM_CHR_NC=$(grep -o _chromosomal_NC $REPORT | wc -l)
	NUM_PLA_NC=$(grep -o _plasmid_NC $REPORT | wc -l)
	CHR_LEN_COL=$( awk -F "\t" '{for(i=1;i<=NF;i++) {if($i ~ "chromosomal"){print i}}}' $REPORT)
	#echo $CHR_LEN_COL
	CHR_LENGTH=""
	for i in $CHR_LEN_COL;do 
		LENGTH=$(awk -F "\t" -v col=$i '{if (NR>1){print $col}}' $REPORT);
		CHR_LENGTH="$CHR_LENGTH $LENGTH";
	done
	
	PLA_LEN_COL=$( awk -F "\t" '{for(i=1;i<=NF;i++) {if($i ~ "plasmid"){print i}}}' $REPORT)
	#echo $PLA_LEN_COL
	PLA_LENGTH=""
        for i in $PLA_LEN_COL;do
                LENGTH=$(awk -F "\t" -v col=$i '{if (NR>1){print $col}}' $REPORT);
                PLA_LENGTH="$LENGTH $PLA_LENGTH";
        done
	echo -e "$SAMPLE\t$NUM_CHR_CONTIGS\t$NUM_PLA_CONTIGS\t$NUM_CHR_NC\t$NUM_PLA_NC\t$CHR_LENGTH\t$PLA_LENGTH" >> $SUMMARY

done


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
	cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/HGAP_run/processed_hgap/26695_vs_${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}_mummerplot.png ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Assembly
	cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_run/motifs_chromosomal.csv ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall
	cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_run/motifs_chromosomal.gff ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall
	PLASMID=$(ls ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/HGAP_run/processed_hgap/*_plasmid*.fasta | wc -l)
	if [[ ${PLASMID} > 0 ]]; then
		cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_run/motifs_plasmid.csv ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall
		cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_run/motifs_plasmid.gff ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall
	fi
	cp ${SCRIPT_DIR}/readme.txt ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery
	cp -r ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery ${DELIVERY_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}
	#cp -l -r ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery /DCEG/TempFileSwap/Wen/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}
	rm -r ${DELIVERY_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Report/temp 2>/dev/null
done
	
rm /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/motif_summary.txt
for i in /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/*/BASEMOD_run/tasks/motif_maker.tasks.find_motifs-0/motifs.csv;do 
	SAMPLE=$(dirname $i| cut -f7 -d/); awk -F, -v sample=$SAMPLE '{if(NR>1){print sample"\t"$1}}' $i;
done>/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/motiff_list.txt

python motif_summary_table.py
