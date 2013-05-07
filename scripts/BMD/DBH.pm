#!/usr/bin/perl -w

package BMD::DBH;

use strict;
use DBI;

my $dbh;

sub new()
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = {
        'dbhost' => '127.0.0.1',
        'dbuser' => 'cesu',
        'dbpass' => 'cesu',
        'dbname' => 'speed',
        'dbport' => 3306,
        @_,
    };

    $dbh = DBI->connect("DBI:mysql:database=$self->{dbname};host=$self->{dbhost};user=$self->{dbuser};password=$self->{dbpass};port=$self->{dbport}") 
        or die("ConnDB err: " . DBI->errstr);
    
    $self->{dbh} = $dbh;

    bless($self, $class);
    return $self;
}

sub query($)
{
    my $self = shift;
    my $sql = shift;

    my $data_ref = ();
    my @row;
    if (!defined($sql)) {
        return;
    }

    #printf("RUNSQL: %s\n", $sql);
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute() or printf("SQL err: [$sql]" . "(" . length($sql) .")" . $sth->errstr);
    while (@row = $sth->fetchrow_array) {
        my @recs = @row;
        push(@$data_ref, \@recs);
    }
    $sth->finish();

    return $data_ref;
}

sub _dosql($)
{
    my $sql = shift;
    #printf("RUNSQL: $sql\n");
    $dbh->do($sql) or printf("SQL err: [$sql]" . "(" . length($sql) .")");
}

sub isnumeric($)
{
    my $val = shift;
    if (!$val) {
        return 0;
    }
    ($val ^ $val) eq '0';
}

sub execute($)
{
    my $self = shift;
    my $sql = shift;
    _dosql($sql);
}

sub insert($$)
{
    my $self = shift;
    my ($table, $data) = @_;
    my (@col, @val);

    foreach my $key (sort keys %$data) {
        push(@col, $key);

        if (isnumeric($data->{$key})) {
            push(@val, $data->{$key});
        } else {
            push(@val, "\'$data->{$key}\'");
        }
    }

    my $sql = "insert into $table(" . join(',', @col) . ") values(" . join(',', @val) . ")";
    _dosql($sql);
}

sub fini()
{
    my $self = shift;
    $self->{dbh}->disconnect();
}

1;


