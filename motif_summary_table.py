#!/usr/bin/env python2.7
################
#to create motif summary file of motif hits for every sample
################
#use awk to create motif_list.txt :for i in /DCEG/Projects/DataDelivery/hpylori/*/Delivery/Basecall/motifs.csv;do SAMPLE=$(dirname $i| cut -f6 -d/); awk -F, -v sample=$SAMPLE '{if(NR>1){print sample"\t"$1}}' $i;done>/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/motiff_list.txt
import os
f = open("/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/motiff_list.txt", "r")
motif_col=[]
sample_col=[]
unique_motif=[]
unique_sample=[]
lines=f.readlines()
for x in lines:
    sample_col.append(x.split('\t')[0])
    motif_col.append(x.split('\t')[1].rstrip()) #remove trailing newline

for x in motif_col: 
    # check if exists in unique_list or not 
    if x not in unique_motif: 
        unique_motif.append(x) 

for x in sample_col: 
    # check if exists in unique_list or not 
    if x not in unique_sample: 
        unique_sample.append(x) 


out = open( '/CGF/Bioinformatics/Production/Wen/20180220_test_hgap_run/motif_summary.txt', 'a' )
out.write( '\t' + '\t'.join(str(x) for x in unique_sample) + '\n' )
print( '\t' + '\t'.join(str(x) for x in unique_sample) + '\n' )
list = ['ACNGT', 'GATC']

for x in unique_motif:
    #print x
    Dict = dict(zip(tuple(unique_sample),[0 for item in unique_sample]))
    #print("len of lines = " + str(len(lines)))
    for line in lines:
        (sample, motif) = line.rstrip('\r\n').split('\t')
        #print sample
        if motif == x:
            #motif = {}
            #type(motif)
            #for y in unique_sample:
                if sample in unique_sample:  
                    Dict[sample] = 1
    #print([Dict[item] for item in sorted(Dict.keys())])
    outline = (x + '\t' + '\t'.join([str(Dict[item]) for item in sorted(Dict.keys())]))
    #print(outline)
    out.write( outline + '\n' )
