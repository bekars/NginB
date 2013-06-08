#!/usr/bin/perl -w

package Speedy::ClientPos;
require Exporter;
use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);

use strict;
use Speedy::Speedy;
use BMD::IPOS;
use DBI;
use autodie;
use Try::Tiny;
use Data::Dumper;

@ISA = qw(Speedy::Speedy);

#
# site broswer position
#
my $_site_h = {};
my $_allip_h = {};
my $_allpos_h = {};

sub new()
{
    my $self = Speedy::Speedy->new();
    bless($self);
    return $self;
}

sub analysis($)
{
    my $self = shift;

    my $node_h = shift;
    if (!defined($node_h)) {
        return;
    }

    my $ipseg = _get_ipseg($node_h->{remote_ip});
    $_site_h->{$node_h->{domain}}{ipseg}{$ipseg}{cnt} += 1;

    return 1;
}

sub _private()
{
}

sub init()
{
    my $self = shift;
    my $ipos = BMD::IPOS->new();
    $ipos->load2("/opt/");
    $self->{ipos} = $ipos;
}

sub fini()
{
    my $self = shift;
    my $total = 0;

    # calculate rate for all ip in sites
    foreach my $k1 (keys %$_site_h) {
        $total = 0;
        my $ipseg_h = $_site_h->{$k1}{ipseg};
        
        foreach my $k2 (keys %$ipseg_h) {
            $total += $ipseg_h->{$k2}{cnt};
        }
 
        foreach my $k3 (keys %$ipseg_h) {
            $ipseg_h->{$k3}{rate} = _round(($ipseg_h->{$k3}{cnt} * 100 / $total), 2);
            $_allip_h->{$k3} += $ipseg_h->{$k3}{cnt};
        }
    }

    # ip => pos
    my $ip_cnt = keys %$_allip_h;
    my $n = 0;
    foreach my $k1 (sort keys %$_allip_h) {
        my ($country, $province, $isp) = $self->{ipos}->query2($k1);

        $n += 1;
        printf("$n/$ip_cnt $country, $province, $isp\n");

        $_allpos_h->{"${province}_${isp}"} += $_allip_h->{$k1};
    
        foreach my $k2 (keys %$_site_h) {
            if (exists($_site_h->{$k2}{ipseg}{$k1})) {
                $_site_h->{$k2}{pos}{"${province}_${isp}"}{cnt} += $_site_h->{$k2}{ipseg}{$k1}{cnt};
                $_site_h->{$k2}{pos}{"${province}_${isp}"}{rate} += $_site_h->{$k2}{ipseg}{$k1}{rate};
            }
        }
    }
    
    # calculate all region rate
    $total = 0;
    foreach my $k (keys %$_allpos_h) {
        $total += $_allpos_h->{$k}
    }

    foreach my $k (keys %$_allpos_h) {
        $_allpos_h->{$k} = _round(($_allpos_h->{$k} * 100 / $total), 2);
    }

    # logit 
    open(my $fp, ">site_cli_pos.txt");
    printf($fp "\t");
    foreach my $k (sort {$_allpos_h->{$b}<=>$_allpos_h->{$a}} keys %$_allpos_h) {
        printf($fp "${k} ($_allpos_h->{$k}%%)\t");
    }
    printf($fp "\n");

    foreach my $k1 (keys %$_site_h) {
        printf($fp "$k1\t"); 
        foreach my $k2 (sort {$_allpos_h->{$b}<=>$_allpos_h->{$a}} keys %$_allpos_h) {
            if (exists($_site_h->{$k1}{pos}{$k2})) {
                my $rate = _round($_site_h->{$k1}{pos}{$k2}{rate}, 2);
                printf($fp "$rate\t");
            } else {
                printf($fp "0\t");
            }
        }
        printf($fp "\n");
    }

    close($fp);
    return 1;
}

sub destroy()
{
    my $self = shift;
    $self->{ipos}->destroy();
    #printf(Dumper($_site_h));
    #printf(Dumper($_allip_h));
}

sub debug($)
{
    my $self = shift;
    my $str = shift;

    printf("CliPos: $self->{basedir} $str\n");
}

1;

# vim: ts=4:sw=4:et

