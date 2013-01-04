#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2013 by Jordi Sanfeliu <jordi@fibranet.cat>
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
		my $d;
		foreach my $f (@fsl) {
			undef($d);
			$f = trim($f);
			$d = $fs->{devmap}->{$f} if $fs->{devmap}->{$f};
			next unless !$d;

			if($f ne "swap") {
				eval {
					alarm $config->{timeout};
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

			if($config->{os} eq "Linux" && $config->{kernel} > 2.4) {
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

			my $f = trim($fsl[$n]) || "";
			if($f && $f eq "swap") {
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
					if(!$config->{alert_rootfs_threshold} || $use < $config->{alert_rootfs_threshold}) {
						$config->{fs_hist}->{rootalert} = 0;
					} else {
						if(!$config->{fs_hist}->{rootalert}) {
							$config->{fs_hist}->{rootalert} = time;
						}
						if($config->{fs_hist}->{rootalert} > 0 && (time - $config->{fs_hist}->{rootalert}) > $config->{alert_rootfs_timeintvl}) {
							if(-x $config->{alert_rootfs_script}) {
								system($config->{alert_rootfs_script} . " " . $config->{alert_rootfs_timeintvl} . " " . $config->{alert_rootfs_threshold} . " " . $use);
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

sub fs_cgi {
	my ($package, $config, $cgi) = @_;

	my $fs = $config->{fs};
	my @rigid = split(',', $fs->{rigid});
	my @limit = split(',', $fs->{limit});
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};

	my $u = "";
	my $width;
	my $height;
	my $graph_title;
	my $vlabel;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
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

	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	$title = !$silent ? $title : "";


	# text mode
	#
	if(lc($config->{iface_mode}) eq "text") {
		if($title) {
			main::graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$colors->{title_bg_color}'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"AVERAGE",
			"-r $tf->{res}");
		$err = RRDs::error;
		print("ERROR: while fetching $rrd: $err\n") if $err;
		my $line1;
		my $line2;
		my $line3;
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		foreach my $k (sort keys %{$fs->{list}}) {
			my @f = split(',', $fs->{list}->{$k});
			for($n = 0; $n < scalar(@f); $n++) {
				$str = sprintf("%23s", $fs->{desc}->{$f[$n]} || trim($f[$n]));
				$line1 .= $str;
				$str = sprintf("   Use     I/O    Time ");
				$line2 .= $str;
				$line3 .=      "-----------------------";
			}
		}
		print("    $line1\n");
		print("Time $line2\n");
		print("-----$line3\n");
		my $line;
		my @row;
		my $time;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			my ($root, $swap) = @$line;
			printf(" %2d$tf->{tc} ", $time);
			$e = 0;
			foreach my $k (sort keys %{$fs->{list}}) {
				my @f = split(',', $fs->{list}->{$k});
				for($n2 = 0; $n2 < scalar(@f); $n2++) {
					$from = ($e * 8 * 3) + ($n2 * 3);
					$to = $from + 3;
					my ($use, $ioa, $tim) = @$line[$from..$to];
					@row = ($use, $ioa, $tim);
					printf(" %4.1f%% %7.1f %7.1f ", @row);
				}
				$e++;
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			main::graph_footer();
		}
		print("  <br>\n");
		return;
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
		for($n2 = 1; $n2 <= 8; $n2++) {
			$str = $u . $package . $n . $n2 . "." . $tf->{when} . ".png";
			push(@PNG, $str);
			unlink("$PNG_DIR" . $str);
			if(lc($config->{enable_zoom}) eq "y") {
				$str = $u . $package . $n . $n2 . "z." . $tf->{when} . ".png";
				push(@PNGz, $str);
				unlink("$PNG_DIR" . $str);
			}
		}
	}

	$e = 0;
	foreach my $k (sort keys %{$fs->{list}}) {
		my @f = split(',', $fs->{list}->{$k});

		if($e) {
			print("   <br>\n");
		}
		if($title) {
			main::graph_header($title, 2);
		}

		undef(@riglim);
		if(trim($rigid[0]) eq 1) {
			push(@riglim, "--upper-limit=" . trim($limit[0]));
		} else {
			if(trim($rigid[0]) eq 2) {
				push(@riglim, "--upper-limit=" . trim($limit[0]));
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "COMMENT: \\n");
		for($n = 0; $n < 8; $n++) {
			if($f[$n]) {
				my $color;

				$str = $fs->{desc}->{$f[$n]} || trim($f[$n]);
				if(trim($f[$n]) eq "/") {
					$color = "#EE4444";
				} elsif($str eq "swap") {
					$color = "#CCCCCC";
				} elsif($str eq "/boot") {
					$color = "#666666";
				} else {
					$color = $LC[$n];
				}
				push(@tmpz, "LINE2:fs" . $n . $color . ":$str");
				$str = sprintf("%-23s", $str);
				push(@tmp, "LINE2:fs" . $n . $color . ":$str");
				push(@tmp, "GPRINT:fs" . $n . ":LAST:Cur\\: %4.1lf%%");
				push(@tmp, "GPRINT:fs" . $n . ":AVERAGE:   Avg\\: %4.1lf%%");
				push(@tmp, "GPRINT:fs" . $n . ":MIN:   Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:fs" . $n . ":MAX:   Max\\: %4.1lf%%\\n");
			}
		}
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		if(scalar(@f) && (scalar(@f) % 2)) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='$colors->{title_bg_color}'>\n");
		}
		($width, $height) = split('x', $config->{graph_size}->{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3]",
			"--title=$config->{graphs}->{_fs1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			"--upper-limit=100",
			@riglim,
			"--lower-limit=0",
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
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3]",
				"--title=$config->{graphs}->{_fs1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=Percent (%)",
				"--width=$width",
				"--height=$height",
				"--upper-limit=100",
				@riglim,
				"--lower-limit=0",
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
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /fs$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3] . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
		}
		undef(@riglim);
		if(trim($rigid[1]) eq 1) {
			push(@riglim, "--upper-limit=" . trim($limit[1]));
		} else {
			if(trim($rigid[1]) eq 2) {
				push(@riglim, "--upper-limit=" . trim($limit[1]));
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 8; $n += 2) {
			my $color;
			if($f[$n]) {
				$str = $fs->{desc}->{$f[$n]} || trim($f[$n]);
				if(trim($f[$n]) eq "/") {
					$color = "#EE4444";
				} elsif($str eq "swap") {
					$color = "#CCCCCC";
				} elsif($str eq "/boot") {
					$color = "#666666";
				} else {
					$color = $LC[$n];
				}
				push(@tmpz, "LINE2:ioa" . $n . $color . ":$str\\g");
				$str = sprintf("%-17s", substr($str, 0, 17));
				push(@tmp, "LINE2:ioa" . $n . $color . ":$str");
			}
			if($f[$n + 1]) {
				$str = $fs->{desc}->{$f[$n + 1]} || trim($f[$n + 1]);
				if(trim($f[$n + 1]) eq "/") {
					$color = "#EE4444";
				} elsif($str eq "swap") {
					$color = "#CCCCCC";
				} elsif($str eq "/boot") {
					$color = "#666666";
				} else {
					$color = $LC[$n + 1];
				}
				push(@tmpz, "LINE2:ioa" . ($n + 1) . $color . ":$str\\g");
				$str = sprintf("%-17s", substr($str, 0, 17));
				push(@tmp, "LINE2:ioa" . ($n + 1) . $color . ":$str\\n");
			}
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
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 1]",
			"--title=$config->{graphs}->{_fs2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Reads+Writes/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:ioa0=$rrd:fs" . $e . "_ioa0:AVERAGE",
			"DEF:ioa1=$rrd:fs" . $e . "_ioa1:AVERAGE",
			"DEF:ioa2=$rrd:fs" . $e . "_ioa2:AVERAGE",
			"DEF:ioa3=$rrd:fs" . $e . "_ioa3:AVERAGE",
			"DEF:ioa4=$rrd:fs" . $e . "_ioa4:AVERAGE",
			"DEF:ioa5=$rrd:fs" . $e . "_ioa5:AVERAGE",
			"DEF:ioa6=$rrd:fs" . $e . "_ioa6:AVERAGE",
			"DEF:ioa7=$rrd:fs" . $e . "_ioa7:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 1]",
				"--title=$config->{graphs}->{_fs2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=Reads+Writes/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:ioa0=$rrd:fs" . $e . "_ioa0:AVERAGE",
				"DEF:ioa1=$rrd:fs" . $e . "_ioa1:AVERAGE",
				"DEF:ioa2=$rrd:fs" . $e . "_ioa2:AVERAGE",
				"DEF:ioa3=$rrd:fs" . $e . "_ioa3:AVERAGE",
				"DEF:ioa4=$rrd:fs" . $e . "_ioa4:AVERAGE",
				"DEF:ioa5=$rrd:fs" . $e . "_ioa5:AVERAGE",
				"DEF:ioa6=$rrd:fs" . $e . "_ioa6:AVERAGE",
				"DEF:ioa7=$rrd:fs" . $e . "_ioa7:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /fs$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3 + 1] . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3 + 1] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 1] . "'>\n");
			}
		}

		undef(@riglim);
		if(trim($rigid[2]) eq 1) {
			push(@riglim, "--upper-limit=" . trim($limit[2]));
		} else {
			if(trim($rigid[2]) eq 2) {
				push(@riglim, "--upper-limit=" . trim($limit[2]));
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		if($config->{os} eq "Linux") {
			if($config->{kernel} > 2.4) {
	   			$graph_title = "$config->{graphs}->{_fs3}  ($tf->{nwhen}$tf->{twhen})";
				$vlabel = "Milliseconds";
			} else {
	   			$graph_title = "Disk sectors activity  ($tf->{nwhen}$tf->{twhen})";
				$vlabel = "Sectors/s";
			}
			for($n = 0; $n < 8; $n += 2) {
				my $color;
				if($f[$n]) {
					$str = $fs->{desc}->{$f[$n]} || trim($f[$n]);
					if(trim($f[$n]) eq "/") {
						$color = "#EE4444";
					} elsif($str eq "swap") {
						$color = "#CCCCCC";
					} elsif($str eq "/boot") {
						$color = "#666666";
					} else {
						$color = $LC[$n];
					}
					push(@tmpz, "LINE2:tim" . $n . $color . ":$str\\g");
					$str = sprintf("%-17s", substr($str, 0, 17));
					push(@tmp, "LINE2:tim" . $n . $color . ":$str");
				}
				if($f[$n + 1]) {
					$str = $fs->{desc}->{$f[$n + 1]} || trim($f[$n + 1]);
					if(trim($f[$n + 1]) eq "/") {
						$color = "#EE4444";
					} elsif($str eq "swap") {
						$color = "#CCCCCC";
					} elsif($str eq "/boot") {
						$color = "#666666";
					} else {
						$color = $LC[$n + 1];
					}
					push(@tmpz, "LINE2:tim" . ($n + 1) . $color . ":$str\\g");
					$str = sprintf("%-17s", substr($str, 0, 17));
					push(@tmp, "LINE2:tim" . ($n + 1) . $color . ":$str\\n");
				}
			}
		} elsif(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
	   		$graph_title = "Disk data activity  ($tf->{nwhen}$tf->{twhen})";
			$vlabel = "KB/s";
			for($n = 0; $n < 8; $n += 2) {
				my $color;
				my $str2;

				$str2 = $fs->{desc}->{$f[$n]} || trim($f[$n]);
				if($f[$n]) {
					$str = sprintf("%-17s", $str2, 0, 17);
					if(trim($f[$n]) eq "/") {
						$color = "#EE4444";
					} elsif($str eq "swap") {
						$color = "#CCCCCC";
					} elsif($str eq "/boot") {
						$color = "#666666";
					} else {
						$color = $LC[$n];
					}
					push(@tmp, "LINE2:tim" . $n . $color . ":$str");
					push(@tmpz, "LINE2:tim" . $n . $color . ":$f[$n]\\g");
				}
				$str2 = $fs->{desc}->{$f[$n + 1]} || trim($f[$n + 1]);
				if($f[$n + 1]) {
					$str = sprintf("%-17s", $str2, 0, 17);
					if(trim($f[$n + 1]) eq "/") {
						$color = "#EE4444";
					} elsif($str eq "swap") {
						$color = "#CCCCCC";
					} elsif($str eq "/boot") {
						$color = "#666666";
					} else {
						$color = $LC[$n + 1];
					}
					push(@tmp, "LINE2:tim" . ($n + 1) . $color . ":$str\\n");
					push(@tmpz, "LINE2:tim" . ($n + 1) . $color . ":$f[$n + 1]\\g");
				}
			}
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
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 2]",
			"--title=$graph_title",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:tim0=$rrd:fs" . $e . "_tim0:AVERAGE",
			"DEF:tim1=$rrd:fs" . $e . "_tim1:AVERAGE",
			"DEF:tim2=$rrd:fs" . $e . "_tim2:AVERAGE",
			"DEF:tim3=$rrd:fs" . $e . "_tim3:AVERAGE",
			"DEF:tim4=$rrd:fs" . $e . "_tim4:AVERAGE",
			"DEF:tim5=$rrd:fs" . $e . "_tim5:AVERAGE",
			"DEF:tim6=$rrd:fs" . $e . "_tim6:AVERAGE",
			"DEF:tim7=$rrd:fs" . $e . "_tim7:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 2]",
				"--title=$graph_title",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:tim0=$rrd:fs" . $e . "_tim0:AVERAGE",
				"DEF:tim1=$rrd:fs" . $e . "_tim1:AVERAGE",
				"DEF:tim2=$rrd:fs" . $e . "_tim2:AVERAGE",
				"DEF:tim3=$rrd:fs" . $e . "_tim3:AVERAGE",
				"DEF:tim4=$rrd:fs" . $e . "_tim4:AVERAGE",
				"DEF:tim5=$rrd:fs" . $e . "_tim5:AVERAGE",
				"DEF:tim6=$rrd:fs" . $e . "_tim6:AVERAGE",
				"DEF:tim7=$rrd:fs" . $e . "_tim7:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /fs$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3 + 2] . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3 + 2] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 2] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			main::graph_footer();
		}
		$e++;
	}
	print("  <br>\n");
	return;
}

1;
