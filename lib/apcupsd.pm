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

package apcupsd;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(apcupsd_init apcupsd_update apcupsd_cgi);

sub apcupsd_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $apcupsd = $config->{apcupsd};

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
		if(scalar(@ds) / 22 != scalar(my @il = split(',', $apcupsd->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @il = split(',', $apcupsd->{list})) . ") and $rrd (" . scalar(@ds) / 22 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @il = split(',', $apcupsd->{list})); $n++) {
			push(@tmp, "DS:apcupsd" . $n . "_linev:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_loadc:GAUGE:120:0:100");
			push(@tmp, "DS:apcupsd" . $n . "_bchar:GAUGE:120:0:100");
			push(@tmp, "DS:apcupsd" . $n . "_timel:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_mbatc:GAUGE:120:0:100");
			push(@tmp, "DS:apcupsd" . $n . "_ovolt:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_ltran:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_htran:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_itemp:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_battv:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_linef:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_nxfer:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_nomov:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_minti:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_nomba:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_humid:GAUGE:120:0:100");
			push(@tmp, "DS:apcupsd" . $n . "_atemp:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_val01:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_val02:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_val03:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_val04:GAUGE:120:0:U");
			push(@tmp, "DS:apcupsd" . $n . "_val05:GAUGE:120:0:U");
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

sub apcupsd_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $apcupsd = $config->{apcupsd};

	my $n;
	my $rrdata = "N";

	my $use_nan_for_missing_data = lc($apcupsd->{use_nan_for_missing_data} || "") eq "y" ? 1 : 0;
	my $default_value = $use_nan_for_missing_data ? (0+"nan") : 0;

	my $e = 0;
	foreach(my @al = split(',', $apcupsd->{list})) {
		my $linev = $default_value;
		my $loadc = $default_value;
		my $bchar = $default_value;
		my $timel = $default_value;
		my $mbatc = $default_value;
		my $ovolt = $default_value;
		my $ltran = $default_value;
		my $htran = $default_value;
		my $itemp = $default_value;
		my $battv = $default_value;
		my $linef = $default_value;
		my $nxfer = $default_value;
		my $nomov = $default_value;
		my $minti = $default_value;
		my $nomba = $default_value;
		my $humid = $default_value;
		my $atemp = $default_value;
		my $val01 = $default_value;
		my $val02 = $default_value;
		my $val03 = $default_value;
		my $val04 = $default_value;
		my $val05 = $default_value;

		my $data;
		if(open(EXEC, $apcupsd->{cmd} . " status " . $al[$e] . " |")) {
			while(<EXEC>) { $data .= $_; }
			close(EXEC);
		}

		if(!$data) {
			logger("$myself: unable to execute '" . $apcupsd->{cmd} . "' command or invalid connection.");
			$rrdata .= ":U:U:U:U:U:U:U:U:U:U:U:U:U:U:U:U:U:U:U:U:U:U";
			next;
		}

		foreach(my @l = split('\n', $data)) {
			if(/^LINEV\s*:\s*(\d+\.\d+)\s+Volts/) {
				$linev = $1;
			}
			if(/^LOADPCT\s*:\s*(\d+\.\d+)\s+Percent/) {
				$loadc = $1;
			}
			if(/^BCHARGE\s*:\s*(\d+\.\d+)\s+Percent/) {
				$bchar = $1;
			}
			if(/^TIMELEFT\s*:\s*(\d+\.\d+)\s+Minutes/) {
				$timel = $1;
			}
			if(/^MBATTCHG\s*:\s*(\d+)\s+Percent/) {
				$mbatc = $1;
			}
			if(/^OUTPUTV\s*:\s*(\d+\.\d+)\s+Volts/) {
				$ovolt = $1;
			}
			if(/^LOTRANS\s*:\s*(\d+\.\d+)\s+Volts/) {
				$ltran = $1;
			}
			if(/^HITRANS\s*:\s*(\d+\.\d+)\s+Volts/) {
				$htran = $1;
			}
			if(/^ITEMP\s*:\s*(\d+\.\d+)\s+C/) {
				$itemp = $1;
			}
			if(/^BATTV\s*:\s*(\d+\.\d+)\s+Volts/) {
				$battv = $1;
			}
			if(/^LINEFREQ\s*:\s*(\d+\.\d+)\s+Hz/) {
				$linef = $1;
			}
			if(/^NUMXFERS\s*:\s*(\d+\.\d+)/) {
				$nxfer = $1;
			}
			if(/^NOMOUTV\s*:\s*(\d+)\s+Volts/) {
				$nomov = $1;
			}
			if(/^MINTIMEL\s*:\s*(\d+)\s+Minutes/) {
				$minti = $1;
			}
			if(/^NOMBATTV\s*:\s*(\d+\.\d+)\s+Volts/) {
				$nomba = $1;
			}
			if(/^HUMIDITY\s*:\s*(\d+\.\d+)\s+Percent/) {
				$humid = $1;
			}
			if(/^AMBTEMP\s*:\s*(\d+\.\d+)\s+C/) {
				$atemp = $1;
			}
		}
		$rrdata .= ":$linev:$loadc:$bchar:$timel:$mbatc:$ovolt:$ltran:$htran:$itemp:$battv:$linef:$nxfer:$nomov:$minti:$nomba:$humid:$atemp:0:0:0:0:0";
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub skipscale_string {
	my ($skipscale) = @_;
	if ($skipscale) {
		return ":skipscale";
	} else {
		return "";
	}
}

sub altscaling_options {
	my ($altscaling) = @_;
	my @scaling_options;
	if ($altscaling) {
		push(@scaling_options, "--alt-autoscale");
		push(@scaling_options, "--alt-y-grid");
	}
	return @scaling_options;
}

sub pad_string {
	my ($string_length, $string) = @_;
	return sprintf("%-" . $string_length . "s",$string);
}

sub apcupsd_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $apcupsd = $config->{apcupsd};
	my @rigid = split(',', ($apcupsd->{rigid} || ""));
	my @limit = split(',', ($apcupsd->{limit} || ""));
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};
	my $zoom = $config->{global_zoom};
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
	my $temp_scale = "Celsius";
	my @extra;
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

	my $gap_on_all_nan = lc($apcupsd->{gap_on_all_nan} || "") eq "y" ? 1 : 0;
	my $skipscale_for_transfer_voltage = lc($apcupsd->{skipscale_for_transfer_voltage} || "") eq "y" ? 1 : 0;
	my $skipscale_for_shutdown_level = lc($apcupsd->{skipscale_for_shutdown_level} || "") eq "y" ? 1 : 0;
	my $alt_scaling_for_voltage = lc($apcupsd->{alt_scaling_for_voltage} || "") eq "y" ? 1 : 0;
	my $alt_scaling_for_timeleft = lc($apcupsd->{alt_scaling_for_timeleft} || "") eq "y" ? 1 : 0;
	my $alt_scaling_for_battery_voltage = lc($apcupsd->{alt_scaling_for_battery_voltage} || "") eq "y" ? 1 : 0;

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
		for($n = 0; $n < scalar(my @pl = split(',', $apcupsd->{list})); $n++) {
			$line1 .= "    HTrans  LineV OutpuV LTrans BCharg  BLoad ShutLv ITemp ATemp Humid Voltag Nomina TimeLf ShutLv Freqcy";
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
			for($n2 = 0; $n2 < scalar(my @pl = split(',', $apcupsd->{list})); $n2++) {
				undef(@row);
				$from = $n2 * 22;
				$to = $from + 22;
				my ($linev, $loadc, $bchar, $timel, $mbatc, $ovolt, $ltran, $htran, $itemp, $battv, $linef, undef, undef, $minti, $nomba, $humid, $atemp) = @$line[$from..$to];
				$itemp = celsius_to($config, $itemp);
				$atemp = celsius_to($config, $atemp);
				push(@output, sprintf("    %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f %5.1f %5.1f %5.1f %6.1f %6.1f %6.1f %6.1f %6.1f", $htran || 0, $linev || 0, $ovolt || 0, $ltran || 0, $bchar || 0, $loadc || 0, $mbatc || 0, $itemp || 0, $atemp || 0, $humid || 0, $battv || 0, $nomba || 0, $timel || 0, $minti || 0, $linef || 0));
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
		$zoom = 1;	# force 'global_zoom' to 1 in Multihost viewer
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "_";
	}
	if($silent eq "imagetagbig") {
		$zoom = 1;	# force 'global_zoom' to 1 in Multihost viewer
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "";
	}
	my $global_zoom = "--zoom=" . $zoom;

	for($n = 0; $n < scalar(my @al = split(',', $apcupsd->{list})); $n++) {
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
	foreach my $url (my @al = split(',', $apcupsd->{list})) {

		my $data;
		if(open(EXEC, $apcupsd->{cmd} . " status " . $al[$e] . " |")) {
			while(<EXEC>) { $data .= $_; }
			close(EXEC);
		}

		next if !$data;

		my $driver = "";
		my $model = "";
		my $status = "";
		my $timeleft = "";
		my $numxfers = "";
		foreach(my @l = split('\n', $data)) {
			if(/^DRIVER\s*:\s*(.*?)$/) {
				$driver = trim($1);
				next;
			}
			if(/^MODEL\s*:\s*(.*?)$/) {
				$model = trim($1);
				next;
			}
			if(/^STATUS\s*:\s*(.*?)$/) {
				$status = trim($1);
				next;
			}
			if(/^TIMELEFT\s*:\s*(.*?)$/) {
				$timeleft = trim($1);
				next;
			}
			if(/^NUMXFERS\s*:\s*(\d+)$/) {
				$numxfers = trim($1);
				next;
			}
		}
		if($RRDs::VERSION > 1.2) {
			$driver = "COMMENT: $driver\\: $model ($status)\\c",
			$timeleft = "COMMENT: Number of transfers to batteries\\: $numxfers\\c",
		} else {
			$driver = "COMMENT: $driver: $model ($status)\\c",
			$timeleft = "COMMENT: Number of transfers to batteries: $numxfers\\c",
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
		push(@tmp, "LINE2:htran#EE4444:High transition" . skipscale_string($skipscale_for_transfer_voltage));
		push(@tmp, "GPRINT:htran:LAST: Current\\: %4.1lf");
		push(@tmp, "GPRINT:htran:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:htran:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:htran:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:linev#44EE44:Line");
		push(@tmp, "GPRINT:linev:LAST:            Current\\: %4.1lf");
		push(@tmp, "GPRINT:linev:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:linev:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:linev:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:ovolt#4444EE:Output");
		push(@tmp, "GPRINT:ovolt:LAST:          Current\\: %4.1lf");
		push(@tmp, "GPRINT:ovolt:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:ovolt:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:ovolt:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:ltran#EE4444:Low transition" . skipscale_string($skipscale_for_transfer_voltage));
		push(@tmp, "GPRINT:ltran:LAST:  Current\\: %4.1lf");
		push(@tmp, "GPRINT:ltran:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:ltran:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:ltran:MAX:   Max\\: %4.1lf\\n");
		push(@tmpz, "LINE2:htran#EE4444:High transition" . skipscale_string($skipscale_for_transfer_voltage));
		push(@tmpz, "LINE2:linev#44EE44:Line");
		push(@tmpz, "LINE2:ovolt#4444EE:Output");
		push(@tmpz, "LINE2:ltran#EE4444:Low transition");
		push(@tmpz, "LINE2:ltran#EE4444:Low transition" . skipscale_string($skipscale_for_transfer_voltage));

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
		my $cdef_allvalues_volt = $gap_on_all_nan ? "CDEF:allvalues=ltran,UN,0,1,IF,htran,UN,0,1,IF,linev,UN,0,1,IF,ovolt,UN,0,1,IF,+,+,+,0,GT,1,UNKN,IF" : "CDEF:allvalues=htran,linev,ovolt,ltran,+,+,+";
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6]",
			"--title=$config->{graphs}->{_apcupsd1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Volts",
			"--width=$width",
			"--height=$height",
			altscaling_options($alt_scaling_for_voltage),
			@extra,
			@riglim,
			$global_zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:htran=$rrd:apcupsd" . $e . "_htran:AVERAGE",
			"DEF:linev=$rrd:apcupsd" . $e . "_linev:AVERAGE",
			"DEF:ovolt=$rrd:apcupsd" . $e . "_ovolt:AVERAGE",
			"DEF:ltran=$rrd:apcupsd" . $e . "_ltran:AVERAGE",
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
				"--title=$config->{graphs}->{_apcupsd1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Volts",
				"--width=$width",
				"--height=$height",
				altscaling_options($alt_scaling_for_voltage),
				@full_size_mode,
				@extra,
				@riglim,
				$global_zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:htran=$rrd:apcupsd" . $e . "_htran:AVERAGE",
				"DEF:linev=$rrd:apcupsd" . $e . "_linev:AVERAGE",
				"DEF:ovolt=$rrd:apcupsd" . $e . "_ovolt:AVERAGE",
				"DEF:ltran=$rrd:apcupsd" . $e . "_ltran:AVERAGE",
				$cdef_allvalues_volt,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apcupsd$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6], IMG => $IMG[$e * 6]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $zoom;
						$picz_height = $picz->{image_height} * $zoom;
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
		push(@tmp, "GPRINT:bchar:LAST:          Current\\:%5.1lf%%");
		push(@tmp, "GPRINT:bchar:AVERAGE:   Average\\:%5.1lf%%");
		push(@tmp, "GPRINT:bchar:MIN:   Min\\:%5.1lf%%");
		push(@tmp, "GPRINT:bchar:MAX:   Max\\:%5.1lf%%\\n");
		push(@tmp, "AREA:loadc#EE4444:Load capacity");
		push(@tmp, "GPRINT:loadc:LAST:   Current\\:%5.1lf%%");
		push(@tmp, "GPRINT:loadc:AVERAGE:   Average\\:%5.1lf%%");
		push(@tmp, "GPRINT:loadc:MIN:   Min\\:%5.1lf%%");
		push(@tmp, "GPRINT:loadc:MAX:   Max\\:%5.1lf%%\\n");
		push(@tmp, "LINE1:bchar#0000EE");
		push(@tmp, "LINE1:loadc#EE0000");
		push(@tmp, "LINE2:mbatc#EEEE44:Shutdown level");
		push(@tmp, "GPRINT:mbatc:LAST:  Current\\:%5.1lf%%");
		push(@tmp, "GPRINT:mbatc:AVERAGE:   Average\\:%5.1lf%%");
		push(@tmp, "GPRINT:mbatc:MIN:   Min\\:%5.1lf%%");
		push(@tmp, "GPRINT:mbatc:MAX:   Max\\:%5.1lf%%\\n");
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
			"--title=$config->{graphs}->{_apcupsd2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$global_zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:bchar=$rrd:apcupsd" . $e . "_bchar:AVERAGE",
			"DEF:mbatc=$rrd:apcupsd" . $e . "_mbatc:AVERAGE",
			"DEF:loadc=$rrd:apcupsd" . $e . "_loadc:AVERAGE",
			$cdef_allvalues_bat,
			@CDEF,
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			$timeleft);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 1]",
				"--title=$config->{graphs}->{_apcupsd2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Percent (%)",
				"--width=$width",
				"--height=$height",
				@full_size_mode,
				@extra,
				@riglim,
				$global_zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:bchar=$rrd:apcupsd" . $e . "_bchar:AVERAGE",
				"DEF:mbatc=$rrd:apcupsd" . $e . "_mbatc:AVERAGE",
				"DEF:loadc=$rrd:apcupsd" . $e . "_loadc:AVERAGE",
				$cdef_allvalues_bat,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apcupsd$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6 + 1], IMG => $IMG[$e * 6 + 1]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $zoom;
						$picz_height = $picz->{image_height} * $zoom;
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
			"--title=$config->{graphs}->{_apcupsd3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$global_zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:itemp=$rrd:apcupsd" . $e . "_itemp:AVERAGE",
			"DEF:atemp=$rrd:apcupsd" . $e . "_atemp:AVERAGE",
			"DEF:humid=$rrd:apcupsd" . $e . "_humid:AVERAGE",
			$cdef_allvalues_temp,
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 2]",
				"--title=$config->{graphs}->{_apcupsd3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=$temp_scale",
				"--width=$width",
				"--height=$height",
				@full_size_mode,
				@extra,
				@riglim,
				$global_zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:itemp=$rrd:apcupsd" . $e . "_itemp:AVERAGE",
				"DEF:atemp=$rrd:apcupsd" . $e . "_atemp:AVERAGE",
				"DEF:humid=$rrd:apcupsd" . $e . "_humid:AVERAGE",
				$cdef_allvalues_temp,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apcupsd$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6 + 2], IMG => $IMG[$e * 6 + 2]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $zoom;
						$picz_height = $picz->{image_height} * $zoom;
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
			"--title=$config->{graphs}->{_apcupsd4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Volts",
			"--width=$width",
			"--height=$height",
			altscaling_options($alt_scaling_for_battery_voltage),
			@extra,
			@riglim,
			$global_zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:battv=$rrd:apcupsd" . $e . "_battv:AVERAGE",
			"DEF:nomba=$rrd:apcupsd" . $e . "_nomba:AVERAGE",
			$cdef_allvalues_batvolt,
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 3]",
				"--title=$config->{graphs}->{_apcupsd4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Volts",
				"--width=$width",
				"--height=$height",
				altscaling_options($alt_scaling_for_battery_voltage),
				@full_size_mode,
				@extra,
				@riglim,
				$global_zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:battv=$rrd:apcupsd" . $e . "_battv:AVERAGE",
				"DEF:nomba=$rrd:apcupsd" . $e . "_nomba:AVERAGE",
				$cdef_allvalues_batvolt,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 3]: $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apcupsd$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6 + 3], IMG => $IMG[$e * 6 + 3]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $zoom;
						$picz_height = $picz->{image_height} * $zoom;
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
		push(@tmp, "LINE2:timel#44EEEE:Minutes left");
		push(@tmp, "GPRINT:timel:LAST:         Current\\: %3.0lf\\n");
		push(@tmp, "LINE2:minti#EEEE44:Shutdown level" . skipscale_string($skipscale_for_shutdown_level));
		push(@tmp, "GPRINT:minti:LAST:       Current\\: %3.0lf\\n");
		push(@tmpz, "LINE2:timel#44EEEE:Minutes left");
		push(@tmpz, "LINE2:minti#EEEE44:Shutdown level" . skipscale_string($skipscale_for_shutdown_level));
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
			"--title=$config->{graphs}->{_apcupsd5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Minutes",
			"--width=$width",
			"--height=$height",
			altscaling_options($alt_scaling_for_timeleft),
			@extra,
			@riglim,
			$global_zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:timel=$rrd:apcupsd" . $e . "_timel:AVERAGE",
			"DEF:minti=$rrd:apcupsd" . $e . "_minti:AVERAGE",
			$cdef_allvalues_timeleft,
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 4]",
				"--title=$config->{graphs}->{_apcupsd5}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Minutes",
				"--width=$width",
				"--height=$height",
				altscaling_options($alt_scaling_for_timeleft),
				@full_size_mode,
				@extra,
				@riglim,
				$global_zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:timel=$rrd:apcupsd" . $e . "_timel:AVERAGE",
				"DEF:minti=$rrd:apcupsd" . $e . "_minti:AVERAGE",
				$cdef_allvalues_timeleft,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 4]: $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apcupsd$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6 + 4], IMG => $IMG[$e * 6 + 4]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $zoom;
						$picz_height = $picz->{image_height} * $zoom;
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
			"--title=$config->{graphs}->{_apcupsd6}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Hz",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$global_zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:linef=$rrd:apcupsd" . $e . "_linef:AVERAGE",
			$cdef_allvalues_freq,
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 5]",
				"--title=$config->{graphs}->{_apcupsd6}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Hz",
				"--width=$width",
				"--height=$height",
				@full_size_mode,
				@extra,
				@riglim,
				$global_zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:linef=$rrd:apcupsd" . $e . "_linef:AVERAGE",
				$cdef_allvalues_freq,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 5]: $err\n") if $err;
		}
		$e2 = $e + 6;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apcupsd$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 6 + 5], IMG => $IMG[$e * 6 + 5]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $zoom;
						$picz_height = $picz->{image_height} * $zoom;
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
			push(@output, "        <b>&nbsp;&nbsp;" . trim($url) . "</b>\n");
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
