#!/usr/bin/perl -w

use strict;
use 5.010;
use Speedy::AQB;
use Speedy::Utils;
use Data::Dumper;
use BMD::DBH;

my $keyword = "total_time";
my $date = `date -d "last day" +"%Y-%m-%d"`;#"2013-05-05";

my $site_rate_href = ();
my $dbh;
my $do_db = 1;

# delete config cache=off site from cesu result
sub speed_rate($)
{
    my $date = shift;
    my $outf = "cesu_" . $date . ".txt";
    my %rate = (
        'TOTAL' => 0,
        'SLOW' => 0,
        'FAST' => 0,
        'SAME' => 0,
        'BIGZERO' => 0,
        'LESSZERO' => 0,
        'ZIP' => 0,
    );

    open(OUTFD, ">" . "history_data/" . $outf);

    foreach my $key (sort {$site_rate_href->{$a} <=> $site_rate_href->{$b}} keys %$site_rate_href) 
    {
        # 0 - rate; 1 - site;
        my @arr = ($site_rate_href->{$key}, $key);
        $arr[0] = roundFloat($arr[0]);
        removeRN(\$arr[1]);

        my $site = getSiteInfo($arr[1]);
        if (((exists($site->{config}->{cache})) && ($site->{config}->{cache} eq "on")) || 
            ((exists($site->{config}->{page_speed_up})) && ($site->{config}->{page_speed_up} eq "on")))
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
                } else {
                    $rate{LESSZERO} += 1;
                    $rate{LESSZERO_CNT} += $arr[0];
                }

                my $sdata = {
                    site => $arr[1],
                    rate => $arr[0],
                    cachehit => 0,
                    time => "$date 00:00:00",
                };
                $dbh->insert('site_cesu_daily', $sdata) if $do_db;
            } else {
               #printf("### OUT site: %s\n", $arr[1]);
           }

        } else {
            #printf("### Cache Off: %s\n", $arr[1]);
        }

#=pod
        if ((exists($site->{config}->{zip})) &&
            ($site->{config}->{zip} eq "on")) 
        {
            $rate{ZIP} += 1;
            #printf("\t\"$arr[1]\",\n");
        }
#=cut
                
        # calculate all site rate
        $rate{ALL_TOTAL} += 1;
        if ($arr[0] > 0) {
            $rate{ALL_BIGZERO} += 1;
            $rate{ALL_BIGZERO_CNT} += $arr[0];
        }
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
    $rate{SLOW_AVG}  = $rate{LESSZERO_CNT} / $rate{LESSZERO};
    $rate{SLOW_AVG}  = roundFloat($rate{SLOW_AVG});
    $rate{ALLBIGZ_RATE} = $rate{ALL_BIGZERO} * 100 / $rate{ALL_TOTAL};
    $rate{ALLBIGZ_RATE} = roundFloat($rate{ALLBIGZ_RATE});
    $rate{ALLFAST_AVG}  = $rate{ALL_BIGZERO_CNT} / $rate{ALL_BIGZERO};
    $rate{ALLFAST_AVG}  = roundFloat($rate{ALLFAST_AVG});
    showHash(\%rate);

    printf(OUTFD "FAST: $rate{FAST_RATE}\t" . 
        "SLOW: $rate{SLOW_RATE}\t" .
        "SAME: $rate{SAME_RATE}\t" .
        "BIGZ: $rate{BIGZ_RATE}\t" .
        "FASTAVG: $rate{FAST_AVG}\t" .
        "SLOWAVG: $rate{SLOW_AVG}\t" .
        #"ZIP: $rate{ZIP}\t" .
        "TOTAL: $rate{TOTAL}\t" .
        "ALLBIGZ_RATE: $rate{ALLBIGZ_RATE}\t" . 
        "ALLFAST_AVG: $rate{ALLFAST_AVG}\t" . 
        "ALL_TOTAL: $rate{ALL_TOTAL}\n");
    
    close(OUTFD);

    my $data = {
        bigzero => $rate{BIGZ_RATE},
        fast => $rate{FAST_RATE},
        slow => $rate{SLOW_RATE},
        same => $rate{SAME_RATE},
        fastavg => $rate{FAST_AVG},
        slowavg => $rate{SLOW_AVG},
        total => $rate{TOTAL},
        all_bigzero => $rate{ALLBIGZ_RATE},
        all_fastavg => $rate{ALLFAST_AVG},
        all_total => $rate{ALL_TOTAL},
        time => "$date 00:00:00",
    };
    $dbh->insert('cesu_daily', $data) if $do_db;
}

sub speed_rate_range()
{
    my $tbegin = "";
    my $tend = "";
    my $time = "";
    for (my $i=11; $i<=17; $i++) {
        my $j = $i + 1;
        if ($i > 9) {
            $tbegin = "2013-04-$i";
        } else {
            $tbegin = "2013-04-0$i";
        }

        if ($j > 9) {
            $tend = "2013-04-$j";
        } else {
            $tend = "2013-04-0$j";
        }

        $time = $tbegin . "~" . $tend;
        printf("### analysis $time ###\n");
        speed_rate($time);
    }
}


use constant {ORG=>0, AQB=>1, DNS=>2};

#my $mysql_comm = 'mysql -h116.213.78.228 -ucesureadonly -p66ecf9c968132321a02e6e7aff34ce5d -P3306 -Dspeed -B -N -e ';
#my $mysql_comm = 'mysql -h59.151.123.74 -ucesu_readonly -p\'Speed@)!@readonly\' -P3307 -Dspeed -B -N -e ';
my $detail_href = {};
sub sort_db_speed(;$$)
{
    my ($keyword, $date) = @_;
    my $sql;
    my $city_sql = "";

    # org
    $sql = qq/select role_id, role_name, round(avg($keyword),4) as a from speed_monitor_data where role_name like "%_ip" and monitor_time >= "$date 00:00:00" and monitor_time <= "$date 23:59:59" and total_time != 0 and error_id=0 and role_ip!="0.0.0.0" $city_sql group by role_id having count(*) > 5 order by a/;
    printf("%s\n", $sql);
    fetch_data($dbh->query($sql), ORG);

    # aqb
    $sql = qq/select role_id, role_name, round(avg($keyword),4) as a from speed_monitor_data where role_name like "%_aqb" and monitor_time >= "$date 00:00:00" and monitor_time <= "$date 23:59:59" and total_time != 0 and error_id=0 and role_ip!="0.0.0.0" $city_sql group by role_id having count(*) > 5 order by a/;
    printf("%s\n", $sql);
    fetch_data($dbh->query($sql), AQB);

    # dns
    $sql = qq/select role_id, role_name, round(avg(dns_time),4) as a from speed_monitor_data where role_name like "%_aqb" and monitor_time > "$date 00:00:00" and monitor_time <= "$date 23:59:59" and total_time != 0 and error_id=0 and role_ip!="0.0.0.0" $city_sql group by role_id having count(*) > 5 order by a/;
    printf("%s\n", $sql);
    fetch_data($dbh->query($sql), DNS);

    # debug
    #print Dumper($detail_href);

    # begin to statistic
    final_stat($keyword);

    return 1;
}

use constant {ROLE_ID=>0, ROLE_NAME=>1, SPEED=>2}; 
sub fetch_data($$)
{
    my ($data_aref, $type) = @_;

    for (my $i = 0; $i <= $#$data_aref; $i++) {
        my $site = get_site_name($data_aref->[$i]->[ROLE_NAME]);
        $detail_href->{$site}{$type}{'speed'} = $data_aref->[$i]->[SPEED];
    }
}

sub final_stat($)
{
    my $keyword = shift;
    my $cnt_hash = {};

    #open my $result_file, '>', "./speed_result.$date.txt" or die "can't open file : $!";

    my @sorted_sites = sort { $a cmp $b } keys %$detail_href;
    foreach my $site (@sorted_sites)
    {
        if (exists $detail_href->{$site}{&ORG} &&
            exists $detail_href->{$site}{&AQB} &&
            exists $detail_href->{$site}{&DNS})
        {
            if ($detail_href->{$site}{&ORG}{'speed'} == 0 || $detail_href->{$site}{&AQB}{'speed'} == 0 ) {
                next;
            }

            my $org = $detail_href->{$site}{&ORG}{'speed'} + $detail_href->{$site}{&DNS}{'speed'};
            my $aqb = $detail_href->{$site}{&AQB}{'speed'};

            my $divby = ($org > $aqb) ? $aqb : $org;
            my $rate = ($org - $aqb) * 100 / $divby;

            if ($rate > 0) {
                $cnt_hash->{'above'}++;
            } else {
                $cnt_hash->{'below'}++;
            }

            #printf($result_file "%-20s  %.2f\n", $site, $rate);
            $site_rate_href->{$site} = $rate;
        }
    }

    #close($result_file);

    say "\e[1;31mresult for $keyword\e[0m";
    say "above: $cnt_hash->{'above'}";
    say "below: $cnt_hash->{'below'}";
}

sub get_site_name($)
{
    my $name = shift;
    return substr($name, 0, (index $name, "_"));
}

#
# begin to run
#
$dbh = BMD::DBH->new(
    'dbhost' => '116.213.78.228',
    'dbuser' => 'cesutest',
    'dbpass' => 'cesutest',
    #'dbuser' => 'cesureadonly',
    #'dbpass' => '66ecf9c968132321a02e6e7aff34ce5d',
    'dbname' => 'speed',
    'dbport' => 3306
);

# analysis bonree cesu data
sort_db_speed($keyword, $date);

# calculata speed rate
speed_rate($date);

$dbh->fini();

1;

# vim: ts=4:sw=4:et

