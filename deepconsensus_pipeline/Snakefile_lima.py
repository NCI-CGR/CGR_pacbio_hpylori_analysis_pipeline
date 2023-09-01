#!/usr/bin/python
import glob
import sys
import os
#configfile: "config.yaml"

manifestFile = config['manifest']

SAMPLES = []
BARCODES= []
SampDict = {}
ReverseSampDict={}
dir= config['DIR'].rstrip('/') + '/'
Smrtcmds= config['smrtcomds'].rstrip('/') + '/'
model= config['model']
outName = os.path.splitext(os.path.basename(manifestFile))[0]

with open(manifestFile) as f:
    next(f)
    for line in f:
        (vial, cgrid, jobid, barcode) = [line.split()[i] for i in [0,1,2,4]]
        sample = vial + "_" + cgrid + "_" + jobid
        SAMPLES.append(sample)
        SampDict[sample] = barcode
        BARCODES.append(barcode)
        ReverseSampDict[barcode]=sample

def get_subreads(wildcards):
    (file) = SampDict[wildcards.sample]
    return file

print(SAMPLES)
print(SampDict)
print(ReverseSampDict)
print(BARCODES)
rule all:
    input:
        lambda wildcards: expand(dir + '{sample}/deepconsensus/circlator/05.clean.fasta', sample=SAMPLES)

rule demultiplx:
    input:
        subreads = config['subreads'],
        barcode = config['barcodes']
    output:
        report = dir + outName + '.xml.lima.report',
        bam = expand(dir + outName + '.xml.' + "{barcode}" + '--' + "{barcode}"+ '.bam',barcode=BARCODES) 
        #lambda wildcards: [dir + '/' + outName + '.xml.' + SampDict[item] + '--' + SampDict[item] + '.bam' for item in SampDict.keys()] #Only input files can be specified as functions
    params:
        out = dir + '/' + outName + '.xml',
        bin = Smrtcmds,
    shell:
        '{params.bin}/lima  --split-bam-named  --same --ignore-missing-adapters {input.subreads} {input.barcode} {params.out}' 
               
rule run_ccs:
    input:
        #get_subreads
        report = dir + '/' + outName + '.xml.lima.report',  
        subreads = lambda wildcards: [dir + outName + '.xml.' + SampDict[wildcards.sample] + '--' + SampDict[wildcards.sample] + '.bam']
    output:
        dir + '{sample}/deepconsensus/{sample}_ccs.bam'
    params:
        Smrtcmds
#    resources: 
 #       tmpdir=dir + '{sample}/deepconsensus/'
    shell:
        '{params}/ccs --min-rq=0.88 {input} {output}'

rule run_actc:
    input:
        ccs = dir + '{sample}/deepconsensus/{sample}_ccs.bam',
        #subreads = get_subreads
        subreads = lambda wildcards: [dir + outName + '.xml.' + SampDict[wildcards.sample] + '--' + SampDict[wildcards.sample] + '.bam']
    output:
        dir + '{sample}/deepconsensus/{sample}_subreads-to-ccs.bam'
    #conda: "env.yml"
    shell:
        '/home/luow2/.conda/envs/pacbio/bin/actc -j 4 {input.subreads} {input.ccs} {output}'

rule run_deepconsensus:
    input:
        ccs = dir + '{sample}/deepconsensus/{sample}_ccs.bam',
        mapped = dir + '{sample}/deepconsensus/{sample}_subreads-to-ccs.bam'
    output:
        dir + '{sample}/deepconsensus/{sample}_deepconsensus.fastq'
    singularity: "docker://google/deepconsensus:1.1.0"    
    params:
        model
    threads:
        10
    shell:
        'deepconsensus run  --subreads_to_ccs={input.mapped} --ccs_bam={input.ccs} --checkpoint={params} --output={output} --cpus=4'

rule run_hifiasm:
    input:
        dir + '{sample}/deepconsensus/{sample}_deepconsensus.fastq'
    output:
        dir + '{sample}/deepconsensus/hifiasm_out/{sample}_deepconsensus.asm.fasta'
    params:
        module = '. /etc/profile.d/modules.sh'        
    threads: 2
    shell:
        '{params.module};. ./global_bash_config.rc;'
        'run_hifiasm_general {input}'

rule run_circlator:
    input:
        contig = dir + '{sample}/deepconsensus/hifiasm_out/{sample}_deepconsensus.asm.fasta',    
        ccs = dir + '{sample}/deepconsensus/{sample}_deepconsensus.fastq'
    output:
        fasta = dir + '{sample}/deepconsensus/circlator/05.clean.fasta'
    params:    
        dir =  dir + '{sample}/deepconsensus/circlator/',
        module = '. /etc/profile.d/modules.sh'                
    shell:
        '{params.module};. ./global_bash_config.rc;'
        'run_circlator {input.contig} {input.ccs} {params.dir}'


        
#/DCEG/CGF/Resources/PacBio/smrtlink/current/smrtcmds/bin/ccs --min-rq=0.88 /DCEG/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/USA-435_SC762111_10102/USA-435_SC762111_bc1059.bam /DCEG/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/USA-435_SC762111_10102/USA-435_SC762111_ccs.bam
#conda activate pacbio
# actc -j 4 /DCEG/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/USA-435_SC762111_10102/USA-435_SC762111_bc1059.bam /DCEG/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/USA-435_SC762111_10102/USA-435_SC762111_ccs.bam /DCEG/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/USA-435_SC762111_10102/USA-435_SC762111_subreads-to-ccs.bam

#deepconsensus
#singularity shell --bind /DCEG docker://google/deepconsensus:1.1.0
#Singularity> deepconsensus run  --subreads_to_ccs=/DCEG/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/USA-435_SC762111_10102/USA-435_SC762111_subreads-to-ccs.bam --ccs_bam=/DCEG/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/USA-435_SC762111_10102/USA-435_SC762111_ccs.bam --checkpoint=/DCEG/CGF/Bioinformatics/Production/Wen/git/deepconsensus/deepconsensus_quick_start/model/checkpoint  --output=/DCEG/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/USA-435_SC762111_10102/USA-435_SC762111_deepconsensus.fastq

#run_hifiasm_general /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/USA-435_SC762111_10102/USA-435_SC762111_deepconsensus.fastq

#conda

