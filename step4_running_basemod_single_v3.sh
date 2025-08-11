#!/bin/bash
. ./global_bash_config.rc
set -euo pipefail

SAMPLE=$1
MANIFEST=$2
VIAL_ID=$(echo $SAMPLE | rev | cut -f3- -d_ | rev)
CGR_ID=$(echo $SAMPLE | rev | cut -f2 -d_ | rev)
HGAP_ANALYSISID=$(echo $SAMPLE | rev | cut -f1 -d_ | rev)
CHR=$(awk -F"\t" -v vialID=${VIAL_ID} '{if($1==vialID){print $4}}' $MANIFEST )
PLA=$(awk -F"\t" -v vialID=${VIAL_ID} '{if($1==vialID){print $5}}' $MANIFEST )
rawPASS=0
hifiPASS=0
echo $VIAL_ID
echo $CHR
echo $PLA
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

mkdir -p ${ROOT_DIR}/${SAMPLE}/Delivery/Assembly 2>/dev/null
echo 	
rawPlasmid=$(ls ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_*plasmid*.fasta | wc -l )
if [[ $CHR == "mga" ]]; then
    echo "${SAMPLE} chr assembly is from mga. "
    cp ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/basecall_ref.fasta
	cp -l ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${SAMPLE}/Delivery/Assembly
	chrPlot=$(ls ${ROOT_DIR}/${SAMPLE}/Report/temp/coverage_plot_ctg*.png | head -1 )
	mv ${chrPlot} ${ROOT_DIR}/${SAMPLE}/Report	
elif [[ $CHR == "hifiasm" ]]; then	
    echo "${SAMPLE} chr assembly is from hifiasm. "
    cp ${ROOT_DIR}/${SAMPLE}/hifiasm_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/basecall_ref.fasta
	cp -l ${ROOT_DIR}/${SAMPLE}/hifiasm_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${SAMPLE}/Delivery/Assembly
	chrPlot=$(ls ${ROOT_DIR}/${SAMPLE}/Report/temp/coverage_plot_${SAMPLE}_ptg*.png  )
	mv ${chrPlot} ${ROOT_DIR}/${SAMPLE}/Report		
elif [[ $CHR == "both" ]] && [[ $rawPASS == 1 ]]; then
    echo "${SAMPLE} chr assembly is from mga and both assembly pass annotation. "
    cp ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/basecall_ref.fasta
	cp -l ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${SAMPLE}/Delivery/Assembly	
elif [[ $CHR == "both" ]] && [[ $rawPASS == 0 ]] && [[ $hifiPASS == 1 ]]; then	
    echo "${SAMPLE} chr assembly is from hifiasm and hifi assembly pass annotation. "
    cp ${ROOT_DIR}/${SAMPLE}/hifiasm_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/basecall_ref.fasta
	cp -l ${ROOT_DIR}/${SAMPLE}/hifiasm_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${SAMPLE}/Delivery/Assembly
elif [[ $CHR == "both" ]] && [[ $rawPASS == 0 ]] && [[ $hifiPASS == 0 ]]; then
    echo "${SAMPLE} chr assembly is from mga and neither assembly pass annotation. "
    cp ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/basecall_ref.fasta
	cp -l ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_chromosomal*.fasta ${ROOT_DIR}/${SAMPLE}/Delivery/Assembly		
else
    echo "${SAMPLE} chr assembly is not assigned! "
	exit 1
fi

if [[ $PLA == "mga" ]] && [[ $rawPlasmid > 0 ]]; then
    echo "${SAMPLE} plasmid assembly is from mga. "
    cat ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_*plasmid*.fasta >> ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/basecall_ref.fasta
	cp -l ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_*plasmid*.fasta ${ROOT_DIR}/${SAMPLE}/Delivery/Assembly
	PLASMID_DIR=${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap
	plaPlot=$(ls ${ROOT_DIR}/${SAMPLE}/Report/temp/coverage_plot_ctg*.png | tail -n +2)
	mv ${plaPlot} ${ROOT_DIR}/${SAMPLE}/Report	
	rm ${ROOT_DIR}/${SAMPLE}/Report/*_thumb.png	
elif [[ $PLA == "hifiasm" ]]; then	
    echo "${SAMPLE} plasmid assembly is from hifiasm. "
    cat ${ROOT_DIR}/${SAMPLE}/hifiasm_run/processed_hgap/${VIAL_ID}_*plasmid*.fasta >> ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/basecall_ref.fasta
	cp -l ${ROOT_DIR}/${SAMPLE}/hifiasm_run/processed_hgap/${VIAL_ID}_*plasmid*.fasta ${ROOT_DIR}/${SAMPLE}/Delivery/Assembly
	PLASMID_DIR=${ROOT_DIR}/${SAMPLE}/hifiasm_run/processed_hgap
	plaPlot=$(ls ${ROOT_DIR}/${SAMPLE}/Report/temp/coverage_plot_ptg*.png  )
	mv ${plaPlot} ${ROOT_DIR}/${SAMPLE}/Report		
else
    echo "${SAMPLE} plasmid assembly is not assigned! "
	#exit 1
fi

samtools faidx ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/basecall_ref.fasta

rm -R ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_basecall_ref 2>/dev/null
CMD="${SMRTCMDS7}/fasta-to-reference ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/basecall_ref.fasta ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/ ${VIAL_ID}_basecall_ref"
echo $CMD
eval $CMD

#pacbio job path is always changing, get the length of jobid and append correct number of 0s to the job id to locate the file path
NUM=$(echo -n $HGAP_ANALYSISID | wc -c)
DOT=""
for j in `seq 1 $NUM`;do DOT="${DOT}.";done
HGAP_ANALYSISID_PART2=$(echo $JOB_PATH_LEN | sed "s/$DOT$/$HGAP_ANALYSISID/")
HGAP_ANALYSISID_PART1=$(echo $HGAP_ANALYSISID_PART2 | cut -c1-7)
REAL_JOB_DIR=$(readlink ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/cromwell-job)

#if the subreads comes from multiple smrtcell, it will be the eid_subread_merged.subreadset.xml
if [[ -f /DCEG/CGF/Resources/PacBio/jobs/0000/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/merge-datasets/outputs/merged.subreadset.xml ]]; then 
	SUBREADS_XML=/DCEG/CGF/Resources/PacBio/jobs/0000/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/merge-datasets/outputs/merged.subreadset.xml
else
	#SUBREADS_XML=$(ls /DCEG/CGF/Resources/PacBio/jobs/0000/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/entry-points/*/*.consensusreadset.xml)
	SUBREADS_XML=$(find /DCEG/CGF/Resources/PacBio/jobs/0000/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/cromwell-job/ -name "*consensusreadset.xml" | head -1)
fi

ANALYSIS_TYPE=$(dirname ${REAL_JOB_DIR} | xargs basename)
if [[ $ANALYSIS_TYPE == pb_assembly_microbial ]]; then
	HGAP_HTRL_FOLDER=$(ls -d ${REAL_JOB_DIR}/jRaptorGraphMapping/*/call-coverage_report/execution/)
elif [[ $ANALYSIS_TYPE == pb_mga4 ]]; then
	HGAP_HTRL_FOLDER=${REAL_JOB_DIR}/call-coverage_report/execution/
elif [[ $ANALYSIS_TYPE == pb_microbial_analysis ]]; then
	HGAP_HTRL_FOLDER=$(ls -d ${REAL_JOB_DIR}/call-pb_basemods_hifi/pb_basemods_hifi/*/call-coverage_reports/coverage_reports/*/call-pbreports_coverage/execution/)
fi

LOG_DIR=${ROOT_DIR}/${SAMPLE}/logs
OUT_BASEMOD=${ROOT_DIR}/${SAMPLE}/BASEMOD_hifi_run
STEP4_WORKING_FLAG=${LOG_DIR}/step4_basemod_call.working
STEP4_DONE_FLAG=${LOG_DIR}/step4_basemod_call.done
mkdir -p ${OUT_BASEMOD}/outputs/

# if [[ -d $HGAP_HTRL_FOLDER ]]; then
	# COV=$(grep -A 1 "Mean Coverage" ${HGAP_HTRL_FOLDER}/coverage.report.json| tail -1 | cut -f2 -d: | bc -l | xargs -I {} printf "%5.4f" {})
	# QUAL_CUTOFF1=`echo ${COV}/6 | bc -l  | xargs -I {} printf "%5.0f" {}`
# else
	# QUAL_CUTOFF1=200
# fi

# if [[ $QUAL_CUTOFF1 -gt 200 ]];then
    # QUAL_CUTOFF1=200
# fi
QUAL_CUTOFF1=$(awk -F"," '{if($4=="T" || $4=="G" && $5>0){print $5}}' /DCEG/CGF/Resources/PacBio/jobs/0000/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/basemods.csv | sort -r -n  | perl -e '$d=.001;@l=<>;print $l[int($d*$#l)]')
#QUAL_CUTOFF2=`echo ${QUAL_CUTOFF1}-20 | bc -l  | xargs -I {} printf "%5.0f" {}`

#CMD="${SMRTCMDS}/pbcromwell run pb_basemods -e ${SUBREADS_XML} -e ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${REFERENCE_VIAL}_basecall_ref/referenceset.xml --output-dir ${OUT_BASEMOD} -c 8 --overwrite"
#CMD="${SMRTCMDS}/pbcromwell run pb_basemods -e ${SUBREADS_XML} -e ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${REFERENCE_VIAL}_basecall_ref/referenceset.xml --output-dir ${OUT_BASEMOD} -c 8 --overwrite --task-option motif_min_score=200 --task-option run_find_motifs=true"
# CMD="${SMRTCMDS}/pbcromwell run pb_basemods_hifi -e ${SUBREADS_XML} -e ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_basecall_ref/referenceset.xml --task-option run_find_motifs=True --task-option filter_min_qv=20 --task-option dataset_filters=\"\" --task-option kineticstools_identify_mods=\"m4C,m6A\"  --config cromwell.conf --nproc 8 --output-dir ${OUT_BASEMOD} --overwrite"

# echo $CMD
# eval $CMD

CMD="/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/python3 -m pbcoretools.tasks.dataset_filter --log-level INFO ${SUBREADS_XML} ${OUT_BASEMOD}/filtered.consensusreadset.xml '--min-qv 20'"
echo $CMD
eval $CMD

CMD="ccs-kinetics-bystrandify --log-level INFO --log-file ${OUT_BASEMOD}/ccs-kinetics-bystrandify.log ${OUT_BASEMOD}/filtered.consensusreadset.xml ${OUT_BASEMOD}/ccs_kinetics_bystrandify.subreadset.xml"
echo $CMD
eval $CMD

CMD="pbmm2 align ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_basecall_ref/referenceset.xml ${OUT_BASEMOD}/ccs_kinetics_bystrandify.subreadset.xml ${OUT_BASEMOD}/mapped.alignmentset.xml --sort --min-gap-comp-id-perc 98.0  --min-length 50  --sample \"\"  --report-json ${OUT_BASEMOD}/mapping_stats.report.json -j 8 --log-level INFO --log-file ${OUT_BASEMOD}/pbmm2.log"
echo $CMD
eval $CMD

CMD="ipdSummary --log-level INFO  --log-file ${OUT_BASEMOD}/ipdSummary.log --numWorkers 8  ${OUT_BASEMOD}/mapped.alignmentset.xml --reference ${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${VIAL_ID}_basecall_ref/referenceset.xml --gff ${OUT_BASEMOD}/outputs/basemods.gff  --csv ${OUT_BASEMOD}/outputs/basemods.csv  --bigwig ipds.bw  --pvalue 0.001  --alignmentSetRefWindows --identify \"m4C,m6A\" --methylFraction"
echo $CMD
eval $CMD

REF=${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/basecall_ref.fasta
OUTDIR=${ROOT_DIR}/${SAMPLE}/BASEMOD_hifi_run

CHR=`grep '>' ${REF} | head -1 | sed 's/>//'`
INGFF_CHR=${OUT_BASEMOD}/outputs/file_chromosomal.gff
head -2 ${OUT_BASEMOD}/outputs/basemods.gff > ${INGFF_CHR}
grep "${CHR}" ${OUT_BASEMOD}/outputs/basemods.gff >> ${INGFF_CHR}

HAS_PLASMID=$(ls -l ${PLASMID_DIR}/*_plasmid*.fasta | wc -l)

echo $CHR
echo $HAS_PLASMID

if [[ ${HAS_PLASMID} > 0 ]]; then 
	INGFF_PLA=${OUT_BASEMOD}/outputs/file_plasmid.gff
	grep -v "$CHR" ${OUT_BASEMOD}/outputs/basemods.gff > ${INGFF_PLA}

	CMD="/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/pbmotifmaker find --min-score ${QUAL_CUTOFF1} ${REF} ${INGFF_PLA} ${OUTDIR}/motifs_plasmid.csv"
	echo $CMD
	eval $CMD

	CMD="/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/pbmotifmaker reprocess ${REF} ${INGFF_PLA} ${OUTDIR}/motifs_plasmid.csv ${OUTDIR}/motifs_plasmid.gff"
	echo $CMD
	eval $CMD
fi

CMD="/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/pbmotifmaker find --min-score ${QUAL_CUTOFF1} ${REF} ${INGFF_CHR} ${OUTDIR}/motifs_chromosomal.csv"
echo $CMD
eval $CMD

CMD="/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/pbmotifmaker reprocess ${REF} ${INGFF_CHR} ${OUTDIR}/motifs_chromosomal.csv ${OUTDIR}/motifs_chromosomal.gff"
echo $CMD
eval $CMD


if [[ $? -ne 0 ]]; then
    echo "Error: $(date) basemod call was failed!" 
    exit 1
fi

echo "###########################"
date
echo "${SAMPLE} finishing basemod call!"
mv ${STEP4_WORKING_FLAG} ${STEP4_DONE_FLAG}
