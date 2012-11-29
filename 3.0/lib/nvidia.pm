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

package nvidia;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(nvidia_init nvidia_update nvidia_cgi);

sub nvidia_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
		eval {
			RRDs::create($rrd,
				"--step=60",
				"DS:nvidia_temp0:GAUGE:120:0:U",
				"DS:nvidia_temp1:GAUGE:120:0:U",
				"DS:nvidia_temp2:GAUGE:120:0:U",
				"DS:nvidia_temp3:GAUGE:120:0:U",
				"DS:nvidia_temp4:GAUGE:120:0:U",
				"DS:nvidia_temp5:GAUGE:120:0:U",
				"DS:nvidia_temp6:GAUGE:120:0:U",
				"DS:nvidia_temp7:GAUGE:120:0:U",
				"DS:nvidia_temp8:GAUGE:120:0:U",
				"DS:nvidia_gpu0:GAUGE:120:0:100",
				"DS:nvidia_gpu1:GAUGE:120:0:100",
				"DS:nvidia_gpu2:GAUGE:120:0:100",
				"DS:nvidia_gpu3:GAUGE:120:0:100",
				"DS:nvidia_gpu4:GAUGE:120:0:100",
				"DS:nvidia_gpu5:GAUGE:120:0:100",
				"DS:nvidia_gpu6:GAUGE:120:0:100",
				"DS:nvidia_gpu7:GAUGE:120:0:100",
				"DS:nvidia_gpu8:GAUGE:120:0:100",
				"DS:nvidia_mem0:GAUGE:120:0:100",
				"DS:nvidia_mem1:GAUGE:120:0:100",
				"DS:nvidia_mem2:GAUGE:120:0:100",
				"DS:nvidia_mem3:GAUGE:120:0:100",
				"DS:nvidia_mem4:GAUGE:120:0:100",
				"DS:nvidia_mem5:GAUGE:120:0:100",
				"DS:nvidia_mem6:GAUGE:120:0:100",
				"DS:nvidia_mem7:GAUGE:120:0:100",
				"DS:nvidia_mem8:GAUGE:120:0:100",
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

sub nvidia_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nvidia = $config->{nvidia};

	my @temp;
	my @gpu;
	my @mem;
	my @data;
	my $utilization;

	my $l;
	my $n;
	my $rrdata = "N";

	for($n = 0; $n < 9; $n++) {
		$temp[$n] = 0;
		$gpu[$n] = 0;
		$mem[$n] = 0;
		if($n < $nvidia->{max}) {
			($mem[$n], $gpu[$n], $temp[$n]) = split(' ', get_nvidia_data($n));
			if(!$temp[$n] && !$gpu[$n] && !$mem[$n]) {
				# attempt to get data using the old driver version
				$utilization = 0;
	  			open(IN, "nvidia-smi -g $n |");
				@data = <IN>;
				close(IN);
				for($l = 0; $l < scalar(@data); $l++) {
					if($data[$l] =~ /Temperature/) {
						my (undef, $tmp) = split(':', $data[$l]);
						if($tmp eq "\n") {
							$l++;
							$tmp = $data[$l];
						}
						my ($value, undef) = split(' ', $tmp);
						$value =~ s/[-]/./;
						$value =~ s/[^0-9.]//g;
						if(int($value) > 0) {
							$temp[$n] = int($value);
						}
					}
					if($data[$l] =~ /Utilization/) {
						$utilization = 1;
					}
					if($utilization == 1) {
						if($data[$l] =~ /GPU/) {
							my (undef, $tmp) = split(':', $data[$l]);
							if($tmp eq "\n") {
								$l++;
								$tmp = $data[$l];
							}
							my ($value, undef) = split(' ', $tmp);
							$value =~ s/[-]/./;
							$value =~ s/[^0-9.]//g;
							if(int($value) > 0) {
								$gpu[$n] = int($value);
							}
						}
						if($data[$l] =~ /Memory/) {
							my (undef, $tmp) = split(':', $data[$l]);
							if($tmp eq "\n") {
								$l++;
								$tmp = $data[$l];
							}
							my ($value, undef) = split(' ', $tmp);
							$value =~ s/[-]/./;
							$value =~ s/[^0-9.]//g;
							if(int($value) > 0) {
								$mem[$n] = int($value);
							}
						}
					}
				}
			}
		}
	}

	for($n = 0; $n < scalar(@temp); $n++) {
		$rrdata .= ":$temp[$n]";
	}
	for($n = 0; $n < scalar(@gpu); $n++) {
		$rrdata .= ":$gpu[$n]";
	}
	for($n = 0; $n < scalar(@mem); $n++) {
		$rrdata .= ":$mem[$n]";
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub get_nvidia_data {
	my ($gpu) = @_;
	my $total = 0;
	my $used = 0;
	my $mem = 0;
	my $cpu = 0;
	my $temp = 0;
	my $check_mem = 0;
	my $check_cpu = 0;
	my $check_temp = 0;
	my $l;

	open(IN, "nvidia-smi -q -i $gpu -d MEMORY,UTILIZATION,TEMPERATURE |");
	my @data = <IN>;
	close(IN);
	for($l = 0; $l < scalar(@data); $l++) {
		if($data[$l] =~ /Memory Usage/) {
			$check_mem = 1;
			next;
		}
		if($check_mem) {	
			if($data[$l] =~ /Total/) {
				my (undef, $tmp) = split(':', $data[$l]);
				if($tmp eq "\n") {
					$l++;
					$tmp = $data[$l];
				}
				my ($value, undef) = split(' ', $tmp);
				$value =~ s/[-]/./;
				$value =~ s/[^0-9.]//g;
				if(int($value) > 0) {
					$total = int($value);
				}
			}
			if($data[$l] =~ /Used/) {
				my (undef, $tmp) = split(':', $data[$l]);
				if($tmp eq "\n") {
					$l++;
					$tmp = $data[$l];
				}
				my ($value, undef) = split(' ', $tmp);
				$value =~ s/[-]/./;
				$value =~ s/[^0-9.]//g;
				if(int($value) > 0) {
					$used = int($value);
				}
				$check_mem = 0;
			}
		}

		if($data[$l] =~ /Utilization/) {
			$check_cpu = 1;
			next;
		}
		if($check_cpu) {	
			if($data[$l] =~ /Gpu/) {
				my (undef, $tmp) = split(':', $data[$l]);
				if($tmp eq "\n") {
					$l++;
					$tmp = $data[$l];
				}
				my ($value, undef) = split(' ', $tmp);
				$value =~ s/[-]/./;
				$value =~ s/[^0-9.]//g;
				if(int($value) > 0) {
					$cpu = int($value);
				}
			}
			if($data[$l] =~ /Memory/) {
				my (undef, $tmp) = split(':', $data[$l]);
				if($tmp eq "\n") {
					$l++;
					$tmp = $data[$l];
				}
				my ($value, undef) = split(' ', $tmp);
				$value =~ s/[-]/./;
				$value =~ s/[^0-9.]//g;
				if(int($value) > 0) {
					$mem = int($value);
				}
			}
			$check_cpu = 0;
		}

		if($data[$l] =~ /Temperature/) {
			$check_temp = 1;
			next;
		}
		if($check_temp) {	
			if($data[$l] =~ /Gpu/) {
				my (undef, $tmp) = split(':', $data[$l]);
				if($tmp eq "\n") {
					$l++;
					$tmp = $data[$l];
				}
				my ($value, undef) = split(' ', $tmp);
				$value =~ s/[-]/./;
				$value =~ s/[^0-9.]//g;
				if(int($value) > 0) {
					$temp = int($value);
				}
			}
			$check_temp = 0;
		}
	}

	# NVIDIA driver v285.+ not supported (needs new output parsing).
	# This is to avoid a divide by zero message.
	if($total) {
		$mem = ($used * 100) / $total;
	} else {
		$mem = $used = $total = 0;
	}
	return join(" ", $mem, $cpu, $temp);
}

1;
