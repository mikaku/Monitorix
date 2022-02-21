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

package du;

use strict;
use warnings;
use Monitorix;
use RRDs;
use POSIX qw(strftime);
use Exporter 'import';
our @EXPORT = qw(du_init du_update du_cgi);

sub du_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $du = $config->{du};

	my $info;
	my @ds;
	my @rra;
	my @ds_to_change_heartbeat;
	my $rrd_heartbeat;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	my $heartbeat = 120;
	my $refresh_interval = ($config->{du}->{refresh_interval} || 0);
	if($refresh_interval > 0) {
		$heartbeat = 2 * $refresh_interval;
	}

	my @disk_list = split(',', $du->{list});

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
			if(index($key, 'ds[') == 0) {
				if(index($key, '.minimal_heartbeat') != -1) {
					$rrd_heartbeat = $info->{$key};
					if($rrd_heartbeat != $heartbeat) {
						my $ds_name = substr($key, 3, index($key, ']') - 3);
						push(@ds_to_change_heartbeat, $ds_name);
					}
				}
			}
		}
		if(scalar(@ds) / 9 != scalar(@disk_list)) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(@disk_list) . ") and $rrd (" . scalar(@ds) / 9 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if(scalar(@rra) < 12 + (4 * $config->{max_historic_years})) {
			logger("$myself: Detected size mismatch between 'max_historic_years' (" . $config->{max_historic_years} . ") and $rrd (" . ((scalar(@rra) -12) / 4) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if((-e $rrd) && scalar(@ds_to_change_heartbeat) > 0) {
			logger("$myself: Detected heartbeat mismatch between set (" . $heartbeat . ") and $rrd (" . $rrd_heartbeat . "). Tuning it accordingly.");
			my @tune_arguments;
			foreach(@ds_to_change_heartbeat) {
				push(@tune_arguments, "-h");
				push(@tune_arguments, "$_:$heartbeat");
			}

			RRDs::tune($rrd, @tune_arguments);
			my $err = RRDs::error;
			logger("ERROR: while tuning $rrd: $err") if $err;
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
		for($n = 0; $n < scalar(@disk_list); $n++) {
			push(@tmp, "DS:du" . $n . "_d1:GAUGE:" . $heartbeat . ":0:U");
			push(@tmp, "DS:du" . $n . "_d2:GAUGE:" . $heartbeat . ":0:U");
			push(@tmp, "DS:du" . $n . "_d3:GAUGE:" . $heartbeat . ":0:U");
			push(@tmp, "DS:du" . $n . "_d4:GAUGE:" . $heartbeat . ":0:U");
			push(@tmp, "DS:du" . $n . "_d5:GAUGE:" . $heartbeat . ":0:U");
			push(@tmp, "DS:du" . $n . "_d6:GAUGE:" . $heartbeat . ":0:U");
			push(@tmp, "DS:du" . $n . "_d7:GAUGE:" . $heartbeat . ":0:U");
			push(@tmp, "DS:du" . $n . "_d8:GAUGE:" . $heartbeat . ":0:U");
			push(@tmp, "DS:du" . $n . "_d9:GAUGE:" . $heartbeat . ":0:U");
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

sub du_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $du = $config->{du};
	my $args = $du->{extra_args} || "";
	my $use_nan_for_missing_data = lc($du->{use_nan_for_missing_data} || "") eq "y" ? 1 : 0;

	my @dirs;

	my $n;
	my $str;
	my $rrdata = "N";

	my $refresh_interval = ($config->{du}->{refresh_interval} || 0);
	if($refresh_interval > 60) {
		# If desired refreshed only every refresh_interval seconds.
		# This logic will refresh atleast once a day.
		my (undef, $min, $hour) = localtime(time);
		return if(($min + 60 * $hour) % int($refresh_interval / 60));
	}

	my @disk_list = split(',', $du->{list});

	my $e = 0;
	while($e < scalar(@disk_list)) {
		my $type;
		my $e2 = 0;

		$type = lc($du->{type}->{$e} || "");

		# default type is 'size'
		$type = "size" if $type eq "";

		foreach my $i (split(',', $du->{desc}->{$e})) {
			my $line;

			$dirs[$e][$e2] = ($use_nan_for_missing_data ? (0+"nan") : 0) unless defined $dirs[$e][$e2];
			$str = trim($i);
			if(-d $str) {
				if($type eq "size") {
					$line = `du -ks $args "$str"`;	# in KB
					if($line =~ /(^\d+)\s+/) {
						$dirs[$e][$e2] = $1;
					}
				} elsif($type eq "files") {
					$line = `ls "$str"/* | wc -l`;
					if($line =~ /(^\d+)$/) {
						$dirs[$e][$e2] = $1;
					}
				} else {
					logger("$myself: ERROR: unrecognized type '$type'.");
				}
			} else {
				logger("$myself: ERROR: '$str' is not a directory");
			}
			$e2++;
		}
		$e++;
	}

	$e = 0;
	while($e < scalar(@disk_list)) {
		for($n = 0; $n < 9; $n++) {
			$dirs[$e][$n] = ($use_nan_for_missing_data ? (0+"nan") : 0) unless defined $dirs[$e][$n];
			$rrdata .= ":" . $dirs[$e][$n];
		}
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub du_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $du = $config->{du};
	my @rigid = split(',', ($du->{rigid} || ""));
	my @limit = split(',', ($du->{limit} || ""));
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
	my $type_label;

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
	my @disk_list = split(',', $du->{list});

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
		for($n = 0; $n < scalar(@disk_list); $n++) {
			$line1 = "";
			foreach my $i (split(',', $du->{desc}->{$n})) {
				$i = trim($i);
				$str = $du->{dirmap}->{$i} || $i;
				$str = sprintf("%20s", substr($str, 0, 20));
				$line1 .= "                     ";
				$line2 .= sprintf(" %20s", $str);
				$line3 .= "---------------------";
			}
			if($line1) {
				my $i = length($line1);
				push(@output, sprintf(sprintf("%${i}s", sprintf("%s", trim($disk_list[$n])))));
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
			for($n2 = 0; $n2 < scalar(@disk_list); $n2++) {
				$n3 = 0;
				foreach my $i (split(',', $du->{desc}->{$n2})) {
					$from = $n2 * 9 + $n3++;
					$to = $from + 1;
					my ($j) = @$line[$from..$to];
					@row = ($j);
					push(@output, sprintf("%17d KB ", @row));
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

	for($n = 0; $n < scalar(@disk_list); $n++) {
		$str = $u . $package . $n . "." . $tf->{when} . ".$imgfmt_lc";
		push(@IMG, $str);
		unlink("$IMG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . $package . $n . "z." . $tf->{when} . ".$imgfmt_lc";
			push(@IMGz, $str);
			unlink("$IMG_DIR" . $str);
		}
	}

	my $graphs_per_row = $du->{graphs_per_row};
	my @linpad =(0) x scalar(@disk_list);
	if ($graphs_per_row > 1) {
		for(my $n = 0; $n < scalar(@disk_list); $n++) {
			my @ls = split(',', $du->{desc}->{$n});
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

	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	$n = 0;
	while($n < scalar(@disk_list)) {
		if($title) {
			if($n == 0) {
				push(@output, main::graph_header($title, $graphs_per_row));
			}
			push(@output, "    <tr>\n");
		}
		for($n2 = 0; $n2 < $graphs_per_row; $n2++) {
			my $type;
			my @DEF0;
			my @CDEF0;

			last unless $n < scalar(@disk_list);
			if($title) {
				push(@output, "    <td>\n");
			}
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			my $e = 0;

			$type = lc($du->{type}->{$n} || "");

			if($type eq "files") {
				$type_label = "files";
				push(@DEF0, "DEF:d1=$rrd:du" . $n . "_d1:AVERAGE");
				push(@DEF0, "DEF:d2=$rrd:du" . $n . "_d2:AVERAGE");
				push(@DEF0, "DEF:d3=$rrd:du" . $n . "_d3:AVERAGE");
				push(@DEF0, "DEF:d4=$rrd:du" . $n . "_d4:AVERAGE");
				push(@DEF0, "DEF:d5=$rrd:du" . $n . "_d5:AVERAGE");
				push(@DEF0, "DEF:d6=$rrd:du" . $n . "_d6:AVERAGE");
				push(@DEF0, "DEF:d7=$rrd:du" . $n . "_d7:AVERAGE");
				push(@DEF0, "DEF:d8=$rrd:du" . $n . "_d8:AVERAGE");
				push(@DEF0, "DEF:d9=$rrd:du" . $n . "_d9:AVERAGE");
				push(@CDEF0, "CDEF:allvalues=d1,d2,d3,d4,d5,d6,d7,d8,d9,+,+,+,+,+,+,+,+");
			# default type is 'bytes'
			} else {
				$type_label = "bytes";
				push(@DEF0, "DEF:dk1=$rrd:du" . $n . "_d1:AVERAGE");
				push(@DEF0, "DEF:dk2=$rrd:du" . $n . "_d2:AVERAGE");
				push(@DEF0, "DEF:dk3=$rrd:du" . $n . "_d3:AVERAGE");
				push(@DEF0, "DEF:dk4=$rrd:du" . $n . "_d4:AVERAGE");
				push(@DEF0, "DEF:dk5=$rrd:du" . $n . "_d5:AVERAGE");
				push(@DEF0, "DEF:dk6=$rrd:du" . $n . "_d6:AVERAGE");
				push(@DEF0, "DEF:dk7=$rrd:du" . $n . "_d7:AVERAGE");
				push(@DEF0, "DEF:dk8=$rrd:du" . $n . "_d8:AVERAGE");
				push(@DEF0, "DEF:dk9=$rrd:du" . $n . "_d9:AVERAGE");
				push(@CDEF0, "CDEF:allvalues=dk1,dk2,dk3,dk4,dk5,dk6,dk7,dk8,dk9,+,+,+,+,+,+,+,+");
				push(@CDEF0, "CDEF:d1=dk1,1024,*");
				push(@CDEF0, "CDEF:d2=dk2,1024,*");
				push(@CDEF0, "CDEF:d3=dk3,1024,*");
				push(@CDEF0, "CDEF:d4=dk4,1024,*");
				push(@CDEF0, "CDEF:d5=dk5,1024,*");
				push(@CDEF0, "CDEF:d6=dk6,1024,*");
				push(@CDEF0, "CDEF:d7=dk7,1024,*");
				push(@CDEF0, "CDEF:d8=dk8,1024,*");
				push(@CDEF0, "CDEF:d9=dk9,1024,*");
			}

			foreach my $i (split(',', $du->{desc}->{$n})) {
				$i = trim($i);
				$str = $du->{dirmap}->{$i} || $i;
				$str = sprintf("%-40s", substr($str, 0, 40));
				push(@tmp, "LINE2:d" . ($e + 1) . $LC[$e] . ":$str");
				if($type eq "files") {
					push(@tmp, "GPRINT:d" . ($e + 1) . ":LAST: Current\\:%7.0lf%s\\n");
				} else {
					push(@tmp, "GPRINT:d" . ($e + 1) . ":LAST: Current\\:%7.1lf%s\\n");
				}
				push(@tmpz, "LINE2:d" . ($e + 1) . $LC[$e] . ":$str");
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
			$str = substr(trim($disk_list[$n]), 0, 25);
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$n]",
				"--title=$str  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=$type_label",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				@DEF0,
				@CDEF0,
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
					"--vertical-label=$type_label",
					"--width=$width",
					"--height=$height",
					@full_size_mode,
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$colors->{graph_colors}},
					@DEF0,
					@CDEF0,
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$n]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /du$n/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$n], IMG => $IMG[$n]) . "\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
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
