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

package nvidia;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(nvidia_init nvidia_update nvidia_cgi);

sub nvidia_init {
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

	# checks if 'nvidia-smi' does exists.
	if(!open(IN, "nvidia-smi |")) {
		logger("$myself: unable to execute 'nvidia-smi'. $!");
		return;
	}
	close(IN);

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
				"DS:nvidia_temp0:GAUGE:120:0:U",
				"DS:nvidia_temp1:GAUGE:120:0:U",
				"DS:nvidia_temp2:GAUGE:120:0:U",
				"DS:nvidia_temp3:GAUGE:120:0:U",
				"DS:nvidia_temp4:GAUGE:120:0:U",
				"DS:nvidia_temp5:GAUGE:120:0:U",
				"DS:nvidia_temp6:GAUGE:120:0:U",
				"DS:nvidia_temp7:GAUGE:120:0:U",
				"DS:nvidia_temp8:GAUGE:120:0:U",
				"DS:nvidia_gpu0:GAUGE:120:0:100",
				"DS:nvidia_gpu1:GAUGE:120:0:100",
				"DS:nvidia_gpu2:GAUGE:120:0:100",
				"DS:nvidia_gpu3:GAUGE:120:0:100",
				"DS:nvidia_gpu4:GAUGE:120:0:100",
				"DS:nvidia_gpu5:GAUGE:120:0:100",
				"DS:nvidia_gpu6:GAUGE:120:0:100",
				"DS:nvidia_gpu7:GAUGE:120:0:100",
				"DS:nvidia_gpu8:GAUGE:120:0:100",
				"DS:nvidia_mem0:GAUGE:120:0:100",
				"DS:nvidia_mem1:GAUGE:120:0:100",
				"DS:nvidia_mem2:GAUGE:120:0:100",
				"DS:nvidia_mem3:GAUGE:120:0:100",
				"DS:nvidia_mem4:GAUGE:120:0:100",
				"DS:nvidia_mem5:GAUGE:120:0:100",
				"DS:nvidia_mem6:GAUGE:120:0:100",
				"DS:nvidia_mem7:GAUGE:120:0:100",
				"DS:nvidia_mem8:GAUGE:120:0:100",
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

	$config->{nvidia_hist_alerts} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub nvidia_alerts {
	my $myself = (caller(0))[3];
	my $config = (shift);
	my $sensor = (shift);
	my $val = (shift);

	my $nvidia = $config->{nvidia};
	my @al = split(',', $nvidia->{alerts}->{$sensor} || "");

	if(scalar(@al)) {
		my $timeintvl = trim($al[0]);
		my $threshold = trim($al[1]);
		my $script = trim($al[2]);
	
		if(!$threshold || $val < $threshold) {
			$config->{nvidia_hist_alerts}->{$sensor} = 0;
		} else {
			if(!$config->{nvidia_hist_alerts}->{$sensor}) {
				$config->{nvidia_hist_alerts}->{$sensor} = time;
			}
			if($config->{nvidia_hist_alerts}->{$sensor} > 0 && (time - $config->{nvidia_hist_alerts}->{$sensor}) >= $timeintvl) {
				if(-x $script) {
					logger("$myself: alert on NVIDIA ($sensor): executing script '$script'.");
					system($script . " " . $timeintvl . " " . $threshold . " " . $val);
				} else {
					logger("$myself: ERROR: script '$script' doesn't exist or don't has execution permissions.");
				}
				$config->{nvidia_hist_alerts}->{$sensor} = time;
			}
		}
	}
}

sub nvidia_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nvidia = $config->{nvidia};

	my @temp;
	my @gpu;
	my @mem;
	my @data;
	my $utilization;

	my $l;
	my $n;
	my $rrdata = "N";

	for($n = 0; $n < 9; $n++) {
		$temp[$n] = 0;
		$gpu[$n] = 0;
		$mem[$n] = 0;
		if($n < $nvidia->{max}) {
			($mem[$n], $gpu[$n], $temp[$n]) = split(' ', get_nvidia_data($n));
			if(!$temp[$n] && !$gpu[$n] && !$mem[$n]) {
				# attempt to get data using the old driver version
				$utilization = 0;
	  			open(IN, "nvidia-smi -g $n |");
				@data = <IN>;
				close(IN);
				for($l = 0; $l < scalar(@data); $l++) {
					if($data[$l] =~ /Temperature/) {
						my (undef, $tmp) = split(':', $data[$l]);
						if($tmp eq "\n") {
							$l++;
							$tmp = $data[$l];
						}
						my ($value, undef) = split(' ', $tmp);
						$value =~ s/[-]/./;
						$value =~ s/[^0-9.]//g;
						if(int($value) > 0) {
							$temp[$n] = int($value);
						}
					}
					if($data[$l] =~ /Utilization/) {
						$utilization = 1;
					}
					if($utilization == 1) {
						if($data[$l] =~ /GPU/) {
							my (undef, $tmp) = split(':', $data[$l]);
							if($tmp eq "\n") {
								$l++;
								$tmp = $data[$l];
							}
							my ($value, undef) = split(' ', $tmp);
							$value =~ s/[-]/./;
							$value =~ s/[^0-9.]//g;
							if(int($value) > 0) {
								$gpu[$n] = int($value);
							}
						}
						if($data[$l] =~ /Memory/) {
							my (undef, $tmp) = split(':', $data[$l]);
							if($tmp eq "\n") {
								$l++;
								$tmp = $data[$l];
							}
							my ($value, undef) = split(' ', $tmp);
							$value =~ s/[-]/./;
							$value =~ s/[^0-9.]//g;
							if(int($value) > 0) {
								$mem[$n] = int($value);
							}
						}
					}
				}
			}
		}
	}

	for($n = 0; $n < scalar(@temp); $n++) {
		# check alerts for each sensor defined
		nvidia_alerts($config, "temp$n", $temp[$n]);
		$rrdata .= ":$temp[$n]";
	}
	for($n = 0; $n < scalar(@gpu); $n++) {
		# check alerts for each sensor defined
		nvidia_alerts($config, "gpu$n", $gpu[$n]);
		$rrdata .= ":$gpu[$n]";
	}
	for($n = 0; $n < scalar(@mem); $n++) {
		# check alerts for each sensor defined
		nvidia_alerts($config, "mem$n", $mem[$n]);
		$rrdata .= ":$mem[$n]";
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub nvidia_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $nvidia = $config->{nvidia};
	my @rigid = split(',', ($nvidia->{rigid} || ""));
	my @limit = split(',', ($nvidia->{limit} || ""));
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
	my @tmp;
	my @tmpz;
	my @CDEF,
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
		"#963C74",
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
		for($n = 0; $n < $nvidia->{max}; $n++) {
			push(@output, "    NVIDIA card $n");
		}
		push(@output, "\n");
		for($n = 0; $n < $nvidia->{max}; $n++) {
			$line2 .= "   Temp  GPU  Mem";
			$line3 .= "-----------------";
		}
		push(@output, "Time$line2\n");
		push(@output, "----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			undef($line1);
			undef(@row);
			for($n2 = 0; $n2 < $nvidia->{max}; $n2++) {
				push(@row, celsius_to($config, @$line[$n2]));
				push(@row, celsius_to($config, @$line[$n2 + 9]));
				push(@row, celsius_to($config, @$line[$n2 + 18]));
				$line1 .= "   %3d %3d%% %3d%%";
			}
			push(@output, sprintf($line1, @row));
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
	for($n = 0; $n < 9; $n++) {
		if($n < $nvidia->{max}) {
			push(@tmp, "LINE2:temp_" . $n . $LC[$n] . ":Card $n");
			push(@tmpz, "LINE2:temp_" . $n . $LC[$n] . ":Card $n");
			push(@tmp, "GPRINT:temp_" . $n . ":LAST:             Current\\: %2.0lf");
			push(@tmp, "GPRINT:temp_" . $n . ":AVERAGE:   Average\\: %2.0lf");
			push(@tmp, "GPRINT:temp_" . $n . ":MIN:   Min\\: %2.0lf");
			push(@tmp, "GPRINT:temp_" . $n . ":MAX:   Max\\: %2.0lf\\n");
		} else {
			push(@tmp, "COMMENT: \\n");
		}
	}

	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td>\n");
	}
	if(lc($config->{temperature_scale}) eq "f") {
		push(@CDEF, "CDEF:temp_0=9,5,/,temp0,*,32,+");
		push(@CDEF, "CDEF:temp_1=9,5,/,temp1,*,32,+");
		push(@CDEF, "CDEF:temp_2=9,5,/,temp2,*,32,+");
		push(@CDEF, "CDEF:temp_3=9,5,/,temp3,*,32,+");
		push(@CDEF, "CDEF:temp_4=9,5,/,temp4,*,32,+");
		push(@CDEF, "CDEF:temp_5=9,5,/,temp5,*,32,+");
		push(@CDEF, "CDEF:temp_6=9,5,/,temp6,*,32,+");
		push(@CDEF, "CDEF:temp_7=9,5,/,temp7,*,32,+");
		push(@CDEF, "CDEF:temp_8=9,5,/,temp8,*,32,+");
	} else {
		push(@CDEF, "CDEF:temp_0=temp0");
		push(@CDEF, "CDEF:temp_1=temp1");
		push(@CDEF, "CDEF:temp_2=temp2");
		push(@CDEF, "CDEF:temp_3=temp3");
		push(@CDEF, "CDEF:temp_4=temp4");
		push(@CDEF, "CDEF:temp_5=temp5");
		push(@CDEF, "CDEF:temp_6=temp6");
		push(@CDEF, "CDEF:temp_7=temp7");
		push(@CDEF, "CDEF:temp_8=temp8");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG1",
		"--title=$config->{graphs}->{_nvidia1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=$temp_scale",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:temp0=$rrd:nvidia_temp0:AVERAGE",
		"DEF:temp1=$rrd:nvidia_temp1:AVERAGE",
		"DEF:temp2=$rrd:nvidia_temp2:AVERAGE",
		"DEF:temp3=$rrd:nvidia_temp3:AVERAGE",
		"DEF:temp4=$rrd:nvidia_temp4:AVERAGE",
		"DEF:temp5=$rrd:nvidia_temp5:AVERAGE",
		"DEF:temp6=$rrd:nvidia_temp6:AVERAGE",
		"DEF:temp7=$rrd:nvidia_temp7:AVERAGE",
		"DEF:temp8=$rrd:nvidia_temp8:AVERAGE",
		"CDEF:allvalues=temp0,temp1,temp2,temp3,temp4,temp5,temp6,temp7,temp8,+,+,+,+,+,+,+,+",
		@CDEF,
		@tmp,
		"COMMENT: \\n",
		"COMMENT: \\n");
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_nvidia1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:temp0=$rrd:nvidia_temp0:AVERAGE",
			"DEF:temp1=$rrd:nvidia_temp1:AVERAGE",
			"DEF:temp2=$rrd:nvidia_temp2:AVERAGE",
			"DEF:temp3=$rrd:nvidia_temp3:AVERAGE",
			"DEF:temp4=$rrd:nvidia_temp4:AVERAGE",
			"DEF:temp5=$rrd:nvidia_temp5:AVERAGE",
			"DEF:temp6=$rrd:nvidia_temp6:AVERAGE",
			"DEF:temp7=$rrd:nvidia_temp7:AVERAGE",
			"DEF:temp8=$rrd:nvidia_temp8:AVERAGE",
			"CDEF:allvalues=temp0,temp1,temp2,temp3,temp4,temp5,temp6,temp7,temp8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nvidia1/)) {
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
	push(@tmp, "LINE2:gpu0#FFA500:Card 0\\g");
	push(@tmp, "GPRINT:gpu0:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu3#4444EE:Card 3\\g");
	push(@tmp, "GPRINT:gpu3:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu6#EE44EE:Card 6\\g");
	push(@tmp, "GPRINT:gpu6:LAST:\\:%3.0lf%%\\n");
	push(@tmp, "LINE2:gpu1#44EEEE:Card 1\\g");
	push(@tmp, "GPRINT:gpu1:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu4#448844:Card 4\\g");
	push(@tmp, "GPRINT:gpu4:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu7#EEEE44:Card 7\\g");
	push(@tmp, "GPRINT:gpu7:LAST:\\:%3.0lf%%\\n");
	push(@tmp, "LINE2:gpu2#44EE44:Card 2\\g");
	push(@tmp, "GPRINT:gpu2:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu5#EE4444:Card 5\\g");
	push(@tmp, "GPRINT:gpu5:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu8#963C74:Card 8\\g");
	push(@tmp, "GPRINT:gpu8:LAST:\\:%3.0lf%%\\n");
        for($n = 0; $n < 9; $n++) {
                if($n < $nvidia->{max}) {
                        push(@tmpz, "LINE2:gpu" . $n . $LC[$n] . ":Card $n");
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
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_nvidia2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Percent",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:gpu0=$rrd:nvidia_gpu0:AVERAGE",
		"DEF:gpu1=$rrd:nvidia_gpu1:AVERAGE",
		"DEF:gpu2=$rrd:nvidia_gpu2:AVERAGE",
		"DEF:gpu3=$rrd:nvidia_gpu3:AVERAGE",
		"DEF:gpu4=$rrd:nvidia_gpu4:AVERAGE",
		"DEF:gpu5=$rrd:nvidia_gpu5:AVERAGE",
		"DEF:gpu6=$rrd:nvidia_gpu6:AVERAGE",
		"DEF:gpu7=$rrd:nvidia_gpu7:AVERAGE",
		"DEF:gpu8=$rrd:nvidia_gpu8:AVERAGE",
		"CDEF:allvalues=gpu0,gpu1,gpu2,gpu3,gpu4,gpu5,gpu6,gpu7,gpu8,+,+,+,+,+,+,+,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_nvidia2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Percent",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:gpu0=$rrd:nvidia_gpu0:AVERAGE",
			"DEF:gpu1=$rrd:nvidia_gpu1:AVERAGE",
			"DEF:gpu2=$rrd:nvidia_gpu2:AVERAGE",
			"DEF:gpu3=$rrd:nvidia_gpu3:AVERAGE",
			"DEF:gpu4=$rrd:nvidia_gpu4:AVERAGE",
			"DEF:gpu5=$rrd:nvidia_gpu5:AVERAGE",
			"DEF:gpu6=$rrd:nvidia_gpu6:AVERAGE",
			"DEF:gpu7=$rrd:nvidia_gpu7:AVERAGE",
			"DEF:gpu8=$rrd:nvidia_gpu8:AVERAGE",
			"CDEF:allvalues=gpu0,gpu1,gpu2,gpu3,gpu4,gpu5,gpu6,gpu7,gpu8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nvidia2/)) {
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
	push(@tmp, "LINE2:mem0#FFA500:Card 0\\g");
	push(@tmp, "GPRINT:mem0:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem3#4444EE:Card 3\\g");
	push(@tmp, "GPRINT:mem3:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem6#EE44EE:Card 6\\g");
	push(@tmp, "GPRINT:mem6:LAST:\\:%3.0lf%%\\n");
	push(@tmp, "LINE2:mem1#44EEEE:Card 1\\g");
	push(@tmp, "GPRINT:mem1:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem4#448844:Card 4\\g");
	push(@tmp, "GPRINT:mem4:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem7#EEEE44:Card 7\\g");
	push(@tmp, "GPRINT:mem7:LAST:\\:%3.0lf%%\\n");
	push(@tmp, "LINE2:mem2#44EE44:Card 2\\g");
	push(@tmp, "GPRINT:mem2:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem5#EE4444:Card 5\\g");
	push(@tmp, "GPRINT:mem5:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem8#963C74:Card 8\\g");
	push(@tmp, "GPRINT:mem8:LAST:\\:%3.0lf%%\\n");
        for($n = 0; $n < 9; $n++) {
                if($n < $nvidia->{max}) {
                        push(@tmpz, "LINE2:mem" . $n . $LC[$n] . ":Card $n");
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
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG3",
		"--title=$config->{graphs}->{_nvidia3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Percent",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		@{$cgi->{version12}},
		$zoom,
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:mem0=$rrd:nvidia_mem0:AVERAGE",
		"DEF:mem1=$rrd:nvidia_mem1:AVERAGE",
		"DEF:mem2=$rrd:nvidia_mem2:AVERAGE",
		"DEF:mem3=$rrd:nvidia_mem3:AVERAGE",
		"DEF:mem4=$rrd:nvidia_mem4:AVERAGE",
		"DEF:mem5=$rrd:nvidia_mem5:AVERAGE",
		"DEF:mem6=$rrd:nvidia_mem6:AVERAGE",
		"DEF:mem7=$rrd:nvidia_mem7:AVERAGE",
		"DEF:mem8=$rrd:nvidia_mem8:AVERAGE",
		"CDEF:allvalues=mem0,mem1,mem2,mem3,mem4,mem5,mem6,mem7,mem8,+,+,+,+,+,+,+,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_nvidia3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Percent",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:mem0=$rrd:nvidia_mem0:AVERAGE",
			"DEF:mem1=$rrd:nvidia_mem1:AVERAGE",
			"DEF:mem2=$rrd:nvidia_mem2:AVERAGE",
			"DEF:mem3=$rrd:nvidia_mem3:AVERAGE",
			"DEF:mem4=$rrd:nvidia_mem4:AVERAGE",
			"DEF:mem5=$rrd:nvidia_mem5:AVERAGE",
			"DEF:mem6=$rrd:nvidia_mem6:AVERAGE",
			"DEF:mem7=$rrd:nvidia_mem7:AVERAGE",
			"DEF:mem8=$rrd:nvidia_mem8:AVERAGE",
			"CDEF:allvalues=mem0,mem1,mem2,mem3,mem4,mem5,mem6,mem7,mem8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nvidia3/)) {
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
