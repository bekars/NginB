#!/usr/bin/perl -w
# 统计HIT之后下载比源站慢的节点，以及下载文件大小的统计数据

use strict;
use 5.010;
use Speedy::Utils;
use Data::Dumper;
use BMD::DBH;
use BMD::IPOS;
use Time::Interval;
use autodie;
use Try::Tiny;

my $keyword = "total_time";

my $today   = `date -d "-1 day" +"%Y-%m-%d"`;
$today      =~ tr/\n//d;

my $date_g = "20130523";

# record cluster data
my $cluster_href = undef;

my $dbh = undef;
my $ipos = undef;

my $pos_c_a_href = ();
my $pos_c_o_href = ();

my $debug = 1;

my %file_size = (
    '0'  => '10',
    '10' => '20',
    '20' => '30',
    '30' => '40',
    '40' => '50',
    '50' => '100',
    '100' => '200',
    '200' => '500',
    '500' => '10000',
);

use constant {
    URL         => 0,
    ROLE_ID     => 1,
    MAIN_ID     => 2,
    ROLE_IP     => 3,
    DOWNSPEED   => 4,
    CITY_CODE   => 5,
    CLIENT_IP   => 6,
    DOWNSIZE    => 7,
    TIME        => 8,
    ROLE_NAME   => 9,
};

# find all have HIT url cluster
sub list_hit_clusters()
{
    my $sqlplus = qq//;

    # find hit clusters
    my $sql = qq/select fun_ipseg(role_ip),count(*) as c from speed_res_data_${date_g} where role_name like "%%_aqb" and header like "%%X-Powered-By-Anquanbao: HIT %%" and fun_ipseg(role_ip)!='0.0.0' $sqlplus group by fun_ipseg(role_ip) order by c desc/;
    
    my $recs = $dbh->query($sql);
    for (my $i = 0; $i <= $#$recs; $i++) {
        $cluster_href->{$recs->[$i][0]}{hit_cnt} = $recs->[$i][1];
    }

    return 1;
}

sub list_hit_clients()
{
    my $client_href = undef;
    my $sqlplus = qq/and down_time_s>0.01/;

    # find hit clients
    my $sql = qq/select fun_ipseg(client_ip),count(*) as c from speed_res_data_${date_g} where role_name like "%%_aqb" and header like "%%X-Powered-By-Anquanbao: HIT %%" and fun_ipseg(role_ip)!='0.0.0' $sqlplus group by fun_ipseg(client_ip) order by c desc/;
    
    my $recs = $dbh->query($sql);
    for (my $i = 0; $i <= $#$recs; $i++) {
        $client_href->{$recs->[$i][0]}{hit_cnt} = $recs->[$i][1];
    }

    return $client_href;
}

sub compare_hit_url($) 
{
    my $clusterip = shift;
    my $downspeed_aqb;
    my $downspeed_org;
    my $roleip_aqb;
    my $roleip_org;
    my ($url, $main_id, $filesize);

    # select hit url on cluster
    my $sql = qq/select url,role_id,stat_main_id,role_ip,down_time_s,city_code,client_ip,down_size_bytes,monitor_time from speed_res_data_${date_g} where role_name like "%%_aqb" and header like "%%X-Powered-By-Anquanbao: HIT %%" and fun_ipseg(role_ip)='$clusterip'/;

    my $recs = $dbh->query($sql);
    for (my $i = 0; $i <= $#$recs; $i++) {
        $url = $recs->[$i][URL];
        $main_id = $recs->[$i][MAIN_ID];
        $downspeed_aqb = $recs->[$i][DOWNSPEED];
        $roleip_aqb = $recs->[$i][ROLE_IP];
        $filesize = $recs->[$i][DOWNSIZE];

        ($downspeed_org, $roleip_org) = get_org_downspeed($url, $main_id);
        if ($downspeed_org && $roleip_org) {
            $url =~ tr/%/#/;
            printf("$url $main_id $downspeed_aqb $roleip_aqb $downspeed_org $roleip_org\n");
            
            foreach my $k (sort keys %file_size) {
                if (($filesize > ($k * 1000)) && ($filesize <= ($file_size{$k} * 1000))) {
                    if ($downspeed_aqb <= $downspeed_org) {
                        $cluster_href->{$clusterip}{"filesize_$k"}{fast} += 1;
                        $cluster_href->{$clusterip}{fast_cnt} += 1;
                    } else {
                        $cluster_href->{$clusterip}{"filesize_$k"}{slow} += 1;
                        $cluster_href->{$clusterip}{slowip}{$recs->[$i][CLIENT_IP]} += 1;
                        $cluster_href->{$clusterip}{slow_cnt} += 1;

                        # log slow client region and url
                        log_url($recs->[$i][CLIENT_IP], $roleip_org, $url);
                    }

                    $cluster_href->{$clusterip}{"filesize_$k"}{total} += 1;
                    $cluster_href->{$clusterip}{"filesize_$k"}{aqb}{total_speed} += $downspeed_aqb;
                    $cluster_href->{$clusterip}{"filesize_$k"}{org}{total_speed} += $downspeed_org;

                    last;
                }
            }
        }
    }

    return 1;
}

sub log_url($$$)
{
    my ($client_ip, $roleip_org, $url) = @_;
    my ($country, $province, $isp) = $ipos->query($client_ip);

    if (($province eq "北京") && ($isp eq "联通")) {
        printf("SLOWURL: %s %s %s\n", $client_ip, $roleip_org, $url);
    }

    return 1;
}

sub get_org_downspeed($$)
{
    my ($url, $main_id) = @_;

    # select same stat_main_id
    my $sql = qq/select url,role_id,stat_main_id,role_ip,down_time_s,city_code,client_ip,down_size_bytes,monitor_time from speed_res_data_${date_g} where role_name like '%%_ip' and url='$url' and stat_main_id=$main_id/;

    my $recs = $dbh->query($sql);
    if ($#$recs != -1) {
        return ($recs->[0][DOWNSPEED], $recs->[0][ROLE_IP]);
    }

    return;
}

sub gen_speed_excel_data()
{
    my ($fast, $slow);

    open(my $fp, ">/tmp/hit_downspeed.txt");
    $fp->autoflush(1);

    printf($fp "cluster\t<10k\t10~20k\t20~30k\t30~40k\t40~50k\t50~100k\t100~200k\t200~500k\t>500k\tfast%%\tcount\n");

    foreach my $k (sort{$cluster_href->{$b}{hit_cnt} <=> $cluster_href->{$a}{hit_cnt}} keys %$cluster_href) {
        printf($fp "%s\t", $k);

        foreach my $s (sort keys %file_size) {
            $fast = 0;
            $slow = 0;

            if (exists($cluster_href->{$k}{"filesize_$s"})) {
                $fast = $cluster_href->{$k}{"filesize_$s"}{fast} if exists($cluster_href->{$k}{"filesize_$s"}{fast});
                $slow = $cluster_href->{$k}{"filesize_$s"}{slow} if exists($cluster_href->{$k}{"filesize_$s"}{slow});
                printf($fp "%.2f\t", $fast * 100 / ($fast + $slow));
            } else {
                printf($fp "N/A\t");
            }
        }

        if (exists($cluster_href->{$k}{fast_cnt}) && exists($cluster_href->{$k}{slow_cnt})) {
            printf($fp "%.2f\t%d\n", 
                $cluster_href->{$k}{fast_cnt} * 100 / ($cluster_href->{$k}{fast_cnt} + $cluster_href->{$k}{slow_cnt}), $cluster_href->{$k}{hit_cnt});
        } else {
            printf($fp "N/A\t%d\n", $cluster_href->{$k}{hit_cnt});
        }
    }

    close($fp);
}

sub gen_client_excel_data()
{
    my $slow_cnt;
    open(my $fp, ">/tmp/hit_client.txt");
    $fp->autoflush(1);

    my ($country, $province, $isp);

    foreach my $k (sort{$cluster_href->{$b}{hit_cnt} <=> $cluster_href->{$a}{hit_cnt}} keys %$cluster_href) {
        $slow_cnt = 0;
        foreach my $p (sort keys %{$cluster_href->{$k}{slowip}}) {
            $slow_cnt += $cluster_href->{$k}{slowip}{$p};
        }

        printf($fp "[%s %s %d %.2f%%]\n", $k, join(",", $ipos->query($k)), 
            $slow_cnt, $slow_cnt * 100 / $cluster_href->{$k}{hit_cnt}
        );

        foreach my $p (sort {$cluster_href->{$k}{slowip}{$b} <=> $cluster_href->{$k}{slowip}{$a}} keys %{$cluster_href->{$k}{slowip}}) {
            ($country, $province, $isp) = $ipos->query($p);
            $cluster_href->{$k}{clipos}{"$province-$isp"} += $cluster_href->{$k}{slowip}{$p};
        }

        foreach my $c (sort {$cluster_href->{$k}{clipos}{$b} <=> $cluster_href->{$k}{clipos}{$a}} keys %{$cluster_href->{$k}{clipos}}) {
            printf($fp "\t%s %.2f%% %d\n", $c, 
                $cluster_href->{$k}{clipos}{$c} * 100 / $slow_cnt,
                $cluster_href->{$k}{clipos}{$c}
            );
        }
    }

    close($fp);
}

sub view_hit_from_clusters()
{
    $cluster_href = ();
    list_hit_clusters();

    foreach my $k (sort{$cluster_href->{$b}{hit_cnt} <=> $cluster_href->{$a}{hit_cnt}} keys %$cluster_href) {
        printf("$k => $cluster_href->{$k}{hit_cnt}\n");
        compare_hit_url($k);
        #last;
    }

    printf(Dumper($cluster_href));

    gen_speed_excel_data();
    gen_client_excel_data();
}

sub ipseg($)
{
    my $ip = shift;
    $ip =~ m/^(\d+?)\.(\d+?)\.(\d+?)\.(\d+?)$/;
    return "$1.$2.$3";
}

sub find_fast_pos($$$$)
{
    my ($ip_cli, $ip_aqb, $ip_org, $isfast) = @_;
    my ($c_cli, $p_cli, $i_cli) = $ipos->query($ip_cli);
    my ($c_aqb, $p_aqb, $i_aqb) = $ipos->query($ip_aqb);
    my ($c_org, $p_org, $i_org) = $ipos->query($ip_org);

    my $ipseg_cli = ipseg($ip_cli);
    my $ipseg_aqb = ipseg($ip_aqb);
    my $ipseg_org = ipseg($ip_org);

    if ($isfast) {
        $pos_c_a_href->{"${p_cli}-${i_cli}-${ipseg_cli}"}{"${p_aqb}-${i_aqb}-${ipseg_aqb}"}{fast} += 1; 
        $pos_c_o_href->{"${p_cli}-${i_cli}-${ipseg_cli}"}{"${p_org}-${i_org}-${ipseg_org}"}{slow} += 1; 
    } else {
        $pos_c_a_href->{"${p_cli}-${i_cli}-${ipseg_cli}"}{"${p_aqb}-${i_aqb}-${ipseg_aqb}"}{slow} += 1; 
        $pos_c_a_href->{"${p_cli}-${i_cli}-${ipseg_cli}"}{"${p_aqb}-${i_aqb}-${ipseg_aqb}"}{org}{"${p_org}-${i_org}-${ipseg_org}"}{total} += 1; 
        $pos_c_o_href->{"${p_cli}-${i_cli}-${ipseg_cli}"}{"${p_org}-${i_org}-${ipseg_org}"}{fast} += 1; 
    }
    $pos_c_a_href->{"${p_cli}-${i_cli}-${ipseg_cli}"}{"${p_aqb}-${i_aqb}-${ipseg_aqb}"}{total} += 1; 
    $pos_c_o_href->{"${p_cli}-${i_cli}-${ipseg_cli}"}{"${p_org}-${i_org}-${ipseg_org}"}{total} += 1; 

    return 1;
}

sub compare_downspeed($$)
{
    my ($url, $main_id) = @_;
    my ($ip_cli, $ip_aqb, $ip_org, $isfast, $speed_aqb, $speed_org);
    my $sqlplus = qq/and down_time_s>0.01/;
    my $sql = qq/select url,role_id,stat_main_id,role_ip,down_time_s,city_code,client_ip,down_size_bytes,monitor_time,role_name from speed_res_data_${date_g} where url='$url' and stat_main_id=$main_id $sqlplus/;

    my $recs = $dbh->query($sql);
    if ($#$recs != 1) {
        return;
    }

    for (my $i = 0; $i <= $#$recs; $i++) {
        if ($recs->[$i][ROLE_NAME] =~ m/.*_aqb/) {
            $ip_cli = $recs->[$i][CLIENT_IP];
            $ip_aqb = $recs->[$i][ROLE_IP];
            $speed_aqb = $recs->[$i][DOWNSPEED];
        } else {
            $ip_org = $recs->[$i][ROLE_IP];
            $speed_org = $recs->[$i][DOWNSPEED];
        }
    }

    if ((not $ip_cli) || (not $ip_aqb) || (not $ip_org) || (not $speed_aqb) || (not $speed_org)) {
        printf("ERR: url=%s, main_id=%d\n", $url, $main_id);
        return;
    }

    $isfast = 0;
    $isfast = 1 if ($speed_aqb <= $speed_org);
    
    $url =~ tr/%/#/;
    printf("$url, $main_id, $isfast, $ip_cli, $ip_aqb, $ip_org, $speed_aqb, $speed_org\n");

    return ($ip_cli, $ip_aqb, $ip_org, $isfast);
}

sub generate_pos_log($$)
{
    my ($pos_href, $logfile) = @_;
    open(my $fp, ">$logfile");
    $fp->autoflush(1);

    foreach my $k1 (keys %$pos_href) {

        printf($fp "$k1:\n");

        my $p = $pos_href->{$k1};
        foreach my $k2 (keys %$p) {
            $p->{$k2}{rate} = roundFloat($p->{$k2}{fast} * 100 / $p->{$k2}{total});
        }

        foreach my $k2 (sort {$p->{$b}{rate} <=> $p->{$a}{rate}} keys %$p) {
            
            printf($fp "\t%s\t%.2f%%\t%d\n", $k2, $p->{$k2}{rate}, $p->{$k2}{total});

            my $q = $p->{$k2}{org};
            foreach my $k3 (sort {$q->{$b}{total} <=> $q->{$a}{total}} keys %$q) {
                printf($fp "\t\t\t\t%s\t%d\n", $k3, $q->{$k3}{total});
            }
        }
    }

    close($fp);
}

sub view_hit_from_clients()
{
    my $client_href = list_hit_clients();
    my $sqlplus = qq/and down_time_s>0.01/;

    my $cnt = 0;
    foreach my $kip (sort{$client_href->{$b}{hit_cnt} <=> $client_href->{$a}{hit_cnt}} keys %$client_href) 
    {
        printf("$kip => $client_href->{$kip}{hit_cnt}\n");

        # select client hit url
        my $sql = qq/select url,role_id,stat_main_id,role_ip,down_time_s,city_code,client_ip,down_size_bytes,monitor_time from speed_res_data_${date_g} where role_name like "%%_aqb" and header like "%%X-Powered-By-Anquanbao: HIT %%" and fun_ipseg(client_ip)='$kip' $sqlplus/;

        my $recs = $dbh->query($sql);
        for (my $i = 0; $i <= $#$recs; $i++) {
            my ($url, $main_id);
            $url = $recs->[$i][URL];
            $main_id = $recs->[$i][MAIN_ID];
            my ($ip_cli, $ip_aqb, $ip_org, $isfast) = compare_downspeed($url, $main_id);
            if ($ip_cli && $ip_aqb && $ip_org) {
                find_fast_pos($ip_cli, $ip_aqb, $ip_org, $isfast);
            }

            last if ++$cnt > 1000;
        }
        
        last;
    }


    generate_pos_log($pos_c_a_href, "/tmp/pos_cli_aqb.txt");
    generate_pos_log($pos_c_o_href, "/tmp/pos_cli_org.txt");
    
    printf(Dumper($pos_c_a_href)) if $debug;
    printf(Dumper($pos_c_o_href)) if $debug;

    return 1;
}

#
# main start
#
$ipos = BMD::IPOS->new();
$ipos->load("/opt/ip_pos.db");

$dbh = BMD::DBH->new(
    'dbhost' => '116.213.78.228',
    'dbuser' => 'cesutest',
    'dbpass' => 'cesutest',
    #'dbuser' => 'cesureadonly',
    #'dbpass' => '66ecf9c968132321a02e6e7aff34ce5d',
    'dbname' => 'speed',
    'dbport' => 3306
);

#view_hit_from_clusters();

view_hit_from_clients();

$dbh->fini();

1;

# vim: ts=4:sw=4:et

