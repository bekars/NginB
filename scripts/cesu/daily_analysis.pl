#!/usr/bin/perl -w

use strict;
use 5.010;
use Speedy::AQB;
use Speedy::Utils;
use Speedy::Http;
use Data::Dumper;
use BMD::DBH;
use Time::Interval;

my $keyword = "total_time";
my $date = "2013-05-03";

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
    
        my $sdata = {
            site => $arr[1],
            rate => $arr[0],
            cachehit => 0,
            time => "$date 00:00:00",
        };
        
        #$dbh->insert('site_cesu_daily', $sdata) if $do_db;
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
    #$dbh->insert('cesu_daily', $data) if $do_db;
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
    my $city_sql = "and city_code=1100501";
    my $start = 10;
    my $end = $start+13;
    # org
    $sql = qq/select role_id, role_name, round(avg($keyword),4) as a from speed_monitor_data where role_name like "%_ip" and monitor_time >= "$date $start:00:00" and monitor_time <= "$date $end:00:00" and total_time != 0 and error_id=0 $city_sql group by role_id order by a/;
    printf("%s\n", $sql);
    fetch_data($dbh->query($sql), ORG);

    # aqb
    $sql = qq/select role_id, role_name, round(avg($keyword),4) as a from speed_monitor_data where role_name like "%_aqb" and monitor_time >= "$date $start:00:00" and monitor_time <= "$date $end:00:00" and total_time != 0 and error_id=0 $city_sql group by role_id order by a/;
    printf("%s\n", $sql);
    fetch_data($dbh->query($sql), AQB);

    # dns
    $sql = qq/select role_id, role_name, round(avg(dns_time),4) as a from speed_monitor_data where role_name like "%_aqb" and monitor_time > "$date $start:00:00" and monitor_time <= "$date $end:00:00" and total_time != 0 and error_id=0 $city_sql group by role_id order by a/;
    printf("%s\n", $sql);
    fetch_data($dbh->query($sql), DNS);
=pod
    # org
    $sql = qq/select role_id, role_name, round(avg($keyword),4) as a from speed_monitor_data where role_name like "%_ip" and monitor_time >= "$date 00:00:00" and monitor_time <= "$date 23:59:59" and total_time != 0 and error_id=0 $city_sql group by role_id having count(*) > 5 order by a/;
    fetch_data($dbh->query($sql), ORG);

    # aqb
    $sql = qq/select role_id, role_name, round(avg($keyword),4) as a from speed_monitor_data where role_name like "%_aqb" and monitor_time >= "$date 00:00:00" and monitor_time <= "$date 23:59:59" and total_time != 0 and error_id=0 $city_sql group by role_id having count(*) > 5 order by a/;
    fetch_data($dbh->query($sql), AQB);

    # dns
    $sql = qq/select role_id, role_name, round(avg(dns_time),4) as a from speed_monitor_data where role_name like "%_aqb" and monitor_time > "$date 00:00:00" and monitor_time <= "$date 23:59:59" and total_time != 0 and error_id=0 $city_sql group by role_id having count(*) > 5 order by a/;
    fetch_data($dbh->query($sql), DNS);
=cut

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


my $city_code = {
    1100201 => "shanghai",
    1101701 => "nanjing",
    1101601 => "hangzhou",
    1100101 => "beijing",
    1100501 => "guangzhou",
};

my $clock = {
    10 => 11,
    12 => 13,
    14 => 15,
    16 => 17,
    18 => 19,
    20 => 21,
    22 => 23,
};

use constant {
    ANA_ROLE_ID        => 0,
    ANA_ROLE_NAME      => 1,
    ANA_ROLE_IP        => 2,
    ANA_TOTAL_TIME     => 3,
    ANA_TCP_TIME       => 4,
    ANA_RESPONSE_TIME  => 5,
    ANA_DOWNLOAD_SPEED => 6,
    ANA_MONITOR_TIME   => 7,
    ANA_DNS_TIME       => 8,
    ANA_ERR_ID         => 9,
};

use constant {
    TIME_TYPE  => 0,
    SPEED_TYPE => 1,
};

sub cal_rate($$$)
{
    my ($aqb, $org, $type) = @_;
    my $rate = 0;
    my $divby = ($org > $aqb) ? $aqb : $org;
    
    if ($divby == 0) {
        return $rate;
    }
    
    if ($type == TIME_TYPE) {
        $rate = ($org - $aqb) * 100 / $divby;
    } else {
        $rate = ($aqb - $org) * 100 / $divby;
    }

    $rate = roundFloat($rate);
    return $rate;
}

sub vs_rate($$$$$)
{
    my ($date, $site, $city, $clock, $vs_href) = @_;
    my $aqb = $vs_href->{aqb};
    my $org = $vs_href->{org};


    $vs_href->{all}{role_id} = $aqb->{&ANA_ROLE_ID};
    $vs_href->{all}{role_name} = $site;
    $vs_href->{all}{city_code} = $city;
    $vs_href->{all}{time} = "$date $clock:00:00";
    $vs_href->{all}{aqb_ip} = $aqb->{&ANA_ROLE_IP};
    $vs_href->{all}{org_ip} = $org->{&ANA_ROLE_IP};
  
    $vs_href->{all}{total_rate} = cal_rate($aqb->{&ANA_TOTAL_TIME}, $org->{&ANA_TOTAL_TIME}, TIME_TYPE);
    $vs_href->{all}{tcp_rate} = cal_rate($aqb->{&ANA_TCP_TIME}, $org->{&ANA_TCP_TIME}, TIME_TYPE);
    $vs_href->{all}{response_rate} = cal_rate($aqb->{&ANA_RESPONSE_TIME}, $org->{&ANA_RESPONSE_TIME}, TIME_TYPE);
    $vs_href->{all}{download_rate} = cal_rate($aqb->{&ANA_DOWNLOAD_SPEED}, $org->{&ANA_DOWNLOAD_SPEED}, SPEED_TYPE);
    my $interval = getInterval($aqb->{&ANA_MONITOR_TIME}, $org->{&ANA_MONITOR_TIME});
    my $intersec = $interval->{days} * 24 * 3600 + $interval->{hours} * 3600 + $interval->{minutes} * 60 + $interval->{seconds};
    $intersec = $intersec * (-1) if ($aqb->{&ANA_MONITOR_TIME} lt $org->{&ANA_MONITOR_TIME});
    $vs_href->{all}{time_interval} = $intersec;

    return $vs_href;
}

my $cesu_sites_aref;
sub generate_speed_analysis($)
{
    my $date = shift;
    my $sql = "";
    my $count = 0;

    # get all cesu role_id and sites
    $sql = qq/select distinct(role_id),role_name from speed_monitor_data where monitor_time>="$date 00:00:00" and monitor_time<="$date 23:59:59" and role_name like "%_aqb" order by role_name/;
    $cesu_sites_aref = $dbh->query($sql);

    # 
    # loop
    # site => city => clock
    #
    for (my $i = 0; $i <= $#$cesu_sites_aref; $i++) {
        $cesu_sites_aref->[$i][ANA_ROLE_NAME] =~ m/^(.*)_.*/;
        my $site = $1;
                    
        ++$count;

        foreach my $key_city (sort keys %$city_code) {
            $sql = qq/select role_id,role_name,role_ip,total_time,tcp_time,response_time,download_speed,monitor_time,dns_time,error_id from speed_monitor_data where monitor_time>="$date 00:00:00" and monitor_time<="$date 23:59:59" and role_name like "$site\_%" and city_code=$key_city order by monitor_time/;
            my $site_city_aref = $dbh->query($sql);

            foreach my $key_clock (sort keys %$clock) {
                my $clock_start = "$date $key_clock:00:00";
                my $clock_end = "$date $clock->{$key_clock}:00:00";

                my $vs_data; 
                for (my $j = 0; $j <= $#$site_city_aref; $j++) 
                {
                    my $r = $site_city_aref->[$j];
                    if (($clock_start lt $r->[ANA_MONITOR_TIME]) and 
                        ($clock_end gt $r->[ANA_MONITOR_TIME]))
                    {
                        my $n;
                        if ($r->[ANA_ROLE_NAME] =~ m/.*_aqb/) {
                            $n = 'aqb';
                        } else {
                            $n = 'org';
                        }
                            
                        $vs_data->{$n}{&ANA_ROLE_ID} = $r->[ANA_ROLE_ID];
                        $vs_data->{$n}{&ANA_ROLE_NAME} = $r->[ANA_ROLE_NAME];
                        $vs_data->{$n}{&ANA_ROLE_IP} = $r->[ANA_ROLE_IP];
                        $vs_data->{$n}{&ANA_TOTAL_TIME} = $r->[ANA_TOTAL_TIME];
                        $vs_data->{$n}{&ANA_TCP_TIME} = $r->[ANA_TCP_TIME];
                        $vs_data->{$n}{&ANA_RESPONSE_TIME} = $r->[ANA_RESPONSE_TIME];
                        $vs_data->{$n}{&ANA_DOWNLOAD_SPEED} = $r->[ANA_DOWNLOAD_SPEED];
                        $vs_data->{$n}{&ANA_MONITOR_TIME} = $r->[ANA_MONITOR_TIME];
                        $vs_data->{$n}{&ANA_DNS_TIME} = $r->[ANA_DNS_TIME];
                        $vs_data->{$n}{&ANA_ERR_ID} = $r->[ANA_ERR_ID];
                    }
                }

                # here calculate aqb vs org
                if (exists($vs_data->{aqb}) && exists($vs_data->{org}) &&
                    (0==$vs_data->{aqb}{&ANA_ERR_ID}) && (0==$vs_data->{org}{&ANA_ERR_ID})) 
                {
                    $vs_data->{org}{&ANA_TOTAL_TIME} += $vs_data->{aqb}{&ANA_DNS_TIME} if $vs_data->{org}{&ANA_TOTAL_TIME}>0;
                    vs_rate($date, $site, $key_city, $key_clock, $vs_data);

                    # save to db
                    $dbh->insert('speed_data_analysis', $vs_data->{all}) if $do_db;
                    printf(Dumper($vs_data));
                    printf("#############################\n");
                }
            }
        }
    }

    printf("\n### $count\n");
}


use constant {
    COM_IPSEG      => 0,
    COM_TOTAL_RATE => 1,
    COM_COUNT      => 2,
};

sub compare_cluster($$)
{
    my ($base_date, $comp_date) = @_;
    my $sql;
    my $comp_href;

    $sql = qq/select fun_ipseg(aqb_ip) as a, round(avg(total_rate),2), count(*) as c from speed_data_analysis where time like "$base_date %" and total_rate!=0 group by fun_ipseg(aqb_ip) order by c desc/;
    my $base_aref = $dbh->query($sql);
    
    $sql = qq/select fun_ipseg(aqb_ip) as a, round(avg(total_rate),2), count(*) as c from speed_data_analysis where time like "$comp_date %" and total_rate!=0 group by fun_ipseg(aqb_ip) order by c desc/;
    my $comp_aref = $dbh->query($sql);

    for (my $i = 0; $i <= $#$base_aref; $i++) {
        for (my $j = 0; $j <= $#$comp_aref; $j++) {
            if ($base_aref->[$i][COM_IPSEG] eq $comp_aref->[$j][COM_IPSEG]) {
                $comp_href->{$base_aref->[$i][COM_IPSEG]}{rate} = $comp_aref->[$j][COM_TOTAL_RATE] - $base_aref->[$i][COM_TOTAL_RATE];
                $comp_href->{$base_aref->[$i][COM_IPSEG]}{count} = $comp_aref->[$j][COM_COUNT] + $base_aref->[$i][COM_COUNT];
            }
        }
    }

    foreach my $k (sort {$comp_href->{$a}{rate} <=> $comp_href->{$b}{rate}} keys %$comp_href) {
        printf("%s.X\t%0.2f\t%d\n", $k, $comp_href->{$k}{rate}, $comp_href->{$k}{count});
    }
    
    for (my $i = 0; $i <= $#$base_aref; $i++) {
        my $findit = 0;
        foreach my $k (keys %$comp_href) {
            if ($base_aref->[$i][COM_IPSEG] eq $k) {
                $findit = 1;
                last;
            }
        }

        if (!$findit) {
            printf("- %s.X\t%0.2f\t%d\n", $base_aref->[$i][COM_IPSEG],
                $base_aref->[$i][COM_TOTAL_RATE],
                $base_aref->[$i][COM_COUNT]);
        }
    }

    for (my $i = 0; $i <= $#$comp_aref; $i++) {
        my $findit = 0;
        foreach my $k (keys %$comp_href) {
            if ($comp_aref->[$i][COM_IPSEG] eq $k) {
                $findit = 1;
                last;
            }
        }

        if (!$findit) {
            printf("+ %s.X\t%0.2f\t%d\n", $comp_aref->[$i][COM_IPSEG],
                $comp_aref->[$i][COM_TOTAL_RATE],
                $comp_aref->[$i][COM_COUNT]);
        }
    }

    return $comp_href;
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

#generate_speed_analysis($date);

#compare_cluster("2013-04-22", "2013-04-27");
#compare_cluster("2013-05-01", "2013-05-02");
compare_cluster("2013-05-01", "2013-05-03");

# analysis bonree cesu data
#sort_db_speed($keyword, $date);

# calculata speed rate
#speed_rate($date);

$dbh->fini();

1;

# vim: ts=4:sw=4:et

