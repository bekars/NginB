#!/usr/bin/perl -w

package Speedy::Speedy;
require	Exporter;

use strict;
use Try::Tiny;

use vars qw($VERSION @EXPORT @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw(&_get_ipseg &_round);
$VERSION	= '1.0.0';

sub new()
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = {
        'mod'       => "Speedy",
        'basedir'   => '/tmp',
        'filename'  => 'speedy.log',
        'storefile' => 'speedy.store',
        'debug'     => 0,
        @_,
    };

    # create children class, not father class
    bless($self, $class);
    return $self;
}

sub set_basedir($)
{
    my $self = shift;
    $self->{basedir} = shift;
}

sub set_filename($)
{
    my $self = shift;
    $self->{filename} = shift;
}

sub set_debug_on()
{
    my $self = shift;
    $self->{debug} = 1;
}

sub _get_ipseg($)
{
    my $ip = shift;
    $ip =~ m/(.*)\.\d+/;
    return $1;
}

sub _round
{
    my ($float, $num) = @_;
    $num = 2 if not $num;
    return sprintf("%.${num}f", $float);
}

sub init()
{
    my $self = shift;
}

sub fini()
{
    my $self = shift;
}

sub destory()
{
    my $self = shift;
}

sub log($)
{
    my $self = shift;
    my $str = shift;

    printf("$self->{mod}: $str\n");
}

1;

# vim: ts=4:sw=4:et

