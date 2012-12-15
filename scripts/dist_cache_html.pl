#!/usr/bin/perl -w

use strict;
use Aqb;

## EXAMPLE ###########################
# CACHEURL: www.shily.net//topic/tag/vmware/ || 03/Dec/2012:18:58:20 +0800 || - || max-age=172800 || Wed, 05 Dec 2012 10:58:19 GMT

my %html_h = ();
my $url_reg = qr/CACHEURL: (.*?) || .*$/;

sub mysort
{
    my ($a, $b) = @_;
    return ($html_h{$b} <=> $html_h{$a});
}

open(CACHE_HTML, "cache_html.result") or die("open cache_html.result error!\n");
while (<CACHE_HTML>)
{
    my @url_a = m/$url_reg/;
    if ($#url_a >= 0) {
        $html_h{$url_a[0]} += 1;
    }
    $#url_a = -1;
}
close(CACHE_HTML);

my $site;
my $path;
my $siteip;
my $curl_cmd;
my $curl_rst;
open(CACHE_HTML_DIST, ">cache_html_dist.result") or die("open cache_html_dist.result error!\n");
foreach my $key (sort {mysort($a, $b)} keys %html_h) {
    $siteip = "*";
    printf(CACHE_HTML_DIST "######################################\n");
    if ($key =~ m/(.*?)\/(.*)$/) {
        $site = $1;
        $path = $2;
        $siteip = getSiteIP($site);
    }
    printf(CACHE_HTML_DIST "$key => $html_h{$key} ($siteip)\n");
    printf("$key => $html_h{$key} ($siteip)\n");
    
    if (length($siteip) > 6) {
        $curl_cmd = "curl --connect-timeout 10 -m 20 -I http://$siteip/$path -H 'Host: $site' 2>&1";
        $curl_rst = `$curl_cmd`;
        $curl_rst =~ tr/%/#/;
        printf(CACHE_HTML_DIST "$curl_cmd\n$curl_rst\n");
    }

    if ($html_h{$key} < 100) {
        last;
    }
}
close(CACHE_HTML_DIST);

