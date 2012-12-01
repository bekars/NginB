#!/usr/bin/perl

use strict;
use Benchmark;
use Getopt::Std;
use Data::Dumper;
#use Time::Interval;

my %options = ();
my $startime = new Benchmark;

my $home_dir = "/usr/local/apache2/logs/";

sub show_hash
{
    my ($hash, $name) = @_;
    my $key;

    if (!defined($name)) {
        $name = "%HASH";
    }

    printf("%$name = {\n");
    foreach $key (sort keys %$hash) {
        printf("       '$key' => $hash->{$key},\n");
    }
    printf("};\n");
}

#
# analysis cache resource
#
my %cache_http_hit_h = ();
my %cache_http_status_h = ();

sub cache_analysis_mod
{
    my $node_h = shift;
    if (!defined($node_h)) {
        return;
    }

    if (($node_h->{cache_status} eq "-") ||
        ($node_h->{cache_status} eq "")) {
        return;
    }
    
    $cache_http_hit_h{$node_h->{cache_status}} += 1;
    $cache_http_hit_h{TOTAL} += 1;
    $cache_http_hit_h{"$node_h->{cache_status}" . "_FLOW"} += $node_h->{http_len};
    $cache_http_hit_h{TOTAL_FLOW} += $node_h->{http_len};
    $cache_http_status_h{$node_h->{http_status}} += 1;
    $cache_http_status_h{TOTAL} += 1;
    $cache_http_status_h{"$node_h->{http_status}" . "_FLOW"} += $node_h->{http_len};
    $cache_http_status_h{TOTAL_FLOW} += $node_h->{http_len};
}

#
# analysis no-cache resource
#
my %nocache_http_status_h = ();
my %nocache_http_header_h = ();
my %nocache_http_sufix_h = ();

sub nocache_analysis_mod
{
    my $node_h = shift;
    if (!defined($node_h)) {
        return;
    }

    if (($node_h->{cache_status} ne "-") &&
        ($node_h->{cache_status} ne "")) {
        return;
    }
    
    $nocache_http_status_h{$node_h->{http_status}} += 1;
    $nocache_http_status_h{TOTAL} += 1;
    $nocache_http_status_h{"$node_h->{http_status}" . "_FLOW"} += $node_h->{http_len};
    $nocache_http_status_h{TOTAL_FLOW} += $node_h->{http_len};

    if (($node_h->{http_etag} ne "-") &&
        ($node_h->{http_etag} ne "")) {
        $nocache_http_header_h{http_etag} += 1;
        $nocache_http_header_h{http_etag_FLOW} += $node_h->{http_len};
    }
    
    if (($node_h->{http_lastmodify} ne "-") &&
        ($node_h->{http_lastmodify} ne "")) {
        $nocache_http_header_h{http_lastmodify} += 1;
        $nocache_http_header_h{http_lastmodify_FLOW} += $node_h->{http_len};
    }
    
    if (($node_h->{cache_control} ne "-") &&
        ($node_h->{cache_control} ne "")) {
        $nocache_http_header_h{cache_control} += 1;
        $nocache_http_header_h{cache_control_FLOW} += $node_h->{http_len};
    }
    
    if (($node_h->{cache_expired} ne "-") &&
        ($node_h->{cache_expired} ne "")) {
        $nocache_http_header_h{cache_expired} += 1;
        $nocache_http_header_h{cache_expired_FLOW} += $node_h->{http_len};
    }
    
    if (($node_h->{http_sufix} ne "-") &&
        ($node_h->{http_sufix} ne "")) {
        $nocache_http_sufix_h{"." . "$node_h->{http_sufix}"} += 1;
        $nocache_http_sufix_h{".$node_h->{http_sufix}" . "_FLOW"} += $node_h->{http_len};
    } else {
        $nocache_http_sufix_h{".NOSUFIX"} += 1;
        $nocache_http_sufix_h{".NOSUFIX_FLOW"} += $node_h->{http_len};
    }
}

sub dump_mod
{
    my $node_h = shift;
    print(Dumper $node_h);
}

sub analysis_url
{
    my $http_line = shift;
    my $http_method = "";
    my $http_uri = "";
    my $http_sufix = "";
    my $http_url = "";
    my $http_arg = "";
    my @ret_a;

    if ($http_line =~ m/(.*?)\s+(.*?)\s+HTTP.*/) {
        $http_method = $1;
        $http_uri = $2;
    }

    if (length($http_uri)) {
        if ($http_uri =~ m/(.*?)\?(.*)/) {
            $http_url = $1;
            $http_arg = $2;
        } else {
            $http_url = $http_uri;
        }
    }

    if (length($http_url)) {
        if ($http_url =~ m/.*\.(.*)/) {
            if (length($1) <= 6) {
                $http_sufix = $1;
            }
        }
    }

    $http_sufix =~ tr/A-Z/a-z/;

    push(@ret_a, $http_method);
    push(@ret_a, $http_url);
    push(@ret_a, $http_arg);
    push(@ret_a, $http_sufix);
    return @ret_a;
}

#
# Rate - 各种头域出现的比率，整体的和未缓存的
# MISS Res - 未命中缓存资源
# No-Cache Res - 未缓存资源 ==> log
#
#
# Log Format
# 127.0.0.1 - - [27/Nov/2012:12:10:59 +0800] "GET http://www.google-analytics.com/__utm.gif?utmwv=5.3.8&utms=1&utmn=2097981030&utmhn=www.anquanbao.com HTTP/1.1" 200 35 "http://www.anquanbao.com/" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:17.0) Gecko/17.0 Firefox/17.0" "-" "-" MISS "Wed, 19 Apr 2000 11:43:00 GMT" "private, no-cache, no-cache=Set-Cookie, proxy-revalidate" "AAAAAAAAAAA" "Wed, 21 Jan 2004 19:51:30 GMT" 0.085 0.085 "-"
#
#        0    1   2      3      4            5       6             7    8 
# domain time url status length cache-status expired cache-control etag last-modified
#
#                     1           2         3       4                                                           5         6           7           8           9
my $log_reg = qr/.*?\[(?# TIME)(.*?)\]\s+\"(?# URI)(.*?)\"\s+(?# HTTP_STATUS)(.*?)\s+(?# HTTP_LEN)(.*?)\s+\"[^\"]*\"\s+\"[^\"]*\"\s+\"[^\"]*\"\s+\"[^\"]*\"\s+(?# CACHE_STATUS)(.*?)\s+\"(?# EXPIRED)(.*?)\"\s+\"(?# CACHE_CONTROL)(.*?)\"\s+\"(?# ETAG)(.*?)\"\s+\"(?# LAST_MODIFIED)(.*?)\"\s+.*/;

sub analysis
{
    my ($log_data_a, $domain, $log) = @_;

    #print(join "|", @$log_data_a);
    #print("\n\n");

    my ($http_method, $http_url, $http_arg, $http_sufix) = analysis_url($log_data_a->[1]);
 
    my %node_h = (
        domain          => $domain,
        log             => $log,
        time            => $log_data_a->[0],
        http_method     => $http_method,
        http_url        => $http_url,
        http_arg        => $http_arg,
        http_sufix      => $http_sufix,
        http_status     => $log_data_a->[2],
        http_len        => $log_data_a->[3],
        cache_status    => $log_data_a->[4],
        cache_expired   => $log_data_a->[5],
        cache_control   => $log_data_a->[6],
        http_etag       => $log_data_a->[7],
        http_lastmodify => $log_data_a->[8],
    );
    
    if (exists($options{D})) {
        dump_mod(\%node_h);
    }
    nocache_analysis_mod(\%node_h);
    cache_analysis_mod(\%node_h);
}

sub unzip_tmpfile
{
    my ($zipfile) = @_;
    if (!defined($zipfile)) {
        return;
    }
    
    my $tmpfile = "access_tmp.log";

    if (! -e $zipfile) {
        printf("ERR: $zipfile not exist!\n");
        return;
    }

    my $zipfile_org = $zipfile;
    $zipfile =~ s/\*/\\\*/;
    if ($zipfile =~ m/(.*)\.(.*)/) {
        if ($2 eq "gz") {
            system("gunzip -c $zipfile > /tmp/$tmpfile");
        } else {
            #system("cp -f $zipfile /tmp/$tmpfile");
            return $zipfile_org;
        }
    } else {
        return;
    }
 
    return "/tmp/$tmpfile";
}

sub parse_log
{
    my ($filepath, $func, $reg, $domain) = @_;

    my $tmpfile = unzip_tmpfile($filepath);
    if (!defined($tmpfile)) {
        printf("ERR: unzip $filepath error!");
        return;
    }

    open(FILEHANDLE, $tmpfile) or do_exit("Can not open file $tmpfile!");

    while (<FILEHANDLE>) {
        my @line = ($_ =~ m/$reg/);
        if ($#line > 0) {
            ## analysis ########
            &{$func}(\@line, $domain, $_);
        } else {
            if (exists($options{D})) {
                printf("ERR: line regex: $_\n");
            }
        }
    }

    close(FILEHANDLE);
}

sub walk_dir
{
    my ($dir, $sufix, $cbfunc) = @_;
    if (!defined($dir)) {
        return;
    }

    my $cnt = 0;
    
    if (!defined($sufix)) {
        $sufix = ".*";
    }

    opendir(DIRHANDLE, $dir) or do_exit("Can not walk dir $dir !");

    my @file_a = readdir(DIRHANDLE);
    for my $i (0..$#file_a) {
        if ($file_a[$i] =~ m/access_(.*?)_80\.$sufix(|\.gz)$/i) {
            $cnt += 1;
            printf("Analysis $cnt $1 Log File: $file_a[$i] ...\n\n");
            ## parse_log ########
            &{$cbfunc}("$dir/$file_a[$i]", \&analysis, $log_reg, $1);
        }
    }
    
    closedir(DIRHANDLE);
}

sub do_exit
{
    my $str = shift;
    die "$str\n";
}

sub usage
{
    print("Usage: \n" . 
          "    -t <date>        date example 20121129\n" .
          "    -d <dir>         logs directory\n" .
          "    -f <logfile>     analysis log file\n" .
          "    -T               benchmark\n" .
          "    -D               debug mode\n" .
          "    -h               for help\n");
    exit();
}


getopts('t:d:f:hTD', \%options);
if (exists($options{h})) {
    usage();
}

if (exists($options{f})) {
    -e $options{f} or do_exit("ERR: no find file $options{f}!");

    if ($options{f} =~ m/.*?access_(.*?)_.*/i) {
        printf("Analysis $1 Log File: $options{f} ...\n\n");
        ## parse_log ########
        parse_log($options{f}, \&analysis, $log_reg, $1);
    }
} else {
    if (!exists($options{t})) {
        usage();
    }

    if (exists($options{d})) {
        $home_dir = $options{d};
    }

    walk_dir($home_dir, "log.$options{t}", \&parse_log);
}

show_hash(\%cache_http_hit_h, "CACHE_HIT");
show_hash(\%cache_http_status_h, "CACHE_STATUS");
show_hash(\%nocache_http_status_h, "NOCACHE_STATUS");
show_hash(\%nocache_http_header_h, "NOCACHE_HEADER");
show_hash(\%nocache_http_sufix_h, "NOCACHE_SUFIX");


if (exists($options{T})) {
    printf "\n\n### %s ###\n\n", timestr(timediff(new Benchmark, $startime));
}

__END__


