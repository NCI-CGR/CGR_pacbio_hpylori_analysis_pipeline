#!/bin/bash
. ./global_bash_config.rc

MANIFEST=$1


for i in  $(awk -F "\t" '{if(NR>1){print $1"_"$2"_"$3}}' $MANIFEST);do
	VIAL_ID=$(echo $i | cut -f1 -d_)
	HGAP_ANALYSISID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $3}}' $MANIFEST)
	[ "$HGAP_ANALYSISID_PART1_PRE" ] || HGAP_ANALYSISID_PART1_PRE=0
	HGAP_ANALYSISID_PART1_PRE=$(echo $HGAP_ANALYSISID | rev | cut -c4- | rev )
	HGAP_ANALYSISID_PART1=$(printf "%03d\n" $HGAP_ANALYSISID_PART1_PRE)
	HGAP_ANALYSISID_PART2=$(echo $HGAP_ANALYSISID | rev | cut -c1-3 | rev)
	LOG_DIR=${ROOT_DIR}/${i}/logs
	OUT_HGAP=${ROOT_DIR}/${i}/HGAP_run
	STEP2_WORKING_FLAG=${LOG_DIR}/step2_circlator.working
	STEP2_DONE_FLAG=${LOG_DIR}/step2_circlator.done
	
	mkdir -p $OUT_HGAP 2>/dev/null
	mkdir -p $LOG_DIR 2>/dev/null
	mkdir -p ${ROOT_DIR}/${i}/HGAP_run/NUCMER 2>/dev/null
	rm ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}.std* 2>/dev/null
	rm -R ${ROOT_DIR}/${i}/HGAP_run/circlator_${HGAP_ANALYSISID} 2>/dev/null
	
	if [[ -f ${STEP2_WORKING_FLAG} || -f ${STEP2_DONE_FLAG} ]];then
		echo "${i} Circlator job is still running or already done, skip..."
	
	else		
		nucmer --maxmatch --nosimplify ${PACBIO_JOB_DIR}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta ${PACBIO_JOB_DIR}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta -p ${ROOT_DIR}/${i}/HGAP_run/NUCMER/file_${HGAP_ANALYSISID}.repeats
		show-coords -r ${ROOT_DIR}/${i}/HGAP_run/NUCMER/file_${HGAP_ANALYSISID}.repeats.delta > ${ROOT_DIR}/${i}/HGAP_run/NUCMER/file_${HGAP_ANALYSISID}.repeats.coords
		
		#CMD="qsub -cwd -q $QUEUE -N HGAP_file${BARCODING_JOB}_${i}_${i} -e ${LOG_DIR}/step2_HGAP_file${BARCODING_JOB}_${i}_${i}.stderr -o ${LOG_DIR}/step2_HGAP_file${BARCODING_JOB}_${i}_${i}.stdout -b y \"/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/pbsmrtpipe pipeline-id pbsmrtpipe.pipelines.polished_falcon_fat -e eid_subread:${ROOT_DIR}/file_${BARCODING_JOB}_${i}_${i}/file_${BARCODING_JOB}_filtered.${i}-${i}.subreads.xml --preset-json=${HGAP_JSON} --output-dir=${OUT_HGAP}\""
		CMD="qsub -cwd -q $QUEUE -N step2_circlator_${HGAP_ANALYSISID} -e ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}.stdout -b y \"touch ${STEP2_WORKING_FLAG}; module load samtools python python3 SPAdes/3.7.1 canu/1.5 bwa/0.7.15 prodigal/2.6.3 MUMmer/3.23; circlator all ${PACBIO_JOB_DIR}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta ${PACBIO_JOB_DIR}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/tasks/falcon_ns2.tasks.task_falcon1_run_db2falcon-0/preads4falcon.fasta ${ROOT_DIR}/${i}/HGAP_run/circlator_${HGAP_ANALYSISID};mv ${STEP2_WORKING_FLAG} ${STEP2_DONE_FLAG}\""
		echo $CMD >> NOHUPS/nohup_step2_$(date +\%Y\%m\%d).txt
		echo $CMD
		eval $CMD
	fi
done


