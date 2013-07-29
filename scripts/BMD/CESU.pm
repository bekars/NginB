#!/usr/bin/perl -w

package	BMD::CESU;
use strict;
use BMD::DBH;
use BMD::AQB;
use Time::Interval;
use Data::Dumper;

my $_dbh = undef;
my ($_dbhost, $_dbuser, $_dbpass, $_dbname, $_dbport) = (
    "127.0.0.1",
    "user",
    "passwd",
    "owdb",
    "3306"
);

sub new()
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = {
        'debug' => 0,
        @_,
    };

    _load_db_conf();
    _conn_db();

    $self->{dbh} = $_dbh;
    bless($self, $class);
    return $self;
}

sub _load_db_conf()
{
    my $conf_file = '/home/apuadmin/baiyu/cesu.conf';
    open(DB_CONFIG, $conf_file) or die("ERR: can't open $conf_file : $!");

    while (<DB_CONFIG>) {
        if (m/^DBHOST=(\S+)/) {
            $_dbhost = $1;	
        }
        elsif (m/^DBUSER=(\S+)/) {
            $_dbuser = $1;	
        }
        elsif (m/^DBPASS=(\S+)/) {
            $_dbpass = $1;
        }
        elsif (m/^DBNAME=(\S+)/) {
            $_dbname = $1;	
        }
        elsif (m/^DBPORT=(\S+)/) {
            $_dbport = $1;	
        }
    }
}

sub _conn_db()
{
    if (!$_dbh) {
        $_dbh = BMD::DBH->new(
            'dbhost' => $_dbhost,
            'dbuser' => $_dbuser,
            'dbpass' => $_dbpass,
            'dbname' => $_dbname,
            'dbport' => $_dbport
        );
        $_dbh->execute("set names utf8") if $_dbh;
    }
}

sub _close_db()
{
    $_dbh->destroy();
    $_dbh = undef;
}

sub _get_now()
{
    my ($sec, $min, $hour, $day, $mon, $year, $weekday, $yeardate, $savinglightday) = (localtime(time));

    $sec  = ($sec < 10) ? "0$sec" : $sec;
    $min  = ($min < 10) ? "0$min" : $min;
    $hour = ($hour < 10) ? "0$hour" : $hour;
    $day  = ($day < 10) ? "0$day" : $day;
    $mon  = ($mon < 9) ? "0".($mon+1) : ($mon+1);
    $year += 1900;

    my $now = "$year-$mon-$day $hour:$min:$sec";
    return $now;
}

sub _get_interval_day($$)
{
    my ($time, $now) = @_;
    my $delta = getInterval(
        $time,
        $now,
        0,
    );
    return $delta->{days};
}

sub get_ddos_site()
{
    my $self = shift;
    my $sql = qq/select site from speed_task where speed_task.task_status=1 order by site/;
    my $site_h = {};
    my $now = _get_now();
    my ($total_site, $ddos_site) = (0, 0);
    my $total_day = 0;

    open(my $fp, ">ddos_site.txt");
    my $recs = $_dbh->query($sql);
    my $aqb_hld = BMD::AQB->new();
    for (my $i = 0; $i <= $#$recs; $i++) {
        ++$total_site;
        my $site = $recs->[$i][0];
        my $site_info = $aqb_hld->get_site_info($site);
        my $schedule_info = $aqb_hld->get_schedule_info($site_info->{id});

        foreach my $kclu (keys %$schedule_info) {
            if (($kclu =~ m/CHN-BJ-YQ-.*/i) || ($kclu =~ m/UNI-WF-GW-.*/i)) {
                my $interval = _get_interval_day($schedule_info->{$kclu}{time}, $now);
                $total_day += $interval;
                if ($interval > 3) {
                    $site_h->{site}{$site} = $interval;
                    ++$ddos_site;
                    printf($fp "$site\n");
                }
            }
        }
    }
    $aqb_hld->destroy();

    $site_h->{total} = $total_site;
    $site_h->{ddos} = $ddos_site;
    $site_h->{avg_day} = $total_day / $site_h->{total};

    close($fp);

    return $site_h;
}


sub destroy()
{
    my $self = shift;
    _close_db() if ($_dbh);
}

1;

# vim: ts=4:sw=4:et

