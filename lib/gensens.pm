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
		if(scalar(@ds) / 9 != keys %{$gensens->{list}}) {
			logger("$myself: Detected size mismatch between 'list' (" . keys(%{$gensens->{list}}) . ") and $rrd (" . scalar(@ds) / 9 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < keys %{$gensens->{list}}; $n++) {
			push(@tmp, "DS:gensens" . $n . "_s1:GAUGE:120:0:U");
			push(@tmp, "DS:gensens" . $n . "_s2:GAUGE:120:0:U");
			push(@tmp, "DS:gensens" . $n . "_s3:GAUGE:120:0:U");
			push(@tmp, "DS:gensens" . $n . "_s4:GAUGE:120:0:U");
			push(@tmp, "DS:gensens" . $n . "_s5:GAUGE:120:0:U");
			push(@tmp, "DS:gensens" . $n . "_s6:GAUGE:120:0:U");
			push(@tmp, "DS:gensens" . $n . "_s7:GAUGE:120:0:U");
			push(@tmp, "DS:gensens" . $n . "_s8:GAUGE:120:0:U");
			push(@tmp, "DS:gensens" . $n . "_s9:GAUGE:120:0:U")
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
				my $when = lc(trim($al[3] || ""));
				my @range = split('-', $threshold);
				$threshold = 0 if !$threshold;
				if(scalar(@range) == 1) {
					$when = "above" if !$when;	# 'above' is the default
					if($when eq "above" && $val < $threshold) {
						$config->{gensens_hist_alerts}->{$str} = 0;
					} elsif($when eq "below" && $val > $threshold) {
						$config->{gensens_hist_alerts}->{$str} = 0;
					} else {
						if($when eq "above" || $when eq "below") {
							if(!$config->{gensens_hist_alerts}->{$str}) {
								$config->{gensens_hist_alerts}->{$str} = time;
							}
							if($config->{gensens_hist_alerts}->{$str} > 0 && (time - $config->{gensens_hist_alerts}->{$str}) >= $timeintvl) {
								if(-x $script) {
									logger("$myself: alert on Generic Sensor ($str): executing script '$script'.");
									system($script . " " . $timeintvl . " " . $threshold . " " . $val . " " . $when);
								} else {
									logger("$myself: ERROR: script '$script' doesn't exist or don't has execution permissions.");
								}
								$config->{gensens_hist_alerts}->{$str} = time;
							}
						} else {
							logger("$myself: ERROR: invalid when value '$when'");
						}
					}
				} elsif(scalar(@range) == 2) {
					if($when) {
						logger("$myself: the forth parameter ('$when') in '$str' is irrelevant when there are range values defined.");
					}
					if($range[0] == $range[1]) {
						logger("$myself: ERROR: range values are identical.");
					} else {
						if($val <= $range[0]) {
							$config->{gensens_hist_alerts}->{$str}->{above} = 0;
							if($val < $range[0] && !$config->{gensens_hist_alerts}->{$str}->{below}) {
								$config->{gensens_hist_alerts}->{$str}->{below} = time;
							}
						}
						if($val >= $range[1]) {
							$config->{gensens_hist_alerts}->{$str}->{below} = 0;
							if($val > $range[1] && !$config->{gensens_hist_alerts}->{$str}->{above}) {
								$config->{gensens_hist_alerts}->{$str}->{above} = time;
							}
						}
						if($config->{gensens_hist_alerts}->{$str}->{below} > 0 && (time - $config->{gensens_hist_alerts}->{$str}->{below}) >= $timeintvl) {
							if(-x $script) {
								logger("$myself: alert on Generic Sensor ($str): executing script '$script'.");
								system($script . " " . $timeintvl . " " . $threshold . " " . $val);
							} else {
								logger("$myself: ERROR: script '$script' doesn't exist or don't has execution permissions.");
							}
							$config->{gensens_hist_alerts}->{$str}->{below} = time;
						}
						if($config->{gensens_hist_alerts}->{$str}->{above} > 0 && (time - $config->{gensens_hist_alerts}->{$str}->{above}) >= $timeintvl) {
							if(-x $script) {
								logger("$myself: alert on Generic Sensor ($str): executing script '$script'.");
								system($script . " " . $timeintvl . " " . $threshold . " " . $val);
							} else {
								logger("$myself: ERROR: script '$script' doesn't exist or don't has execution permissions.");
							}
							$config->{gensens_hist_alerts}->{$str}->{above} = time;
						}
					}
				} else {
					logger("$myself: ERROR: invalid threshold value '$threshold'");
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
	my @extra;
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
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		foreach my $sg (sort keys %{$gensens->{list}}) {
			$line1 = "";
			foreach my $i (split(',', $gensens->{list}->{$sg})) {
				$i = trim($i);
				$str = $i;
				$str = sprintf("%12s", substr($str, 0, 10));
				$line1 .= "             ";
				$line2 .= sprintf(" %12s", $str);
				$line3 .= "-------------";
			}
			if($line1) {
				my $i = length($line1);
				push(@output, substr(sprintf("%${i}s", sprintf("%s", trim($gensens->{title}->{$sg}))), 0, 13));
			}
		}
		push(@output, "\n");
		push(@output, "Time$line2\n");
		push(@output, "----$line3 \n");
		my $line;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			foreach my $sg (sort keys %{$gensens->{list}}) {
				$n2 = 0;
				foreach my $i (split(',', $gensens->{list}->{$sg})) {
					$from = $sg * 9 + $n2++;
					$to = $from + 1;
					my ($j) = @$line[$from..$to];
					if(index($sg, "temp")) {
						$j = celsius_to($config, $j || 0);
					}
					push(@output, sprintf("%12d ", $j || 0));
				}
				$n2++;
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

	my @linpad =(0);
	my $e = 0;
	foreach my $sg (sort keys %{$gensens->{list}}) {
		my @ls = split(',', $gensens->{list}->{$sg});
		$linpad[$e] = scalar(@ls);
		if($e && $e % 2) {
			$linpad[$e] = max($linpad[$e - 1], $linpad[$e]);
			$linpad[$e - 1] = $linpad[$e];
		}
		$e++;
	}

	my $vlabel;
	$e = 0;
	foreach my $sg (sort keys %{$gensens->{list}}) {
		my @ls = split(',', $gensens->{list}->{$sg});

		# determine if we are dealing with a 'temp', 'cpu' or 'bat' graph
		if(index($ls[0], "temp") == 0) {
			$vlabel = $temp_scale;
		} elsif(index($ls[0], "cpu") == 0) {
			$vlabel = "Hz";
		} elsif(index($ls[0], "bat") == 0) {
			$vlabel = "Charge";
		} else {
			# not supported yet
		}

		if(!$e) {
			if($title) {
				push(@output, main::graph_header($title, 2));
				push(@output, "    <tr>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[$e], $limit[$e])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < 9; $n++) {
			my $str = trim($ls[$n] || "");
			if($str) {
				$str = $gensens->{map}->{$str} ? $gensens->{map}->{$str} : $str;
				$str = sprintf("%-20s", substr($str, 0, 20));
				push(@tmp, "LINE2:gsen_" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:gsen_" . $n . ":LAST: Cur\\:%5.1lf%s");
				push(@tmp, "GPRINT:gsen_" . $n . ":MIN: Min\\:%5.1lf%s");
				push(@tmp, "GPRINT:gsen_" . $n . ":MAX: Max\\:%5.1lf%s\\n");
				push(@tmpz, "LINE2:gsen_" . $n . $LC[$n] . ":$str");
				next;
			}
			last;
		}
		while($n < $linpad[$e]) {
			push(@tmp, "COMMENT: \\n");
			$n++;
		}

		if($title) {
			push(@output, "    <td>\n");
		}
		if(index($ls[0], "temp") == 0) {
			if(lc($config->{temperature_scale}) eq "f") {
				push(@CDEF, "CDEF:gsen_0=9,5,/,gsen0,*,32,+");
				push(@CDEF, "CDEF:gsen_1=9,5,/,gsen1,*,32,+");
				push(@CDEF, "CDEF:gsen_2=9,5,/,gsen2,*,32,+");
				push(@CDEF, "CDEF:gsen_3=9,5,/,gsen3,*,32,+");
				push(@CDEF, "CDEF:gsen_4=9,5,/,gsen4,*,32,+");
				push(@CDEF, "CDEF:gsen_5=9,5,/,gsen5,*,32,+");
				push(@CDEF, "CDEF:gsen_6=9,5,/,gsen6,*,32,+");
				push(@CDEF, "CDEF:gsen_7=9,5,/,gsen7,*,32,+");
				push(@CDEF, "CDEF:gsen_8=9,5,/,gsen8,*,32,+");
			} else {
				push(@CDEF, "CDEF:gsen_0=gsen0");
				push(@CDEF, "CDEF:gsen_1=gsen1");
				push(@CDEF, "CDEF:gsen_2=gsen2");
				push(@CDEF, "CDEF:gsen_3=gsen3");
				push(@CDEF, "CDEF:gsen_4=gsen4");
				push(@CDEF, "CDEF:gsen_5=gsen5");
				push(@CDEF, "CDEF:gsen_6=gsen6");
				push(@CDEF, "CDEF:gsen_7=gsen7");
				push(@CDEF, "CDEF:gsen_8=gsen8");
			}
		} else {
			push(@CDEF, "CDEF:gsen_0=gsen0");
			push(@CDEF, "CDEF:gsen_1=gsen1");
			push(@CDEF, "CDEF:gsen_2=gsen2");
			push(@CDEF, "CDEF:gsen_3=gsen3");
			push(@CDEF, "CDEF:gsen_4=gsen4");
			push(@CDEF, "CDEF:gsen_5=gsen5");
			push(@CDEF, "CDEF:gsen_6=gsen6");
			push(@CDEF, "CDEF:gsen_7=gsen7");
			push(@CDEF, "CDEF:gsen_8=gsen8");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e]",
			"--title=$gensens->{title}->{$sg}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:gsen0=$rrd:gensens" . $e . "_s1:AVERAGE",
			"DEF:gsen1=$rrd:gensens" . $e . "_s2:AVERAGE",
			"DEF:gsen2=$rrd:gensens" . $e . "_s3:AVERAGE",
			"DEF:gsen3=$rrd:gensens" . $e . "_s4:AVERAGE",
			"DEF:gsen4=$rrd:gensens" . $e . "_s5:AVERAGE",
			"DEF:gsen5=$rrd:gensens" . $e . "_s6:AVERAGE",
			"DEF:gsen6=$rrd:gensens" . $e . "_s7:AVERAGE",
			"DEF:gsen7=$rrd:gensens" . $e . "_s8:AVERAGE",
			"DEF:gsen8=$rrd:gensens" . $e . "_s9:AVERAGE",
			"CDEF:allvalues=gsen0,gsen1,gsen2,gsen3,gsen4,gsen5,gsen6,gsen7,gsen8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e]",
				"--title=$gensens->{title}->{$sg}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:gsen0=$rrd:gensens" . $e . "_s1:AVERAGE",
				"DEF:gsen1=$rrd:gensens" . $e . "_s2:AVERAGE",
				"DEF:gsen2=$rrd:gensens" . $e . "_s3:AVERAGE",
				"DEF:gsen3=$rrd:gensens" . $e . "_s4:AVERAGE",
				"DEF:gsen4=$rrd:gensens" . $e . "_s5:AVERAGE",
				"DEF:gsen5=$rrd:gensens" . $e . "_s6:AVERAGE",
				"DEF:gsen6=$rrd:gensens" . $e . "_s7:AVERAGE",
				"DEF:gsen7=$rrd:gensens" . $e . "_s8:AVERAGE",
				"DEF:gsen8=$rrd:gensens" . $e . "_s9:AVERAGE",
				"CDEF:allvalues=gsen0,gsen1,gsen2,gsen3,gsen4,gsen5,gsen6,gsen7,gsen8,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /gensens0/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
		}

		$e++;
		if(!($e % 2) && $e < keys(%{$gensens->{list}})) {
			push(@output, "    </tr>\n");
			push(@output, "    <tr>\n");
		}
	}

	if($title) {
		push(@output, "    </tr>\n");
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
