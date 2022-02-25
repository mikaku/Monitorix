#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2022 by Jordi Sanfeliu <jordi@fibranet.cat>
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

package nut;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(nut_init nut_update nut_cgi);

sub nut_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nut = $config->{nut};

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
		if(scalar(@ds) / 21 != scalar(my @il = split(',', $nut->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @il = split(',', $nut->{list})) . ") and $rrd (" . scalar(@ds) / 21 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @il = split(',', $nut->{list})); $n++) {
			push(@tmp, "DS:nut" . $n . "_ltran:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_htran:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_ivolt:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_ovolt:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_bchar:GAUGE:120:0:100");
			push(@tmp, "DS:nut" . $n . "_loadc:GAUGE:120:0:100");
			push(@tmp, "DS:nut" . $n . "_mbatc:GAUGE:120:0:100");
			push(@tmp, "DS:nut" . $n . "_nxfer:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_atemp:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_itemp:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_humid:GAUGE:120:0:100");
			push(@tmp, "DS:nut" . $n . "_battv:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_nomba:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_timel:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_minti:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_linef:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_val01:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_val02:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_val03:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_val04:GAUGE:120:0:U");
			push(@tmp, "DS:nut" . $n . "_val05:GAUGE:120:0:U");
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

	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub nut_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nut = $config->{nut};

	my $n;
	my $rrdata = "N";

	my $use_nan_for_missing_data = lc($nut->{use_nan_for_missing_data} || "") eq "y" ? 1 : 0;
	my $ignore_error_output = lc($nut->{ignore_error_output} || "") eq "y" ? 1 : 0;

	my $e = 0;
	foreach my $ups (my @nl = split(',', $nut->{list})) {
		my $default_value = $use_nan_for_missing_data ? (0+"nan") : 0;

		my $ltran = $default_value;
		my $htran = $default_value;
		my $ivolt = $default_value;
		my $ovolt = $default_value;
		my $bchar = $default_value;
		my $loadc = $default_value;
		my $mbatc = $default_value;
		my $nxfer = $default_value;
		my $atemp = $default_value;
		my $itemp = $default_value;
		my $humid = $default_value;
		my $battv = $default_value;
		my $nomba = $default_value;
		my $timel = $default_value;
		my $minti = $default_value;
		my $linef = $default_value;
		my $val01 = $default_value;
		my $val02 = $default_value;
		my $val03 = $default_value;
		my $val04 = $default_value;
		my $val05 = $default_value;

		my $data;
		my $upsc_cmd = "upsc $ups";
		if ($ignore_error_output) {
			$upsc_cmd .= " 2>/dev/null";
		}
		if(open(PIPE, "$upsc_cmd |")) {
			while(<PIPE>) { $data .= $_; }
			close(PIPE);
		}

		if(!$data) {
			logger("$myself: unable to execute '$upsc_cmd' command or invalid connection.");
			$rrdata .= ":$ltran:$htran:$ivolt:$ovolt:$bchar:$loadc:$mbatc:$nxfer:$atemp:$itemp:$humid:$battv:$nomba:$timel:$minti:$linef:$default_value:$default_value:$default_value:$default_value:$default_value";
			next;
		}

		foreach(my @l = split('\n', $data)) {
			if(/^input\.transfer\.low:\s+(\d+\.?\d*)/) {
				$ltran = $1;
			}
			if(/^input\.transfer\.high:\s+(\d+\.?\d*)/) {
				$htran = $1;
			}
			if(/^input\.voltage:\s+(\d+\.?\d*)/) {
				$ivolt = $1;
			}
			if(/^output\.voltage:\s+(\d+\.?\d*)/) {
				$ovolt = $1;
			}
			if(/^battery\.charge:\s+(\d+)/) {
				$bchar = $1;
			}
			if(/^ups\.load:\s+(\d+)/) {
				$loadc = $1;
			}
			if(/^battery\.charge\.low:\s+(\d+)/) {
				$mbatc = $1;
			}
			# nxfer
			if(/^ambient\.temperature:\s+(\d+\.?\d*)/) {
				$atemp = $1;
			}
			if(/^ups\.temperature:\s+(\d+\.?\d*)/) {
				$itemp = $1;
			}
			if(/^ambient\.humidity:\s+(\d+\.?\d*)/) {
				$humid = $1;
			}
			if(/^battery\.voltage:\s+(\d+\.?\d*)/) {
				$battv = $1;
			}
			if(/^battery\.voltage\.nominal:\s+(\d+\.?\d*)/) {
				$nomba = $1;
			}
			if(/^battery\.runtime:\s+(\d+)/) {
				$timel = $1;
			}
			if(/^battery\.runtime\.low:\s+(\d+)/) {
				$minti = $1;
			}
			if(/^input\.frequency:\s+(\d+\.?\d*)/) {
				$linef = $1;
			}
		}
		$rrdata .= ":$ltran:$htran:$ivolt:$ovolt:$bchar:$loadc:$mbatc:$nxfer:$atemp:$itemp:$humid:$battv:$nomba:$timel:$minti:$linef:0:0:0:0:0";
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub nut_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $nut = $config->{nut};
	my @rigid = split(',', ($nut->{rigid} || ""));
	my @limit = split(',', ($nut->{limit} || ""));
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
	my @full_size_mode;
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
	my @IMG;
	my @IMGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $e;
	my $e2;
	my $n;
	my $n2;
	my $str;
	my $err;

	$version = "old" if $RRDs::VERSION < 1.3;
	push(@full_size_mode, "--full-size-mode") if $RRDs::VERSION > 1.3;
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

	my $gap_on_all_nan = lc($nut->{gap_on_all_nan} || "") eq "y" ? 1 : 0;
	my $ignore_error_output = lc($nut->{ignore_error_output} || "") eq "y" ? 1 : 0;

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
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		for($n = 0; $n < scalar(my @pl = split(',', $nut->{list})); $n++) {
			$line1 .= "    LTrans HTrans InputV OutpuV BCharg  BLoad ShutLv ATemp ITemp Humid Voltag Nomina TimeLf ShutLv Freqcy";
			$line2 .= "---------------------------------------------------------------------------------------------------------";
			if($line2) {
				my $i = length($line2);
				push(@output, sprintf(sprintf("%${i}s", sprintf("%s", trim($pl[$n])))));
			}
		}
		push(@output, "\n");
		push(@output, "Time$line1\n");
		push(@output, "----$line2 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc}", $time));
			for($n2 = 0; $n2 < scalar(my @pl = split(',', $nut->{list})); $n2++) {
				undef(@row);
				$from = $n2 * 21;
				$to = $from + 21;
				my ($ltran, $htran, $ivolt, $ovolt, $bchar, $loadc, $mbatc, undef, $atemp, $itemp, $humid, $battv, $nomba, $timel, $minti, $linef) = @$line[$from..$to];
				$itemp = celsius_to($config, $itemp);
				$atemp = celsius_to($config, $atemp);
				push(@output, sprintf("    %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f %5.1f %5.1f %5.1f %6.1f %6.1f %6.1f %6.1f %6.1f", $ltran || 0, $htran || 0, $ivolt || 0, $ovolt || 0, $bchar || 0, $loadc || 0, $mbatc || 0, $atemp || 0, $itemp || 0, $humid || 0, $battv || 0, $nomba || 0, $timel || 0, $minti || 0, $linef || 0));
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

	for($n = 0; $n < scalar(my @nl = split(',', $nut->{list})); $n++) {
		for($n2 = 1; $n2 <= 6; $n2++) {
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

	$e = 0;
	foreach my $ups (my @nl = split(',', $nut->{list})) {

		my $data;
		my $upsc_cmd = "upsc $ups";
		if ($ignore_error_output) {
			$upsc_cmd .= " 2>/dev/null";
		}
		if(open(PIPE, "$upsc_cmd |")) {
			while(<PIPE>) { $data .= $_; }
			close(PIPE);
		}

		next if !$data;

		my $driver = "";
		my $model = "";
		my $status = "";
		my $transfer = "";
		foreach(my @l = split('\n', $data)) {
			if(/^driver\.name:\s+(.*?)$/) {
				$driver = trim($1);
				next;
			}
			if(/^device\.mfr:\s+(.*?)$/) {
				$model = trim($1);
				next;
			}
			if(/^device\.model:\s+(.*?)$/) {
				$model .= " " . trim($1);
				next;
			}
			if(/^ups\.status:\s+(.*?)$/) {
				$status = trim($1);
				next;
			}
			if(/^input\.transfer\.reason:\s+(\d+)$/) {
				$transfer = trim($1);
				next;
			}
		}
		if($RRDs::VERSION > 1.2) {
			$driver = "COMMENT: $driver\\: $model ($status)\\c",
			$transfer = "COMMENT: Reason for last transfer to battery\\: $transfer\\c",
		} else {
			$driver = "COMMENT: $driver: $model ($status)\\c",
			$transfer = "COMMENT: Reason for last transfer to battery: $transfer\\c",
		}

		if($e) {
			push(@output, "  <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}
		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:htran#EE4444:High input transfer");
		push(@tmp, "GPRINT:htran:LAST:   Cur\\: %5.1lf");
		push(@tmp, "GPRINT:htran:AVERAGE:  Avg\\: %5.1lf");
		push(@tmp, "GPRINT:htran:MIN:  Min\\: %5.1lf");
		push(@tmp, "GPRINT:htran:MAX:  Max\\: %5.1lf\\n");
		push(@tmp, "LINE2:ivolt#44EE44:Input voltage");
		push(@tmp, "GPRINT:ivolt:LAST:         Cur\\: %5.1lf");
		push(@tmp, "GPRINT:ivolt:AVERAGE:  Avg\\: %5.1lf");
		push(@tmp, "GPRINT:ivolt:MIN:  Min\\: %5.1lf");
		push(@tmp, "GPRINT:ivolt:MAX:  Max\\: %5.1lf\\n");
		push(@tmp, "LINE2:ovolt#4444EE:Output voltage");
		push(@tmp, "GPRINT:ovolt:LAST:        Cur\\: %5.1lf");
		push(@tmp, "GPRINT:ovolt:AVERAGE:  Avg\\: %5.1lf");
		push(@tmp, "GPRINT:ovolt:MIN:  Min\\: %5.1lf");
		push(@tmp, "GPRINT:ovolt:MAX:  Max\\: %5.1lf\\n");
		push(@tmp, "LINE2:ltran#EE4444:Low input transfer");
		push(@tmp, "GPRINT:ltran:LAST:    Cur\\: %5.1lf");
		push(@tmp, "GPRINT:ltran:AVERAGE:  Avg\\: %5.1lf");
		push(@tmp, "GPRINT:ltran:MIN:  Min\\: %5.1lf");
		push(@tmp, "GPRINT:ltran:MAX:  Max\\: %5.1lf\\n");
		push(@tmpz, "LINE2:htran#EE4444:High input transfer");
		push(@tmpz, "LINE2:ivolt#44EE44:Input voltage");
		push(@tmpz, "LINE2:ovolt#4444EE:Output voltage");
		push(@tmpz, "LINE2:ltran#EE4444:Low input transfer");
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
		}
		my $cdef_allvalues_volt = $gap_on_all_nan ? "CDEF:allvalues=ltran,UN,0,1,IF,htran,UN,0,1,IF,ivolt,UN,0,1,IF,ovolt,UN,0,1,IF,+,+,+,0,GT,1,UNKN,IF" : "CDEF:allvalues=ltran,htran,ivolt,ovolt,+,+,+";
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6]",
			"--title=$config->{graphs}->{_nut1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Volts",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:ltran=$rrd:nut" . $e . "_ltran:AVERAGE",
			"DEF:htran=$rrd:nut" . $e . "_htran:AVERAGE",
			"DEF:ivolt=$rrd:nut" . $e . "_ivolt:AVERAGE",
			"DEF:ovolt=$rrd:nut" . $e . "_ovolt:AVERAGE",
			$cdef_allvalues_volt,
			@CDEF,
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			$driver);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6]",
				"--title=$config->{graphs}->{_nut1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Volts",
				"--width=$width",
				"--height=$height",
				@full_size_mode,
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:ltran=$rrd:nut" . $e . "_ltran:AVERAGE",
				"DEF:htran=$rrd:nut" . $e . "_htran:AVERAGE",
				"DEF:ivolt=$rrd:nut" . $e . "_ivolt:AVERAGE",
				"DEF:ovolt=$rrd:nut" . $e . "_ovolt:AVERAGE",
				$cdef_allvalues_volt,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /nut$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6], IMG => $IMG[$e * 6]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      " . picz_js_a_element(width => $picz_width, height => $picz_height, config => $config, IMGz => $IMGz[$e * 6], IMG => $IMG[$e * 6]) . "\n");
				}
			} else {
				push(@output, "      " . img_element(config => $config, IMG => $IMG[$e * 6]) . "\n");
			}
		}

		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:bchar#4444EE:Charge");
		push(@tmp, "GPRINT:bchar:LAST:             Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:bchar:AVERAGE:   Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:bchar:MIN:   Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:bchar:MAX:   Max\\: %4.1lf%%\\n");
		push(@tmp, "AREA:loadc#EE4444:Load capacity");
		push(@tmp, "GPRINT:loadc:LAST:      Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:loadc:AVERAGE:   Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:loadc:MIN:   Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:loadc:MAX:   Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE1:bchar#0000EE");
		push(@tmp, "LINE1:loadc#EE0000");
		push(@tmp, "LINE2:mbatc#EEEE44:Shutdown level");
		push(@tmp, "GPRINT:mbatc:LAST:     Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:mbatc:AVERAGE:   Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:mbatc:MIN:   Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:mbatc:MAX:   Max\\: %4.1lf%%\\n");
		push(@tmpz, "AREA:bchar#4444EE:Charge");
		push(@tmpz, "AREA:loadc#EE4444:Load");
		push(@tmpz, "LINE2:mbatc#EEEE44:Shutdown level");
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
		}
		my $cdef_allvalues_bat = $gap_on_all_nan ? "CDEF:allvalues=bchar,UN,0,1,IF,mbatc,UN,0,1,IF,loadc,UN,0,1,IF,+,+,0,GT,1,UNKN,IF" : "CDEF:allvalues=bchar,mbatc,loadc,+,+";
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 1]",
			"--title=$config->{graphs}->{_nut2}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:bchar=$rrd:nut" . $e . "_bchar:AVERAGE",
			"DEF:loadc=$rrd:nut" . $e . "_loadc:AVERAGE",
			"DEF:mbatc=$rrd:nut" . $e . "_mbatc:AVERAGE",
			$cdef_allvalues_bat,
			@CDEF,
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			$transfer,
			"COMMENT: \\n");
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 1]",
				"--title=$config->{graphs}->{_nut2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Percent (%)",
				"--width=$width",
				"--height=$height",
				@full_size_mode,
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:bchar=$rrd:nut" . $e . "_bchar:AVERAGE",
				"DEF:loadc=$rrd:nut" . $e . "_loadc:AVERAGE",
				"DEF:mbatc=$rrd:nut" . $e . "_mbatc:AVERAGE",
				$cdef_allvalues_bat,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /nut$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6 + 1], IMG => $IMG[$e * 6 + 1]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      " . picz_js_a_element(width => $picz_width, height => $picz_height, config => $config, IMGz => $IMGz[$e * 6 + 1], IMG => $IMG[$e * 6 + 1]) . "\n");
				}
			} else {
				push(@output, "      " . img_element(config => $config, IMG => $IMG[$e * 6 + 1]) . "\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}

		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:_itemp#44EEEE:Internal");
		push(@tmp, "GPRINT:_itemp:LAST:             Current\\: %4.1lf\\n");
		push(@tmp, "LINE2:_atemp#4444EE:Ambient");
		push(@tmp, "GPRINT:_atemp:LAST:              Current\\: %4.1lf\\n");
		push(@tmp, "GPRINT:humid:LAST:                        Humidity\\: %4.1lf%%\\n");
		push(@tmpz, "LINE2:_itemp#44EEEE:Internal");
		push(@tmpz, "LINE2:_atemp#4444EE:Ambient");
		if(lc($config->{temperature_scale}) eq "f") {
			push(@CDEF, "CDEF:_itemp=9,5,/,itemp,*,32,+");
			push(@CDEF, "CDEF:_atemp=9,5,/,atemp,*,32,+");
		} else {
			push(@CDEF, "CDEF:_itemp=itemp");
			push(@CDEF, "CDEF:_atemp=atemp");
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
		my $cdef_allvalues_temp = $gap_on_all_nan ? "CDEF:allvalues=itemp,UN,0,1,IF,atemp,UN,0,1,IF,humid,UN,0,1,IF,+,+,0,GT,1,UNKN,IF" : "CDEF:allvalues=itemp,atemp,humid,+,+";
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 2]",
			"--title=$config->{graphs}->{_nut3}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:itemp=$rrd:nut" . $e . "_itemp:AVERAGE",
			"DEF:atemp=$rrd:nut" . $e . "_atemp:AVERAGE",
			"DEF:humid=$rrd:nut" . $e . "_humid:AVERAGE",
			$cdef_allvalues_temp,
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 2]",
				"--title=$config->{graphs}->{_nut3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=$temp_scale",
				"--width=$width",
				"--height=$height",
				@full_size_mode,
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:itemp=$rrd:nut" . $e . "_itemp:AVERAGE",
				"DEF:atemp=$rrd:nut" . $e . "_atemp:AVERAGE",
				"DEF:humid=$rrd:nut" . $e . "_humid:AVERAGE",
				$cdef_allvalues_temp,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /nut$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6 + 2], IMG => $IMG[$e * 6 + 2]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      " . picz_js_a_element(width => $picz_width, height => $picz_height, config => $config, IMGz => $IMGz[$e * 6 + 2], IMG => $IMG[$e * 6 + 2]) . "\n");
				}
			} else {
				push(@output, "      " . img_element(config => $config, IMG => $IMG[$e * 6 + 2]) . "\n");
			}
		}

		@riglim = @{setup_riglim($rigid[3], $limit[3])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:battv#44EEEE:Voltage");
		push(@tmp, "GPRINT:battv:LAST:              Current\\: %4.1lf\\n");
		push(@tmp, "LINE2:nomba#4444EE:Nominal");
		push(@tmp, "GPRINT:nomba:LAST:              Current\\: %4.1lf\\n");
		push(@tmpz, "LINE2:battv#44EEEE:Voltage");
		push(@tmpz, "LINE2:nomba#4444EE:Nominal");
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
		my $cdef_allvalues_batvolt = $gap_on_all_nan ? "CDEF:allvalues=battv,UN,0,1,IF,nomba,UN,0,1,IF,+,0,GT,1,UNKN,IF" : "CDEF:allvalues=battv,nomba,+";
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 3]",
			"--title=$config->{graphs}->{_nut4}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:battv=$rrd:nut" . $e . "_battv:AVERAGE",
			"DEF:nomba=$rrd:nut" . $e . "_nomba:AVERAGE",
			$cdef_allvalues_batvolt,
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 3]",
				"--title=$config->{graphs}->{_nut4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Volts",
				"--width=$width",
				"--height=$height",
				@full_size_mode,
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:battv=$rrd:nut" . $e . "_battv:AVERAGE",
				"DEF:nomba=$rrd:nut" . $e . "_nomba:AVERAGE",
				$cdef_allvalues_batvolt,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 3]: $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /nut$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6 + 3], IMG => $IMG[$e * 6 + 3]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      " . picz_js_a_element(width => $picz_width, height => $picz_height, config => $config, IMGz => $IMGz[$e * 6 + 3], IMG => $IMG[$e * 6 + 3]) . "\n");
				}
			} else {
				push(@output, "      " . img_element(config => $config, IMG => $IMG[$e * 6 + 3]) . "\n");
			}
		}

		@riglim = @{setup_riglim($rigid[4], $limit[4])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:timel_min#44EEEE:Minutes left");
		push(@tmp, "GPRINT:timel_min:LAST:         Current\\: %3.0lf\\n");
		push(@tmp, "LINE2:minti_min#EEEE44:Shutdown level");
		push(@tmp, "GPRINT:minti_min:LAST:       Current\\: %3.0lf\\n");
		push(@tmpz, "LINE2:timel_min#44EEEE:Minutes left");
		push(@tmpz, "LINE2:minti_min#EEEE44:Shutdown level");
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
		my $cdef_allvalues_timeleft = $gap_on_all_nan ? "CDEF:allvalues=timel,UN,0,1,IF,minti,UN,0,1,IF,+,0,GT,1,UNKN,IF" : "CDEF:allvalues=timel,minti,+";
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 4]",
			"--title=$config->{graphs}->{_nut5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Minutes",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:timel=$rrd:nut" . $e . "_timel:AVERAGE",
			"DEF:minti=$rrd:nut" . $e . "_minti:AVERAGE",
			$cdef_allvalues_timeleft,
			"CDEF:timel_min=timel,60,/",
			"CDEF:minti_min=minti,60,/",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 4]",
				"--title=$config->{graphs}->{_nut5}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Minutes",
				"--width=$width",
				"--height=$height",
				@full_size_mode,
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:timel=$rrd:nut" . $e . "_timel:AVERAGE",
				"DEF:minti=$rrd:nut" . $e . "_minti:AVERAGE",
				$cdef_allvalues_timeleft,
				"CDEF:timel_min=timel,60,/",
				"CDEF:minti_min=minti,60,/",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 4]: $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /nut$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6 + 4], IMG => $IMG[$e * 6 + 4]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      " . picz_js_a_element(width => $picz_width, height => $picz_height, config => $config, IMGz => $IMGz[$e * 6 + 4], IMG => $IMG[$e * 6 + 4]) . "\n");
				}
			} else {
				push(@output, "      " . img_element(config => $config, IMG => $IMG[$e * 6 + 4]) . "\n");
			}
		}

		@riglim = @{setup_riglim($rigid[5], $limit[5])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:linef#EE44EE:Frequency");
		push(@tmp, "GPRINT:linef:LAST:            Current\\: %1.0lf\\n");
		push(@tmpz, "LINE2:linef#EE44EE:Frequency");
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
		my $cdef_allvalues_freq = $gap_on_all_nan ? "CDEF:allvalues=linef,UN,0,1,IF,0,GT,1,UNKN,IF" : "CDEF:allvalues=linef";
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 5]",
			"--title=$config->{graphs}->{_nut6}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Hz",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:linef=$rrd:nut" . $e . "_linef:AVERAGE",
			$cdef_allvalues_freq,
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 5]",
				"--title=$config->{graphs}->{_nut6}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Hz",
				"--width=$width",
				"--height=$height",
				@full_size_mode,
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:linef=$rrd:nut" . $e . "_linef:AVERAGE",
				$cdef_allvalues_freq,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 5]: $err\n") if $err;
		}
		$e2 = $e + 6;
		if($title || ($silent =~ /imagetag/ && $graph =~ /nut$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6 + 5], IMG => $IMG[$e * 6 + 5]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      " . picz_js_a_element(width => $picz_width, height => $picz_height, config => $config, IMGz => $IMGz[$e * 6 + 5], IMG => $IMG[$e * 6 + 5]) . "\n");
				}
			} else {
				push(@output, "      " . img_element(config => $config, IMG => $IMG[$e * 6 + 5]) . "\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");

			push(@output, "    <tr>\n");
			push(@output, "      <td class='td-title' colspan='2'>\n");
			push(@output, "       <font size='-1'>\n");
			push(@output, "        <b>&nbsp;&nbsp;" . trim($ups) . "</b>\n");
			push(@output, "       </font>\n");
			push(@output, "      </td>\n");
			push(@output, "    </tr>\n");
			push(@output, main::graph_footer());
		}
		$e++;
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
