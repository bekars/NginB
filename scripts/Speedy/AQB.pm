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

use constant {
    RECORD_ID       => 0, 
    RECORD_IP       => 1,
    RECORD_TYPE     => 2,
    RECORD_DNS      => 3,
    RECORD_DOMAINID => 4,
    RECORD_REV      => 5,
};

use constant {
    CONFIG     => 0, 
    CONFIG_VAL => 1,
};

sub getSiteInfo($)
{
    my %site_h = ();
    my %conf_h = ();
    my $name = shift;
    if (!defined($name)) {
        return \%site_h;
    }
    
    my $sql = "select id,ip,type,dns,domain_id,rev from records where whole_name='$name'";
    my $sth = $dbh->prepare($sql);
    $sth->execute() or die("SQL err: " . $sth->errstr);
    my @recs = $sth->fetchrow_array;
    if ($#recs >= 0) {
        $site_h{'id'} = $recs[RECORD_ID];
        $site_h{'ip'} = $recs[RECORD_IP];
        $site_h{'type'} = $recs[RECORD_TYPE];
        $site_h{'dns'} = $recs[RECORD_DNS];
        $site_h{'domainid'} = $recs[RECORD_DOMAINID];
        $site_h{'rev'} = $recs[RECORD_REV];
    } else {
        printf("ERR: site ($name) no find in db!\n");
        $sth->finish();  
        return \%site_h;
    }

    if (exists($site_h{'id'}) and $site_h{'id'} > 0) {
        $sql = "select config, value from site_configswitch where siteid=$site_h{'id'}";
        $sth = $dbh->prepare($sql);
        $sth->execute() or die("SQL err: " . $sth->errstr);
        while (@recs = $sth->fetchrow_array) {
            $conf_h{$recs[CONFIG]} = $recs[CONFIG_VAL];
        }
    }

    # fill info
    $site_h{'config'} = \%conf_h;
    
    $sth->finish();
    return \%site_h;
}

use constant {
    DOMAIN_ID = 0,

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

