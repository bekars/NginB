#!/usr/bin/perl -w

package BMD::IPOS;

use strict;
use utf8;
use autodie;
use Try::Tiny;
use Data::Dumper;
use Encode;
use BMD::DBH;
use BMD::HTTP;
use JSON -support_by_pp;
use Storable;

my $debug = 1;

sub new()
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = {
        'debug' => 0,
        @_,
    };

    bless($self, $class);
    return $self;
}

# input ip address like 
#   ip: 1.2.3.4
#   ipseg: 1.2.3
sub query($)
{
    my $self = shift;
    my $ip = shift;
    my $ipos = undef;

    $ip .= '.0' if (2 == ($ip =~ tr/././));

    printf("### find in hash\n") if $self->{debug};
    if (exists($self->{ip_pos}{$ip})) {
        return $self->{ip_pos}{$ip};
    }

    printf("### find in db\n") if $self->{debug};
    #$ipos = _query_db($ip);
    #return $ipos if $ipos;

    printf("### find in net\n") if $self->{debug};
    $ipos = _query_net($ip);
    return $ipos if $ipos;

    printf("ERR: $ip NOT FOUND !\n");
    return;
}

use constant {
    IP      => 0,
    IPNUM   => 1,
    COUNTRY => 2,
    AREA    => 3,
    REGION  => 4,
    CITY    => 5,
    COUNTY  => 6,
    ISP     => 7,
};

sub _query_db($)
{
    my $ip = shift;
    my $ipos;
    my $sql = qq/select ip,ipnum,country,area,region,city,county,isp from ip where ip="$ip"/;
    
    my $dbh = BMD::DBH->new(
        'dbhost' => '127.0.0.1',
        'dbuser' => 'bmd',
        'dbpass' => 'didi',
        'dbname' => 'bmd',
        'dbport' => 3306
    );
    
    $dbh->execute("set names utf8");
    my $recs = $dbh->query($sql);
    if ($#$recs != -1) {
        $ipos->{ip}      = $recs->[0][IP]; 
        $ipos->{ipnum}   = $recs->[0][IPNUM]; 
        $ipos->{country} = $recs->[0][COUNTRY]; 
        $ipos->{area}    = $recs->[0][AREA]; 
        $ipos->{region}  = $recs->[0][REGION]; 
        $ipos->{city}    = $recs->[0][CITY]; 
        $ipos->{county}  = $recs->[0][COUNTY]; 
        $ipos->{isp}     = $recs->[0][ISP]; 
        return $ipos
    }

    return;
}

sub _query_net($)
{
    my $ip = shift;

    $ip .= '.0' if (2 == ($ip =~ tr/././));
    $ip =~ m/^(\d+?)\.(\d+?)\.(\d+?)\.(\d+?).*/;
    my $ipnum = $1*256*256*256 + $2*256*256 + $3*256 + $4;

    my $http = undef;
    my $query_url = sprintf("http://ip.taobao.com/service/getIpInfo.php?ip=%s", $ip);
    my $http_hld = BMD::HTTP->new();

    LOOP: for (my $i = 0; $i < 10; ++$i) {
        $http = $http_hld->query($query_url);
        last LOOP if ($http);
        sleep(1);
    }

    my $json = from_json($http->{BODY}, {utf8=>1});
    if ($json->{code} != 0) {
        return;
    }

    $json->{data}{ip}      = $ip;
    $json->{data}{ipnum}   = $ipnum;
    $json->{data}{country} = encode("utf8", $json->{data}{country});
    $json->{data}{area}    = encode("utf8", $json->{data}{area});
    $json->{data}{region}  = encode("utf8", $json->{data}{region});
    $json->{data}{city}    = encode("utf8", $json->{data}{city});
    $json->{data}{county}  = encode("utf8", $json->{data}{county});
    $json->{data}{isp}     = encode("utf8", $json->{data}{isp});
    return $json->{data};
}

sub load($)
{
    my $self = shift;
    my $ipdb = shift;
    my $file = "$ipdb/ipseg.hash";

    if (-e "$file") {
        printf("### load ip hash from %s\n", "$file") if $self->{debug};
        $self->{ip_pos} = retrieve("$file");
    } else {
        printf("ERR: $file not exist!\n");
    }
}

sub format($)
{
    my $self = shift;
    my $ipos = shift;
    my $pos_str = "";

    if (!exists($ipos->{isp})) {
        return $ipos->{ip};
    }

    $ipos->{isp} = "NA" if ($ipos->{isp} eq "");

    if ($ipos->{county} ne "") {
        $pos_str = "$ipos->{region}_$ipos->{city}_$ipos->{county}_$ipos->{isp}";
    } else {
        if ($ipos->{city} ne "") {
            $pos_str = "$ipos->{region}_$ipos->{city}_$ipos->{isp}";
        } else {
            if ($ipos->{region} ne "") {
                $pos_str = "$ipos->{region}_$ipos->{isp}";
            } else {
                $pos_str = "$ipos->{country}";
            }
        }
    }

    return $pos_str;
}

sub destroy()
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

sub generate_ip_hash_file($)
{
    my $self = shift;
    my $ipdb = shift;
    my %ipref;
    my $store_file = "$ipdb/ipseg.hash";

    printf("### generate ip hash stored file to %s\n", $store_file) if $self->{debug};
    open(my $ipfp, "<$ipdb/ipseg.db") or die("ERR: can not open $ipdb/ipseg.db!\n");
    while (<$ipfp>) {
        my @arr = ($_ =~ m/^.*\t.*\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\n$/);
        if ($#arr == 13) {
            $ipref{$1}->{ip} = $1;
            $ipref{$1}->{ipnum} = $2;
            $ipref{$1}->{country} = $3;
            $ipref{$1}->{area} = $5;
            $ipref{$1}->{region} = $7;
            $ipref{$1}->{city} = $9;
            $ipref{$1}->{county} = $11;
            $ipref{$1}->{isp} = $13;
            printf("### load ip %s\n", $1);
        } else {
            printf("ERR: line $_ parse error! %d\n", $#arr);
        }
    }
    close($ipfp);

    store(\%ipref, $store_file);
}

sub BEGIN
{
}

sub DESTROY
{
}

=pod
sub load_old($)
{
    my $self = shift;
    my $ipdb = shift;

    my @rec_a;
    my $recs;
    my $sql;

    if ($ipdb eq "DB") {
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

    printf("### load ip pos\n") if $debug;
    if ($ipdb eq "DB") {
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

    printf("### load country\n") if $debug;
    if ($ipdb eq "DB") {
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

    printf("### load province\n") if $debug;
    if ($ipdb eq "DB") {
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

    printf("### load isp\n") if $debug;
    if ($ipdb eq "DB") {
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

    if ($ipdb eq "DB") {
        $self->{dbh}->fini();
    }

    return 1;
}

sub load($)
{
    my $self = shift;
    my $ipdb = shift;

    printf("### load ip pos\n") if $debug;
    open(my $ipfp, "<$ipdb/ipseg.db") or die("ERR: can not open $ipdb/ipseg.db!\n");
    while (<$ipfp>) {
        $_ =~ m/^.*\t.*\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\t(.*?)\n$/;
        $self->{ip_pos}{$1}{ip} = $1;
        $self->{ip_pos}{$1}{ipnum} = $2;
        $self->{ip_pos}{$1}{country} = $3;
        $self->{ip_pos}{$1}{area} = $5;
        $self->{ip_pos}{$1}{region} = $7;
        $self->{ip_pos}{$1}{city} = $9;
        $self->{ip_pos}{$1}{county} = $11;
        $self->{ip_pos}{$1}{isp} = $13;
        printf("### load ip %s\n", $1);
    }
    close($ipfp);
    return 1;
}

=cut

1;

# vim: ts=4:sw=4:et

