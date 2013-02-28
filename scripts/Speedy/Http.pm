
## Global Stuff ###################################
package	Speedy::Http;
use		strict;
use warnings;
use     WWW::Curl::Easy;
require	Exporter;

#class global vars ...
use vars qw($VERSION @EXPORT @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw(&getHttpInfo);
$VERSION	= '1.0.0';


sub getHttpInfo($)
{
    my %http_h = ();
    my $url = shift;
    if (!defined($url)) {
        return \%http_h;
    }
    
    my $curl = WWW::Curl::Easy->new;

    $curl->setopt(CURLOPT_HEADER, 1);
    $curl->setopt(CURLOPT_URL, $url);
    $curl->setopt(CURLOPT_CONNECTTIMEOUT, 30);

    # a filehandle, reference to a scalar or reference to a typeglob can be used here.
    my $response_body;
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);

    # start the actual request
    my $retcode = $curl->perform;

    # get http info
    $http_h{HTTP_CODE} = $curl->getinfo(CURLINFO_HTTP_CODE);
    $http_h{SIZE_DOWNLOAD} = $curl->getinfo(CURLINFO_SIZE_DOWNLOAD);
    $http_h{SPEED_DOWNLOAD} = $curl->getinfo(CURLINFO_SPEED_DOWNLOAD);
    $http_h{PRETRANSFER_TIME} = $curl->getinfo(CURLINFO_PRETRANSFER_TIME);
    $http_h{STARTTRANSFER_TIME} = $curl->getinfo(CURLINFO_STARTTRANSFER_TIME);
    $http_h{NAMELOOKUP_TIME} = $curl->getinfo(CURLINFO_NAMELOOKUP_TIME);
    $http_h{TOTAL_TIME} = $curl->getinfo(CURLINFO_TOTAL_TIME);
    $http_h{RESPONSE_CODE} = $curl->getinfo(CURLINFO_RESPONSE_CODE);
    $http_h{REDIRECT_TIME} = $curl->getinfo(CURLINFO_REDIRECT_TIME);
    $http_h{REDIRECT_URL} = $curl->getinfo(CURLINFO_REDIRECT_URL);
    $http_h{LOCAL_IP} = $curl->getinfo(CURLINFO_LOCAL_IP);
    $http_h{PRIMARY_IP} = $curl->getinfo(CURLINFO_PRIMARY_IP);
    $http_h{CONNECT_TIME} = $curl->getinfo(CURLINFO_CONNECT_TIME);
    $http_h{CONTENT_LENGTH} = $curl->getinfo(CURLINFO_CONTENT_LENGTH_DOWNLOAD);
    $http_h{CONTENT_TYPE} = $curl->getinfo(CURLINFO_CONTENT_TYPE);
    $http_h{HEADER_IN} = $curl->getinfo(CURLINFO_HEADER_IN);
    $http_h{HEADER_OUT} = $curl->getinfo(CURLINFO_HEADER_OUT);
    $http_h{HEADER_SIZE} = $curl->getinfo(CURLINFO_HEADER_SIZE);
    $http_h{FILETIME} = $curl->getinfo(CURLINFO_FILETIME);
    $http_h{COOKIELIST} = $curl->getinfo(CURLINFO_COOKIELIST);
    $http_h{HTTP_CONNECTCODE} = $curl->getinfo(CURLINFO_HTTP_CONNECTCODE);

    # looking at the results...
    if ($retcode == 0) {
        #print("Transfer went ok\n");
        # judge result and next action based on $response_code
        #print("Received response: $response_body\n");
    } else {
        # Error code, type of error, error message
        print("ERR($url): $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n");
    }

    return \%http_h;
}

1;
