#!/usr/bin/perl -w

use strict;
use Speedy::AQB;
use Speedy::Utils;
use Speedy::Http;
use Data::Dumper;

require "sites.pl";

# delete config cache=off site from cesu result
sub removeCacheOff($)
{
    my $time = shift;
    my $inf = "speed_sort.". $time . ".txt";
    my $outf = "cesu_" . $time . ".result";
    my %rate = (
        'TOTAL' => 0,
        'SLOW' => 0,
        'FAST' => 0,
        'SAME' => 0,
    );

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
            printf(OUTFD $arr[0]."\t".$arr[1]."\n");

            $rate{TOTAL} += 1;
            if ($arr[0] < -0.1) {
                $rate{SLOW} += 1;
            } elsif ($arr[0] > 0.1) {
                $rate{FAST} += 1;
            } else {
                $rate{SAME} += 1;
            }
        }
    }

    $rate{FAST_RATE} = $rate{FAST} * 100 / $rate{TOTAL};
    $rate{FAST_RATE} = sprintf("%.2f", $rate{FAST_RATE});
    $rate{SLOW_RATE} = $rate{SLOW} * 100 / $rate{TOTAL};
    $rate{SLOW_RATE} = sprintf("%.2f", $rate{SLOW_RATE});
    $rate{SAME_RATE} = $rate{SAME} * 100 / $rate{TOTAL};
    $rate{SAME_RATE} = sprintf("%.2f", $rate{SAME_RATE});
    showHash(\%rate);
            
    printf(OUTFD "FAST: $rate{FAST_RATE}\t" . 
        "SLOW: $rate{SLOW_RATE}\t" .
        "SAME: $rate{SAME_RATE}\t" .
        "TOTAL: $rate{TOTAL}\n");
    
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

#isDynPage();

my $time = "2013-03-08~2013-03-09";
removeCacheOff($time);
exit(0);

for (my $i=1; $i<=7; $i++) {
    my $j = $i + 1;
    $time = "2013-03-0$i~2013-03-0$j";
    removeCacheOff($time);
}

1;

