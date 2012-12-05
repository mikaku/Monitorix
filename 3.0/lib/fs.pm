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

package fs;

#use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(fs_init fs_update fs_cgi);

sub fs_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $fs = $config->{fs};

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
		if(scalar(@ds) / 24 != keys(%{$fs->{list}})) {
			logger("Detected size mismatch between <list>...</list> (" . keys(%{$fs->{list}}) . ") and $rrd (" . scalar(@ds) / 24 . "). Resizing it accordingly. All historic data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
	}

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
		for($n = 0; $n < keys(%{$fs->{list}}); $n++) {
			push(@tmp, "DS:fs" . $n . "_use0:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa0:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim0:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use1:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa1:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim1:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use2:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa2:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim2:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use3:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa3:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim3:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use4:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa4:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim4:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use5:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa5:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim5:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use6:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa6:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim6:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_use7:GAUGE:120:0:100");
			push(@tmp, "DS:fs" . $n . "_ioa7:GAUGE:120:0:U");
			push(@tmp, "DS:fs" . $n . "_tim7:GAUGE:120:0:U");
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

	# This tries to find out the physical device name of each fs.
	foreach my $k (sort keys %{$fs->{list}}) {
		my @fsl = split(',', $fs->{list}->{$k});
		foreach my $f (@$fsl) {
			my $d = $fs->{devmap}->{$fs} if $fs->{devmap}->{$fs};
			next unless !$d;

			if($f ne "swap") {
				eval {
					alarm $TIMEOUT;
					open(IN, "df -P $f |");
					while(<IN>) {
						if(/ $f$/) {
							($d) = split(' ', $_);
							last;
						}
					}
					close(IN);
					alarm 0;
					chomp($d);
				};
			}

			if($os eq "Linux" && $kernel_branch > 2.4) {
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
					$link = readlink($d);
					$d = abs_path(dirname($d) . "/" . $link);
					chomp($d);
				}

				# get the major and minor of $d
				my $rdev = (stat($d))[6];
				my $minor = $rdev % 256;
				my $major = int($rdev / 256);

				# do exists in /proc/diskstats?
				if($found = is_in_diskstats($d, $major, $minor)) {
					$d = $found;
					$fs->{devmap}->{$f} = $d;
					logger("$myself: Detected physical device name for $f in '$d'.") unless !$opt_d;
					next;
				}

				logger("$myself: Unable to find major/minor in /proc/diskstats.") unless !$opt_d;

				# check if device is using EVMS <http://evms.sourceforge.net/>
				if($d =~ m/\/dev\/evms\//) {
					$d = `evms_query disks $d`;
					if($found = is_in_diskstats($d)) {
						$d = $found;
						$fs->{devmap}->{$f} = $d;
						logger("$myself: Detected physical device name for $f in '$d'.") unless !$opt_d;
						next;
					}
				}

				$d =~ s/^.*dev\///;	# remove the /dev/ prefix
				$d =~ s/^.*mapper\///;	# remove the mapper/ prefix

				# check if the device is under a crypt LUKS (encrypted fs)
				if($dev = is_luks($d)) {
					$d = $dev;
				}

				# do exists in /proc/diskstats?
				if($found = is_in_diskstats($d)) {
					$d = $found;
					$fs->{devmap}->{$f} = $d;
					logger("$myself: Detected physical device name for $f in '$d'.") unless !$opt_d;
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
			} elsif($os eq "FreeBSD" || $os eq "OpenBSD" || $os eq "NetBSD") {
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
			logger("$myself: Detected physical device name for $f in '$d'.") unless !$opt_d;
		}
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

			my $used = 0;
			my $free = 0;

			$f = trim($fsl[$n]);	FIX ME !!!!
			if($f eq "swap") {
				if($config->{os} eq "Linux") {
					open(IN, "free |");
					while(<IN>) {
						if(/^Swap:\s+\d+\s+(\d+)\s+(\d+)$/) {
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
				} elsif($config->{os} eq "OpenBSD" || $os eq "NetBSD") {
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
				eval {
					alarm $config->{timeout};
					open(IN, "df -P $f |");
					while(<IN>) {
						if(/ $f$/) {
							@tmp = split(' ', $_);
							last;
						}
					}
					close(IN);
					alarm 0;
				};
				(undef, undef, $used, $free) = @tmp;
				chomp($used, $free);
				$use = ($used * 100) / ($used + $free);

				# FS alert
				if($f eq "/" && lc($config->{enable_alerts}) eq "y") {
					if(!$config->{alert_rootfs_threshold} || $pcnt < $config->{alert_rootfs_threshold}) {
						$config->{fs_hist}->{rootalert} = 0;
					} else {
						if(!$config->{fs_hist}->{rootalert}) {
							$config->{fs_hist}->{rootalert} = time;
						}
						if($config->{fs_hist}->{rootalert} > 0 && (time - $config->{fs_hist}->{rootalert}) > $config->{alert_rootfs_timeintvl}) {
							if(-x $config->{alert_rootfs_script}) {
								system($config->{alert_rootfs_script} . " " . $config->{alert_rootfs_timeintvl} . " " . $config->{alert_rootfs_threshold} . " " . $pcnt);
							}
							$config->{fs_hist}->{rootalert} = time;
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
				if($config->{kernel} > 2.4) {
					open(IN, "/proc/diskstats");
					while(<IN>) {
						if(/ $d /) {
							@tmp = split(' ', $_);
							last;
						}
					}
					close(IN);
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
				@tmp = split(' ', `iostat -xI $d | grep -w $d`);
				if(@tmp) {
					(undef, $read_cnt, $write_cnt, $read_sec, $write_sec) = @tmp;
					$read_cnt = int($read_cnt);
					$write_cnt = int($write_cnt);
					$read_sec = int($read_sec);
					$write_sec = int($write_sec);
				} else {
					@tmp = split(' ', `iostat -dI | tail -1`);
					(undef, $read_cnt, $read_sec) = @tmp;
					$write_cnt = "";
					$write_sec = "";
					chomp($read_sec);
					$read_sec = int($read_sec);
				}
			} elsif($config->{os} eq "OpenBSD" || $config->{os} eq "NetBSD") {
				@tmp = split(' ', `iostat -DI | tail -1`);
				($read_cnt, $read_sec) = @tmp;
				$write_cnt = "";
				$write_sec = "";
				chomp($read_sec);
				$read_sec = int($read_sec);
			}
			}

			$ioa = $read_cnt + $write_cnt;
			$tim = $read_sec + $write_sec;

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

			$rrdata .= ":$use:$ioa:$tim";
		}
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}
