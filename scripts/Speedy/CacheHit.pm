###################################################
## Speedy::CacheHit
##
## Cache Hit statistic
## analysis cache resource
###################################################


## Global Stuff ###################################
package	Speedy::CacheHit;
use strict;
require	Exporter;

use Speedy::TTL qw(&get_maxage_interval &get_expired_interval);
use Speedy::Utils;

use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw(%cache_hit_h %cache_http_status_h %cache_expired_h);
@EXPORT_OK	= qw(&cachehit_analysis_mod &cachehit_analysis_init &cachehit_result);
$VERSION	= '1.0.0';

## statistic intervals ############################
our %cache_hit_h = ();
our %cache_http_status_h = ();
our %cache_expired_h = ();

my $log_result = "%s/cachehit_%s.result";
my $site_result = "%s/cache_site_%s.result";
my $domain_flag = "";
my %cachehit_site_h = ();

my $miss_result = "%s/miss_%s.result";
my $miss_fp;

sub cache_expired_analysis
{
    my $node_h = shift;
    if (!defined($node_h)) {
        return;
    }

    my $interval = 1;

    if ((($node_h->{cache_control} eq "-") || 
        ($node_h->{cache_control} eq "")) &&
        (($node_h->{cache_expired} eq "-") || 
        ($node_h->{cache_expired} eq "")))
    {
        $cache_expired_h{TOTAL} += 1;
        $cache_expired_h{TOTAL_FLOW} += $node_h->{http_len};
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

    if ($interval <= 0) {
        $cache_expired_h{TOTAL} += 1;
        $cache_expired_h{TOTAL_FLOW} += $node_h->{http_len};
    }
}

sub cachehit_analysis_init($)
{
    my $mod_h = shift;
    if (!defined($mod_h)) {
        return;
    }

    $log_result = sprintf($log_result, $mod_h->{dir}, $mod_h->{date});
    $site_result = sprintf($site_result, $mod_h->{dir}, $mod_h->{date});

    $miss_result = sprintf($miss_result, $mod_h->{dir}, $mod_h->{date});
    open($miss_fp, ">$miss_result");
}

sub cachehit_site
{
    my ($cache_site_h, $node_h) = @_;
    
    $cache_site_h->{$node_h->{cache_status}} += 1;
    $cache_site_h->{TOTAL} += 1;
    $cache_site_h->{"$node_h->{cache_status}" . "_FLOW"} += $node_h->{http_len};
    $cache_site_h->{TOTAL_FLOW} += $node_h->{http_len};
}

sub cachehit_analysis_mod($)
{
    my $node_h = shift;
    if (!defined($node_h)) {
        return;
    }

    #if (($node_h->{cache_status} eq "-") ||
    #    ($node_h->{cache_status} eq "")) {
    #    return;
    #}

    if ($node_h->{http_status} eq "404") {
        return;
    }

    if ($node_h->{cache_control} =~ m/private|no-cache|no-store/i) {
        return;
    }

    if ($node_h->{cache_status} eq "") {
        $node_h->{cache_status} = "NULL";
    }

    if ($node_h->{agent} =~ m/aqb_prefetch/) {
        return;
    }
    
    $cache_hit_h{$node_h->{cache_status}} += 1;
    $cache_hit_h{TOTAL} += 1;
    $cache_hit_h{"$node_h->{cache_status}" . "_FLOW"} += $node_h->{http_len};
    $cache_hit_h{TOTAL_FLOW} += $node_h->{http_len};
    $cache_http_status_h{$node_h->{http_status}} += 1;
    $cache_http_status_h{TOTAL} += 1;
    $cache_http_status_h{"$node_h->{http_status}" . "_FLOW"} += $node_h->{http_len};
    $cache_http_status_h{TOTAL_FLOW} += $node_h->{http_len};

    # record miss log
    if ($node_h->{cache_status} eq "MISS") {
        my $log = $node_h->{log};
        $log =~ tr/%/#/;
        $log =~ tr/\n//d;
        printf($miss_fp "$log  $node_h->{domain}\n");
    }

    cache_expired_analysis($node_h);

    # cachehit for per site
    if ($domain_flag ne $node_h->{domain}) {
        my %cache_site_h = ();
        $cache_site_h{'-'} = 0;
        $cache_site_h{'-_FLOW'} = 0;
        $cache_site_h{'HIT'} = 0;
        $cache_site_h{'HIT_FLOW'} = 0;
        $cache_site_h{'MISS'} = 0;
        $cache_site_h{'MISS_FLOW'} = 0;
        $cache_site_h{'EXPIRED'} = 0;
        $cache_site_h{'EXPIRED_FLOW'} = 0;
        $cache_site_h{'TOTAL'} = 0;
        $cache_site_h{'TOTAL_FLOW'} = 0;
        $cachehit_site_h{$node_h->{domain}} = \%cache_site_h;
        $domain_flag = $node_h->{domain};
    }

    cachehit_site($cachehit_site_h{$node_h->{domain}}, $node_h);
}

sub cachehit_result
{
    if (!exists($cache_hit_h{HIT})) {
        return 0;
    }

    open(CACHESITE_FILE, ">$site_result") or return;

    my $total = 0;
    my $total_flow = 0;
    foreach my $key (keys %cachehit_site_h) {
        $total = ($cachehit_site_h{$key}->{HIT} + $cachehit_site_h{$key}->{MISS} + $cachehit_site_h{$key}->{EXPIRED});
        if (0 == $total) {
            $cachehit_site_h{$key}->{HITRATE} = -1;
        } else {
            $cachehit_site_h{$key}->{HITRATE} = $cachehit_site_h{$key}->{HIT} * 100 / $total;
        }

        $total_flow = ($cachehit_site_h{$key}->{HIT_FLOW} + $cachehit_site_h{$key}->{MISS_FLOW} + $cachehit_site_h{$key}->{EXPIRED_FLOW});
        if (0 == $total_flow) {
            $cachehit_site_h{$key}->{HITRATE_FLOW} = -1;
        } else {
            $cachehit_site_h{$key}->{HITRATE_FLOW} = $cachehit_site_h{$key}->{HIT_FLOW} * 100 / $total_flow;
        }

        if ((0 == $cachehit_site_h{$key}->{TOTAL}) ||
            (0 == $cachehit_site_h{$key}->{TOTAL_FLOW})) {
            $cachehit_site_h{$key}->{CACHERATE} = -1;
            $cachehit_site_h{$key}->{CACHERATE_FLOW} = -1;
        } else {
            $cachehit_site_h{$key}->{CACHERATE} = $total * 100 / $cachehit_site_h{$key}->{TOTAL};
            $cachehit_site_h{$key}->{CACHERATE_FLOW} = $total_flow * 100 / $cachehit_site_h{$key}->{TOTAL_FLOW};
        }

        printf(CACHESITE_FILE "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", 
            $key,
            roundFloat($cachehit_site_h{$key}->{HITRATE}), roundFloat($cachehit_site_h{$key}->{HITRATE_FLOW}), 
            roundFloat($cachehit_site_h{$key}->{CACHERATE}), roundFloat($cachehit_site_h{$key}->{CACHERATE_FLOW}),
            $cachehit_site_h{$key}->{HIT}, $cachehit_site_h{$key}->{MISS}, $cachehit_site_h{$key}->{EXPIRED},
            $cachehit_site_h{$key}->{TOTAL}, $cachehit_site_h{$key}->{TOTAL_FLOW},
        );
    }
    close(CACHESITE_FILE);
    
    
    # HIT   MISS    EXPIRED     -   TOTAL   HIT_RATE    CACHE_RATE
    $cache_hit_h{HITRATE} = $cache_hit_h{HIT} * 100 / ($cache_hit_h{HIT} + $cache_hit_h{MISS} + $cache_hit_h{EXPIRED});
    $cache_hit_h{HITRATE_FLOW} = $cache_hit_h{HIT_FLOW} * 100 / ($cache_hit_h{HIT_FLOW} + $cache_hit_h{MISS_FLOW} + $cache_hit_h{EXPIRED_FLOW});
    $cache_hit_h{CACHERATE} = ($cache_hit_h{HIT} + $cache_hit_h{MISS} + $cache_hit_h{EXPIRED}) * 100 / $cache_hit_h{TOTAL};
    $cache_hit_h{CACHERATE_FLOW} = ($cache_hit_h{HIT_FLOW} + $cache_hit_h{MISS_FLOW} + $cache_hit_h{EXPIRED_FLOW}) * 100 / $cache_hit_h{TOTAL_FLOW};
    
    my $line = sprintf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t" .
                       "%s\t%s\t%s\t%s\t%s\t%s\n",
                   $cache_hit_h{HIT}, $cache_hit_h{HIT_FLOW},
                   $cache_hit_h{MISS}, $cache_hit_h{MISS_FLOW},
                   $cache_hit_h{EXPIRED}, $cache_hit_h{EXPIRED_FLOW},
                   $cache_hit_h{'-'}, $cache_hit_h{'-_FLOW'},
                   $cache_hit_h{TOTAL}, $cache_hit_h{TOTAL_FLOW},
                   $cache_hit_h{HITRATE}, $cache_hit_h{HITRATE_FLOW},
                   $cache_hit_h{CACHERATE}, $cache_hit_h{CACHERATE_FLOW},
               );

    open(CACHEHIT_FILE, ">$log_result") or return;
    printf(CACHEHIT_FILE $line);
    close(CACHEHIT_FILE);
}

BEGIN
{
}

END
{
}

1;

