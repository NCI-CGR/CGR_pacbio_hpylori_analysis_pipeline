#!/bin/bash
. ./global_bash_config.rc

HGAP_ANALYSISID=$1
VIAL_ID=$2
CGR_ID=$3

HGAP_ANALYSISID_PART1_PRE=$(echo $HGAP_ANALYSISID | rev | cut -c4- | rev )
HGAP_ANALYSISID_PART1=$(printf "%03d\n" $HGAP_ANALYSISID_PART1_PRE)
HGAP_ANALYSISID_PART2=$(echo $HGAP_ANALYSISID | rev | cut -c1-3 | rev)
OUT_HGAP=${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/HGAP_run
OUT_BASEMOD=${ROOT_DIR}/${VIAL_ID}_${CGR_ID}_${HGAP_ANALYSISID}/BASEMOD_run
REFERENCE_VIAL=$(echo $VIAL_ID |sed -e 's/-/_/g')
HGAP_HTRL_FOLDER=${PACBIO_JOB_DIR}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/html
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
	VALUE=$(grep -A 1 "$i" ${HGAP_HTRL_FOLDER}/pbreports.tasks.polished_assembly.html | tail -1 | cut -f2 -d:)
	HEADER="$HEADER\t$i" 
	CONTENT="$CONTENT\t$VALUE"
done

CHR_NAME=$(basename ${OUT_HGAP}/processed_hgap/${VIAL_ID}_chromosomal*.fasta .fasta)
#CHR_LEN=$(awk '/^>/ {if (seqlen){print seqlen}; print ;seqlen=0;next; } { seqlen += length($0)}END{print seqlen}' ${OUT_HGAP}/processed_hgap/${VIAL_ID}_chromosomal.fasta)
CHR_LEN=$(head -1 ${OUT_HGAP}/processed_hgap/${VIAL_ID}_chromosomal*.fasta | cut -f2 -d=)
HEADER="$HEADER\t$CHR_NAME" 
CONTENT="$CONTENT\t$CHR_LEN"

HAS_PLASMID=$(ll ${OUT_HGAP}/processed_hgap/*_plasmid*.fasta | wc -l)

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
cp ${HGAP_HTRL_FOLDER}/images/pbreports.tasks.polished_assembly/polished_coverage_vs_quality.png ${REPORT_DIR}

#processing coverage report
HEADER="Mean Coverage"
CONTENT=$(grep -A 1 "Mean Coverage" ${HGAP_HTRL_FOLDER}/pbreports.tasks.coverage_report_hgap.html| tail -1 | cut -f2 -d: | bc -l | xargs -I {} printf "%5.4f" {})


echo -e $HEADER >> ${REPORT_TMP}/coverage_report.txt
echo -e $CONTENT >> ${REPORT_TMP}/coverage_report.txt

python tsv2html_colorless.py ${REPORT_TMP}/coverage_report.txt ${REPORT_TMP}/coverage_report_html.txt 
#move copy image step to step3 in case of both overage_plot_000000F.png and overage_plot_0.png
#cp ${HGAP_HTRL_FOLDER}/images/pbreports.tasks.coverage_report_hgap/coverage_plot_000000F.png ${REPORT_DIR}

#processing realignment report
HEADER=""
CONTENT=""
for i in "Number of Polymerase Reads (realigned)" "Polymerase Read Length Mean (realigned)" "Polymerase Read N50 (realigned)" "Number of Subread Bases (realigned)" "Subread Length Mean (realigned)" ;do 
	VALUE=$(grep -A 1 "$i" ${HGAP_HTRL_FOLDER}/pbreports.tasks.mapping_stats_hgap.html | head -2 | tail -1 | cut -f2 -d:)
	HEADER="$HEADER\t$i"
	CONTENT="$CONTENT\t$VALUE"
done

i="Mean Concordance (realigned)"
VALUE=$(grep -A 1 "$i" ${HGAP_HTRL_FOLDER}/pbreports.tasks.mapping_stats_hgap.html | head -2 | tail -1 | cut -f2 -d: | bc -l | xargs -I {} printf "%0.4f" {})
HEADER="$HEADER\t$i"
CONTENT="$CONTENT\t$VALUE"

echo -e $HEADER >> ${REPORT_TMP}/mapping_stats_report.txt
echo -e $CONTENT >> ${REPORT_TMP}/mapping_stats_report.txt

python tsv2html_colorless.py ${REPORT_TMP}/mapping_stats_report.txt ${REPORT_TMP}/mapping_stats_report_html.txt 
cp ${BASEMOD_HTML_FOLDER}/images/pbreports.tasks.modifications_report/kinetic_detections.png ${REPORT_DIR}
cp ${BASEMOD_HTML_FOLDER}/images/pbreports.tasks.modifications_report/kinetic_histogram.png ${REPORT_DIR}

#generating parameter file
grep "u'" ${PACBIO_JOB_DIR}/${HGAP_ANALYSISID_PART1}/${HGAP_ANALYSISID_PART1}${HGAP_ANALYSISID_PART2}/logs/pbsmrtpipe.log | sed -e "s/u'//g" | sed -e "s/'//g" | sed -e "s/,//g"| sed -e "s/:/\t/g" |  sed -e "s/}//g" | sed -e "s/{//g" | grep -v genomic_consensus.task_options.track_description > ${REPORT_TMP}/parameters.txt
python tsv2html_colorless.py ${REPORT_TMP}/parameters.txt ${REPORT_TMP}/parameters_html.txt 

#processing realignment report
grep -A 1 "name" ${HGAP_HTRL_FOLDER}/falcon_ns.tasks.task_report_preassembly_yield.html | awk -F ":" '{print $2}' | awk -vRS=",\n" -vORS="\t" '1' | sed 's/"//g' | awk -vRS="\n\n" -vORS="\n" '1' > ${REPORT_TMP}/pre_assembly_report.txt

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

