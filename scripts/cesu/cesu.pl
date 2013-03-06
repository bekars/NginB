#!/usr/bin/perl -w

use strict;
use Speedy::AQB;
use Speedy::Utils;
use Speedy::Http;
use Data::Dumper;

require "sites.pl";

# delete config cache=off site from cesu result
sub removeCacheOff()
{
    my $inf = "/home/baiyu/Dropbox/Cesu/results/speed_sort.2013-03-02~2013-03-03.txt";
    my $outf = "cesu.result";

    open(INFD, $inf);
    open(OUTFD, ">" . $outf);

    while (<INFD>)
    {
        my @arr = split(/ /, $_);
        removeRN(\$arr[1]);

        my $site = getSiteInfo($arr[1]);
        if ((!exists($site->{config}->{cache})) ||
            (exists($site->{config}->{cache}) && ($site->{config}->{cache} eq "on"))) 
        {
            printf($arr[0]."\t".$arr[1]."\n");
        }
    }

    close(INFD);
    close(OUTFD);
}

# mainpage is dyn-page ?
sub isDynPage
{
    my $sites = $cesusites::sites;
    foreach my $key (sort keys %$cesusites::sites) {
        printf("$key\t");
        my $httpinfo = getHttpInfo($key);
        my $dynpage = checkDynPage($httpinfo);

        if ($dynpage > 0) {
            printf("DYN_PAGE\tR$dynpage\n");
        } else {
            printf("STATIC_PAGE\tR$dynpage\n");
        }

        $|++;
    }
}

isDynPage();

1;

