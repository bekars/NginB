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
@EXPORT		= qw(&getSiteIP &getSchedule &getStr);
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

sub getSiteInfo($)
{
    my %site_h = ();
    my $ip = "";
    my $name = shift;
    if (!defined($name)) {
        return \%site_h;
    }
    
    my $sql = "select ip from records where whole_name like '$name'";
    my $sth = $dbh->prepare($sql);

    $sth->execute() or die("SQL err: " . $sth->errstr);
    my @recs = $sth->fetchrow_array;
    if ($#recs >= 0) {
        $ip = $recs[0];
    }
    $sth->finish();  

    $site_h{'ip'} = $ip;
    return \%site_h;
}

sub getSiteIP($)
{
    my $name = shift;
    if (!defined($name)) {
        return "";
    }

    my $site = getSiteInfo($name);
    if (exists($site->{'ip'})) {
        return $site->{'ip'};
    }
    return "";
}

sub getSchedule($)
{
    my $schedule;
    my $domain = shift;
    if (!defined($domain)) {
        return;
    }

    my $sql = "select sitedefault from domain where domain='$domain'";
    my $sth = $dbh->prepare($sql);

    $sth->execute() or die("SQL err: " . $sth->errstr);
    my @recs = $sth->fetchrow_array;
    if ($#recs >= 0) {
        $schedule = $recs[0];
    }
    $sth->finish();  

    return $schedule;
}

