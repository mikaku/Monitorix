#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2021 by Jordi Sanfeliu <jordi@fibranet.cat>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

# For information on PostgreSQL statisitcs check:
# <https://www.postgresql.org/docs/11/monitoring-stats.html>

package pgsql;

use strict;
use warnings;
use Monitorix;
use RRDs;
use DBI;
use Exporter 'import';
our @EXPORT = qw(pgsql_init pgsql_update pgsql_cgi);

sub pgsql_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $pgsql = $config->{pgsql};

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;
	my $n2;

	my @average;
	my @min;
	my @max;
	my @last;

	if(-e $rrd) {
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'ds[') == 0) {
				if(index($key, '.type') != -1) {
					push(@ds, substr($key, 3, index($key, ']') - 3));
				}
			}
			if(index($key, 'rra[') == 0) {
				if(index($key, '.rows') != -1) {
					push(@rra, substr($key, 4, index($key, ']') - 4));
				}
			}
		}
		if(scalar(@ds) / 248 != scalar(my @pl = split(',', $pgsql->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @pl = split(',', $pgsql->{list})) . ") and $rrd (" . scalar(@ds) / 248 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if(scalar(@rra) < 12 + (4 * $config->{max_historic_years})) {
			logger("$myself: Detected size mismatch between 'max_historic_years' (" . $config->{max_historic_years} . ") and $rrd (" . ((scalar(@rra) -12) / 4) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
	}

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
		for($n = 1; $n <= $config->{max_historic_years}; $n++) {
			push(@average, "RRA:AVERAGE:0.5:1440:" . (365 * $n));
			push(@min, "RRA:MIN:0.5:1440:" . (365 * $n));
			push(@max, "RRA:MAX:0.5:1440:" . (365 * $n));
			push(@last, "RRA:LAST:0.5:1440:" . (365 * $n));
		}
		for($n = 0; $n < scalar(my @pl = split(',', $pgsql->{list})); $n++) {
			push(@tmp, "DS:pgsql" . $n . "_uptime:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tsize:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tconns:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tactcon:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tidlcon:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tidxcon:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tixacon:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_trret:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_trfet:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_trins:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_trupd:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_trdel:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_txactcom:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_txactrlb:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tblkrea:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tblkhit:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tbgwchkt:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tbgwchkr:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tbgwbchk:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tbgwbcln:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tbgwmaxc:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tbgwbbac:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_tbgwball:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_val01:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_val02:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_val03:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_val04:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_val05:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_val06:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_val07:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_val08:GAUGE:120:0:U");
			push(@tmp, "DS:pgsql" . $n . "_val09:GAUGE:120:0:U");
			for($n2 = 0; $n2 < 9; $n2++) {
				push(@tmp, "DS:pgsql" . $n . $n2 . "_size:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_conns:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_actcon:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_idlcon:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_idxcon:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_ixacon:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_rret:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_rfet:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_rins:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_rupd:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_rdel:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_xactcom:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_xactrlb:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_blkrea:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_blkhit:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_val01:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_val02:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_val03:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_val04:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_val05:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_val06:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_val07:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_val08:GAUGE:120:0:U");
				push(@tmp, "DS:pgsql" . $n . $n2 . "_val09:GAUGE:120:0:U");
			}
		}
		eval {
			RRDs::create($rrd,
				"--step=60",
				@tmp,
				"RRA:AVERAGE:0.5:1:1440",
				"RRA:AVERAGE:0.5:30:336",
				"RRA:AVERAGE:0.5:60:744",
				@average,
				"RRA:MIN:0.5:1:1440",
				"RRA:MIN:0.5:30:336",
				"RRA:MIN:0.5:60:744",
				@min,
				"RRA:MAX:0.5:1:1440",
				"RRA:MAX:0.5:30:336",
				"RRA:MAX:0.5:60:744",
				@max,
				"RRA:LAST:0.5:1:1440",
				"RRA:LAST:0.5:30:336",
				"RRA:LAST:0.5:60:744",
				@last,
			);
		};
		my $err = RRDs::error;
		if($@ || $err) {
			logger("$@") unless !$@;
			if($err) {
				logger("ERROR: while creating $rrd: $err");
				if($err eq "RRDs::error") {
					logger("... is the RRDtool Perl package installed?");
				}
			}
			return;
		}
	}

	$config->{pgsql_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub pgsql_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $pgsql = $config->{pgsql};

	my $str;
	my $n = 0;
	my $n2 = 0;
	my $rrdata = "N";

	my $print_error = 0;
	$print_error = 1 if $debug;

	for($n = 0; $n < scalar(my @pl = split(',', $pgsql->{list})); $n++) {
		my $pg = trim($pl[$n]);
		my $host = $pgsql->{desc}->{$pg}->{host} || "";
		my $port = $pgsql->{desc}->{$pg}->{port} || "";
		my $user = $pgsql->{desc}->{$pg}->{username} || "";
		my $pass = $pgsql->{desc}->{$pg}->{password} || "";
		my $dbh;
		$dbh = DBI->connect(
			"DBI:Pg:host=$host;port=$port",
			$user,
			$pass,
			{ PrintError => $print_error, }
		) or logger("$myself: Cannot connect to PostgreSQL '$host:$port'.") and next;

		# GLOBAL STATUS
		my $uptime = 0;
		my $tsize = 0;
		my $tconns = 0;
		my $tactcon = 0;
		my $tidlcon = 0;
		my $tidxcon = 0;
		my $tixacon = 0;
		my $trret = 0;
		my $trfet = 0;
		my $trins = 0;
		my $trupd = 0;
		my $trdel = 0;
		my $txactcom = 0;
		my $txactrlb = 0;
		my $tblkrea = 0;
		my $tblkhit = 0;
		my $tbgwchkt = 0;
		my $tbgwchkr = 0;
		my $tbgwbchk = 0;
		my $tbgwbcln = 0;
		my $tbgwmaxc = 0;
		my $tbgwbbac = 0;
		my $tbgwball = 0;

		my $sth;
		my $result;
		my $value;

		$sth = $dbh->prepare("SELECT EXTRACT(epoch from now()-pg_postmaster_start_time())");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$uptime = @{$result}[0];
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(pg_database_size(datid)) AS total_size FROM pg_stat_database");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$tsize = @{$result}[0];
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(numbackends) FROM pg_stat_database");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$tconns = @{$result}[0];
		$sth->finish;

		$sth = $dbh->prepare("SELECT COUNT(1) FROM pg_stat_activity WHERE state = 'active'");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$tactcon = @{$result}[0];
		$sth->finish;

		$sth = $dbh->prepare("SELECT COUNT(1) FROM pg_stat_activity WHERE state = 'idle'");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$tidlcon = @{$result}[0];
		$sth->finish;

		$sth = $dbh->prepare("SELECT COUNT(1) FROM pg_stat_activity WHERE state = 'idle in transaction'");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$tidxcon = @{$result}[0];
		$sth->finish;

		$sth = $dbh->prepare("SELECT COUNT(1) FROM pg_stat_activity WHERE state = 'idle in transaction (aborted)'");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$tixacon = @{$result}[0];
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(tup_returned) FROM pg_stat_database");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "trret";
		$trret = $value - ($config->{pgsql_hist}->{$str} || 0);
		$trret = 0 unless $trret != $value;
		$trret /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(tup_fetched) FROM pg_stat_database");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "trfet";
		$trfet = $value - ($config->{pgsql_hist}->{$str} || 0);
		$trfet = 0 unless $trfet != $value;
		$trfet /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(tup_inserted) FROM pg_stat_database");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "trins";
		$trins = $value - ($config->{pgsql_hist}->{$str} || 0);
		$trins = 0 unless $trins != $value;
		$trins /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(tup_updated) FROM pg_stat_database");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "trupd";
		$trupd = $value - ($config->{pgsql_hist}->{$str} || 0);
		$trupd = 0 unless $trupd != $value;
		$trupd /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(tup_deleted) FROM pg_stat_database");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "trdel";
		$trdel = $value - ($config->{pgsql_hist}->{$str} || 0);
		$trdel = 0 unless $trdel != $value;
		$trdel /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(xact_commit) FROM pg_stat_database");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "txactcom";
		$txactcom = $value - ($config->{pgsql_hist}->{$str} || 0);
		$txactcom = 0 unless $txactcom != $value;
		$txactcom /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(xact_rollback) FROM pg_stat_database");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "txactrlb";
		$txactrlb = $value - ($config->{pgsql_hist}->{$str} || 0);
		$txactrlb = 0 unless $txactrlb != $value;
		$txactrlb /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(blks_read) FROM pg_stat_database");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "tblkrea";
		$tblkrea = $value - ($config->{pgsql_hist}->{$str} || 0);
		$tblkrea = 0 unless $tblkrea != $value;
		$tblkrea /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(blks_hit) FROM pg_stat_database");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "tblkhit";
		$tblkhit = $value - ($config->{pgsql_hist}->{$str} || 0);
		$tblkhit = 0 unless $tblkhit != $value;
		$tblkhit /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(checkpoints_timed) FROM pg_stat_bgwriter");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "tbgwchkt";
		$tbgwchkt = $value - ($config->{pgsql_hist}->{$str} || 0);
		$tbgwchkt = 0 unless $tbgwchkt != $value;
		$tbgwchkt /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(checkpoints_req) FROM pg_stat_bgwriter");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "tbgwchkr";
		$tbgwchkr = $value - ($config->{pgsql_hist}->{$str} || 0);
		$tbgwchkr = 0 unless $tbgwchkr != $value;
		$tbgwchkr /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(buffers_checkpoint) FROM pg_stat_bgwriter");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "tbgwbchk";
		$tbgwbchk = $value - ($config->{pgsql_hist}->{$str} || 0);
		$tbgwbchk = 0 unless $tbgwbchk != $value;
		$tbgwbchk /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(buffers_clean) FROM pg_stat_bgwriter");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "tbgwbcln";
		$tbgwbcln = $value - ($config->{pgsql_hist}->{$str} || 0);
		$tbgwbcln = 0 unless $tbgwbcln != $value;
		$tbgwbcln /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(maxwritten_clean) FROM pg_stat_bgwriter");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "tbgwmaxc";
		$tbgwmaxc = $value - ($config->{pgsql_hist}->{$str} || 0);
		$tbgwmaxc = 0 unless $tbgwmaxc != $value;
		$tbgwmaxc /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(buffers_backend) FROM pg_stat_bgwriter");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "tbgwbbac";
		$tbgwbbac = $value - ($config->{pgsql_hist}->{$str} || 0);
		$tbgwbbac = 0 unless $tbgwbbac != $value;
		$tbgwbbac /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$sth = $dbh->prepare("SELECT SUM(buffers_alloc) FROM pg_stat_bgwriter");
		$sth->execute;
		$result = $sth->fetchrow_arrayref();
		$value = @{$result}[0];
		$str = $n . "tbgwball";
		$tbgwball = $value - ($config->{pgsql_hist}->{$str} || 0);
		$tbgwball = 0 unless $tbgwball != $value;
		$tbgwball /= 60;
		$config->{pgsql_hist}->{$str} = $value;
		$sth->finish;

		$rrdata .= ":$uptime:$tsize:$tconns:$tactcon:$tidlcon:$tidxcon:$tixacon:$trret:$trfet:$trins:$trupd:$trdel:$txactcom:$txactrlb:$tblkrea:$tblkhit:$tbgwchkt:$tbgwchkr:$tbgwbchk:$tbgwbcln:$tbgwmaxc:$tbgwbbac:$tbgwball:0:0:0:0:0:0:0:0:0";

		# DATABASE-RELATED VALUES
		my @dbl = split(',', $pgsql->{desc}->{$pg}->{db_list});
		for($n2 = 0; $n2 < 9; $n2++) {
			my $db = trim($dbl[$n2]);
			my $size = 0;
			my $conns = 0;
			my $actcon = 0;
			my $idlcon = 0;
			my $idxcon = 0;
			my $ixacon = 0;
			my $rret = 0;
			my $rfet = 0;
			my $rins = 0;
			my $rupd = 0;
			my $rdel = 0;
			my $xactcom = 0;
			my $xactrlb = 0;
			my $blkrea = 0;
			my $blkhit = 0;

			# check if the database exists
			if($db) {
				$sth = $dbh->prepare("SELECT 1 FROM pg_database WHERE datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				my $exist = @{$result}[0];
				$sth->finish;
				if(!$exist) {
					logger("ERROR: database '$db' does not exist!");
					$db = "";
				}
			}

			if($db) {
				$sth = $dbh->prepare("SELECT pg_database_size('$db')");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$size = @{$result}[0];
				$sth->finish;

				$sth = $dbh->prepare("SELECT numbackends FROM pg_stat_database WHERE datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$conns = @{$result}[0];
				$sth->finish;

				$sth = $dbh->prepare("SELECT COUNT(1) FROM pg_stat_activity WHERE state = 'active' AND datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$actcon = @{$result}[0];
				$sth->finish;

				$sth = $dbh->prepare("SELECT COUNT(1) FROM pg_stat_activity WHERE state = 'idle' AND datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$idlcon = @{$result}[0];
				$sth->finish;

				$sth = $dbh->prepare("SELECT COUNT(1) FROM pg_stat_activity WHERE state = 'idle in transaction' AND datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$idxcon = @{$result}[0];
				$sth->finish;

				$sth = $dbh->prepare("SELECT COUNT(1) FROM pg_stat_activity WHERE state = 'idle in transaction (aborted)' AND datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$ixacon = @{$result}[0];
				$sth->finish;

				$sth = $dbh->prepare("SELECT tup_returned FROM pg_stat_database WHERE datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$value = @{$result}[0];
				$str = $n . "_" . $n2 . "rret";
				$rret = $value - ($config->{pgsql_hist}->{$str} || 0);
				$rret = 0 unless $rret != $value;
				$rret /= 60;
				$config->{pgsql_hist}->{$str} = $value;
				$sth->finish;

				$sth = $dbh->prepare("SELECT tup_fetched FROM pg_stat_database WHERE datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$value = @{$result}[0];
				$str = $n . "_" . $n2 . "rfet";
				$rfet = $value - ($config->{pgsql_hist}->{$str} || 0);
				$rfet = 0 unless $rfet != $value;
				$rfet /= 60;
				$config->{pgsql_hist}->{$str} = $value;
				$sth->finish;

				$sth = $dbh->prepare("SELECT tup_inserted FROM pg_stat_database WHERE datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$value = @{$result}[0];
				$str = $n . "_" . -$n2 . "rins";
				$rins = $value - ($config->{pgsql_hist}->{$str} || 0);
				$rins = 0 unless $rins != $value;
				$rins /= 60;
				$config->{pgsql_hist}->{$str} = $value;
				$sth->finish;

				$sth = $dbh->prepare("SELECT tup_updated FROM pg_stat_database WHERE datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$value = @{$result}[0];
				$str = $n . "_" . $n2 . "rupd";
				$rupd = $value - ($config->{pgsql_hist}->{$str} || 0);
				$rupd = 0 unless $rupd != $value;
				$rupd /= 60;
				$config->{pgsql_hist}->{$str} = $value;
				$sth->finish;

				$sth = $dbh->prepare("SELECT tup_deleted FROM pg_stat_database WHERE datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$value = @{$result}[0];
				$str = $n . "_" . $n2 . "rdel";
				$rdel = $value - ($config->{pgsql_hist}->{$str} || 0);
				$rdel = 0 unless $rdel != $value;
				$rdel /= 60;
				$config->{pgsql_hist}->{$str} = $value;
				$sth->finish;

				$sth = $dbh->prepare("SELECT xact_commit FROM pg_stat_database WHERE datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$value = @{$result}[0];
				$str = $n . "_" . $n2 . "xactcom";
				$xactcom = $value - ($config->{pgsql_hist}->{$str} || 0);
				$xactcom = 0 unless $xactcom != $value;
				$xactcom /= 60;
				$config->{pgsql_hist}->{$str} = $value;
				$sth->finish;

				$sth = $dbh->prepare("SELECT xact_rollback FROM pg_stat_database WHERE datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$value = @{$result}[0];
				$str = $n . "_" . $n2 . "xactrlb";
				$xactrlb = $value - ($config->{pgsql_hist}->{$str} || 0);
				$xactrlb = 0 unless $xactrlb != $value;
				$xactrlb /= 60;
				$config->{pgsql_hist}->{$str} = $value;
				$sth->finish;

				$sth = $dbh->prepare("SELECT blks_read FROM pg_stat_database WHERE datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$value = @{$result}[0];
				$str = $n . "_" . $n2 . "blkrea";
				$blkrea = $value - ($config->{pgsql_hist}->{$str} || 0);
				$blkrea = 0 unless $blkrea != $value;
				$blkrea /= 60;
				$config->{pgsql_hist}->{$str} = $value;
				$sth->finish;

				$sth = $dbh->prepare("SELECT blks_hit FROM pg_stat_database WHERE datname = '$db'");
				$sth->execute;
				$result = $sth->fetchrow_arrayref();
				$value = @{$result}[0];
				$str = $n . "_" . $n2 . "blkhit";
				$blkhit = $value - ($config->{pgsql_hist}->{$str} || 0);
				$blkhit = 0 unless $blkhit != $value;
				$blkhit /= 60;
				$config->{pgsql_hist}->{$str} = $value;
				$sth->finish;
			}
			$rrdata .= ":$size:$conns:$actcon:$idlcon:$idxcon:$ixacon:$rret:$rfet:$rins:$rupd:$rdel:$xactcom:$xactrlb:$blkrea:$blkhit:0:0:0:0:0:0:0:0:0";
		}
		$dbh->disconnect;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub pgsql_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $pgsql = $config->{pgsql};
	my @rigid = split(',', ($pgsql->{rigid} || ""));
	my @limit = split(',', ($pgsql->{limit} || ""));
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};
	my $zoom = "--zoom=" . $config->{global_zoom};
	my %rrd = (
		'new' => \&RRDs::graphv,
		'old' => \&RRDs::graph,
	);
	my $version = "new";
	my $pic;
	my $picz;
	my $picz_width;
	my $picz_height;

	my $u = "";
	my $width;
	my $height;
	my @extra;
	my @riglim;
	my @IMG;
	my @IMGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $e;
	my $e2;
	my $n;
	my $n2;
	my $err;

	$version = "old" if $RRDs::VERSION < 1.3;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $IMG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};
	my $imgfmt_uc = uc($config->{image_format});
	my $imgfmt_lc = lc($config->{image_format});
	foreach my $i (split(',', $config->{rrdtool_extra_options} || "")) {
		push(@extra, trim($i)) if trim($i);
	}

	$title = !$silent ? $title : "";


	# text mode
	#
	if(lc($config->{iface_mode}) eq "text") {
		if($title) {
			push(@output, main::graph_header($title, 2));
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
			"--resolution=$tf->{res}",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"AVERAGE");
		$err = RRDs::error;
		push(@output, "ERROR: while fetching $rrd: $err\n") if $err;
		my $line1;
		my $line2;
		my $line3;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		for($n = 0; $n < scalar(my @pl = split(',', $pgsql->{list})); $n++) {
			my $pg = trim($pl[$n]);
			my $host = $pgsql->{desc}->{$pg}->{host} || "";
			my $port = $pgsql->{desc}->{$pg}->{port} || "";
			$line1 = "                                                                                                                                                                                                                           ";
			$line2 .= "   Uptime  T.Size  T.Conn  T.ActC  T.IdlC  T.IdXC  T.IXAC  T.TuRet  T.TuFet  T.TuIns  T.TuUpd  T.TuDel  T.XactCm  T.XactRB  T.BlkRea  T.BlkHit  T.BgwChkT  T.BgwChkR  T.BgwBChk  T.BgwBCln  T.BgwMaxC  T.BgwBBac  T.BgwBAll";
			$line3 .= "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
			if($line1) {
				my $i = length($line1);
				push(@output, sprintf(sprintf("%${i}s", sprintf("%s:%s", $host, $port))));
			}
		}
		push(@output, "\n");
		push(@output, "Time$line2\n");
		push(@output, "----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc}", $time));
			for($n2 = 0; $n2 < scalar(my @pl = split(',', $pgsql->{list})); $n2++) {
				undef(@row);
				$from = $n2 * 248;
				$to = $from + 248;
				push(@row, @$line[$from..$to]);
				$row[1] = sprintf("%d", ($row[1] || 0) / (1024 * 1024));
				if($row[1] < 1024) {
					$row[1] = sprintf("%6dM", $row[1]);
				} else {
					$row[1] = sprintf("%6dG", $row[1] / 1024);
				}
				push(@output, sprintf("   %6d %s  %6d  %6d  %6d  %6d  %6d  %7d  %7d  %7d  %7d  %7d  %8d  %8d  %8d  %8d  %9d  %9d  %9d  %9d  %9d  %9d  %9d", @row[0..22]));
			}
			push(@output, "\n");
		}
		push(@output, "    </pre>\n");
		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");
			push(@output, main::graph_footer());
		}
		push(@output, "  <br>\n");
		return @output;
	}


	# graph mode
	#
	if($silent eq "yes" || $silent eq "imagetag") {
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "_";
	}
	if($silent eq "imagetagbig") {
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "";
	}

	for($n = 0; $n < scalar(my @pl = split(',', $pgsql->{list})); $n++) {
		for($n2 = 1; $n2 <= 6; $n2++) {
			my $str = $u . $package . $n . $n2 . "." . $tf->{when} . ".$imgfmt_lc";
			push(@IMG, $str);
			unlink("$IMG_DIR" . $str);
			if(lc($config->{enable_zoom}) eq "y") {
				$str = $u . $package . $n . $n2 . "z." . $tf->{when} . ".$imgfmt_lc";
				push(@IMGz, $str);
				unlink("$IMG_DIR" . $str);
			}
		}
		my $n3;
		my $pg = trim($pl[$n]);
		for($n3 = 0; $n3 < scalar(my @dbl = split(',', $pgsql->{desc}->{$pg}->{db_list})); $n3++) {
			my $n4;
			for($n4 = 1; $n4 <= 5; $n4++) {
				my $str = $u . $package . $n . $n2 . "." . $tf->{when} . ".$imgfmt_lc";
				push(@IMG, $str);
				unlink("$IMG_DIR" . $str);
				if(lc($config->{enable_zoom}) eq "y") {
					$str = $u . $package . $n . $n2 . "z." . $tf->{when} . ".$imgfmt_lc";
					push(@IMGz, $str);
					unlink("$IMG_DIR" . $str);
				}
				$n2++;
			}
		}
	}

	$e = 0;
	foreach my $db (my @pl = split(',', $pgsql->{list})) {
		my $pg = trim($db);

		if($e) {
			push(@output, "  <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}

		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
			"--resolution=60",
			"--start=-1min",
			"AVERAGE");
		$err = RRDs::error;
		push(@output, "ERROR: while fetching $rrd: $err\n") if $err;
		my $line = @$data[0];
		my ($uptime) = @$line[0];
		my $uptimeline;
		if($RRDs::VERSION > 1.2) {
			$uptimeline = "COMMENT:uptime\\: " . uptime2str(trim($uptime)) . "\\c";
		} else {
			$uptimeline = "COMMENT:uptime: " . uptime2str(trim($uptime)) . "\\c";
		}

		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:returned#44EEEE:Returned");
		push(@tmp, "GPRINT:returned:LAST:          Cur\\: %5.1lf%s");
		push(@tmp, "GPRINT:returned:AVERAGE:   Avg\\: %5.1lf%s");
		push(@tmp, "GPRINT:returned:MIN:   Min\\: %5.1lf%s");
		push(@tmp, "GPRINT:returned:MAX:   Max\\: %5.1lf%s\\n");
		push(@tmp, "LINE2:fetched#EEEE44:Fetched");
		push(@tmp, "GPRINT:fetched:LAST:           Cur\\: %5.1lf%s");
		push(@tmp, "GPRINT:fetched:AVERAGE:   Avg\\: %5.1lf%s");
		push(@tmp, "GPRINT:fetched:MIN:   Min\\: %5.1lf%s");
		push(@tmp, "GPRINT:fetched:MAX:   Max\\: %5.1lf%s\\n");
		push(@tmp, "LINE2:inserted#44EE44:Inserted");
		push(@tmp, "GPRINT:inserted:LAST:          Cur\\: %5.1lf%s");
		push(@tmp, "GPRINT:inserted:AVERAGE:   Avg\\: %5.1lf%s");
		push(@tmp, "GPRINT:inserted:MIN:   Min\\: %5.1lf%s");
		push(@tmp, "GPRINT:inserted:MAX:   Max\\: %5.1lf%s\\n");
		push(@tmp, "LINE2:updated#EE44EE:Updated");
		push(@tmp, "GPRINT:updated:LAST:           Cur\\: %5.1lf%s");
		push(@tmp, "GPRINT:updated:AVERAGE:   Avg\\: %5.1lf%s");
		push(@tmp, "GPRINT:updated:MIN:   Min\\: %5.1lf%s");
		push(@tmp, "GPRINT:updated:MAX:   Max\\: %5.1lf%s\\n");
		push(@tmp, "LINE2:deleted#EE4444:Deleted");
		push(@tmp, "GPRINT:deleted:LAST:           Cur\\: %5.1lf%s");
		push(@tmp, "GPRINT:deleted:AVERAGE:   Avg\\: %5.1lf%s");
		push(@tmp, "GPRINT:deleted:MIN:   Min\\: %5.1lf%s");
		push(@tmp, "GPRINT:deleted:MAX:   Max\\: %5.1lf%s\\n");
		push(@tmpz, "LINE2:returned#44EEEE:Returned");
		push(@tmpz, "LINE2:fetched#EEEE44:Fetched");
		push(@tmpz, "LINE2:inserted#44EE44:Inserted");
		push(@tmpz, "LINE2:updated#EE44EE:Updated");
		push(@tmpz, "LINE2:deleted#EE4444:Deleted");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6]",
			"--title=$config->{graphs}->{_pgsql1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Tuples/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:returned=$rrd:pgsql" . $e . "_trret:AVERAGE",
			"DEF:fetched=$rrd:pgsql" . $e . "_trfet:AVERAGE",
			"DEF:inserted=$rrd:pgsql" . $e . "_trins:AVERAGE",
			"DEF:updated=$rrd:pgsql" . $e . "_trupd:AVERAGE",
			"DEF:deleted=$rrd:pgsql" . $e . "_trdel:AVERAGE",
			"CDEF:allvalues=returned,fetched,inserted,updated,deleted,+,+,+,+",
			@CDEF,
			@tmp,
			"COMMENT: \\n",
			$uptimeline,
			"COMMENT: \\n");
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6]",
				"--title=$config->{graphs}->{_pgsql1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Tuples/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:returned=$rrd:pgsql" . $e . "_trret:AVERAGE",
				"DEF:fetched=$rrd:pgsql" . $e . "_trfet:AVERAGE",
				"DEF:inserted=$rrd:pgsql" . $e . "_trins:AVERAGE",
				"DEF:updated=$rrd:pgsql" . $e . "_trupd:AVERAGE",
				"DEF:deleted=$rrd:pgsql" . $e . "_trdel:AVERAGE",
				"CDEF:allvalues=returned,fetched,inserted,updated,deleted,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pgsql$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:bgwchkt#FFA500:checkpoints_timed");
		push(@tmp, "GPRINT:bgwchkt:LAST: Cur\\: %4.0lf");
		push(@tmp, "GPRINT:bgwchkt:AVERAGE:     Avg\\: %4.0lf");
		push(@tmp, "GPRINT:bgwchkt:MIN:     Min\\: %4.0lf");
		push(@tmp, "GPRINT:bgwchkt:MAX:     Max\\: %4.0lf\\n");
		push(@tmp, "LINE2:bgwchkr#4444EE:checkpoints_req");
		push(@tmp, "GPRINT:bgwchkr:LAST:   Cur\\: %4.0lf");
		push(@tmp, "GPRINT:bgwchkr:AVERAGE:     Avg\\: %4.0lf");
		push(@tmp, "GPRINT:bgwchkr:MIN:     Min\\: %4.0lf");
		push(@tmp, "GPRINT:bgwchkr:MAX:     Max\\: %4.0lf\\n");
		push(@tmp, "LINE2:bgwbchk#44EEEE:buffers_checkpoint");
		push(@tmp, "GPRINT:bgwbchk:LAST:Cur\\: %4.0lf");
		push(@tmp, "GPRINT:bgwbchk:AVERAGE:     Avg\\: %4.0lf");
		push(@tmp, "GPRINT:bgwbchk:MIN:     Min\\: %4.0lf");
		push(@tmp, "GPRINT:bgwbchk:MAX:     Max\\: %4.0lf\\n");
		push(@tmp, "LINE2:bgwbcln#44EE44:buffers_clean");
		push(@tmp, "GPRINT:bgwbcln:LAST:     Cur\\: %4.0lf");
		push(@tmp, "GPRINT:bgwbcln:AVERAGE:     Avg\\: %4.0lf");
		push(@tmp, "GPRINT:bgwbcln:MIN:     Min\\: %4.0lf");
		push(@tmp, "GPRINT:bgwbcln:MAX:     Max\\: %4.0lf\\n");
		push(@tmp, "LINE2:bgwmaxc#EE4444:maxwritten_clean");
		push(@tmp, "GPRINT:bgwmaxc:LAST:  Cur\\: %4.0lf");
		push(@tmp, "GPRINT:bgwmaxc:AVERAGE:     Avg\\: %4.0lf");
		push(@tmp, "GPRINT:bgwmaxc:MIN:     Min\\: %4.0lf");
		push(@tmp, "GPRINT:bgwmaxc:MAX:     Max\\: %4.0lf\\n");
		push(@tmp, "LINE2:bgwbbac#EE44EE:buffers_backend");
		push(@tmp, "GPRINT:bgwbbac:LAST:   Cur\\: %4.0lf");
		push(@tmp, "GPRINT:bgwbbac:AVERAGE:     Avg\\: %4.0lf");
		push(@tmp, "GPRINT:bgwbbac:MIN:     Min\\: %4.0lf");
		push(@tmp, "GPRINT:bgwbbac:MAX:     Max\\: %4.0lf\\n");
		push(@tmp, "LINE2:bgwball#EEEE44:buffers_alloc");
		push(@tmp, "GPRINT:bgwball:LAST:     Cur\\: %4.0lf");
		push(@tmp, "GPRINT:bgwball:AVERAGE:     Avg\\: %4.0lf");
		push(@tmp, "GPRINT:bgwball:MIN:     Min\\: %4.0lf");
		push(@tmp, "GPRINT:bgwball:MAX:     Max\\: %4.0lf\\n");
		push(@tmpz, "LINE2:bgwchkt#FFA500:checkpoints_timed");
		push(@tmpz, "LINE2:bgwchkr#4444EE:checkpoints_req");
		push(@tmpz, "LINE2:bgwbchk#44EEEE:buffers_checkpoint");
		push(@tmpz, "LINE2:bgwbcln#44EE44:buffers_clean");
		push(@tmpz, "LINE2:bgwmaxc#EE4444:maxwritten_clean");
		push(@tmpz, "LINE2:bgwbbac#EE44EE:buffers_backend");
		push(@tmpz, "LINE2:bgwball#EEEE44:buffers_alloc");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 1]",
			"--title=$config->{graphs}->{_pgsql2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Buffers written/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:bgwchkt=$rrd:pgsql" . $e . "_tbgwchkt:AVERAGE",
			"DEF:bgwchkr=$rrd:pgsql" . $e . "_tbgwchkr:AVERAGE",
			"DEF:bgwbchk=$rrd:pgsql" . $e . "_tbgwbchk:AVERAGE",
			"DEF:bgwbcln=$rrd:pgsql" . $e . "_tbgwbcln:AVERAGE",
			"DEF:bgwmaxc=$rrd:pgsql" . $e . "_tbgwmaxc:AVERAGE",
			"DEF:bgwbbac=$rrd:pgsql" . $e . "_tbgwbbac:AVERAGE",
			"DEF:bgwball=$rrd:pgsql" . $e . "_tbgwball:AVERAGE",
			"CDEF:allvalues=bgwchkt,bgwchkr,bgwbchk,bgwbcln,bgwmaxc,bgwbbac,bgwball,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 1]",
				"--title=$config->{graphs}->{_pgsql2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Buffers written/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:bgwchkt=$rrd:pgsql" . $e . "_tbgwchkt:AVERAGE",
				"DEF:bgwchkr=$rrd:pgsql" . $e . "_tbgwchkr:AVERAGE",
				"DEF:bgwbchk=$rrd:pgsql" . $e . "_tbgwbchk:AVERAGE",
				"DEF:bgwbcln=$rrd:pgsql" . $e . "_tbgwbcln:AVERAGE",
				"DEF:bgwmaxc=$rrd:pgsql" . $e . "_tbgwmaxc:AVERAGE",
				"DEF:bgwbbac=$rrd:pgsql" . $e . "_tbgwbbac:AVERAGE",
				"DEF:bgwball=$rrd:pgsql" . $e . "_tbgwball:AVERAGE",
				"CDEF:allvalues=bgwchkt,bgwchkr,bgwbchk,bgwbcln,bgwmaxc,bgwbbac,bgwball,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pgsql$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}
		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:tsize#EEEE44:Total size");
		push(@tmp, "GPRINT:tsize:LAST:           Current\\: %5.1lf%s\\n");
		push(@tmpz, "LINE2:tsize#EEEE44:Total size");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 2]",
			"--title=$config->{graphs}->{_pgsql3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=bytes",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:tsize=$rrd:pgsql" . $e . "_tsize:AVERAGE",
			"CDEF:allvalues=tsize",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 2]",
				"--title=$config->{graphs}->{_pgsql3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=bytes",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:tsize=$rrd:pgsql" . $e . "_tsize:AVERAGE",
				"CDEF:allvalues=tsize",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pgsql$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[3], $limit[3])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:tconns#4444EE:Total");
		push(@tmp, "GPRINT:tconns:LAST:                Current\\: %4.0lf\\n");
		push(@tmp, "LINE2:tactcon#EE44EE:Active");
		push(@tmp, "GPRINT:tactcon:LAST:               Current\\: %4.0lf\\n");
		push(@tmp, "LINE2:tidlcon#44EEEE:Idle");
		push(@tmp, "GPRINT:tidlcon:LAST:                 Current\\: %4.0lf\\n");
		push(@tmp, "LINE2:tidxcon#EEEE44:Idle in transaction");
		push(@tmp, "GPRINT:tidxcon:LAST:  Current\\: %4.0lf\\n");
		push(@tmp, "LINE2:tixacon#EE4444:Idle (aborted)");
		push(@tmp, "GPRINT:tixacon:LAST:       Current\\: %4.0lf\\n");
		push(@tmpz, "AREA:tconns#4444EE:Total");
		push(@tmpz, "LINE2:tactcon#EE44EE:Active");
		push(@tmpz, "LINE2:tidlcon#44EEEE:Idle");
		push(@tmpz, "LINE2:tidxcon#EEEE44:Idle in transaction");
		push(@tmpz, "LINE2:tixacon#EE4444:Idle in transaction (aborted)");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 3]",
			"--title=$config->{graphs}->{_pgsql4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Connections",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:tconns=$rrd:pgsql" . $e . "_tconns:AVERAGE",
			"DEF:tactcon=$rrd:pgsql" . $e . "_tactcon:AVERAGE",
			"DEF:tidlcon=$rrd:pgsql" . $e . "_tidlcon:AVERAGE",
			"DEF:tidxcon=$rrd:pgsql" . $e . "_tidxcon:AVERAGE",
			"DEF:tixacon=$rrd:pgsql" . $e . "_tixacon:AVERAGE",
			"CDEF:allvalues=tconns,tactcon,tidlcon,tidxcon,tixacon,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 3]",
				"--title=$config->{graphs}->{_pgsql4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Connections",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:tconns=$rrd:pgsql" . $e . "_tconns:AVERAGE",
				"DEF:tactcon=$rrd:pgsql" . $e . "_tactcon:AVERAGE",
				"DEF:tidlcon=$rrd:pgsql" . $e . "_tidlcon:AVERAGE",
				"DEF:tidxcon=$rrd:pgsql" . $e . "_tidxcon:AVERAGE",
				"DEF:tixacon=$rrd:pgsql" . $e . "_tixacon:AVERAGE",
				"CDEF:allvalues=tconns,tactcon,tidlcon,tidxcon,tixacon,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 3]: $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pgsql$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[4], $limit[4])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:xactcom#EE44EE:Committed");
		push(@tmp, "GPRINT:xactcom:LAST:            Current\\: %3.0lf\\n");
		push(@tmp, "AREA:xactrlb#EEEE44:Rolled back");
		push(@tmp, "GPRINT:xactrlb:LAST:          Current\\: %3.0lf\\n");
		push(@tmp, "LINE2:xactcom#EE00EE");
		push(@tmp, "LINE2:xactrlb#EEEE00");
		push(@tmpz, "AREA:xactcom#EE44EE:Committed");
		push(@tmpz, "AREA:xactrlb#EEEE44:Rolled back");
		push(@tmpz, "LINE2:xactcom#EE00EE");
		push(@tmpz, "LINE2:xactrlb#EEEE00");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 4]",
			"--title=$config->{graphs}->{_pgsql5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Transactions/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:xactcom=$rrd:pgsql" . $e . "_txactcom:AVERAGE",
			"DEF:xactrlb=$rrd:pgsql" . $e . "_txactrlb:AVERAGE",
			"CDEF:allvalues=xactcom,xactrlb,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 4]",
				"--title=$config->{graphs}->{_pgsql5}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Transactions/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:xactcom=$rrd:pgsql" . $e . "_txactcom:AVERAGE",
				"DEF:xactrlb=$rrd:pgsql" . $e . "_txactrlb:AVERAGE",
				"CDEF:allvalues=xactcom,xactrlb,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 4]: $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pgsql$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 4] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 4] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[5], $limit[5])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:blkhit#44EEEE:Blocks hit");
		push(@tmp, "GPRINT:blkhit:LAST:           Current\\: %4.1lf%s\\n");
		push(@tmp, "AREA:blkrea#EE44EE:Blocks read");
		push(@tmp, "GPRINT:blkrea:LAST:          Current\\: %4.1lf%s\\n");
		push(@tmp, "LINE2:blkhit#00EEEE");
		push(@tmp, "LINE2:blkrea#EE00EE");
		push(@tmpz, "AREA:blkhit#44EEEE:Blocks hit");
		push(@tmpz, "AREA:blkrea#EE44EE:Blocks read");
		push(@tmpz, "LINE2:blkhit#00EEEE");
		push(@tmpz, "LINE2:blkrea#EE00EE");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 5]",
			"--title=$config->{graphs}->{_pgsql6}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Values/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:blkrea=$rrd:pgsql" . $e . "_tblkrea:AVERAGE",
			"DEF:blkhit=$rrd:pgsql" . $e . "_tblkhit:AVERAGE",
			"CDEF:allvalues=blkrea,blkhit,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 5]",
				"--title=$config->{graphs}->{_pgsql6}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Values/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:blkrea=$rrd:pgsql" . $e . "_tblkrea:AVERAGE",
				"DEF:blkhit=$rrd:pgsql" . $e . "_tblkhit:AVERAGE",
				"CDEF:allvalues=blkrea,blkhit,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 5]: $err\n") if $err;
		}
		$e2 = $e + 6;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pgsql$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 5] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 5] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "'>\n");
			}
		}


		# "per-database" graphs

		my $e3 = 0;
		$e2 = 6;
		while($e3 < scalar(my @dbl = split(',', $pgsql->{desc}->{$pg}->{db_list}))) {
			my $str = trim($dbl[$e3]);

			if($title) {
				push(@output, "  </table>\n");
				push(@output, "  <table cellspacing='5' cellpadding='0' width='1' bgcolor='$colors->{graph_bg_color}' border='1'>\n");

				push(@output, "    <tr>\n");
				push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
				push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
				push(@output, "       <font size='-1'>\n");
				push(@output, "        <b style='{color: " . $colors->{title_fg_color} . "}'>&nbsp;&nbsp;'$str' database statistics</b>\n");
				push(@output, "       </font></font>\n");
				push(@output, "      </td>\n");
				push(@output, "    </tr>\n");

				push(@output, "    <tr>\n");
				push(@output, "    <td class='td-valign-top'>\n");
			}

			@riglim = @{setup_riglim($rigid[0], $limit[0])};
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			push(@tmp, "LINE2:returned#44EEEE:Returned");
			push(@tmp, "GPRINT:returned:LAST:       Cur\\: %5.1lf%s");
			push(@tmp, "GPRINT:returned:AVERAGE:  Avg\\: %5.1lf%s");
			push(@tmp, "GPRINT:returned:MAX:  Max\\: %5.1lf%s\\n");
			push(@tmp, "LINE2:fetched#EEEE44:Fetched");
			push(@tmp, "GPRINT:fetched:LAST:        Cur\\: %5.1lf%s");
			push(@tmp, "GPRINT:fetched:AVERAGE:  Avg\\: %5.1lf%s");
			push(@tmp, "GPRINT:fetched:MAX:  Max\\: %5.1lf%s\\n");
			push(@tmp, "LINE2:inserted#44EE44:Inserted");
			push(@tmp, "GPRINT:inserted:LAST:       Cur\\: %5.1lf%s");
			push(@tmp, "GPRINT:inserted:AVERAGE:  Avg\\: %5.1lf%s");
			push(@tmp, "GPRINT:inserted:MAX:  Max\\: %5.1lf%s\\n");
			push(@tmp, "LINE2:updated#EE44EE:Updated");
			push(@tmp, "GPRINT:updated:LAST:        Cur\\: %5.1lf%s");
			push(@tmp, "GPRINT:updated:AVERAGE:  Avg\\: %5.1lf%s");
			push(@tmp, "GPRINT:updated:MAX:  Max\\: %5.1lf%s\\n");
			push(@tmp, "LINE2:deleted#EE4444:Deleted");
			push(@tmp, "GPRINT:deleted:LAST:        Cur\\: %5.1lf%s");
			push(@tmp, "GPRINT:deleted:AVERAGE:  Avg\\: %5.1lf%s");
			push(@tmp, "GPRINT:deleted:MAX:  Max\\: %5.1lf%s\\n");
			push(@tmpz, "LINE2:returned#44EEEE:Returned");
			push(@tmpz, "LINE2:fetched#EEEE44:Fetched");
			push(@tmpz, "LINE2:inserted#44EE44:Inserted");
			push(@tmpz, "LINE2:updated#EE44EE:Updated");
			push(@tmpz, "LINE2:deleted#EE4444:Deleted");
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{medium});
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
				@tmp = @tmpz;
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + $e2]",
				"--title=$config->{graphs}->{_pgsql1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Tuples/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:returned=$rrd:pgsql" . $e . $e3 . "_rret:AVERAGE",
				"DEF:fetched=$rrd:pgsql" . $e . $e3 . "_rfet:AVERAGE",
				"DEF:inserted=$rrd:pgsql" . $e . $e3 . "_rins:AVERAGE",
				"DEF:updated=$rrd:pgsql" . $e . $e3 . "_rupd:AVERAGE",
				"DEF:deleted=$rrd:pgsql" . $e . $e3 . "_rdel:AVERAGE",
				"CDEF:allvalues=returned,fetched,inserted,updated,deleted,+,+,+,+",
				@CDEF,
				@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + $e2]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + $e2]",
					"--title=$config->{graphs}->{_pgsql1}  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=Tuples/s",
					"--width=$width",
					"--height=$height",
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$colors->{graph_colors}},
					"DEF:returned=$rrd:pgsql" . $e . $e3 . "_rret:AVERAGE",
					"DEF:fetched=$rrd:pgsql" . $e . $e3 . "_rfet:AVERAGE",
					"DEF:inserted=$rrd:pgsql" . $e . $e3 . "_rins:AVERAGE",
					"DEF:updated=$rrd:pgsql" . $e . $e3 . "_rupd:AVERAGE",
					"DEF:deleted=$rrd:pgsql" . $e . $e3 . "_rdel:AVERAGE",
					"CDEF:allvalues=returned,fetched,inserted,updated,deleted,+,+,+,+",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + $e2]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /pgsql/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "'>\n");
				}
			}

			$e2++;
			@riglim = @{setup_riglim($rigid[3], $limit[3])};
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			push(@tmp, "AREA:conns#4444EE:Total");
			push(@tmp, "GPRINT:conns:LAST:          Cur\\: %4.0lf");
			push(@tmp, "GPRINT:conns:AVERAGE:    Avg\\: %4.0lf");
			push(@tmp, "GPRINT:conns:MAX:   Max\\: %4.0lf\\n");
			push(@tmp, "LINE2:actcon#EE44EE:Active");
			push(@tmp, "GPRINT:actcon:LAST:         Cur\\: %4.0lf");
			push(@tmp, "GPRINT:actcon:AVERAGE:    Avg\\: %4.0lf");
			push(@tmp, "GPRINT:actcon:MAX:   Max\\: %4.0lf\\n");
			push(@tmp, "LINE2:idlcon#44EEEE:Idle");
			push(@tmp, "GPRINT:idlcon:LAST:           Cur\\: %4.0lf");
			push(@tmp, "GPRINT:idlcon:AVERAGE:    Avg\\: %4.0lf");
			push(@tmp, "GPRINT:idlcon:MAX:   Max\\: %4.0lf\\n");
			push(@tmp, "LINE2:idxcon#EEEE44:Idle in trans.");
			push(@tmp, "GPRINT:idxcon:LAST: Cur\\: %4.0lf");
			push(@tmp, "GPRINT:idxcon:AVERAGE:    Avg\\: %4.0lf");
			push(@tmp, "GPRINT:idxcon:MAX:   Max\\: %4.0lf\\n");
			push(@tmp, "LINE2:ixacon#EE4444:Idle (aborted)");
			push(@tmp, "GPRINT:ixacon:LAST: Cur\\: %4.0lf");
			push(@tmp, "GPRINT:ixacon:AVERAGE:    Avg\\: %4.0lf");
			push(@tmp, "GPRINT:ixacon:MAX:   Max\\: %4.0lf\\n");
			push(@tmpz, "AREA:conns#4444EE:Total");
			push(@tmpz, "LINE2:actcon#EE44EE:Active");
			push(@tmpz, "LINE2:idlcon#44EEEE:Idle");
			push(@tmpz, "LINE2:idxcon#EEEE44:Idle in transaction");
			push(@tmpz, "LINE2:ixacon#EE4444:Idle in transaction (aborted)");
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{medium2});
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
				@tmp = @tmpz;
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + $e2]",
				"--title=$config->{graphs}->{_pgsql4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Connections",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:conns=$rrd:pgsql" . $e . $e3 . "_conns:AVERAGE",
				"DEF:actcon=$rrd:pgsql" . $e . $e3 . "_actcon:AVERAGE",
				"DEF:idlcon=$rrd:pgsql" . $e . $e3 . "_idlcon:AVERAGE",
				"DEF:idxcon=$rrd:pgsql" . $e . $e3 . "_idxcon:AVERAGE",
				"DEF:ixacon=$rrd:pgsql" . $e . $e3 . "_ixacon:AVERAGE",
				"CDEF:allvalues=conns,actcon,idlcon,idxcon,ixacon,+,+,+,+",
				@CDEF,
				@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + $e2]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + $e2]",
					"--title=$config->{graphs}->{_pgsql4}  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=Connections",
					"--width=$width",
					"--height=$height",
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$cgi->{version12_small}},
					@{$colors->{graph_colors}},
					"DEF:conns=$rrd:pgsql" . $e . $e3 . "_conns:AVERAGE",
					"DEF:actcon=$rrd:pgsql" . $e . $e3 . "_actcon:AVERAGE",
					"DEF:idlcon=$rrd:pgsql" . $e . $e3 . "_idlcon:AVERAGE",
					"DEF:idxcon=$rrd:pgsql" . $e . $e3 . "_idxcon:AVERAGE",
					"DEF:ixacon=$rrd:pgsql" . $e . $e3 . "_ixacon:AVERAGE",
					"CDEF:allvalues=conns,actcon,idlcon,idxcon,ixacon,+,+,+,+",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + $e2]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /pgsql/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "'>\n");
				}
			}

			if($title) {
				push(@output, "    </td>\n");
				push(@output, "    <td class='td-valign-top'>\n");
			}

			$e2++;
			@riglim = @{setup_riglim($rigid[2], $limit[2])};
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			push(@tmp, "LINE2:size#EEEE44:Size");
			push(@tmp, "GPRINT:size:LAST:           Cur\\: %5.1lf%s");
			push(@tmp, "GPRINT:size:AVERAGE:   Avg\\: %5.1lf%s");
			push(@tmp, "GPRINT:size:MAX:  Max\\: %5.1lf%s\\n");
			push(@tmpz, "LINE2:size#EEEE44:Size");
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{medium2});
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
				@tmp = @tmpz;
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + $e2]",
				"--title=$config->{graphs}->{_pgsql3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=bytes",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:size=$rrd:pgsql" . $e . $e3 . "_size:AVERAGE",
				"CDEF:allvalues=size",
				@CDEF,
				@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + $e2]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + $e2]",
					"--title=$config->{graphs}->{_pgsql3}  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=bytes",
					"--width=$width",
					"--height=$height",
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$cgi->{version12_small}},
					@{$colors->{graph_colors}},
					"DEF:size=$rrd:pgsql" . $e . $e3 . "_size:AVERAGE",
					"CDEF:allvalues=size",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + $e2]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /pgsql/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "'>\n");
				}
			}

			$e2++;
			@riglim = @{setup_riglim($rigid[4], $limit[4])};
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			push(@tmp, "AREA:xactcom#EE44EE:Committed");
			push(@tmp, "GPRINT:xactcom:LAST:      Cur\\: %3.0lf");
			push(@tmp, "GPRINT:xactcom:AVERAGE:      Avg\\: %3.0lf");
			push(@tmp, "GPRINT:xactcom:MAX:     Max\\: %3.0lf\\n");
			push(@tmp, "AREA:xactrlb#EEEE44:Rolled back");
			push(@tmp, "GPRINT:xactrlb:LAST:    Cur\\: %3.0lf");
			push(@tmp, "GPRINT:xactrlb:AVERAGE:      Avg\\: %3.0lf");
			push(@tmp, "GPRINT:xactrlb:MAX:     Max\\: %3.0lf\\n");
			push(@tmp, "LINE2:xactcom#EE00EE");
			push(@tmp, "LINE2:xactrlb#EEEE00");
			push(@tmpz, "AREA:xactcom#EE44EE:Committed");
			push(@tmpz, "AREA:xactrlb#EEEE44:Rolled back");
			push(@tmpz, "LINE2:xactcom#EE00EE");
			push(@tmpz, "LINE2:xactrlb#EEEE00");
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{medium2});
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
				@tmp = @tmpz;
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + $e2]",
				"--title=$config->{graphs}->{_pgsql5}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Transactions/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:xactcom=$rrd:pgsql" . $e . $e3 . "_xactcom:AVERAGE",
				"DEF:xactrlb=$rrd:pgsql" . $e . $e3 . "_xactrlb:AVERAGE",
				"CDEF:allvalues=xactcom,xactrlb,+",
				@CDEF,
				@tmp,
				"COMMENT: \\n");
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + $e2]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + $e2]",
					"--title=$config->{graphs}->{_pgsql5}  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=Transactions/s",
					"--width=$width",
					"--height=$height",
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$cgi->{version12_small}},
					@{$colors->{graph_colors}},
					"DEF:xactcom=$rrd:pgsql" . $e . $e3 . "_xactcom:AVERAGE",
					"DEF:xactrlb=$rrd:pgsql" . $e . $e3 . "_xactrlb:AVERAGE",
					"CDEF:allvalues=xactcom,xactrlb,+",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + $e2]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /pgsql/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "'>\n");
				}
			}

			$e2++;
			@riglim = @{setup_riglim($rigid[5], $limit[5])};
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			push(@tmp, "AREA:blkhit#44EEEE:Blocks hit");
			push(@tmp, "GPRINT:blkhit:LAST:     Cur\\: %5.1lf%s");
			push(@tmp, "GPRINT:blkhit:AVERAGE:   Avg\\: %5.1lf%s");
			push(@tmp, "GPRINT:blkhit:MAX:  Max\\: %5.1lf%s\\n");
			push(@tmp, "AREA:blkrea#EE44EE:Blocks read");
			push(@tmp, "GPRINT:blkrea:LAST:    Cur\\: %5.1lf%s");
			push(@tmp, "GPRINT:blkrea:AVERAGE:   Avg\\: %5.1lf%s");
			push(@tmp, "GPRINT:blkrea:MAX:  Max\\: %5.1lf%s\\n");
			push(@tmp, "LINE2:blkhit#00EEEE");
			push(@tmp, "LINE2:blkrea#EE00EE");
			push(@tmpz, "AREA:blkhit#44EEEE:Blocks hit");
			push(@tmpz, "AREA:blkrea#EE44EE:Blocks read");
			push(@tmpz, "LINE2:blkhit#00EEEE");
			push(@tmpz, "LINE2:blkrea#EE00EE");
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{medium2});
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
				@tmp = @tmpz;
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + $e2]",
				"--title=$config->{graphs}->{_pgsql6}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Values/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:blkrea=$rrd:pgsql" . $e . $e3 . "_blkrea:AVERAGE",
				"DEF:blkhit=$rrd:pgsql" . $e . $e3 . "_blkhit:AVERAGE",
				"CDEF:allvalues=blkrea,blkhit,+",
				@CDEF,
				@tmp,
				"COMMENT: \\n");
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + $e2]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + $e2]",
					"--title=$config->{graphs}->{_pgsql6}  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=Values/s",
					"--width=$width",
					"--height=$height",
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$cgi->{version12_small}},
					@{$colors->{graph_colors}},
					"DEF:blkrea=$rrd:pgsql" . $e . $e3 . "_blkrea:AVERAGE",
					"DEF:blkhit=$rrd:pgsql" . $e . $e3 . "_blkhit:AVERAGE",
					"CDEF:allvalues=blkrea,blkhit,+",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + $e2]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /pgsql/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "'>\n");
				}
			}
			$e2++;
			$e3++;
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");

			push(@output, "    <tr>\n");
			push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
			push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
			push(@output, "       <font size='-1'>\n");
			push(@output, "        <b style='{color: " . $colors->{title_fg_color} . "}'>&nbsp;&nbsp;$pg</b>\n");
			push(@output, "       </font></font>\n");
			push(@output, "      </td>\n");
			push(@output, "    </tr>\n");
			push(@output, main::graph_footer());
		}
		$e++;
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
