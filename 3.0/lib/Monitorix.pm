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

package Monitorix;

use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw(logger trim get_nvidia_data);

sub logger {
	my ($msg) = @_;

	$msg = localtime() . " - " . $msg;
	print("$msg\n");
}

sub trim {
	my $str = shift;

	if($str) {
		$str =~ s/^\s+//;
		$str =~ s/\s+$//;
		return $str;
	}
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
