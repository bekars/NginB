#!/usr/bin/perl -w

use strict;
use warnings;
use Net::SMTP;
use Authen::SASL;
use MIME::Base64;
use Encode;

# mail_user should be your_mail@163.com
sub send_mail
{
    my $to_address  = shift;
    my $mail_user   = 'donotreply@anquanbao.com.cn';
    my $mail_pwd    = 'a45febb10cc82a0dce518b64d742a8f5';
    my $mail_server = 'anquanbao.com.cn';
    my $mail_from   = 'donotreply@anquanbao.com.cn';

    my $from    = "From: $mail_user\n";
    my $to      = "To: JustYou\@unlun.com\n";
    my $subject = "[AQB测速分析] 每日测速监控 2013-05-08\n\n";

    my $message = ""; 
    open(my $fp, "</tmp/analysis_daily.txt");
    while (<$fp>) {
        $message .= $_;
    }
    close($fp);

    my $smtp = Net::SMTP->new($mail_server);

    $smtp->auth($mail_user, $mail_pwd) || die "Auth Error! $!";
    $smtp->mail($mail_from);
    $smtp->to($to_address);

    $smtp->data();             # begin the data
    $smtp->datasend($from);    # set user
    $smtp->datasend($to);    # set user
    $smtp->datasend("Content-Type:text/plain;charset=UTF-8\n");
    $smtp->datasend("Subject:=?UTF-8?B?".encode_base64($subject, '')."?=\n\n");
    $smtp->datasend($message); # set content
    $smtp->dataend();

    $smtp->quit();
}


send_mail('yu.bai@unlun.com');
send_mail('t@unlun.com');
send_mail('chao.chen@unlun.com');
send_mail('yi.chen@unlun.com');
send_mail('li.huang@unlun.com');
send_mail('xl.hao@unlun.com');
send_mail('zhen.cui@unlun.com');
send_mail('ff@unlun.com');

1;


