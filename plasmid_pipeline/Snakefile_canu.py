#!/usr/bin/python
import glob
import sys
import os

configfile: "config.yaml"

SAMPLE_NAME = config['SAMPLE_NAME']
FILTER_LENGTH = config['FILTER_LENGTH']
JOB_NUM = config['JOB_NUM']

rule all:
    input:
        expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/CANU_filter{filterlen}_GL10000/circlator/04.merge.circularise_details.log', sample = SAMPLE_NAME, filterlen = FILTER_LENGTH),

rule canu_blasr:
    input:
        assembly = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/file.contigset_chromosomal.fasta', sample = SAMPLE_NAME), 
        filefasta = expand('/CGF/Resources/PacBio/jobs/001/00{job}/tasks/pbcoretools.tasks.gather_fasta-1/file.fasta', job = JOB_NUM)
    output:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/chromosomal_{job}_zmw.txt'
    shell:
        '/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/blasr {input.filefasta} {input.assembly} > {output}'
		
rule canu_blacklist:
    input:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/chromosomal_{job}_zmw.txt'
    output:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/chromosomal_{job}_zmw_blacklist.txt'
    run:
        with open(output[0], 'w') as out:
            with open(input[0]) as f:
                list=[]
                lines=f.readlines()
                for x in lines:
                    list.append(x.split('/')[1])
                    set(list)
                    f.close()			
                for i in list:
                    out.write("%s\n" % i)

rule canu_bamsieve:
    input:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/chromosomal_{job}_zmw_blacklist.txt' 
    params: 
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/file{job}.subreadset.xml'	     
    output: 
        xml='/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal.subreadset.xml',
        bam='/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal.subreads.bam'
    shell:
        '. /etc/profile.d/modules.sh; module load python python3;'
        'export PYTHONPATH=/CGF/Resources/PacBio/smrtlink/install/smrtlink-release_5.1.0.26412/bundles/smrttools/install/smrttools-release_5.1.0.26366/private/pacbio/pythonpkgs/pbcommand/lib/python2.7/site-packages/:/DCEG/CGF/Resources/PacBio/smrtlink/install/smrtlink-release_5.1.0.26412/bundles/smrttools/install/smrttools-release_5.1.0.26366/private/pacbio/pythonpkgs/pbcore/lib/python2.7/site-packages/;'
        '/DCEG/CGF/Resources/PacBio/smrtlink/install/smrtlink-release_5.1.0.26412/bundles/smrttools/current/private/otherbins/internalall/bin/bamsieve --blacklist {input} {params} {output.xml}'
		
rule canu_filter:
    input:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal.subreads.bam'
    output:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal_filter{filterlen}.subreads.bam'
    shell:
        '/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/bamtools filter -length "<{wildcards.filterlen}" -in {input} -out {output}'
		
rule canu_index:
    input:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal_filter{filterlen}.subreads.bam'
    output:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal_filter{filterlen}.subreads.bam.pbi'
    shell:
        '/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/pbindex {input}'

rule canu_dataset_create:
    input:
        inbam = '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal_filter{filterlen}.subreads.bam',
        index = '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal_filter{filterlen}.subreads.bam.pbi'
    output:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal_created_filter{filterlen}.subreadset.xml'        
    shell:
        '/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/dataset create --name bamsieve_file{wildcards.job}_nonchromosomal_created_filter{wildcards.filterlen} --type SubreadSet {output} {input.inbam}'
		
rule canu_dataset2fastq:
    input:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal_created_filter{filterlen}.subreadset.xml'
    output:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal_created_filter{filterlen}.subreadset.fasta.gz'   
    params:
        '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal_created_filter{filterlen}.subreadset'	
    shell:
        '/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/bam2fasta {input} -o {params}'

rule canu:
    input:
        expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/bamsieve_file{job}_nonchromosomal_created_filter{filterlen}.subreadset.fasta.gz', sample = SAMPLE_NAME, job = JOB_NUM, filterlen = FILTER_LENGTH)
    output:
        assembly = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/CANU_filter{filterlen}_GL10000/canu_filter{filterlen}_GL10000.contigs.fasta', sample = SAMPLE_NAME, filterlen = FILTER_LENGTH),
        preadsfasta = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/CANU_filter{filterlen}_GL10000/canu_filter{filterlen}_GL10000.trimmedReads.fasta.gz', sample = SAMPLE_NAME, filterlen = FILTER_LENGTH)
    params: 
        outprefix = expand('canu_filter{filterlen}_GL10000', filterlen = FILTER_LENGTH),
        outdir = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/CANU_filter{filterlen}_GL10000', sample = SAMPLE_NAME, filterlen = FILTER_LENGTH)
    shell:
        '. /etc/profile.d/modules.sh; module load canu;'
        'canu -p {params.outprefix} -d {params.outdir} genomeSize=10k -pacbio-raw {input} useGrid=false'
		
rule canu_circlator:
    input:
        assembly = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/CANU_filter{filterlen}_GL10000/canu_filter{filterlen}_GL10000.contigs.fasta', sample = SAMPLE_NAME, filterlen = FILTER_LENGTH),
        preadsfasta = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/CANU_filter{filterlen}_GL10000/canu_filter{filterlen}_GL10000.trimmedReads.fasta.gz', sample = SAMPLE_NAME, filterlen = FILTER_LENGTH)
    output:
        expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/CANU_filter{filterlen}_GL10000/circlator/04.merge.circularise_details.log', sample = SAMPLE_NAME, filterlen = FILTER_LENGTH)
    params:
        outdir = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/CANU_filter{filterlen}_GL10000/circlator', sample = SAMPLE_NAME, filterlen = FILTER_LENGTH),
#        outdir_final = expand('/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/plasmid_test/{sample}_plasmid/HGAP_filter{filterlen}_GL10000/circlator', sample = SAMPLE_NAME, filterlen = FILTER_LENGTH)
    shell:
        '. /etc/profile.d/modules.sh; module load samtools python python3 SPAdes/3.7.1 canu/1.5 bwa/0.7.15 prodigal/2.6.3 MUMmer/3.23;'	
        'rm -R {params.outdir}; circlator all --merge_min_length_merge 1000 {input.assembly} {input.preadsfasta} {params.outdir};'
#        'mv {params.outdir} {params.outdir_final}'

##circlator will error out if output folder is already created and snakemake will automatically create output folder. Has to direct circlator output to another new folder and move it back to the designated snakemake outdir after circlator finish.		
		
		
