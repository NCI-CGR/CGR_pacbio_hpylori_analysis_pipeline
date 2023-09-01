#!/bin/sh

module load python3/3.10.2 singularity slurm

DATE=$(date +%y%m%d)
mkdir -p logs_${DATE}
TMP=/scratch/luow2/annotation_${DATE}/

sing_arg='"'$(echo "--bind /DCEG")'"'
echo $sing_arg

snakemake --cores=1 --unlock --configfile config.yaml 
sbcmd="sbatch --time=48:00:00 --mem=64g --partition=bigmemq --cpus-per-task={threads} --output=logs_${DATE}/snakejob_%j.out"
snakemake -pr --use-singularity --singularity-args "--bind /DCEG" --cluster-config cluster_config.yml --configfile config.yaml --cluster "$sbcmd" --keep-going --rerun-incomplete --jobs 300 --latency-wait 120

