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
use BMD::EXCEL;
use BMD::MAIL;

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
#   "total"
#       "cnt"                   - 总访问次数
#       "rate"                  - 总访问比例
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
#   "total"
#       "cnt"                   - 总访问次数
#       "rate"                  - 总访问比例
my $_cluster_h = {};

# KEY: region
#   "cluster"
#       cluster
#           "cnt"               - 访问cluster次数
#           "rate"              - 访问cluster比例
#   "total"
#       "cnt"                   - 总访问次数
#       "rate"                  - 总访问比例
my $_region_h = {};

my $_ip_pos_h = {};

my $_ipos = undef;
my $_aqb = undef;

sub new()
{
    my $self = Speedy::Speedy->new(
        mod      => 'ClientPos', 
        filename => 'client_pos.xls',
        basedir  => '/home/apuadmin/baiyu',
    );
    bless($self);
    return $self;
}

sub _download_rate($)
{
    my $node_h = shift;
    my $min_len = 10000;

    if (($node_h->{cache_status} eq "HIT") &&
        ($node_h->{http_status} eq "200") && 
        ($node_h->{body_len} > $min_len) && 
        ($node_h->{req_time} > 0.01)) 
    {
        return _round(($node_h->{body_len} / $node_h->{req_time}), 2);
    }

    return 0;
}

my $_site_region = ();
sub get_site_region($$)
{
    my ($site, $ip_str) = @_;

    return $_site_region->{$site} if exists($_site_region->{$site}); 

    my @ip_arr = split(",", $ip_str);
    my $ipos = $_ipos->query($ip_arr[0]);
    $_site_region->{$site} = $_ipos->format_region($ipos);
    return $_site_region->{$site}; 
}

sub analysis($)
{
    my $self = shift;
    my $node_h = shift;
    return unless defined($node_h);
    return if (($node_h->{cluster} eq "cscs") or ($node_h->{cluster_room} eq "cscs"));

    my ($cluster_info, $cluster_str);
    my ($site_info, $site_region, $site_str);

    my $ipseg = _get_ipseg($node_h->{remote_ip});

    $site_info = $_aqb->get_site_info($node_h->{domain});
    if ($site_info) {
        $site_region = get_site_region($node_h->{domain}, $site_info->{ip});
        $site_str = "$node_h->{domain}($site_region)";
    } else {
        $site_str = "$node_h->{domain}";
    }
    $_site_h->{$site_str}{ipseg}{$ipseg}{cnt} += 1;
 
    $cluster_info = $_aqb->get_cluster_info($node_h->{cluster});
    if ($cluster_info) {
        $cluster_str = "$node_h->{cluster_room}($cluster_info->{location})";
    } else {
        # 没有cluster位置信息打印
        printf("### NO CLUSTER $node_h->{cluster} INFO!\n");
        #printf(Dumper($node_h));

        if ($node_h->{cluster_room}) {
            $cluster_str = "$node_h->{cluster_room}";
        } else {
            $cluster_str = "$node_h->{cluster}";
        }
    }
    $_cluster_h->{$cluster_str}{ipseg}{$ipseg}{cnt} += 1;

    # calculte download rate
    my $drate = _download_rate($node_h);
    if ($drate > 0) {
        $_site_h->{$site_str}{ipseg}{$ipseg}{download_rate} += $drate;
        $_site_h->{$site_str}{ipseg}{$ipseg}{download_cnt} += 1;

        $_cluster_h->{$cluster_str}{ipseg}{$ipseg}{download_rate} += $drate;
        $_cluster_h->{$cluster_str}{ipseg}{$ipseg}{download_cnt} += 1;
    }

    return 1;
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
    # convert ip to region
    _analysis_ip_region($_site_h, $self);
}

# rtt.db
# cluster_room|region|rtt|rtt_rate
#
# cluster_room
#   region
#       {rtt}
#       {rate}
#
my $_rtt_h = undef;
sub _load_rtt()
{
    open(my $fp, "</home/apuadmin/baiyu/rtt.db");
    while (<$fp>) {
        $_ =~ tr/\n//d;
        $_ =~ tr/\r//d;
        my @arr = split(/\|/, $_);
        next unless ($#arr == 3);
        $_rtt_h->{$arr[0]}{$arr[1]}{rtt} = $arr[2];
        $_rtt_h->{$arr[0]}{$arr[1]}{rtt_rate} = $arr[3];
    }
        
    #printf(Dumper($_rtt_h));
    close($fp);
}
 

use constant {
    RTT   => 1,
    NORTT => 0,
    SELECTOR => 1,
    NO_SELECTOR => 0,
};

sub tofile()
{
    my $self = shift;
    my $file_xls = "$self->{basedir}/$self->{filename}";
    my $excel_hld = BMD::EXCEL->new(filename=>"$file_xls");
    $self->{excel_hld} = $excel_hld;

    # load rtt data
    _load_rtt();

    # analysis client position
    my $allpos_h = _analysis_clipos($self, "节点(下载速度|延时|访问比例)", $_cluster_h, RTT);

    # select cluster to service region
    _analysis_cluster($self, "优先调度节点", $_cluster_h, $allpos_h);
    
    # analysis region => cluster
    _analysis_region($self, "区域访问节点", $_cluster_h);

    #_analysis_clipos($self, "源站(下载速度|访问比例)", $_site_h, NORTT);
    
    $self->{excel_hld}->destroy();
}

sub send_mail()
{
    my $self = shift;
    my $file_xls = "$self->{basedir}/$self->{filename}";
    my $mail = BMD::MAIL->new();
    $mail->send_mail("dnspod访问区域和下载速度", "dnspod访问区域和下载速度统计数据", $file_xls);
    $mail->destroy();
}

#
# ip => region
#
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
        my $ipos = $_ipos->query($k1);

        # 只计算电信和联通线路
        my $position = $_ipos->format_known_isp($ipos);
        next LOOP unless $position;

        $n += 1;
        printf("$n/$ip_cnt\t$k1\t$position\n") if $self->{debug};

        $_ip_pos_h->{$k1} = $position;
    }

    return 1;
}

use constant { MAX_PERCENT => 70 };
sub _analysis_cluster($$$$)
{
    my ($self, $name, $cluster_h, $allpos_h) = @_;
    my $selector_h = {};
    my $region_h = {};

    my $total = 0;
    # 找出所有region
    foreach my $k (sort {$allpos_h->{$b}<=>$allpos_h->{$a}} keys %$allpos_h) {
        $total += $allpos_h->{$k};
        last if $total > MAX_PERCENT; 
        $region_h->{$k} = $allpos_h->{$k};
    }

    # 找出所有区域访问最快的节点
    foreach my $kreg (sort {$region_h->{$b}<=>$region_h->{$a}} keys %$region_h) {
        my $max_speed = 0;
        my $min_rtt = 9999;
        my $select_clu = undef;

        # 有rtt按rtt算，没有rtt用downspeed算
        foreach my $kclu (keys %$cluster_h) {
            if (exists($cluster_h->{$kclu}{pos}{$kreg})) {
                if ((9999 == $min_rtt) && 
                    exists($cluster_h->{$kclu}{pos}{$kreg}{download_rate}) && 
                    ($cluster_h->{$kclu}{pos}{$kreg}{download_rate} > $max_speed)) 
                {
                    $max_speed = $cluster_h->{$kclu}{pos}{$kreg}{download_rate};
                    $select_clu = $kclu;
                }

                if (exists($_rtt_h->{$kclu}{$kreg}{rtt}) && 
                    ($_rtt_h->{$kclu}{$kreg}{rtt} > 0) &&
                    ($_rtt_h->{$kclu}{$kreg}{rtt} < $min_rtt))
                {
                    $min_rtt = $_rtt_h->{$kclu}{$kreg}{rtt};
                    $select_clu = $kclu;
                }
            }
        }

        if ($select_clu) {
            my ($downspeed, $percent, $rtt, $rtt_rate) = (0, 0, 0, 0);
            if (exists($cluster_h->{$select_clu}{pos}{$kreg}{download_rate})) {
                $downspeed = $cluster_h->{$select_clu}{pos}{$kreg}{download_rate};
                $percent = _round($cluster_h->{$select_clu}{pos}{$kreg}{rate}, 2);
            }
            if (exists($_rtt_h->{$select_clu}{$kreg}{rtt})) {
                $rtt = $_rtt_h->{$select_clu}{$kreg}{rtt};
                $rtt_rate = $_rtt_h->{$select_clu}{$kreg}{rtt_rate};
            }
            $selector_h->{$select_clu}{$kreg}{downspeed} = $downspeed;
            $selector_h->{$select_clu}{$kreg}{percent} = $percent;
            $selector_h->{$select_clu}{$kreg}{rtt} = $rtt;
            $selector_h->{$select_clu}{$kreg}{rtt_rate} = $rtt_rate;
        }
    }

    #printf(Dumper($selector_h));
    _log_selector_excel($self, $name, $selector_h, $region_h, $cluster_h);

}

sub _log_selector_excel($$$$$)
{
    my ($self, $name, $selector_h, $region_h, $cluster_h) = @_;
    my ($row, $col, $total) = (0, 0, 0);

    my $excel_hld = $self->{excel_hld};
    my $sheet = $excel_hld->add_sheet($name);
    $excel_hld->set_column_width($sheet, 0, 0, 20);
    $excel_hld->set_column_width($sheet, 1, 1000, 15);

    $excel_hld->write($sheet, $row, $col, "客户端区域", "black", "yellow");
    foreach my $k (sort {$region_h->{$b}<=>$region_h->{$a}} keys %$region_h) {
        ++$col;
        $excel_hld->write($sheet, $row, $col, "$k", "black", "yellow");
    }
    
    $col = 0;
    ++$row;
    $excel_hld->write($sheet, $row, $col, "区域访问百分比", "black", "yellow");
    foreach my $k (sort {$region_h->{$b}<=>$region_h->{$a}} keys %$region_h) {
        ++$col;
        $excel_hld->write($sheet, $row, $col, "$region_h->{$k}%", "black", "yellow");
    }

    foreach my $kclu (sort {$cluster_h->{$b}{total}{rate}<=>$cluster_h->{$a}{total}{rate}} keys %$cluster_h) 
    {
        # 没有选中的节点不显示
        next unless exists($selector_h->{$kclu});

        $col = 0;
        ++$row;
        $excel_hld->write($sheet, $row, $col, "$kclu");
        foreach my $kreg (sort {$region_h->{$b}<=>$region_h->{$a}} keys %$region_h) 
        {
            ++$col;
            if (exists($selector_h->{$kclu}{$kreg})) {
                my $downspeed = $selector_h->{$kclu}{$kreg}{downspeed};
                my $percent = $selector_h->{$kclu}{$kreg}{percent};
                my $rtt = $selector_h->{$kclu}{$kreg}{rtt};
                my $rtt_rate = $selector_h->{$kclu}{$kreg}{rtt_rate};
                my ($text, $color) = _color_data($kclu, $kreg, $downspeed, $percent, RTT, SELECTOR);
                if ($color) {
                    $excel_hld->write($sheet, $row, $col, $text, "black", $color);
                } else {
                    $excel_hld->write($sheet, $row, $col, $text);
                }
            }
        }
    }
    
    _show_help($self, $sheet, $row, $col);
}

sub _analysis_region($$$)
{
    my ($self, $name, $cluster_h) = @_;
    my $total = 0;

    # 计算每个区域访问各个cluster的次数
    foreach my $kipseg (sort keys %$_ip_pos_h) {
        my $region = $_ip_pos_h->{$kipseg};

        foreach my $kclu (keys %$cluster_h) {
            if (exists($cluster_h->{$kclu}{ipseg}{$kipseg})) {
                $_region_h->{$region}{cluster}{$kclu}{cnt} += $cluster_h->{$kclu}{ipseg}{$kipseg}{cnt};
            }
        }
    }

    # 计算每个区域访问各个cluster的百分比
    foreach my $kreg (sort keys %$_region_h) {
        $total = 0;

        foreach my $kclu (keys %{$_region_h->{$kreg}{cluster}}) {
            $total += $_region_h->{$kreg}{cluster}{$kclu}{cnt};
        }
        
        foreach my $kclu (keys %{$_region_h->{$kreg}{cluster}}) {
            $_region_h->{$kreg}{cluster}{$kclu}{rate} = $_region_h->{$kreg}{cluster}{$kclu}{cnt} * 100 / $total;
        }
    }

    # 统计每个区域的访问次数和百分比
    foreach my $kreg (sort keys %$_region_h) {
        foreach my $kclu (keys %{$_region_h->{$kreg}{cluster}}) {
            $_region_h->{$kreg}{total}{cnt} += $_region_h->{$kreg}{cluster}{$kclu}{cnt};
        }
    } 
 
    $total = 0;
    foreach my $kreg (sort keys %$_region_h) {
        $total += $_region_h->{$kreg}{total}{cnt};
    }
    foreach my $kreg (sort keys %$_region_h) {
        $_region_h->{$kreg}{total}{rate} = _round(($_region_h->{$kreg}{total}{cnt} * 100) / $total, 2)
    }

    # generate excel
    _log_region_excel($self, $name, $cluster_h, $_region_h);

    return 1;
}

sub _log_region_excel($$$$)
{
    my ($self, $name, $cluster_h, $region_h) = @_;
    my ($row, $col) = (0, 0);

    my $excel_hld = $self->{excel_hld};
    my $sheet = $excel_hld->add_sheet($name);
    $excel_hld->set_column_width($sheet, 0, 0, 16);
    $excel_hld->set_column_width($sheet, 2, 1000, 17);

    $excel_hld->write($sheet, $row, $col, "客户端位置\\机房", "black", "yellow");
    ++$col;
    $excel_hld->write($sheet, $row, $col, "访问比例", "black", "cyan");
    foreach my $kclu (sort keys %$cluster_h) {
        ++$col;
        $excel_hld->write($sheet, $row, $col, "$kclu", "black", "yellow");
    }
 
    foreach my $kreg (sort {$region_h->{$b}{total}{rate} <=> $region_h->{$a}{total}{rate}} keys %$region_h) {
        $col = 0;
        ++$row;
        $excel_hld->write($sheet, $row, $col, "$kreg");
        ++$col;
        $excel_hld->write($sheet, $row, $col, "$region_h->{$kreg}{total}{rate}%", "black", "cyan", "right");
        
        foreach my $kclu (sort keys %$cluster_h) {
            ++$col;
            if (exists($region_h->{$kreg}{cluster}{$kclu}{rate})) {
                my $rate = _round($region_h->{$kreg}{cluster}{$kclu}{rate}, 2);
                if ($rate >= 5) {
                    $excel_hld->write($sheet, $row, $col, "${rate}%", "black", "lime");
                } else {
                    $excel_hld->write($sheet, $row, $col, "${rate}%");
                }
            } else {
                $excel_hld->write($sheet, $row, $col, "N/A");
            }
        }
    }
}

sub _analysis_clipos($$$$)
{
    my ($self, $name, $data_h, $is_rtt) = @_;
    my $total = 0;
    my $allip_h = {};
    my $allpos_h = {};

    # 计算每个节点/网站在各个ip段的访问百分比
    foreach my $k1 (keys %$data_h) {
        $total = 0;
        my $ipseg_h = $data_h->{$k1}{ipseg};
        
        foreach my $kipseg (keys %$ipseg_h) {
            next unless exists($_ip_pos_h->{$kipseg});
            $total += $ipseg_h->{$kipseg}{cnt} if $kipseg;
        }
 
        foreach my $kipseg (keys %$ipseg_h) {
            next unless exists($_ip_pos_h->{$kipseg});
            $ipseg_h->{$kipseg}{rate} = ($ipseg_h->{$kipseg}{cnt} * 100 / $total);
            
            # 统计不同ip段地址
            $allip_h->{$kipseg} += $ipseg_h->{$kipseg}{cnt};
        }
    }

    # 将ip段地址转成物理位置
    LOOP: foreach my $k1 (sort keys %$allip_h) {
        next LOOP unless exists($_ip_pos_h->{$k1});

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

    # 计算各节点/源站访问总次数和比例
    foreach my $k1 (keys %$data_h) {
        $total = 0;
        foreach my $k2 (keys %$allpos_h) {
            $total += $data_h->{$k1}{pos}{$k2}{cnt} if (exists($data_h->{$k1}{pos}{$k2}{cnt}));
        }
        $data_h->{$k1}{total}{cnt}  = $total;
        $data_h->{$k1}{total}{rate} = _round($total * 100 / $total_cnt, 2);
    }

    # generate excel
    _log_cnt_download_excel($self, $name, $allpos_h, $data_h, $total_cnt, $is_rtt);

    return $allpos_h;
}

my $_color = {
    black     =>    8,
    blue      =>   12,
    brown     =>   16,
    cyan      =>   15,
    gray      =>   23,
    green     =>   17,
    lime      =>   11,
    magenta   =>   14,
    navy      =>   18,
    orange    =>   53,
    pink      =>   33,
    purple    =>   20,
    red       =>   10,
    silver    =>   22,
    white     =>    9,
    yellow    =>   13,
};

sub _log_cnt_download_excel($$$$$$)
{
    my ($self, $name, $allpos_h, $data_h, $total_cnt, $is_rtt) = @_;
    my ($row, $col, $total) = (0, 0, 0);

    my $excel_hld = $self->{excel_hld};
    my $sheet = $excel_hld->add_sheet($name);
    $excel_hld->set_column_width($sheet, 0, 0, 20);
    $excel_hld->set_column_width($sheet, 2, 1000, 12);

    $excel_hld->write($sheet, $row, $col, "客户端区域", "black", "yellow");
    ++$col;
    $excel_hld->write($sheet, $row, $col, "访问比例", "black", "cyan");
    foreach my $k (sort {$allpos_h->{$b}<=>$allpos_h->{$a}} keys %$allpos_h) {
        ++$col;
        $excel_hld->write($sheet, $row, $col, "$k", "black", "yellow");
    }
    
    $col = 0;
    ++$row;
    $excel_hld->write($sheet, $row, $col, "区域访问百分比", "black", "yellow");
    ++$col;
    $excel_hld->write($sheet, $row, $col, $total_cnt, "black", "cyan");
    foreach my $k (sort {$allpos_h->{$b}<=>$allpos_h->{$a}} keys %$allpos_h) {
        ++$col;
        $excel_hld->write($sheet, $row, $col, "$allpos_h->{$k}%", "black", "yellow");
    }

    foreach my $k1 (sort {$data_h->{$b}{total}{rate}<=>$data_h->{$a}{total}{rate}} keys %$data_h) 
    {
        $col = 0;
        ++$row;
        $excel_hld->write($sheet, $row, $col, "$k1");
        ++$col;
        $excel_hld->write($sheet, $row, $col, "$data_h->{$k1}{total}{rate}%", "black", "cyan", "right");
        foreach my $k2 (sort {$allpos_h->{$b}<=>$allpos_h->{$a}} keys %$allpos_h) 
        {
            ++$col;
            my ($rate, $downspeed);
            if (exists($data_h->{$k1}{pos}{$k2}{rate})) {
                $rate = _round($data_h->{$k1}{pos}{$k2}{rate}, 2);
            } else {
                $rate = 0;
            }
                
            if (exists($data_h->{$k1}{pos}{$k2}{download_rate})) {
                $data_h->{$k1}{pos}{$k2}{download_rate} = _round($data_h->{$k1}{pos}{$k2}{download_rate} / $data_h->{$k1}{pos}{$k2}{download_cnt} / 1024, 2);
                $downspeed = $data_h->{$k1}{pos}{$k2}{download_rate};
            } else {
                $downspeed = 0;
            }

            my ($text, $color) = _color_data($k1, $k2, $downspeed, $rate, $is_rtt, NO_SELECTOR);
            if ($color) {
                $excel_hld->write($sheet, $row, $col, $text, "black", $color);
            } else {
                $excel_hld->write($sheet, $row, $col, $text);
            }
        }
    }
    
    _show_help($self, $sheet, $row, $col);
}

sub _show_help($$$$)
{
    my ($self, $sheet, $row, $col) = @_;
    my $excel_hld = $self->{excel_hld};

    $row += 5;
    $col = 0;
    foreach my $kcolor (sort keys %$_color) {
        $excel_hld->write($sheet, $row, $col, "", "black", $kcolor);
        ++$col;
    }
    $row += 2;
    $col = 0;
    $excel_hld->write($sheet, $row, $col, "访问量>5%, GOOD", "black", "lime");
    ++$row;
    $excel_hld->write($sheet, $row, $col, "访问量>5%, 下载<700KB/s", "black", "red");
    ++$row;
    $excel_hld->write($sheet, $row, $col, "访问量>5%, RTT>40ms或者RTT<40ms百分比小于80%", "black", "pink");
    ++$row;
    $excel_hld->write($sheet, $row, $col, "被选择节点但访问量小于5%", "black", "orange");
}

sub _color_data($$$$$$)
{
    my ($cluster, $region, $downspeed, $rate, $is_rtt, $is_selector) = @_;
    my ($text, $color) = ("", "white");
    my ($rtt_time, $rtt_rate) = (0, 0);

    if ($is_rtt && exists($_rtt_h->{$cluster}{$region}{rtt})) {
        $rtt_time = $_rtt_h->{$cluster}{$region}{rtt};
        $rtt_rate = $_rtt_h->{$cluster}{$region}{rtt_rate};
        $text = "${downspeed}|${rtt_time}|${rtt_rate}%|${rate}%";
    } else {
        if (!$rate && !$downspeed) {
            $text = "";
        } else {
            $text = "${downspeed}|${rate}%";
        }
    }

    #
    # over 5% to color, bad is:
    # 1. download rate < 700 or
    # 2. rtt < 40ms and below 80% or
    # 3. rtt > 40ms
    #
    if (!$is_selector && ($rate >= 5)) {
        if (($rtt_time > 0) && (($rtt_rate < 80 && $rtt_time < 40) || ($rtt_time > 40))) {
            $color = "pink";
        } elsif ($downspeed > 0 && $downspeed < 700) {
            $color = "red";
        } else {
            $color = "lime";
        }
    }

    if ($is_selector) {
        if (($rtt_time > 0) && (($rtt_rate < 80 && $rtt_time < 40) || ($rtt_time > 40))) {
            $color = "pink";
        } elsif ($downspeed > 0 && $downspeed < 700) {
            $color = "red";
        } elsif ($rate < 5) {
            $color = "orange";
        } else {
            $color = "lime";
        }
    }

    return ($text, $color);
}

sub tostore()
{
    my $self = shift;
    my $data_ref = undef;
    $data_ref->{_site_h}    = $_site_h;
    $data_ref->{_cluster_h} = $_cluster_h;
    $data_ref->{_region_h}  = $_region_h;
    $data_ref->{_ip_pos_h}  = $_ip_pos_h;

    my $file = "$self->{basedir}/$self->{mod}.store";
    return _tostore($data_ref, $file);
}

sub restore()
{
    my $self = shift;
    my $file = "$self->{basedir}/$self->{mod}.store";

    $_site_h    = undef;
    $_cluster_h = undef;
    $_region_h  = undef;
    $_ip_pos_h  = undef;

    my $data_ref = _restore($file);
    die "ERR: restore $self->{basedir}/$self->{mod}.store fail!" unless $data_ref;

    $_site_h    = $data_ref->{_site_h};
    $_cluster_h = $data_ref->{_cluster_h};
    $_region_h  = $data_ref->{_region_h};
    $_ip_pos_h  = $data_ref->{_ip_pos_h};

    return 1;
}

sub destroy()
{
    my $self = shift;
    $self->{ipos}->destroy();
}

1;

# vim: ts=4:sw=4:et

