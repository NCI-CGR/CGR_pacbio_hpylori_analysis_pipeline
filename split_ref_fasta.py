#!/usr/bin/env python
import sys
import os.path

inFasta = sys.argv[1]
outDir = sys.argv[2]

f=open(inFasta,"r");
opened = False
for line in f :
    if(line[0] == ">") :
        if(opened) :
            of.close()
        opened = True
        outName = os.path.join(outDir, line[1:].rstrip()+".fa") 
        of=open(outName, "w")
        print(line[1:].rstrip())
    of.write(line)
of.close()