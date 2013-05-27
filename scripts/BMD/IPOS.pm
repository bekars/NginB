#!/usr/bin/perl -w

package BMD::IPOS;

use strict;
use BMD::DBH;
use autodie;
use Try::Tiny;
use Data::Dumper;

my $dbh;

sub new()
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = {
        @_,
    };

    bless($self, $class);
    return $self;
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

sub load($)
{
    my $self = shift;
    my $ipdb = shift;

    my @rec_a;
    my $recs;
    my $sql;

    if ($ipdb eq "db") {
        $dbh = BMD::DBH->new(
            'dbhost' => '116.213.78.197',
            'dbuser' => 'readonly',
            'dbpass' => 'anQuanba0sp11d',
            'dbname' => 'ip',
            'dbport' => 3306
        );

        $self->{dbh} = $dbh;
        $self->{dbh}->execute("set names utf8");
    }

    printf("### load ip pos\n");
    if ($ipdb eq "db") {
        $sql = qq/select id,ipstart,ipend,countryid,provinceid,ispid from ip/;
        $self->{ip_pos} = $self->{dbh}->query($sql);
    } else {
        open(my $ipfp, "<$ipdb/ip.db") or die("ERR: can not open $ipdb/ip.db!\n");
        while (<$ipfp>) {
            $_ =~ m/^(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\n$/;
            my @rec_data = ($1, $2, $3, $4, $5, $6);
            push(@rec_a, \@rec_data);
        }
        close($ipfp);
        $self->{ip_pos} = \@rec_a;
    }

    printf("### load country\n");
    if ($ipdb eq "db") {
        $sql = qq/select id,country from country/;
        $recs = $self->{dbh}->query($sql);
        for (my $i = 0; $i <= $#$recs; $i++) {
            $self->{country}->{$recs->[$i][ID]} = $recs->[$i][VAL];
        }
    } else {
        open(my $cfp, "<$ipdb/country.db") or die("ERR: can not open $ipdb/country.db!\n");
        while (<$cfp>) {
            $_ =~ m/^(.*?)\t(.*?)\n$/;
            $self->{country}->{$1} = $2;
        }
        close($cfp);
    }

    printf("### load province\n");
    if ($ipdb eq "db") {
        $sql = qq/select id,province from province/;
        $recs = $self->{dbh}->query($sql);
        for (my $i = 0; $i <= $#$recs; $i++) {
            $self->{province}->{$recs->[$i][ID]} = $recs->[$i][VAL];
        }
    } else {
        open(my $pfp, "<$ipdb/province.db") or die("ERR: can not open $ipdb/province.db!\n");
        while (<$pfp>) {
            $_ =~ m/^(.*?)\t(.*?)\n$/;
            $self->{province}->{$1} = $2;
        }
        close($pfp);
    }

    printf("### load isp\n");
    if ($ipdb eq "db") {
        $sql = qq/select id,isp from isp/;
        $recs = $self->{dbh}->query($sql);
        for (my $i = 0; $i <= $#$recs; $i++) {
            $self->{isp}->{$recs->[$i][ID]} = $recs->[$i][VAL];
        }
    } else {
        open(my $ifp, "<$ipdb/isp.db") or die("ERR: can not open $ipdb/isp.db!\n");
        while (<$ifp>) {
            $_ =~ m/^(.*?)\t(.*?)\n$/;
            $self->{isp}->{$1} = $2;
        }
        close($ifp);
    }

    if ($ipdb eq "db") {
        $self->{dbh}->fini();
    }

    return 1;
}

my @ip_cache = ();

# input ip address like 
#   ip: 1.2.3.4
#   ipseg: 1.2.3
sub query($)
{
    my $self = shift;
    my $ip = shift;

    $ip .= '.1' if (2 == ($ip =~ tr/././));

    my $ip_pos = $self->{ip_pos};
    my $country = $self->{country};
    my $province = $self->{province};
    my $isp = $self->{isp};
    
    $ip =~ m/^(\d+?)\.(\d+?)\.(\d+?)\.(\d+?).*/;
    my $ipnum = $1*256*256*256 + $2*256*256 + $3*256 + $4;

    for (my $j = 0; $j <= $#ip_cache; $j++) {
        if ($ip_cache[$j][0] == $ipnum) {
            #printf("### HIT ip cache\n");
            return ($ip_cache[$j][1], $ip_cache[$j][2], $ip_cache[$j][3]);
        }
    }

    if ($#ip_cache > 10000) {
        shift(@ip_cache);
    }

    for (my $i = 0; $i <= $#$ip_pos; $i++) 
    {
        if (($ipnum > $ip_pos->[$i]->[IPSTART]) && ($ipnum < $ip_pos->[$i]->[IPEND])) 
        {
            my $c_data = "UFO";
            my $p_data = "UFO";
            my $i_data = "UFO";

            printf("### $ip $ipnum $ip_pos->[$i]->[COUNTRY] $ip_pos->[$i]->[PROVINCE] $ip_pos->[$i]->[ISP]\n");
            $c_data = $country->{$ip_pos->[$i]->[COUNTRY]} if $ip_pos->[$i]->[COUNTRY];
            $p_data = $province->{$ip_pos->[$i]->[PROVINCE]} if $ip_pos->[$i]->[PROVINCE];
            $i_data = $isp->{$ip_pos->[$i]->[ISP]} if $ip_pos->[$i]->[ISP];
            $i_data = "UFO" if $i_data eq "";

            if (($ipnum >= 1778515968) && ($ipnum <= 1778647039)) {
                $c_data = $country->{2};
                $p_data = $province->{4};
                $i_data = "UFO";
            }

            my @c = ($ipnum, $c_data, $p_data, $i_data);
            push(@ip_cache, \@c);
            return ($c_data, $p_data, $i_data);
        }
    }

    return ("UFO", "UFO", "UFO");
}

sub destory()
{
    my $self = shift;
}

sub get_country_byid($)
{
    my $self = shift;
    my $id = shift;
    return $self->{country}->{$id};
}

sub get_province_byid($)
{
    my $self = shift;
    my $id = shift;
    return $self->{province}->{$id};
}

sub get_isp_byid($)
{
    my $self = shift;
    my $id = shift;
    return $self->{isp}->{$id};
}

sub BEGIN
{
}

sub DESTROY
{
}

1;

# vim: ts=4:sw=4:et

