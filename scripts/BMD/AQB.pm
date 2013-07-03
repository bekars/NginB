#!/usr/bin/perl -w

package	BMD::AQB;
use strict;
use Data::Dumper;
use BMD::DBH;

my $_dbh = undef;
my ($_dbhost, $_dbuser, $_dbpass, $_dbname, $_dbport) = (
    "127.0.0.1",
    "user",
    "passwd",
    "owdb",
    "3306"
);

sub new()
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = {
        'debug' => 0,
        @_,
    };

    _load_db_conf();
    _conn_db();

    $self->{dbh} = $_dbh;
    bless($self, $class);
    return $self;
}

sub _load_db_conf()
{
    my $conf_file = '/home/apuadmin/baiyu/antnest.conf';
    open(DB_CONFIG, $conf_file) or die("ERR: can't open $conf_file : $!");

    while (<DB_CONFIG>) {
        if (m/^DBHOST=(\S+)/) {
            $_dbhost = $1;	
        }
        elsif (m/^DBUSER=(\S+)/) {
            $_dbuser = $1;	
        }
        elsif (m/^DBPASS=(\S+)/) {
            $_dbpass = $1;
        }
        elsif (m/^DBNAME=(\S+)/) {
            $_dbname = $1;	
        }
        elsif (m/^DBPORT=(\S+)/) {
            $_dbport = $1;	
        }
    }
}

sub _conn_db()
{
    if (!$_dbh) {
        $_dbh = BMD::DBH->new(
            'dbhost' => $_dbhost,
            'dbuser' => $_dbuser,
            'dbpass' => $_dbpass,
            'dbname' => $_dbname,
            'dbport' => $_dbport
        );
        $_dbh->execute("set names utf8") if $_dbh;
    }
}

sub _close_db()
{
    $_dbh->destroy();
    $_dbh = undef;
}


use constant {
    CONFIG     => 0, 
    CONFIG_VAL => 1,
};

use constant {
    SCHED_ID      => 0,
    SCHED_NAME    => 1,
    SCHED_IP      => 2,
    SCHED_IPALIAS => 3,
    SCHED_TIME    => 4,
};

sub get_schedule_info($)
{
    my $self = shift;
    my $siteid = shift;
    return if (!defined($siteid));
    my $sched_h = undef;

    my $sql = qq/select id,name,ipaddr,ipalias,statustime from schedulemap,clusters where id=clusterid and siteid=$siteid/;
    my $recs = $_dbh->query($sql);
    for (my $i = 0; $i <= $#$recs; $i++) {
        my $cluster = $recs->[$i]->[SCHED_NAME];
        $sched_h->{$cluster}{'id'}      = $recs->[$i][SCHED_ID];
        $sched_h->{$cluster}{'name'}    = $recs->[$i][SCHED_NAME];
        $sched_h->{$cluster}{'ip'}      = $recs->[$i][SCHED_IP];
        $sched_h->{$cluster}{'ipalias'} = $recs->[$i][SCHED_IPALIAS];
        $sched_h->{$cluster}{'time'}    = $recs->[$i][SCHED_TIME];
    }

    return $sched_h;
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

sub get_site_info($)
{
    my $self = shift;
    my $name = shift;
    return if (!defined($name));
    my $site_h = undef;
    my $conf_h = undef;
    
    return $self->{site}{$name} if exists($self->{site}{$name});

    my $sql = qq/select id,ip,type,dns,domain_id,rev,whole_name from records where whole_name="$name"/;
    my $recs = $_dbh->query($sql);
    if ($#$recs > -1) {
        $site_h->{'id'}         = $recs->[0][RECORD_ID];
        $site_h->{'ip'}         = $recs->[0][RECORD_IP];
        $site_h->{'type'}       = $recs->[0][RECORD_TYPE];
        $site_h->{'dns'}        = $recs->[0][RECORD_DNS];
        $site_h->{'domainid'}   = $recs->[0][RECORD_DOMAINID];
        $site_h->{'rev_record'} = $recs->[0][RECORD_REV];
        $site_h->{'whole_name'} = $recs->[0][RECORD_WHOLENAME];
    } else {
        printf("ERR: site ($name) no find in db!\n");
        $self->{site}{$name} = undef;
        return;
    }

    if (exists($site_h->{'id'}) && ($site_h->{'id'} > 0)) {
        $sql = qq/select config,value from site_configswitch where siteid=$site_h->{'id'}/;
        $recs = $_dbh->query($sql);
        for (my $i = 0; $i <= $#$recs; ++$i) {
            $conf_h->{$recs->[$i][CONFIG]} = $recs->[$i][CONFIG_VAL];
        }

        $sql = qq/select rev,policy,prioritycluster,views,status from sites where siteid=$site_h->{'id'}/;
        $recs = $_dbh->query($sql);
        if ($#$recs > -1) {
            $site_h->{'site_rev'}    = $recs->[0][SITE_REV];
            $site_h->{'site_policy'} = $recs->[0][SITE_POLICY];
            $site_h->{'site_priory'} = $recs->[0][SITE_PRIORY];
            $site_h->{'site_view'}   = $recs->[0][SITE_VIEW];
            $site_h->{'site_status'} = $recs->[0][SITE_STATUS];
        }
    }

    $site_h->{'config'} = $conf_h;
    
    $self->{site}{$name} = $site_h;
    return $self->{site}{$name};
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

sub get_domain_info($)
{
    my $self = shift;
    my $name = shift;
    return if (!defined($name));
    my $domain_h = undef;
    my $sql = qq/select id,domain,status,user_id,ns,check_time,sitedefault,type,dnsserver,checkin from domain where domain='$name'/;
    my $recs = $_dbh->query($sql);
    if ($#$recs > -1) {
        $domain_h->{'domain_id'}   = $recs->[0][DOMAIN_ID];
        $domain_h->{'domain'}      = $recs->[0][DOMAIN];
        $domain_h->{'status'}      = $recs->[0][STATUS];
        $domain_h->{'user_id'}     = $recs->[0][USER_ID];
        $domain_h->{'ns'}          = $recs->[0][NS];
        $domain_h->{'check_time'}  = $recs->[0][CHECK_TIME];
        $domain_h->{'sitedefault'} = $recs->[0][SITEDEFAULT];
        $domain_h->{'type'}        = $recs->[0][TYPE];
        $domain_h->{'dns_srv'}     = $recs->[0][DNS_SRV];
        $domain_h->{'checkin'}     = $recs->[0][CHECKIN];
    }

    return $domain_h;
}

use constant {
    CLUSTER_ID      => 0,
    CLUSTER_NAME    => 1,
    CLUSTER_IP      => 2,
    CLUSTER_LOC     => 3,
    CLUSTER_IDC     => 4,
    CLUSTER_SCHED   => 5,
    CLUSTER_BAND    => 6,
    CLUSTER_IPALIAS => 7,
};

sub get_cluster_info($)
{
    my $self = shift;
    my $name = shift;
    return if (!defined($name));
    my $cluster_h = undef;

    $name =~ tr/[A-Z]/[a-z]/;
    
    return $self->{cluster}{$name} if exists($self->{cluster}{$name});
    
    my $sql = qq/select id,lower(name),ipaddr,location,idc,schedule,bandwidth,ipalias from clusters/;
    my $recs = $_dbh->query($sql);
    for (my $i = 0; $i <= $#$recs; ++$i) {
        $cluster_h->{$recs->[$i][CLUSTER_NAME]}{id}       = $recs->[$i][CLUSTER_ID];
        $cluster_h->{$recs->[$i][CLUSTER_NAME]}{name}     = $recs->[$i][CLUSTER_NAME];
        $cluster_h->{$recs->[$i][CLUSTER_NAME]}{ip}       = $recs->[$i][CLUSTER_IP];
        $cluster_h->{$recs->[$i][CLUSTER_NAME]}{location} = $recs->[$i][CLUSTER_LOC];
        $cluster_h->{$recs->[$i][CLUSTER_NAME]}{idc}      = $recs->[$i][CLUSTER_IDC];
        $cluster_h->{$recs->[$i][CLUSTER_NAME]}{sched}    = $recs->[$i][CLUSTER_SCHED];
        $cluster_h->{$recs->[$i][CLUSTER_NAME]}{band}     = $recs->[$i][CLUSTER_BAND];
        $cluster_h->{$recs->[$i][CLUSTER_NAME]}{ipalias}  = $recs->[$i][CLUSTER_IPALIAS];
    } 

    $self->{cluster} = $cluster_h;

    return $self->{cluster}{$name} if exists($self->{cluster}{$name});
    return;
}

sub destroy()
{
    my $self = shift;
    _close_db() if ($_dbh);
}

1;

# vim: ts=4:sw=4:et

