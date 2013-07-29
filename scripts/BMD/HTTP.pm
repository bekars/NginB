#!/usr/bin/perl -w

package BMD::HTTP;

use strict;
use warnings;
use autodie;
use Try::Tiny;
use Data::Dumper;
use WWW::Curl::Easy;

my $debug = 1;

sub new()
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = {
        @_,
    };

    bless($self, $class);
    return $self;
}

sub query($;$$)
{
    my $self = shift;
    my ($url, $ishead, $proxy) = @_;
    $ishead = 0 unless $ishead;

    my %http_h = ();
    my $curl = WWW::Curl::Easy->new();

    $curl->setopt(CURLOPT_URL, $url);
    $curl->setopt(CURLOPT_CONNECTTIMEOUT, 5);
    $curl->setopt(CURLOPT_TIMEOUT, 5);
    # not inlcude header in response
    $curl->setopt(CURLOPT_HEADER, 0);
    # follow redirect
    $curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
    # not include body in response
    $curl->setopt(CURLOPT_NOBODY, $ishead);
    # set proxy
    $curl->setopt(CURLOPT_PROXY, $proxy) if $proxy;

    # a filehandle, reference to a scalar or reference to a typeglob can be used here.
    my $response_header;
    my $response_body;
    $curl->setopt(CURLOPT_HEADERDATA, \$response_header);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    #$curl->setopt(CURLOPT_TRANSFER_ENCODING, 1);
    #$curl->setopt(CURLOPT_WRITEFUNCTION, \&body_callback);
    #$curl->setopt(CURLOPT_ACCEPT_ENCODING, "gzip");

    # start the actual request
    my $retcode = $curl->perform();

    # looking at the results...
    if ($retcode == 0) {
        $response_header =~ s/%/%%/g;
        $response_body =~ s/%/%%/g;

        # get http info
        $http_h{HEADER} = $response_header;
        $http_h{BODY}   = $response_body;
        $http_h{HTTP_CODE}          = $curl->getinfo(CURLINFO_HTTP_CODE);
        $http_h{SIZE_DOWNLOAD}      = $curl->getinfo(CURLINFO_SIZE_DOWNLOAD);
        $http_h{SPEED_DOWNLOAD}     = $curl->getinfo(CURLINFO_SPEED_DOWNLOAD);
        $http_h{PRETRANSFER_TIME}   = $curl->getinfo(CURLINFO_PRETRANSFER_TIME);
        $http_h{STARTTRANSFER_TIME} = $curl->getinfo(CURLINFO_STARTTRANSFER_TIME);
        $http_h{NAMELOOKUP_TIME}    = $curl->getinfo(CURLINFO_NAMELOOKUP_TIME);
        $http_h{TOTAL_TIME}         = $curl->getinfo(CURLINFO_TOTAL_TIME);
        $http_h{RESPONSE_CODE}      = $curl->getinfo(CURLINFO_RESPONSE_CODE);
        $http_h{REDIRECT_TIME}      = $curl->getinfo(CURLINFO_REDIRECT_TIME);
        $http_h{REDIRECT_URL}       = $curl->getinfo(CURLINFO_REDIRECT_URL);
        $http_h{LOCAL_IP}           = $curl->getinfo(CURLINFO_LOCAL_IP);
        $http_h{PRIMARY_IP}         = $curl->getinfo(CURLINFO_PRIMARY_IP);
        $http_h{CONNECT_TIME}       = $curl->getinfo(CURLINFO_CONNECT_TIME);
        $http_h{CONTENT_LENGTH}     = $curl->getinfo(CURLINFO_CONTENT_LENGTH_DOWNLOAD);
        $http_h{CONTENT_TYPE}       = $curl->getinfo(CURLINFO_CONTENT_TYPE);
        $http_h{HEADER_IN}          = $curl->getinfo(CURLINFO_HEADER_IN);
        $http_h{HEADER_OUT}         = $curl->getinfo(CURLINFO_HEADER_OUT);
        $http_h{HEADER_SIZE}        = $curl->getinfo(CURLINFO_HEADER_SIZE);
        $http_h{FILETIME}           = $curl->getinfo(CURLINFO_FILETIME);
        $http_h{COOKIELIST}         = $curl->getinfo(CURLINFO_COOKIELIST);
        $http_h{HTTP_CONNECTCODE}   = $curl->getinfo(CURLINFO_HTTP_CONNECTCODE);

        #print("Transfer went ok\n");
        # judge result and next action based on $response_code
        #print("Received response: $response_header\n");
    } else {
        # Error code, type of error, error message
        printf("ERR($url): $retcode " . $curl->strerror($retcode) . " " . $curl->errbuf . "\n") if $debug;
        return;
    }

    return \%http_h;
}

my $_total_len = 0;
my $_body_len = 0;
my $_cache_status = "MISS";
sub _header_callback 
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
    #printf("HEADER($len|$_total_len|$_cache_status): $chunk");
    #${$user_data} .= $chunk;
    return $len;
}

my @_display = qw(| / - \\ | / - \\);
my $_discnt = 0;
sub _body_callback 
{
    my ($chunk, $user_data) = @_;
    my $len = length($chunk);

    $_body_len += $len;
    $|++;
    printf("PROGRESS => %.2f%%  %s\r", ($_body_len * 100 / $_total_len), $_display[(++$_discnt) % 8]);
    #${$user_data} .= $chunk;
    return $len;
}

sub fetch_cache($;$$)
{
    my $self = shift;
    my ($url, $proxy, $nobody) = @_;

    my $http_h = undef;
    my $curl = WWW::Curl::Easy->new();

    $curl->setopt(CURLOPT_URL, $url);
    $curl->setopt(CURLOPT_CONNECTTIMEOUT, 10);
    #$curl->setopt(CURLOPT_TIMEOUT, 30);
    # not inlcude header in response
    $curl->setopt(CURLOPT_HEADER, 0);
    # follow redirect
    $curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
    # include body in response
    $curl->setopt(CURLOPT_NOBODY, $nobody);
    # set proxy
    $curl->setopt(CURLOPT_PROXY, $proxy) if $proxy;

    # a filehandle, reference to a scalar or reference to a typeglob can be used here.
    my $response_header = "";
    my $response_body = "";
    $curl->setopt(CURLOPT_HEADERDATA, \$response_header);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    #$curl->setopt(CURLOPT_TRANSFER_ENCODING, 1);
    #$curl->setopt(CURLOPT_ACCEPT_ENCODING, "gzip");
    $curl->setopt(CURLOPT_HEADERFUNCTION, \&_header_callback);
    $curl->setopt(CURLOPT_WRITEFUNCTION, \&_body_callback);

    $_total_len = 0;
    $_body_len = 0;
    $_cache_status = "MISS";
    # start the actual request
    my $retcode = $curl->perform();
    
    # looking at the results...
    if ($retcode == 0) {
        $response_header =~ s/%/%%/g;
        $response_body =~ s/%/%%/g;
        
        # get http info
        $http_h->{URL} = $url;
        $http_h->{HEADER} = $response_header;
        $http_h->{BODY}   = $response_body;
        $http_h->{RESPONSE_CODE}  = $curl->getinfo(CURLINFO_RESPONSE_CODE);
        $http_h->{CONTENT_LENGTH} = $curl->getinfo(CURLINFO_CONTENT_LENGTH_DOWNLOAD);
        $http_h->{CACHE_STATUS}   = $_cache_status;

        printf("\n");
    } else {
        if ($_cache_status eq "HIT") {
            $http_h->{CACHE_STATUS} = $_cache_status;
            return $http_h;
        }

        # Error code, type of error, error message
        printf("ERR($url): $retcode " . $curl->strerror($retcode) . " " . $curl->errbuf . "\n") if $debug;
        return;
    }

    return $http_h;
}


sub BEGIN
{
}

sub DESTROY
{
}

1;

# vim: ts=4:sw=4:et

