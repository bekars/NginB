#!/usr/bin/perl -w

# 统计由于丢包导致：
#     tcp建立连接时间长 > 1s
#     服务器响应时间长 > 3s
#     下载时间长 > 10s

use strict;
use Speedy::Utils;
use Speedy::Http;
use Speedy::AQB;
use Data::Dumper;
use IO::Handle;

use DBI;

my $dr_sites = {};
my $date_g = "20130426";
my $limit_g = "";#"limit 1000";
my $fp;
my $cluster;

my $dbh;
my ($dbhost, $dbuser, $dbpass, $dbname, $dbport);

sub load_db_config
{
    my $conf_file_path = '/etc/cesu.conf';
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
    $sth->execute() or die("SQL err: [$sql]" . "(" . length($sql) .")" . $sth->errstr);
    while (@row = $sth->fetchrow_array) {
        my @recs = @row;
        push(@rec_a, \@recs);
    }
    $sth->finish();

    return \@rec_a;
}

 
use constant {
    ROLE_NAME       => 0,
    URL             => 1,
    TCP_TIME_S      => 2,
    RES_TIME_S      => 3,
    DOWN_TIME_S     => 4,
    ROLE_IP         => 5,
    CLIENT_IP       => 6,
    HEADER          => 7,
    MONITOR_TIME    => 8,
};

sub walk_slow_url()
{
    my $node;
    my $sql = sprintf("select role_name,url,tcp_time_s,res_time_s,down_time_s,role_ip,client_ip,header,monitor_time from speed_res_data_%s where role_name like '%%%%_aqb' and (tcp_time_s>1 or res_time_s>3 or down_time_s>10) %s;", $date_g, $limit_g);
    my $recs_aqb = runSQL($sql);

    LOOP: for (my $i = 0; $i <= $#$recs_aqb; $i++) {
        $node->{role_name} = $recs_aqb->[$i]->[ROLE_NAME];
        $node->{url} = $recs_aqb->[$i]->[URL];
        $node->{url} =~ tr/%/#/;
        $node->{tcp_time} = $recs_aqb->[$i]->[TCP_TIME_S];
        $node->{resp_time} = $recs_aqb->[$i]->[RES_TIME_S];
        $node->{down_time} = $recs_aqb->[$i]->[DOWN_TIME_S];
        $node->{srv_ip} = $recs_aqb->[$i]->[ROLE_IP];
        $node->{cli_ip} = $recs_aqb->[$i]->[CLIENT_IP];
        if ($recs_aqb->[$i]->[HEADER] =~ m/.* HIT .*/) {
            $node->{hitcache} = 1;
        } else {
            $node->{hitcache} = 0;
        }
        if ($recs_aqb->[$i]->[HEADER] =~ m/.*\^X-Powered-By-Anquanbao: .* from (.*?)\^.*$/) {
            $node->{cluster} = $1;
        } else {
            $node->{cluster} = "UNKNOWN";
            #printf("### $recs_aqb->[$i]->[HEADER] ###");
            next LOOP;
        }
        if ($recs_aqb->[$i]->[ROLE_NAME] =~ m/^(.*?)_.*$/) {
            $node->{site} = $1;
        } else {
            $node->{site} = "";
        }
        
        my $site = getSiteInfo($node->{site});
        $node->{site_ip} = $site->{ip} if $site->{ip};

        ($node->{cli_country}, $node->{cli_loc}, $node->{cli_isp}) = match_ip_pos($node->{cli_ip});
        ($node->{srv_country}, $node->{srv_loc}, $node->{srv_isp}) = match_ip_pos($node->{srv_ip});
        ($node->{site_country}, $node->{site_loc}, $node->{site_isp}) = match_ip_pos($node->{site_ip});

        statistic_cluster($node);
    }
}

my $counter = 0;
sub statistic_cluster($)
{
    my $node = shift;

    $counter += 1;
    printf("### $counter\n");
    print Dumper($node);

    $cluster->{$node->{cluster}} += 1;
    
    log_one_record($node);
}

sub log_one_record($)
{
    my $node = shift;

    my $line = sprintf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t", 
        $node->{cluster}, 
        $node->{srv_ip}, 
        $node->{srv_loc}, 
        $node->{srv_isp}, 
        $node->{cli_ip}, 
        $node->{cli_loc}, 
        $node->{cli_isp}, 
        $node->{site_ip}, 
        $node->{site_loc}, 
        $node->{site_isp}, 
        $node->{tcp_time}, 
        $node->{resp_time}, 
        $node->{down_time}, 
        $node->{hitcache}, 
        $node->{url});

    printf($fp "$line\n");
}

sub log_header()
{
    my $line = sprintf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t", 
        "cluster", 
        "srv_ip", 
        "srv_loc",
        "srv_isp",
        "cli_ip", 
        "cli_loc",
        "cli_isp",
        "site_ip", 
        "site_loc",
        "site_isp",
        "tcp_time", 
        "resp_time", 
        "down_time", 
        "hitcache", 
        "url");
    printf($fp "$line\n");
}

use constant {
    IPSTART  => 1,
    IPEND    => 2,
    COUNTRY  => 3,
    PROVINCE => 4,
    ISP      => 5,
    ID  => 0,
    VAL => 1,
};

my $ip_pos;
my $country;
my $province;
my $isp;

sub load_ip_pos($)
{
    my $ipdb = shift;
    my @rec_a = ();
    my @row;
    my $sql;
    my $sth;
    my $db_hdl = DBI->connect("DBI:mysql:database=ip;host=116.213.78.197;user=readonly;password=anQuanba0sp11d;port=3306") or die("ConnDB err: " . DBI->errstr);

    $sql = "set names utf8";
    $sth = $db_hdl->prepare($sql);
    $sth->execute() or die("SQL err: [$sql]" . "(" . length($sql) .")" . $sth->errstr);
    $sth->finish();

    printf("### load ip pos\n");
    if ($ipdb eq "db") {
        $sql = "select id,ipstart,ipend,countryid,provinceid,ispid from ip";
        $sth = $db_hdl->prepare($sql);
        $sth->execute() or die("SQL err: [$sql]" . "(" . length($sql) .")" . $sth->errstr);
        while (@row = $sth->fetchrow_array) {
            my @rec_data = @row;
            push(@rec_a, \@rec_data);
        }
        $sth->finish();
    } else {
        open(my $ipfp, "<$ipdb") or die("ERR: can not open $ipdb!\n");
        while (<$ipfp>) {
            $_ =~ m/^(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)/;
            my @rec_data = ($1, $2, $3, $4, $5, $6);
            push(@rec_a, \@rec_data);
        }
        close($ipfp);
    }
    $ip_pos = \@rec_a;

    printf("### load country\n");
    $sql = "select id,country from country";
    $sth = $db_hdl->prepare($sql);
    $sth->execute() or die("SQL err: [$sql]" . "(" . length($sql) .")" . $sth->errstr);
    while (@row = $sth->fetchrow_array) {
        $country->{$row[ID]} = $row[VAL];
    }
    $sth->finish();
    
    printf("### load province\n");
    $sql = "select id,province from province";
    $sth = $db_hdl->prepare($sql);
    $sth->execute() or die("SQL err: [$sql]" . "(" . length($sql) .")" . $sth->errstr);
    while (@row = $sth->fetchrow_array) {
        $province->{$row[ID]} = $row[VAL];
    }
    $sth->finish();
 
    $sql = "select id,isp from isp";
    $sth = $db_hdl->prepare($sql);
    $sth->execute() or die("SQL err: [$sql]" . "(" . length($sql) .")" . $sth->errstr);
    while (@row = $sth->fetchrow_array) {
        $isp->{$row[ID]} = $row[VAL];
    }
    $sth->finish();
 
    $db_hdl->disconnect();
}


my @ip_cache = ();

sub match_ip_pos($)
{
    my $ip = shift;
    $ip =~ m/^(\d+?)\.(\d+?)\.(\d+?)\.(\d+?).*/;
    my $ipnum = $1*256*256*256 + $2*256*256 + $3*256 + $4;

    for (my $j = 0; $j <= $#ip_cache; $j++) {
        if ($ip_cache[$j][0] == $ipnum) {
            printf("### HIT ip cache\n");
            return ($ip_cache[$j][1], $ip_cache[$j][2], $ip_cache[$j][3]);
        }
    }

    if ($#ip_cache > 10000) {
        shift(@ip_cache);
    }

    for (my $i = 0; $i <= $#$ip_pos; $i++) {
        if (($ipnum > $ip_pos->[$i]->[IPSTART]) && ($ipnum < $ip_pos->[$i]->[IPEND])) {
            my @c = ($ipnum, $country->{$ip_pos->[$i]->[COUNTRY]},  
                $province->{$ip_pos->[$i]->[PROVINCE]}, $isp->{$ip_pos->[$i]->[ISP]});
            push(@ip_cache, \@c);
            return ($country->{$ip_pos->[$i]->[COUNTRY]}, 
                $province->{$ip_pos->[$i]->[PROVINCE]}, $isp->{$ip_pos->[$i]->[ISP]});
        }
    }

    return ("UFO", "UFO", "UFO");
}

#load_ip_pos("db");
load_ip_pos("ip_pos.db");

my $driver  = "DBI:mysql";
load_db_config();
# database connect
$dbh = DBI->connect("$driver:database=$dbname;host=$dbhost;user=$dbuser;password=$dbpass;port=$dbport") or die("ConnDB err: " . DBI->errstr);

open($fp, ">lost_pkt.txt");
$fp->autoflush(1);

log_header();
walk_slow_url();

$dbh->disconnect();

foreach my $k (sort {$cluster->{$b} <=> $cluster->{$a}} keys $cluster) {
    printf($fp "$k\t$cluster->{$k}\n");
}

close($fp);

1;

