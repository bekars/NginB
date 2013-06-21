#!/usr/bin/perl -w

package BMD::MAIL;

use 5.010;
use strict;
use warnings;
use Net::SMTP;
use Authen::SASL;
use MIME::Base64;
use MIME::Lite;
use Encode;

my @my_email = (
    'bekars@126.com',
#    'bekars@gmail.com',
);

sub new()
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = {
        'email_addr' => \@my_email,
        'debug'      => 0,
        @_,
    };

    bless($self, $class);
    return $self;
}

sub _send_mail($$$$)
{
    my ($title, $content, $attach, $mailto_arr) = @_;
    my $mail_user   = 'bmdw81@163.com';
    my $mail_pwd    = 'bmd0412';
    my $mail_server = 'smtp.163.com';
    my $mail_from   = 'bmdw81@163.com';
    my $mail_to = join(', ', @$mailto_arr);

    my $msg = MIME::Lite->new(
        From    => $mail_from,
        To      => $mail_to,
        Subject => $title,
        Type    => 'TEXT',
        Data    => $content,
    );

    $attach =~ m/.*\/(.*?)$/;
    my $filename = $1;
    $msg->attach(
        Type     => 'AUTO',
        Path     => $attach,
        Filename => $filename,
    );
    
    my $str = $msg->as_string() or die "convert msg to str error: $!\n";

    my $smtp = Net::SMTP->new($mail_server, Timeout=>120, Debug=>0);
    $smtp->auth($mail_user, $mail_pwd) or die "Auth Error! $!";
    $smtp->mail($mail_from);
    foreach my $kto (@$mailto_arr) {
        $smtp->to($kto);
    }

    $smtp->data();
    $smtp->datasend($str);
    $smtp->dataend();

    $smtp->quit();
}

sub send_mail($$$$)
{
    my ($self, $title, $content, $attach, $mailto_arr) = @_;
    if (!$mailto_arr) {
        return _send_mail($title, $content, $attach, \@my_email);
    }
    return _send_mail($title, $content, $attach, $mailto_arr);
}

sub destroy()
{
    my $self = shift;
}

=pod
say "send mail to " . join(', ', @my_email) . "...";
_send_mail("DIDI", "CONTENT", "/tmp/pos_cluster_download.txt", \@my_email);
=cut

1;

# vim: ts=4:sw=4:et

