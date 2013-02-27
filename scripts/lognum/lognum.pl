#!/usr/bin/perl

use strict;
use DBI;
use Benchmark;
use Getopt::Std;
use Data::Dumper;

my $logdate = "20130216";
my $cnt = 0;
my $lognum_file = "lognum_" . $logdate . ".result";
my $speedsite_file = "speedsite_" . $logdate . ".result";

my $reg = qr/(\d*?)\s+access_(.*?)_.*$/;

open(FILEINPUT, "<$lognum_file") or do_exit("Can not open file $lognum_file!");
open(FILEOUTPUT, ">$speedsite_file") or do_exit("Can not open file $speedsite_file!");

printf(FILEOUTPUT "\$xx = {\n");
LOOP: while (<FILEINPUT>) {
    my @line = ($_ =~ m/$reg/);
    if ($#line > 0) {
        if ($line[0] <= 10000) {
            last LOOP;
        } else {
            printf(FILEOUTPUT "    \'$line[1]\' => 1,\t\t\t\#$line[0]\n");
        }
    }
    $cnt += 1;
}
printf(FILEOUTPUT "};\n\n");

close(FILEINPUT);
close(FILEOUTPUT);

