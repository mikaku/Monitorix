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

package ipmi;

use strict;
use warnings;
use Monitorix;
use RRDs;
use POSIX qw(strftime);
use Exporter 'import';
our @EXPORT = qw(ipmi_init ipmi_update ipmi_cgi);

sub ipmi_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $ipmi = $config->{ipmi};

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
		if(scalar(@ds) / 9 != scalar(my @fl = split(',', $ipmi->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @fl = split(',', $ipmi->{list})) . ") and $rrd (" . scalar(@ds) / 9 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @sensor_list = split(',', $ipmi->{list})); $n++) {
			push(@tmp, "DS:ipmi" . $n . "_s1:GAUGE:120:U:U");
			push(@tmp, "DS:ipmi" . $n . "_s2:GAUGE:120:U:U");
			push(@tmp, "DS:ipmi" . $n . "_s3:GAUGE:120:U:U");
			push(@tmp, "DS:ipmi" . $n . "_s4:GAUGE:120:U:U");
			push(@tmp, "DS:ipmi" . $n . "_s5:GAUGE:120:U:U");
			push(@tmp, "DS:ipmi" . $n . "_s6:GAUGE:120:U:U");
			push(@tmp, "DS:ipmi" . $n . "_s7:GAUGE:120:U:U");
			push(@tmp, "DS:ipmi" . $n . "_s8:GAUGE:120:U:U");
			push(@tmp, "DS:ipmi" . $n . "_s9:GAUGE:120:U:U");
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

	$config->{ipmi_hist_alerts} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub ipmi_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $ipmi = $config->{ipmi};
	my $args = $ipmi->{extra_args} || "";
	my $use_nan_for_missing_data = lc($ipmi->{use_nan_for_missing_data} || "") eq "y" ? 1 : 0;

	my @sens;

	my $n;
	my $str;
	my $rrdata = "N";

	if(!open(IN, "ipmitool $args sdr |")) {
		logger("$myself: unable to execute 'ipmitool'. $!");
		return;
	}
	my @data = <IN>;
	close(IN);

	my @sensor_list = split(',', $ipmi->{list});

	my $e = 0;
	while($e < scalar(@sensor_list)) {
		my $e2 = 0;
		foreach my $i (split(',', $ipmi->{desc}->{$e})) {
			my $unit;
			$sens[$e][$e2] = ($use_nan_for_missing_data ? (0+"nan") : 0) unless defined $sens[$e][$e2];
			$str = trim($i);
			$unit = $ipmi->{units}->{$e};
			foreach(@data) {
				if(/^($str)\s+\|\s+(-?\d+\.*\d*)\s+$unit\s+/) {
					my $val = $2;
					$sens[$e][$e2] = $val;

					# check alerts for each sensor defined
					$str =~ s/ /_/;
					my @al = split(',', $ipmi->{alerts}->{$str} || "");
					if(scalar(@al)) {
						my $timeintvl = trim($al[0]);
						my $threshold = trim($al[1]);
						my $script = trim($al[2]);

						if(!$threshold || $val < $threshold) {
							$config->{ipmi_hist_alerts}->{$str} = 0;
						} else {
							if(!$config->{ipmi_hist_alerts}->{$str}) {
								$config->{ipmi_hist_alerts}->{$str} = time;
							}
							if($config->{ipmi_hist_alerts}->{$str} > 0 && (time - $config->{ipmi_hist_alerts}->{$str}) >= $timeintvl) {
								if(-x $script) {
									logger("$myself: alert on IPMI Sensor ($str): executing script '$script'.");
									system($script . " " . $timeintvl . " " . $threshold . " " . $val);
								} else {
									logger("$myself: ERROR: script '$script' doesn't exist or don't has execution permissions.");
								}
								$config->{ipmi_hist_alerts}->{$str} = time;
							}
						}
					}
				}
			}
			$e2++;
		}
		$e++;
	}

	$e = 0;
	while($e < scalar(@sensor_list)) {
		for($n = 0; $n < 9; $n++) {
			$sens[$e][$n] = 0 unless defined $sens[$e][$n];
			$rrdata .= ":" . $sens[$e][$n];
		}
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub ipmi_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $ipmi = $config->{ipmi};
	my $gap_on_all_nan = lc($ipmi->{gap_on_all_nan} || "") eq "y" ? 1 : 0;
	my @rigid = split(',', ($ipmi->{rigid} || ""));
	my @limit = split(',', ($ipmi->{limit} || ""));
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
	my @extra;
	my @riglim;
	my @IMG;
	my @IMGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $n;
	my $n2;
	my $str;
	my $err;
	my @LC = (
		"#4444EE",
		"#EEEE44",
		"#44EEEE",
		"#EE44EE",
		"#888888",
		"#E29136",
		"#44EE44",
		"#448844",
		"#EE4444",
	);

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
	my @sensor_list = split(',', $ipmi->{list});

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
		push(@output, "    ");
		for($n = 0; $n < scalar(@sensor_list); $n++) {
			$line1 = "";
			foreach my $i (split(',', $ipmi->{desc}->{$n})) {
				$i = trim($i);
				$str = $ipmi->{map}->{$i} || $i;
				$str = sprintf("%7s", substr($str, 0, 5));
				$line1 .= "        ";
				$line2 .= sprintf(" %7s", $str);
				$line3 .= "--------";
			}
			if($line1) {
				my $i = length($line1);
				push(@output, sprintf(sprintf("%${i}s", sprintf("%s", trim($sensor_list[$n])))));
			}
		}
		push(@output, "\n");
		push(@output, "Time$line2\n");
		push(@output, "----$line3 \n");
		my $line;
		my $time;
		my $n2;
		my $n3;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			for($n2 = 0; $n2 < scalar(@sensor_list); $n2++) {
				$n3 = $n2 * 9;
				foreach my $i (split(',', $ipmi->{desc}->{$n2})) {
					$from = $n3++;
					$to = $from + 1;
					my ($j) = @$line[$from..$to];
					push(@output, sprintf("%7.1lf ", $j || 0));
				}
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

	for($n = 0; $n < scalar(@sensor_list); $n++) {
		$str = $u . $package . $n . "." . $tf->{when} . ".$imgfmt_lc";
		push(@IMG, $str);
		unlink("$IMG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . $package . $n . "z." . $tf->{when} . ".$imgfmt_lc";
			push(@IMGz, $str);
			unlink("$IMG_DIR" . $str);
		}
	}

	my $graphs_per_row = $ipmi->{graphs_per_row};
	my @linpad =(0) x scalar(@sensor_list);
	if ($graphs_per_row > 1) {
		for(my $n = 0; $n < scalar(@sensor_list); $n++) {
			my @ls = split(',', $ipmi->{desc}->{$n});
			$linpad[$n] = scalar(@ls);
		}
		for(my $n = 0; $n < scalar(@linpad); $n++) {
			if ($n % $graphs_per_row == 0) {
				my $max_number_of_lines = 0;
				for (my $sub_n = $n; $sub_n < min($n + $graphs_per_row, scalar(@linpad)); $sub_n++) {
					$max_number_of_lines = max($max_number_of_lines, $linpad[$sub_n]);
				}
				for (my $sub_n = $n; $sub_n < min($n + $graphs_per_row, scalar(@linpad)); $sub_n++) {
					$linpad[$sub_n] = $max_number_of_lines;
				}
			}
		}
	}

	my $whitespace_key_support = lc($ipmi->{whitespace_key_support} || "") eq "y" ? 1 : 0;

	$n = 0;
	while($n < scalar(@sensor_list)) {
		if($title) {
			if($n == 0) {
				push(@output, main::graph_header($title, $graphs_per_row));
			}
			push(@output, "    <tr>\n");
		}
		for($n2 = 0; $n2 < $graphs_per_row; $n2++) {
			last unless $n < scalar(@sensor_list);
			if($title) {
				push(@output, "    <td>\n");
			}
			@riglim = @{setup_riglim($rigid[$n], $limit[$n])};
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			my $e = 0;
			my $unit = $ipmi->{units}->{$n};
			foreach my $i (split(',', $ipmi->{desc}->{$n})) {
				$i = trim($i);
				if ($whitespace_key_support) {
					$i=~s/ /_/g;
				}
				$str = $ipmi->{map}->{$i} || $i;
				$str = sprintf("%-40s", substr($str, 0, 40));
				push(@tmp, "LINE2:s" . ($e + 1) . $LC[$e] . ":$str");
				push(@tmp, "GPRINT:s" . ($e + 1) . ":LAST: Current\\:%7.1lf\\n");
				push(@tmpz, "LINE2:s" . ($e + 1) . $LC[$e] . ":$str");
				$e++;
			}
			while($e < $linpad[$n]) {
				push(@tmp, "COMMENT: \\n");
				$e++;
			}
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{medium});
			$str = substr(trim($sensor_list[$n]), 0, 25);
			my $cdef_allvalues = $gap_on_all_nan ? "CDEF:allvalues=s1,UN,0,1,IF,s2,UN,0,1,IF,s3,UN,0,1,IF,s4,UN,0,1,IF,s5,UN,0,1,IF,s6,UN,0,1,IF,s7,UN,0,1,IF,s8,UN,0,1,IF,s9,UN,0,1,IF,+,+,+,+,+,+,+,+,0,GT,1,UNKN,IF" : "CDEF:allvalues=s1,s2,s3,s4,s5,s6,s7,s8,s9,+,+,+,+,+,+,+,+";
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$n]",
				"--title=$str  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=$unit",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$global_zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:s1=$rrd:ipmi" . $n . "_s1:AVERAGE",
				"DEF:s2=$rrd:ipmi" . $n . "_s2:AVERAGE",
				"DEF:s3=$rrd:ipmi" . $n . "_s3:AVERAGE",
				"DEF:s4=$rrd:ipmi" . $n . "_s4:AVERAGE",
				"DEF:s5=$rrd:ipmi" . $n . "_s5:AVERAGE",
				"DEF:s6=$rrd:ipmi" . $n . "_s6:AVERAGE",
				"DEF:s7=$rrd:ipmi" . $n . "_s7:AVERAGE",
				"DEF:s8=$rrd:ipmi" . $n . "_s8:AVERAGE",
				"DEF:s9=$rrd:ipmi" . $n . "_s9:AVERAGE",
				$cdef_allvalues,
				@CDEF,
				@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$n]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$n]",
					"--title=$str  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=$unit",
					"--width=$width",
					"--height=$height",
					@full_size_mode,
					@extra,
					@riglim,
					$global_zoom,
					@{$cgi->{version12}},
					@{$colors->{graph_colors}},
					"DEF:s1=$rrd:ipmi" . $n . "_s1:AVERAGE",
					"DEF:s2=$rrd:ipmi" . $n . "_s2:AVERAGE",
					"DEF:s3=$rrd:ipmi" . $n . "_s3:AVERAGE",
					"DEF:s4=$rrd:ipmi" . $n . "_s4:AVERAGE",
					"DEF:s5=$rrd:ipmi" . $n . "_s5:AVERAGE",
					"DEF:s6=$rrd:ipmi" . $n . "_s6:AVERAGE",
					"DEF:s7=$rrd:ipmi" . $n . "_s7:AVERAGE",
					"DEF:s8=$rrd:ipmi" . $n . "_s8:AVERAGE",
					"DEF:s9=$rrd:ipmi" . $n . "_s9:AVERAGE",
					$cdef_allvalues,
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$n]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /ipmi$n/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$n], IMG => $IMG[$n]) . "\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $zoom;
							$picz_height = $picz->{image_height} * $zoom;
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      " . picz_js_a_element(width => $picz_width, height => $picz_height, config => $config, IMGz => $IMGz[$n], IMG => $IMG[$n]) . "\n");
					}
				} else {
					push(@output, "      " . img_element(config => $config, IMG => $IMG[$n]) . "\n");
				}
			}
			if($title) {
				push(@output, "    </td>\n");
			}
			$n++;
		}
		if($title) {
			push(@output, "    </tr>\n");
		}
	}
	if($title) {
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
