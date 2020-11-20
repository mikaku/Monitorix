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

package raspberrypi;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(raspberrypi_init raspberrypi_update raspberrypi_cgi);

sub raspberrypi_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $raspberrypi = $config->{raspberrypi};

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	if(! -e "$raspberrypi->{cmd}") {
		logger("$myself: '$raspberrypi->{cmd}' not found or is not executable. $!");
		return;
	}

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
				"DS:rpi_clock0:GAUGE:120:0:U",
				"DS:rpi_clock1:GAUGE:120:0:U",
				"DS:rpi_clock2:GAUGE:120:0:U",
				"DS:rpi_clock3:GAUGE:120:0:U",
				"DS:rpi_clock4:GAUGE:120:0:U",
				"DS:rpi_clock5:GAUGE:120:0:U",
				"DS:rpi_clock6:GAUGE:120:0:U",
				"DS:rpi_clock7:GAUGE:120:0:U",
				"DS:rpi_clock8:GAUGE:120:0:U",
				"DS:rpi_temp0:GAUGE:120:0:100",
				"DS:rpi_temp1:GAUGE:120:0:100",
				"DS:rpi_temp2:GAUGE:120:0:100",
				"DS:rpi_volt0:GAUGE:120:U:U",
				"DS:rpi_volt1:GAUGE:120:U:U",
				"DS:rpi_volt2:GAUGE:120:U:U",
				"DS:rpi_volt3:GAUGE:120:U:U",
				"DS:rpi_volt4:GAUGE:120:U:U",
				"DS:rpi_volt5:GAUGE:120:U:U",
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

	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub raspberrypi_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $raspberrypi = $config->{raspberrypi};

	my @clock = (0) x 9;
	my @temp = (0) x 3;
	my @volt = (0) x 6;

	my $n;
	my $rrdata = "N";

	$n = 0;
	foreach my $c (split(',', ($raspberrypi->{clocks} || ""))) {
		$c = trim($c);
		if(!open(IN, "$raspberrypi->{cmd} measure_clock $c |")) {
			logger("$myself: unable to execute '$raspberrypi->{cmd} measure_clock $c'. $!");
			next;
		}
		while(<IN>) {
			if(/^frequency\(\d+\)=(\d+)$/) {
				$clock[$n] = $1;
			}
		}
		close(IN);
		$n++;
	}

	if(!open(IN, "$raspberrypi->{cmd} measure_temp |")) {
		logger("$myself: unable to execute '$raspberrypi->{cmd} measure_temp'. $!");
	} else {
		while(<IN>) {
			if(/^temp=(\d+\.\d+)/) {
				$temp[0] = $1;
			}
		}
		$temp[1] = 0;
		$temp[2] = 0;
		close(IN);
	}

	$n = 0;
	foreach my $v (split(',', ($raspberrypi->{volts} || ""))) {
		$v = trim($v);
		if(!open(IN, "$raspberrypi->{cmd} measure_volts $v |")) {
			logger("$myself: unable to execute '$raspberrypi->{cmd} measure_volts $v'. $!");
			next;
		}
		while(<IN>) {
			if(/^volt=(\d+\.\d+)V$/) {
				$volt[$n] = $1;
			}
		}
		close(IN);
		$n++;
	}

	for($n = 0; $n < scalar(@clock); $n++) {
		$rrdata .= ":$clock[$n]";
	}
	for($n = 0; $n < scalar(@temp); $n++) {
		$rrdata .= ":$temp[$n]";
	}
	for($n = 0; $n < scalar(@volt); $n++) {
		$rrdata .= ":$volt[$n]";
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub raspberrypi_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $raspberrypi = $config->{raspberrypi};
	my @rigid = split(',', ($raspberrypi->{rigid} || ""));
	my @limit = split(',', ($raspberrypi->{limit} || ""));
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
	my $temp_scale = "Celsius";
	my @riglim;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $n;
	my $err;
	my @LC = (
		"#FFA500",
		"#44EEEE",
		"#44EE44",
		"#4444EE",
		"#448844",
		"#EE4444",
		"#EE44EE",
		"#EEEE44",
		"#444444",
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

	if(lc($config->{temperature_scale}) eq "f") {
		$temp_scale = "Fahrenheit";
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
		my $l;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		foreach my $c (split(',', ($raspberrypi->{clocks} || ""))) {
			$line2 .= sprintf(" %9s", substr(trim($c), 0, 9));
			$line3 .= "----------";
		}
		$l = length($line2) + 6;
		$line1 = sprintf("%${l}s", "Clocks");
		$line1 .= " Temperature";
		$line2 .= "        temp";
		$line3 .= "------------";
		$l = length($line2) + 6;
		foreach my $v (split(',', ($raspberrypi->{volts} || ""))) {
			$line2 .= sprintf(" %8s", substr(trim($v), 0, 8));
			$line3 .= "---------";
		}
		$l = length($line2) + 6 - $l;
		$line1 .= sprintf("%${l}s", "Voltages");
		push(@output, "$line1\n");
		push(@output, "Time  $line2 \n");
		push(@output, "------$line3\n");
		my $line;
		my @row;
		my $time;
		my @clock;
		my @temp;
		my @volt;
		for($l = 0, $time = $tf->{tb}; $l < ($tf->{tb} * $tf->{ts}); $l++) {
			$line1 = " %2d$tf->{tc}  ";
			undef(@row);
			$line = @$data[$l];
			(@clock[0..8], @temp[0..2], @volt[0..5]) = @$line;
			for($n = 0; $n < 9; $n++) {
				push(@row, celsius_to($config, $clock[$n]));
				$line1 .= " ";
				$line1 .= "%9d";
			}
			push(@row, celsius_to($config, $temp[0]));
			$line1 .= "      ";
			$line1 .= "%6.1f";
			$time = $time - (1 / $tf->{ts});
			for($n = 0; $n < 4; $n++) {
				push(@row, celsius_to($config, $volt[$n]));
				$line1 .= "   ";
				$line1 .= "%6.2f";
			}
			push(@output, sprintf("$line1 \n", $time, @row));
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

	my $IMG1 = $u . $package . "1." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2 = $u . $package . "2." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3 = $u . $package . "3." . $tf->{when} . ".$imgfmt_lc";
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
			"$IMG_DIR" . "$IMG2z",
			"$IMG_DIR" . "$IMG3z");
	}

	if($title) {
		push(@output, main::graph_header($title, 2));
	}

	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	$n = 0;
	foreach my $c (split(',', ($raspberrypi->{clocks} || ""))) {
		$c = trim($c);
		if($c) {
			my $str = sprintf("%-5s", substr($c, 0, 5));
			push(@CDEF, "CDEF:clk$n=clock$n,1000000,/");
			push(@tmp, "LINE2:clock$n" . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:clk$n:LAST: Cur\\: %6.1lfMhz");
			push(@tmp, "GPRINT:clk$n:AVERAGE:   Avg\\: %6.1lfMhz");
			push(@tmp, "GPRINT:clk$n:MIN:   Min\\: %6.1lfMhz");
			push(@tmp, "GPRINT:clk$n:MAX:   Max\\: %6.1lfMhz\\n");
			$str =~ s/\s+$//;
			push(@tmpz, "LINE2:clock$n" . $LC[$n] . ":$str");
		} else {
			push(@tmp, "COMMENT: \\n");
		}
		$n++;
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
	($width, $height) = split('x', $config->{graph_size}->{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG1",
		"--title=$config->{graphs}->{_raspberrypi1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Hz",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:clock0=$rrd:rpi_clock0:AVERAGE",
		"DEF:clock1=$rrd:rpi_clock1:AVERAGE",
		"DEF:clock2=$rrd:rpi_clock2:AVERAGE",
		"DEF:clock3=$rrd:rpi_clock3:AVERAGE",
		"DEF:clock4=$rrd:rpi_clock4:AVERAGE",
		"DEF:clock5=$rrd:rpi_clock5:AVERAGE",
		"DEF:clock6=$rrd:rpi_clock6:AVERAGE",
		"DEF:clock7=$rrd:rpi_clock7:AVERAGE",
		"DEF:clock8=$rrd:rpi_clock8:AVERAGE",
		"CDEF:allvalues=clock0,clock1,clock2,clock3,clock4,clock5,clock6,clock7,clock8,+,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_raspberrypi1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Hz",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:clock0=$rrd:rpi_clock0:AVERAGE",
			"DEF:clock1=$rrd:rpi_clock1:AVERAGE",
			"DEF:clock2=$rrd:rpi_clock2:AVERAGE",
			"DEF:clock3=$rrd:rpi_clock3:AVERAGE",
			"DEF:clock4=$rrd:rpi_clock4:AVERAGE",
			"DEF:clock5=$rrd:rpi_clock5:AVERAGE",
			"DEF:clock6=$rrd:rpi_clock6:AVERAGE",
			"DEF:clock7=$rrd:rpi_clock7:AVERAGE",
			"DEF:clock8=$rrd:rpi_clock8:AVERAGE",
			"CDEF:allvalues=clock0,clock1,clock2,clock3,clock4,clock5,clock6,clock7,clock8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /raspberrypi1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "'>\n");
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
	push(@tmp, "LINE2:temp_0#44AAEE:Temperature");
	push(@tmp, "GPRINT:temp_0:LAST:          Current\\: %4.1lf\\n");
	push(@tmpz, "LINE2:temp_0#44AAEE:Temperature");
	push(@tmp, "COMMENT: \\n");
	if(lc($config->{temperature_scale}) eq "f") {
		push(@CDEF, "CDEF:temp_0=9,5,/,temp0,*,32,+");
	} else {
		push(@CDEF, "CDEF:temp_0=temp0");
	}
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_raspberrypi2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=$temp_scale",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:temp0=$rrd:rpi_temp0:AVERAGE",
		"CDEF:allvalues=temp0",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_raspberrypi2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:temp0=$rrd:rpi_temp0:AVERAGE",
			"CDEF:allvalues=temp0",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /raspberrypi2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "'>\n");
		}
	}

	@riglim = @{setup_riglim($rigid[2], $limit[2])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	if(scalar(my @volts = split(',', ($raspberrypi->{volts} || "")))) {
		for($n = 0; $n < 4; $n++) {
			if($volts[$n]) {
				my $str = sprintf("%-10s", substr(trim($volts[$n]), 0, 10));
				push(@tmp, "LINE2:volt$n" . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:volt$n:LAST:           Current\\: %5.2lf\\n");
				$str =~ s/\s+$//;
				push(@tmpz, "LINE2:volt$n" . $LC[$n] . ":$str");
			} else {
				push(@tmp, "COMMENT: \\n");
			}
		}
	}
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
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG3",
		"--title=$config->{graphs}->{_raspberrypi3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Volts",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:volt0=$rrd:rpi_volt0:AVERAGE",
		"DEF:volt1=$rrd:rpi_volt1:AVERAGE",
		"DEF:volt2=$rrd:rpi_volt2:AVERAGE",
		"DEF:volt3=$rrd:rpi_volt3:AVERAGE",
		"CDEF:allvalues=volt0,volt1,volt2,volt3,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_raspberrypi3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Volts",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:volt0=$rrd:rpi_volt0:AVERAGE",
			"DEF:volt1=$rrd:rpi_volt1:AVERAGE",
			"DEF:volt2=$rrd:rpi_volt2:AVERAGE",
			"DEF:volt3=$rrd:rpi_volt3:AVERAGE",
			"CDEF:allvalues=volt0,volt1,volt2,volt3,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /raspberrypi3/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "'>\n");
		}
	}

	if($title) {
		push(@output, "    </td>\n");
		push(@output, "    </tr>\n");
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
