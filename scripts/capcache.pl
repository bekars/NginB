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
use Speedy::TTL qw(&ttl_analysis_mod &ttl_analysis_init &ttl_result &get_maxage_interval &get_expired_interval %expires_h);
use Speedy::CacheControl qw(&cachecontrol_analysis_mod &cachecontrol_analysis_init);
use Speedy::CacheHit qw(&cachehit_analysis_mod &cachehit_analysis_init &cachehit_result %cache_hit_h %cache_http_status_h %cache_expired_h);
use Speedy::Utils;
use Speedy::Html qw(&html_analysis_mod &html_analysis_init %html_http_header_h);
use IO::Handle;

use Speedy::ClientPos;

my %options = ();
my $startime = new Benchmark;

my $log_time = "20130531";
my $home_dir = "/var/BLOGS/$log_time";
my $debug = 0;
my $debuglog = 0;

my %mod_h = ();


my $clipos_hld = Speedy::ClientPos->new();
$clipos_hld->set_debug_on();


sub mod_init
{
    $mod_h{date} = $log_time;
    $mod_h{dir} = "SPD_$log_time";

    $clipos_hld->set_basedir("/home/apuadmin/baiyu");
    $clipos_hld->init();

=pod
    ttl_analysis_init(\%mod_h);
    cachehit_analysis_init(\%mod_h);
    cachecontrol_analysis_init(\%mod_h);
    html_analysis_init(\%mod_h);
=cut
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
# Log Format
# 127.0.0.1 chn-jx-jy-sb1.24467-52715356-1 remote_user [27/Nov/2012:12:10:59 +0800] "GET http://www.google-analytics.com/utm.gif?utmwv=5.3.8&utms=1&utmn=2097981030&utmhn=www.anquanbao.com HTTP/1.1" 200 35 "http://www.anquanbao.com/" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:17.0) Gecko/17.0 Firefox/17.0" "x_forward" "cookie" HIT "Wed, 19 Apr 2000 11:43:00 GMT" "private, no-cache, no-cache=Set-Cookie, proxy-revalidate" "etag" "Wed, 21 Jan 2004 19:51:30 GMT" 0.085 0.085 "req_body"
#
# log_format main 
#   $remote_addr $hostname $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" 
#   "$http_user_agent" "$http_x_forwarded_for" "$http_cookie" $upstream_cache_status
#   "$upstream_http_expires" "$upstream_http_cache_control" "$upstream_http_etag" "$upstream_http_last_modified"
#   $request_time $upstream_response_time "$request_body";
#
my $log_reg = qr/^(?# REMOTE_IP)(.*?)\s+(?# CLUSTER)(.*?)\.(?# THREAD)(.*?)\s+(?# REMOTE_USER)(.*?)\s+\[(?# TIME)(.*?)\]\s+\"(?# URI)(.*?)\"\s+(?# HTTP_STATUS)(.*?)\s+(?# BODY_LEN)(.*?)\s+\"(?# REFER)(.*?)\"\s+\"(?# AGENT)(.*?)\"\s+\"(?# X_FORWARD)(.*?)\"\s+\"(?# COOKIE)(.*?)\"\s+(?# CACHE_STATUS)(.*?)\s+\"(?# EXPIRED)(.*?)\"\s+\"(?# CACHE_CONTROL)(.*?)\"\s+\"(?# ETAG)(.*?)\"\s+\"(?# LAST_MODIFIED)(.*?)\"\s+(?# REQ_TIME)(.*?)\s+(?# UPSTREAM_TIME)(.*?)\s+\"(?# REQ_BODY)(.*?)\".*/;

use constant {REMOTE_IP=>0, CLUSTER=>1, THREAD=>2, REMOTE_USER=>3, TIME=>4, URL=>5, HTTP_STATUS=>6, BODY_LEN=>7, REFER=>8, AGENT=>9, X_FORWARD=>10, COOKIE=>11, CACHE_STATUS=>12, EXPIRED=>13, CACHE_CONTROL=>14, ETAG=>15, LAST_MODIFIED=>16, REQ_TIME=>17, UPSTREAM_TIME=>18, REQ_BODY=>19};

#
# log_data_a : log reg word segment
# domain     : domain name
# log        : whle log line
#
sub analysis
{
    my ($log_data_a, $domain, $log) = @_;

    $log =~ s/%/%%/g;

    my ($http_method, $http_url, $http_arg, $http_suffix) = analysis_url($log_data_a->[URL]);
    $log_data_a->[CLUSTER] =~ m/(.*)-.*/;
    my ($cluster_room) = $1;
 
    my %node_h = (
        domain          => $domain,
        log             => $log,
        remote_ip       => $log_data_a->[REMOTE_IP],
        cluster         => $log_data_a->[CLUSTER],
        cluster_room    => $cluster_room,
        thread          => $log_data_a->[THREAD],
        remote_user     => $log_data_a->[REMOTE_USER],
        time            => $log_data_a->[TIME],
        http_method     => $http_method,
        http_url        => $http_url,
        http_arg        => $http_arg,
        http_suffix     => $http_suffix,
        http_status     => $log_data_a->[HTTP_STATUS],
        body_len        => $log_data_a->[BODY_LEN],
        refer           => $log_data_a->[REFER],
        agent           => $log_data_a->[AGENT],
        x_forward       => $log_data_a->[X_FORWARD],
        cookie          => $log_data_a->[COOKIE],
        cache_status    => $log_data_a->[CACHE_STATUS],
        cache_expired   => $log_data_a->[EXPIRED],
        cache_control   => $log_data_a->[CACHE_CONTROL],
        http_etag       => $log_data_a->[ETAG],
        http_lastmodify => $log_data_a->[LAST_MODIFIED],
        req_time        => $log_data_a->[REQ_TIME],
        upstream_time   => $log_data_a->[UPSTREAM_TIME],
        req_body        => $log_data_a->[REQ_BODY],
    );
    
    if ($debug) {
        dump_mod(\%node_h);
    }

    $clipos_hld->analysis(\%node_h);

=pod
    nocache_analysis_mod(\%node_h);
    cachehit_analysis_mod(\%node_h);
    ttl_analysis_mod(\%node_h);
    cachecontrol_analysis_mod(\%node_h);
    html_analysis_mod(\%node_h);
=cut
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

#
# filepath : log file path
# func     : parse log line cb (analysis)
# reg      : log line reg
# domain   : log domain name
#
sub parse_log
{
    my ($filepath, $func, $reg, $domain) = @_;
    my $errcnt = 0;

    my $tmpfile = unzip_tmpfile($filepath);
    if (!defined($tmpfile)) {
        printf("ERR: unzip $filepath error!");
        return;
    }

    open(FILEHANDLE, $tmpfile) or log_exit("Can not open file $tmpfile!");

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

#
# dir    : logs location
# suffix : log file suffix
# cbfunc : call back to parse log (parse_log)
#
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

    opendir(DIRHANDLE, $dir) or log_exit("Can not open dir $dir !");

    my @file_a = readdir(DIRHANDLE);
    for my $i (0..$#file_a) {
        if ($file_a[$i] =~ m/access_(.*?)_80\.$suffix(|\.gz)$/i) {
            $cnt += 1;
            printf("Analysis $cnt $1 Log File: $file_a[$i] ...\n\n");
            ## parse_log ########
            &{$cbfunc}("$dir/$file_a[$i]", \&analysis, $log_reg, $1);
        }
        $|++;
    }
 
    closedir(DIRHANDLE);
}

sub walk_log
{
    my ($dir, $suffix, $cbfunc, $log_arr) = @_;

    my $cnt = 0;

    if (!defined($suffix)) {
        $suffix = ".*";
    }

    foreach my $node (@$log_arr) {
        printf("### $node\n");
        my $file = $dir . "/access_" . $node . "_80\." . $suffix;

        if (-e $file) {
            $cnt += 1;
            printf("Analysis $cnt $node Log File: $file ...\n\n");
            ## parse_log ########
            &{$cbfunc}($file, \&analysis, $log_reg, $node);
        }
    }

    return 1;
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


##########################################
# start main
#
##########################################

getopts('t:d:f:hTDL', \%options);
if (exists($options{h})) {
    usage();
}

if (exists($options{D})) {
    $debug = 1;
}

if (exists($options{L})) {
    $debuglog = 1;
}

if (exists($options{t})) {
    $log_time = $options{t};
}

if (exists($options{d})) {
    $home_dir = $options{d};
}

mod_init();

if (exists($options{f})) {
    -e $options{f} or log_exit("ERR: no find file $options{f}!");

    open(my $fp, "<$options{f}");
    my @log_arr = ();
    while (<$fp>) {
        $_ =~ tr/\n//d;
        push(@log_arr, $_)
    }
    close($fp);
    
    walk_log($home_dir, "log.$log_time", \&parse_log, \@log_arr);
 
    #if ($options{f} =~ m/.*?access_(.*?)_.*/i) {
    #    printf("Analysis $1 Log File: $options{f} ...\n\n");
        ## parse_log ########
    #    parse_log($options{f}, \&analysis, $log_reg, $1);
    #}
} else {
    mkdir("SPD_$log_time", 0755);# or log_exit("ERR: can not mkdir $options{t}!");
    walk_dir($home_dir, "log.$log_time", \&parse_log);
}

$clipos_hld->fini();
#$clipos_hld->destroy();

=pod
my $result_file = sprintf("%s/analysis_%s.result", $mod_h{dir}, $mod_h{date});
showHash(\%cache_hit_h, "CACHE_HIT", $result_file);
showHash(\%cache_http_status_h, "CACHE_STATUS", $result_file);
showHash(\%cache_expired_h, "CACHE_NOTTL", $result_file);
showHash(\%nocache_http_status_h, "NOCACHE_STATUS", $result_file);
showHash(\%nocache_http_header_h, "NOCACHE_HEADER", $result_file);
showHash(\%nocache_http_suffix_h, "NOCACHE_SUFFIX", $result_file);
showHash(\%html_http_header_h, "HTML_HEADER", $result_file);
showHash(\%expires_h, "EXPIRED_TTL", $result_file);


cachehit_result();
ttl_result();
=cut


if (exists($options{T})) {
    printf "\n\n### %s ###\n\n", timestr(timediff(new Benchmark, $startime));
}


__END__


