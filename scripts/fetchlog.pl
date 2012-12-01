#!/usr/bin/perl

use strict;
use DBI;
use Benchmark;
use Getopt::Std;
use Data::Dumper;

my %options = ();
my $startime = new Benchmark;

my $driver   = "DBI:mysql";
my $dbh;
my ($dbhost, $dbuser, $dbpass, $dbname, $dbport);

my $log_dir = "./LOGS";
my $log_date;
my $fdfs_cmd = "/opt/nevel/fdfs-file-zcat/bin/fdfs-file-zcat /etc/fdfs/client.conf";

sub do_exit
{
    my $str = shift;
    die "ERR: $str\n";
}

sub load_dbconfig
{
    $dbhost = "127.0.0.1";	
    $dbuser = "root";	
    $dbpass = "aqbsec-0000";
    $dbname = "logs";	
    $dbport = "3306";	
}

sub fetch_log
{
    my ($site, $path) = @_;
            
    my $out_file = "$log_dir/access_$site.log.$log_date";
    print "$fdfs_cmd >> $out_file\n";
}

sub run_sql
{
    my ($start, $end, $cb) = @_;
    $dbh = DBI->connect("$driver:database=$dbname;host=$dbhost;user=$dbuser;password=$dbpass;port=$dbport") or do_exit("ConnDB err: " . DBI->errstr);

    my $sql = "select type,site,path from logs where begin>$start and end<$end order by begin limit 100";
    my $sth = $dbh->prepare($sql);
    my $cnt = 1;

    $sth->execute() or do_exit("SQL err: " . $sth->errstr);
    while (my ($type, $site, $path) = $sth->fetchrow_array) {
        if (($type eq "1") and ($path ne "/")) {
            print "$cnt => $type $site $path\n";
            $cnt += 1;
            &{$cb}($site, $path);
        }
    }

    $sth->finish();
    $dbh->disconnect();
}

sub get_log_time
{
    my $date = shift;
    my @ret;

    if ($date =~ m/(.{4})(.{2})(.{2})/) {
        my $start = `date +%s -d'$1-$2-$3 00:00:00'`;
        my $end = `date +%s -d'$1-$2-$3 23:59:59'`;
        push(@ret, $start);
        push(@ret, $end);
        return @ret;
    } else {
        do_exit("date format error!");
        return;
    }
}

sub usage
{
    print("Usage: \n" . 
          "    -t <date>        date example 20121129\n" .
          "    -d <dir>         logs directory\n" .
          "    -T               benchmark\n" .
          "    -D               debug mode\n" .
          "    -h               for help\n");
    exit();
}


## get args ########
getopts('t:d:hTD', \%options);
if (exists($options{h}) || !exists($options{t})) {
    usage();
}

if (exists($options{d})) {
    $log_dir = $options{d};
}

(-e $log_dir) or mkdir($log_dir);

$log_date = $options{t};
my ($start_time, $end_time) = get_log_time($log_date);
printf("Start: " . `date -d \@$start_time` . "  End: " . `date -d \@$end_time` . "\n\n");

## get date log trackers ########
load_dbconfig();
    
run_sql($start_time, $end_time, \&fetch_log);


#
# get every domain logs
#




