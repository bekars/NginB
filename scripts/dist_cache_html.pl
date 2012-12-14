#!/usr/bin/perl -w

use strict;

# CACHEURL: www.shily.net//topic/tag/vmware/ || 03/Dec/2012:18:58:20 +0800 || - || max-age=172800 || Wed, 05 Dec 2012 10:58:19 GMT

my %html_h = ();
my $url_reg = qr/CACHEURL: (.*?) || .*$/;

open(CACHE_HTML, "cache_html.rst") or die("open cache_html.rst error!\n");
while (<CACHE_HTML>)
{
    my @url_a = m/$url_reg/;
    if ($#url_a >= 0) {
        $html_h{$url_a[0]} += 1;
    }
    $#url_a = -1;
}

close(CACHE_HTML);

open(CACHE_HTML_DIST, ">cache_html_dist.rst") or die("open cache_html_dist.rst error!\n");
foreach my $key (sort keys %html_h) {
    printf(CACHE_HTML_DIST "$key => $html_h{$key}\n");
}
close(CACHE_HTML_DIST);

