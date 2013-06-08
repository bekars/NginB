#!/usr/bin/perl -w
use strict;
use BMD::IPOS;
use Data::Dumper;
    
my $ipos_hld = BMD::IPOS->new();

my $dbh = BMD::DBH->new(
    'dbhost' => '127.0.0.1',
    'dbuser' => 'bmd',
    'dbpass' => 'didi',
    'dbname' => 'bmd',
    'dbport' => 3306
);

$dbh->execute("set names utf8");

#my $ipos = $ipos_hld->query_taobao("202.106.0.0");
#printf(Dumper($ipos));
#exit(0);

for (my $i1 = 1; $i1 < 100; ++$i1) {
    for (my $i2 = 0; $i2 <= 255; ++$i2) {
        for (my $i3 = 0; $i3 <= 255; ++$i3) {
            my $ipos = $ipos_hld->query_taobao("$i1.$i2.$i3.0");
            $ipos->{cnt} = ($i1 - 1) * 256 * 256 + $i2 * 256 + $i3 + 1;
            printf(Dumper($ipos));
            $dbh->insert("ip", $ipos);
        }
    }
}

$dbh->fini();

1;

