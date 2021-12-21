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

package libvirt;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(libvirt_init libvirt_update libvirt_cgi);

sub libvirt_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $libvirt = $config->{libvirt};

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

		if(scalar(@ds) / 64 != keys(%{$libvirt->{list}})) {
			logger("$myself: Detected size mismatch between <list>...</list> (" . keys(%{$libvirt->{list}}) . ") and $rrd (" . scalar(@ds) / 64 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < keys(%{$libvirt->{list}}); $n++) {
			my $n2;
			for($n2 = 0; $n2 < 8; $n2++) {
				push(@tmp, "DS:libv" . $n . "_cpu" . $n2 . ":GAUGE:120:0:100");
				push(@tmp, "DS:libv" . $n . "_mem" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:libv" . $n . "_dsk" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:libv" . $n . "_net" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:libv" . $n . "_va1" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:libv" . $n . "_va2" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:libv" . $n . "_va3" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:libv" . $n . "_va4" . $n2 . ":GAUGE:120:0:U");
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

	# check for missing options
	if(!$libvirt->{cmd}) {
		logger("$myself: WARNING: the 'cmd' option doesn't exist. Please consider upgrading your configuration file.");
		$libvirt->{cmd} = "virsh";
	}

	$config->{libvirt_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub libvirt_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $libvirt = $config->{libvirt};

	my $n;
	my $rrdata = "N";

	my $e = 0;
	foreach my $vmg (sort keys %{$libvirt->{list}}) {
		my @lvl = split(',', $libvirt->{list}->{$vmg});
		for($n = 0; $n < 8; $n++) {
			my $cpu = 0;
			my $mem = 0;
			my $dsk = 0;
			my $net = 0;

			my $str;
			my $state = "";
			my $vm = trim($lvl[$n] || "");

			my @vda;
			my @vmac;

			# convert from old configuration to new
			if(ref($libvirt->{desc}->{$vm} || "") ne "HASH") {
				my $val;

				$val = trim((split(',', $libvirt->{desc}->{$vm} || ""))[1]);
				push(@vda, $val) if $val;
				$val = trim((split(',', $libvirt->{desc}->{$vm} || ""))[2]);
				push(@vmac, $val) if $val;
			} else {
				@vda = split(',', $libvirt->{desc}->{$vm}->{disk} || "");
				@vmac = split(',', $libvirt->{desc}->{$vm}->{net} || "");
			}

			my $vnet = "";

			if($vm && (!scalar(@vda) || !scalar(@vmac))) {
				logger("$myself: missing parameters in '$vm' virtual machine.");
				$vm = "";	# invalidates this vm
			}

			# check first if that 'vm' is running
			if($vm && open(IN, "$libvirt->{cmd} domstate $vm |")) {
				$state = trim(<IN>);
				close(IN);
			}

			if($state eq "running") {
				my $t;

				if(open(IN, "$libvirt->{cmd} cpu-stats $vm --total |")) {
					my $c = 0;
					while(<IN>) {
						if(/^\s+cpu_time\s+(\d+\.\d+) seconds$/) {
							$c = $1;
						}
					}
					close(IN);
					$str = $e . "_cpu" . $n;
					$cpu = $c - ($config->{libvirt_hist}->{$str} || 0);
					$cpu = 0 unless $c != $cpu;
					$cpu = $cpu * 100 / 60;
					$cpu = $cpu > 100 ? 100 : $cpu;
					$config->{libvirt_hist}->{$str} = $c;
				}
				if(open(IN, "$libvirt->{cmd} dommemstat $vm |")) {
					while(<IN>) {
						if(/^rss\s+(\d+)$/) {
							$mem = $1 * 1024;
						}
					}
					close(IN);
				}

				# summarizes all virtual disks stats for each 'vm'
				$t = 0;
				foreach my $vd (@vda) {
					$vd = trim($vd);
					if(open(IN, "$libvirt->{cmd} domblkstat $vm $vd |")) {
						my $r = 0;
						my $w = 0;
						while(<IN>) {
							if(/^$vd\s+rd_bytes\s+(\d+)$/) {
								$r = $1;
							}
							if(/^$vd\s+wr_bytes\s+(\d+)$/) {
								$w = $1;
								last;
							}
						}
						close(IN);
						$t += ($r + $w);
					}
				}
				$str = $e . "_dsk" . $n;
				$dsk = $t - ($config->{libvirt_hist}->{$str} || 0);
				$dsk = 0 unless $t != $dsk;
				$dsk /= 60;
				$config->{libvirt_hist}->{$str} = $t;

				# summarizes all virtual network stats for each 'vm'
				$t = 0;
				foreach my $vn (@vmac) {
					$vn = trim($vn);
					if(open(IN, "$libvirt->{cmd} domiflist $vm |")) {
						while(<IN>) {
							if(/^\s*(\S+)\s+.*?\s+$vn$/) {
								$vnet = $1;
							}
						}
						close(IN);
					}
					if(!$vnet) {
						logger("$myself: invalid MAC address '$vn' in '$vm'.");
						next;
					}

					if(open(IN, "$libvirt->{cmd} domifstat $vm $vnet |")) {
						my $r = 0;
						my $w = 0;
						while(<IN>) {
							if(/^$vnet\s+rx_bytes\s+(\d+)$/) {
								$r = $1;
							}
							if(/^$vnet\s+tx_bytes\s+(\d+)$/) {
								$w = $1;
								last;
							}
						}
						close(IN);
						$t += ($r + $w);
					}
				}
				$str = $e . "_net" . $n;
				$net = $t - ($config->{libvirt_hist}->{$str} || 0);
				$net = 0 unless $t != $net;
				$net /= 60;
				$config->{libvirt_hist}->{$str} = $t;
			}
			$rrdata .= ":$cpu:$mem:$dsk:$net:0:0:0:0";
		}
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub libvirt_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $libvirt = $config->{libvirt};
	my @rigid = split(',', ($libvirt->{rigid} || ""));
	my @limit = split(',', ($libvirt->{limit} || ""));
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
	my @IMG;
	my @IMGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $T = "B";
	my $vlabel = "bytes/s";
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

	if(lc($config->{netstats_in_bps}) eq "y") {
		$T = "b";
		$vlabel = "bits/s";
	}


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
		foreach my $vmg (sort keys %{$libvirt->{list}}) {
			my @lvl = split(',', $libvirt->{list}->{$vmg});
			for($n = 0; $n < scalar(@lvl); $n++) {
				my $vm = trim($lvl[$n]);

				# convert from old configuration to new
				if(ref($libvirt->{desc}->{$vm} || "") ne "HASH") {
					$str = trim((split(',', $libvirt->{desc}->{$vm} || ""))[0]);
				} else {
					$str = $libvirt->{desc}->{$vm}->{desc} || "";
				}

				$str = sprintf("%31s", trim((split(',', $str || $vm))[0]));
				$line1 .= $str;
				$str = sprintf("  CPU%%  Memory    Disk     Net ");
				$line2 .= $str;
				$line3 .=      "-------------------------------";
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
			foreach my $vmg (sort keys %{$libvirt->{list}}) {
				my @lvl = split(',', $libvirt->{list}->{$vmg});
				for($n2 = 0; $n2 < scalar(@lvl); $n2++) {
					$from = ($e * 8 * 8) + ($n2 * 8);
					$to = $from + 8;
					my ($cpu, $mem, $dsk, $net) = @$line[$from..$to];
					if(lc($config->{netstats_in_bps}) eq "y") {
						$net *= 8;
					}
					@row = ($cpu || 0, ($mem || 0) / 1024 / 1024, ($dsk || 0) / 1024, ($net || 0) / 1024);
					push(@output, sprintf(" %4.1f%% %6dM %6.1fM %6.1fM ", @row));
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

	for($n = 0; $n < keys(%{$libvirt->{list}}); $n++) {
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
	foreach my $vmg (sort keys %{$libvirt->{list}}) {
		my @lvl = split(',', $libvirt->{list}->{$vmg});

		# hide empty groups
		next if !scalar(@lvl);

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
		for($n = 0; $n < 8; $n++) {
			my $vm = trim($lvl[$n] || "");

			if($vm) {
				# convert from old configuration to new
				if(ref($libvirt->{desc}->{$vm} || "") ne "HASH") {
					$str = trim((split(',', $libvirt->{desc}->{$vm} || ""))[0]);
				} else {
					$str = $libvirt->{desc}->{$vm}->{desc} || "";
				}

				push(@tmpz, "LINE2:cpu" . $n . $LC[$n] . ":$str");
				$str = sprintf("%-20s", substr($str, 0, 20));
				push(@tmp, "LINE2:cpu" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:cpu" . $n . ":LAST:Cur\\: %4.1lf%%");
				push(@tmp, "GPRINT:cpu" . $n . ":MIN:  Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:cpu" . $n . ":MAX:  Max\\: %4.1lf%%\\n");
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
			"--title=$config->{graphs}->{_libvirt1}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:cpu0=$rrd:libv" . $e . "_cpu0:AVERAGE",
			"DEF:cpu1=$rrd:libv" . $e . "_cpu1:AVERAGE",
			"DEF:cpu2=$rrd:libv" . $e . "_cpu2:AVERAGE",
			"DEF:cpu3=$rrd:libv" . $e . "_cpu3:AVERAGE",
			"DEF:cpu4=$rrd:libv" . $e . "_cpu4:AVERAGE",
			"DEF:cpu5=$rrd:libv" . $e . "_cpu5:AVERAGE",
			"DEF:cpu6=$rrd:libv" . $e . "_cpu6:AVERAGE",
			"DEF:cpu7=$rrd:libv" . $e . "_cpu7:AVERAGE",
			"CDEF:allvalues=cpu0,cpu1,cpu2,cpu3,cpu4,cpu5,cpu6,cpu7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4]",
				"--title=$config->{graphs}->{_libvirt1}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:cpu0=$rrd:libv" . $e . "_cpu0:AVERAGE",
				"DEF:cpu1=$rrd:libv" . $e . "_cpu1:AVERAGE",
				"DEF:cpu2=$rrd:libv" . $e . "_cpu2:AVERAGE",
				"DEF:cpu3=$rrd:libv" . $e . "_cpu3:AVERAGE",
				"DEF:cpu4=$rrd:libv" . $e . "_cpu4:AVERAGE",
				"DEF:cpu5=$rrd:libv" . $e . "_cpu5:AVERAGE",
				"DEF:cpu6=$rrd:libv" . $e . "_cpu6:AVERAGE",
				"DEF:cpu7=$rrd:libv" . $e . "_cpu7:AVERAGE",
				"CDEF:allvalues=cpu0,cpu1,cpu2,cpu3,cpu4,cpu5,cpu6,cpu7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4]: $err\n") if $err;
		}
		$e2 = $e . "1";
		if($title || ($silent =~ /imagetag/ && $graph =~ /libvirt$e2/)) {
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
		for($n = 0; $n < 8; $n++) {
			my $vm = trim($lvl[$n] || "");

			if($vm) {
				# convert from old configuration to new
				if(ref($libvirt->{desc}->{$vm} || "") ne "HASH") {
					$str = trim((split(',', $libvirt->{desc}->{$vm} || ""))[0]);
				} else {
					$str = $libvirt->{desc}->{$vm}->{desc} || "";
				}
				push(@tmpz, "LINE2:mem" . $n . $LC[$n] . ":$str");
				$str = sprintf("%-20s", substr($str, 0, 20));
				push(@tmp, "LINE2:mem" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:m_mem" . $n . ":LAST:Cur\\: %4.0lfM");
				push(@tmp, "GPRINT:m_mem" . $n . ":MIN:  Min\\: %4.0lfM");
				push(@tmp, "GPRINT:m_mem" . $n . ":MAX:  Max\\: %4.0lfM\\n");
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
			"--title=$config->{graphs}->{_libvirt2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Bytes",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:mem0=$rrd:libv" . $e . "_mem0:AVERAGE",
			"DEF:mem1=$rrd:libv" . $e . "_mem1:AVERAGE",
			"DEF:mem2=$rrd:libv" . $e . "_mem2:AVERAGE",
			"DEF:mem3=$rrd:libv" . $e . "_mem3:AVERAGE",
			"DEF:mem4=$rrd:libv" . $e . "_mem4:AVERAGE",
			"DEF:mem5=$rrd:libv" . $e . "_mem5:AVERAGE",
			"DEF:mem6=$rrd:libv" . $e . "_mem6:AVERAGE",
			"DEF:mem7=$rrd:libv" . $e . "_mem7:AVERAGE",
			"CDEF:allvalues=mem0,mem1,mem2,mem3,mem4,mem5,mem6,mem7,+,+,+,+,+,+,+",
			"CDEF:m_mem0=mem0,1024,/,1024,/",
			"CDEF:m_mem1=mem1,1024,/,1024,/",
			"CDEF:m_mem2=mem2,1024,/,1024,/",
			"CDEF:m_mem3=mem3,1024,/,1024,/",
			"CDEF:m_mem4=mem4,1024,/,1024,/",
			"CDEF:m_mem5=mem5,1024,/,1024,/",
			"CDEF:m_mem6=mem6,1024,/,1024,/",
			"CDEF:m_mem7=mem7,1024,/,1024,/",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4 + 1]",
				"--title=$config->{graphs}->{_libvirt2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Bytes",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:mem0=$rrd:libv" . $e . "_mem0:AVERAGE",
				"DEF:mem1=$rrd:libv" . $e . "_mem1:AVERAGE",
				"DEF:mem2=$rrd:libv" . $e . "_mem2:AVERAGE",
				"DEF:mem3=$rrd:libv" . $e . "_mem3:AVERAGE",
				"DEF:mem4=$rrd:libv" . $e . "_mem4:AVERAGE",
				"DEF:mem5=$rrd:libv" . $e . "_mem5:AVERAGE",
				"DEF:mem6=$rrd:libv" . $e . "_mem6:AVERAGE",
				"DEF:mem7=$rrd:libv" . $e . "_mem7:AVERAGE",
				"CDEF:allvalues=mem0,mem1,mem2,mem3,mem4,mem5,mem6,mem7,+,+,+,+,+,+,+",
				"CDEF:m_mem0=mem0,1024,/,1024,/",
				"CDEF:m_mem1=mem1,1024,/,1024,/",
				"CDEF:m_mem2=mem2,1024,/,1024,/",
				"CDEF:m_mem3=mem3,1024,/,1024,/",
				"CDEF:m_mem4=mem4,1024,/,1024,/",
				"CDEF:m_mem5=mem5,1024,/,1024,/",
				"CDEF:m_mem6=mem6,1024,/,1024,/",
				"CDEF:m_mem7=mem7,1024,/,1024,/",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4 + 1]: $err\n") if $err;
		}
		$e2 = $e . "2";
		if($title || ($silent =~ /imagetag/ && $graph =~ /libvirt$e2/)) {
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
		for($n = 0; $n < 8; $n++) {
			my $vm = trim($lvl[$n] || "");

			if($vm) {
				# convert from old configuration to new
				if(ref($libvirt->{desc}->{$vm} || "") ne "HASH") {
					$str = trim((split(',', $libvirt->{desc}->{$vm} || ""))[0]);
				} else {
					$str = $libvirt->{desc}->{$vm}->{desc} || "";
				}
				push(@tmpz, "LINE2:dsk" . $n . $LC[$n] . ":$str");
				$str = sprintf("%-20s", substr($str, 0, 20));
				push(@tmp, "LINE2:dsk" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:m_dsk" . $n . ":LAST:Cur\\: %4.1lfM");
				push(@tmp, "GPRINT:m_dsk" . $n . ":MIN:  Min\\: %4.1lfM");
				push(@tmp, "GPRINT:m_dsk" . $n . ":MAX:  Max\\: %4.1lfM\\n");
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
			"--title=$config->{graphs}->{_libvirt3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=bytes/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:dsk0=$rrd:libv" . $e . "_dsk0:AVERAGE",
			"DEF:dsk1=$rrd:libv" . $e . "_dsk1:AVERAGE",
			"DEF:dsk2=$rrd:libv" . $e . "_dsk2:AVERAGE",
			"DEF:dsk3=$rrd:libv" . $e . "_dsk3:AVERAGE",
			"DEF:dsk4=$rrd:libv" . $e . "_dsk4:AVERAGE",
			"DEF:dsk5=$rrd:libv" . $e . "_dsk5:AVERAGE",
			"DEF:dsk6=$rrd:libv" . $e . "_dsk6:AVERAGE",
			"DEF:dsk7=$rrd:libv" . $e . "_dsk7:AVERAGE",
			"CDEF:allvalues=dsk0,dsk1,dsk2,dsk3,dsk4,dsk5,dsk6,dsk7,+,+,+,+,+,+,+",
			"CDEF:m_dsk0=dsk0,1024,/,1024,/",
			"CDEF:m_dsk1=dsk1,1024,/,1024,/",
			"CDEF:m_dsk2=dsk2,1024,/,1024,/",
			"CDEF:m_dsk3=dsk3,1024,/,1024,/",
			"CDEF:m_dsk4=dsk4,1024,/,1024,/",
			"CDEF:m_dsk5=dsk5,1024,/,1024,/",
			"CDEF:m_dsk6=dsk6,1024,/,1024,/",
			"CDEF:m_dsk7=dsk7,1024,/,1024,/",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4 + 2]",
				"--title=$config->{graphs}->{_libvirt3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=bytes/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:dsk0=$rrd:libv" . $e . "_dsk0:AVERAGE",
				"DEF:dsk1=$rrd:libv" . $e . "_dsk1:AVERAGE",
				"DEF:dsk2=$rrd:libv" . $e . "_dsk2:AVERAGE",
				"DEF:dsk3=$rrd:libv" . $e . "_dsk3:AVERAGE",
				"DEF:dsk4=$rrd:libv" . $e . "_dsk4:AVERAGE",
				"DEF:dsk5=$rrd:libv" . $e . "_dsk5:AVERAGE",
				"DEF:dsk6=$rrd:libv" . $e . "_dsk6:AVERAGE",
				"DEF:dsk7=$rrd:libv" . $e . "_dsk7:AVERAGE",
				"CDEF:allvalues=dsk0,dsk1,dsk2,dsk3,dsk4,dsk5,dsk6,dsk7,+,+,+,+,+,+,+",
				@CDEF,
				"CDEF:m_dsk0=dsk0,1024,/,1024,/",
				"CDEF:m_dsk1=dsk1,1024,/,1024,/",
				"CDEF:m_dsk2=dsk2,1024,/,1024,/",
				"CDEF:m_dsk3=dsk3,1024,/,1024,/",
				"CDEF:m_dsk4=dsk4,1024,/,1024,/",
				"CDEF:m_dsk5=dsk5,1024,/,1024,/",
				"CDEF:m_dsk6=dsk6,1024,/,1024,/",
				"CDEF:m_dsk7=dsk7,1024,/,1024,/",
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4 + 2]: $err\n") if $err;
		}
		$e2 = $e . "3";
		if($title || ($silent =~ /imagetag/ && $graph =~ /libvirt$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 2] . "' border='0'></a>\n");
				}
				else { if($version eq "new") {
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
		for($n = 0; $n < 8; $n++) {
			my $vm = trim($lvl[$n] || "");

			if($vm) {
				# convert from old configuration to new
				if(ref($libvirt->{desc}->{$vm} || "") ne "HASH") {
					$str = trim((split(',', $libvirt->{desc}->{$vm} || ""))[0]);
				} else {
					$str = $libvirt->{desc}->{$vm}->{desc} || "";
				}
				push(@tmpz, "LINE2:net" . $n . $LC[$n] . ":$str");
				$str = sprintf("%-20s", substr($str, 0, 20));
				push(@tmp, "LINE2:net" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:m_net" . $n . ":LAST:Cur\\: %4.1lfM");
				push(@tmp, "GPRINT:m_net" . $n . ":MIN:  Min\\: %4.1lfM");
				push(@tmp, "GPRINT:m_net" . $n . ":MAX:  Max\\: %4.1lfM\\n");
			}
		}
		if(lc($config->{netstats_in_bps}) eq "y") {
			push(@CDEF, "CDEF:m_net0=net0,1024,/,1024,/,8,*");
			push(@CDEF, "CDEF:m_net1=net1,1024,/,1024,/,8,*");
			push(@CDEF, "CDEF:m_net2=net2,1024,/,1024,/,8,*");
			push(@CDEF, "CDEF:m_net3=net3,1024,/,1024,/,8,*");
			push(@CDEF, "CDEF:m_net4=net4,1024,/,1024,/,8,*");
			push(@CDEF, "CDEF:m_net5=net5,1024,/,1024,/,8,*");
			push(@CDEF, "CDEF:m_net6=net6,1024,/,1024,/,8,*");
			push(@CDEF, "CDEF:m_net7=net7,1024,/,1024,/,8,*");
		} else {
			push(@CDEF, "CDEF:m_net0=net0,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net1=net1,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net2=net2,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net3=net3,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net4=net4,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net5=net5,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net6=net6,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net7=net7,1024,/,1024,/");
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
			"--title=$config->{graphs}->{_libvirt4}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:net0=$rrd:libv" . $e . "_net0:AVERAGE",
			"DEF:net1=$rrd:libv" . $e . "_net1:AVERAGE",
			"DEF:net2=$rrd:libv" . $e . "_net2:AVERAGE",
			"DEF:net3=$rrd:libv" . $e . "_net3:AVERAGE",
			"DEF:net4=$rrd:libv" . $e . "_net4:AVERAGE",
			"DEF:net5=$rrd:libv" . $e . "_net5:AVERAGE",
			"DEF:net6=$rrd:libv" . $e . "_net6:AVERAGE",
			"DEF:net7=$rrd:libv" . $e . "_net7:AVERAGE",
			"CDEF:allvalues=net0,net1,net2,net3,net4,net5,net6,net7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4 + 3]",
				"--title=$config->{graphs}->{_libvirt4}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:net0=$rrd:libv" . $e . "_net0:AVERAGE",
				"DEF:net1=$rrd:libv" . $e . "_net1:AVERAGE",
				"DEF:net2=$rrd:libv" . $e . "_net2:AVERAGE",
				"DEF:net3=$rrd:libv" . $e . "_net3:AVERAGE",
				"DEF:net4=$rrd:libv" . $e . "_net4:AVERAGE",
				"DEF:net5=$rrd:libv" . $e . "_net5:AVERAGE",
				"DEF:net6=$rrd:libv" . $e . "_net6:AVERAGE",
				"DEF:net7=$rrd:libv" . $e . "_net7:AVERAGE",
				"CDEF:allvalues=net0,net1,net2,net3,net4,net5,net6,net7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4 + 3]: $err\n") if $err;
		}
		$e2 = $e . "4";
		if($title || ($silent =~ /imagetag/ && $graph =~ /libvirt$e2/)) {
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
