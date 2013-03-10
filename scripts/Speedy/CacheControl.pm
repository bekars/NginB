###################################################
## Speedy::CacheControl
##
## CacheControl statistic
###################################################


## Global Stuff ###################################
package	Speedy::CacheControl;
use strict;
use IO::Handle;
require	Exporter;

use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw();
@EXPORT_OK	= qw(&cachecontrol_analysis_mod &cachecontrol_analysis_init);
$VERSION	= '1.0.0';

## statistic intervals ############################
my $log_result = "%s/cache_ctrl_%s.result";
my $cc_maxage_reg = qr/.*max-age=(.*?)(|,.*|\s.*)$/;
my $cc_nocache_reg = qr/.*public.*/;
my $start = 1;

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
    if ($start) {
        open(CC_FILE, ">$log_result") or return;
        CC_FILE->autoflush(1);
        $start = 0;
    }

    $line =~ tr/%/#/;
    printf(CC_FILE $line);
}

sub cachecontrol_analysis_init($)
{
    my $mod_h = shift;
    if (!defined($mod_h)) {
        return;
    }

    $log_result = sprintf($log_result, $mod_h->{dir}, $mod_h->{date});
}

BEGIN
{
}

END
{
    close(CC_FILE);
}

1;

