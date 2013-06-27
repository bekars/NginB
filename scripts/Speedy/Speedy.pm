#!/usr/bin/perl -w

package Speedy::Speedy;
require	Exporter;

use strict;
use Storable;

use vars qw($VERSION @EXPORT @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw(&_get_ipseg &_round &_tostore &_restore);
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

sub init()
{
    my $self = shift;
    $self->log("Speedy init function!\n");
}

sub fini()
{
    my $self = shift;
    $self->log("Speedy fini function!\n");
}

sub destory()
{
    my $self = shift;
    $self->log("Speedy destroy function!\n");
}

sub tofile()
{
    my $self = shift;
    $self->log("Speedy tofile function!\n");
}

sub tostore()
{
    my $self = shift;
    $self->log("Speedy tostore function!\n");
}

sub restore()
{
    my $self = shift;
    $self->log("Speedy restore function!\n");
}

sub send_mail()
{
    my $self = shift;
    $self->log("Speedy send_mail function!\n");
}

sub log($)
{
    my $self = shift;
    my $str = shift;
    printf("$self->{mod}: $str\n") if ($self->{debug});
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

#
# utils
#
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

sub _tostore($$)
{
    my ($data_ref, $file) = @_;
    Storable::store($data_ref, $file);
}

sub _restore($)
{
    my ($file) = @_;
    return unless (-e $file);
    my $data_ref = Storable::retrieve("$file");
    return $data_ref;
}

1;

# vim: ts=4:sw=4:et

