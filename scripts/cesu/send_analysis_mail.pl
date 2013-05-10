#!/usr/bin/perl -w

use 5.010;
use strict;
use warnings;
use Net::SMTP;
use Authen::SASL;
use MIME::Base64;
use Encode;

my $today = `date -d "-1 day" +"%Y-%m-%d"`;

my @mail_addr = (
    'yu.bai@unlun.com',
    't@unlun.com',
    'chao.chen@unlun.com',
    'yi.chen@unlun.com',
    'li.huang@unlun.com',
    'xl.hao@unlun.com',
    'zhen.cui@unlun.com',
    'ff@unlun.com',
);

sub send_mail($)
{
    my $to_addr     = shift;
    my $mail_user   = 'donotreply@anquanbao.com.cn';
    my $mail_pwd    = 'a45febb10cc82a0dce518b64d742a8f5';
    my $mail_server = 'anquanbao.com.cn';
    my $mail_from   = 'donotreply@anquanbao.com.cn';

    my $from    = "From: $mail_user\n";
    my $to      = "To: $to_addr\n";
    my $subject = "[AQB测速分析] 每日测速监控 $today\n\n";

    my $message = ""; 
    open(my $fp, "</tmp/analysis_daily.txt");
    while (<$fp>) {
        $message .= $_;
    }
    close($fp);

    my $smtp = Net::SMTP->new($mail_server);

    $smtp->auth($mail_user, $mail_pwd) || die "Auth Error! $!";
    $smtp->mail($mail_from);
    $smtp->to($to_addr);

    $smtp->data();
    $smtp->datasend($from);
    $smtp->datasend($to);
    $smtp->datasend("Content-Type:text/plain;charset=UTF-8\n");
    $smtp->datasend("Subject:=?UTF-8?B?".encode_base64($subject, '')."?=\n\n");
    $smtp->datasend($message);
    $smtp->dataend();

    $smtp->quit();
}


foreach my $m (@mail_addr) {
    say "send mail to $m ...";
    send_mail($m);
}

1;


