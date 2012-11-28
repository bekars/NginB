#!/usr/bin/perl

use strict;
use Benchmark;
my $startime = new Benchmark;

my $logfile = "www.domain.com_80.log";

#
# Log Format
# 127.0.0.1 - - [27/Nov/2012:12:10:59 +0800] "GET http://www.google-analytics.com/__utm.gif?utmwv=5.3.8&utms=1&utmn=2097981030&utmhn=www.anquanbao.com HTTP/1.1" 200 35 "http://www.anquanbao.com/" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:17.0) Gecko/17.0 Firefox/17.0" "-" "-" MISS "Wed, 19 Apr 2000 11:43:00 GMT" "private, no-cache, no-cache=Set-Cookie, proxy-revalidate" "AAAAAAAAAAA" "Wed, 21 Jan 2004 19:51:30 GMT" 0.085 0.085 "-"
#
#        1    2   3           4      5            6       7             8    9
# domain time url http-status length cache-status expired cache-control etag last-modified
#
#                       1           2         3       4                                                           5         6           7           8           9
my $match_str = qr/.*?\[(.*?)\].*?\"(.*?)\"\s+(.*?)\s+(.*?)\s+\"[^\"]+\"\s+\"[^\"]+\"\s+\"[^\"]+\"\s+\"[^\"]+\"\s+(.*?)\s+\"(.*?)\"\s+\"(.*?)\"\s+\"(.*?)\"\s+\"(.*?)\"\s+.*/;

sub do_exit
{
    my $logstr = shift;
    die "$logstr\n";
}

sub analysis
{
    my $data = shift;
    print(join "|", @$data);
}

sub parse_log
{
    my ($filename, $func) = @_;

    open(FILEHANDLE, $filename) or do_exit("Can not open file $filename !");

    while (<FILEHANDLE>) {
        print("$_\n");
        my @line = ($_ =~ m/$match_str/);
        if ($#line > 0) {
            &{$func}(\@line);
        } else {
            print("Expr error!\n");
        }
    }

    close(FILEHANDLE);
}

parse_log($logfile, \&analysis);

printf "\n\n### %s ###\n\n", timestr(timediff(new Benchmark, $startime));

__END__

