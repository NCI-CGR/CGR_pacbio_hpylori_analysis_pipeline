#!/bin/bash
module load python
. ./global_bash_config.rc

MANIFEST=$1
MANIFEST_NAME=$(basename $MANIFEST .txt)
	
#create assembly summary file for the batch
SUMMARY1=${ROOT_DIR}/summary_${MANIFEST_NAME}.txt
echo -e "SAMPLE\tASSEMBLE_COV\tNUM_CHR_CONTIGS\tNUM_PLA_CONTIGS\tNUM_CHR_NC\tNUM_PLA_NC\tLEN_CHR_CONTIGS\tLEN_PLA_CONTIGS" > $SUMMARY1

SUMMARY2=${ROOT_DIR}/summary_basemod_${MANIFEST_NAME}.txt
echo -e "SAMPLE\tM6A_QUAL\tM6A_COV\tM6A_IPD\tM6A_IDENTQV\tM4C_QUAL\tM4C_COV\tM4C_IPD\tM4C_IDENTQV\tMODBASE_QUAL\tMODBASE_COV\tMODBASE_IPD\tM6A_BASEMOD_COUNT\tM4C_BASEMOD_COUNT\tMODBASE_BASEMOD_COUNT\tASSEMBLE_COV" > $SUMMARY2

#for REPORT in $(awk -F"\t" 'NR>1{print "${ROOT_DIR}/"$1"_"$2"_"$3"/Report/temp/polished_assembly_report.txt"}' $MANIFEST);do
for i in  $(awk -F "\t" '{if(NR>1){print $1"_"$2"_"$3}}' $MANIFEST);do
	VIAL_ID=$(echo $i | cut -f1 -d_)
	HGAP_ANALYSISID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $3}}' $MANIFEST)
	CGR_ID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $2}}' $MANIFEST)
	REFERENCE_VIAL=$(echo $i | cut -f1 -d_ |sed -e 's/-/_/g')
	SAMPLE=${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}
	
	echo "#################Create Assembly Summary#####################"
	REPORT=${ROOT_DIR}/${SAMPLE}/Report/temp/polished_assembly_report.txt
	echo $REPORT

	CHR=$(grep $VIAL_ID $MANIFEST | awk -F"\t" '{print $4}' )
	PLA=$(grep $VIAL_ID $MANIFEST | awk -F"\t" '{print $5}' )
	rawPASS=0
	hifiPASS=0
	echo $CHR
	ASSEMBLE_COV=`head -2 ${ROOT_DIR}/${SAMPLE}/Report/temp/coverage_report.txt | tail -1`
	echo $ASSEMBLE_COV
	# grep -c will only count once for two occurence in the same line
	NUM_CHR_CONTIGS=$(grep -o _chromosomal $REPORT | wc -l)
	NUM_PLA_CONTIGS=$(grep -o _plasmid $REPORT | wc -l)
	NUM_CHR_NC=$(grep -o _chromosomal_NC $REPORT | wc -l)
	NUM_PLA_NC=$(grep -o _plasmid_NC $REPORT | wc -l)
	CHR_LEN_COL=$( awk -F "\t" '{for(i=1;i<=NF;i++) {if($i ~ "chromosomal"){print i}}}' $REPORT)

	echo $NUM_CHR_CONTIGS
	CHR_LENGTH=""
	for i in $CHR_LEN_COL;do 
		LENGTH=$(awk -F "\t" -v col=$i '{if (NR>1){print $col}}' $REPORT);
		CHR_LENGTH="$CHR_LENGTH $LENGTH";
	done
	
	PLA_LEN_COL=$( awk -F "\t" '{for(i=1;i<=NF;i++) {if($i ~ "plasmid"){print i}}}' $REPORT)
	echo $PLA_LEN_COL
	PLA_LENGTH=""
        for i in $PLA_LEN_COL;do
                LENGTH=$(awk -F "\t" -v col=$i '{if (NR>1){print $col}}' $REPORT);
                PLA_LENGTH="$LENGTH $PLA_LENGTH";
        done
		
	rawPsuedoFrac=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/raw_assemble_annotation.txt | cut -f5)
	rawgene=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/raw_assemble_annotation.txt | cut -f1)
	rawcds=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/raw_assemble_annotation.txt | cut -f2); 
	rawrRNA=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/raw_assemble_annotation.txt | cut -f3); 
	rawtRNA=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/raw_assemble_annotation.txt | cut -f4)

	if [[ $rawPsuedoFrac < 0.05 ]] && [[ $rawgene < 1700 ]] &&[[ $rawtRNA -eq "36" ]] && [[ $rawrRNA -eq "4" ]]; then 
		rawPASS=1
		echo "raw assembly pass annotation" 
	fi

	hifiPsuedoFrac=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/hifi_assemble_annotation.txt | cut -f5)
	hifigene=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/hifi_assemble_annotation.txt | cut -f1)
	hificds=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/hifi_assemble_annotation.txt | cut -f2); 
	hifirRNA=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/hifi_assemble_annotation.txt | cut -f3); 
	hifitRNA=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/hifi_assemble_annotation.txt | cut -f4)

	if [[ $hifiPsuedoFrac < 0.05 ]] && [[ $hifigene < 1700 ]] && [[ $hifirRNA -eq "4" ]]&& [[ $hifitRNA -eq "36" ]] ; then 
		hifiPASS=1
		echo "hifi assembly pass annotation" 
	fi

	echo 	
	echo $rawPASS
	echo $hifiPASS
	
	if [[ $CHR == "mga" ]]; then
		echo "${SAMPLE} chr assembly is from hgap. "
		ANNO=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/raw_assemble_annotation.txt )
		BUSCO=$(tail -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/raw_assemble_annotation.txt )
		cp -l -r ${ROOT_DIR}/${SAMPLE}/HGAP_run/prokka_protein ${ROOT_DIR}/${SAMPLE}/Delivery/
	elif [[ $CHR == "hifiasm" ]]; then	
		echo "${SAMPLE} chr assembly is from hifiasm. "
		ANNO=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/hifi_assemble_annotation.txt )
		cp -l -r ${ROOT_DIR}/${SAMPLE}/hifiasm_run/prokka_protein ${ROOT_DIR}/${SAMPLE}/Delivery/
		BUSCO=$(tail -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/hifi_assemble_annotation.txt )
	elif [[ $CHR == "both" ]] && [[ $rawPASS == 1 ]]; then
		echo "${SAMPLE} chr assembly is from hgap and both assembly pass annotation. "
		ANNO=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/raw_assemble_annotation.txt )
		cp -l -r ${ROOT_DIR}/${SAMPLE}/HGAP_run/prokka_protein ${ROOT_DIR}/${SAMPLE}/Delivery/
	elif [[ $CHR == "both" ]] && [[ $rawPASS == 0 ]] && [[ $hifiPASS == 1 ]]; then	
		echo "${SAMPLE} chr assembly is from hifiasm and hifi assembly pass annotation. "
		ANNO=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/hifi_assemble_annotation.txt )
		cp -l -r ${ROOT_DIR}/${SAMPLE}/hifiasm_run/prokka_protein ${ROOT_DIR}/${SAMPLE}/Delivery/
	elif [[ $CHR == "both" ]] && [[ $rawPASS == 0 ]] && [[ $hifiPASS == 0 ]]; then
		echo "${SAMPLE} chr assembly is from hgap and neither assembly pass annotation. "
		ANNO=$(head -1 ${ROOT_DIR}/${SAMPLE}/Report/temp/raw_assemble_annotation.txt )
		cp -l -r ${ROOT_DIR}/${SAMPLE}/HGAP_run/prokka_protein ${ROOT_DIR}/${SAMPLE}/Delivery/		
	else
		echo "${SAMPLE} chr assembly is not assigned! "
		exit 1
	fi		
	echo -e "$SAMPLE\t$ASSEMBLE_COV\t$NUM_CHR_CONTIGS\t$NUM_PLA_CONTIGS\t$NUM_CHR_NC\t$NUM_PLA_NC\t$CHR_LENGTH\t$PLA_LENGTH\t$ANNO\t$BUSCO" >> $SUMMARY1

    echo "#################Create Basemod Calling Summary#####################"
    REPORT2=${ROOT_DIR}/${SAMPLE}/BASEMOD_hifi_run/outputs/motifs.gff
#for REPORT in ${ROOT_DIR}/*/BASEMOD_hifi_run/tasks/motif_maker.tasks.reprocess-0/motifs.gff;do

	CONTIG=`grep '##sequence-region' $REPORT2 |head -1 | cut -f2 -d" " | cut -f1 -d'|'`
	M6A_QUAL=`awk -F"\t" '{if($3 =="m6A"){sum+=$6;count+=1}}END{print sum/count}' $REPORT2`
	M6A_COV=`awk -F"\t" '{if($3 =="m6A"){print $9}}' $REPORT2 | awk -F "coverage=" '{print $2}' | awk -F ";" '{sum+=$1;count+=1}END{print sum/count}'`
	M6A_IPD=`awk -F"\t" '{if($3 =="m6A"){print $9}}' $REPORT2 | awk -F "IPDRatio=" '{print $2}' | awk -F ";" '{sum+=$1;count+=1}END{print sum/count}'`
	M6A_IDENTQV=`awk -F"\t" '{if($3 =="m6A"){print $9}}' $REPORT2 | awk -F "identificationQv=" '{print $2}' | awk -F ";" '{sum+=$1;count+=1}END{print sum/count}'`
	
	M4C_QUAL=`awk -F"\t" '{if($3 =="m4C"){sum+=$6;count+=1}}END{print sum/count}' $REPORT2`
	M4C_COV=`awk -F"\t" '{if($3 =="m4C"){print $9}}' $REPORT2 | awk -F "coverage=" '{print $2}' | awk -F ";" '{sum+=$1;count+=1}END{print sum/count}'`
	M4C_IPD=`awk -F"\t" '{if($3 =="m4C"){print $9}}' $REPORT2 | awk -F "IPDRatio=" '{print $2}' | awk -F ";" '{sum+=$1;count+=1}END{print sum/count}'`
	M4C_IDENTQV=`awk -F"\t" '{if($3 =="m4C"){print $9}}' $REPORT2 | awk -F "identificationQv=" '{print $2}' | awk -F ";" '{sum+=$1;count+=1}END{print sum/count}'`

	MODBASE_QUAL=`awk -F"\t" '{if($3 =="modified_base"){sum+=$6;count+=1}}END{print sum/count}' $REPORT2`
	MODBASE_COV=`awk -F"\t" '{if($3 =="modified_base"){print $9}}' $REPORT2 | awk -F "coverage=" '{print $2}' | awk -F ";" '{sum+=$1;count+=1}END{print sum/count}'`
	MODBASE_IPD=`awk -F"\t" '{if($3 =="modified_base"){print $9}}' $REPORT2 | awk -F "IPDRatio=" '{print $2}' | awk -F ";" '{sum+=$1;count+=1}END{print sum/count}'`
	
	M6A_BASEMOD_COUNT=`awk -F"\t" '{if($3 =="m6A"){print $0}}' $REPORT2| wc -l`
	M4C_BASEMOD_COUNT=`awk -F"\t" '{if($3 =="m4C"){print $0}}' $REPORT2| wc -l`
	MODBASE_BASEMOD_COUNT=`awk -F"\t" '{if($3 =="modified_base"){print $0}}' $REPORT2| wc -l`
	ASSEMBLE_COV=`head -2 ${ROOT_DIR}/${SAMPLE}/Report/temp/coverage_report.txt | tail -1`


	echo -e "$SAMPLE\t$M6A_QUAL\t$M6A_COV\t$M6A_IPD\t$M6A_IDENTQV\t$M4C_QUAL\t$M4C_COV\t$M4C_IPD\t$M4C_IDENTQV\t$MODBASE_QUAL\t$MODBASE_COV\t$MODBASE_IPD\t$M6A_BASEMOD_COUNT\t$M4C_BASEMOD_COUNT\t$MODBASE_BASEMOD_COUNT\t$ASSEMBLE_COV" >> $SUMMARY2


    echo "#################Create delivery folders#####################"

	#echo $CGR_ID
	#chmod -R 777 ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}
	#chmod 774 ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/REPORT2
	echo $CGR_ID

	mkdir -p ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall 2>/dev/null
	mkdir -p ${DELIVERY_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}  2>/dev/null
	chmod -R 777 ${DELIVERY_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}
	cp -r ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Report ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery
	#cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/HGAP_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Assembly
	#cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/HGAP_run/processed_hgap/*_plasmid*.fasta ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Assembly
	cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/HGAP_run/processed_hgap/26695_vs_${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}_mummerplot.png ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Assembly
	cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_hifi_run/motifs_chromosomal.csv ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall
	cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_hifi_run/motifs_chromosomal.gff ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall
	PLASMID=$(ls ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/*/processed_hgap/*_plasmid*.fasta | wc -l)
	if [[ ${PLASMID} > 0 ]]; then
		cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_hifi_run/motifs_plasmid.csv ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall
		cp -l ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_hifi_run/motifs_plasmid.gff ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Basecall
	fi
	cp ${SCRIPT_DIR}/readme.txt ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery
	cp -r ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery ${DELIVERY_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}
	#cp -l -r ${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery /DCEG/TempFileSwap/Wen/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}
	rm -r ${DELIVERY_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Delivery/Report/temp 2>/dev/null
done
	
#run motif table summary for accumulated samples
rm ${ROOT_DIR}/motif_summary.txt
# for i in $(awk -F"\t" 'NR>1{print "${ROOT_DIR}/"$1"_"$2"_"$3"/BASEMOD_hifi_run/outputs/basemods.csv"}' $MANIFEST);do 
	# SAMPLE=$(dirname $i| cut -f7 -d/); awk -F, -v sample=$SAMPLE '{if(NR>1){print sample"\t"$1}}' $i;
for i in $(awk 'NR>1{print $1"_"$2"_"$3}' $MANIFEST); do 
	awk -F, -v sample=$i '{if(NR>1){print sample"\t"$1}}' ${ROOT_DIR}/${i}/BASEMOD_hifi_run/motifs_chromosomal.csv; 
	if [[ -s ${ROOT_DIR}/${i}/BASEMOD_hifi_run/motifs_plasmid.csv ]]; then 
		awk -F, -v sample=$i '{if(NR>1){print sample"\t"$1}}' ${ROOT_DIR}/${i}/BASEMOD_hifi_run/motifs_plasmid.csv; 
	fi; 
done >>${ROOT_DIR}/motiff_list.txt

python motif_summary_table.py
