#!/usr/bin/perl -w

use strict;
use 5.010;

use Data::Dumper;

# handle param
if( @ARGV < 3 ){
	print <<HELP;
usage:
	xxx.pl keyword date1-start date1-end
		keyword is the column of table speed_monitor_data
		date must be the format : 2012-10-01 2012-10-02
		the result is > 2012-10-01 00:00:00 and < 2012-10-02 00:00:00
HELP
	exit 0;
}

my $keyword = shift;

foreach ( @ARGV ){
	die "wrong date time" unless m/^\d{4}-\d{2}-\d{2}$/ ;
}

# main
my ($time_start, $time_end) = @ARGV;

my $detail_hash = {};
#my $filter_hash = do './filter.txt';
#my $mysql_comm = 'mysql -h116.213.78.228 -ucesureadonly -p66ecf9c968132321a02e6e7aff34ce5d -P3306 -Dspeed -B -N -e ';
my $mysql_comm = 'mysql -h59.151.123.74 -ucesu_readonly -p\'Speed@)!@readonly\' -P3307 -Dspeed -B -N -e ';
my $sql;

#print Dumper($filter_hash);

# aqb
$sql = qq/select role_id, role_name, round(avg($keyword),4) as a from speed_monitor_data where role_name like "%_aqb" and monitor_time > "$time_start" and monitor_time < "$time_end" and total_time != 0 and error_id=0 group by role_id having count(*) > 5 order by a/;
filter($sql, 1, $mysql_comm);

# ip
$sql = qq/select role_id, role_name, round(avg($keyword),4) as a from speed_monitor_data where role_name like "%_ip" and monitor_time > "$time_start" and monitor_time < "$time_end" and total_time != 0 and error_id=0 group by role_id having count(*) > 5 order by a/;
filter($sql, 0, $mysql_comm);

# dns
$sql = qq/select role_id, role_name, round(avg(dns_time),4) as a from speed_monitor_data where role_name like "%_aqb" and monitor_time > "$time_start" and monitor_time < "$time_end" and total_time != 0 and error_id=0 group by role_id having count(*) > 5 order by a/;
filter($sql, 2, $mysql_comm);


# debug
print Dumper($detail_hash);

# begin to statistic
final_st();

sub filter
{
	my ($sql_str, $via_aqb, $mysql_comm) = @_;
	my $detail_ref = [];

	my $cmd = "$mysql_comm '$sql_str'";
	say $cmd;

	my $result      = `$mysql_comm '$sql_str'`;
	@$detail_ref = split /\n/, $result;

	# remove the top 10 and bottom 10
    #pop @$detail_ref foreach 1 .. 10;
    #unshift @$detail_ref foreach 1 .. 10;

	foreach ( @$detail_ref ){
		my @items = split;
		my $site  = strip_($items[1]);

		$detail_hash->{$site}{$via_aqb}{'speed'} = $items[2];
	}
}

sub final_st
{
	my $fast_value = 0;
	my $slow_value = 0;
	my $total_fast_value = 0;
	my $total_slow_value = 0;

	my $total_value = 0;
	my $total_st_value = 0;
	my $st = {};
	my $cnt_hash = {};

	open my $result_file, '>', "./speed_result.$time_start~$time_end.txt"
		or die "can't open file : $!";

	my @sorted_sites = sort { $a cmp $b } keys %$detail_hash;
	foreach my $site (@sorted_sites){
		if( 
			exists $detail_hash->{$site}{0} &&
			exists $detail_hash->{$site}{1} &&
			exists $detail_hash->{$site}{2}
		){
			#say "$site $filter_hash->{$site}";
			#if( $detail_hash->{$site}{0}{'speed'} == 0 || $filter_hash->{$site} == 0 ){
			#	next;
			#}
			#say "doing $site";

			next if $detail_hash->{$site}{0}{'speed'} == 0;

            my $org = $detail_hash->{$site}{0}{'speed'} + $detail_hash->{$site}{2}{'speed'};
            my $aqb = $detail_hash->{$site}{1}{'speed'};

			my $divby = ($org > $aqb) ? $aqb : $org;
			my $rate = ($org - $aqb) * 100 / $divby;

			# skip abnormal data
            #if( abs($tmp_value) > 100 ){ next; }

			$st->{'total_org_value'} += $org;
			$st->{'total_aqb_value'} += $aqb;

			if ( $rate > 0 ) {
				$cnt_hash->{'above'}++;
                #$st->{'fast_value'} += $tmp;
                #$st->{'total_fast_value'} += $tmp_ip_time;
			} else {
				$cnt_hash->{'below'}++;
                #$st->{'slow_value'} += $tmp;
                #$st->{'total_slow_value'} += $tmp_ip_time;
			}

			printf $result_file "%-20s  %.2f\n", $site, $rate;
		}
	}

	close $result_file;

    #eval{say "fast  ", $st->{fast_value}  / $st->{total_fast_value};};
    #eval{say "slow  ", $st->{slow_value}  / $st->{total_slow_value};};
    eval{say "total ", ($st->{total_org_value} - $st->{'total_aqb_value'}) * 100 / $st->{total_aqb_value};};

	say "\e[1;31mresult for $keyword\e[0m";
	say "above: $cnt_hash->{'above'}";
	say "below: $cnt_hash->{'below'}";
}

sub strip_
{
	my $name = shift;

	return substr($name, 0, (index $name, "_"));
}

