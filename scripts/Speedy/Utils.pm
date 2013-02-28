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
@EXPORT		= qw(&showHash);
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

1;
