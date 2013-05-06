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

my $dbh;
my $do_db = 1;

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
sub speed_data_analysis($)
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

    return 1;
}

use constant {
    COM_IPSEG      => 0,
    COM_TOTAL_RATE => 1,
    COM_COUNT      => 2,
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
            $cl_hour_href->{total_rate} = $recs->[0][COM_TOTAL_RATE];
            $cl_hour_href->{count} = $recs->[0][COM_COUNT];
            $cl_hour_href->{time} = "$date";

            $dbh->insert("cluster_cesu_hour", $cl_hour_href);
        }
    }
}

sub cluster_cesu_daily($)
{
    my $date = shift;
    my $sql = "";
    my $cluster_href = ();
    
    $sql = qq/select fun_ipseg(aqb_ip) as a, round(avg(total_rate),2), count(*) as c from speed_data_analysis where time like "$date %" and total_rate!=0 group by fun_ipseg(aqb_ip) order by c desc/;
    my $recs = $dbh->query($sql);
    for (my $i = 0; $i <= $#$recs; $i++) {
        $cluster_href = ();
        $cluster_href->{ipseg} = $recs->[$i][COM_IPSEG];
        $cluster_href->{total_rate} = $recs->[$i][COM_TOTAL_RATE];
        $cluster_href->{count} = $recs->[$i][COM_COUNT];
        $cluster_href->{time} = "$date";

        $dbh->insert("cluster_cesu_daily", $cluster_href);

        # if speed rate too bad, need to analysis hours data
        if (($cluster_href->{count} > 200) && ($cluster_href->{total_rate} <= 0)) {
            $sql = qq/select id from cluster_cesu_daily where ipseg="$cluster_href->{ipseg}" and time like "$date %"/;
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

#speed_data_analysis($date);

cluster_cesu_daily($date);

#compare_cluster("2013-04-22", "2013-05-05");
#compare_cluster("2013-05-01", "2013-05-02");
#compare_cluster("2013-05-03", "2013-05-04");

$dbh->fini();

1;

# vim: ts=4:sw=4:et

