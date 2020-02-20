#!/bin/bash
. ./global_bash_config.rc

HGAP_ANALYSISID=$1
VIAL_ID=$2
CGR_ID=$3

#pacbio job path is always changing, get the length of jobid and append correct number of 0s to the job id to locate the file path
NUM=$(echo -n $HGAP_ANALYSISID | wc -c)
DOT=""
for j in seq 1 $NUM;do DOT="${DOT}.";done
HGAP_ANALYSISID_PART2=$(echo $JOB_PATH_LEN | sed "s/$DOT$/$HGAP_ANALYSISID/")
HGAP_ANALYSISID_PART1=$(echo $HGAP_ANALYSISID_PART2 | cut -c1-7)
REAL_JOB_DIR=$(readlink ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/cromwell-job)
OUT_HGAP=${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/HGAP_run
OUT_BASEMOD=${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_run
ANALYSIS_TYPE=$(dirname ${REAL_JOB_DIR} | xargs basename)
if [[ $ANALYSIS_TYPE == pb_assembly_microbial ]]; then
	HGAP_HTRL_FOLDER=$(ls -d ${REAL_JOB_DIR}/call-mapping_all/RaptorGraphMapping/*/call-coverage_report/execution/)
	POLISHED_CONTIG_DIR=${REAL_JOB_DIR}/call-polished_assembly/execution
elif [[ $ANALYSIS_TYPE == pb_hgap4 ]]; then
	HGAP_HTRL_FOLDER=${REAL_JOB_DIR}/call-coverage_report/execution/
	POLISHED_CONTIG_DIR=${REAL_JOB_DIR}/call-polished_assembly/execution
fi
MAPPING_REPORT=`find ${REAL_JOB_DIR}/ -name "mapping_stats.report.json"`
PREASSEMBLE_REPORT=`find ${REAL_JOB_DIR}/ -name "preassembly.report.json"`
BASEMOD_HTML_FOLDER=${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_run/html
REPORT_DIR=${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/Report
HTML_REPORT=${REPORT_DIR}/${VIAL_ID}_${CGR_ID}_report.html
REPORT_TMP=${REPORT_DIR}/temp
mkdir -p ${REPORT_DIR} 2>/dev/null
mkdir -p ${REPORT_DIR}/temp 2>/dev/null
rm ${REPORT_TMP}/*.txt 2>/dev/null
rm ${HTML_REPORT}/*.html 2>/dev/null

#processing contig report
HEADER=""
CONTENT=""
for i in "Polished Contigs" "Maximum Contig Length" "N50 Contig Length" "Sum of Contig Lengths";do 
	VALUE=$(grep -A 1 "$i" ${POLISHED_CONTIG_DIR}/polished_assembly.report.json | head -2 | tail -1 | cut -f2 -d:)
	HEADER="$HEADER\t$i" 
	CONTENT="$CONTENT\t$VALUE"
done

for i in ${OUT_HGAP}/processed_hgap/*_chromosomal*.fasta;do

    CHR_NAME=$(basename $i .fasta)
    CHR_LEN=$(awk '/^>/ {if (seqlen){print seqlen}; print ;seqlen=0;next; } { seqlen += length($0)}END{print seqlen}' ${i} | tail -1)
    #CHR_LEN=$(head -1 $i | cut -f2 -d=)
    HEADER="$HEADER\t$CHR_NAME" 
    CONTENT="$CONTENT\t$CHR_LEN"
done

HAS_PLASMID=$(ls -l ${OUT_HGAP}/processed_hgap/*_plasmid*.fasta | wc -l)

if [[ $HAS_PLASMID -gt 0 ]];then 
	for i in ${OUT_HGAP}/processed_hgap/*_plasmid*.fasta;do 
		CHR_NAME=$(basename $i .fasta)
		CHR_LEN=$(awk '/^>/ {if (seqlen){print seqlen};seqlen=0;next; } { seqlen += length($0)}END{print seqlen}' $i)
		HEADER="$HEADER\t$CHR_NAME" 
		CONTENT="$CONTENT\t$CHR_LEN"
	done
fi

echo -e $HEADER >> ${REPORT_TMP}/polished_assembly_report.txt
echo -e $CONTENT >> ${REPORT_TMP}/polished_assembly_report.txt

python tsv2html_colorless.py ${REPORT_TMP}/polished_assembly_report.txt ${REPORT_TMP}/polished_assembly_report_html.txt
cp ${POLISHED_CONTIG_DIR}/polished_coverage_vs_quality.png ${REPORT_DIR}

#processing coverage report
HEADER="Mean Coverage"
CONTENT=$(grep -A 1 "Mean Coverage" ${HGAP_HTRL_FOLDER}/coverage.report.json| tail -1 | cut -f2 -d: | bc -l | xargs -I {} printf "%5.4f" {})


echo -e $HEADER >> ${REPORT_TMP}/coverage_report.txt
echo -e $CONTENT >> ${REPORT_TMP}/coverage_report.txt

python tsv2html_colorless.py ${REPORT_TMP}/coverage_report.txt ${REPORT_TMP}/coverage_report_html.txt 
#move copy image step to step3 in case of both overage_plot_000000F.png and overage_plot_0.png
#cp ${HGAP_HTRL_FOLDER}/images/pbreports.tasks.coverage_report_hgap/coverage_plot_000000F.png ${REPORT_DIR}

#processing realignment report
HEADER=""
CONTENT=""
for i in "Number of Polymerase Reads (aligned)" "Polymerase Read Length Mean (aligned)" "Polymerase Read N50 (aligned)" "Number of Subread Bases (aligned)" "Alignment Length Mean (aligned)" ;do 
	VALUE=$(grep -A 1 "$i" ${MAPPING_REPORT} | head -2 | tail -1 | cut -f2 -d:)
	HEADER="$HEADER\t$i"
	CONTENT="$CONTENT\t$VALUE"
done

i="Mean Concordance (aligned)"
VALUE=$(grep -A 1 "$i" ${MAPPING_REPORT} | head -2 | tail -1 | cut -f2 -d: | bc -l | xargs -I {} printf "%0.4f" {})
HEADER="$HEADER\t$i"
CONTENT="$CONTENT\t$VALUE"

echo -e $HEADER >> ${REPORT_TMP}/mapping_stats_report.txt
echo -e $CONTENT >> ${REPORT_TMP}/mapping_stats_report.txt

python tsv2html_colorless.py ${REPORT_TMP}/mapping_stats_report.txt ${REPORT_TMP}/mapping_stats_report_html.txt 
cp ${BASEMOD_HTML_FOLDER}/images/pbreports.tasks.modifications_report/kinetic_detections.png ${REPORT_DIR}
cp ${BASEMOD_HTML_FOLDER}/images/pbreports.tasks.modifications_report/kinetic_histogram.png ${REPORT_DIR}

#generating parameter file
grep -A 1 '"id":'  ${PACBIO_JOB_DIR8}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART2}/pbscala-job.stdout | awk -F":" '{print $2}' |  tr ",\n" "\t" | awk '{for (i=1;i<=NF;i++) {if(i%2 !=0) {print $i"\t"$(i+1)}}}' > ${REPORT_TMP}/parameters.txt
python tsv2html_colorless.py ${REPORT_TMP}/parameters.txt ${REPORT_TMP}/parameters_html.txt 

#processing realignment report
grep -A 1 '"name":'  ${PREASSEMBLE_REPORT} | awk -F":" '{print $2}' |  tr "\n" "\t" | awk -F"\t" '{for (i=1;i<=NF;i++) {if(i%3 ==1) {print $i"\t"$(i+1)}}}' > ${REPORT_TMP}/pre_assembly_report.txt

#start building html report
echo "<html><body>" > $HTML_REPORT
echo "<h2>Poslished assembly report</h2>" >> $HTML_REPORT
echo "<br>" >> $HTML_REPORT
cat ${REPORT_TMP}/polished_assembly_report_html.txt >> $HTML_REPORT
echo "<br>" >> $HTML_REPORT
echo "<img src=\"polished_coverage_vs_quality.png\" width=\"1000\" height=\"700\" alt=\"polished_coverage_vs_quality\">" >> $HTML_REPORT
echo "<br>" >> $HTML_REPORT
echo "<h2>Coverage report</h2>" >> $HTML_REPORT
echo "<br>" >> $HTML_REPORT
cat ${REPORT_TMP}/coverage_report_html.txt >> $HTML_REPORT
for i in ${REPORT_DIR}/coverage_plot_*.png;do 
	IMAGE_NAME=$(basename $i .png | cut -f3 -d_)
	echo "<br>" >> $HTML_REPORT
	echo "<h2>coverage_plot_${IMAGE_NAME}</h2>" >> $HTML_REPORT
	echo "<img src=\"coverage_plot_${IMAGE_NAME}.png\" width=\"1000\" height=\"700\" alt=\"coverage_plot_${IMAGE_NAME}\">" >> $HTML_REPORT
done
echo "<br>" >> $HTML_REPORT
echo "<h2>Mapping stats report</h2>" >> $HTML_REPORT
echo "<br>" >> $HTML_REPORT
cat ${REPORT_TMP}/mapping_stats_report_html.txt >> $HTML_REPORT
echo "<br>" >> $HTML_REPORT
echo "<h2>Hgap parameter</h2>" >> $HTML_REPORT
echo "<br>" >> $HTML_REPORT
cat ${REPORT_TMP}/parameters_html.txt >> $HTML_REPORT
echo "<br>" >> $HTML_REPORT
echo "<h2>Base modification kinetic</h2>" >> $HTML_REPORT
echo "<br>" >> $HTML_REPORT
echo "<img src=\"kinetic_detections.png\" width=\"1000\" height=\"700\" alt=\"kinetic_detections\">" >> $HTML_REPORT
echo "<br>" >> $HTML_REPORT
echo "<img src=\"kinetic_histogram.png\" width=\"1000\" height=\"700\" alt=\"kinetic_histogram\">" >> $HTML_REPORT
echo "<br>" >> $HTML_REPORT

