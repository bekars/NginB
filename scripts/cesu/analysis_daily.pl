#!/usr/bin/perl -w

# INSERT DB
#   speed_data_analysis
#   cluster_cesu_daily
#   cluster_cesu_hour

use strict;
use 5.010;
use Speedy::Utils;
use Data::Dumper;
use BMD::DBH;
use Time::Interval;
use Getopt::Long;
use Smart::Comments;

my $keyword = "total_time";

my $today     = `/bin/date -d "-1 day" +"%Y-%m-%d"`;
my $yesterday = `/bin/date -d "-2 day" +"%Y-%m-%d"`;

$today     =~ tr/\n//d;
$yesterday =~ tr/\n//d;

#$yesterday = "2013-05-24";
#$today     = "2013-05-25";

my $dbh;
my $do_db = 0;
my $do_analysis = 0;

my $analysis_fp;

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

    # abnormal data return null
    if (($vs_href->{all}{total_rate}) > 300 || ($vs_href->{all}{total_rate} < -300)) {
        return;
    }

    return $vs_href;
}

my $cesu_sites_aref;
sub speed_data_analysis($)
{
    my $date = shift;
    my $sql = "";
    my $count = 0;

    # get all cesu role_id and sites
    $sql = qq/select distinct(role_id),role_name from speed_monitor_data,speed_task where speed_monitor_data.role_id=speed_task.aqb_role_id and speed_task.cesu=1 and speed_task.task_status=1 and date(monitor_time)="$date" and role_name like "%_aqb" order by role_name/;
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
            $sql = qq/select role_id,role_name,role_ip,total_time,tcp_time,response_time,download_speed,monitor_time,dns_time,error_id from speed_monitor_data where monitor_time>="$date 00:00:00" and monitor_time<="$date 23:59:59" and role_name like "${site}_%" and city_code=$key_city order by monitor_time/;
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
                    if (vs_rate($date, $site, $key_city, $key_clock, $vs_data)) {
                        # save to db
                        $dbh->insert('speed_data_analysis', $vs_data->{all}) if $do_db;
                    }
                    printf(Dumper($vs_data));
                    printf("#############################\n");
                }
            }
        }
    }

    printf("\n### $count\n");

    return 1;
}

use constant {
    COM_IPSEG      => 0,
    COM_TOTAL_RATE => 1,
    COM_COUNT      => 2,
    COM_PERCENT    => 3,
};

sub cluster_cesu_hour($$$)
{
    my ($id, $date, $cl_href) = @_;
    my $cl_hour_href = ();

    foreach my $key_clock (sort keys %$clock) {
        my $clock_start = "$date $key_clock:00:00";
        my $clock_end = "$date $clock->{$key_clock}:00:00";
        my $sql = qq/select fun_ipseg(aqb_ip) as a, round(avg(total_rate),2), count(*) as c from speed_data_analysis where time>="$clock_start" and time<="$clock_end" and total_rate!=0 and fun_ipseg(aqb_ip)="$cl_href->{ipseg}"/;

        my $recs = $dbh->query($sql);
        if (exists($recs->[0])) {
            $cl_hour_href->{dailyid} = $id;
            $cl_hour_href->{clock} = "$key_clock:00:00";
            $cl_hour_href->{ipseg} = $cl_href->{ipseg};
            $cl_hour_href->{total_rate} = 0;
            $cl_hour_href->{total_rate} = $recs->[0][COM_TOTAL_RATE] if $recs->[0][COM_TOTAL_RATE];
            $cl_hour_href->{count} = $recs->[0][COM_COUNT];
            $cl_hour_href->{time} = "$date";

            $dbh->insert("cluster_cesu_hour", $cl_hour_href) if $do_db;
        }
    }
}

sub cluster_cesu_daily($)
{
    my $date = shift;
    my $sql = "";
    my $cluster_href = ();
    
    $sql = qq/select count(*) as c from speed_data_analysis where date(time)="$date" and total_rate!=0/;
    my $total_cnt = $dbh->query_count($sql);

    $sql = qq/select fun_ipseg(aqb_ip) as a, round(avg(total_rate),2), count(*) as c from speed_data_analysis where date(time)="$date" and total_rate!=0 group by fun_ipseg(aqb_ip) order by c desc/;
    my $recs = $dbh->query($sql);
    for (my $i = 0; $i <= $#$recs; $i++) {
        $cluster_href = ();
        $cluster_href->{ipseg} = $recs->[$i][COM_IPSEG];
        $cluster_href->{total_rate} = $recs->[$i][COM_TOTAL_RATE];
        $cluster_href->{count} = $recs->[$i][COM_COUNT];
        $cluster_href->{percent} = roundFloat($recs->[$i][COM_COUNT] * 100 / $total_cnt);
        $cluster_href->{time} = "$date";

        $dbh->insert("cluster_cesu_daily", $cluster_href) if $do_db;

        # if speed rate too bad, need to analysis hours data
        if ($cluster_href->{count} > 10) { # || ($cluster_href->{total_rate} <= 0))) {
            $sql = qq/select id from cluster_cesu_daily where ipseg="$cluster_href->{ipseg}" and date(time)="$date"/;
            my $id = $dbh->query($sql);
            if (exists($id->[0][0])) {
                cluster_cesu_hour($id->[0][0], $date, $cluster_href);
            }
        }
    }

    return 1;
}

sub compare_cluster($$)
{
    my ($base_date, $comp_date) = @_;
    my $sql;
    my $comp_href;

    $sql = qq/select ipseg, total_rate, count, percent from cluster_cesu_daily where time like "$base_date %" order by percent desc/;
    my $base_aref = $dbh->query($sql);
    
    $sql = qq/select ipseg, total_rate, count, percent from cluster_cesu_daily where time like "$comp_date %" order by percent desc/;
    my $comp_aref = $dbh->query($sql);

    for (my $i = 0; $i <= $#$base_aref; $i++) {
        for (my $j = 0; $j <= $#$comp_aref; $j++) {
            if ($base_aref->[$i][COM_IPSEG] eq $comp_aref->[$j][COM_IPSEG]) {
                $comp_href->{$base_aref->[$i][COM_IPSEG]}{rate} = $comp_aref->[$j][COM_TOTAL_RATE] - $base_aref->[$i][COM_TOTAL_RATE];
                $comp_href->{$base_aref->[$i][COM_IPSEG]}{count} = $comp_aref->[$j][COM_COUNT] + $base_aref->[$i][COM_COUNT];
                $comp_href->{$base_aref->[$i][COM_IPSEG]}{percent} = ($comp_aref->[$j][COM_PERCENT] + $base_aref->[$i][COM_PERCENT]) / 2;
                $comp_href->{$base_aref->[$i][COM_IPSEG]}{old_rate} = $base_aref->[$i][COM_TOTAL_RATE];
                $comp_href->{$base_aref->[$i][COM_IPSEG]}{now_rate} = $comp_aref->[$j][COM_TOTAL_RATE];
                $comp_href->{$base_aref->[$i][COM_IPSEG]}{old_percent} = $base_aref->[$i][COM_PERCENT];
                $comp_href->{$base_aref->[$i][COM_IPSEG]}{now_percent} = $comp_aref->[$j][COM_PERCENT];
                $comp_href->{$base_aref->[$i][COM_IPSEG]}{effect} = $comp_href->{$base_aref->[$i][COM_IPSEG]}{rate} * $comp_href->{$base_aref->[$i][COM_IPSEG]}{percent} / 100;
            }
        }
    }

    foreach my $k (sort {$comp_href->{$a}{rate} <=> $comp_href->{$b}{rate}} keys %$comp_href) {
        printf("%11s.X\t%.2f\t%.2f%%\t%.2f%%\t\t%.2f%%\t%.2f%%\t%.2f%%\t%.2f%%\n", $k, 
            $comp_href->{$k}{rate}, $comp_href->{$k}{percent}, 
            $comp_href->{$k}{effect},
            $comp_href->{$k}{old_rate}, $comp_href->{$k}{now_rate}, 
            $comp_href->{$k}{old_percent}, $comp_href->{$k}{now_percent}, 
        );

        cluster_rate_log($base_date, 
            $comp_date, 
            $k, 
            $comp_href->{$k}{old_rate}, 
            $comp_href->{$k}{now_rate},
            $comp_href->{$k}{old_percent}, 
            $comp_href->{$k}{now_percent},
        );
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
            my $effect = $base_aref->[$i][COM_TOTAL_RATE] * $base_aref->[$i][COM_PERCENT] / 100;
            printf("- %11s.X\t%.2f%%\t%.2f%%\t%.2f%%\n", $base_aref->[$i][COM_IPSEG],
                $base_aref->[$i][COM_TOTAL_RATE],
                $base_aref->[$i][COM_PERCENT],
                $effect
            );

            cluster_rate_log($base_date, 
                "", 
                $base_aref->[$i][COM_IPSEG],
                $base_aref->[$i][COM_TOTAL_RATE],
                0,
                $base_aref->[$i][COM_PERCENT],
                0,
            );
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
            my $effect = $comp_aref->[$i][COM_TOTAL_RATE] * $comp_aref->[$i][COM_PERCENT] / 100;
            printf("+ %11s.X\t%.2f%%\t%.2f%%\t%.2f%%\n", $comp_aref->[$i][COM_IPSEG],
                $comp_aref->[$i][COM_TOTAL_RATE],
                $comp_aref->[$i][COM_PERCENT],
                $effect
            );
            
            cluster_rate_log("", 
                $comp_date, 
                $comp_aref->[$i][COM_IPSEG],
                0,
                $comp_aref->[$i][COM_TOTAL_RATE],
                0,
                $comp_aref->[$i][COM_PERCENT],
            );
        }
    }

    return $comp_href;
}

sub cluster_rate_log($$$$$$$)
{
    my ($date_base, $date_comp, $ipseg, $rate_base, $rate_comp, $perc_base, $perc_comp) = @_;

    return 0 if is_out_cluster($ipseg);

    if (($date_base ne '') && ($date_comp ne '')) {
        my $rate = $rate_comp - $rate_base;
        my $percent = ($perc_comp + $perc_base) / 2;
        my $effect = $rate * $percent / 100;
        my $flag = 0;

        if ($effect < -0.5) {
            printf($analysis_fp "[$ipseg 性能下降]\n");
            $flag = 1;
        } elsif ($effect > 0.5) {
            printf($analysis_fp "[$ipseg 性能提高]\n");
            $flag = 1;
        }

        if ($flag) {
            printf($analysis_fp "性能变化差值: %.2f%%\n" . 
                "占测速比例: %.2f%%\n" . 
                "影响测速百分比: %.2f%%\n" . 
                "%s性能: %.2f%%\n" . 
                "%s性能: %.2f%%\n" . 
                "%s占测速比例: %.2f%%\n" .
                "%s占测速比例: %.2f%%\n\n",
                $rate,
                $percent,
                $effect,
                $date_base, $rate_base,
                $date_comp, $rate_comp,
                $date_base, $perc_base,
                $date_comp, $perc_comp,
            );
        }

        return 1 if ($flag);

        use constant {DELTA_PERCENT=>5, NEG_DELTA_PERCENT=>-5};
        my $delta_percent = $perc_comp - $perc_base;
        my $delta_rate = ($rate_comp * $delta_percent / 100);
        if ($delta_percent > DELTA_PERCENT && $rate_comp > 0) {
            printf($analysis_fp "[$ipseg 调入导致性能提高]\n");
            $flag = 1;
        } elsif ($delta_percent > DELTA_PERCENT && $rate_comp < 0) {
            printf($analysis_fp "[$ipseg 调入导致性能下降]\n");
            $flag = 1;
        } elsif ($delta_percent < NEG_DELTA_PERCENT && $rate_base < 0) {
            printf($analysis_fp "[$ipseg 调出导致性能提高]\n");
            $flag = 1;
        } elsif ($delta_percent < NEG_DELTA_PERCENT && $rate_base > 0) {
            printf($analysis_fp "[$ipseg 调出导致性能下降]\n");
            $flag = 1;
        }

        if ($flag) {
            printf($analysis_fp "性能变化差值: %.2f%%\n" . 
                "占测速比例: %.2f%%\n" . 
                "影响测速百分比: %.2f%%\n\n", 
                $rate_comp,
                $delta_percent,
                $delta_rate,
            );
        }
    } 
    elsif (($date_base ne '') && ($date_comp eq '')) {
        my $effect = $rate_base * $perc_base / 100;
        if ($effect > 1 || $effect < -1) {
            if ($rate_base > 0) {
                printf($analysis_fp "[$ipseg 调出导致性能下降]\n");
            } else {
                printf($analysis_fp "[$ipseg 调出导致性能提高]\n");
            }

            printf($analysis_fp "性能变化差值: %.2f%%\n" . 
                "占测速比例: %.2f%%\n" . 
                "影响测速百分比: %.2f%%\n\n", 
                $rate_base,
                $perc_base,
                $effect,
            );
        }
    }
    elsif (($date_base eq '') && ($date_comp ne '')) {
        my $effect = $rate_comp * $perc_comp / 100;
        if ($effect > 1 || $effect < -1) {
            if ($rate_comp > 0) {
                printf($analysis_fp "[$ipseg 调入导致性能提高]\n");
            } else {
                printf($analysis_fp "[$ipseg 调入导致性能下降]\n");
            }

            printf($analysis_fp "性能变化差值: %.2f%%\n" . 
                "占测速比例: %.2f%%\n" . 
                "影响测速百分比: %.2f%%\n\n", 
                $rate_comp,
                $perc_comp,
                $effect,
            );
        }
    }

    return 1;
}

sub delta_daily($$)
{
    my ($date_start, $date_end) = @_;

    my $sql = qq/select distince(ipseg) from cluster_cesu_daily where time>="$date_start 00:00:00" and time<="$date_end 00:00:00"/;
    my $ipseg_aref = $dbh->query($sql);

    for (my $i = 0; $i <= $#$ipseg_aref; $i++) {
        say($ipseg_aref->[$i]);

        $sql = qq/select total_rate from cluster_cesu_daily where time>="$date_start 00:00:00" and time<="$date_end 00:00:00"/;

    }

    return 1;
}

my @cluster_out = (
    '64.32.4', 
    '69.28.51', 
    '210.209.122', 
    '61.244.110', 
    '120.50.35', 
    '54.248.83', 
);

sub is_out_cluster($)
{
    my $ipseg = shift;
    foreach my $out (@cluster_out) {
        return 1 if ($out eq $ipseg);
    }
    return 0;
}

sub cluster_slow_log($$)
{
    my ($yesterday, $today) = @_;
    my $sql = qq/select ipseg,total_rate,count,percent from cluster_cesu_daily where time like "$today %" and percent>0.5 and total_rate<-10 order by total_rate/;

    printf($analysis_fp "\n### 速度比源站慢超过10%%的机房 %s ###\n", $today);

    my $recs = $dbh->query($sql);
    LOOP: for (my $i = 0; $i <= $#$recs; $i++) {
        next LOOP if is_out_cluster($recs->[$i][COM_IPSEG]);

        $sql = qq/select total_rate from cluster_cesu_daily where ipseg='$recs->[$i][COM_IPSEG]' and time like '$yesterday %'/;
        my $yesterday_rate = $dbh->query_count($sql);
        $yesterday_rate = 0 if !$yesterday_rate;

        printf($analysis_fp "[机房: %s]\n比源站慢: %.2f%%\n占测速比重: %.2f%%\n%s此机房比源站慢: %.2f%%\n\n",
            $recs->[$i][COM_IPSEG],
            $recs->[$i][COM_TOTAL_RATE],
            $recs->[$i][COM_PERCENT],
            $yesterday, $yesterday_rate,
        );
    }
}

use constant {
    CESU_BIGZERO    => 0,
    CESU_FAST       => 1,
    CESU_FASTAVG    => 2,
    CESU_SLOW       => 3,
    CESU_SLOWAVG    => 4,
    CESU_TOTAL      => 5,
    CESU_ALLBIGZERO => 6,
    CESU_ALLFASTAVG => 7,
    CESU_ALLTOTAL   => 8,
    CESU_DATE       => 9,
};

sub cesu_daily_log($$$$)
{
    my ($yesterday, $today, $type, $fp) = @_;

    my $sql_tmpl = qq/select bigzero,fast,fastavg,slow,slowavg,total,all_bigzero,all_fastavg,all_total,date(time) from cesu_daily where type='%s' and date(time)='%s'/;

    my $sql = sprintf($sql_tmpl, $type, $yesterday);
    my $recs = $dbh->query($sql);
    my ($y_b, $y_f, $y_fa, $y_s, $y_sa, $y_t, $y_ab, $y_af, $y_at, $y_d) = ( 
        $recs->[0][CESU_BIGZERO],
        $recs->[0][CESU_FAST],
        $recs->[0][CESU_FASTAVG],
        $recs->[0][CESU_SLOW],
        $recs->[0][CESU_SLOWAVG],
        $recs->[0][CESU_TOTAL],
        $recs->[0][CESU_ALLBIGZERO],
        $recs->[0][CESU_ALLFASTAVG],
        $recs->[0][CESU_ALLTOTAL],
        $recs->[0][CESU_DATE]) if ($recs->[0]);

    $sql = sprintf($sql_tmpl, $type, $today);
    $recs = $dbh->query($sql);
    my ($t_b, $t_f, $t_fa, $t_s, $t_sa, $t_t, $t_ab, $t_af, $t_at, $t_d) = (
        $recs->[0][CESU_BIGZERO],
        $recs->[0][CESU_FAST],
        $recs->[0][CESU_FASTAVG],
        $recs->[0][CESU_SLOW],
        $recs->[0][CESU_SLOWAVG],
        $recs->[0][CESU_TOTAL],
        $recs->[0][CESU_ALLBIGZERO],
        $recs->[0][CESU_ALLFASTAVG],
        $recs->[0][CESU_ALLTOTAL],
        $recs->[0][CESU_DATE]) if ($recs->[0]);

    printf($fp "\n### 加速比 ###\n" .
        "%s比源站快%%: %.2f%%\n" .
        "%s比源站快%%: %.2f%%\n", 
        $yesterday, $y_b, 
        $today, $t_b,
    );

    my $delta = $t_b - $y_b;
    if ($delta > 0) {
        printf($fp "加速提升: %.2f%%\n", $delta);
    } else {
        printf($fp "减速下降: %.2f%%\n", $delta);
    }

    printf($fp 
        "\n[%s详细数据]\n符合测速条件共%d站: 比源站快: %.2f%%; 快>10%%: %.2f%%; 平均加速幅度: %.2f%%; 慢<-10%%: %.2f%%; 平均减速幅度：%.2f%%;\n总共测速%d站: 比源站快: %.2f%%; 平均加速幅度: %.2f%%\n" .
        "\n[%s详细数据]\n符合测速条件共%d站: 比源站快: %.2f%%; 快>10%%: %.2f%%; 平均加速幅度: %.2f%%; 慢<-10%%: %.2f%%; 平均减速幅度：%.2f%%;\n总共测速%d站: 比源站快: %.2f%%; 平均加速幅度: %.2f%%\n\n",
        $yesterday, $y_t, $y_b, $y_f, $y_fa, $y_s, $y_sa, $y_at, $y_ab, $y_af,
        $today, $t_t, $t_b, $t_f, $t_fa, $t_s, $t_sa, $t_at, $t_ab, $t_af,
    );

    return 1;
}

sub cache_hit_log($)
{
    my ($today) = @_;
    my $sql = qq/select cachehit,cacherate_flow,hit,hit_flow,total,total_flow from cache_hit where date(time)="$today"/;
    my $recs = $dbh->query($sql);

    my ($cachehit, $cacherate, $hit, $hit_flow, $total, $total_flow) = (0, 0, 0, 0, 1, 1);
    if (exists($recs->[0])) {
        ($cachehit, $cacherate, $hit, $hit_flow, $total, $total_flow) = @{$recs->[0]};
    }

    printf($analysis_fp "\n### 缓存命中率 %s ###\n" .
        "缓存命中率: %.2f%%, 缓存率: %.2f%%\n" .
        "HIT总体命中率: %.2f%%, HIT总体缓存率: %.2f%%\n" .
        "总日志数: %.2f亿, 总流量: %.2fG\n\n",
        $today, $cachehit, $cacherate,
        $hit * 100 / $total, $hit_flow * 100 / $total_flow,
        $total / 100000000, $total_flow / 1024 / 1024 /1024);
}

#
# begin to run
#

GetOptions(
    'do_db|d+' => \$do_db,
    'do_analysis|a+' => \$do_analysis,
);

$dbh = BMD::DBH->new(
    'dbhost' => '116.213.78.228',
    'dbuser' => 'cesutest',
    'dbpass' => 'cesutest',
    #'dbuser' => 'cesureadonly',
    #'dbpass' => '66ecf9c968132321a02e6e7aff34ce5d',
    'dbname' => 'speed',
    'dbport' => 3306
);

speed_data_analysis($today) if $do_analysis;

cluster_cesu_daily($today) if $do_analysis;

open($analysis_fp, ">/tmp/analysis_daily.txt");

printf($analysis_fp "\n对比%s和%s的测速数据\n", $yesterday, $today);
cesu_daily_log($yesterday, $today, "cesu", $analysis_fp);

cache_hit_log($yesterday);

printf($analysis_fp "\n### 机房性能变化 %s ~ %s ###\n", $yesterday, $today);
compare_cluster($yesterday, $today);

cluster_slow_log($yesterday, $today);

close($analysis_fp);

#
# dnspod cesu data
#
open(my $dnspod_fp, ">/tmp/dnspod_daily.txt");
printf($dnspod_fp "\n对比%s和%s的测速数据\n", $yesterday, $today);
cesu_daily_log($yesterday, $today, "dnspod", $dnspod_fp);

close($dnspod_fp);

$dbh->fini();

1;

# vim: ts=4:sw=4:et

