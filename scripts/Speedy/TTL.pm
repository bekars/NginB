###################################################
## Speedy::TTL
##
## 超时时间统计
## 统计所有资源expired和cache-control: max-age中的超时时间，
## 分为@TTL_a几个区间统计流量和次数。
###################################################


## Global Stuff ###################################
package	Speedy::TTL;
use strict;
use Date::Parse;
require	Exporter;

#class global vars ...
use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw(@TTL_a %expires_h);
@EXPORT_OK	= qw(&ttl_analysis_mod &ttl_analysis_init &ttl_result &get_maxage_interval &get_expired_interval);
$VERSION	= '1.0.0';

## statistic intervals ############################
my $log_result = "%s/ttl.result";
our %expires_h = ();
our @TTL_a = (
    {
        name => "1h",
        min => 0,
        max => 3600,
    },
    {
        name => "2h",
        min => 3600,
        max => 7200,
    },
    {
        name => "3h",
        min => 7200,
        max => 10800,
    },
    {
        name => "4h",
        min => 10800,
        max => 14400,
    },
    {
        name => "5h",
        min => 14400,
        max => 18000,
    },
    {
        name => "6h",
        min => 18000,
        max => 21600,
    },
    {
        name => "8h",
        min => 21600,
        max => 28800,
    },
    {
        name => "12h",
        min => 28800,
        max => 43200,
    },
    {
        name => "16h",
        min => 43200,
        max => 57600,
    },
    {
        name => "20h",
        min => 57600,
        max => 72000,
    },
    {
        name => "1d",
        min => 72000,
        max => 86400,
    },
    {
        name => "2d",
        min => 86400,
        max => 172800,
    },
    {
        name => "3d",
        min => 172800,
        max => 259200,
    },
    {
        name => "4d",
        min => 259200,
        max => 345600,
    },
    {
        name => "5d",
        min => 345600,
        max => 432000,
    },
    {
        name => "6d",
        min => 432000,
        max => 518400,
    },
    {
        name => "8d",
        min => 518400,
        max => 691200,
    },
    {
        name => "16d",
        min => 691200,
        max => 1382400,
    },
    {
        name => "24d",
        min => 1382400,
        max => 2073600,
    },
    {
        name => "1m",
        min => 2073600,
        max => 2592000,
    },
    {
        name => "2m",
        min => 2592000,
        max => 5184000,
    },
    {
        name => "3m",
        min => 5184000,
        max => 7776000,
    },
    {
        name => "6m",
        min => 7776000,
        max => 15552000,
    },
    {
        name => "9m",
        min => 15552000,
        max => 23328000,
    },
    {
        name => "1y",
        min => 23328000,
        max => 31104000,
    },
    {
        name => ">1y",
        min => 31104000,
        max => 9999999999,
    },
);


sub get_expired_interval
{
    my ($expired, $logtime) = @_;
    
    if (length($expired) < 20) {
        return -1;
    }

    $expired = str2time($expired);
    $logtime = str2time($logtime);

    if ($expired > $logtime) {
        return ($expired - $logtime);
    }

    return 0;
}

my $ccontrol_maxage_reg = qr/.*max-age=(.*?)(|,.*|\s.*)$/;
sub get_maxage_interval
{
    my $ccontrol = shift;
    if (!defined($ccontrol)) {
        return 0;
    }

    my @age = ($ccontrol =~ m/$ccontrol_maxage_reg/);
    if (($#age > 0) && ($age[0] > 0)) {
        return $age[0];
    }

    return 0;
}

sub ttl_analysis_mod($)
{
    my $node_h = shift;
    if (!defined($node_h)) {
        return;
    }

    my $interval = -1;

    if ((($node_h->{cache_control} eq "-") || 
        ($node_h->{cache_control} eq "")) &&
        (($node_h->{cache_expired} eq "-") || 
        ($node_h->{cache_expired} eq "")))
    {
        return;
    }

    if (($node_h->{cache_control} ne "-") &&
        ($node_h->{cache_control} ne "")) {
        $interval = get_maxage_interval($node_h->{cache_control});
    }
    elsif (($node_h->{cache_expired} ne "-") &&
        ($node_h->{cache_expired} ne "")) {
        $interval = get_expired_interval($node_h->{cache_expired}, $node_h->{time});
    }

    if ($interval > 0) {
        for my $index (0..$#TTL_a) {
            if (($interval > $TTL_a[$index]{min}) && 
                ($interval <= $TTL_a[$index]{max}))
            {
                $expires_h{$TTL_a[$index]{name}} += 1;
                $expires_h{$TTL_a[$index]{name} . "_FLOW"} += $node_h->{http_len};
                last;
            }
        }
 
        # 统计设置了超时时间的各类资源的数据
        if (($node_h->{http_suffix} ne "-") && ($node_h->{http_suffix} ne "")) {
            $expires_h{".$node_h->{http_suffix}"} += 1;
            $expires_h{".$node_h->{http_suffix}" . "_FLOW"} += $node_h->{http_len};
        }
        $expires_h{TOTAL} += 1;
        $expires_h{TOTAL_FLOW} += $node_h->{http_len};
    }
}

sub ttl_result
{
    open(EXPIRED_FILE, ">$log_result");

    for my $index (0..$#TTL_a) {
        if (exists($expires_h{$TTL_a[$index]{name}})) {
            printf(EXPIRED_FILE "$TTL_a[$index]{name}\t" . 
                "$expires_h{$TTL_a[$index]{name} . '_FLOW'}\t" .
                "$expires_h{$TTL_a[$index]{name}}\n");
        }
    }

    close(EXPIRED_FILE);
}

sub ttl_analysis_init($)
{
    my $mod_h = shift;
    if (!defined($mod_h)) {
        return;
    }

    $log_result = sprintf($log_result, $mod_h->{date});
}

1;

