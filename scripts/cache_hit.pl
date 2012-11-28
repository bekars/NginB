#!/usr/bin/perl

use DBI;
use Time::Interval;
use Data::Dumper;

my $driver   = "DBI:mysql";
my ($dbhost, $dbuser, $dbpass, $dbname, $dbport);

my @uufo_stat_array = ();

sub do_log
{
    my $logstr = shift;
    die "$logstr\n";
}

sub load_config
{
    my $conf_file_path = 'cache_hit.conf';
    open my $conf_file, '<', $conf_file_path or die "can't open $conf_file_path : $!";

    while (<$conf_file>) {
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

=pod
# gif|jpg|jpeg|png|bmp|swf|js|css (hit/miss & size)
# cache_hit
# cache_miss
# cache_cnt
# cache_size
# other_cnt
# other_size
# total_cnt
# total_size

后缀是gif|jpg|jpeg|png|bmp|swf|js|css为可缓存，记录(cnt & size)和cache hit&miss
否则为不能缓存资源，记录other的cnt和size
计算total_cnt和total_size
=cut

my @site_array = ();
my $site_cnt = 0;

sub init_site
{
    my $site_name = shift;
    my %sinfo = ();
    $sinfo{site} = $site_name;
    $sinfo{cache_hit} = 0;
    $sinfo{cache_miss} = 0;
    $sinfo{cache_hit_size} = 0;
    $sinfo{cache_miss_size} = 0;
    $sinfo{cache_cnt} = 0;
    $sinfo{cache_size} = 0;
    $sinfo{other_cnt} = 0;
    $sinfo{other_size} = 0;
    $sinfo{total_cnt} = 0;
    $sinfo{total_size} = 0;

    my %objinfo = ();
    $objinfo{gif_cnt} = 0;
    $objinfo{gif_size} = 0;
    $objinfo{jpg_cnt} = 0;
    $objinfo{jpg_size} = 0;
    $objinfo{png_cnt} = 0;
    $objinfo{png_size} = 0;
    $objinfo{bmp_cnt} = 0;
    $objinfo{bmp_size} = 0;
    $objinfo{swf_cnt} = 0;
    $objinfo{swf_size} = 0;
    $objinfo{js_cnt} = 0;
    $objinfo{js_size} = 0;
    $objinfo{css_cnt} = 0;
    $objinfo{css_size} = 0;
    $objinfo{html_cnt} = 0;
    $objinfo{html_size} = 0;
    $objinfo{ufo_cnt} = 0;
    $objinfo{ufo_size} = 0;
    $sinfo{objinfo} = \%objinfo;
    
    my %ufoinfo = ();
    $ufoinfo{mpage_cnt} = 0;
    $ufoinfo{mpage_size} = 0;
    $ufoinfo{dir_cnt} = 0;
    $ufoinfo{dir_size} = 0;
    $ufoinfo{dyn_cnt} = 0;
    $ufoinfo{dyn_size} = 0;
    $ufoinfo{uufo_cnt} = 0;
    $ufoinfo{uufo_size} = 0;
    $sinfo{ufoinfo} = \%ufoinfo;

    return \%sinfo;
}

sub get_site_in_array
{
    my $sname = shift;
    my $sinfo;

    for my $index (0..$#site_array) {
        $sinfo = $site_array[$index];
        if ($sinfo->{site} eq $sname) {
            return $sinfo;
        }

        # www.xxx.com eq xxx.com
        if ($sname =~ m/(.*?)\.(.*)/) {
            if (($1 eq "www") and ($2 eq $sinfo->{site})) {
                return $sinfo;
            }
        }
        elsif ($sinfo->{site} =~ m/(.*?)\.(.*)/) {
            if (($1 eq "www") and ($2 eq $sname)) {
                return $sinfo;
            }
        }
    }

    return;
}

sub add_site_to_array
{
    my $sinfo = shift; 
    push(@site_array, $sinfo);
}

sub dump_site_array
{
    my $sinfo;
    my $cnt = 1;
    open(FILEHANDLE, ">cache_hit.log") or die "Can not open file";

    print FILEHANDLE "index\tsite\t" .
        "cache_hit\tcache_miss\tcache_hit_size\tcache_miss_size\tcache_cnt\tcache_size\t" .
        "other_cnt\tother_size\ttotal_cnt\ttotal_size\t" .
        "gif_cnt\tgif_size\tjpg_cnt\tjpg_size\tpng_cnt\tpng_size\tbmp_cnt\tbmp_size\t" . 
        "swf_cnt\tswf_size\tjs_cnt\tjs_size\tcss_cnt\tcss_size\thtml_cnt\thtml_size\t" .
        "unknown_cnt\tunknown_size\t" .
        "mpage_cnt\tmpage_size\tdir_cnt\tdir_size\tdyn_cnt\tdyn_size\tuufo_cnt\tuufo_size\n";

    for my $index (0..$#site_array) {
        $sinfo = $site_array[$index];
        print FILEHANDLE "$cnt\t$$sinfo{site}\t" .
            "$$sinfo{cache_hit}\t$$sinfo{cache_miss}\t" . 
            "$$sinfo{cache_hit_size}\t$$sinfo{cache_miss_size}\t" . 
            "$$sinfo{cache_cnt}\t$$sinfo{cache_size}\t" . 
            "$$sinfo{other_cnt}\t$$sinfo{other_size}\t" . 
            "$$sinfo{total_cnt}\t$$sinfo{total_size}\t" .
            "$$sinfo{objinfo}->{gif_cnt}\t$$sinfo{objinfo}->{gif_size}\t" .
            "$$sinfo{objinfo}->{jpg_cnt}\t$$sinfo{objinfo}->{jpg_size}\t" .
            "$$sinfo{objinfo}->{png_cnt}\t$$sinfo{objinfo}->{png_size}\t" .
            "$$sinfo{objinfo}->{bmp_cnt}\t$$sinfo{objinfo}->{bmp_size}\t" .
            "$$sinfo{objinfo}->{swf_cnt}\t$$sinfo{objinfo}->{swf_size}\t" .
            "$$sinfo{objinfo}->{js_cnt}\t$$sinfo{objinfo}->{js_size}\t" .
            "$$sinfo{objinfo}->{css_cnt}\t$$sinfo{objinfo}->{css_size}\t" .
            "$$sinfo{objinfo}->{html_cnt}\t$$sinfo{objinfo}->{html_size}\t" .
            "$$sinfo{objinfo}->{ufo_cnt}\t$$sinfo{objinfo}->{ufo_size}\t" .
            "$$sinfo{ufoinfo}->{mpage_cnt}\t$$sinfo{ufoinfo}->{mpage_size}\t" .
            "$$sinfo{ufoinfo}->{dir_cnt}\t$$sinfo{ufoinfo}->{dir_size}\t" .
            "$$sinfo{ufoinfo}->{dyn_cnt}\t$$sinfo{ufoinfo}->{dyn_size}\t" .
            "$$sinfo{ufoinfo}->{uufo_cnt}\t$$sinfo{ufoinfo}->{uufo_size}\n";
        $cnt += 1;
    }
    close(FILEHANDLE);
}

sub get_cached_obj_name
{
    my $url = shift;
    my $sufix = substr($url, rindex($url, ".") + 1, length($url));

    if ($sufix =~ m/gif/i) {
        return "gif";
    }
    if (($sufix =~ m/jpg/i) or ($sufix =~ m/jpeg/i)) {
        return "jpg";
    }
    if ($sufix =~ m/png/i) {
        return "png";
    }
    if ($sufix =~ m/bmp/i) {
        return "bmp";
    }
    if ($sufix =~ m/swf/i) {
        return "swf";
    }
    if ($sufix =~ m/js/i) {
        return "js";
    }
    if ($sufix =~ m/css/i) {
        return "css";
    }
    if (($sufix =~ m/html/i) or ($sufix =~ m/htm/i)) {
        return "html";
    }
    return "ufo";
}

sub get_ufo_obj_name
{
    my $url = shift;

    # is mainpage ?
    if ($url =~ m/^\/$/) {
        return "mpage";
    }

    # is directory ?
    if ($url =~ m/(.{1})\z/) {
        if ($1 eq "/") {
            my $slashcnt = ($url =~ tr/\//\//);
            if ($slashcnt >= 2) {
                return "dir";
            }
        }
    }

    # is dynamic page ?
    if ($url =~ m/.*\.(.*)/) {
        my $sufix = $1;
        if (($sufix =~ m/asp/i) or 
            ($sufix =~ m/aspx/i) or
            ($sufix =~ m/php/i) or
            ($sufix =~ m/do/i))
        {
            return "dyn";
        }
    } 
    # no sufix look as dynamic page
    else {
        return "dyn";
    }

    # print ufo url
    #print("$url\n");
    return "uufo";
}

# id, url, count, size, misscount, hitcount, misssize, hitsize, 200count
# 0   1    2      3     4          5         6         7        8
sub update_site_summary
{
    my $sname = shift;
    my $sid = shift;
    my $objname;
    my $objcnt;
    my $objsize;
    my @site_res_array = ();

    my $sinfo = get_site_in_array($sname);
    if (!defined($sinfo)) {
        return;
    }

    my $sql = sprintf("select id, url, count, size, misscount, hitcount, misssize, hitsize, 200count from url where siteid=%s", $sid);
    my $sth = $dbh->prepare($sql);
    $sth->execute() or do_log("SQL err: " . $sth->errstr);
    while (my @recs = $sth->fetchrow_array) {
        #print "$recs[0] $recs[1] $recs[2] $recs[3] $recs[4] $recs[5] $recs[6] $recs[7]\n";

        $objname = get_cached_obj_name($recs[1]);
        $objcnt = sprintf("%s_cnt", $objname);
        $objsize = sprintf("%s_size", $objname);
        if (($objname eq "gif") or
            ($objname eq "jpg") or
            ($objname eq "png") or
            ($objname eq "bmp") or
            ($objname eq "swf") or
            ($objname eq "js") or
            ($objname eq "css"))
        {
            $sinfo->{cache_hit} += $recs[5];
            $sinfo->{cache_miss} += $recs[4];
            $sinfo->{cache_cnt} += $recs[4] + $recs[5];
            $sinfo->{cache_hit_size} += $recs[7];
            $sinfo->{cache_miss_size} += $recs[6];
            $sinfo->{cache_size} += $recs[6] + $recs[7];
            $sinfo->{total_cnt} += $recs[4] + $recs[5];
            $sinfo->{total_size} += $recs[6] + $recs[7];
            $sinfo->{objinfo}->{$objcnt} += $recs[4] + $recs[5];
            $sinfo->{objinfo}->{$objsize} += $recs[6] + $recs[7];
        } else {
            $sinfo->{other_cnt} += $recs[2];
            $sinfo->{other_size} += $recs[3];
            $sinfo->{total_cnt} += $recs[2];
            $sinfo->{total_size} += $recs[3];
            $sinfo->{objinfo}->{$objcnt} += $recs[2];
            $sinfo->{objinfo}->{$objsize} += $recs[3];

            if ($objname eq "ufo") {
                $objname = get_ufo_obj_name($recs[1]);
                $objcnt = sprintf("%s_cnt", $objname);
                $objsize = sprintf("%s_size", $objname);
                $sinfo->{ufoinfo}->{$objcnt} += $recs[2];
                $sinfo->{ufoinfo}->{$objsize} += $recs[3];

                if (($objname eq "uufo") and !($recs[8] eq "0")) {
                    uufo_statistic($recs[1], $recs[2], $recs[3], \@site_res_array);
                }
            }
        }
    }

    for my $i (0..$#site_res_array) {
        for my $j (0..$#uufo_stat_array) {
            if (($uufo_stat_array[$j]->{sufix} eq $site_res_array[$i]) or ($uufo_stat_array[$j]->{sufix} =~ m/$site_res_array[$i]/i)) {
                $uufo_stat_array[$j]->{site} += 1;
            }
        }
    }
    $#site_res_array = -1;

    $sth->finish();
    
    #print Dumper $sinfo;
}


sub uufo_find_node
{
    my $sufix = shift;
    my $stat_node;

    for my $i (0..$#uufo_stat_array) {
        $stat_node = $uufo_stat_array[$i];
        if ($stat_node->{sufix} =~ m/$sufix/i) {
            return $stat_node;
        }
    }

    my %statinfo = ();
    $statinfo{sufix} = $sufix;
    $statinfo{cnt} = 0;
    $statinfo{size} = 0;
    $statinfo{site} = 0;
    $stat_node = \%statinfo;
    push(@uufo_stat_array, $stat_node);
    return $stat_node;
}

sub uufo_statistic
{
    my ($url, $cnt, $size, $res_array) = @_;
    my $sufix;

    #print("URL: $url $cnt $size\n");

    my @arr = split(/\./, $url);
    if ($#arr != 1) {
        return;
    }

    if ($url =~ m/.*\.(.*)/) {
        $sufix = $1;
    } else {
        return;
    }

    if ((length($sufix) > 7) or 
        (length($sufix) == 0) or
        !($sufix =~ m/^\w+$/)) 
    {
        #$url =~ s/%/#/;
        #printf(BADURLFILE "$url\n");
        return;
    }

    my $stat_node = uufo_find_node($sufix);
    if (defined($stat_node)) {
        $stat_node->{cnt} += $cnt;
        $stat_node->{size} += $size;
    } else {
        return;
    }
    
    # record site url type
    my $findit = 0;
    LOOP: for my $i (0..$#res_array) {
        if ($sufix =~ m/$res_array[$i]/i) {
            $findit = 1;
            last LOOP;
        }
    }

    if (!$findit) {
        push($res_array, $sufix);
    }
}

sub uufo_dump
{
    for my $i (0..$#uufo_stat_array) {
        my $stat_node = $uufo_stat_array[$i];
        printf(Dumper $stat_node);
    }
}

sub uufo_dump_file
{
    open(FILEHANDLE, ">uufo_res.log");
    printf(FILEHANDLE "sufix\tcnt\tsize\tsite\n");

    for my $i (0..$#uufo_stat_array) {
        my $stat_node = $uufo_stat_array[$i];
        printf(FILEHANDLE ".$stat_node->{sufix}\t" .
                           "$stat_node->{cnt}\t" .
                           "$stat_node->{size}\t" .
                           "$stat_node->{site}\n");
    }

    close(FILEHANDLE);
}

# load config
load_config();

open(BADURLFILE, ">bad_url.log");

# database connect
$dbh = DBI->connect("$driver:database=$dbname;host=$dbhost;user=$dbuser;password=$dbpass;port=$dbport") or do_log("ConnDB err: " . DBI->errstr);

    my $sql = "select id, sitename, count, size from site";
    my $sth = $dbh->prepare($sql);
    my $cnt = 1;

    $sth->execute() or do_log("SQL err: " . $sth->errstr);
    while (my @recs = $sth->fetchrow_array) {
        print "$cnt => $recs[0] $recs[1] $recs[2] $recs[3]\n";
        $cnt += 1;

        if (!defined(get_site_in_array($recs[1]))) {
            my $sinfo = init_site($recs[1]);
            add_site_to_array($sinfo);
        }

        update_site_summary($recs[1], $recs[0]);
    }
    
    $sth->finish();

    dump_site_array();

    uufo_dump_file();

# database disconnect
$dbh->disconnect();

close(BADURLFILE);

1;

