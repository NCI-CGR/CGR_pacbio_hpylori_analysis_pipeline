#!/bin/bash
. ./global_bash_config.rc

BARCODING_JOB=$1
BARCODE_NAME=$2
OUT_HGAP=$3

BARCODING_JOB_PART1_PRE=$(echo $BARCODING_JOB | rev | cut -c4- | rev )
BARCODING_JOB_PART1=$(printf "%03d\n" $BARCODING_JOB_PART1_PRE)
BARCODING_JOB_PART2=$(echo $BARCODING_JOB | rev | cut -c1-3 | rev)
	
echo ====================
date;echo "HGAP started.."

SUBREADS_XML=$(ls /CGF/Resources/PacBio/smrtlink/userdata/jobs_root/${BARCODING_JOB_PART1}/${BARCODING_JOB_PART1}${BARCODING_JOB_PART2}/tasks/pbcoretools.tasks.update_barcoded_sample_metadata-0/lima_output.${BARCODE_NAME}*.subreadset.xml)
CMD="/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/pbsmrtpipe pipeline-id pbsmrtpipe.pipelines.polished_falcon_fat -e eid_subread:$SUBREADS_XML --preset-json=${HGAP_JSON} --output-dir=${OUT_HGAP}"
#CMD="/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/pbsmrtpipe pipeline-id pbsmrtpipe.pipelines.polished_falcon_fat -e eid_subread:$SUBREADS_XML --preset-json=/home/luow2/20180220_test_hgap_run/test2/preset_rl2000.json --output-dir=${OUT_HGAP}"
echo $CMD
eval $CMD

echo ====================
date;echo "HGAP finished.."

mkdir -p ${OUT_HGAP}/NUCMER 2>/dev/null
nucmer --maxmatch --nosimplify ${OUT_HGAP}/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta ${OUT_HGAP}/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta -p ${OUT_HGAP}/NUCMER/file_${BARCODING_JOB}_${BARCODE_NAME}.repeats
show-coords -r ${OUT_HGAP}/NUCMER/file_${BARCODING_JOB}_${BARCODE_NAME}.repeats.delta > ${OUT_HGAP}/NUCMER/file_${BARCODING_JOB}_${BARCODE_NAME}.repeats.coords

CMD="circlator all ${OUT_HGAP}/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta ${OUT_HGAP}/tasks/falcon_ns.tasks.task_falcon1_run_merge_consensus_jobs-0/preads4falcon.fasta ${OUT_HGAP}/circlator_${BARCODING_JOB}_${BARCODE_NAME}"
echo $CMD
eval $CMD


