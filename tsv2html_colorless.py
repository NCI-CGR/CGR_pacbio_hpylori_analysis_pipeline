#!/usr/bin/python
# python ${DIRNAME}/tsv2html_colorless.py ${RESULTS_DIR}/coverage_summary.xls ${RESULTS_DIR}/coverage_summary.txt
# Author: Xijun Zhang
# Email: zhangx7@mail.nih.gov

from __future__ import division
import sys

def main():
  (tsv_file, html_file) = sys.argv[1:3]
  tsv = open(tsv_file, 'r')
  html = open(html_file, 'w')
  html.write("<table border=1>")
  for line in tsv:
    html.write("<tr>")
    for i in line.split("\t"):
      html.write("<td>" + str(i) + "</td>")
    html.write("</tr>")
  html.write("</table>")
  html.close()
  tsv.close()

if __name__=='__main__':
  main()
  
