#!/usr/bin/env python

####
#### DW: April-2017
#### move 12 nt from the end of the genome  
#### to the beginning of the genome
#### in the meantime, reformat the fasta file
#### also, put seq length in header for verification 
####

####
#### Usage: python ./fixformat.py file.fasta 60 > file.fix.fasta
#### 
####

import os
import sys

f = open(sys.argv[1],'rU')
header = f.readline()
header = header.rstrip(os.linesep)
sequence=''
for line in f:
  line = line.rstrip('\n')
  if(line[0] == '>'):
    header = header[1:]
    header = line
    print (header, len(sequence))
    sequence = ''
  else:
    sequence += line

## cut the last 12 letters and put it at the beginning 
fseq = sequence[-12:]+sequence[:-12]

flen=sys.argv[2]

## print with no space
print(header,"|len=",len(sequence),sep='')
#print header
for i in range(0, len(fseq), int(flen)):
    print (fseq[i:i+int(flen)])
