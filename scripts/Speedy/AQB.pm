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
@EXPORT		= qw(&getSiteInfo &getDomainInfo &getScheduleInfo);
$VERSION	= '1.0.0';

my $dbh;
my ($dbhost, $dbuser, $dbpass, $dbname, $dbport);

sub load_db_config
{
    my $conf_file_path = '/home/apuadmin/baiyu/antnest.conf.net';
    open(DB_CONFIG, $conf_file_path) or die("ERR: can't open $conf_file_path : $!");

    $dbname = "owdb";
    $dbport = 3306;

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
    CONFIG     => 0, 
    CONFIG_VAL => 1,
};

sub runSQL($)
{
    my @rec_a = ();
    my @row;
    my $sql = shift;
    if (!defined($sql)) {
        return;
    }

    #printf("RUNSQL: $sql\n");
    my $sth = $dbh->prepare($sql);
    $sth->execute() or printf("SQL err: [$sql]" . "(" . length($sql) .")" . $sth->errstr);
    while (@row = $sth->fetchrow_array) {
        my @recs = @row;
        push(@rec_a, \@recs);
    }
    $sth->finish();

    return \@rec_a;
}

use constant {
    SCHED_ID      => 0,
    SCHED_NAME    => 1,
    SCHED_IP      => 2,
    SCHED_IPALIAS => 3,
};

sub getScheduleInfo($)
{
    my %schedule_h = ();
    my $siteid = shift;
    if (!defined($siteid)) {
        return;
    }

    my $sql = qq/select id,name,ipaddr,ipalias from schedulemap,clusters where id=clusterid and siteid=$siteid/;
    my $recs = runSQL($sql);

    #printf("### @$recs\n $#$recs\n");

    if ($#$recs > -1) {
        for (my $i = 0; $i <= $#$recs; $i++) {
            my %sched_h = ();
            $sched_h{'id'} = $recs->[$i]->[SCHED_ID];
            $sched_h{'name'} = $recs->[$i]->[SCHED_NAME];
            $sched_h{'ip'} = $recs->[$i]->[SCHED_IP];
            $sched_h{'ipalias'} = $recs->[$i]->[SCHED_IPALIAS];
            $schedule_h{$recs->[$i]->[SCHED_NAME]} = \%sched_h;
        }
    }

    return \%schedule_h;
}

use constant {
    RECORD_ID        => 0, 
    RECORD_IP        => 1,
    RECORD_TYPE      => 2,
    RECORD_DNS       => 3,
    RECORD_DOMAINID  => 4,
    RECORD_REV       => 5,
    RECORD_WHOLENAME => 6,
    SITE_REV         => 0, 
    SITE_POLICY      => 1,
    SITE_PRIORY      => 2,
    SITE_VIEW        => 3,
    SITE_STATUS      => 4,
};

sub getSiteInfo($)
{
    my %site_h = ();
    my %conf_h = ();
    my $name = shift;
    if (!defined($name)) {
        return \%site_h;
    }
    
    my $sql = qq/select id,ip,type,dns,domain_id,rev,whole_name from records where whole_name="$name"/;
    my $recs = runSQL($sql);
    if ($#$recs >= 0) {
        $site_h{'id'} = $recs->[0]->[RECORD_ID];
        $site_h{'ip'} = $recs->[0]->[RECORD_IP];
        $site_h{'type'} = $recs->[0]->[RECORD_TYPE];
        $site_h{'dns'} = $recs->[0]->[RECORD_DNS];
        $site_h{'domainid'} = $recs->[0]->[RECORD_DOMAINID];
        $site_h{'rev_record'} = $recs->[0]->[RECORD_REV];
        $site_h{'whole_name'} = $recs->[0]->[RECORD_WHOLENAME];
    } else {
        printf("ERR: site ($name) no find in db!\n");
        return \%site_h;
    }

    if (exists($site_h{'id'}) and $site_h{'id'} > 0) {
        $sql = "select config, value from site_configswitch where siteid=$site_h{'id'}";
        $recs = runSQL($sql);
        for (my $i = 0; $i <= $#$recs; $i++) {
            $conf_h{$recs->[$i]->[CONFIG]} = $recs->[$i]->[CONFIG_VAL];
        }

        $sql = "select rev,policy,prioritycluster,views,status from sites where siteid=$site_h{'id'}";
        $recs = runSQL($sql);
        $site_h{'site_rev'} = $recs->[0]->[SITE_REV];
        $site_h{'site_policy'} = $recs->[0]->[SITE_POLICY];
        $site_h{'site_priory'} = $recs->[0]->[SITE_PRIORY];
        $site_h{'site_view'} = $recs->[0]->[SITE_VIEW];
        $site_h{'site_status'} = $recs->[0]->[SITE_STATUS];
    }

    # fill info
    $site_h{'config'} = \%conf_h;
    
    return \%site_h;
}

use constant {
    DOMAIN_ID   => 0,
    DOMAIN      => 1,
    STATUS      => 2,
    USER_ID     => 3,
    NS          => 4,
    CHECK_TIME  => 5,
    SITEDEFAULT => 6,
    TYPE        => 7,
    DNS_SRV     => 8,
    CHECKIN     => 9,
};

sub getDomainInfo($)
{
    my %domain_h = ();
    my $name = shift;
    if (!defined($name)) {
        return;
    }

    my $sql = "select id,domain,status,user_id,ns,check_time,sitedefault,type,dnsserver,checkin from domain where domain='$name';";
    my $recs = runSQL($sql);
    if ($#$recs >= 0) {
        $domain_h{'domain_id'} = $recs->[0]->[DOMAIN_ID];
        $domain_h{'domain'} = $recs->[0]->[DOMAIN];
        $domain_h{'status'} = $recs->[0]->[STATUS];
        $domain_h{'user_id'} = $recs->[0]->[USER_ID];
        $domain_h{'ns'} = $recs->[0]->[NS];
        $domain_h{'check_time'} = $recs->[0]->[CHECK_TIME];
        $domain_h{'sitedefault'} = $recs->[0]->[SITEDEFAULT];
        $domain_h{'type'} = $recs->[0]->[TYPE];
        $domain_h{'dns_srv'} = $recs->[0]->[DNS_SRV];
        $domain_h{'checkin'} = $recs->[0]->[CHECKIN];
    }

    # fill info
    return \%domain_h;
}

1;

