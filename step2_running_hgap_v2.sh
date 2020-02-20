#!/bin/bash
. ./global_bash_config.rc

MANIFEST=$1


for i in  $(awk -F "\t" '{if(NR>1){print $1"_"$2"_"$3}}' $MANIFEST);do
	VIAL_ID=$(echo $i | cut -f1 -d_)
	HGAP_ANALYSISID=$(awk -F "\t" -v vial=$VIAL_ID '{if($1==vial){print $3}}' $MANIFEST)
	LOG_DIR=${ROOT_DIR}/${i}/logs
	OUT_HGAP=${ROOT_DIR}/${i}/HGAP_run
	STEP2_WORKING_FLAG=${LOG_DIR}/step2_circlator.working
	STEP2_DONE_FLAG=${LOG_DIR}/step2_circlator.done
	
	#pacbio job path is always changing, get the length of jobid and append correct number of 0s to the job id to locate the file path
	NUM=$(echo -n $HGAP_ANALYSISID | wc -c)
	DOT=""
	for j in seq 1 $NUM;do DOT="${DOT}.";done
	HGAP_ANALYSISID_PART2=$(echo $JOB_PATH_LEN | sed "s/$DOT$/$HGAP_ANALYSISID/")
	echo $HGAP_ANALYSISID_PART2
	HGAP_ANALYSISID_PART1=$(echo $HGAP_ANALYSISID_PART2 | cut -c1-7)
	echo $HGAP_ANALYSISID_PART1
	REAL_JOB_DIR=$(readlink ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/cromwell-job)
	echo $REAL_JOB_DIR
	mkdir -p $OUT_HGAP 2>/dev/null
	mkdir -p $LOG_DIR 2>/dev/null
	mkdir -p ${ROOT_DIR}/${i}/HGAP_run/NUCMER 2>/dev/null
	rm ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}.std* 2>/dev/null
	rm -R ${ROOT_DIR}/${i}/HGAP_run/circlator_${HGAP_ANALYSISID} 2>/dev/null
	
	if [[ -f ${STEP2_WORKING_FLAG} || -f ${STEP2_DONE_FLAG} ]];then
		echo "${i} Circlator job is still running or already done, skip..."
	
	else		
		#find the raw reads file preads4falcon.fasta for circlator. In the new smrtlink v7, preads4falcon.fasta was separated into chr and plasmid
		ANALYSIS_TYPE=$(dirname ${REAL_JOB_DIR} | xargs basename)
		if [[ $ANALYSIS_TYPE == pb_assembly_microbial ]]; then
			PLASMID_FASTA=$(find ${REAL_JOB_DIR} -name "preads4falcon.fasta" | grep call-asm_plasmid)
			CHR_FASTA=$(find ${REAL_JOB_DIR} -name "preads4falcon.fasta" | grep call-asm_chrom)
			nucmer --maxmatch --nosimplify ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/consensus.fasta ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/consensus.fasta -p ${ROOT_DIR}/${i}/HGAP_run/NUCMER/file_${HGAP_ANALYSISID}.repeats
			show-coords -r ${ROOT_DIR}/${i}/HGAP_run/NUCMER/file_${HGAP_ANALYSISID}.repeats.delta > ${ROOT_DIR}/${i}/HGAP_run/NUCMER/file_${HGAP_ANALYSISID}.repeats.coords
			
			#CMD="qsub -cwd -q $QUEUE -N HGAP_file${BARCODING_JOB}_${i}_${i} -e ${LOG_DIR}/step2_HGAP_file${BARCODING_JOB}_${i}_${i}.stderr -o ${LOG_DIR}/step2_HGAP_file${BARCODING_JOB}_${i}_${i}.stdout -b y \"/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/pbsmrtpipe pipeline-id pbsmrtpipe.pipelines.polished_falcon_fat -e eid_subread:${ROOT_DIR}/file_${BARCODING_JOB}_${i}_${i}/file_${BARCODING_JOB}_filtered.${i}-${i}.subreads.xml --preset-json=${HGAP_JSON} --output-dir=${OUT_HGAP}\""
			CMD="qsub -cwd -q $QUEUE -N step2_circlator_${HGAP_ANALYSISID}_plasmid -e ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}_plasmid.stderr -o ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}_plasmid.stdout -b y \"touch ${STEP2_WORKING_FLAG}_plasmid; module load samtools python python3 SPAdes/3.7.1 canu/1.5 bwa/0.7.15 prodigal/2.6.3 MUMmer/3.23; circlator all --merge_min_length_merge 1000 ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/consensus.fasta ${PLASMID_FASTA} ${ROOT_DIR}/${i}/HGAP_run/circlator_${HGAP_ANALYSISID}_plasmid;mv ${STEP2_WORKING_FLAG}_plasmid ${STEP2_DONE_FLAG}_plasmid\""
			echo $CMD >> NOHUPS/nohup_step2_$(date +\%Y\%m\%d).txt
			echo $CMD
			eval $CMD
			CMD="qsub -cwd -q $QUEUE -N step2_circlator_${HGAP_ANALYSISID}_chrom -e ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}_chrom.stderr -o ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}_chrom.stdout -b y \"touch ${STEP2_WORKING_FLAG}_chrom; module load samtools python python3 SPAdes/3.7.1 canu/1.5 bwa/0.7.15 prodigal/2.6.3 MUMmer/3.23; circlator all ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/consensus.fasta ${CHR_FASTA} ${ROOT_DIR}/${i}/HGAP_run/circlator_${HGAP_ANALYSISID}_chrom;mv ${STEP2_WORKING_FLAG}_chrom ${STEP2_DONE_FLAG}_chrom\""
			echo $CMD >> NOHUPS/nohup_step2_$(date +\%Y\%m\%d).txt
			echo $CMD
			eval $CMD
		elif [[ $ANALYSIS_TYPE == pb_hgap4 ]]; then
			RAW_FASTA=$(find ${REAL_JOB_DIR} -name "preads4falcon.fasta" | tail -1)
			nucmer --maxmatch --nosimplify ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/consensus.fasta ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/consensus.fasta -p ${ROOT_DIR}/${i}/HGAP_run/NUCMER/file_${HGAP_ANALYSISID}.repeats
			show-coords -r ${ROOT_DIR}/${i}/HGAP_run/NUCMER/file_${HGAP_ANALYSISID}.repeats.delta > ${ROOT_DIR}/${i}/HGAP_run/NUCMER/file_${HGAP_ANALYSISID}.repeats.coords
			
			#CMD="qsub -cwd -q $QUEUE -N HGAP_file${BARCODING_JOB}_${i}_${i} -e ${LOG_DIR}/step2_HGAP_file${BARCODING_JOB}_${i}_${i}.stderr -o ${LOG_DIR}/step2_HGAP_file${BARCODING_JOB}_${i}_${i}.stdout -b y \"/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/pbsmrtpipe pipeline-id pbsmrtpipe.pipelines.polished_falcon_fat -e eid_subread:${ROOT_DIR}/file_${BARCODING_JOB}_${i}_${i}/file_${BARCODING_JOB}_filtered.${i}-${i}.subreads.xml --preset-json=${HGAP_JSON} --output-dir=${OUT_HGAP}\""
			CMD="qsub -cwd -q $QUEUE -N step2_circlator_${HGAP_ANALYSISID} -e ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}.stderr -o ${LOG_DIR}/step2_circlator_${HGAP_ANALYSISID}.stdout -b y \"touch ${STEP2_WORKING_FLAG}; module load samtools python python3 SPAdes/3.7.1 canu/1.5 bwa/0.7.15 prodigal/2.6.3 MUMmer/3.23; circlator all ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/outputs/consensus.fasta ${RAW_FASTA} ${ROOT_DIR}/${i}/HGAP_run/circlator_${HGAP_ANALYSISID};mv ${STEP2_WORKING_FLAG} ${STEP2_DONE_FLAG}\""
			echo $CMD >> NOHUPS/nohup_step2_$(date +\%Y\%m\%d).txt
			echo $CMD
			eval $CMD
		fi
	fi
done


