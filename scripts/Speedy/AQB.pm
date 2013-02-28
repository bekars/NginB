###################################################
## module include some aqb utils
###################################################


## Global Stuff ###################################
package	Speedy::AQB;
use		strict;
use     DBI;
require	Exporter;

#class global vars ...
use vars qw($VERSION @EXPORT @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw(&getSiteInfo &getDomainInfo);
$VERSION	= '1.0.0';

my $dbh;
my ($dbhost, $dbuser, $dbpass, $dbname, $dbport);

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
        elsif (m/^DBPORT=(\S+)/) {
            $dbport = $1;	
        }
    }
}

BEGIN
{
    my $driver  = "DBI:mysql";
    load_db_config();
    # database connect
    $dbh = DBI->connect("$driver:database=$dbname;host=$dbhost;user=$dbuser;password=$dbpass;port=$dbport")
        or die("ConnDB err: " . DBI->errstr);
}

END
{
    $dbh->disconnect();
}


sub getSiteInfo($)
{
    use constant {RECORD_ID=>0, RECORD_IP=>1};
    my %site_h = ();
    my $ip = "";
    my $name = shift;
    if (!defined($name)) {
        return \%site_h;
    }
    
    my $sql = "select id, ip from records where whole_name='$name'";
    my $sth = $dbh->prepare($sql);

    $sth->execute() or die("SQL err: " . $sth->errstr);
    my @recs = $sth->fetchrow_array;
    if ($#recs >= 0) {
        $ip = $recs[RECORD_IP];
    }
    $sth->finish();  

    # fill info
    $site_h{'ip'} = $ip;
    return \%site_h;
}

sub getDomainInfo($)
{
    my %domain_h = ();
    my $schedule = "";
    my $name = shift;
    if (!defined($name)) {
        return;
    }

    my $sql = "select sitedefault from domain where domain='$name'";
    my $sth = $dbh->prepare($sql);

    $sth->execute() or die("SQL err: " . $sth->errstr);
    my @recs = $sth->fetchrow_array;
    if ($#recs >= 0) {
        $schedule = $recs[0];
    }
    $sth->finish();  

    # fill info
    $domain_h{'schedule'} = $schedule;
    return \%domain_h;
}

1;

