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
        'BIGZERO' => 0,
        'ZIP' => 0,
    );

    open(INFD, $inf);
    open(OUTFD, ">" . $outf);

    while (<INFD>)
    {
        my @arr = split(/ /, $_);
        removeRN(\$arr[1]);

        my $site = getSiteInfo($arr[1]);
        if (((exists($site->{config}->{cache})) && ($site->{config}->{cache} eq "on")) ||
            ((exists($site->{config}->{cachesize})) && ($site->{config}->{cachesize} > 0))) 
        {
            my $sched = getScheduleInfo($site->{id});
            if (getHashLen($sched) > 3) {
                printf(OUTFD $arr[0]."\t".$arr[1]."\n");

                $rate{TOTAL} += 1;
                if ($arr[0] < -10) {
                    $rate{SLOW} += 1;
                } elsif ($arr[0] > 10) {
                    $rate{FAST} += 1;
                } else {
                    $rate{SAME} += 1;
                }

                if ($arr[0] > 0) {
                    $rate{BIGZERO} += 1;
                    $rate{BIGZERO_CNT} += $arr[0];
                }
           } else {
               printf("### OUT site: %s\n", $arr[1]);
           }

        } else {
            printf("### Cache Off: %s\n", $arr[1]);
        }

#=pod
        if ((exists($site->{config}->{zip})) &&
            ($site->{config}->{zip} eq "on")) 
        {
            $rate{ZIP} += 1;
            printf("\t\"$arr[1]\",\n");
        }
#=cut
    }

    $rate{FAST_RATE} = $rate{FAST} * 100 / $rate{TOTAL};
    $rate{FAST_RATE} = roundFloat($rate{FAST_RATE});
    $rate{SLOW_RATE} = $rate{SLOW} * 100 / $rate{TOTAL};
    $rate{SLOW_RATE} = roundFloat($rate{SLOW_RATE});
    $rate{SAME_RATE} = $rate{SAME} * 100 / $rate{TOTAL};
    $rate{SAME_RATE} = roundFloat($rate{SAME_RATE});
    $rate{BIGZ_RATE} = $rate{BIGZERO} * 100 / $rate{TOTAL};
    $rate{BIGZ_RATE} = roundFloat($rate{BIGZ_RATE});
    $rate{FAST_AVG}  = $rate{BIGZERO_CNT} / $rate{BIGZERO};
    $rate{FAST_AVG}  = roundFloat($rate{FAST_AVG});
    showHash(\%rate);

    printf(OUTFD "FAST: $rate{FAST_RATE}\t" . 
        "SLOW: $rate{SLOW_RATE}\t" .
        "SAME: $rate{SAME_RATE}\t" .
        "BIGZ: $rate{BIGZ_RATE}\t" .
        "FAVG: $rate{FAST_AVG}\t" .
        "ZIP: $rate{ZIP}\t" .
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
        my $downsize = $httpinfo->{SIZE_DOWNLOAD} / 1000;

        if ($dynpage > 0) {
            printf("DYN_PAGE\tR$dynpage\t$downsize\n");
        } else {
            printf("STATIC_PAGE\tR$dynpage\t$downsize\n");
        }

        $|++;
    }
}

#isDynPage();exit(0);

my $time = "2013-03-21~2013-03-22";
removeCacheOff($time);
exit(0);

my $tbegin = "";
my $tend = "";
for (my $i=9; $i<=13; $i++) {
    my $j = $i + 1;
    if ($i > 9) {
        $tbegin = "2013-03-$i";
    } else {
        $tbegin = "2013-03-0$i";
    }

    if ($j > 9) {
        $tend = "2013-03-$j";
    } else {
        $tend = "2013-03-0$j";
    }

    $time = $tbegin . "~" . $tend;
    printf("### analysis $time ###\n");
    removeCacheOff($time);
}

1;
