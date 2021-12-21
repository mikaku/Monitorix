#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2020 by Jordi Sanfeliu <jordi@fibranet.cat>
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

package fs;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Cwd 'abs_path';
use File::Basename;
use Exporter 'import';
our @EXPORT = qw(fs_init fs_update fs_cgi);

#
# Some ideas of this upgrading function have been taken from a script written
# by Joost Cassee and found in the RRDtool Contrib Area:
# <http://oss.oetiker.ch/rrdtool/pub/contrib/>
#
sub upgrade_to_350 {
	my $myself = (caller(0))[3];
	my $rrd = shift;

	my $ds = 0;
	my $cdp = 0;
	my $end_tim = 0;
	my $str = "";

	logger("$myself: Adding new 'ino' plus 4 extra DS to '$rrd'.");
	logger("$myself: $!") if !(open(IN, "rrdtool dump $rrd |"));
	logger("$myself: $!") if !(open(OUT, "| rrdtool restore - $rrd.new"));

	while(<IN>) {
		$ds = 1 if /<!-- Round Robin Database Dump -->/;
		$ds = 0 if /<!-- Round Robin Archives -->/;
		$cdp = 1 if /<cdp_prep>/;
		$cdp = 0 if /<\/cdp_prep>/;
		if($ds) {
			if(/<name> fs(\d+)_use(\d+) <\/name>/) {
				$str = "fs$1" . "_tim$2";
			}
			$end_tim = 1 if /<name> $str <\/name>/;
			if($end_tim) {
				if(/<\/ds>/) {
					$str =~ s/tim/ino/;
					print OUT $_;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> 100 </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/ino/va1/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/va1/va2/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/va2/va3/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/va3/va4/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$end_tim = 0;
					next;
				}
			}
		}
		if($cdp) {
			if(/<\/ds>/) {
				if(!($cdp % 3)) {
					print OUT $_;
					print OUT <<EOF;
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
EOF
					$cdp++;
					next;
				}
				$cdp++;
			}
		}

		if(/<\/row>/) {
			my $str = $_;
			my $n = 0;
			$str =~ s/(\s*<\/v>)/++$n % 3 == 0 ? " $1<v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v>" : $1/eg;
			print OUT $str;
			next;
		}

		print OUT $_;
	}
	close(IN);
	close(OUT);

	if(-f "$rrd.new") {
		rename($rrd, "$rrd.old");
		rename("$rrd.new", $rrd);
	} else {
		logger("$myself: WARNING: something went wrong upgrading $rrd. You have an unsupported old version.");
	}
}

sub fs_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $fs = $config->{fs};

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;

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

		# convert from 3.4.0- to 3.5.0 (add fs_ino plus 4 extra DS)
		upgrade_to_350($rrd) if scalar(@ds) == 24;
		# recalculate the number of DS
		undef(@ds);
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'ds[') == 0) {
				if(index($key, '.type') != -1) {
					push(@ds, substr($key, 3, index($key, ']') - 3));
				}
			}
		}

		if(scalar(@ds) / 64 != keys(%{$fs->{list}})) {
			logger("$myself: Detected size mismatch between <list>...</list> (" . keys(%{$fs->{list}}) . ") and $rrd (" . scalar(@ds) / 64 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < keys(%{$fs->{list}}); $n++) {
			push(@tmp, "DS:fs" . $n . "_use0:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa0:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim0:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_ino0:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_va10:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va20:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va30:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va40:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use1:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa1:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim1:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_ino1:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_va11:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va21:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va31:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va41:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use2:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa2:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim2:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_ino2:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_va12:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va22:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va32:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va42:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use3:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa3:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim3:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_ino3:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_va13:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va23:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va33:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va43:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use4:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa4:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim4:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_ino4:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_va14:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va24:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va34:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va44:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use5:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa5:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim5:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_ino5:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_va15:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va25:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va35:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va45:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use6:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa6:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim6:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_ino6:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_va16:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va26:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va36:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va46:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use7:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa7:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim7:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_ino7:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_va17:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va27:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va37:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_va47:GAUGE:120:0:U");
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

	# This tries to find out the physical device name of each fs.
	foreach my $k (sort keys %{$fs->{list}}) {
		my @fsl = split(',', $fs->{list}->{$k});
		my $d;
		foreach my $f (@fsl) {
			$d = "";
			$f = trim($f);
			$d = $fs->{devmap}->{$f} if $fs->{devmap}->{$f};
			next unless !$d;

			if($f ne "swap") {
				my $pid;
				eval {
					local $SIG{'ALRM'} = sub {
						if($pid) {
							logger("$myself: Timeout! Process with PID '$pid' still hung after $config->{timeout} secs. Killed.");
							kill 9, $pid;
						} else {
							logger("$myself: WARNING: \$pid has no value ('$pid') in ALRM sighandler.");
						}
					};
					alarm($config->{timeout});
					$pid = open(IN, "df -P '$f' |");
					while(<IN>) {
						if(/ $f$/) {
							($d) = split(' ', $_);
							last;
						}
					}
					close(IN);
					alarm(0);
					chomp($d);
				};
			}

			if($config->{os} eq "Linux" && $config->{kernel} gt "2.4") {
				my $lvm;
				my $lvm_disk;
				my $is_md;
				my $found;

				if($f eq "swap") {
					$d = `cat /proc/swaps | tail -1 | awk -F " " '{ print \$1 }'`;
					chomp($d);
				}

				# check for device names using symbolic links
				# e.g. /dev/disk/by-uuid/db312d12-0da6-44e5-a354-4c82118f4b66
				if(-l $d) {
					$d = abs_path(dirname($d) . "/" . readlink($d));
					chomp($d);
				}

				# get the major and minor of $d
				my $rdev = (stat($d))[6];
				if(!$rdev) {
					logger("$myself: Unable to detect the device name of '$f', I/O stats won't be shown in graph. If this is really a mount point then consider using <devmap> to map it manually to a device name.");
					next;
				}
				my $minor = $rdev % 256;
				my $major = int($rdev / 256);

				# do exists in /proc/diskstats?
				if($found = is_in_diskstats($d, $major, $minor)) {
					$d = $found;
					$fs->{devmap}->{$f} = $d;
					logger("$myself: Detected physical device name for $f in '$d'.") if $debug;
					next;
				}

				logger("$myself: Unable to find major/minor in /proc/diskstats.") if $debug;

				# check if device is using EVMS <http://evms.sourceforge.net/>
				if($d =~ m/\/dev\/evms\//) {
					$d = `evms_query disks $d`;
					if($found = is_in_diskstats($d)) {
						$d = $found;
						$fs->{devmap}->{$f} = $d;
						logger("$myself: Detected physical device name for $f in '$d'.") if $debug;
						next;
					}
				}

				$d =~ s/^.*dev\///;	# remove the /dev/ prefix
				$d =~ s/^.*mapper\///;	# remove the mapper/ prefix

				# check if the device is under a crypt LUKS (encrypted fs)
				my $dev;
				if($dev = is_luks($d)) {
					$d = $dev;
				}

				# do exists in /proc/diskstats?
				if($found = is_in_diskstats($d)) {
					$d = $found;
					$fs->{devmap}->{$f} = $d;
					logger("$myself: Detected physical device name for $f in '$d'.") if $debug;
					next;
				}

				# check if the device is in a LVM
				$lvm = $d;
				$lvm =~ s/-.*//;
				if($lvm ne $d) {	# probably LVM
					if(system("pvs >/dev/null 2>&1") == 0 && $lvm) {
						$lvm_disk = `pvs --noheadings | grep $lvm | tail -1 | awk -F " " '{ print \$1 }'`;
						chomp($lvm_disk);
						$lvm_disk =~ s/^.*dev\///;	# remove the /dev/ prefix
						$lvm_disk =~ s/^.*mapper\///;	# remove the mapper/ prefix
						if(!($lvm_disk =~ m/md/)) {
							if($lvm_disk =~ m/cciss/) {
								# LVM over a CCISS disk (/dev/cciss/c0d0)
								$d = $lvm_disk;
								chomp($d);
							} elsif($dev = is_luks($lvm_disk)) {
								$d = $dev;
							} else {
								# LVM over a direct disk (/dev/sda1)
								$d = $lvm_disk;
								chomp($d);
							}
						} else {
							# LVM over Linux RAID combination (/dev/md1)
							$d = $lvm_disk;
							chomp($d);
						}
					}
				}
			} elsif($config->{os} eq "FreeBSD" || $config->{os} eq "OpenBSD" || $config->{os} eq "NetBSD") {
				if($f eq "swap") {
					if($config->{os} eq "FreeBSD" || $config->{os} eq "NetBSD") {
						$d = `swapinfo | tail -1 | awk -F " " '{ print \$1 }'`;
						chomp($d);
					}
					if($config->{os} eq "OpenBSD") {
						$d = `swapctl -l | tail -1 | awk -F " " '{ print \$1 }'`;
						chomp($d);
					}
				}

				# remove the /dev/ prefix
				if ($d =~ s/^.*dev\///) {
					# not ZFS; get the device name, eg ada0; md0; ad10
					$d =~ s/^(\D+\d*)\D.*/$1/;
				} else {
					# Just take ZFS pool name
					$d =~ s,^([^/]*)/.*,$1,;
				}
			}
			$fs->{devmap}->{$f} = $d;
			logger("$myself: Detected physical device name for $f in '$d'.") if $debug;
		}
	}

	# check for deprecated options
	if($fs->{alerts}->{rootfs_enabled} || $fs->{alerts}->{rootfs_timeintvl} || $fs->{alerts}->{rootfs_threshold} || $fs->{alerts}->{rootfs_script}) {
		logger("$myself: WARNING: you have deprecated options in the <alerts> section. Please read the monitorix.conf(5) man page and consider also upgrade your current configuration file.");
	}

	$config->{fs_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub is_in_diskstats {
	my ($d, $major, $minor) = @_;

	open(IN, "/proc/diskstats");
	my @data = <IN>;
	close(IN);
	foreach(@data) {
		my ($maj, $min, $device) = split(' ', $_);
		return $device unless $d ne $device;
		if($maj == $major && $min == $minor) {
			return $device;
		}
	}
}

sub is_luks {
	my ($d) = @_;

	if($d =~ m/luks/) {
		$d =~ s/luks-//;
		$d = `blkid -t UUID=$d | awk -F ":" '{ print \$1 }'`;
		chomp($d);
		$d =~ s/^.*dev\///;	# remove the /dev/ prefix
		$d =~ s/^.*mapper\///;	# remove the mapper/ prefix
		return $d;
	}
}

sub fs_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $fs = $config->{fs};

	my @tmp;
	my $val;
	my $str;

	my $n;
	my $rrdata = "N";

	my $e = 0;
	foreach my $k (sort keys %{$fs->{list}}) {
		my @fsl = split(',', $fs->{list}->{$k});
		for($n = 0; $n < 8; $n++) {
			my $use = 0;
			my $ioa = 0;
			my $tim = 0;
			my $ino = 0;

			my $used = 0;
			my $free = 0;

			my $f = trim($fsl[$n]) || "";
			if($f && $f eq "swap") {
				if($config->{os} eq "Linux") {
					open(IN, "free |");
					while(<IN>) {
						if(/^Swap:\s+\d+\s+(\d+)\s+(\d+)\s*$/) {
							$used = $1;
							$free = $2;
						}
					}
					close(IN);
				} elsif($config->{os} eq "FreeBSD") {
					open(IN, "swapinfo -k |");
					while(<IN>) {
						if(/^.*?\s+\d+\s+(\d+)\s+(\d+)\s+\d+\%$/) {
							$used = $1;
							$free = $2;
						}
					}
					close(IN);
				} elsif($config->{os} eq "OpenBSD" || $config->{os} eq "NetBSD") {
					open(IN, "pstat -sk |");
					while(<IN>) {
						if(/^swap_device\s+\d+\s+(\d+)\s+(\d+) /) {
							$used = $1;
							$free = $2;
						}
					}
					close(IN);
				}

				chomp($used, $free);
				# prevents a division by 0 if swap device is not used
				$use = ($used * 100) / ($used + $free) unless $used + $free == 0;
			} elsif($f) {
				my $pid;
				@tmp = (0) x 10;
				eval {
					local $SIG{'ALRM'} = sub {
						if($pid) {
							logger("$myself: Timeout! Process with PID '$pid' still hung after $config->{timeout} secs. Killed.");
							kill 9, $pid;
						} else {
							logger("$myself: WARNING: \$pid has no value ('$pid') in ALRM sighandler.");
						}
						@tmp = (0, 0, 0, 0);
					};
					alarm($config->{timeout});
					$pid = open(IN, "df -P '$f' |");
					while(<IN>) {
						if(/ $f$/) {
							@tmp = split(' ', $_);
							last;
						}
					}
					close(IN);
					alarm(0);
				};
				(undef, undef, $used, $free) = @tmp;
				chomp($used, $free);
				# prevents a division by 0 if device is not responding
				$use = ($used * 100) / ($used + $free) unless $used + $free == 0;

				eval {
					local $SIG{'ALRM'} = sub {
						if($pid) {
							logger("$myself: Timeout! Process with PID '$pid' still hung after $config->{timeout} secs. Killed.");
							kill 9, $pid;
						} else {
							logger("$myself: WARNING: \$pid has no value ('$pid') in ALRM sighandler.");
						}
						@tmp = (0, 0, 0, 0, 0, 0, 0);
					};
					alarm($config->{timeout});
					if($config->{os} eq "Linux") {
						$pid = open(IN, "df -P -i '$f' |");
					} elsif($config->{os} eq "FreeBSD" || $config->{os} eq "OpenBSD") {
						$pid = open(IN, "df -i '$f' |");
					}
					while(<IN>) {
						if(/ $f$/) {
							@tmp = split(' ', $_);
							last;
						}
					}
					close(IN);
					alarm(0);
				};
				if($config->{os} eq "Linux") {
					(undef, undef, $used, $free) = @tmp;
				} elsif($config->{os} eq "FreeBSD" || $config->{os} eq "OpenBSD") {
					(undef, undef, undef, undef, undef, $used, $free) = @tmp;
				}
				chomp($used, $free);
				# prevents a division by 0 if device is not responding
				$ino = ($used * 100) / ($used + $free) unless $used + $free == 0;

				# check alerts for each filesystem
				my @al = split(',', $fs->{alerts}->{$f} || "");
				if(scalar(@al)) {
					my $timeintvl = trim($al[0]);
					my $threshold = trim($al[1]);
					my $script = trim($al[2]);

					if(!$threshold || $use < $threshold) {
						$config->{fs_hist}->{$f} = 0;
					} else {
						if(!$config->{fs_hist}->{$f}) {
							$config->{fs_hist}->{$f} = time;
						}
						if($config->{fs_hist}->{$f} > 0 && (time - $config->{fs_hist}->{$f}) >= $timeintvl) {
							if(-x $script) {
								logger("$myself: alert on filesystem '$f': executing script '$script'.");
								system($script . " " . $timeintvl . " " . $threshold . " " . $use);
							} else {
								logger("$myself: ERROR: script '$script' doesn't exist or don't has execution permissions.");
							}
							$config->{fs_hist}->{$f} = time;
						}
					}
				}
			}

			my $read_cnt = 0;
			my $read_sec = 0;
			my $write_cnt = 0;
			my $write_sec = 0;
			my $d = $fs->{devmap}->{$f};
			if($d) {
				if($config->{os} eq "Linux") {
					if($config->{kernel} gt "2.4") {
						if(open(IN, "/proc/diskstats")) {
							while(<IN>) {
								if(/ $d /) {
									@tmp = split(' ', $_);
									last;
								}
							}
							close(IN);
						}
						(undef, undef, undef, $read_cnt, undef, undef, $read_sec, $write_cnt, undef, undef, $write_sec) = @tmp;
					} else {
						my $io;
						open(IN, "/proc/stat");
						while(<IN>) {
							if(/^disk_io/) {
								(undef, undef, $io) = split(':', $_);
								last;
							}
						}
						close(IN);
						(undef, $read_cnt, $read_sec, $write_cnt, $write_sec) = split(',', $io);
						$write_sec =~ s/\).*$//;
					}
				} elsif($config->{os} eq "FreeBSD") {
					@tmp = split(' ', `iostat -xI '$d' | grep -w '$d'`);
					if(@tmp) {
						(undef, $read_cnt, $write_cnt, $read_sec, $write_sec) = @tmp;
						$read_cnt = int($read_cnt);
						$write_cnt = int($write_cnt);
						$read_sec = int($read_sec);
						$write_sec = int($write_sec);
					} else {
						@tmp = split(' ', `iostat -dI | tail -1`);
						(undef, $read_cnt, $read_sec) = @tmp;
						$write_cnt = 0;
						$write_sec = 0;
						chomp($read_sec);
						$read_sec = int($read_sec);
					}
				} elsif($config->{os} eq "OpenBSD" || $config->{os} eq "NetBSD") {
					@tmp = split(' ', `iostat -DI | tail -1`);
					($read_cnt, $read_sec) = @tmp;
					$write_cnt = 0;
					$write_sec = 0;
					chomp($read_sec);
					$read_sec = int($read_sec);
				}
			}

			$ioa = ($read_cnt || 0) + ($write_cnt || 0);
			$tim = ($read_sec || 0) + ($write_sec || 0);

			$str = $e . "_ioa" . $n;
			$val = $ioa;
			$ioa = $val - ($config->{fs_hist}->{$str} || 0);
			$ioa = 0 unless $val != $ioa;
			$ioa /= 60;
			$config->{fs_hist}->{$str} = $val;

			$str = $e . "_tim" . $n;
			$val = $tim;
			$tim = $val - ($config->{fs_hist}->{$str} || 0);
			$tim = 0 unless $val != $tim;
			$tim /= 60;
			$config->{fs_hist}->{$str} = $val;

			$rrdata .= ":$use:$ioa:$tim:$ino:0:0:0:0";
		}
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub fs_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $fs = $config->{fs};
	my @rigid = split(',', ($fs->{rigid} || ""));
	my @limit = split(',', ($fs->{limit} || ""));
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
	my $graph_title;
	my $vlabel;
	my @IMG;
	my @IMGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my @riglim;
	my $n;
	my $n2;
	my $e;
	my $e2;
	my $str;
	my $err;
	my @LC = (
		"#FFA500",
		"#44EEEE",
		"#44EE44",
		"#4444EE",
		"#448844",
		"#5F04B4",
		"#EE44EE",
		"#EEEE44",
	);

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
		foreach my $k (sort keys %{$fs->{list}}) {
			my @f = split(',', $fs->{list}->{$k});
			for($n = 0; $n < scalar(@f); $n++) {
				$f[$n] = trim($f[$n]);
				$str = sprintf("%29s", $fs->{desc}->{$f[$n]} || $f[$n]);
				$line1 .= $str;
				$str = sprintf("   Use     I/O    Time Inode ");
				$line2 .= $str;
				$line3 .=      "-----------------------------";
			}
		}
		push(@output, "    $line1\n");
		push(@output, "Time $line2\n");
		push(@output, "-----$line3\n");
		my $line;
		my @row;
		my $time;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			my ($root, $swap) = @$line;
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			$e = 0;
			foreach my $k (sort keys %{$fs->{list}}) {
				my @f = split(',', $fs->{list}->{$k});
				for($n2 = 0; $n2 < scalar(@f); $n2++) {
					$from = ($e * 8 * 8) + ($n2 * 8);
					$to = $from + 8;
					my ($use, $ioa, $tim, $ino) = @$line[$from..$to];
					@row = ($use, $ioa, $tim, $ino);
					push(@output, sprintf(" %4.1f%% %7.1f %7.1f %4.1f%% ", @row));
				}
				$e++;
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

	for($n = 0; $n < keys(%{$fs->{list}}); $n++) {
		for($n2 = 1; $n2 <= 4; $n2++) {
			$str = $u . $package . $n . $n2 . "." . $tf->{when} . ".$imgfmt_lc";
			push(@IMG, $str);
			unlink("$IMG_DIR" . $str);
			if(lc($config->{enable_zoom}) eq "y") {
				$str = $u . $package . $n . $n2 . "z." . $tf->{when} . ".$imgfmt_lc";
				push(@IMGz, $str);
				unlink("$IMG_DIR" . $str);
			}
		}
	}

	$e = $e2 = 0;
	foreach my $k (sort keys %{$fs->{list}}) {
		my @f = split(',', $fs->{list}->{$k});

		if($e) {
			push(@output, "   <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}

		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n2 = 0, $n = 0; $n < 8; $n++) {
			if($f[$n]) {
				$f[$n] = trim($f[$n]);
				my $color;

				$str = $fs->{desc}->{$f[$n]} || $f[$n];
				if($f[$n] eq "/") {
					$color = "#EE4444";
				} elsif($f[$n] eq "swap") {
					$color = "#CCCCCC";
				} elsif($f[$n] eq "/boot") {
					$color = "#666666";
				} else {
					$color = $LC[$n2++];
				}
				push(@tmpz, "LINE2:fs" . $n . $color . ":$str");
				$str = sprintf("%-23s", substr($str, 0, 23));
				push(@tmp, "LINE2:fs" . $n . $color . ":$str");
				push(@tmp, "GPRINT:fs" . $n . ":LAST:Cur\\: %4.1lf%%");
				push(@tmp, "GPRINT:fs" . $n . ":MIN: Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:fs" . $n . ":MAX: Max\\: %4.1lf%%\\n");
			}
		}
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
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
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 4]",
			"--title=$config->{graphs}->{_fs1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:fs0=$rrd:fs" . $e . "_use0:AVERAGE",
			"DEF:fs1=$rrd:fs" . $e . "_use1:AVERAGE",
			"DEF:fs2=$rrd:fs" . $e . "_use2:AVERAGE",
			"DEF:fs3=$rrd:fs" . $e . "_use3:AVERAGE",
			"DEF:fs4=$rrd:fs" . $e . "_use4:AVERAGE",
			"DEF:fs5=$rrd:fs" . $e . "_use5:AVERAGE",
			"DEF:fs6=$rrd:fs" . $e . "_use6:AVERAGE",
			"DEF:fs7=$rrd:fs" . $e . "_use7:AVERAGE",
			"CDEF:allvalues=fs0,fs1,fs2,fs3,fs4,fs5,fs6,fs7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4]",
				"--title=$config->{graphs}->{_fs1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Percent (%)",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:fs0=$rrd:fs" . $e . "_use0:AVERAGE",
				"DEF:fs1=$rrd:fs" . $e . "_use1:AVERAGE",
				"DEF:fs2=$rrd:fs" . $e . "_use2:AVERAGE",
				"DEF:fs3=$rrd:fs" . $e . "_use3:AVERAGE",
				"DEF:fs4=$rrd:fs" . $e . "_use4:AVERAGE",
				"DEF:fs5=$rrd:fs" . $e . "_use5:AVERAGE",
				"DEF:fs6=$rrd:fs" . $e . "_use6:AVERAGE",
				"DEF:fs7=$rrd:fs" . $e . "_use7:AVERAGE",
				"CDEF:allvalues=fs0,fs1,fs2,fs3,fs4,fs5,fs6,fs7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4]: $err\n") if $err;
		}
		$e2 = $e . "1";
		if($title || ($silent =~ /imagetag/ && $graph =~ /fs$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}
		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n2 = 0, $n = 0; $n < 8; $n++) {
			if($f[$n]) {
				$f[$n] = trim($f[$n]);
				my $color;

				$str = $fs->{desc}->{$f[$n]} || $f[$n];
				if($f[$n] eq "/") {
					$color = "#EE4444";
				} elsif($f[$n] eq "swap") {
					$color = "#CCCCCC";
				} elsif($f[$n] eq "/boot") {
					$color = "#666666";
				} else {
					$color = $LC[$n2++];
				}
				push(@tmpz, "LINE2:ioa" . $n . $color . ":$str");
				$str = sprintf("%-23s", substr($str, 0, 23));
				push(@tmp, "LINE2:ioa" . $n . $color . ":$str");
				push(@tmp, "GPRINT:ioa" . $n . ":LAST:Cur\\: %4.0lf");
				push(@tmp, "GPRINT:ioa" . $n . ":MIN: Min\\: %4.0lf");
				push(@tmp, "GPRINT:ioa" . $n . ":MAX: Max\\: %4.0lf\\n");
			}
		}
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
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 4 + 1]",
			"--title=$config->{graphs}->{_fs2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Reads+Writes/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:ioa0=$rrd:fs" . $e . "_ioa0:AVERAGE",
			"DEF:ioa1=$rrd:fs" . $e . "_ioa1:AVERAGE",
			"DEF:ioa2=$rrd:fs" . $e . "_ioa2:AVERAGE",
			"DEF:ioa3=$rrd:fs" . $e . "_ioa3:AVERAGE",
			"DEF:ioa4=$rrd:fs" . $e . "_ioa4:AVERAGE",
			"DEF:ioa5=$rrd:fs" . $e . "_ioa5:AVERAGE",
			"DEF:ioa6=$rrd:fs" . $e . "_ioa6:AVERAGE",
			"DEF:ioa7=$rrd:fs" . $e . "_ioa7:AVERAGE",
			"CDEF:allvalues=ioa0,ioa1,ioa2,ioa3,ioa4,ioa5,ioa6,ioa7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4 + 1]",
				"--title=$config->{graphs}->{_fs2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Reads+Writes/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:ioa0=$rrd:fs" . $e . "_ioa0:AVERAGE",
				"DEF:ioa1=$rrd:fs" . $e . "_ioa1:AVERAGE",
				"DEF:ioa2=$rrd:fs" . $e . "_ioa2:AVERAGE",
				"DEF:ioa3=$rrd:fs" . $e . "_ioa3:AVERAGE",
				"DEF:ioa4=$rrd:fs" . $e . "_ioa4:AVERAGE",
				"DEF:ioa5=$rrd:fs" . $e . "_ioa5:AVERAGE",
				"DEF:ioa6=$rrd:fs" . $e . "_ioa6:AVERAGE",
				"DEF:ioa7=$rrd:fs" . $e . "_ioa7:AVERAGE",
				"CDEF:allvalues=ioa0,ioa1,ioa2,ioa3,ioa4,ioa5,ioa6,ioa7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4 + 1]: $err\n") if $err;
		}
		$e2 = $e . "2";
		if($title || ($silent =~ /imagetag/ && $graph =~ /fs$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 1] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n2 = 0, $n = 0; $n < 8; $n++) {
			if($f[$n]) {
				$f[$n] = trim($f[$n]);
				my $color;

				$str = $fs->{desc}->{$f[$n]} || $f[$n];
				if($f[$n] eq "/") {
					$color = "#EE4444";
				} elsif($f[$n] eq "swap") {
					$color = "#CCCCCC";
				} elsif($f[$n] eq "/boot") {
					$color = "#666666";
				} else {
					$color = $LC[$n2++];
				}
				push(@tmpz, "LINE2:fs" . $n . $color . ":$str");
				$str = sprintf("%-23s", substr($str, 0, 23));
				push(@tmp, "LINE2:fs" . $n . $color . ":$str");
				push(@tmp, "GPRINT:fs" . $n . ":LAST:Cur\\: %4.1lf%%");
				push(@tmp, "GPRINT:fs" . $n . ":MIN: Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:fs" . $n . ":MAX: Max\\: %4.1lf%%\\n");
			}
		}
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
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
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 4 + 2]",
			"--title=$config->{graphs}->{_fs3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:fs0=$rrd:fs" . $e . "_ino0:AVERAGE",
			"DEF:fs1=$rrd:fs" . $e . "_ino1:AVERAGE",
			"DEF:fs2=$rrd:fs" . $e . "_ino2:AVERAGE",
			"DEF:fs3=$rrd:fs" . $e . "_ino3:AVERAGE",
			"DEF:fs4=$rrd:fs" . $e . "_ino4:AVERAGE",
			"DEF:fs5=$rrd:fs" . $e . "_ino5:AVERAGE",
			"DEF:fs6=$rrd:fs" . $e . "_ino6:AVERAGE",
			"DEF:fs7=$rrd:fs" . $e . "_ino7:AVERAGE",
			"CDEF:allvalues=fs0,fs1,fs2,fs3,fs4,fs5,fs6,fs7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4 + 2]",
				"--title=$config->{graphs}->{_fs3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Percent (%)",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:fs0=$rrd:fs" . $e . "_ino0:AVERAGE",
				"DEF:fs1=$rrd:fs" . $e . "_ino1:AVERAGE",
				"DEF:fs2=$rrd:fs" . $e . "_ino2:AVERAGE",
				"DEF:fs3=$rrd:fs" . $e . "_ino3:AVERAGE",
				"DEF:fs4=$rrd:fs" . $e . "_ino4:AVERAGE",
				"DEF:fs5=$rrd:fs" . $e . "_ino5:AVERAGE",
				"DEF:fs6=$rrd:fs" . $e . "_ino6:AVERAGE",
				"DEF:fs7=$rrd:fs" . $e . "_ino7:AVERAGE",
				"CDEF:allvalues=fs0,fs1,fs2,fs3,fs4,fs5,fs6,fs7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4 + 2]: $err\n") if $err;
		}
		$e2 = $e . "3";
		if($title || ($silent =~ /imagetag/ && $graph =~ /fs$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 2] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}
		@riglim = @{setup_riglim($rigid[3], $limit[3])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		if($config->{os} eq "Linux") {
			if($config->{kernel} gt "2.4") {
	   			$graph_title = "$config->{graphs}->{_fs4}  ($tf->{nwhen}$tf->{twhen})";
				$vlabel = "Milliseconds";
			} else {
	   			$graph_title = "Disk sectors activity  ($tf->{nwhen}$tf->{twhen})";
				$vlabel = "Sectors/s";
			}
			for($n2 = 0, $n = 0; $n < 8; $n++) {
				if($f[$n]) {
					$f[$n] = trim($f[$n]);
					my $color;
	
					$str = $fs->{desc}->{$f[$n]} || $f[$n];
					if($f[$n] eq "/") {
						$color = "#EE4444";
					} elsif($f[$n] eq "swap") {
						$color = "#CCCCCC";
					} elsif($f[$n] eq "/boot") {
						$color = "#666666";
					} else {
						$color = $LC[$n2++];
					}
					push(@tmpz, "LINE2:tim" . $n . $color . ":$str");
					$str = sprintf("%-23s", substr($str, 0, 23));
					push(@tmp, "LINE2:tim" . $n . $color . ":$str");
					push(@tmp, "GPRINT:stim" . $n . ":LAST:Cur\\: %4.1lfs");
					push(@tmp, "GPRINT:stim" . $n . ":MIN:Min\\: %4.1lfs");
					push(@tmp, "GPRINT:stim" . $n . ":MAX:Max\\: %4.1lfs\\n");
				}
			}
		} elsif(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
	   		$graph_title = "Disk data activity  ($tf->{nwhen}$tf->{twhen})";
			$vlabel = "KB/s";
			for($n2 = 0, $n = 0; $n < 8; $n++) {
				if($f[$n]) {
					$f[$n] = trim($f[$n]);
					my $color;
	
					$str = $fs->{desc}->{$f[$n]} || $f[$n];
					if($f[$n] eq "/") {
						$color = "#EE4444";
					} elsif($f[$n] eq "swap") {
						$color = "#CCCCCC";
					} elsif($f[$n] eq "/boot") {
						$color = "#666666";
					} else {
						$color = $LC[$n2++];
					}
					push(@tmpz, "LINE2:tim" . $n . $color . ":$str");
					$str = sprintf("%-23s", substr($str, 0, 23));
					push(@tmp, "LINE2:tim" . $n . $color . ":$str");
					push(@tmp, "GPRINT:tim" . $n . ":LAST:Cur\\: %4.0lf");
					push(@tmp, "GPRINT:tim" . $n . ":MIN: Min\\: %4.0lf");
					push(@tmp, "GPRINT:tim" . $n . ":MAX: Max\\: %4.0lf\\n");
				}
			}
		}
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
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 4 + 3]",
			"--title=$graph_title",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:tim0=$rrd:fs" . $e . "_tim0:AVERAGE",
			"DEF:tim1=$rrd:fs" . $e . "_tim1:AVERAGE",
			"DEF:tim2=$rrd:fs" . $e . "_tim2:AVERAGE",
			"DEF:tim3=$rrd:fs" . $e . "_tim3:AVERAGE",
			"DEF:tim4=$rrd:fs" . $e . "_tim4:AVERAGE",
			"DEF:tim5=$rrd:fs" . $e . "_tim5:AVERAGE",
			"DEF:tim6=$rrd:fs" . $e . "_tim6:AVERAGE",
			"DEF:tim7=$rrd:fs" . $e . "_tim7:AVERAGE",
			"CDEF:allvalues=tim0,tim1,tim2,tim3,tim4,tim5,tim6,tim7,+,+,+,+,+,+,+",
			"CDEF:stim0=tim0,1000,/",
			"CDEF:stim1=tim1,1000,/",
			"CDEF:stim2=tim2,1000,/",
			"CDEF:stim3=tim3,1000,/",
			"CDEF:stim4=tim4,1000,/",
			"CDEF:stim5=tim5,1000,/",
			"CDEF:stim6=tim6,1000,/",
			"CDEF:stim7=tim7,1000,/",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4 + 3]",
				"--title=$graph_title",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:tim0=$rrd:fs" . $e . "_tim0:AVERAGE",
				"DEF:tim1=$rrd:fs" . $e . "_tim1:AVERAGE",
				"DEF:tim2=$rrd:fs" . $e . "_tim2:AVERAGE",
				"DEF:tim3=$rrd:fs" . $e . "_tim3:AVERAGE",
				"DEF:tim4=$rrd:fs" . $e . "_tim4:AVERAGE",
				"DEF:tim5=$rrd:fs" . $e . "_tim5:AVERAGE",
				"DEF:tim6=$rrd:fs" . $e . "_tim6:AVERAGE",
				"DEF:tim7=$rrd:fs" . $e . "_tim7:AVERAGE",
				"CDEF:allvalues=tim0,tim1,tim2,tim3,tim4,tim5,tim6,tim7,+,+,+,+,+,+,+",
				"CDEF:stim0=tim0,1000,/",
				"CDEF:stim1=tim1,1000,/",
				"CDEF:stim2=tim2,1000,/",
				"CDEF:stim3=tim3,1000,/",
				"CDEF:stim4=tim4,1000,/",
				"CDEF:stim5=tim5,1000,/",
				"CDEF:stim6=tim6,1000,/",
				"CDEF:stim7=tim7,1000,/",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4 + 3]: $err\n") if $err;
		}
		$e2 = $e . "4";
		if($title || ($silent =~ /imagetag/ && $graph =~ /fs$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 3] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");
			push(@output, main::graph_footer());
		}
		$e++;
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
