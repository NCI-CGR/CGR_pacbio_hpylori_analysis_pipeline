# Hpylori Analysis Pipeline version=20200220

## Description

The main purpose of this pipeline is to achieve 1, circularized hpylori chromosomal; 2; plasmid contigs and base modification calls of m6A, m4C, and potentially m5C; 3, motif summary of pass filter base modifications.
It is consisted of 3 aspects. 
- Main Pipeline: assuming everything runs smoothly from start to end.
- Reseq Pipeline: For chromosomal contigs that fail to circularise with default circlator run, we will retrieve assemble fasta and run resequence analysis(mapping subreads to assembly) and run a ciruclarization again. 
- Plasmid Followup Pipeline: For plasmid contigs that fail to circularise with default run, we will have 3 ways to try to ciruclarize.

## Main pipeline:
- Step 01: step1_running_hgap_circlator_batch.sh (to run hgap on demultiplexed samples, for now we don't need to run this one because Kristie is currently running HGAP through SMRTLink)
- Step 02: step2_running_hgap.sh $MANIFEST (to run circlator and nucmer self repeat)
- Step 03: step3_format_hgap_result_batch.sh $MANIFEST (to collect hpylori chr contig and plasmid contig, format them and create ref file for base modification call)
- Step 04: step4_running_basemod_submit.sh $MANIFEST (to run base modification call)
- Step 05: step5_retrieve_stats.sh $MANIFEST (to generate report)
- Step 06: step6_delivery.sh $MANIFEST  (to copy deliverables to DataDelivery folder)

Sample Manifest provided by lab(first 3 columns are required):
Vial ID CGR ID  HGAP Analysis Job ID    Demultiplex Barcodes Analysis Job ID    PB barcode name demultiplexed data id
POR-001 SC489836        2274    2193    BC1001  3237
POR-002 SC489837        2273    2193    BC1002  3238
POR-003 SC489838        2272    2193    BC1004  3233
POR-004 SC489839        2271    2193    BC1008  3239
POR-005 SC489840        2270    2193    BC1009  3234

## Reseq Pipeline(force closure of uncircularized chr contig)

Reseq chr cicularization pipeline(snakemake):
#intend to run on the sample with chr contig fail to circularize in previous step1_running_hgap_circlator_batch
qsub -cwd -q $QUEUE -N ${SAMPLE} -o ${STDOUT} -e {STDERR} -s /bin/sh reseq_pipeline/mainSnake.sh ${SAMPLE} 
#SAMPLE in the format of POR-005_SC489840_2270

## Plasmid cicularization follow up pipeline(snakemake) :
01: to run hgap on plasmid only data with read length filter to remove chimeric expansion
	sh plasmid_pipeline/submit_main.sh plasmid_pipeline/manifest_example.txt
02: in case of previous step fail to ciruclarize, substitute hgap with canu
	sh plasmid_pipeline/submit_main_canu.sh plasmid_pipeline/manifest_canu_example.txt
03: in case of both previous steps fail to circularize, pull out all reads mapped to plasmid contig and redo assemble again
	sh plasmid_pipeline/submit_resequence.sh plasmid_pipeline/manifest_reseq_example.txt