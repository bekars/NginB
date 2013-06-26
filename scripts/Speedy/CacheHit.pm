#!/usr/bin/perl -w
###################################################
## Speedy::CacheHit
##
## Cache Hit statistic
## analysis cache resource
###################################################

package Speedy::CacheHit;
require Exporter;
use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);

use strict;
use utf8;
use autodie;
use Encode;
use Try::Tiny;
use Data::Dumper;
use Speedy::Speedy;
use BMD::EXCEL;
use BMD::MAIL;

@ISA = qw(Speedy::Speedy);

#
# {site}
#       site
#           {cnt}
#           {flow}
#           {miss}
#           {miss_flow}
#           {hit}
#           {hit_flow}
#           {expire}
#           {expire_flow}
#           {nocache}
#           {nocache_flow}
#           {cachehit}
#           {cachehit_flow}
#           {cacherate}
#           {cacherate_flow}
# {total}
#       {cnt}
#       {flow}
#       {miss}
#       {miss_flow}
#       {hit}
#       {hit_flow}
#       {expire}
#       {expire_flow}
#       {nocache}
#       {nocache_flow}
#       {cachehit}
#       {cachehit_flow}
#       {cacherate}
#       {cacherate_flow}
#
my $_cachehit = undef;

sub new()
{
    my $self = Speedy::Speedy->new(mod=>'CacheHit', filename=>'cachehit.txt');
    $self->{cachehit} = $_cachehit;
    bless($self);
    return $self;
}

my $_remote_ip = undef;
my $_log_cnt = 0;
sub analysis($)
{
    my $self = shift;
    my $node_h = shift;
    return if (!defined($node_h));

    $node_h->{cache_status} = 'nocache' if $node_h->{cache_status} eq "-";
    $node_h->{cache_status} =~ tr/[A-Z]/[a-z]/;

    if (($node_h->{http_status} eq "404") ||
        ($node_h->{cache_control} =~ m/private|no-cache|no-store/i) ||
        ($node_h->{agent} =~ m/aqb_prefetch/i) ||
        ($node_h->{agent} =~ m/aqb-monitor/i))
    {
        return;
    }

    $_cachehit->{total}{cnt} += 1;
    $_cachehit->{total}{flow} += $node_h->{body_len};
    $_cachehit->{total}{"$node_h->{cache_status}"} += 1;
    $_cachehit->{total}{"$node_h->{cache_status}_flow"} += $node_h->{body_len};

    $_cachehit->{site}{"$node_h->{domain}"}{cnt} += 1;
    $_cachehit->{site}{"$node_h->{domain}"}{flow} += $node_h->{body_len};
    $_cachehit->{site}{"$node_h->{domain}"}{"$node_h->{cache_status}"} += 1;
    $_cachehit->{site}{"$node_h->{domain}"}{"$node_h->{cache_status}_flow"} += $node_h->{body_len};

    $_remote_ip->{$node_h->{remote_ip}} += 1;
    ++$_log_cnt;
    return 1;
}

sub init()
{
    my $self = shift;
}

sub _cal_hitrate($)
{
    my $data = shift;
    my $hitrate = undef;
    my ($hit, $miss, $expired, $nocache, $hit_flow, $miss_flow, $expired_flow, $nocache_flow, $total, $total_flow) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

    $data->{hit}           = 0 if (!exists($data->{hit}));
    $data->{miss}          = 0 if (!exists($data->{miss}));
    $data->{expired}       = 0 if (!exists($data->{expired}));
    $data->{nocache}       = 0 if (!exists($data->{nocache}));
    $data->{hit_flow}      = 0 if (!exists($data->{hit_flow}));
    $data->{miss_flow}     = 0 if (!exists($data->{miss_flow}));
    $data->{expired_flow}  = 0 if (!exists($data->{expired_flow}));
    $data->{nocache_flow}  = 0 if (!exists($data->{nocache_flow}));

    $hit          = $data->{hit}; 
    $miss         = $data->{miss}; 
    $expired      = $data->{expired};
    $nocache      = $data->{nocache};
    $hit_flow     = $data->{hit_flow};
    $miss_flow    = $data->{miss_flow};
    $expired_flow = $data->{expired_flow};
    $nocache_flow = $data->{nocache_flow};
        
    $total = ($hit + $miss + $expired);
    $total_flow = ($hit_flow + $miss_flow + $expired_flow);

    if (0 == $total) {
        $data->{cachehit} = -1;
    } else {
        $data->{cachehit} = _round($hit * 100 / $total);
    }

    if (0 == $total_flow) {
        $data->{cachehit_flow} = -1;
    } else {
        $data->{cachehit_flow} = _round($hit_flow * 100 / $total_flow);
    }

    if ((0 == $data->{cnt}) || (0 == $data->{flow})) 
    {
        $data->{cacherate} = -1;
        $data->{cacherate_flow} = -1;
    } else {
        $data->{cacherate} = _round($hit * 100 / $data->{cnt});
        $data->{cacherate_flow} = _round($hit_flow * 100 / $data->{flow});
    }

    return $data;
}

sub _log_file($$$)
{
    my ($fp, $name, $data) = @_;
    printf($fp "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", 
        $name,
        $data->{cachehit}, 
        $data->{cachehit_flow}, 
        $data->{cacherate}, 
        $data->{cacherate_flow}, 
        $data->{hit}, 
        $data->{hit_flow}, 
        $data->{miss}, 
        $data->{miss_flow}, 
        $data->{expired}, 
        $data->{expired_flow}, 
        $data->{nocache}, 
        $data->{nocache_flow}, 
        $data->{cnt}, 
        $data->{flow}
    );
}

sub fini()
{
    my $self = shift;
    my $total = 0;
    my $total_flow = 0;

    open(my $fp, ">$self->{basedir}/$self->{filename}") or return;

    foreach my $key (sort {$_cachehit->{site}{$b}{cnt}<=>$_cachehit->{site}{$a}{cnt}} keys %{$_cachehit->{site}}) {
        $_cachehit->{site}{$key} = _cal_hitrate($_cachehit->{site}{$key});
        _log_file($fp, $key, $_cachehit->{site}{$key});
    }
    
    $_cachehit->{total} = _cal_hitrate($_cachehit->{total});
    _log_file($fp, "ALL", $_cachehit->{total});
 
    close($fp);
}

sub send_mail()
{
    my $self = shift;
    my $mail_to = [
        'yu.bai@unlun.com',
    ];

    my $date = `date -d"-1 day" +"%Y%m%d"`;
    $date =~ tr/\n//d;
    $date =~ tr/\r//d;
    my $site = "test.weiweimeishi.com";
    my $mail = BMD::MAIL->new();
    my $content = "[$site]\n总流量：\t%sMB\n节省流量：\t%sMB\n缓存率：\t%s%%\n" . 
                  "缓存命中率：\t%s%%\n独立访问客户端数：\t%d\n" .
                  "总访问次数：\t%d\n";
    
    foreach my $k (keys %{$_cachehit->{site}}) {
        if ($k eq $site) {
            my $flow = _round($_cachehit->{site}{$k}{flow} / 1024 / 1024);
            my $flow_save = _round($flow * $_cachehit->{site}{$k}{cacherate_flow} / 100);
            my $total_remote = keys %$_remote_ip;

            $content = sprintf($content, 
                $flow, $flow_save, $_cachehit->{site}{$k}{cacherate_flow}, 
                $_cachehit->{site}{$k}{cachehit}, $total_remote, $_log_cnt);
            last;
        }
    }
    $mail->send_mail("[火花下载]每日统计_$date", $content, undef, $mail_to);
    $mail->destroy();
}

sub store()
{
    my $self = shift;
}

sub destroy()
{
    my $self = shift;
}

1;

# vim: ts=4:sw=4:et

