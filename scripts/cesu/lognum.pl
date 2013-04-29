#!/usr/bin/perl

use strict;
use DBI;
use Benchmark;
use Getopt::Std;
use Data::Dumper;
use Speedy::Http;
use Speedy::Utils;
use Speedy::AQB;
use IO::Handle;

my $logdate = "20130406";
my $cnt = 0;
my $lognum_file = "lognum_" . $logdate . ".result";
my $speedsite_file = "speedsite_" . $logdate . ".result";

my $reg = qr/(\d*?)\s+access_(.*?)_.*$/;

open(FILEINPUT, "<$lognum_file") or do_exit("Can not open file $lognum_file!");
open(FILEOUTPUT, ">$speedsite_file") or do_exit("Can not open file $speedsite_file!");
FILEOUTPUT->autoflush(1);

printf(FILEOUTPUT "\$cesu_sites = {\n");
LOOP: while (<FILEINPUT>) {
    my @line = ($_ =~ m/$reg/);
    if ($#line > 0) {
        $|++;
        if ($line[0] <= 10000) {
            last LOOP;
        } else {
            if ($line[1] =~ m/\*\.(.*)/) {
                $line[1] = $1;
            }
            $line[1] =~ tr/\r//d;
            $line[1] =~ tr/\n//d;

            printf("### Get $line[1] Http Info ... ###\n");
            my $httpinfo = getHttpInfo($line[1]);
            my $siteinfo = getSiteInfo($line[1]);
            #showHash($httpinfo, "HINFO_$line[1]");
            if (($httpinfo->{HTTP_CODE} == 200) &&
                ($httpinfo->{SIZE_DOWNLOAD} > 1000 ))
            {
                if (($siteinfo->{config}->{cache} eq "on") ||
                    ($siteinfo->{config}->{page_speed_up} eq "on")) {
                    printf(FILEOUTPUT "    \'$line[1]\' => 1,\t\t\t\#$line[0]\n");
                } else {
                    printf(FILEOUTPUT "    \'$line[1]\' => 1,\t\t\t\#$line[0] NOCACHE\n");
                }
            } else {
                printf(FILEOUTPUT "    \#NOSITE \'$line[1]\' => 1,\t\t\t\#$line[0]\n");
            }
        }
    }
    $cnt += 1;
}
printf(FILEOUTPUT "};\n\n");

close(FILEINPUT);
close(FILEOUTPUT);

