#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2012 by Jordi Sanfeliu <jordi@fibranet.cat>
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

package port;

#use strict;
use warnings;
use Monitorix;
use RRDs;
use POSIX qw(strftime);
use Exporter 'import';
our @EXPORT = qw(port_init port_update port_cgi);

sub port_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $port = $config->{port};

	my $info;
	my @ds;
	my @tmp;
	my $n;

	if(-e $rrd) {
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'ds[') == 0) {
				if(index($key, '.type') != -1) {
					push(@ds, substr($key, 3, index($key, ']') - 3));
				}
			}
		}
		if(scalar(@ds) / 2 != $port->{max}) {
			logger("Detected size mismatch between 'max = $port->{max}' and $rrd (" . scalar(@ds) / 2 . "). Resizing it accordingly. All historic data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
	}

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
		for($n = 0; $n < $port->{max}; $n++) {
			push(@tmp, "DS:port" . $n . "_in:GAUGE:120:0:U");
			push(@tmp, "DS:port" . $n . "_out:GAUGE:120:0:U");
		}
		eval {
			RRDs::create($rrd,
				"--step=60",
				@tmp,
				"RRA:AVERAGE:0.5:1:1440",
				"RRA:AVERAGE:0.5:30:336",
				"RRA:AVERAGE:0.5:60:744",
				"RRA:AVERAGE:0.5:1440:365",
				"RRA:MIN:0.5:1:1440",
				"RRA:MIN:0.5:30:336",
				"RRA:MIN:0.5:60:744",
				"RRA:MIN:0.5:1440:365",
				"RRA:MAX:0.5:1:1440",
				"RRA:MAX:0.5:30:336",
				"RRA:MAX:0.5:60:744",
				"RRA:MAX:0.5:1440:365",
				"RRA:LAST:0.5:1:1440",
				"RRA:LAST:0.5:30:336",
				"RRA:LAST:0.5:60:744",
				"RRA:LAST:0.5:1440:365",
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

	if($config->{os} eq "Linux") {
		my $num;
		my @line;

		# set the iptables rules for each defined port
		my @pl = split(',', $port->{list});
		for($n = 0; $n < $port->{max}; $n++) {
			$pl[$n] = trim($pl[$n]);
			if($pl[$n]) {
				my $p = lc((split(',', $port->{desc}->{$pl[$n]}))[1]) || "all";
				system("iptables -N monitorix_IN_$n 2>/dev/null");
				system("iptables -I INPUT -p $p --dport $pl[$n] -j monitorix_IN_$n -c 0 0");
				system("iptables -N monitorix_OUT_$n 2>/dev/null");
				system("iptables -I OUTPUT -p $p --sport $pl[$n] -j monitorix_OUT_$n -c 0 0");
			}
		}
	}
	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		# set the ipfw rules for each defined port
		my @pl = split(',', $port->{list});
		for($n = 0; $n < $port->{max}; $n++) {
			$pl[$n] = trim($pl[$n]);
			if($pl[$n]) {
				my $p = lc((split(',', $port->{desc}->{$pl[$n]}))[1]) || "all";
				system("ipfw -q add $port->{rule} count $p from me $pl[$n] to any");
				system("ipfw -q add $port->{rule} count $p from any to me $pl[$n]");
			}
		}
	}

	$config->{port_hist_in} = ();
	$config->{port_hist_out} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub port_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $port = $config->{port};

	my @in;
	my @out;

	my $n;
	my $rrdata = "N";

	if($config->{os} eq "Linux") {
		open(IN, "iptables -nxvL INPUT |");
		while(<IN>) {
			for($n = 0; $n < $port->{max}; $n++) {
				$in[$n] = 0 unless $in[$n];
				if(/ monitorix_IN_$n /) {
					my (undef, $bytes) = split(' ', $_);
					chomp($bytes);
					$in[$n] = $bytes - ($config->{port_hist_in}[$n] || 0);
					$in[$n] = 0 unless $in[$n] != $bytes;
					$config->{port_hist_in}[$n] = $bytes;
					$in[$n] /= 60;
				}
			}
		}
		close(IN);
		open(IN, "iptables -nxvL OUTPUT |");
		while(<IN>) {
			for($n = 0; $n < $port->{max}; $n++) {
				$out[$n] = 0 unless $out[$n];
				if(/ monitorix_OUT_$n /) {
					my (undef, $bytes) = split(' ', $_);
					chomp($bytes);
					$out[$n] = $bytes - ($config->{port_hist_out}[$n] || 0);
					$out[$n] = 0 unless $out[$n] != $bytes;
					$config->{port_hist_out}[$n] = $bytes;
					$out[$n] /= 60;
				}
			}
		}
		close(IN);
	}
	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		my @pl = split(',', $port->{list});
		open(IN, "ipfw show $port->{rule} 2>/dev/null |");
		while(<IN>) {
			for($n = 0; $n < $port->{max}; $n++) {
				$in[$n] = 0 unless $in[$n];
				$pl[$n] = trim($pl[$n]);
				if(/ from any to me dst-port $pl[$n]$/) {
					my (undef, undef, $bytes) = split(' ', $_);
					chomp($bytes);
					$in[$n] = $bytes;
				}
				$out[$n] = 0 unless $out[$n];
				if(/ from me $pl[$n] to any$/) {
					my (undef, undef, $bytes) = split(' ', $_);
					chomp($bytes);
					$out[$n] = $bytes;
				}
			}
		}
		close(IN);
	}

	for($n = 0; $n < $port->{max}; $n++) {
		$rrdata .= ":$in[$n]:$out[$n]";
	}
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

1;
