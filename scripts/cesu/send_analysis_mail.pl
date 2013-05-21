#!/usr/bin/perl -w

use 5.010;
use strict;
use warnings;
use Net::SMTP;
use Authen::SASL;
use MIME::Base64;
use Encode;

my $today = `/bin/date +"%Y-%m-%d"`;

my @mail_addr = (
    'fast@unlun.com',
    'op@unlun.com',
    'ff@unlun.com',
    'jie.ma@unlun.com',
    'bekars@126.com',
);

sub send_mail($)
{
    my $to_addr     = shift;
    my $mail_user   = 'donotreply@anquanbao.com.cn';
    my $mail_pwd    = 'a45febb10cc82a0dce518b64d742a8f5';
    my $mail_server = 'anquanbao.com.cn';
    my $mail_from   = 'donotreply@anquanbao.com.cn';

    my $from    = "From: yu.bai\@unlun.com\n";
    my $to      = "To: $to_addr\n";
    my $subject = "[AQB测速分析] $today 测速监控数据\n\n";

    my $message = ""; 
    open(my $fp, "</tmp/analysis_daily.txt");
    while (<$fp>) {
        $message .= $_;
    }
    close($fp);

    my $smtp = Net::SMTP->new($mail_server);

    $smtp->auth($mail_user, $mail_pwd) || die "Auth Error! $!";
    $smtp->mail($mail_from);
    foreach my $mto (@mail_addr) {
        $smtp->to($mto);
    }

    $smtp->data();
    $smtp->datasend($from);
    $smtp->datasend($to);
    $smtp->datasend("Content-Type:text/plain;charset=UTF-8\n");
    $smtp->datasend("Subject:=?UTF-8?B?".encode_base64($subject, '')."?=\n\n");
    $smtp->datasend($message);
    $smtp->dataend();

    $smtp->quit();
}


my $to_addr = join(', ', @mail_addr);
say "send mail to $to_addr ...";
send_mail($to_addr);


1;

# vim: ts=4:sw=4:et

