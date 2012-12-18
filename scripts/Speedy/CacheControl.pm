###################################################
## Speedy::CacheControl
##
## CacheControl statistic
###################################################


## Global Stuff ###################################
package	Speedy::CacheControl;
use strict;
require	Exporter;

use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw();
@EXPORT_OK	= qw(&cachecontrol_analysis_mod);
$VERSION	= '1.0.0';

## statistic intervals ############################
my $logfile = "cache_control.result";
my $cc_maxage_reg = qr/.*max-age=(.*?)(|,.*|\s.*)$/;
my $cc_nocache_reg = qr/.*public.*/;

sub cachecontrol_analysis_mod($)
{
    my $node_h = shift;
    if (!defined($node_h)) {
        return;
    }

    if (($node_h->{cache_control} eq "-") || 
        ($node_h->{cache_control} eq ""))
    {
        return;
    }

    if (($node_h->{cache_control} =~ m/$cc_maxage_reg/) &&
        ($node_h->{cache_control} =~ m/$cc_nocache_reg/)) 
    {
        cachecontrol_dump_log("$node_h->{domain}$node_h->{http_url} || $node_h->{cache_control}\n");
    }
}

sub cachecontrol_dump_log
{
    my $line = shift;
    open(CC_FILE, ">>$logfile") or return;
    $line =~ tr/%/#/;
    printf(CC_FILE $line);
    close(CC_FILE);
}

BEGIN
{
    my $logfile = "cache_control.result";
    open(CC_FILE, ">$logfile") or return;
    close(CC_FILE);
}

END
{
}

1;

