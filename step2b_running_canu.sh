#!/bin/bash
module load canu

SUBREADS=$1
NAME=$(basename $SUBREADS .subreadset.xml)
mkdir -p /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/${NAME}/canu

CMD="/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/dataset filter $SUBREADS /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/${NAME}/${NAME}_filtered.subreadset.xml filters 'bq>=45 rq>=0.7' " 

#echo $CMD
#eval $CMD


CMD="/DCEG/CGF/Resources/PacBio/smrtlink/smrtcmds/bin/bam2fasta $SUBREADS -o /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/${NAME}/${NAME}.subreadset"
echo $CMD
eval $CMD

CMD="canu -d /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/${NAME}/canu -p ${NAME}_filtered genomeSize=1.6M -pacbio-raw /CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/${NAME}/${NAME}.subreadset.fasta.gz useGrid=false"

echo $CMD
eval $CMD

