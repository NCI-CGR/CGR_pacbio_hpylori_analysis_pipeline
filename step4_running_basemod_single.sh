#!/bin/bash
. ./global_bash_config.rc

SAMPLE=$1

VIAL_ID=$(echo $SAMPLE | cut -f1 -d_)
CGR_ID=$(echo $SAMPLE | cut -f2 -d_)
HGAP_ANALYSISID=$(echo $SAMPLE | cut -f3 -d_)

HGAP_ANALYSISID_PART1_PRE=$(echo $HGAP_ANALYSISID | rev | cut -c4- | rev )
HGAP_ANALYSISID_PART1=$(printf "%03d\n" $HGAP_ANALYSISID_PART1_PRE)
HGAP_ANALYSISID_PART2=$(echo $HGAP_ANALYSISID | rev | cut -c1-3 | rev)
#REFERENCE_VIAL=$(echo $i | cut -f1 -d_ |sed -e 's/-/_/g')
REFERENCE_VIAL=$(echo $SAMPLE | cut -f1 -d_)
LOG_DIR=${ROOT_DIR}/${SAMPLE}/logs
OUT_BASEMOD=${ROOT_DIR}/${SAMPLE}/BASEMOD_run
STEP4_WORKING_FLAG=${LOG_DIR}/step4_basemod_call.working
STEP4_DONE_FLAG=${LOG_DIR}/step4_basemod_call.done
if [[ -f /CGF/Resources/PacBio/jobs/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/eid_subread_merged.subreadset.xml ]]; then 
	SUBREADS_XML=/CGF/Resources/PacBio/jobs/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/eid_subread_merged.subreadset.xml
else
	SUBREADS_XML=$(ls /CGF/Resources/PacBio/jobs/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/entry-points/*.subreadset.xml)
fi
HGAP_HTRL_FOLDER=${PACBIO_JOB_DIR}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/html

COV=$(grep -A 1 "Mean Coverage" ${HGAP_HTRL_FOLDER}/pbreports.tasks.coverage_report_hgap.html| tail -1 | cut -f2 -d: | bc -l | xargs -I {} printf "%5.4f" {})
QUAL_CUTOFF1=`echo 0.15*${COV} | bc -l  | xargs -I {} printf "%5.0f" {}`

# if [[ $QUAL_CUTOFF1 -gt 240 ]];then
    # QUAL_CUTOFF1=240
# fi

#QUAL_CUTOFF2=`echo ${QUAL_CUTOFF1}-20 | bc -l  | xargs -I {} printf "%5.0f" {}`

CMD="${SMRTCMDS7}/pbsmrtpipe pipeline-id pbsmrtpipe.pipelines.ds_modification_motif_analysis -e eid_subread:${SUBREADS_XML} -e eid_ref_dataset:${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/${REFERENCE_VIAL}_basecall_ref/referenceset.xml --preset-json=${BASEMOD_JSON} --output-dir=${OUT_BASEMOD} --local-only"
echo $CMD
eval $CMD

INGFF=${ROOT_DIR}/${SAMPLE}/BASEMOD_run/tasks/pbcoretools.tasks.gather_gff-1/file.gff
REF=${ROOT_DIR}/${SAMPLE}/HGAP_run/processed_hgap/basecall_ref.fasta
OUTDIR=${ROOT_DIR}/${SAMPLE}/BASEMOD_run

CHR=`grep '>' ${REF} | head -1 | sed 's/>//'`
INGFF_CHR=${ROOT_DIR}/${SAMPLE}/BASEMOD_run/tasks/pbcoretools.tasks.gather_gff-1/file_chromosomal.gff
head -2 ${INGFF} > ${INGFF_CHR}
grep "${CHR}" ${INGFF} >> ${INGFF_CHR}
INGFF_PLA=${ROOT_DIR}/${SAMPLE}/BASEMOD_run/tasks/pbcoretools.tasks.gather_gff-1/file_plasmid.gff
grep -v "$CHR" ${INGFF} > ${INGFF_PLA}


CMD="/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/motifMaker find -f ${REF} -g ${INGFF_CHR} -m ${QUAL_CUTOFF1} -o ${OUTDIR}/motifs_chromosomal.csv"
echo $CMD
eval $CMD

CMD="/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/motifMaker reprocess -f ${REF} -g ${INGFF_CHR} -m ${OUTDIR}/motifs_chromosomal.csv -o ${OUTDIR}/motifs_chromosomal.gff"
echo $CMD
eval $CMD

CMD="/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/motifMaker find -f ${REF} -g ${INGFF_PLA} -m ${QUAL_CUTOFF1} -o ${OUTDIR}/motifs_plasmid.csv"
echo $CMD
eval $CMD

CMD="/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/motifMaker reprocess -f ${REF} -g ${INGFF_PLA} -m ${OUTDIR}/motifs_plasmid.csv -o ${OUTDIR}/motifs_plasmid.gff"
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