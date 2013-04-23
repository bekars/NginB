#!/usr/bin/perl -w

# 统计HIT之后下载比源站慢的节点

use strict;
use Speedy::Utils;
use Speedy::Http;
use Data::Dumper;
use IO::Handle;

use DBI;

my $dr_sites = {};
my $date_g = "2013-03-24";
my $fp;

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
    DOWN_SIZE   => 0,
    DOWN_TIME   => 1,
    DOWN_SPEED  => 2,
    ROLE_IP     => 3,
    URL         => 4,
    HEADER      => 5,
    CLI_IP      => 6,
    CLI_TYPE    => 7,
};
sub dr_one_site_elements($)
{
    my $site_ref = shift;
    my $cluster = "";
    
    my $sql = sprintf("select down_size_bytes, down_time_s, down_speed_kbs, role_ip, url, header, client_ip, client_type from speed_monitor_res_data where mime_type like 'image/%%%%' and role_id=%d and monitor_time='%s';", 
        $site_ref->{aqb}{role_id}, $site_ref->{aqb}{monitor_time});
    my $recs_aqb = runSQL($sql);
    
    $sql = sprintf("select down_size_bytes, down_time_s, down_speed_kbs, role_ip, url, header, client_ip, client_type from speed_monitor_res_data where mime_type like 'image/%%%%' and role_id=%d and monitor_time='%s';", 
        $site_ref->{org}{role_id}, $site_ref->{org}{monitor_time});
    my $recs_org = runSQL($sql);

    for (my $i = 0; $i <= $#$recs_aqb; $i++) {
        if ($recs_aqb->[$i]->[HEADER] =~ m/.*\^X-Powered-By-Anquanbao: HIT from (.*?)\^.*$/) {
            $cluster = $1;

            if ($recs_aqb->[$i]->[DOWN_TIME] == 0) {
                $recs_aqb->[$i]->[DOWN_TIME] = -1;
            }

            LOOP: for (my $j = 0; $j <= $#$recs_org; $j++) {
                if ($recs_org->[$j]->[URL] eq $recs_aqb->[$i]->[URL]) {
                    if ($recs_org->[$j]->[DOWN_TIME] == 0) {
                        $recs_org->[$j]->[DOWN_TIME] = -1;
                    }

                    if (($recs_aqb->[$i]->[DOWN_TIME]>1) && ($recs_aqb->[$i]->[DOWN_TIME]/$recs_org->[$j]->[DOWN_TIME]) > 1.5) {
                        $site_ref->{clusters}{$cluster}{$recs_aqb->[$i]->[URL]}{aqb}{downtime} = $recs_aqb->[$i]->[DOWN_TIME];
                        $site_ref->{clusters}{$cluster}{$recs_aqb->[$i]->[URL]}{org}{downtime} = $recs_org->[$j]->[DOWN_TIME];
                        $site_ref->{clusters}{$cluster}{$recs_aqb->[$i]->[URL]}{aqb}{ip} = $recs_aqb->[$i]->[ROLE_IP];
                        $site_ref->{clusters}{$cluster}{$recs_aqb->[$i]->[URL]}{org}{ip} = $recs_org->[$j]->[ROLE_IP];
                        $site_ref->{clusters}{$cluster}{$recs_aqb->[$i]->[URL]}{aqb}{cli_ip} = $recs_aqb->[$i]->[CLI_IP];
                        $site_ref->{clusters}{$cluster}{$recs_aqb->[$i]->[URL]}{org}{cli_ip} = $recs_org->[$j]->[CLI_IP];
                        $site_ref->{clusters}{$cluster}{$recs_aqb->[$i]->[URL]}{aqb}{cli_type} = $recs_aqb->[$i]->[CLI_TYPE];
                        $site_ref->{clusters}{$cluster}{$recs_aqb->[$i]->[URL]}{org}{cli_type} = $recs_org->[$j]->[CLI_TYPE];
                    }

                    last LOOP;
                }
            }
        }
    }
}

use constant {
    ROLE_ID      => 0,
    TOTAL_TIME   => 1,
    CITY_CODE    => 2,
    MONITOR_TIME => 3,
};
sub dr_one_site($$)
{
    my ($site, $hour) = @_;
    # find the max total time cesu record
    my $sql = sprintf("select role_id, total_time, city_code, monitor_time from speed_monitor_data where role_name='%s_aqb' and monitor_time>'%s %d:00:00' and monitor_time<'%s %d:00:00' and error_id=0 order by total_time desc limit 1;", 
        $site, $date_g, $hour, $date_g, $hour+1);

    my $recs = runSQL($sql);
    for (my $i = 0; $i <= $#$recs; $i++) {
        $dr_sites->{$site}{aqb}{role_id} = $recs->[$i]->[ROLE_ID];
        $dr_sites->{$site}{aqb}{total_time} = $recs->[$i]->[TOTAL_TIME];
        $dr_sites->{$site}{aqb}{city_code} = $recs->[$i]->[CITY_CODE];
        $dr_sites->{$site}{aqb}{monitor_time} = $recs->[$i]->[MONITOR_TIME];
    }

    $sql = sprintf("select role_id, total_time, city_code, monitor_time from speed_monitor_data where role_name='%s_ip' and monitor_time>'%s %d:00:00' and monitor_time<'%s %d:00:00' and error_id=0 and role_id=%d and city_code=%d;", 
        $site, $date_g, $hour, $date_g, $hour+1, $dr_sites->{$site}{aqb}{role_id}+1, $dr_sites->{$site}{aqb}{city_code});
    
    $recs = runSQL($sql);
    for (my $i = 0; $i <= $#$recs; $i++) {
        $dr_sites->{$site}{org}{role_id} = $recs->[$i]->[ROLE_ID];
        $dr_sites->{$site}{org}{total_time} = $recs->[$i]->[TOTAL_TIME];
        $dr_sites->{$site}{org}{city_code} = $recs->[$i]->[CITY_CODE];
        $dr_sites->{$site}{org}{monitor_time} = $recs->[$i]->[MONITOR_TIME];
    }

    if ($#$recs != -1) {
        if (($dr_sites->{$site}{aqb}{total_time}/$dr_sites->{$site}{org}{total_time}) > 1.5) {
            dr_one_site_elements($dr_sites->{$site});
        }
    }

    print Dumper($dr_sites->{$site});
    
}

sub log_one_site($)
{
    my $site_k = shift;
    if (exists($dr_sites->{$site_k}) && exists($dr_sites->{$site_k}->{clusters})) {
        my $len = keys %{$dr_sites->{$site_k}->{clusters}};
        if ($len > 0) { 
            printf($fp "[$site_k]\n");
            foreach my $srv_k (sort keys %{$dr_sites->{$site_k}->{clusters}}) {
                printf($fp "$srv_k\n");
                foreach my $e (sort keys %{$dr_sites->{$site_k}->{clusters}->{$srv_k}}) {
                    printf($fp "\tURL: $e\n");
                    printf($fp "\tORG: $dr_sites->{$site_k}->{clusters}->{$srv_k}{$e}{org}{ip}, " .
                        "$dr_sites->{$site_k}->{clusters}->{$srv_k}{$e}{org}{downtime}, " .
                        "$dr_sites->{$site_k}->{clusters}->{$srv_k}{$e}{org}{cli_ip}, " .
                        "$dr_sites->{$site_k}->{clusters}->{$srv_k}{$e}{org}{cli_type}\n");
                    printf($fp "\tAQB: $dr_sites->{$site_k}->{clusters}->{$srv_k}{$e}{aqb}{ip}, " .
                        "$dr_sites->{$site_k}->{clusters}->{$srv_k}{$e}{aqb}{downtime}, " .
                        "$dr_sites->{$site_k}->{clusters}->{$srv_k}{$e}{aqb}{cli_ip}, " .
                        "$dr_sites->{$site_k}->{clusters}->{$srv_k}{$e}{aqb}{cli_type}\n");
                }
            }
        }
    }
}


open($fp, ">hit_download.result");
$fp->autoflush(1);

my $driver  = "DBI:mysql";
load_db_config();
# database connect
$dbh = DBI->connect("$driver:database=$dbname;host=$dbhost;user=$dbuser;password=$dbpass;port=$dbport") or die("ConnDB err: " . DBI->errstr);

open(my $fcesu, "<cesu.result");
while (<$fcesu>) {
    if (m/(.*?)\t(.*?)$/) {
        if ($1 < 0) {
            printf("### analysis $2 ...\n");
            dr_one_site($2, 12);
            log_one_site($2);
        }
    }
}
close($fcesu);

$dbh->disconnect();

close($fp);

1;

