#!/usr/bin/perl -w

#
# 统计log信息
#
package Speedy::LogInfo;
require Exporter;
use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);

use strict;
use autodie;
use Try::Tiny;
use Data::Dumper;
use Speedy::Speedy;

@ISA = qw(Speedy::Speedy);

my $_remoteip = undef;

sub new()
{
    my $self = Speedy::Speedy->new(
        mod      => 'LogInfo', 
        basedir  => '/home/apuadmin/baiyu/',
        filename => 'ip_list.txt',
        debug    => 0,
    );
    $self->{remoteip} = $_remoteip;
    bless($self);
    return $self;
}

sub analysis($)
{
    my ($self, $node_h) = @_;
    $_remoteip->{$node_h->{remote_ip}} += 1;
    return 1;
}

sub init()
{
    my $self = shift;
}

sub fini()
{
    my $self = shift;

    open(my $fp, ">$self->{basedir}/$self->{filename}");
    foreach my $k (keys %$_remoteip) {
        printf($fp "$k\n");
    }
    close($fp);

    return 1;
}

sub destroy()
{
    my $self = shift;
}

1;

# vim: ts=4:sw=4:et

