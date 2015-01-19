#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2014 by Jordi Sanfeliu <jordi@fibranet.cat>
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

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(net_init net_update net_cgi);

sub net_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

	my $info;
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
			if(index($key, 'rra[') == 0) {
				if(index($key, '.rows') != -1) {
					push(@rra, substr($key, 4, index($key, ']') - 4));
				}
			}
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
		eval {
			RRDs::create($rrd,
				"--step=60",
				"DS:net0_bytes_in:GAUGE:120:0:U",
				"DS:net0_bytes_out:GAUGE:120:0:U",
				"DS:net0_packs_in:GAUGE:120:0:U",
				"DS:net0_packs_out:GAUGE:120:0:U",
				"DS:net0_error_in:GAUGE:120:0:U",
				"DS:net0_error_out:GAUGE:120:0:U",
				"DS:net1_bytes_in:GAUGE:120:0:U",
				"DS:net1_bytes_out:GAUGE:120:0:U",
				"DS:net1_packs_in:GAUGE:120:0:U",
				"DS:net1_packs_out:GAUGE:120:0:U",
				"DS:net1_error_in:GAUGE:120:0:U",
				"DS:net1_error_out:GAUGE:120:0:U",
				"DS:net2_bytes_in:GAUGE:120:0:U",
				"DS:net2_bytes_out:GAUGE:120:0:U",
				"DS:net2_packs_in:GAUGE:120:0:U",
				"DS:net2_packs_out:GAUGE:120:0:U",
				"DS:net2_error_in:GAUGE:120:0:U",
				"DS:net2_error_out:GAUGE:120:0:U",
				"DS:net3_bytes_in:GAUGE:120:0:U",
				"DS:net3_bytes_out:GAUGE:120:0:U",
				"DS:net3_packs_in:GAUGE:120:0:U",
				"DS:net3_packs_out:GAUGE:120:0:U",
				"DS:net3_error_in:GAUGE:120:0:U",
				"DS:net3_error_out:GAUGE:120:0:U",
				"DS:net4_bytes_in:GAUGE:120:0:U",
				"DS:net4_bytes_out:GAUGE:120:0:U",
				"DS:net4_packs_in:GAUGE:120:0:U",
				"DS:net4_packs_out:GAUGE:120:0:U",
				"DS:net4_error_in:GAUGE:120:0:U",
				"DS:net4_error_out:GAUGE:120:0:U",
				"DS:net5_bytes_in:GAUGE:120:0:U",
				"DS:net5_bytes_out:GAUGE:120:0:U",
				"DS:net5_packs_in:GAUGE:120:0:U",
				"DS:net5_packs_out:GAUGE:120:0:U",
				"DS:net5_error_in:GAUGE:120:0:U",
				"DS:net5_error_out:GAUGE:120:0:U",
				"DS:net6_bytes_in:GAUGE:120:0:U",
				"DS:net6_bytes_out:GAUGE:120:0:U",
				"DS:net6_packs_in:GAUGE:120:0:U",
				"DS:net6_packs_out:GAUGE:120:0:U",
				"DS:net6_error_in:GAUGE:120:0:U",
				"DS:net6_error_out:GAUGE:120:0:U",
				"DS:net7_bytes_in:GAUGE:120:0:U",
				"DS:net7_bytes_out:GAUGE:120:0:U",
				"DS:net7_packs_in:GAUGE:120:0:U",
				"DS:net7_packs_out:GAUGE:120:0:U",
				"DS:net7_error_in:GAUGE:120:0:U",
				"DS:net7_error_out:GAUGE:120:0:U",
				"DS:net8_bytes_in:GAUGE:120:0:U",
				"DS:net8_bytes_out:GAUGE:120:0:U",
				"DS:net8_packs_in:GAUGE:120:0:U",
				"DS:net8_packs_out:GAUGE:120:0:U",
				"DS:net8_error_in:GAUGE:120:0:U",
				"DS:net8_error_out:GAUGE:120:0:U",
				"DS:net9_bytes_in:GAUGE:120:0:U",
				"DS:net9_bytes_out:GAUGE:120:0:U",
				"DS:net9_packs_in:GAUGE:120:0:U",
				"DS:net9_packs_out:GAUGE:120:0:U",
				"DS:net9_error_in:GAUGE:120:0:U",
				"DS:net9_error_out:GAUGE:120:0:U",
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

	# Since 3.6.0 all DS changed from COUNTER to GAUGE
	for($n = 0; $n < 10; $n++) {
		RRDs::tune($rrd,
			"--data-source-type=net" . $n . "_bytes_in:GAUGE",
			"--data-source-type=net" . $n . "_bytes_out:GAUGE",
			"--data-source-type=net" . $n . "_packs_in:GAUGE",
			"--data-source-type=net" . $n . "_packs_out:GAUGE",
			"--data-source-type=net" . $n . "_error_in:GAUGE",
			"--data-source-type=net" . $n . "_error_out:GAUGE",
		);
	}

	$config->{net_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub net_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $net = $config->{net};

	my $n;
	my $rrdata = "N";

	for($n = 0; $n < 10 ; $n++) {
		my ($bytes_in, $bi) = (0, 0);
		my ($bytes_out, $bo) = (0, 0);
		my ($packs_in, $pi) = (0, 0);
		my ($packs_out, $po) = (0, 0);
		my ($error_in, $ei) = (0, 0);
		my ($error_out, $eo) = (0, 0);
		my $str;

		if($n < scalar(my @nl = split(',', $net->{list}))) {
			$nl[$n] = trim($nl[$n]);
			if($config->{os} eq "Linux") {
				open(IN, "/proc/net/dev");
				while(<IN>) {
					my ($dev, $data) = split(':', $_);
					if(trim($dev) eq $nl[$n]) {
						($bi, $pi, $ei, undef, undef, undef, undef, undef, $bo, $po, $eo) = split(' ', $data);
						last;
					}
				}
				close(IN);
			} elsif($config->{os} eq "FreeBSD") {
				open(IN, "netstat -nibd |");
				while(<IN>) {
					if(/Link/ && /$nl[$n]/) {
						# Idrop column added in 8.0
						if($config->{kernel} > "7.2") {
							(undef, undef, undef, undef, $pi, $ei, undef, $bi, $po, $eo, $bo) = split(' ', $_);
						} else {
							(undef, undef, undef, undef, $pi, $ei, $bi, $po, $eo, $bo) = split(' ', $_);
						}
						last;
					}
				}
				close(IN);
			} elsif($config->{os} eq "OpenBSD" || $config->{os} eq "NetBSD") {
				open(IN, "netstat -nibd |");
				while(<IN>) {
					if(/Link/ && /^$nl[$n]/) {
						(undef, undef, undef, undef, $bi, $bo) = split(' ', $_);
						$pi = 0;
						$ei = 0;
						$po = 0;
						$eo = 0;
						last;
					}
				}
				close(IN);
			}
		}
		chomp($bi, $bo, $pi, $po, $ei, $eo);

		$str = $n . "_bytes_in";
		$bytes_in = $bi - ($config->{net_hist}->{$str} || 0);
		$bytes_in = 0 unless $bytes_in != $bi;
		$config->{net_hist}->{$str} = $bi;
		$bytes_in /= 60;

		$str = $n . "_bytes_out";
		$bytes_out = $bo - ($config->{net_hist}->{$str} || 0);
		$bytes_out = 0 unless $bytes_out != $bo;
		$config->{net_hist}->{$str} = $bo;
		$bytes_out /= 60;

		$str = $n . "_packs_in";
		$packs_in = $pi - ($config->{net_hist}->{$str} || 0);
		$packs_in = 0 unless $packs_in != $pi;
		$config->{net_hist}->{$str} = $pi;
		$packs_in /= 60;

		$str = $n . "_packs_out";
		$packs_out = $po - ($config->{net_hist}->{$str} || 0);
		$packs_out = 0 unless $packs_out != $po;
		$config->{net_hist}->{$str} = $po;
		$packs_out /= 60;

		$str = $n . "_error_in";
		$error_in = $ei - ($config->{net_hist}->{$str} || 0);
		$error_in = 0 unless $error_in != $ei;
		$config->{net_hist}->{$str} = $ei;
		$error_in /= 60;

		$str = $n . "_error_out";
		$error_out = $eo - ($config->{net_hist}->{$str} || 0);
		$error_out = 0 unless $error_out != $eo;
		$config->{net_hist}->{$str} = $eo;
		$error_out /= 60;


		$rrdata .= ":$bytes_in:$bytes_out:$packs_in:$packs_out:$error_in:$error_out";
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub net_cgi {
	my ($package, $config, $cgi) = @_;

	my $net = $config->{net};
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
	my @riglim;
	my $netname;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $T = "B";
	my $vlabel = "bytes/s";
	my $n;
	my $str;
	my $err;

	$version = "old" if $RRDs::VERSION < 1.3;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	$title = !$silent ? $title : "";

	if(lc($config->{netstats_in_bps}) eq "y") {
		$T = "b";
		$vlabel = "bits/s";
	}


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
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		print("       ");
		for($n = 0; $n < scalar(my @nl = split(',', $net->{list})); $n++) {
			$nl[$n] = trim($nl[$n]);
			my $nd = trim((split(',', $net->{desc}->{$nl[$n]}))[0]);
			print(trim($nl[$n]) . " ($nd)                          ");
		}
		print("\nTime");
		for($n = 0; $n < scalar(my @nl = split(',', $net->{list})); $n++) {
			print("   K$T/s_I  K$T/s_O  Pk/s_I  Pk/s_O  Er/s_I  Er/s_O");
		}
		print(" \n----");
		for($n = 0; $n < scalar(my @nl = split(',', $net->{list})); $n++) {
			print("-------------------------------------------------");
		}
		print " \n";
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			printf(" %2d$tf->{tc}", $time);
			for($n2 = 0; $n2 < scalar(my @nl = split(',', $net->{list})); $n2++) {
				$from = $n2 * 6;
				$to = $from + 6;
				my ($ki, $ko, $pi, $po, $ei, $eo) = @$line[$from..$to];
				$ki /= 1024;
				$ko /= 1024;
				$pi /= 1024;
				$po /= 1024;
				$ei /= 1024;
				$eo /= 1024;
				if(lc($config->{netstats_in_bps}) eq "y") {
					$ki *= 8;
					$ko *= 8;
				}
				@row = ($ki, $ko, $pi, $po, $ei, $eo);
				printf("   %6d  %6d  %6d  %6d  %6d  %6d", @row);
			}
			print(" \n");
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

	my $PNG1;
	my $PNG2;
	my $PNG3;
	my $PNG1z;
	my $PNG2z;
	my $PNG3z;
	for($n = 0; $n < scalar(my @nl = split(',', $net->{list})); $n++) {
		$PNG1 = $u . $package . $n . "1." . $tf->{when} . ".png";
		$PNG2 = $u . $package . $n . "2." . $tf->{when} . ".png";
		$PNG3 = $u . $package . $n . "3." . $tf->{when} . ".png";
		unlink("$PNG_DIR" . $PNG1);
		unlink("$PNG_DIR" . $PNG2);
		unlink("$PNG_DIR" . $PNG3);
		if(lc($config->{enable_zoom}) eq "y") {
			$PNG1z = $u . $package . $n . "1z." . $tf->{when} . ".png";
			$PNG2z = $u . $package . $n . "2z." . $tf->{when} . ".png";
			$PNG3z = $u . $package . $n . "3z." . $tf->{when} . ".png";
			unlink("$PNG_DIR" . $PNG1z);
			unlink("$PNG_DIR" . $PNG2z);
			unlink("$PNG_DIR" . $PNG3z);
		}

		$nl[$n] = trim($nl[$n]);
		my $nd = trim((split(',', $net->{desc}->{$nl[$n]}))[0]);
		my $rigid = trim((split(',', $net->{desc}->{$nl[$n]}))[1]);
		my $limit = trim((split(',', $net->{desc}->{$nl[$n]}))[2]);

		if($title) {
			if($n) {
				print("    <br>\n");
			}
			main::graph_header($nl[$n] . " " . $title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$colors->{title_bg_color}'>\n");
		}

		@riglim = @{setup_riglim($rigid, $limit)};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:B_in#44EE44:K$T/s Input");
		push(@tmp, "GPRINT:K_in:LAST:     Current\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:AVERAGE: Average\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:MIN:    Min\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:MAX:    Max\\: %5.0lf\\n");
		push(@tmp, "AREA:B_out#4444EE:K$T/s Output");
		push(@tmp, "GPRINT:K_out:LAST:    Current\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:AVERAGE: Average\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:MIN:    Min\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:MAX:    Max\\: %5.0lf\\n");
		push(@tmp, "AREA:B_out#4444EE:");
		push(@tmp, "AREA:B_in#44EE44:");
		push(@tmp, "LINE1:B_out#0000EE");
		push(@tmp, "LINE1:B_in#00EE00");
		push(@tmpz, "AREA:B_in#44EE44:Input");
		push(@tmpz, "AREA:B_out#4444EE:Output");
		push(@tmpz, "AREA:B_out#4444EE:");
		push(@tmpz, "AREA:B_in#44EE44:");
		push(@tmpz, "LINE1:B_out#0000EE");
		push(@tmpz, "LINE1:B_in#00EE00");
		if(lc($config->{netstats_in_bps}) eq "y") {
			push(@CDEF, "CDEF:B_in=in,8,*");
			push(@CDEF, "CDEF:B_out=out,8,*");
		} else {
			push(@CDEF, "CDEF:B_in=in");
			push(@CDEF, "CDEF:B_out=out");
		}
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
		}
		$pic = $rrd{$version}->("$PNG_DIR" . "$PNG1",
			"--title=$nl[$n] $nd  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:in=$rrd:net" . $n . "_bytes_in:AVERAGE",
			"DEF:out=$rrd:net" . $n . "_bytes_out:AVERAGE",
			"CDEF:allvalues=in,out,+",
			@CDEF,
			"CDEF:K_in=B_in,1024,/",
			"CDEF:K_out=B_out,1024,/",
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			"COMMENT: \\n",
			);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$PNG_DIR" . "$PNG1z",
				"--title=$nl[$n] $nd  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:in=$rrd:net" . $n . "_bytes_in:AVERAGE",
				"DEF:out=$rrd:net" . $n . "_bytes_out:AVERAGE",
				"CDEF:allvalues=in,out,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
		}
		$netname="net" . $n . "1";
		if($title || ($silent =~ /imagetag/ && $graph =~ /$netname/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
				}
				else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
		}
		@riglim = @{setup_riglim($rigid, $limit)};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:p_in#44EE44:Input");
		push(@tmp, "AREA:p_out#4444EE:Output");
		push(@tmp, "AREA:p_out#4444EE:");
		push(@tmp, "AREA:p_in#44EE44:");
		push(@tmp, "LINE1:p_out#0000EE");
		push(@tmp, "LINE1:p_in#00EE00");
		push(@tmpz, "AREA:p_in#44EE44:Input");
		push(@tmpz, "AREA:p_out#4444EE:Output");
		push(@tmpz, "AREA:p_out#4444EE:");
		push(@tmpz, "AREA:p_in#44EE44:");
		push(@tmpz, "LINE1:p_out#0000EE");
		push(@tmpz, "LINE1:p_in#00EE00");
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
		$pic = $rrd{$version}->("$PNG_DIR" . "$PNG2",
			"--title=$nl[$n] $config->{graphs}->{_net2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Packets/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:p_in=$rrd:net" . $n . "_packs_in:AVERAGE",
			"DEF:p_out=$rrd:net" . $n . "_packs_out:AVERAGE",
			"CDEF:allvalues=p_in,p_out,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$PNG_DIR" . "$PNG2z",
				"--title=$nl[$n] $config->{graphs}->{_net2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=Packets/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:p_in=$rrd:net" . $n . "_packs_in:AVERAGE",
				"DEF:p_out=$rrd:net" . $n . "_packs_out:AVERAGE",
				"CDEF:allvalues=p_in,p_out,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
		}
		$netname="net" . $n . "2";
		if($title || ($silent =~ /imagetag/ && $graph =~ /$netname/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
				}
				else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid, $limit)};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:e_in#44EE44:Input");
		push(@tmp, "AREA:e_out#4444EE:Output");
		push(@tmp, "AREA:e_out#4444EE:");
		push(@tmp, "AREA:e_in#44EE44:");
		push(@tmp, "LINE1:e_out#0000EE");
		push(@tmp, "LINE1:e_in#00EE00");
		push(@tmpz, "AREA:e_in#44EE44:Input");
		push(@tmpz, "AREA:e_out#4444EE:Output");
		push(@tmpz, "AREA:e_out#4444EE:");
		push(@tmpz, "AREA:e_in#44EE44:");
		push(@tmpz, "LINE1:e_out#0000EE");
		push(@tmpz, "LINE1:e_in#00EE00");
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
		$pic = $rrd{$version}->("$PNG_DIR" . "$PNG3",
			"--title=$nl[$n] $config->{graphs}->{_net3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Errors/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:e_in=$rrd:net" . $n . "_error_in:AVERAGE",
			"DEF:e_out=$rrd:net" . $n . "_error_out:AVERAGE",
			"CDEF:allvalues=e_in,e_out,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$PNG_DIR" . "$PNG3z",
				"--title=$nl[$n] $config->{graphs}->{_net3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=Errors/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:e_in=$rrd:net" . $n . "_error_in:AVERAGE",
				"DEF:e_out=$rrd:net" . $n . "_error_out:AVERAGE",
				"CDEF:allvalues=e_in,e_out,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
		}
		$netname="net" . $n . "3";
		if($title || ($silent =~ /imagetag/ && $graph =~ /$netname/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
				}
				else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			main::graph_footer();
		}
	}
	print("  <br>\n");
	return;
}
1;
