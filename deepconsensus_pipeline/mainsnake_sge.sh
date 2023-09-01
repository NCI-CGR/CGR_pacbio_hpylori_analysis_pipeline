#!/bin/sh

module load bcftools python3/3.7.0 singularity/3.0.1
cd $PWD
DATE=$(date +%y%m%d)
mkdir -p logs_${DATE}
#TMP=/scratch/luow2/annotation_${DATE}/

sing_arg='"'$(echo "--bind /DCEG")'"'
echo $sing_arg

snakemake --cores=1 --unlock --configfile config.yaml 
sbcmd="qsub -cwd -q seq-*.q -pe by_node {threads} -o logs_${DATE}/ -e logs_${DATE}/ -V"
snakemake -pr --use-singularity --singularity-args "--bind /DCEG" --configfile config.yaml --cluster "$sbcmd" --keep-going --rerun-incomplete --jobs 300 --latency-wait 120

