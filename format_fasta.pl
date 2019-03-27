#!/usr/bin/perl
#
$in_fasta = $ARGV[0];
$out_fasta = $ARGV[1];

use Bio::SeqIO;
$in  = Bio::SeqIO->new(-file => "$in_fasta",
                       -format => 'Fasta');
$out = Bio::SeqIO->new(-file => ">$out_fasta",
                       -format => 'Fasta');
while ( my $seq = $in->next_seq() ) {$out->write_seq($seq); }
