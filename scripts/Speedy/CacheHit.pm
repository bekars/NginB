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

use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw(%cache_hit_h);
@EXPORT_OK	= qw(&cachehit_analysis_mod &cachehit_analysis_init &cachehit_result);
$VERSION	= '1.0.0';

## statistic intervals ############################
our %cache_hit_h = ();
my %cache_http_status_h = ();
my %cache_expired_h = ();
my $log_result = "%s/cachehit.result";

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

    $log_result = sprintf($log_result, $mod_h->{date});
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
    
    $cache_hit_h{$node_h->{cache_status}} += 1;
    $cache_hit_h{TOTAL} += 1;
    $cache_hit_h{"$node_h->{cache_status}" . "_FLOW"} += $node_h->{http_len};
    $cache_hit_h{TOTAL_FLOW} += $node_h->{http_len};
    $cache_http_status_h{$node_h->{http_status}} += 1;
    $cache_http_status_h{TOTAL} += 1;
    $cache_http_status_h{"$node_h->{http_status}" . "_FLOW"} += $node_h->{http_len};
    $cache_http_status_h{TOTAL_FLOW} += $node_h->{http_len};

    cache_expired_analysis($node_h);
}

sub cachehit_result
{
    if (!exists($cache_hit_h{HIT})) {
        return 0;
    }

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

