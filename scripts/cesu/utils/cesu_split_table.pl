#!/usr/bin/perl -w

# 每日进行测速全元素数据库分表

use strict;
use Data::Dumper;
use IO::Handle;

use DBI;

my $today = `date -d "today" +"%Y-%m-%d"`;
my $yesterday = `date -d "last day" +"%Y-%m-%d"`;
my $yesterday1 = `date -d "last day" +"%Y%m%d"`;
$today =~ tr/\n//d;
$yesterday =~ tr/\n//d;
$yesterday1 =~ tr/\n//d;

my $dbh;
my ($dbhost, $dbuser, $dbpass, $dbname, $dbport);

my $union_file = "/home/apuadmin/baiyu/cesu_union_tables";

sub load_db_config
{
    $dbhost = "127.0.0.1";;	
    $dbuser = "cesu";	
    $dbpass = "cesu";
    $dbname = "speed";	
    $dbport = 3306;	
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
=pod
    while (@row = $sth->fetchrow_array) {
        my @recs = @row;
        push(@rec_a, \@recs);
    }
=cut
    $sth->finish();

    return \@rec_a;
}

sub get_union_tables()
{
    my $fp;
    my $sql = "";

    open($fp, "<$union_file");
    while (<$fp>) {
        $_ =~ tr/\n//d;
        $sql .= $_ . ",";
    }
    close($fp);

    $sql =~ m/(.*),/;
    #printf($1);
    return $1;
}

sub put_union_tables($)
{
    my $fp;
    my $table = shift;
    open($fp, ">>$union_file");
    printf($fp "$table\n");
    close($fp);
}

my $create_table_sql = "CREATE TABLE `speed_res_data_%s` ( 
  `id` int(20) unsigned NOT NULL AUTO_INCREMENT,
  `stat_main_id` int(10) unsigned NOT NULL DEFAULT '0',
  `role_id` bigint(20) NOT NULL,
  `role_name` varchar(500) DEFAULT NULL,
  `role_url` varchar(500) DEFAULT NULL,
  `role_ip` varchar(512) DEFAULT NULL,
  `down_size_bytes` float DEFAULT NULL,
  `mime_type` varchar(128) DEFAULT NULL,
  `status_code` int(11) DEFAULT NULL,
  `url` varchar(512) DEFAULT NULL,
  `header` text,
  `s_time_s` float DEFAULT NULL,
  `start_time_s` float DEFAULT NULL,
  `block_time_s` float DEFAULT NULL,
  `dns_time_s` float DEFAULT NULL,
  `tcp_time_s` float DEFAULT NULL,
  `req_time_ms` float DEFAULT NULL,
  `res_time_s` float DEFAULT NULL,
  `down_time_s` float DEFAULT NULL,
  `ssl_time_s` float DEFAULT NULL,
  `city_code` int(11) DEFAULT NULL,
  `city_code1` int(11) DEFAULT NULL,
  `netservice_id` int(4) DEFAULT NULL,
  `dns` varchar(512) DEFAULT NULL,
  `c_netspeed` float DEFAULT NULL,
  `client_type` int(11) DEFAULT NULL,
  `client_ip` varchar(512) DEFAULT NULL,
  `onebytes_time_s` float DEFAULT NULL,
  `down_speed_kbs` float DEFAULT NULL,
  `monitor_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_stat_res_main_id` (`stat_main_id`),
  KEY `index_role_name` (`role_name`(32))
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8";

my $import_data_sql = "insert into speed_res_data_%s (select * from speed_monitor_res_data where monitor_time>'%s 00:00:00' and monitor_time<'%s 00:00:00')";

my $union_table_sql = "alter table speed_res_data_all union(%s)";

my $sql;
my $recs;
my $driver  = "DBI:mysql";
load_db_config();
# database connect
$dbh = DBI->connect("$driver:database=$dbname;host=$dbhost;user=$dbuser;password=$dbpass;port=$dbport") or die("ConnDB err: " . DBI->errstr);

printf("### create table speed_res_data_%s\n", $yesterday1);
$sql = sprintf($create_table_sql, $yesterday1);
$recs = runSQL($sql);

printf("### import data into table speed_res_data_%s\n", $yesterday1);
$sql = sprintf($import_data_sql, $yesterday1, $yesterday, $today);
$recs = runSQL($sql);

printf("### alter uninon table speed_res_data_%s\n", $yesterday1);
put_union_tables("speed_res_data_$yesterday1");
$sql = sprintf($union_table_sql, get_union_tables());
$recs = runSQL($sql);

$dbh->disconnect();

1;

# vim: ts=4:sw=4:et

=pod
CREATE TABLE `speed_res_data_all` (
  `id` int(20) unsigned NOT NULL AUTO_INCREMENT,
  `stat_main_id` int(10) unsigned NOT NULL DEFAULT '0',
  `role_id` bigint(20) NOT NULL,
  `role_name` varchar(500) DEFAULT NULL,
  `role_url` varchar(500) DEFAULT NULL,
  `role_ip` varchar(512) DEFAULT NULL,
  `down_size_bytes` float DEFAULT NULL,
  `mime_type` varchar(128) DEFAULT NULL,
  `status_code` int(11) DEFAULT NULL,
  `url` varchar(512) DEFAULT NULL,
  `header` text,
  `s_time_s` float DEFAULT NULL,
  `start_time_s` float DEFAULT NULL,
  `block_time_s` float DEFAULT NULL,
  `dns_time_s` float DEFAULT NULL,
  `tcp_time_s` float DEFAULT NULL,
  `req_time_ms` float DEFAULT NULL,
  `res_time_s` float DEFAULT NULL,
  `down_time_s` float DEFAULT NULL,
  `ssl_time_s` float DEFAULT NULL,
  `city_code` int(11) DEFAULT NULL,
  `city_code1` int(11) DEFAULT NULL,
  `netservice_id` int(4) DEFAULT NULL,
  `dns` varchar(512) DEFAULT NULL,
  `c_netspeed` float DEFAULT NULL,
  `client_type` int(11) DEFAULT NULL,
  `client_ip` varchar(512) DEFAULT NULL,
  `onebytes_time_s` float DEFAULT NULL,
  `down_speed_kbs` float DEFAULT NULL,
  `monitor_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_stat_res_main_id` (`stat_main_id`)
) ENGINE=MRG_MyISAM DEFAULT CHARSET=utf8 INSERT_METHOD=LAST UNION=(`speed_res_data_20130420`,`speed_res_data_20130421`,`speed_res_data_20130422`,`speed_res_data_20130423`)
=cut

