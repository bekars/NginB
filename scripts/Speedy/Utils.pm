###################################################
## module include some good utils
###################################################


## Global Stuff ###################################
package	Speedy::Utils;
use		strict;
require	Exporter;

#class global vars ...
use vars qw($VERSION @EXPORT @ISA);
@ISA 		= qw(Exporter);
@EXPORT		= qw(&showHash &removeRN);
$VERSION	= '1.0.0';

BEGIN
{
}

END
{
}

sub showHash
{
    my ($hash, $name) = @_;
    my $key;
    my $key_tmp;

    if (!defined($name)) {
        $name = "HASH";
    }

    printf("my %%$name = (\n");
    foreach $key (sort keys %$hash) {
        $key_tmp = $key;
        $key_tmp =~ tr/%/#/;
        $key_tmp =~ tr/'/*/;
        if ($hash->{$key}) {
            printf("       '$key_tmp' => $hash->{$key},\n");
        } else {
            printf("       '$key_tmp' => NONE,\n");
        }
    }
    printf(");\n");
}

sub removeRN($)
{
    my $str = shift;
    $$str =~ tr/\r//d;
    $$str =~ tr/\n//d;
}


sub getNow()
{
    my ($sec, $min, $hour, $day, $mon, $year, $weekday, $yeardate, $savinglightday) = (localtime(time));

    $sec  = ($sec < 10) ? "0$sec" : $sec;
    $min  = ($min < 10) ? "0$min" : $min;
    $hour = ($hour < 10) ? "0$hour" : $hour;
    $day  = ($day < 10) ? "0$day" : $day;
    $mon  = ($mon < 9) ? "0".($mon+1) : ($mon+1);
    $year += 1900;

    my $today = "$year-$mon-$day $hour:$min:$sec";
    return $today;
}

1;

