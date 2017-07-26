#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2017 by Jordi Sanfeliu <jordi@fibranet.cat>
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

package gensens;

use strict;
use warnings;
use Monitorix;
use RRDs;
use POSIX qw(strftime);
use Exporter 'import';
our @EXPORT = qw(gensens_init gensens_update gensens_cgi);

sub gensens_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $gensens = $config->{gensens};

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
				"DS:gensens0_s1:GAUGE:120:U:U",
				"DS:gensens0_s2:GAUGE:120:U:U",
				"DS:gensens0_s3:GAUGE:120:U:U",
				"DS:gensens0_s4:GAUGE:120:U:U",
				"DS:gensens0_s5:GAUGE:120:U:U",
				"DS:gensens0_s6:GAUGE:120:U:U",
				"DS:gensens0_s7:GAUGE:120:U:U",
				"DS:gensens0_s8:GAUGE:120:U:U",
				"DS:gensens0_s9:GAUGE:120:U:U",
				"DS:gensens1_s1:GAUGE:120:U:U",
				"DS:gensens1_s2:GAUGE:120:U:U",
				"DS:gensens1_s3:GAUGE:120:U:U",
				"DS:gensens1_s4:GAUGE:120:U:U",
				"DS:gensens1_s5:GAUGE:120:U:U",
				"DS:gensens1_s6:GAUGE:120:U:U",
				"DS:gensens1_s7:GAUGE:120:U:U",
				"DS:gensens1_s8:GAUGE:120:U:U",
				"DS:gensens1_s9:GAUGE:120:U:U",
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

	$config->{gensens_hist_alerts} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub gensens_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $gensens = $config->{gensens};

	my $n;
	my $rrdata = "N";

	foreach my $sg (sort keys %{$gensens->{list}}) {
		my @ls = split(',', $gensens->{list}->{$sg});
		for($n = 0; $n < 9; $n++) {
			my $val;
			my $str;

			$val = 0;
			$str = trim($ls[$n] || "");
			if($gensens->{desc}->{$str}) {
				if(open(IN, $gensens->{desc}->{$str})) {
					my $unit;
					my $c;

					$val = <IN>;
					$val = trim($val);
					$unit = $gensens->{unit}->{$str} || 0;
					$c = () = $unit =~ /0/g;
					$val /= 10**$c if $unit > 1;
					$val *= 10**$c if $unit > 0 && $unit < 1;
					close(IN);
				} else {
					logger("$myself: ERROR: unable to open '$gensens->{desc}->{$str}'.");
				}
			}

			# check alerts for each sensor defined
			my @al = split(',', $gensens->{alerts}->{$str} || "");
			if(scalar(@al)) {
				my $timeintvl = trim($al[0]);
				my $threshold = trim($al[1]);
				my $script = trim($al[2]);
	
				if(!$threshold || $val < $threshold) {
					$config->{gensens_hist_alerts}->{$str} = 0;
				} else {
					if(!$config->{gensens_hist_alerts}->{$str}) {
						$config->{gensens_hist_alerts}->{$str} = time;
					}
					if($config->{gensens_hist_alerts}->{$str} > 0 && (time - $config->{gensens_hist_alerts}->{$str}) >= $timeintvl) {
						if(-x $script) {
							logger("$myself: alert on Generic Sensor ($str): executing script '$script'.");
							system($script . " " . $timeintvl . " " . $threshold . " " . $val);
						} else {
							logger("$myself: ERROR: script '$script' doesn't exist or don't has execution permissions.");
						}
						$config->{gensens_hist_alerts}->{$str} = time;
					}
				}
	
			}

			$rrdata .= ":$val";
		}
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub gensens_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $gensens = $config->{gensens};
	my @rigid = split(',', ($gensens->{rigid} || ""));
	my @limit = split(',', ($gensens->{limit} || ""));
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
	my $temp_scale = "Celsius";
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
		"#EEEE44",
		"#4444EE",
		"#44EEEE",
		"#EE44EE",
		"#888888",
		"#E29136",
		"#44EE44",
		"#448844",
		"#EE4444",
	);

	$version = "old" if $RRDs::VERSION < 1.3;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $IMG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};
	my $imgfmt_uc = uc($config->{image_format});
	my $imgfmt_lc = lc($config->{image_format});

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
			push(@output, "    <td bgcolor='$colors->{title_bg_color}'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"AVERAGE",
			"-r $tf->{res}");
		$err = RRDs::error;
		push(@output, "ERROR: while fetching $rrd: $err\n") if $err;
		my $line1;
		my $line2;
		my $line3;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		for($n = 0; $n < 2; $n++) {
			$line1 = "";
			foreach my $i (split(',', $gensens->{list}->{$n})) {
				$i = trim($i);
				$str = $i;
				$str = sprintf("%10s", substr($str, 0, 10));
				$line1 .= "           ";
				$line2 .= sprintf(" %10s", $str);
				$line3 .= "-----------";
			}
			if($line1) {
				my $i = length($line1);
				$str = "_gensens" . ($n + 1);
				push(@output, sprintf(sprintf("%${i}s", sprintf("%s", trim($config->{graphs}->{$str})))));
			}
		}
		push(@output, "\n");
		push(@output, "Time$line2\n");
		push(@output, "----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $n3;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			for($n2 = 0; $n2 < 2; $n2++) {
				$n3 = 0;
				foreach my $i (split(',', $gensens->{list}->{$n2})) {
					$from = $n2 * 9 + $n3++;
					$to = $from + 1;
					my ($j) = @$line[$from..$to];
					@row = ($j);
					push(@output, sprintf("%10d ", @row));
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
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "_";
	}
	if($silent eq "imagetagbig") {
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "";
	}

	for($n = 0; $n < keys(%{$gensens->{list}}); $n++) {
		$str = $u . $package . $n . "." . $tf->{when} . ".$imgfmt_lc";
		push(@IMG, $str);
		unlink("$IMG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . $package . $n . "z." . $tf->{when} . ".$imgfmt_lc";
			push(@IMGz, $str);
			unlink("$IMG_DIR" . $str);
		}
	}

	my (@ls, $max, @sg);

	$max = max(scalar(@sg = split(',', $gensens->{list}->{0}), @sg = split(',', $gensens->{list}->{1})));

	# Temperatures
	if($title) {
		push(@output, main::graph_header($title, 2));
		push(@output, "    <tr>\n");
	}

	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	@ls = split(',', $gensens->{list}->{0});
	for($n = 0; $n < 9; $n++) {
		my $str = trim($ls[$n] || "");
		if($str) {
			$str = $gensens->{map}->{$str} ? $gensens->{map}->{$str} : $str;
			$str = sprintf("%-20s", substr($str, 0, 20));
			push(@tmp, "LINE2:gsen" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:gsen" . $n . ":LAST: Cur\\:%5.1lf%s");
			push(@tmp, "GPRINT:gsen" . $n . ":MIN: Min\\:%5.1lf%s");
			push(@tmp, "GPRINT:gsen" . $n . ":MAX: Max\\:%5.1lf%s\\n");
			push(@tmpz, "LINE2:gsen" . $n . $LC[$n] . ":$str");
			next;
		}
		last;
	}
	while($n < $max) {
		push(@tmp, "COMMENT: \\n");
		$n++;
	}
	if($title) {
		push(@output, "    <td bgcolor='$colors->{title_bg_color}'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[0]",
		"--title=$config->{graphs}->{_gensens1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=$temp_scale",
		"--width=$width",
		"--height=$height",
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:gsen0=$rrd:gensens0_s1:AVERAGE",
		"DEF:gsen1=$rrd:gensens0_s2:AVERAGE",
		"DEF:gsen2=$rrd:gensens0_s3:AVERAGE",
		"DEF:gsen3=$rrd:gensens0_s4:AVERAGE",
		"DEF:gsen4=$rrd:gensens0_s5:AVERAGE",
		"DEF:gsen5=$rrd:gensens0_s6:AVERAGE",
		"DEF:gsen6=$rrd:gensens0_s7:AVERAGE",
		"DEF:gsen7=$rrd:gensens0_s8:AVERAGE",
		"DEF:gsen8=$rrd:gensens0_s9:AVERAGE",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[0]: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[0]",
			"--title=$config->{graphs}->{_gensens1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:gsen0=$rrd:gensens0_s1:AVERAGE",
			"DEF:gsen1=$rrd:gensens0_s2:AVERAGE",
			"DEF:gsen2=$rrd:gensens0_s3:AVERAGE",
			"DEF:gsen3=$rrd:gensens0_s4:AVERAGE",
			"DEF:gsen4=$rrd:gensens0_s5:AVERAGE",
			"DEF:gsen5=$rrd:gensens0_s6:AVERAGE",
			"DEF:gsen6=$rrd:gensens0_s7:AVERAGE",
			"DEF:gsen7=$rrd:gensens0_s8:AVERAGE",
			"DEF:gsen8=$rrd:gensens0_s9:AVERAGE",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[0]: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /gensens0/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[0] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[0] . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[0] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[0] . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[0] . "'>\n");
		}
	}

	if($title) {
		push(@output, "    </td>\n");
	}

	# CPU frequency
	@riglim = @{setup_riglim($rigid[1], $limit[1])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	@ls = split(',', $gensens->{list}->{1});
	for($n = 0; $n < 9; $n++) {
		my $str = trim($ls[$n] || "");
		if($str) {
			$str = $gensens->{map}->{$str} ? $gensens->{map}->{$str} : $str;
			$str = sprintf("%-20s", substr($str, 0, 20));
			push(@tmp, "LINE2:gsen" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:gsen" . $n . ":LAST: Cur\\:%4.1lf%shz");
			push(@tmp, "GPRINT:gsen" . $n . ":MIN: Min\\:%4.1lf%shz");
			push(@tmp, "GPRINT:gsen" . $n . ":MAX: Max\\:%4.1lf%shz\\n");
			push(@tmpz, "LINE2:gsen" . $n . $LC[$n] . ":$str");
			next;
		}
		last;
	}
	while($n < $max) {
		push(@tmp, "COMMENT: \\n");
		$n++;
	}
	if($title) {
		push(@output, "    <td bgcolor='$colors->{title_bg_color}'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[1]",
		"--title=$config->{graphs}->{_gensens2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Hz",
		"--width=$width",
		"--height=$height",
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:gsen0=$rrd:gensens1_s1:AVERAGE",
		"DEF:gsen1=$rrd:gensens1_s2:AVERAGE",
		"DEF:gsen2=$rrd:gensens1_s3:AVERAGE",
		"DEF:gsen3=$rrd:gensens1_s4:AVERAGE",
		"DEF:gsen4=$rrd:gensens1_s5:AVERAGE",
		"DEF:gsen5=$rrd:gensens1_s6:AVERAGE",
		"DEF:gsen6=$rrd:gensens1_s7:AVERAGE",
		"DEF:gsen7=$rrd:gensens1_s8:AVERAGE",
		"DEF:gsen8=$rrd:gensens1_s9:AVERAGE",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[1]: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[1]",
			"--title=$config->{graphs}->{_gensens2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Hz",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:gsen0=$rrd:gensens1_s1:AVERAGE",
			"DEF:gsen1=$rrd:gensens1_s2:AVERAGE",
			"DEF:gsen2=$rrd:gensens1_s3:AVERAGE",
			"DEF:gsen3=$rrd:gensens1_s4:AVERAGE",
			"DEF:gsen4=$rrd:gensens1_s5:AVERAGE",
			"DEF:gsen5=$rrd:gensens1_s6:AVERAGE",
			"DEF:gsen6=$rrd:gensens1_s7:AVERAGE",
			"DEF:gsen7=$rrd:gensens1_s8:AVERAGE",
			"DEF:gsen8=$rrd:gensens1_s9:AVERAGE",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[1]: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /gensens1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[1] . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[1] . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[1] . "'>\n");
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
