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

sub query($)
{
    my $self = shift;
    my $url = shift;

    my %http_h = ();
    if (!defined($url)) {
        return undef;
    }
    
    my $curl = WWW::Curl::Easy->new();

    $curl->setopt(CURLOPT_HEADER, 1);
    $curl->setopt(CURLOPT_URL, $url);
    $curl->setopt(CURLOPT_CONNECTTIMEOUT, 20);
    $curl->setopt(CURLOPT_TIMEOUT, 30);

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
        $response_body =~ m/^${response_header}(.*)$/;
        $response_body = $1;
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
        print("ERR($url): $retcode " . $curl->strerror($retcode) . " " . $curl->errbuf . "\n") if $debug;
        return;
    }

    return \%http_h;
}

sub BEGIN
{
}

sub DESTROY
{
}

1;

# vim: ts=4:sw=4:et

