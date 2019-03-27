#!/bin/sh
# properties = {"type": "single", "rule": "fixstart", "local": false, "input": ["/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/POR-005_SC489840_2270/HGAP_run/circlator_2270/00.input_assembly.fasta"], "output": ["/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/POR-005_SC489840_2270/HGAP_run/Resequence/assembly2270.fixstart.fasta"], "wildcards": {}, "params": {"prefix": ["/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/POR-005_SC489840_2270/HGAP_run/Resequence/assembly2270.fixstart"]}, "log": [], "threads": 1, "resources": {}, "jobid": 5, "cluster": {}}
cd /mnt/nfs/gigantor/ifs/DCEG/Home/luow2/20180220_test_hgap_run/reseq_pipeline && \
/DCEG/Resources/Tools/python3/3.6.3-shared/bin/python3.6 \
-m snakemake /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/POR-005_SC489840_2270/HGAP_run/Resequence/assembly2270.fixstart.fasta --snakefile /mnt/nfs/gigantor/ifs/DCEG/Home/luow2/20180220_test_hgap_run/reseq_pipeline/Snakefile \
--force -j --keep-target-files --keep-remote \
--wait-for-files /mnt/nfs/gigantor/ifs/DCEG/Home/luow2/20180220_test_hgap_run/reseq_pipeline/.snakemake/tmp.e3cto_30 /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/POR-005_SC489840_2270/HGAP_run/circlator_2270/00.input_assembly.fasta --latency-wait 120 \
 --attempt 1 --force-use-threads \
--wrapper-prefix https://bitbucket.org/snakemake/snakemake-wrappers/raw/ \
 --config JOB_NUM=2270 SAMPLE_NAME=POR-005_SC489840_2270 -p --nocolor \
--notemp --no-hooks --nolock --mode 2  --allowed-rules fixstart  && touch "/mnt/nfs/gigantor/ifs/DCEG/Home/luow2/20180220_test_hgap_run/reseq_pipeline/.snakemake/tmp.e3cto_30/5.jobfinished" || (touch "/mnt/nfs/gigantor/ifs/DCEG/Home/luow2/20180220_test_hgap_run/reseq_pipeline/.snakemake/tmp.e3cto_30/5.jobfailed"; exit 1)

