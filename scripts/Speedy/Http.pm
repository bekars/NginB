
## Global Stuff ###################################
package	Speedy::Http;
use		strict;
use warnings;
use     WWW::Curl::Easy;
require	Exporter;

#class global vars ...
use vars qw($VERSION @EXPORT @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw(&curlTest);
$VERSION	= '1.0.0';


sub curlTest()
{
    my $curl = WWW::Curl::Easy->new;

    $curl->setopt(CURLOPT_HEADER,1);
    $curl->setopt(CURLOPT_URL, 'http://www.baiyu.net.cn');

    # A filehandle, reference to a scalar or reference to a typeglob can be used here.
    my $response_body;
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);

    # Starts the actual request
    my $retcode = $curl->perform;

    my $transtime = $curl->getinfo(CURLINFO_STARTTRANSFER_TIME);
    printf("Time: $transtime\n");
    my $httpcode = $curl->getinfo(CURLINFO_HTTP_CODE);
    printf("Code: $httpcode\n");

    # Looking at the results...
    if ($retcode == 0) {
        print("Transfer went ok\n");
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        # judge result and next action based on $response_code
        #print("Received response: $response_body\n");
    } else {
        # Error code, type of error, error message
        print("An error happened: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n");
    }
}

