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

package process;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(process_init process_update process_cgi);

sub process_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $process = $config->{process};

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	if(!grep {$_ eq $config->{os}} ("Linux")) {
		logger("$myself is not supported yet by your operating system ($config->{os}).");
		return;
	}

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

		if(scalar(@ds) / 110 != keys(%{$process->{list}})) {
			logger("$myself: Detected size mismatch between <list>...</list> (" . keys(%{$process->{list}}) . ") and $rrd (" . scalar(@ds) / 110 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < keys(%{$process->{list}}); $n++) {
			my $n2;
			for($n2 = 0; $n2 < 10; $n2++) {
				push(@tmp, "DS:proc" . $n . "_cpu" . $n2 . ":GAUGE:120:0:100");
				push(@tmp, "DS:proc" . $n . "_mem" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:proc" . $n . "_dsk" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:proc" . $n . "_net" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:proc" . $n . "_nof" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:proc" . $n . "_pro" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:proc" . $n . "_nth" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:proc" . $n . "_vcs" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:proc" . $n . "_ics" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:proc" . $n . "_va1" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:proc" . $n . "_va2" . $n2 . ":GAUGE:120:0:U");
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

	$config->{process_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub process_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $process = $config->{process};

	my $n;
	my $rrdata = "N";

	my $e = 0;
	foreach my $pg (sort keys %{$process->{list}}) {
		my @lp = split(',', $process->{list}->{$pg});
		for($n = 0; $n < 10; $n++) {
			my $cpu = 0;
			my $mem = 0;
			my $dsk = 0;
			my $net = 0;
			my $nof = 0;
			my $pro = 0;
			my $nth = 0;
			my $vcs = 0;
			my $ics = 0;

			my $str;
			my @pids;
			my $p = trim($lp[$n] || "");
			my $val;
			my $s_usage = 0;

			# check if that process is running
			if(open(IN, "ps -eo pid,comm,command |")) {
				while(<IN>) {
					if(m/^\s*(\d+)\s+(\S+)\s+(.*?)$/) {
						if($p eq trim($2)) {
							push(@pids, $1);
							$pro++;
							next;
						}
						if($p eq trim($3)) {
							push(@pids, $1);
							$pro++;
							next;
						}
						if(index($3, $p) != -1) {
							push(@pids, $1);
							$pro++;
							next;
						}
					}
					if(substr($p, 0, 15) eq substr($_, 6, 15)) {
						push(@pids, $1);
						$pro++;
						next;
					}
				}
				close(IN);
			}

			if(open(IN, "/proc/stat")) {
				while(<IN>) {
					if(/^cpu /) {
						my (undef, $user, $nice, $sys, $idle, $iow, $irq, $sirq, $steal, $guest) = split(' ', $_);
						$s_usage = $user + $nice + $sys + $idle + $iow + $irq + $sirq + $steal + ($guest || 0);
						last;
					}
				}
				close(IN);
			}

			my $p_usage = 0;
			foreach my $pid (@pids) {
				if(open(IN, "/proc/$pid/stat")) {
					my $utime = 0;
					my $stime = 0;
					my $v_nth = 0;
					my $v_mem = 0;
					my $rest;

					# since a process name can include spaces an 'split(' ', <IN>)' wouldn't work here,
					# therefore we discard the first part of the process information (pid, comm and state).
					(undef, $rest) = <IN> =~ m/^(\d+\s\(.*?\)\s\S\s)(.*?)$/;
					close(IN);
					if($rest) {
						(undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, $utime, $stime, undef, undef, undef, undef, $v_nth, undef, undef, undef, $v_mem) = split(' ', $rest);
						$mem += ($v_mem *= 4096);
						$nth += ($v_nth - 1);
						$p_usage += $utime + $stime;
					} else {
						logger("$myself: WARNING: PID $pid ('$p') has vanished while accounting!");
					}
				}
			}
			$str = $e . "_cpu" . $n;
			$cpu += 100 * ($p_usage - ($config->{process_hist}->{$str}->{pusage} || 0)) / ($s_usage - ($config->{process_hist}->{$str}->{susage} || 0));
			$config->{process_hist}->{$str}->{pusage} = $p_usage;
			$config->{process_hist}->{$str}->{susage} = $s_usage;

			my $v_dsk = 0;
			my $v_net = 0;
			foreach my $pid (@pids) {
				if(open(IN, "/proc/$pid/io")) {
					my $rchar = 0;
					my $wchar = 0;
					my $readb = 0;
					my $writb = 0;
					while(<IN>) {
						$rchar = $1 if /^rchar:\s+(\d+)$/;
						$wchar = $1 if /^wchar:\s+(\d+)$/;
						$readb = $1 if /^read_bytes:\s+(\d+)$/;
						$writb = $1 if /^write_bytes:\s+(\d+)$/;
					}
					close(IN);
					$v_dsk += $readb + $writb;
					$v_net += ($rchar + $wchar) - ($readb + $writb);
				}
			}
			$str = $e . "_dsk" . $n;
			$dsk = $v_dsk - ($config->{process_hist}->{$str} || 0);
			$dsk = 0 unless $v_dsk != $dsk;
			$dsk /= 60;
			$config->{process_hist}->{$str} = $v_dsk;
			$str = $e . "_net" . $n;
			$net = $v_net - ($config->{process_hist}->{$str} || 0);
			$net = 0 unless $v_net != $net;
			$net /= 60;
			$config->{process_hist}->{$str} = $v_net;
			$net = 0 if $net < 0;

			my $v_vcs = 0;
			my $v_ics = 0;
			foreach my $pid (@pids) {
				if(opendir(DIR, "/proc/$pid/fdinfo")) {
					my @files = grep { !/^[.]/ } readdir(DIR);
					$nof += scalar(@files);
					closedir(DIR);
				}

				if(open(IN, "/proc/$pid/status")) {
					while(<IN>) {
						if(/^voluntary_ctxt_switches:\s+(\d+)$/) {
							$v_vcs += $1;
						}
						if(/^nonvoluntary_ctxt_switches:\s+(\d+)$/) {
							$v_ics += $1;
						}
					}
					close(IN);
				}
			}
			$str = $e . "_vcs" . $n;
			$vcs = $v_vcs - ($config->{process_hist}->{$str} || 0);
			$vcs = 0 unless $v_vcs != $vcs;
			$vcs /= 60;
			$config->{process_hist}->{$str} = $v_vcs;
			$str = $e . "_ics" . $n;
			$ics = $v_ics - ($config->{process_hist}->{$str} || 0);
			$ics = 0 unless $v_ics != $ics;
			$ics /= 60;
			$config->{process_hist}->{$str} = $v_ics;

			$rrdata .= ":$cpu:$mem:$dsk:$net:$nof:$pro:$nth:$vcs:$ics:0:0";
		}
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub process_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $process = $config->{process};
	my @rigid = split(',', ($process->{rigid} || ""));
	my @limit = split(',', ($process->{limit} || ""));
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
		"#888888",
		"#DDAE8C",
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
		foreach my $pg (sort keys %{$process->{list}}) {
			my @lp = split(',', $process->{list}->{$pg});
			for($n = 0; $n < scalar(@lp); $n++) {
				my $p = trim($lp[$n]);
				$str = sprintf("  %61s", trim((split(',', $process->{desc}->{$p} || $p))));
				$line1 .= $str;
				$str = sprintf("   CPU%%  Memory    Disk     Net  OFiles  NProcs Threads CtxtS/s");
				$line2 .= $str;
				$line3 .=      "---------------------------------------------------------------";
			}
		}
		push(@output, "     $line1\n");
		push(@output, "Time $line2\n");
		push(@output, "-----$line3 \n");
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
			foreach my $pg (sort keys %{$process->{list}}) {
				my @lp = split(',', $process->{list}->{$pg});
				for($n2 = 0; $n2 < scalar(@lp); $n2++) {
					$from = ($e * 10 * 11) + ($n2 * 11);
					$to = $from + 11;
					my ($cpu, $mem, $dsk, $net, $nof, $pro, $nth, $vcs, $ics) = @$line[$from..$to];
					if(lc($config->{netstats_in_bps}) eq "y") {
						$net *= 8;
					}
					$cpu ||= 0;
					$mem = ($mem || 0) / 1024 / 1024;
					$dsk = ($dsk || 0) / 1024;
					$net = ($net || 0) / 1024;
					$nof ||= 0;
					$pro ||= 0;
					$nth ||= 0;
					my $cs = ($vcs || 0) + ($ics || 0) ;
					push(@output, sprintf("  %4.1f%% %6dM %6dM %6dM %7d %7d %7d %7d", $cpu, $mem, $dsk, $net, $nof, $pro, $nth, $cs));
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

	for($n = 0; $n < keys(%{$process->{list}}); $n++) {
		for($n2 = 1; $n2 <= 10; $n2++) {
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
	foreach my $pg (sort keys %{$process->{list}}) {
		my @lp = split(',', $process->{list}->{$pg});

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
		for($n = 0; $n < 10; $n++) {
			my $p = trim($lp[$n] || "");

			if($p) {
				$str = trim((split(',', $process->{desc}->{$p} || ""))[0]) || $p;
				$str =~ s/:/\\:/g;	# escape colons
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 10]",
			"--title=$config->{graphs}->{_process1}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:cpu0=$rrd:proc" . $e . "_cpu0:AVERAGE",
			"DEF:cpu1=$rrd:proc" . $e . "_cpu1:AVERAGE",
			"DEF:cpu2=$rrd:proc" . $e . "_cpu2:AVERAGE",
			"DEF:cpu3=$rrd:proc" . $e . "_cpu3:AVERAGE",
			"DEF:cpu4=$rrd:proc" . $e . "_cpu4:AVERAGE",
			"DEF:cpu5=$rrd:proc" . $e . "_cpu5:AVERAGE",
			"DEF:cpu6=$rrd:proc" . $e . "_cpu6:AVERAGE",
			"DEF:cpu7=$rrd:proc" . $e . "_cpu7:AVERAGE",
			"DEF:cpu8=$rrd:proc" . $e . "_cpu8:AVERAGE",
			"DEF:cpu9=$rrd:proc" . $e . "_cpu9:AVERAGE",
			"CDEF:allvalues=cpu0,cpu1,cpu2,cpu3,cpu4,cpu5,cpu6,cpu7,cpu8,cpu9,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 10]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 10]",
				"--title=$config->{graphs}->{_process1}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:cpu0=$rrd:proc" . $e . "_cpu0:AVERAGE",
				"DEF:cpu1=$rrd:proc" . $e . "_cpu1:AVERAGE",
				"DEF:cpu2=$rrd:proc" . $e . "_cpu2:AVERAGE",
				"DEF:cpu3=$rrd:proc" . $e . "_cpu3:AVERAGE",
				"DEF:cpu4=$rrd:proc" . $e . "_cpu4:AVERAGE",
				"DEF:cpu5=$rrd:proc" . $e . "_cpu5:AVERAGE",
				"DEF:cpu6=$rrd:proc" . $e . "_cpu6:AVERAGE",
				"DEF:cpu7=$rrd:proc" . $e . "_cpu7:AVERAGE",
				"DEF:cpu8=$rrd:proc" . $e . "_cpu8:AVERAGE",
				"DEF:cpu9=$rrd:proc" . $e . "_cpu9:AVERAGE",
				"CDEF:allvalues=cpu0,cpu1,cpu2,cpu3,cpu4,cpu5,cpu6,cpu7,cpu8,cpu9,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 10]: $err\n") if $err;
		}
		$e2 = $e . "1";
		if($title || ($silent =~ /imagetag/ && $graph =~ /process$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10] . "'>\n");
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
		for($n = 0; $n < 10; $n++) {
			my $p = trim($lp[$n] || "");

			if($p) {
				$str = trim((split(',', $process->{desc}->{$p} || ""))[0]) || $p;
				$str =~ s/:/\\:/g;	# escape colons
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 10 + 1]",
			"--title=$config->{graphs}->{_process2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=bytes",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:mem0=$rrd:proc" . $e . "_mem0:AVERAGE",
			"DEF:mem1=$rrd:proc" . $e . "_mem1:AVERAGE",
			"DEF:mem2=$rrd:proc" . $e . "_mem2:AVERAGE",
			"DEF:mem3=$rrd:proc" . $e . "_mem3:AVERAGE",
			"DEF:mem4=$rrd:proc" . $e . "_mem4:AVERAGE",
			"DEF:mem5=$rrd:proc" . $e . "_mem5:AVERAGE",
			"DEF:mem6=$rrd:proc" . $e . "_mem6:AVERAGE",
			"DEF:mem7=$rrd:proc" . $e . "_mem7:AVERAGE",
			"DEF:mem8=$rrd:proc" . $e . "_mem8:AVERAGE",
			"DEF:mem9=$rrd:proc" . $e . "_mem9:AVERAGE",
			"CDEF:allvalues=mem0,mem1,mem2,mem3,mem4,mem5,mem6,mem7,mem8,mem9,+,+,+,+,+,+,+,+,+",
			"CDEF:m_mem0=mem0,1024,/,1024,/",
			"CDEF:m_mem1=mem1,1024,/,1024,/",
			"CDEF:m_mem2=mem2,1024,/,1024,/",
			"CDEF:m_mem3=mem3,1024,/,1024,/",
			"CDEF:m_mem4=mem4,1024,/,1024,/",
			"CDEF:m_mem5=mem5,1024,/,1024,/",
			"CDEF:m_mem6=mem6,1024,/,1024,/",
			"CDEF:m_mem7=mem7,1024,/,1024,/",
			"CDEF:m_mem8=mem8,1024,/,1024,/",
			"CDEF:m_mem9=mem9,1024,/,1024,/",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 10 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 10 + 1]",
				"--title=$config->{graphs}->{_process2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=bytes",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:mem0=$rrd:proc" . $e . "_mem0:AVERAGE",
				"DEF:mem1=$rrd:proc" . $e . "_mem1:AVERAGE",
				"DEF:mem2=$rrd:proc" . $e . "_mem2:AVERAGE",
				"DEF:mem3=$rrd:proc" . $e . "_mem3:AVERAGE",
				"DEF:mem4=$rrd:proc" . $e . "_mem4:AVERAGE",
				"DEF:mem5=$rrd:proc" . $e . "_mem5:AVERAGE",
				"DEF:mem6=$rrd:proc" . $e . "_mem6:AVERAGE",
				"DEF:mem7=$rrd:proc" . $e . "_mem7:AVERAGE",
				"DEF:mem8=$rrd:proc" . $e . "_mem8:AVERAGE",
				"DEF:mem9=$rrd:proc" . $e . "_mem9:AVERAGE",
				"CDEF:allvalues=mem0,mem1,mem2,mem3,mem4,mem5,mem6,mem7,mem8,mem9,+,+,+,+,+,+,+,+,+",
				"CDEF:m_mem0=mem0,1024,/,1024,/",
				"CDEF:m_mem1=mem1,1024,/,1024,/",
				"CDEF:m_mem2=mem2,1024,/,1024,/",
				"CDEF:m_mem3=mem3,1024,/,1024,/",
				"CDEF:m_mem4=mem4,1024,/,1024,/",
				"CDEF:m_mem5=mem5,1024,/,1024,/",
				"CDEF:m_mem6=mem6,1024,/,1024,/",
				"CDEF:m_mem7=mem7,1024,/,1024,/",
				"CDEF:m_mem8=mem8,1024,/,1024,/",
				"CDEF:m_mem9=mem9,1024,/,1024,/",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 10 + 1]: $err\n") if $err;
		}
		$e2 = $e . "2";
		if($title || ($silent =~ /imagetag/ && $graph =~ /process$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 1] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < 10; $n++) {
			my $p = trim($lp[$n] || "");

			if($p) {
				$str = trim((split(',', $process->{desc}->{$p} || ""))[0]) || $p;
				$str =~ s/:/\\:/g;	# escape colons
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 10 + 2]",
			"--title=$config->{graphs}->{_process3}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:dsk0=$rrd:proc" . $e . "_dsk0:AVERAGE",
			"DEF:dsk1=$rrd:proc" . $e . "_dsk1:AVERAGE",
			"DEF:dsk2=$rrd:proc" . $e . "_dsk2:AVERAGE",
			"DEF:dsk3=$rrd:proc" . $e . "_dsk3:AVERAGE",
			"DEF:dsk4=$rrd:proc" . $e . "_dsk4:AVERAGE",
			"DEF:dsk5=$rrd:proc" . $e . "_dsk5:AVERAGE",
			"DEF:dsk6=$rrd:proc" . $e . "_dsk6:AVERAGE",
			"DEF:dsk7=$rrd:proc" . $e . "_dsk7:AVERAGE",
			"DEF:dsk8=$rrd:proc" . $e . "_dsk8:AVERAGE",
			"DEF:dsk9=$rrd:proc" . $e . "_dsk9:AVERAGE",
			"CDEF:allvalues=dsk0,dsk1,dsk2,dsk3,dsk4,dsk5,dsk6,dsk7,dsk8,dsk9,+,+,+,+,+,+,+,+,+",
			"CDEF:m_dsk0=dsk0,1024,/,1024,/",
			"CDEF:m_dsk1=dsk1,1024,/,1024,/",
			"CDEF:m_dsk2=dsk2,1024,/,1024,/",
			"CDEF:m_dsk3=dsk3,1024,/,1024,/",
			"CDEF:m_dsk4=dsk4,1024,/,1024,/",
			"CDEF:m_dsk5=dsk5,1024,/,1024,/",
			"CDEF:m_dsk6=dsk6,1024,/,1024,/",
			"CDEF:m_dsk7=dsk7,1024,/,1024,/",
			"CDEF:m_dsk8=dsk8,1024,/,1024,/",
			"CDEF:m_dsk9=dsk9,1024,/,1024,/",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 10 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 10 + 2]",
				"--title=$config->{graphs}->{_process3}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:dsk0=$rrd:proc" . $e . "_dsk0:AVERAGE",
				"DEF:dsk1=$rrd:proc" . $e . "_dsk1:AVERAGE",
				"DEF:dsk2=$rrd:proc" . $e . "_dsk2:AVERAGE",
				"DEF:dsk3=$rrd:proc" . $e . "_dsk3:AVERAGE",
				"DEF:dsk4=$rrd:proc" . $e . "_dsk4:AVERAGE",
				"DEF:dsk5=$rrd:proc" . $e . "_dsk5:AVERAGE",
				"DEF:dsk6=$rrd:proc" . $e . "_dsk6:AVERAGE",
				"DEF:dsk7=$rrd:proc" . $e . "_dsk7:AVERAGE",
				"DEF:dsk8=$rrd:proc" . $e . "_dsk8:AVERAGE",
				"DEF:dsk9=$rrd:proc" . $e . "_dsk9:AVERAGE",
				"CDEF:allvalues=dsk0,dsk1,dsk2,dsk3,dsk4,dsk5,dsk6,dsk7,dsk8,dsk9,+,+,+,+,+,+,+,+,+",
				"CDEF:m_dsk0=dsk0,1024,/,1024,/",
				"CDEF:m_dsk1=dsk1,1024,/,1024,/",
				"CDEF:m_dsk2=dsk2,1024,/,1024,/",
				"CDEF:m_dsk3=dsk3,1024,/,1024,/",
				"CDEF:m_dsk4=dsk4,1024,/,1024,/",
				"CDEF:m_dsk5=dsk5,1024,/,1024,/",
				"CDEF:m_dsk6=dsk6,1024,/,1024,/",
				"CDEF:m_dsk7=dsk7,1024,/,1024,/",
				"CDEF:m_dsk8=dsk8,1024,/,1024,/",
				"CDEF:m_dsk9=dsk9,1024,/,1024,/",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 10 + 2]: $err\n") if $err;
		}
		$e2 = $e . "3";
		if($title || ($silent =~ /imagetag/ && $graph =~ /process$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 2] . "'>\n");
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
		for($n = 0; $n < 10; $n++) {
			my $p = trim($lp[$n] || "");

			if($p) {
				$str = trim((split(',', $process->{desc}->{$p} || ""))[0]) || $p;
				$str =~ s/:/\\:/g;	# escape colons
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
			push(@CDEF, "CDEF:m_net8=net8,1024,/,1024,/,8,*");
			push(@CDEF, "CDEF:m_net9=net9,1024,/,1024,/,8,*");
		} else {
			push(@CDEF, "CDEF:m_net0=net0,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net1=net1,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net2=net2,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net3=net3,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net4=net4,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net5=net5,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net6=net6,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net7=net7,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net8=net8,1024,/,1024,/");
			push(@CDEF, "CDEF:m_net9=net9,1024,/,1024,/");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 10 + 3]",
			"--title=$config->{graphs}->{_process4}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:net0=$rrd:proc" . $e . "_net0:AVERAGE",
			"DEF:net1=$rrd:proc" . $e . "_net1:AVERAGE",
			"DEF:net2=$rrd:proc" . $e . "_net2:AVERAGE",
			"DEF:net3=$rrd:proc" . $e . "_net3:AVERAGE",
			"DEF:net4=$rrd:proc" . $e . "_net4:AVERAGE",
			"DEF:net5=$rrd:proc" . $e . "_net5:AVERAGE",
			"DEF:net6=$rrd:proc" . $e . "_net6:AVERAGE",
			"DEF:net7=$rrd:proc" . $e . "_net7:AVERAGE",
			"DEF:net8=$rrd:proc" . $e . "_net8:AVERAGE",
			"DEF:net9=$rrd:proc" . $e . "_net9:AVERAGE",
			"CDEF:allvalues=net0,net1,net2,net3,net4,net5,net6,net7,net8,net9,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 10 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 10 + 3]",
				"--title=$config->{graphs}->{_process4}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:net0=$rrd:proc" . $e . "_net0:AVERAGE",
				"DEF:net1=$rrd:proc" . $e . "_net1:AVERAGE",
				"DEF:net2=$rrd:proc" . $e . "_net2:AVERAGE",
				"DEF:net3=$rrd:proc" . $e . "_net3:AVERAGE",
				"DEF:net4=$rrd:proc" . $e . "_net4:AVERAGE",
				"DEF:net5=$rrd:proc" . $e . "_net5:AVERAGE",
				"DEF:net6=$rrd:proc" . $e . "_net6:AVERAGE",
				"DEF:net7=$rrd:proc" . $e . "_net7:AVERAGE",
				"DEF:net8=$rrd:proc" . $e . "_net8:AVERAGE",
				"DEF:net9=$rrd:proc" . $e . "_net9:AVERAGE",
				"CDEF:allvalues=net0,net1,net2,net3,net4,net5,net6,net7,net8,net9,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 10 + 3]: $err\n") if $err;
		}
		$e2 = $e . "4";
		if($title || ($silent =~ /imagetag/ && $graph =~ /process$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 3] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[4], $limit[4])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < 10; $n++) {
			my $p = trim($lp[$n] || "");

			if($p) {
				$str = trim((split(',', $process->{desc}->{$p} || ""))[0]) || $p;
				$str =~ s/:/\\:/g;	# escape colons
				push(@tmpz, "LINE2:nof" . $n . $LC[$n] . ":$str");
				$str = sprintf("%-20s", substr($str, 0, 20));
				push(@tmp, "LINE2:nof" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:nof" . $n . ":LAST:Cur\\: %4.0lf");
				push(@tmp, "GPRINT:nof" . $n . ":MIN:  Min\\: %4.0lf");
				push(@tmp, "GPRINT:nof" . $n . ":MAX:  Max\\: %4.0lf\\n");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 10 + 4]",
			"--title=$config->{graphs}->{_process5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Files",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:nof0=$rrd:proc" . $e . "_nof0:AVERAGE",
			"DEF:nof1=$rrd:proc" . $e . "_nof1:AVERAGE",
			"DEF:nof2=$rrd:proc" . $e . "_nof2:AVERAGE",
			"DEF:nof3=$rrd:proc" . $e . "_nof3:AVERAGE",
			"DEF:nof4=$rrd:proc" . $e . "_nof4:AVERAGE",
			"DEF:nof5=$rrd:proc" . $e . "_nof5:AVERAGE",
			"DEF:nof6=$rrd:proc" . $e . "_nof6:AVERAGE",
			"DEF:nof7=$rrd:proc" . $e . "_nof7:AVERAGE",
			"DEF:nof8=$rrd:proc" . $e . "_nof8:AVERAGE",
			"DEF:nof9=$rrd:proc" . $e . "_nof9:AVERAGE",
			"CDEF:allvalues=nof0,nof1,nof2,nof3,nof4,nof5,nof6,nof7,nof8,nof9,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 10 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 10 + 4]",
				"--title=$config->{graphs}->{_process5}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Files",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:nof0=$rrd:proc" . $e . "_nof0:AVERAGE",
				"DEF:nof1=$rrd:proc" . $e . "_nof1:AVERAGE",
				"DEF:nof2=$rrd:proc" . $e . "_nof2:AVERAGE",
				"DEF:nof3=$rrd:proc" . $e . "_nof3:AVERAGE",
				"DEF:nof4=$rrd:proc" . $e . "_nof4:AVERAGE",
				"DEF:nof5=$rrd:proc" . $e . "_nof5:AVERAGE",
				"DEF:nof6=$rrd:proc" . $e . "_nof6:AVERAGE",
				"DEF:nof7=$rrd:proc" . $e . "_nof7:AVERAGE",
				"DEF:nof8=$rrd:proc" . $e . "_nof8:AVERAGE",
				"DEF:nof9=$rrd:proc" . $e . "_nof9:AVERAGE",
				"CDEF:allvalues=nof0,nof1,nof2,nof3,nof4,nof5,nof6,nof7,nof8,nof9,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 10 + 4]: $err\n") if $err;
		}
		$e2 = $e . "5";
		if($title || ($silent =~ /imagetag/ && $graph =~ /process$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 4] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 4] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 4] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 4] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 4] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}
		@riglim = @{setup_riglim($rigid[5], $limit[5])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < 10; $n++) {
			my $p = trim($lp[$n] || "");

			if($p) {
				$str = trim((split(',', $process->{desc}->{$p} || ""))[0]) || $p;
				$str =~ s/:/\\:/g;	# escape colons
				push(@tmpz, "LINE2:nth" . $n . $LC[$n] . ":$str");
				$str = sprintf("%-20s", substr($str, 0, 20));
				push(@tmp, "LINE2:nth" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:nth" . $n . ":LAST:Cur\\: %4.0lf");
				push(@tmp, "GPRINT:nth" . $n . ":MIN:  Min\\: %4.0lf");
				push(@tmp, "GPRINT:nth" . $n . ":MAX:  Max\\: %4.0lf\\n");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 10 + 5]",
			"--title=$config->{graphs}->{_process6}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Threads",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:nth0=$rrd:proc" . $e . "_nth0:AVERAGE",
			"DEF:nth1=$rrd:proc" . $e . "_nth1:AVERAGE",
			"DEF:nth2=$rrd:proc" . $e . "_nth2:AVERAGE",
			"DEF:nth3=$rrd:proc" . $e . "_nth3:AVERAGE",
			"DEF:nth4=$rrd:proc" . $e . "_nth4:AVERAGE",
			"DEF:nth5=$rrd:proc" . $e . "_nth5:AVERAGE",
			"DEF:nth6=$rrd:proc" . $e . "_nth6:AVERAGE",
			"DEF:nth7=$rrd:proc" . $e . "_nth7:AVERAGE",
			"DEF:nth8=$rrd:proc" . $e . "_nth8:AVERAGE",
			"DEF:nth9=$rrd:proc" . $e . "_nth9:AVERAGE",
			"CDEF:allvalues=nth0,nth1,nth2,nth3,nth4,nth5,nth6,nth7,nth8,nth9,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 10 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 10 + 5]",
				"--title=$config->{graphs}->{_process6}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Threads",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:nth0=$rrd:proc" . $e . "_nth0:AVERAGE",
				"DEF:nth1=$rrd:proc" . $e . "_nth1:AVERAGE",
				"DEF:nth2=$rrd:proc" . $e . "_nth2:AVERAGE",
				"DEF:nth3=$rrd:proc" . $e . "_nth3:AVERAGE",
				"DEF:nth4=$rrd:proc" . $e . "_nth4:AVERAGE",
				"DEF:nth5=$rrd:proc" . $e . "_nth5:AVERAGE",
				"DEF:nth6=$rrd:proc" . $e . "_nth6:AVERAGE",
				"DEF:nth7=$rrd:proc" . $e . "_nth7:AVERAGE",
				"DEF:nth8=$rrd:proc" . $e . "_nth8:AVERAGE",
				"DEF:nth9=$rrd:proc" . $e . "_nth9:AVERAGE",
				"CDEF:allvalues=nth0,nth1,nth2,nth3,nth4,nth5,nth6,nth7,nth8,nth9,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 10 + 5]: $err\n") if $err;
		}
		$e2 = $e . "6";
		if($title || ($silent =~ /imagetag/ && $graph =~ /process$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 5] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 5] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 5] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 5] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 5] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[6], $limit[6])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < 10; $n++) {
			my $p = trim($lp[$n] || "");

			if($p) {
				$str = trim((split(',', $process->{desc}->{$p} || ""))[0]) || $p;
				$str =~ s/:/\\:/g;	# escape colons
				push(@tmpz, "LINE2:vcs" . $n . $LC[$n] . ":$str");
				push(@tmpz, "LINE2:n_ics" . $n . $LC[$n]);
				$str = sprintf("%-20s", substr($str, 0, 20));
				push(@tmp, "LINE2:vcs" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:tcs" . $n . ":LAST:Cur\\: %4.0lf");
				push(@tmp, "GPRINT:tcs" . $n . ":MIN:  Min\\: %4.0lf");
				push(@tmp, "GPRINT:tcs" . $n . ":MAX:  Max\\: %4.0lf\\n");
				push(@tmp, "LINE2:n_ics" . $n . $LC[$n]);
			}
		}
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata_p#$colors->{gap}:");
			push(@tmp, "AREA:wrongdata_m#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata_p#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata_m#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata_p=allvalues_p,UN,INF,UNKN,IF");
			push(@CDEF, "CDEF:wrongdata_m=allvalues_m,0,LT,INF,-1,*,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 10 + 6]",
			"--title=$config->{graphs}->{_process7}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Nonvoluntary + voluntary/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:vcs0=$rrd:proc" . $e . "_vcs0:AVERAGE",
			"DEF:vcs1=$rrd:proc" . $e . "_vcs1:AVERAGE",
			"DEF:vcs2=$rrd:proc" . $e . "_vcs2:AVERAGE",
			"DEF:vcs3=$rrd:proc" . $e . "_vcs3:AVERAGE",
			"DEF:vcs4=$rrd:proc" . $e . "_vcs4:AVERAGE",
			"DEF:vcs5=$rrd:proc" . $e . "_vcs5:AVERAGE",
			"DEF:vcs6=$rrd:proc" . $e . "_vcs6:AVERAGE",
			"DEF:vcs7=$rrd:proc" . $e . "_vcs7:AVERAGE",
			"DEF:vcs8=$rrd:proc" . $e . "_vcs8:AVERAGE",
			"DEF:vcs9=$rrd:proc" . $e . "_vcs9:AVERAGE",
			"DEF:ics0=$rrd:proc" . $e . "_ics0:AVERAGE",
			"DEF:ics1=$rrd:proc" . $e . "_ics1:AVERAGE",
			"DEF:ics2=$rrd:proc" . $e . "_ics2:AVERAGE",
			"DEF:ics3=$rrd:proc" . $e . "_ics3:AVERAGE",
			"DEF:ics4=$rrd:proc" . $e . "_ics4:AVERAGE",
			"DEF:ics5=$rrd:proc" . $e . "_ics5:AVERAGE",
			"DEF:ics6=$rrd:proc" . $e . "_ics6:AVERAGE",
			"DEF:ics7=$rrd:proc" . $e . "_ics7:AVERAGE",
			"DEF:ics8=$rrd:proc" . $e . "_ics8:AVERAGE",
			"DEF:ics9=$rrd:proc" . $e . "_ics9:AVERAGE",
			"CDEF:allvalues_p=vcs0,vcs1,vcs2,vcs3,vcs4,vcs5,vcs6,vcs7,vcs8,vcs9,ics0,ics1,ics2,ics3,ics4,ics5,ics6,ics7,ics8,ics9,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
			"CDEF:allvalues_m=allvalues_p,UN,-1,UNKN,IF",
			@CDEF,
			"CDEF:n_ics0=ics0,-1,*",
			"CDEF:n_ics1=ics1,-1,*",
			"CDEF:n_ics2=ics2,-1,*",
			"CDEF:n_ics3=ics3,-1,*",
			"CDEF:n_ics4=ics4,-1,*",
			"CDEF:n_ics5=ics5,-1,*",
			"CDEF:n_ics6=ics6,-1,*",
			"CDEF:n_ics7=ics7,-1,*",
			"CDEF:n_ics8=ics8,-1,*",
			"CDEF:n_ics9=ics9,-1,*",
			"CDEF:tcs0=vcs0,ics0,+",
			"CDEF:tcs1=vcs1,ics1,+",
			"CDEF:tcs2=vcs2,ics2,+",
			"CDEF:tcs3=vcs3,ics3,+",
			"CDEF:tcs4=vcs4,ics4,+",
			"CDEF:tcs5=vcs5,ics5,+",
			"CDEF:tcs6=vcs6,ics6,+",
			"CDEF:tcs7=vcs7,ics7,+",
			"CDEF:tcs8=vcs8,ics8,+",
			"CDEF:tcs9=vcs9,ics9,+",
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 10 + 6]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 10 + 6]",
				"--title=$config->{graphs}->{_process7}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Nonvoluntary + voluntary/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:vcs0=$rrd:proc" . $e . "_vcs0:AVERAGE",
				"DEF:vcs1=$rrd:proc" . $e . "_vcs1:AVERAGE",
				"DEF:vcs2=$rrd:proc" . $e . "_vcs2:AVERAGE",
				"DEF:vcs3=$rrd:proc" . $e . "_vcs3:AVERAGE",
				"DEF:vcs4=$rrd:proc" . $e . "_vcs4:AVERAGE",
				"DEF:vcs5=$rrd:proc" . $e . "_vcs5:AVERAGE",
				"DEF:vcs6=$rrd:proc" . $e . "_vcs6:AVERAGE",
				"DEF:vcs7=$rrd:proc" . $e . "_vcs7:AVERAGE",
				"DEF:vcs8=$rrd:proc" . $e . "_vcs8:AVERAGE",
				"DEF:vcs9=$rrd:proc" . $e . "_vcs9:AVERAGE",
				"DEF:ics0=$rrd:proc" . $e . "_ics0:AVERAGE",
				"DEF:ics1=$rrd:proc" . $e . "_ics1:AVERAGE",
				"DEF:ics2=$rrd:proc" . $e . "_ics2:AVERAGE",
				"DEF:ics3=$rrd:proc" . $e . "_ics3:AVERAGE",
				"DEF:ics4=$rrd:proc" . $e . "_ics4:AVERAGE",
				"DEF:ics5=$rrd:proc" . $e . "_ics5:AVERAGE",
				"DEF:ics6=$rrd:proc" . $e . "_ics6:AVERAGE",
				"DEF:ics7=$rrd:proc" . $e . "_ics7:AVERAGE",
				"DEF:ics8=$rrd:proc" . $e . "_ics8:AVERAGE",
				"DEF:ics9=$rrd:proc" . $e . "_ics9:AVERAGE",
				"CDEF:allvalues_p=vcs0,vcs1,vcs2,vcs3,vcs4,vcs5,vcs6,vcs7,vcs8,vcs9,ics0,ics1,ics2,ics3,ics4,ics5,ics6,ics7,ics8,ics9,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
				"CDEF:allvalues_m=allvalues_p,UN,-1,UNKN,IF",
				@CDEF,
				"CDEF:n_ics0=ics0,-1,*",
				"CDEF:n_ics1=ics1,-1,*",
				"CDEF:n_ics2=ics2,-1,*",
				"CDEF:n_ics3=ics3,-1,*",
				"CDEF:n_ics4=ics4,-1,*",
				"CDEF:n_ics5=ics5,-1,*",
				"CDEF:n_ics6=ics6,-1,*",
				"CDEF:n_ics7=ics7,-1,*",
				"CDEF:n_ics8=ics8,-1,*",
				"CDEF:n_ics9=ics9,-1,*",
				"CDEF:tcs0=vcs0,ics0,+",
				"CDEF:tcs1=vcs1,ics1,+",
				"CDEF:tcs2=vcs2,ics2,+",
				"CDEF:tcs3=vcs3,ics3,+",
				"CDEF:tcs4=vcs4,ics4,+",
				"CDEF:tcs5=vcs5,ics5,+",
				"CDEF:tcs6=vcs6,ics6,+",
				"CDEF:tcs7=vcs7,ics7,+",
				"CDEF:tcs8=vcs8,ics8,+",
				"CDEF:tcs9=vcs9,ics9,+",
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 10 + 6]: $err\n") if $err;
		}
		$e2 = $e . "7";
		if($title || ($silent =~ /imagetag/ && $graph =~ /process$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 6] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 6] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 6] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 6] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 6] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}
		@riglim = @{setup_riglim($rigid[7], $limit[7])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < 10; $n++) {
			my $p = trim($lp[$n] || "");

			if($p) {
				$str = trim((split(',', $process->{desc}->{$p} || ""))[0]) || $p;
				$str =~ s/:/\\:/g;	# escape colons
				push(@tmpz, "LINE2:pro" . $n . $LC[$n] . ":$str");
				$str = sprintf("%-20s", substr($str, 0, 20));
				push(@tmp, "LINE2:pro" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:pro" . $n . ":LAST:Cur\\: %4.0lf");
				push(@tmp, "GPRINT:pro" . $n . ":MIN:  Min\\: %4.0lf");
				push(@tmp, "GPRINT:pro" . $n . ":MAX:  Max\\: %4.0lf\\n");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 10 + 7]",
			"--title=$config->{graphs}->{_process8}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Processes",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:pro0=$rrd:proc" . $e . "_pro0:AVERAGE",
			"DEF:pro1=$rrd:proc" . $e . "_pro1:AVERAGE",
			"DEF:pro2=$rrd:proc" . $e . "_pro2:AVERAGE",
			"DEF:pro3=$rrd:proc" . $e . "_pro3:AVERAGE",
			"DEF:pro4=$rrd:proc" . $e . "_pro4:AVERAGE",
			"DEF:pro5=$rrd:proc" . $e . "_pro5:AVERAGE",
			"DEF:pro6=$rrd:proc" . $e . "_pro6:AVERAGE",
			"DEF:pro7=$rrd:proc" . $e . "_pro7:AVERAGE",
			"DEF:pro8=$rrd:proc" . $e . "_pro8:AVERAGE",
			"DEF:pro9=$rrd:proc" . $e . "_pro9:AVERAGE",
			"CDEF:allvalues=pro0,pro1,pro2,pro3,pro4,pro5,pro6,pro7,pro8,pro9,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 10 + 7]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 10 + 7]",
				"--title=$config->{graphs}->{_process8}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Processes",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:pro0=$rrd:proc" . $e . "_pro0:AVERAGE",
				"DEF:pro1=$rrd:proc" . $e . "_pro1:AVERAGE",
				"DEF:pro2=$rrd:proc" . $e . "_pro2:AVERAGE",
				"DEF:pro3=$rrd:proc" . $e . "_pro3:AVERAGE",
				"DEF:pro4=$rrd:proc" . $e . "_pro4:AVERAGE",
				"DEF:pro5=$rrd:proc" . $e . "_pro5:AVERAGE",
				"DEF:pro6=$rrd:proc" . $e . "_pro6:AVERAGE",
				"DEF:pro7=$rrd:proc" . $e . "_pro7:AVERAGE",
				"DEF:pro8=$rrd:proc" . $e . "_pro8:AVERAGE",
				"DEF:pro9=$rrd:proc" . $e . "_pro9:AVERAGE",
				"CDEF:allvalues=pro0,pro1,pro2,pro3,pro4,pro5,pro6,pro7,pro8,pro9,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 10 + 7]: $err\n") if $err;
		}
		$e2 = $e . "8";
		if($title || ($silent =~ /imagetag/ && $graph =~ /process$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 7] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 7] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 10 + 7] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 7] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 10 + 7] . "'>\n");
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
