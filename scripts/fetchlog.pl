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

sub run_sql
{
    $dbh = DBI->connect("$driver:database=$dbname;host=$dbhost;user=$dbuser;password=$dbpass;port=$dbport") or do_exit("ConnDB err: " . DBI->errstr);

    my $sql = "select type, site, log from logs where begin>1354204800 and end<1354291199 limit 10";
    my $sth = $dbh->prepare($sql);
    my $cnt = 1;

    $sth->execute() or do_exit("SQL err: " . $sth->errstr);
    while (my @recs = $sth->fetchrow_array) {
        print "$cnt => $recs[0] $recs[1] $recs[2] $recs[3]\n";
        $cnt += 1;

    }

    $sth->finish();

    $dbh->disconnect();
}

## get args ########

## get date log trackers ########
load_dbconfig();

run_sql();


#
# get every domain logs
#




