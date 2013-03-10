###################################################
## Speedy::Html
##
## html页面统计
## html可缓存统计
###################################################


## Global Stuff ###################################
package	Speedy::Html;
use strict;
use Date::Parse;
require	Exporter;

#class global vars ...
use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw(%html_http_header_h);
@EXPORT_OK	= qw(&html_analysis_mod &html_analysis_init);
$VERSION	= '1.0.0';

## statistic intervals ############################
my $log_result = "%s/html_%s.result";
our %html_http_header_h = ();


my $ccontrol_nocache_reg = qr/.*(no-cache|no-store|private).*$/;
my $ccontrol_maxage_reg = qr/.*max-age=(.*?)(|,.*|\s.*)$/;
sub is_valid_cache_control
{
    my $ccontrol = shift;
    if (!defined($ccontrol)) {
        return 0;
    }

    # no-cache : no-cache, no-store, private
    if ($ccontrol =~ m/$ccontrol_nocache_reg/) {
        return 0;
    }
 
    # cache : max-age > 0 or no max-age
    my @age = ($ccontrol =~ m/$ccontrol_maxage_reg/);
    if (($#age > 0) && ($age[0] > 0)) {
        return 1;
    } elsif ($#age == 0) {
        return 1;
    }

    return 0;
}
    
sub is_valid_expired
{
    my ($expired, $logtime) = @_;
    
    if (length($expired) < 20) {
        return 0;
    }

    $expired = str2time($expired);
    $logtime = str2time($logtime);

    if ($expired > $logtime) {
        return 1;
    }

    return 0;
}

sub html_analysis_init($)
{
    my $mod_h = shift;
    if (!defined($mod_h)) {
        return;
    }

    $log_result = sprintf($log_result, $mod_h->{dir}, $mod_h->{date});
    open(RESULTFILE, ">$log_result");
    close(RESULTFILE);
}


sub html_analysis_mod($)
{
    use constant {NONE=>0, ETAG=>1, LM=>2, CONTROL=>4, EXPIRED=>8};

    my $node_h = shift;
    if (!defined($node_h)) {
        return;
    }

    if (!(($node_h->{http_suffix} eq "htm") ||
        ($node_h->{http_suffix} eq "html") ||
        ($node_h->{http_suffix} eq "/") ||
        ($node_h->{http_suffix} eq "//"))) {
        return;
    }

    my $hflag = 0;
    my $nocache = 0;
    my $judgeby = NONE;

    if (($node_h->{http_etag} ne "-") &&
        ($node_h->{http_etag} ne "")) {
        $hflag |= ETAG;
        $html_http_header_h{http_etag} += 1;
        $html_http_header_h{http_etag_FLOW} += $node_h->{http_len};
    }
    
    if (($node_h->{http_lastmodify} ne "-") &&
        ($node_h->{http_lastmodify} ne "")) {
        $hflag |= LM;
        $html_http_header_h{http_lastmodify} += 1;
        $html_http_header_h{http_lastmodify_FLOW} += $node_h->{http_len};
    }
    
    if (($node_h->{cache_control} ne "-") &&
        ($node_h->{cache_control} ne "")) {
        $hflag |= CONTROL;
        $html_http_header_h{cache_control} += 1;
        $html_http_header_h{cache_control_FLOW} += $node_h->{http_len};
    }
    
    if (($node_h->{cache_expired} ne "-") &&
        ($node_h->{cache_expired} ne "")) {
        $hflag |= EXPIRED;
        $html_http_header_h{cache_expired} += 1;
        $html_http_header_h{cache_expired_FLOW} += $node_h->{http_len};
    }
    
    $html_http_header_h{TOTAL} += 1;
    $html_http_header_h{TOTAL_FLOW} += $node_h->{http_len};

    #
    # 统计
    # 1. 可以缓存的html流量
    # 2. 首页可以缓存的流量
    #
    # 判断逻辑
    #   存在Set-Cookie头不能缓存(log中目前没有记录)；
    #   如果存在Cache-Control头，存在no-cache/no-store/private标记不能缓存, max-age大于0可以缓存；
    #   如果没有Cache-Control头而有Expirs头，Expirs时间有效且在未来可以缓存；
    #   没有明确断定不能缓存的判断为可以缓存；
    #
    if ($hflag & CONTROL)
    {
        if (!is_valid_cache_control($node_h->{cache_control})) {
            $nocache = 1;
        } else {
            $judgeby = CONTROL;
            $nocache = 0;
        }
    }
    
    if (($judgeby == NONE) && ($hflag & EXPIRED)) {
        if (!is_valid_expired($node_h->{cache_expired}, $node_h->{time})) {
            $nocache = 1;
        } else {
            $judgeby = EXPIRED;
            $nocache = 0;
        }
    }

    if (!$nocache) {
        $html_http_header_h{CACHE} += 1;
        $html_http_header_h{CACHE_FLOW} += $node_h->{http_len};
        if ($node_h->{http_url} eq "/") {
            $html_http_header_h{CACHE_MAINPAGE} += 1;
            $html_http_header_h{CACHE_MAINPAGE_FLOW} += $node_h->{http_len};
        }
    
        if ($judgeby == NONE) {
            $html_http_header_h{CACHE_BY_NONE} += 1;
            $html_http_header_h{CACHE_BY_NONE_FLOW} += $node_h->{http_len};
        }
        
        if ($judgeby == CONTROL) {
            $html_http_header_h{CACHE_BY_CC} += 1;
            $html_http_header_h{CACHE_BY_CC_FLOW} += $node_h->{http_len};
        }

        if ($judgeby == EXPIRED) {
            $html_http_header_h{CACHE_BY_EXPIRED} += 1;
            $html_http_header_h{CACHE_BY_EXPIRED_FLOW} += $node_h->{http_len};
        }
    }

    open(RESULTFILE, ">>$log_result");
    $node_h->{http_url} =~ tr/%/#/;
    my $line_hdr = "CACHED";
    if ($nocache) {
        $line_hdr = "NOCACHED";
    } 
    printf(RESULTFILE "$line_hdr: $node_h->{domain}$node_h->{http_url} || $node_h->{time} || $node_h->{http_etag} || $node_h->{cache_control} || $node_h->{cache_expired}\n");
    close(RESULTFILE);
}

1;

