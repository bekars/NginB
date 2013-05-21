#!/usr/bin/perl -w
# 统计HIT之后下载比源站慢的节点，以及下载文件大小的统计数据

use strict;
use 5.010;
use Speedy::Utils;
use Data::Dumper;
use BMD::DBH;
use BMD::IPOS;
use Time::Interval;

my $keyword = "total_time";

my $today   = `date -d "-1 day" +"%Y-%m-%d"`;
$today      =~ tr/\n//d;

my $date_g = "20130520";

# record cluster data
my $cluster_href;

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
};

my $ipos = BMD::IPOS->new();
$ipos->load("/opt/ip_pos.db");

my $dbh = BMD::DBH->new(
    'dbhost' => '116.213.78.228',
    'dbuser' => 'cesutest',
    'dbpass' => 'cesutest',
    #'dbuser' => 'cesureadonly',
    #'dbpass' => '66ecf9c968132321a02e6e7aff34ce5d',
    'dbname' => 'speed',
    'dbport' => 3306
);

sub list_hit_clusters()
{
    # find hit clusters
    my $sql = qq/select fun_ipseg(role_ip),count(*) as c from speed_res_data_${date_g} where role_name like "%%_aqb" and header like "%%X-Powered-By-Anquanbao: HIT %%" and fun_ipseg(role_ip)!='0.0.0' group by fun_ipseg(role_ip) order by c desc/;
    
    my $recs = $dbh->query($sql);
    for (my $i = 0; $i <= $#$recs; $i++) {
        $cluster_href->{$recs->[$i][0]}{hit_cnt} = $recs->[$i][1];
    }

    return 1;
}

sub compare_hit_url($) 
{
    my $clusterip = shift;
    my $downkbs_aqb;
    my $downkbs_org;
    my $roleip_aqb;
    my $roleip_org;
    my ($url, $main_id, $filesize);

    # select hit url on cluster
    my $sql = qq/select url,role_id,stat_main_id,role_ip,down_speed_kbs,city_code,client_ip,down_size_bytes,monitor_time from speed_res_data_${date_g} where role_name like "%%_aqb" and header like "%%X-Powered-By-Anquanbao: HIT %%" and fun_ipseg(role_ip)='$clusterip'/;

    my $recs = $dbh->query($sql);
    for (my $i = 0; $i <= $#$recs; $i++) {
        $url = $recs->[$i][URL];
        $main_id = $recs->[$i][MAIN_ID];
        $downkbs_aqb = $recs->[$i][DOWNSPEED];
        $roleip_aqb = $recs->[$i][ROLE_IP];
        $filesize = $recs->[$i][DOWNSIZE];

        ($downkbs_org, $roleip_org) = get_org_downspeed($url, $main_id);
        if ($downkbs_org && $roleip_org) {
            printf("$url $main_id $downkbs_aqb $roleip_aqb $downkbs_org $roleip_org\n");
            
            foreach my $k (sort keys %file_size) {
                if (($filesize > ($k * 1000)) && ($filesize <= ($file_size{$k} * 1000))) {
                    if ($downkbs_aqb >= $downkbs_org) {
                        $cluster_href->{$clusterip}{"filesize_$k"}{fast} += 1;
                        $cluster_href->{$clusterip}{fast_cnt} += 1;
                    } else {
                        $cluster_href->{$clusterip}{"filesize_$k"}{slow} += 1;
                        $cluster_href->{$clusterip}{slowip}{$recs->[$i][CLIENT_IP]} += 1;
                        $cluster_href->{$clusterip}{slow_cnt} += 1;
                    }

                    $cluster_href->{$clusterip}{"filesize_$k"}{total} += 1;
                    $cluster_href->{$clusterip}{"filesize_$k"}{aqb}{total_kbs} += $downkbs_aqb;
                    $cluster_href->{$clusterip}{"filesize_$k"}{org}{total_kbs} += $downkbs_org;

                    last;
                }
            }
        }
    }

    return 1;
}

sub get_org_downspeed($$)
{
    my ($url, $main_id) = @_;

    # select same stat_main_id
    my $sql = qq/select url,role_id,stat_main_id,role_ip,down_speed_kbs,city_code,client_ip,down_size_bytes,monitor_time from speed_res_data_${date_g} where role_name like '%%_ip' and url='$url' and stat_main_id=$main_id/;

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

        if (exists($cluster_href->{$k}{fast_cnt})) {
            printf($fp "%.2f\t%d\n", 
                $cluster_href->{$k}{fast_cnt} * 100 / ($cluster_href->{$k}{fast_cnt} + $cluster_href->{$k}{slow_cnt}), $cluster_href->{$k}{hit_cnt});
        } else {
            printf($fp "N/A\tN/A\n");
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

        printf($fp "[%s %s %d]\n", $k, join(",", get_ipseg_pos($k)), $slow_cnt);

        foreach my $p (sort {$cluster_href->{$k}{slowip}{$b} <=> $cluster_href->{$k}{slowip}{$a}} keys %{$cluster_href->{$k}{slowip}}) {
            ($country, $province, $isp) = get_ipseg_pos($p);
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

sub get_ipseg_pos($)
{
    my $ipseg = shift;
    return $ipos->query("$ipseg.1");
}

#
# main start
#
list_hit_clusters();

foreach my $k (sort{$cluster_href->{$b}{hit_cnt} <=> $cluster_href->{$a}{hit_cnt}} keys %$cluster_href) {
    printf("$k => $cluster_href->{$k}{hit_cnt}\n");
    compare_hit_url($k);
    #last;
}

printf(Dumper($cluster_href));

gen_speed_excel_data();
gen_client_excel_data();

$dbh->fini();

1;

# vim: ts=4:sw=4:et

