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

package net;

#use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(net_init net_update net_cgi);

sub net_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $net = $config->{net};

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
		eval {
			RRDs::create($rrd,
				"--step=60",
				"DS:net0_bytes_in:COUNTER:120:0:U",
				"DS:net0_bytes_out:COUNTER:120:0:U",
				"DS:net0_packs_in:COUNTER:120:0:U",
				"DS:net0_packs_out:COUNTER:120:0:U",
				"DS:net0_error_in:COUNTER:120:0:U",
				"DS:net0_error_out:COUNTER:120:0:U",
				"DS:net1_bytes_in:COUNTER:120:0:U",
				"DS:net1_bytes_out:COUNTER:120:0:U",
				"DS:net1_packs_in:COUNTER:120:0:U",
				"DS:net1_packs_out:COUNTER:120:0:U",
				"DS:net1_error_in:COUNTER:120:0:U",
				"DS:net1_error_out:COUNTER:120:0:U",
				"DS:net2_bytes_in:COUNTER:120:0:U",
				"DS:net2_bytes_out:COUNTER:120:0:U",
				"DS:net2_packs_in:COUNTER:120:0:U",
				"DS:net2_packs_out:COUNTER:120:0:U",
				"DS:net2_error_in:COUNTER:120:0:U",
				"DS:net2_error_out:COUNTER:120:0:U",
				"DS:net3_bytes_in:COUNTER:120:0:U",
				"DS:net3_bytes_out:COUNTER:120:0:U",
				"DS:net3_packs_in:COUNTER:120:0:U",
				"DS:net3_packs_out:COUNTER:120:0:U",
				"DS:net3_error_in:COUNTER:120:0:U",
				"DS:net3_error_out:COUNTER:120:0:U",
				"DS:net4_bytes_in:COUNTER:120:0:U",
				"DS:net4_bytes_out:COUNTER:120:0:U",
				"DS:net4_packs_in:COUNTER:120:0:U",
				"DS:net4_packs_out:COUNTER:120:0:U",
				"DS:net4_error_in:COUNTER:120:0:U",
				"DS:net4_error_out:COUNTER:120:0:U",
				"DS:net5_bytes_in:COUNTER:120:0:U",
				"DS:net5_bytes_out:COUNTER:120:0:U",
				"DS:net5_packs_in:COUNTER:120:0:U",
				"DS:net5_packs_out:COUNTER:120:0:U",
				"DS:net5_error_in:COUNTER:120:0:U",
				"DS:net5_error_out:COUNTER:120:0:U",
				"DS:net6_bytes_in:COUNTER:120:0:U",
				"DS:net6_bytes_out:COUNTER:120:0:U",
				"DS:net6_packs_in:COUNTER:120:0:U",
				"DS:net6_packs_out:COUNTER:120:0:U",
				"DS:net6_error_in:COUNTER:120:0:U",
				"DS:net6_error_out:COUNTER:120:0:U",
				"DS:net7_bytes_in:COUNTER:120:0:U",
				"DS:net7_bytes_out:COUNTER:120:0:U",
				"DS:net7_packs_in:COUNTER:120:0:U",
				"DS:net7_packs_out:COUNTER:120:0:U",
				"DS:net7_error_in:COUNTER:120:0:U",
				"DS:net7_error_out:COUNTER:120:0:U",
				"DS:net8_bytes_in:COUNTER:120:0:U",
				"DS:net8_bytes_out:COUNTER:120:0:U",
				"DS:net8_packs_in:COUNTER:120:0:U",
				"DS:net8_packs_out:COUNTER:120:0:U",
				"DS:net8_error_in:COUNTER:120:0:U",
				"DS:net8_error_out:COUNTER:120:0:U",
				"DS:net9_bytes_in:COUNTER:120:0:U",
				"DS:net9_bytes_out:COUNTER:120:0:U",
				"DS:net9_packs_in:COUNTER:120:0:U",
				"DS:net9_packs_out:COUNTER:120:0:U",
				"DS:net9_error_in:COUNTER:120:0:U",
				"DS:net9_error_out:COUNTER:120:0:U",
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

	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub net_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $net = $config->{net};

	my @net_bytes_in;
	my @net_bytes_out;
	my @net_packs_in;
	my @net_packs_out;
	my @net_error_in;
	my @net_error_out;

	my $n;
	my $rrdata = "N";

	for($n = 0; $n < 10 ; $n++) {
		$net_bytes_in[$n] = 0;
		$net_bytes_out[$n] = 0;
		$net_packs_in[$n] = 0;
		$net_packs_out[$n] = 0;
		$net_error_in[$n] = 0;
		$net_error_out[$n] = 0;
		if($n < scalar(my @nl = split(',', $net->{list}))) {
			if($config->{os} eq "Linux") {
				open(IN, "/proc/net/dev");
				my $dev;
				while(<IN>) {
					($dev, $data) = split(':', $_);
					$_ = $dev;
					if(/$nl[$n]/) {
						($net_bytes_in[$n], $net_packs_in[$n], $net_error_in[$n], undef, undef, undef, undef, undef, $net_bytes_out[$n], $net_packs_out[$n], $net_error_out[$n]) = split(' ', $data);
						last;
					}
				}
				close(IN);
			} elsif($config->{os} eq "FreeBSD") {
				open(IN, "netstat -nibd |");
				while(<IN>) {
					if(/Link/ && /$nl[$n]/) {
						# Idrop column added in 8.0
						if($config->{kernel} > 7.2) {
							(undef, undef, undef, undef, $net_packs_in[$n], $net_error_in[$n], undef, $net_bytes_in[$n], $net_packs_out[$n], $net_error_out[$n], $net_bytes_out[$n]) = split(' ', $_);
						} else {
							(undef, undef, undef, undef, $net_packs_in[$n], $net_error_in[$n], $net_bytes_in[$n], $net_packs_out[$n], $net_error_out[$n], $net_bytes_out[$n]) = split(' ', $_);
						}
						last;
					}
				}
				close(IN);
			} elsif($config->{os} eq "OpenBSD" || $config->{os} eq "NetBSD") {
				open(IN, "netstat -nibd |");
				while(<IN>) {
					if(/Link/ && /^$nl[$n]/) {
						(undef, undef, undef, undef, $net_bytes_in[$n], $net_bytes_out[$n]) = split(' ', $_);
						$net_packs_in[$n] = 0;
						$net_error_in[$n] = 0;
						$net_packs_out[$n] = 0;
						$net_error_out[$n] = 0;
						last;
					}
				}
				close(IN);
			}
		}
		chomp($net_bytes_in[$n],
			$net_bytes_out[$n],
			$net_packs_in[$n],
			$net_packs_out[$n],
			$net_error_in[$n],
			$net_error_out[$n]);
		$rrdata .= ":$net_bytes_in[$n]:$net_bytes_out[$n]:$net_packs_in[$n]:$net_packs_out[$n]:$net_error_in[$n]:$net_error_out[$n]";
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

1;
