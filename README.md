# Hpylori Analysis Pipeline version=20200220

## Description

The main purpose of this pipeline is to achieve 1, circularized hpylori chromosomal; 2; plasmid contigs and base modification calls of m6A, m4C, and potentially m5C; 3, motif summary of pass filter base modifications.
It is consisted of 3 aspects. 
- Main Pipeline: assuming everything runs smoothly from start to end.
- Reseq Pipeline: For chromosomal contigs that fail to circularise with default circlator run, we will retrieve assemble fasta and run resequence analysis(mapping subreads to assembly) and run a ciruclarization again. (deprecated)
- Plasmid Followup Pipeline: For plasmid contigs that fail to circularise with default run, we will have 3 ways to try to ciruclarize. (deprecated)

## Main pipeline:
- Step 01: step1_running_hgap_circlator_batch.sh (to run hgap on demultiplexed samples, for now we don't need to run this one because Kristie is currently running HGAP through SMRTLink)
- Step 02: step2_running_hgap.sh $MANIFEST (to run circlator and nucmer self repeat)
- Step 03: step3_format_hgap_result_batch.sh $MANIFEST (to collect hpylori chr contig and plasmid contig, format them and create ref file for base modification call)
- Step 04: step4_running_basemod_submit.sh $MANIFEST (to run base modification call)
- Step 05: step5_retrieve_stats.sh $MANIFEST (to generate report)
- Step 06: step6_delivery.sh $MANIFEST  (to copy deliverables to DataDelivery folder)

Sample Manifest provided by lab(first 3 columns are required, 4, 5 column will be filled before base modification call):
Vial ID CGR ID  HGAP Analysis Job ID    chr	plasmid	Demultiplex Barcodes Analysis Job ID    PB barcode name demultiplexed data id
POR-001 SC489836        2274    2193    		BC1001  3237
POR-002 SC489837        2273    2193    		BC1002  3238
POR-003 SC489838        2272    2193    		BC1004  3233
POR-004 SC489839        2271    2193    		BC1008  3239
POR-005 SC489840        2270    2193    		BC1009  3234

## Manual steps to check QC output and decide proceeding contigs
- Post step 02 ciruclarization: 
	1, Examine circularization result and Kristie's comment on assemblies and decide ciruclarized small contigs and uncircularized contigs that potentially are palsmid. 
	2, Append '-include' after "ciruclar: no" to the 04.merge.circularise_details.log file.
- Post step 03 qc result examination:
	1, check plasmid blastn output
```
for i in $(awk -F"\t" 'NR>1{print $1"_"$2"_"$3}' $MANIFEST);do for j in /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/*/processed_hgap/*_blast.out; do ll $j; grep -n plasmid $j| head -5;done; done
``` 
	2, check plasmid repeat check
```
for i in $(awk -F"\t" 'NR>1{print $1"_"$2"_"$3}' $MANIFEST);do cp -l /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/*/processed_hgap/*_plasmid_*mummerplot.png /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/Manifest/plasmid_repeat/Revio-validation-NP0454-041;done
```
	3, check hifiasm coverage plot
```
for i in $(awk -F"\t" 'NR>1{print $1"_"$2"_"$3}' $MANIFEST);do cp -l /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/hifiasm_run/processed_hgap/coverage*len*.png /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/Manifest/hifiasm_coverage_plot/Revio-validation-NP0454-041; for j in /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/hifiasm_run/processed_hgap/coverage_plot_ptg*.png;do name=$(basename $j .png | cut -f3 -d_); cp -l $j /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/Manifest/hifiasm_coverage_plot/Revio-validation-NP0454-041/coverage_${i}_${name}.png;done; done
```
	4, check plasmid database OriC blast result
```
for i in $(awk -F"\t" 'NR>1{print $1"_"$2"_"$3}' /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/Manifest/Manifest-NP0454-043.txt);do ls -l /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/*/processed_hgap/*_blastDoriC.txt;done	
```

	5, check what chr and plasmid contigs are processed
```
for i in $(awk -F"\t" 'NR>1{print $1"_"$2"_"$3}' $MANIFEST);do ls -l  /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/*_run/processed_hgap/*chromosomal*.fasta;done
for i in $(awk -F"\t" 'NR>1{print $1"_"$2"_"$3}' $MANIFEST);do ls -l  /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/*_run/processed_hgap/*plasmid*.fasta;done
for i in $(awk -F"\t" 'NR>1{print $1"_"$2"_"$3}' /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/Manifest/Manifest-NP0454-045-BATCH2.txt);do chr=$(awk '/^>/ {if (seqlen){print seqlen}; print ;seqlen=0;next; } { seqlen += length($0)}END{print seqlen}' /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/HGAP_run/processed_hgap/*_chromosomal*.fasta | tail -1);plasmid="";for j in /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/HGAP_run/processed_hgap/*plasmid*.fasta;do len=$(awk '/^>/ {if (seqlen){print seqlen}; print ;seqlen=0;next; } { seqlen += length($0)}END{print seqlen}' ${j} | tail -1);plasmid="${plasmid},${len}";done; echo -e "${chr}/${plasmid}";done 2>/dev/null
```

	6, check prokka annotation and BUSCO score and compare between hgap and hifasm result as one of the criteria for assembly choice
```	
for i in $(awk -F"\t" 'NR>1{print $1"_"$2"_"$3}' $MANIFEST);do annotation=$(head -1  /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/Report/temp/raw_assemble_annotation.txt);busco=$(head -2 /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/Report/temp/raw_assemble_annotation.txt | tail -1);echo -e "${i}\t${annotation}\t${busco}";done
for i in $(awk -F"\t" 'NR>1{print $1"_"$2"_"$3}' $MANIFEST);do annotation=$(head -1  /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/Report/temp/hifi_assemble_annotation.txt);busco=$(head -2 /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/Report/temp/hifi_assemble_annotation.txt | tail -1);echo -e "${annotation}\t${busco}";done
for i in $(awk -F"\t" 'NR>1{print $1"_"$2"_"$3}' /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/Manifest/Manifest-NP0454-045-BATCH2.txt);do name=$(echo ${i} | cut -f1 -d_);fail=$(grep 'BUSCO analysis failed!' /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/logs/step3_format_hgap_*.stderr | wc -l); if [[ ${fail} > 0 ]];then run_busco /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/HGAP_run/processed_hgap/${name}_chromosomal.fasta;  grep 'C:' /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/HGAP_run/processed_hgap/${name}_chromosomal/short_summary.specific.campylobacterales_odb10.${name}_chromosomal.txt >> /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/Report/temp/raw_assemble_annotation.txt;fi; done

```	

- Pre step 04 assigning contigs to do base modification call: Append two columns to $MANIFEST for chr contigs and plasmid contigs. Parameters to assign "mga" or "hifiasm"

- Post step 04 check base modification call reference 
```
for i in $(awk -F"\t" 'NR>1{print $1"_"$2"_"$3}' $MANIFEST);do grep '#' /DCEG/CGF/Bioinformatics/Production/Wen/20230213_HpGP_phase2/${i}/BASEMOD_hifi_run/outputs/motifs.gff;done
```


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
