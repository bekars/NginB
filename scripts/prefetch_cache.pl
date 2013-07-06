#!/usr/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use WWW::Curl::Easy;

my @cluster = qw/61.147.79.211 61.147.79.211/;

my $url = qq/http:\/\/test.weiweimeishi.com\/huohua\/movie\/1-20small\/51a877a814215c1ae800004f.flv/;

my $total = $#cluster;
++$total;
my $cnt = 0;
my $success = 0;
my $showhelp = 0;

my $_total_len = 0;
my $_body_len = 0;
my $_cache_status = "MISS";

sub header_callback 
{
    my ($chunk, $user_data) = @_;
    my $len = length($chunk);

    if ($chunk =~ m/x-powered-by-anquanbao:\s+(.+?)\s+/i) {
        $_cache_status = $1;
        if (lc($_cache_status) eq "hit") {
            $_cache_status = "HIT";
            return 0;
        }
    }

    if ($chunk =~ m/content-length:\s*(\d+)/i) {
        $_total_len = $1;
    }
    return $len;
}

my @_display = qw(| / - \\ | / - \\);
my $_discnt = 0;
sub body_callback 
{
    my ($chunk, $user_data) = @_;
    my $len = length($chunk);

    $_body_len += $len;
    $|++;
    printf("PROGRESS => %.2f%%  %s\r", ($_body_len * 100 / $_total_len), $_display[(++$_discnt) % 8]);
    return $len;
}

sub fetch_cache($;$$)
{
    my ($url, $proxy, $nobody) = @_;

    my $http_h = undef;
    my $curl = WWW::Curl::Easy->new();

    $curl->setopt(CURLOPT_URL, $url);
    $curl->setopt(CURLOPT_CONNECTTIMEOUT, 10);
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
    $curl->setopt(CURLOPT_NOBODY, $nobody);
    $curl->setopt(CURLOPT_PROXY, $proxy) if $proxy;

    my $response_header = "";
    my $response_body = "";
    $curl->setopt(CURLOPT_HEADERDATA, \$response_header);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    $curl->setopt(CURLOPT_TRANSFER_ENCODING, 1);
    $curl->setopt(CURLOPT_ACCEPT_ENCODING, "gzip");
    $curl->setopt(CURLOPT_HEADERFUNCTION, \&header_callback);
    $curl->setopt(CURLOPT_WRITEFUNCTION, \&body_callback);

    $_total_len = 0;
    $_body_len = 0;
    $_cache_status = "MISS";
    my $retcode = $curl->perform();
    
    if ($retcode == 0) {
        $http_h->{URL} = $url;
        $http_h->{HEADER} = $response_header;
        $http_h->{BODY}   = $response_body;
        $http_h->{RESPONSE_CODE}  = $curl->getinfo(CURLINFO_RESPONSE_CODE);
        $http_h->{CONTENT_LENGTH} = $curl->getinfo(CURLINFO_CONTENT_LENGTH_DOWNLOAD);
        $http_h->{CACHE_STATUS}   = $_cache_status;
    } else {
        if ($_cache_status eq "HIT") {
            $http_h->{CACHE_STATUS} = $_cache_status;
            return $http_h;
        }

        printf("ERR($url): $retcode " . $curl->strerror($retcode) . " " . $curl->errbuf . "\n");
    }

    return $http_h;
}

sub showhelp()
{
    printf("Usage: perl prefetch_cache.pl --url <URL>\n");
    exit(0);
}

GetOptions(
    'url|u=s' => \$url,
    'help|h+' => \$showhelp,
);

showhelp() if ($showhelp);

foreach my $kip (@cluster) {
    printf("[PREFETCH %d/%d]\n", ++$cnt, $total);
    my $http = fetch_cache($url, "$kip:80", 0);
    $http = fetch_cache($url, "$kip:80", 1);
    if ($http->{CACHE_STATUS} eq "HIT") {
        ++$success;
    } else {
        printf("HTTP ERR: $http->{RESPONSE_CODE}\n");
    }
}

if ($success == $total) {
    printf("PREFETCH OK!\n");
} else {
    printf("PREFETCH ERR!\n");
}

1;

# vim: ts=4:sw=4:et

