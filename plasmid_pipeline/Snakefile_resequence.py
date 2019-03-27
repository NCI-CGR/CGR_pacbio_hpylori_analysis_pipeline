#!/usr/bin/python

##add your name below if you are editing this
'''
pipeline contributors:
Wen


This is to original dataset and plasmid contig to do resequencing and get the reads filtered out during plasmid follow up pipeline because they mapped to both chr and plasmid. and then use the whitelist reads to do assemble again.
'''

import glob
import sys
import os

configfile: "config_resequence.yaml"

SAMPLE_NAME = config['SAMPLE_NAME']
PLASMID_CONTIG = config['PLASMID_CONTIG']
JOB_NUM = config['JOB_NUM']

rule all:
    input:
        expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/circlator/04.merge.circularise_details.log', sample = SAMPLE_NAME),
        expand('CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/CANU/circlator/04.merge.circularise_details.log', sample = SAMPLE_NAME)

rule reseq_fasta_to_reference:
    input:
        contig = PLASMID_CONTIG, 
        dir = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid' , sample = SAMPLE_NAME) 
    output:
        expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/referenceset.xml', sample = SAMPLE_NAME)
    params:
        'plasmid_resequence'        
    shell:
        'rm -R {input.dir}/plasmid_resequence/;/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/fasta-to-reference {input.contig} {input.dir} {params} --organism Hpylori_plasmid'
		
rule reseq_resequence:
    input:	
        ref = '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/referenceset.xml'		
    output:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/Resequence/tasks/pbcoretools.tasks.gather_alignmentset-1/file.alignmentset.xml'
    params:
        outdir = '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/Resequence',
        dataset = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/file{job}.subreadset.xml', sample = SAMPLE_NAME, job = JOB_NUM)
    threads:
        1
    shell:
        '/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/pbsmrtpipe pipeline-id pbsmrtpipe.pipelines.sa3_ds_resequencing_fat -e eid_ref_dataset:{input.ref} -e eid_subread:{params.dataset} --preset-json=/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/resequence_preset.json --output-dir={params.outdir}'


rule reseq_dataset_consilidate:
    input:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/Resequence/tasks/pbcoretools.tasks.gather_alignmentset-1/file.alignmentset.xml'
    output:
        bam = '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/consolidate_file{job}_alignmentset.bam',
        xml = '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/consolidate_file{job}_alignmentset.xml'        
    shell:
        '/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/dataset consolidate {input} {output.bam} {output.xml}'


rule reseq_whitelist:
    input:
        expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/consolidate_file{job}_alignmentset.bam', sample = SAMPLE_NAME, job = JOB_NUM)
    output:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/alignment_whitelist.txt'
    shell:
        '. /etc/profile.d/modules.sh; module load samtools;'
        'samtools view {input}  | cut -f1 | cut -f2 -d/ | sort | uniq > {output}'
		
		
rule reseq_bamsieve:
    input:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/alignment_whitelist.txt' 
    params: 
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/file{job}.subreadset.xml'	     
    output: 
        xml='/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/file{job}_alignmentset_whitelist.subreadset.xml',
        bam='/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/file{job}_alignmentset_whitelist.subreads.bam'
    shell:
        '. /etc/profile.d/modules.sh; module load python python3;'
        'export PYTHONPATH=/CGF/Resources/PacBio/smrtlink/install/smrtlink-release_5.1.0.26412/bundles/smrttools/install/smrttools-release_5.1.0.26366/private/pacbio/pythonpkgs/pbcommand/lib/python2.7/site-packages/:/DCEG/CGF/Resources/PacBio/smrtlink/install/smrtlink-release_5.1.0.26412/bundles/smrttools/install/smrttools-release_5.1.0.26366/private/pacbio/pythonpkgs/pbcore/lib/python2.7/site-packages/;'
        '/DCEG/CGF/Resources/PacBio/smrtlink/install/smrtlink-release_5.1.0.26412/bundles/smrttools/current/private/otherbins/internalall/bin/bamsieve --whitelist {input} {params} {output.xml}'
		
rule reseq_hgap:
    input:
        expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/file{job}_alignmentset_whitelist.subreadset.xml', sample = SAMPLE_NAME, job = JOB_NUM)
    output:
        assembly = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta', sample = SAMPLE_NAME),
        preadsfasta = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/tasks/falcon_ns2.tasks.task_falcon1_run_db2falcon-0/preads4falcon.fasta', sample = SAMPLE_NAME)
    params: 
        json = config['HGAP_JSON'],    
        outdir = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence', sample = SAMPLE_NAME)
    shell:
        '/CGF/Resources/PacBio/smrtlink/current/bundles/smrttools/smrtcmds/bin/pbsmrtpipe pipeline-id pbsmrtpipe.pipelines.polished_falcon_fat -e eid_subread:{input} --preset-json={params.json} --output-dir={params.outdir}'
		
rule reseq_hgap_circlator:
    input:
        assembly = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/tasks/pbcoretools.tasks.gather_contigset-1/file.contigset.fasta', sample = SAMPLE_NAME),
        preadsfasta = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/tasks/falcon_ns2.tasks.task_falcon1_run_db2falcon-0/preads4falcon.fasta', sample = SAMPLE_NAME)
    output:
        expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/circlator/04.merge.circularise_details.log', sample = SAMPLE_NAME)
    params:
        outdir = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/circlator', sample = SAMPLE_NAME)
#        outdir_final = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid_filter{filterlen}_GL10000/circlator', sample = SAMPLE_NAME, filterlen = FILTER_LENGTH)
    shell:
        '. /etc/profile.d/modules.sh; module load samtools python python3 SPAdes/3.7.1 canu/1.5 bwa/0.7.15 prodigal/2.6.3 MUMmer/3.23;'	
        'rm -R {params.outdir}; circlator all --merge_min_length_merge 1000 {input.assembly} {input.preadsfasta} {params.outdir};'
#        'mv {params.outdir} {params.outdir_final}'

##circlator will error out if output folder is already created and snakemake will automatically create output folder. Has to direct circlator output to another new folder and move it back to the designated snakemake outdir after circlator finish.		
rule reseq_bam2fastq:
    input:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/file{job}_alignmentset_whitelist.subreadset.xml'
    output:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/file{job}_alignmentset_whitelist.subreadset.fasta.gz'   
    params:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/file{job}_alignmentset_whitelist.subreadset'	
    shell:
        '/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/bam2fasta {input} -o {params}'
		
rule reseq_canu:
    input:
        expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/file{job}_alignmentset_whitelist.subreadset.fasta.gz', sample = SAMPLE_NAME, job = JOB_NUM)
    output:
        assembly = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/CANU/canu_reseq.contigs.fasta', sample = SAMPLE_NAME),
        preadsfasta = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/CANU/canu_reseq.trimmedReads.fasta.gz', sample = SAMPLE_NAME)
    params: 
        outprefix = 'canu_reseq',
        outdir = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/CANU', sample = SAMPLE_NAME)
    shell:
        '. /etc/profile.d/modules.sh; module load canu;'
        'canu -p {params.outprefix} -d {params.outdir} genomeSize=10k -pacbio-raw {input} useGrid=false'
		
rule reseq_canu_circlator:
    input:
        assembly = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/CANU/canu_reseq.contigs.fasta', sample = SAMPLE_NAME),
        preadsfasta = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/CANU/canu_reseq.trimmedReads.fasta.gz', sample = SAMPLE_NAME)
    output:
        expand('CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/CANU/circlator/04.merge.circularise_details.log', sample = SAMPLE_NAME)
    params:
        outdir = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/plasmid_resequence/CANU/circlator', sample = SAMPLE_NAME),
#        outdir_final = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid_filter{filterlen}_GL10000/circlator', sample = SAMPLE_NAME, filterlen = FILTER_LENGTH)
    shell:
        '. /etc/profile.d/modules.sh; module load samtools python python3 SPAdes/3.7.1 canu/1.5 bwa/0.7.15 prodigal/2.6.3 MUMmer/3.23;'	
        'rm -R {params.outdir}; circlator all --merge_min_length_merge 1000 {input.assembly} {input.preadsfasta} {params.outdir};'		
