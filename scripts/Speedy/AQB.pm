###################################################
## perl module for dealing with aqb
###################################################


## Global Stuff ###################################
package	Aqb;
use		strict;
use     DBI;
require	Exporter;

#class global vars ...
use vars qw($VERSION @EXPORT @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw(&getSiteIP);
$VERSION	= '1.0.0';

my $dbh;
my ($dbhost, $dbuser, $dbpass, $dbname);

sub load_db_config
{
    my $conf_file_path = '/etc/antnest.conf.net';
    open(DB_CONFIG, $conf_file_path) or die("ERR: can't open $conf_file_path : $!");

    while (<DB_CONFIG>) {
        if (m/^DBHOST=(\S+)/) {
            $dbhost = $1;	
        }
        elsif (m/^DBUSER=(\S+)/) {
            $dbuser = $1;	
        }
        elsif (m/^DBPASS=(\S+)/) {
            $dbpass = $1;
        }
        elsif (m/^DBNAME=(\S+)/) {
            $dbname = $1;	
        }
    }
}

BEGIN
{
    my $driver  = "DBI:mysql";
    load_db_config();
    # database connect
    $dbh = DBI->connect("$driver:database=$dbname;host=$dbhost;user=$dbuser;password=$dbpass")
        or die("ConnDB err: " . DBI->errstr);
}

END
{
    $dbh->disconnect();
}

sub getSiteIP($)
{
    my $ip;
    my $site = shift;
    if (!defined($site)) {
        return;
    }

    my $sql = "select ip from records where whole_name like '$site'";
    my $sth = $dbh->prepare($sql);

    $sth->execute() or die("SQL err: " . $sth->errstr);
    my @recs = $sth->fetchrow_array;
    if ($#recs >= 0) {
        $ip = $recs[0];
    }
    $sth->finish();  

    return $ip;
}


