#!/usr/bin/perl -w

#################################################
# Speedy统计运算的总入口
# 调用其他功能模块完成统计计算
#
#################################################

use strict;
use Benchmark;
use Getopt::Std;
use Data::Dumper;
use Date::Parse;
use Speedy::TTL qw(&ttl_analysis_mod &ttl_dump_log &get_maxage_interval &get_expired_interval %expires_h);
use Speedy::CacheControl qw(&cachecontrol_analysis_mod);
use Speedy::CacheHit qw(&cachehit_analysis_mod &cachehit_analysis_init &cachehit_result %cache_hit_h);
#use Time::Interval;

my %options = ();
my $startime = new Benchmark;

my $home_dir = "/usr/local/apache2/logs/";
my $debug = 0;
my $debuglog = 0;

sub show_hash
{
    my ($hash, $name) = @_;
    my $key;
    my $key_tmp;

    if (!defined($name)) {
        $name = "HASH";
    }

    printf("$name = {\n");
    foreach $key (sort keys %$hash) {
        $key_tmp = $key;
        $key_tmp =~ tr/%/#/;
        printf("       '$key_tmp' => $hash->{$key},\n");
    }
    printf("};\n");
}

sub mod_init
{
    my %mod_h = (
        date => $options{t},
    );

    cachehit_analysis_init(\%mod_h);
}

#
# analysis html resource
#
my %html_http_header_h = ();

my $ccontrol_nocache_reg = qr/.*(no-cache|no-store|private).*$/;
my $ccontrol_maxage_reg = qr/.*max-age=(.*?)(|,.*|\s.*)$/;
sub is_valid_cache_control
{
    my $ccontrol = shift;
    if (!defined($ccontrol)) {
        return 0;
    }

    if ($ccontrol =~ m/$ccontrol_nocache_reg/) {
        return 0;
    }
 
    my @age = ($ccontrol =~ m/$ccontrol_maxage_reg/);
    if (($#age > 0) && ($age[0] > 0)) {
        return 1;
    }

    return 0;
}
    
sub is_valid_expired
{
    my ($expired, $logtime) = @_;
    
    if (length($expired) < 20) {
        return 0;
    }

    $expired = str2time($expired);
    $logtime = str2time($logtime);

    if ($expired > $logtime) {
        return 1;
    }

    return 0;
}

sub analysis_html_mod
{
    my $node_h = shift;
    if (!defined($node_h)) {
        return;
    }

    my $hflag = 0;
    my $cflag = 0;

    if (($node_h->{http_etag} ne "-") &&
        ($node_h->{http_etag} ne "")) {
        $hflag |= 1;
        $html_http_header_h{http_etag} += 1;
        $html_http_header_h{http_etag_FLOW} += $node_h->{http_len};
    }
    
    if (($node_h->{http_lastmodify} ne "-") &&
        ($node_h->{http_lastmodify} ne "")) {
        $hflag |= 2;
        $html_http_header_h{http_lastmodify} += 1;
        $html_http_header_h{http_lastmodify_FLOW} += $node_h->{http_len};
    }
    
    if (($node_h->{cache_control} ne "-") &&
        ($node_h->{cache_control} ne "")) {
        $hflag |= 4;
        $html_http_header_h{cache_control} += 1;
        $html_http_header_h{cache_control_FLOW} += $node_h->{http_len};
    }
    
    if (($node_h->{cache_expired} ne "-") &&
        ($node_h->{cache_expired} ne "")) {
        $hflag |= 8;
        $html_http_header_h{cache_expired} += 1;
        $html_http_header_h{cache_expired_FLOW} += $node_h->{http_len};
    }
    
    $html_http_header_h{TOTAL} += 1;
    $html_http_header_h{TOTAL_FLOW} += $node_h->{http_len};

    #
    # 统计
    # 1. 可以缓存的html流量
    # 2. 首页可以缓存的流量
    #
    # 判断逻辑
    #   存在Set-Cookie头不能缓存(log中目前没有记录)；
    #   如果存在Cache-Control头，存在no-cache/no-store/private标记不能缓存, max-age大于0可以缓存；
    #   如果没有Cache-Control头而有Expirs头，Expirs时间有效且在未来可以缓存；
    #   如果Cache-Control和Expirs头都没有，而有ETag或者Last-Modified则可以缓存 ???；
    #
    if ($hflag & 4)
    {
        if (is_valid_cache_control($node_h->{cache_control})) {
            $cflag = 1;
        }
    } elsif ($hflag & 8) {
        if (is_valid_expired($node_h->{cache_expired}, $node_h->{time})) {
            $cflag = 1;
        }
    } elsif (($hflag & 1) || ($hflag & 2)) {
        $cflag = 1;
    }

    if ($cflag) {
        $html_http_header_h{CACHE} += 1;
        $html_http_header_h{CACHE_FLOW} += $node_h->{http_len};
        if ($node_h->{http_url} eq "/") {
            $html_http_header_h{CACHE_MAINPAGE} += 1;
            $html_http_header_h{CACHE_MAINPAGE_FLOW} += $node_h->{http_len};
        }
    
        if ($hflag & 2) {
            $html_http_header_h{CACHE_LM} += 1;
            $html_http_header_h{CACHE_LM_FLOW} += $node_h->{http_len};
        }
    }

    if ($cflag) {
        if ($debuglog) {
            $node_h->{http_url} =~ tr/%/#/;
            printf(DUMPFILE "CACHEURL: $node_h->{domain}$node_h->{http_url} || $node_h->{time} || $node_h->{http_etag} || $node_h->{cache_control} || $node_h->{cache_expired}\n");
        }
    } else {
        if ($debuglog) {
            $node_h->{http_url} =~ tr/%/#/;
            printf(DUMPFILE "NOCACHE: $node_h->{domain}$node_h->{http_url} || $node_h->{time} || $node_h->{http_etag} || $node_h->{cache_control} || $node_h->{cache_expired}\n");
        }
    } 
}

#
# analysis no-cache resource
#
my %nocache_http_status_h = ();
my %nocache_http_header_h = ();
my %nocache_http_suffix_h = ();

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
    
    if (($node_h->{http_suffix} ne "-") &&
        ($node_h->{http_suffix} ne "")) {
        $nocache_http_suffix_h{".$node_h->{http_suffix}"} += 1;
        $nocache_http_suffix_h{".$node_h->{http_suffix}" . "_FLOW"} += $node_h->{http_len};
    } else {
        $nocache_http_suffix_h{".NOSUFFIX"} += 1;
        $nocache_http_suffix_h{".NOSUFFIX_FLOW"} += $node_h->{http_len};
    }

    if (($node_h->{http_suffix} eq "htm") ||
        ($node_h->{http_suffix} eq "html") ||
        ($node_h->{http_suffix} eq "/") ||
        ($node_h->{http_suffix} eq "//")) {
        analysis_html_mod($node_h);
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
    my $http_suffix = "";
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
                $http_suffix = $1;
            }
        } else {
            if ($http_url eq "/") {
                $http_suffix = "/";
            } elsif (substr($http_url, -1, 1) eq "/") {
                $http_suffix = "//";
            }
        }
    }

    $http_suffix =~ tr/A-Z/a-z/;

    push(@ret_a, $http_method);
    push(@ret_a, $http_url);
    push(@ret_a, $http_arg);
    push(@ret_a, $http_suffix);
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

    my ($http_method, $http_url, $http_arg, $http_suffix) = analysis_url($log_data_a->[1]);
 
    my %node_h = (
        domain          => $domain,
        log             => $log,
        time            => $log_data_a->[0],
        http_method     => $http_method,
        http_url        => $http_url,
        http_arg        => $http_arg,
        http_suffix      => $http_suffix,
        http_status     => $log_data_a->[2],
        http_len        => $log_data_a->[3],
        cache_status    => $log_data_a->[4],
        cache_expired   => $log_data_a->[5],
        cache_control   => $log_data_a->[6],
        http_etag       => $log_data_a->[7],
        http_lastmodify => $log_data_a->[8],
    );
    
    if ($debug) {
        dump_mod(\%node_h);
    }

    nocache_analysis_mod(\%node_h);
    cachehit_analysis_mod(\%node_h);
    ttl_analysis_mod(\%node_h);
    cachecontrol_analysis_mod(\%node_h);
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
    my $errcnt = 0;

    my $tmpfile = unzip_tmpfile($filepath);
    if (!defined($tmpfile)) {
        printf("ERR: unzip $filepath error!");
        return;
    }

    open(FILEHANDLE, $tmpfile) or do_exit("Can not open file $tmpfile!");

    LOOP: while (<FILEHANDLE>) {
        my @line = ($_ =~ m/$reg/);
        if ($#line > 0) {
            ## analysis ########
            &{$func}(\@line, $domain, $_);
        } else {
            $errcnt += 1;
            if ($debug) {
                printf("ERR: line regex: $_\n");
            }
        }

        if ($errcnt > 100) {
            printf("   ERR: $filepath format error!\n");
            last LOOP;
        }
    }

    close(FILEHANDLE);
}

sub walk_dir
{
    my ($dir, $suffix, $cbfunc) = @_;
    if (!defined($dir)) {
        return;
    }

    my $cnt = 0;
    
    if (!defined($suffix)) {
        $suffix = ".*";
    }

    opendir(DIRHANDLE, $dir) or do_exit("Can not walk dir $dir !");

    my @file_a = readdir(DIRHANDLE);
    for my $i (0..$#file_a) {
        if ($file_a[$i] =~ m/access_(.*?)_80\.$suffix(|\.gz)$/i) {
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
          "    -D               debug mode on\n" .
          "    -L               debug log mode on\n" .
          "    -h               for help\n");
    exit();
}


getopts('t:d:f:hTDL', \%options);
if (exists($options{h})) {
    usage();
}

open(DUMPFILE, ">dump.result");

if (exists($options{D})) {
    $debug = 1;
}

if (exists($options{L})) {
    $debuglog = 1;
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

    mod_init();
    walk_dir($home_dir, "log.$options{t}", \&parse_log);
}

show_hash(\%cache_hit_h, "CACHE_HIT");
#show_hash(\%cache_http_status_h, "CACHE_STATUS");
#show_hash(\%cache_expired_h, "CACHE_NOTTL");
show_hash(\%nocache_http_status_h, "NOCACHE_STATUS");
show_hash(\%nocache_http_header_h, "NOCACHE_HEADER");
show_hash(\%nocache_http_suffix_h, "NOCACHE_SUFFIX");
show_hash(\%html_http_header_h, "HTML_HEADER");
show_hash(\%expires_h, "EXPIRED_TTL");


cachehit_result();
ttl_dump_log();

if (exists($options{T})) {
    printf "\n\n### %s ###\n\n", timestr(timediff(new Benchmark, $startime));
}

close(DUMPFILE);

__END__


