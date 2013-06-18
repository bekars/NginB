#!/usr/bin/perl -w

package Speedy::ClientPos;
require Exporter;
use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);

use strict;
use autodie;
use Try::Tiny;
use Data::Dumper;
use Speedy::Speedy;
use BMD::IPOS;
use BMD::AQB;

@ISA = qw(Speedy::Speedy);

#
# site broswer position
#

# KEY: site 
#   "ipseg"
#       ipseg
#           "cnt"               - ip段访问次数
#           "rate"              - ip段访问次数比例
#           "download_rate"     - ip段下载速率
#           "download_cnt"      - ip段下载次数
#   "pos"
#       position
#           "cnt"               - ip段访问次数
#           "rate"              - ip段访问次数比例
#           "download_rate"     - ip段下载速率
#           "download_cnt"      - ip段下载次数
my $_site_h = {};

# KEY: cluster_room
#   "ipseg"
#       ipseg
#           "cnt"
#           "rate"
#           "download_rate"
#           "download_cnt"
#   "pos"
#       position
#           "cnt"               - ip段访问次数
#           "rate"              - ip段访问次数比例
#           "download_rate"     - ip段下载速率
#           "download_cnt"      - ip段下载次数
my $_cluster_h = {};

my $_ipos = undef;
my $_aqb = undef;

sub new()
{
    my $self = Speedy::Speedy->new();
    bless($self);
    return $self;
}

sub _download_rate($)
{
    my $node_h = shift;

    if (($node_h->{cache_status} eq "HIT") &&
        ($node_h->{http_status} eq "200") && 
        ($node_h->{body_len} > 2000) && 
        ($node_h->{req_time} > 0.01)) 
    {
        return _round(($node_h->{body_len} / $node_h->{req_time}), 2);
    }

    return 0;
}

sub analysis($)
{
    my $self = shift;
    my $node_h = shift;
    return if (!defined($node_h));
    my ($cluster_info, $cluster_str);

    my $ipseg = _get_ipseg($node_h->{remote_ip});
    $_site_h->{$node_h->{domain}}{ipseg}{$ipseg}{cnt} += 1;
    
    $cluster_info = $_aqb->get_cluster_info($node_h->{cluster});
    if ($cluster_info) {
        $cluster_str = "$node_h->{cluster_room}($cluster_info->{location})";
    } else {
        $cluster_str = "$node_h->{cluster_room}";
    }
    $_cluster_h->{$cluster_str}{ipseg}{$ipseg}{cnt} += 1;

    # calculte download rate
    my $drate = _download_rate($node_h);
    if ($drate > 0) {
        $_site_h->{$node_h->{domain}}{ipseg}{$ipseg}{download_rate} += $drate;
        $_site_h->{$node_h->{domain}}{ipseg}{$ipseg}{download_cnt} += 1;

        $_cluster_h->{$cluster_str}{ipseg}{$ipseg}{download_rate} += $drate;
        $_cluster_h->{$cluster_str}{ipseg}{$ipseg}{download_cnt} += 1;
    }

    return 1;
}

sub _private()
{
}

sub init()
{
    my $self = shift;
    $_ipos = BMD::IPOS->new();
    $_ipos->load("/home/apuadmin/baiyu/");
    $self->{ipos} = $_ipos;
    $_aqb = BMD::AQB->new();
    $self->{aqb} = $_aqb;
}

sub fini()
{
    my $self = shift;
    # analysis ip and region
    _analysis_ip_region($_site_h, $self);

    # analysis client position
    _analysis_clipos("site", $_site_h, $self);
    _analysis_clipos("cluster", $_cluster_h, $self);
}

my $_ip_pos_h = {};

sub _analysis_ip_region($$)
{
    my ($data_h, $self) = @_;
    my $allip_h = {};
   
    # find all kind ipseg
    foreach my $k1 (keys %$data_h) {
        my $ipseg_h = $data_h->{$k1}{ipseg};
        foreach my $kipseg (keys %$ipseg_h) {
            $allip_h->{$kipseg} += $ipseg_h->{$kipseg}{cnt};
        }
    }
    
    my $ip_cnt = keys %$allip_h;
    my $n = 0;
    LOOP: foreach my $k1 (sort keys %$allip_h) {
        next LOOP if (!$k1);

        my $ipos = $_ipos->query($k1);
        my $position = $_ipos->format_region($ipos);

        $n += 1;
        printf("$n/$ip_cnt\t$k1\t$position\n") if $self->{debug};

        $_ip_pos_h->{$k1} = $position;
    }

    return 1;
}

sub _analysis_clipos($$$)
{
    my ($name, $data_h, $self) = @_;
    my $total = 0;
    my $allip_h = {};
    my $allpos_h = {};

    # 计算每个网站在各个ip段的访问百分比
    foreach my $k1 (keys %$data_h) {
        $total = 0;
        my $ipseg_h = $data_h->{$k1}{ipseg};
        
        foreach my $kipseg (keys %$ipseg_h) {
            $total += $ipseg_h->{$kipseg}{cnt} if $kipseg;
        }
 
        foreach my $kipseg (keys %$ipseg_h) {
            $ipseg_h->{$kipseg}{rate} = ($ipseg_h->{$kipseg}{cnt} * 100 / $total);
            
            # 统计不同ip段地址
            $allip_h->{$kipseg} += $ipseg_h->{$kipseg}{cnt};
        }
    }

    # 将ip段地址转成物理位置
    LOOP: foreach my $k1 (sort keys %$allip_h) {
        next LOOP if (!$k1);

        my $position = $_ip_pos_h->{$k1};

        # 统计各物理位置访问次数
        $allpos_h->{$position} += $allip_h->{$k1};
    
        # 按每个站统计各物理位置访问，同区域ip段数据合并累计
        foreach my $k2 (keys %$data_h) {
            if (exists($data_h->{$k2}{ipseg}{$k1})) {
                $data_h->{$k2}{pos}{$position}{cnt} += $data_h->{$k2}{ipseg}{$k1}{cnt};
                $data_h->{$k2}{pos}{$position}{rate} += $data_h->{$k2}{ipseg}{$k1}{rate};
                $data_h->{$k2}{pos}{$position}{download_rate} += $data_h->{$k2}{ipseg}{$k1}{download_rate} if exists($data_h->{$k2}{ipseg}{$k1}{download_rate});
                $data_h->{$k2}{pos}{$position}{download_cnt} += $data_h->{$k2}{ipseg}{$k1}{download_cnt} if exists($data_h->{$k2}{ipseg}{$k1}{download_cnt});
            }
        }
    }
    
    # 计算各区域总访问数和比例
    my $total_cnt = 0;
    foreach my $k (keys %$allpos_h) {
        $total_cnt += $allpos_h->{$k}
    }
    foreach my $k (keys %$allpos_h) {
        $allpos_h->{$k} = _round(($allpos_h->{$k} * 100 / $total_cnt), 2);
    }

    # write to log file
    _log_cnt_pos($name, $allpos_h, $data_h, $total_cnt, $self);
    _log_download_pos($name, $allpos_h, $data_h, $self);

    return 1;
}

sub _log_cnt_pos($$$$)
{
    my ($name, $allpos_h, $data_h, $total_cnt, $self) = @_;
    my $total = 0;

    open(my $fp, ">$self->{basedir}/pos_${name}_cnt.txt");
    printf($fp "客户端区域\t所有区域\t");
    foreach my $k (sort {$allpos_h->{$b}<=>$allpos_h->{$a}} keys %$allpos_h) {
        printf($fp "${k}\t");
    }
    printf($fp "\n");

    printf($fp "区域访问百分比\t$total_cnt\t");
    foreach my $k (sort {$allpos_h->{$b}<=>$allpos_h->{$a}} keys %$allpos_h) {
        printf($fp "$allpos_h->{$k}%%\t");
    }
    printf($fp "\n");

    foreach my $k1 (keys %$data_h) {
        $total = 0;
        foreach my $k2 (sort {$allpos_h->{$b}<=>$allpos_h->{$a}} keys %$allpos_h) {
            $total += $data_h->{$k1}{pos}{$k2}{cnt} if (exists($data_h->{$k1}{pos}{$k2}));
        }

        printf($fp "$k1\t$total\t");
        foreach my $k2 (sort {$allpos_h->{$b}<=>$allpos_h->{$a}} keys %$allpos_h) {
            if (exists($data_h->{$k1}{pos}{$k2})) {
                my $rate = _round($data_h->{$k1}{pos}{$k2}{rate}, 2);
                printf($fp "$rate\t");
            } else {
                printf($fp "0\t");
            }
        }
        printf($fp "\n");
    }

    close($fp);
}

sub _log_download_pos($$$$)
{
    my ($name, $allpos_h, $data_h, $self) = @_;

    open(my $fp, ">$self->{basedir}/pos_${name}_download.txt");
    printf($fp "客户端区域\t");
    foreach my $k (sort {$allpos_h->{$b}<=>$allpos_h->{$a}} keys %$allpos_h) {
        printf($fp "${k}\t");
    }
    printf($fp "\n");

    printf($fp "区域访问百分比\t");
    foreach my $k (sort {$allpos_h->{$b}<=>$allpos_h->{$a}} keys %$allpos_h) {
        printf($fp "$allpos_h->{$k}%%\t");
    }
    printf($fp "\n");

    foreach my $k1 (keys %$data_h) {
        printf($fp "$k1\t");
        foreach my $k2 (sort {$allpos_h->{$b}<=>$allpos_h->{$a}} keys %$allpos_h) {
            if (exists($data_h->{$k1}{pos}{$k2}{download_rate})) {
                my $rate = _round($data_h->{$k1}{pos}{$k2}{download_rate} / $data_h->{$k1}{pos}{$k2}{download_cnt} / 1024, 2);
                printf($fp "$rate\t");
            } else {
                printf($fp "0\t");
            }
        }
        printf($fp "\n");
    }

    close($fp);
}

sub destroy()
{
    my $self = shift;
    $self->{ipos}->destroy();
}

sub log($)
{
    my $self = shift;
    my $str = shift;

    printf("CliPos: $self->{basedir} $str\n");
}

1;

# vim: ts=4:sw=4:et

