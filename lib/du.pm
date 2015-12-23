#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2015 by Jordi Sanfeliu <jordi@fibranet.cat>
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
		if(scalar(@ds) / 9 != scalar(my @fl = split(',', $du->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @fl = split(',', $du->{list})) . ") and $rrd (" . scalar(@ds) / 9 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @fl = split(',', $du->{list})); $n++) {
			push(@tmp, "DS:du" . $n . "_d1:GAUGE:120:0:U");
			push(@tmp, "DS:du" . $n . "_d2:GAUGE:120:0:U");
			push(@tmp, "DS:du" . $n . "_d3:GAUGE:120:0:U");
			push(@tmp, "DS:du" . $n . "_d4:GAUGE:120:0:U");
			push(@tmp, "DS:du" . $n . "_d5:GAUGE:120:0:U");
			push(@tmp, "DS:du" . $n . "_d6:GAUGE:120:0:U");
			push(@tmp, "DS:du" . $n . "_d7:GAUGE:120:0:U");
			push(@tmp, "DS:du" . $n . "_d8:GAUGE:120:0:U");
			push(@tmp, "DS:du" . $n . "_d9:GAUGE:120:0:U");
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

	my $seek_pos;
	my $logsize;
	my @dirs;

	my $n;
	my $str;
	my $rrdata = "N";

	my $e = 0;
	while($e < scalar(my @dl = split(',', $du->{list}))) {
		my $e2 = 0;
		foreach my $i (split(',', $du->{desc}->{$e})) {
			my $line;

			$dirs[$e][$e2] = 0 unless defined $dirs[$e][$e2];
			$str = trim($i);
			if(-d $str) {
				$line = `du -ks $args "$str"`;	# in KB
				if($line =~ /(^\d+)\s+/) {
					$dirs[$e][$e2] = $1;
				}
			} else {
				logger("$myself: ERROR: '$str' is not a directory");
			}
			$e2++;
		}
		$e++;
	}

	$e = 0;
	while($e < scalar(my @dl = split(',', $du->{list}))) {
		for($n = 0; $n < 9; $n++) {
			$dirs[$e][$n] = 0 unless defined $dirs[$e][$n];
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
	my $pic;
	my $picz;
	my $picz_width;
	my $picz_height;

	my $u = "";
	my $width;
	my $height;
	my @riglim;
	my @PNG;
	my @PNGz;
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
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	$title = !$silent ? $title : "";


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
		my $line1;
		my $line2;
		my $line3;
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		print("    ");
		for($n = 0; $n < scalar(my @dl = split(',', $du->{list})); $n++) {
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
				printf(sprintf("%${i}s", sprintf("%s", trim($dl[$n]))));
			}
		}
		print("\n");
		print("Time$line2\n");
		print("----$line3 \n");
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
			printf(" %2d$tf->{tc} ", $time);
			for($n2 = 0; $n2 < scalar(my @dl = split(',', $du->{list})); $n2++) {
				$n3 = 0;
				foreach my $i (split(',', $du->{desc}->{$n2})) {
					$from = $n2 * 9 + $n3++;
					$to = $from + 1;
					my ($j) = @$line[$from..$to];
					@row = ($j);
					printf("%17d KB ", @row);
				}
			}
			print("\n");
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

	for($n = 0; $n < scalar(my @dl = split(',', $du->{list})); $n++) {
		$str = $u . $package . $n . "." . $tf->{when} . ".png";
		push(@PNG, $str);
		unlink("$PNG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . $package . $n . "z." . $tf->{when} . ".png";
			push(@PNGz, $str);
			unlink("$PNG_DIR" . $str);
		}
	}

	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	$n = 0;
	while($n < scalar(my @dl = split(',', $du->{list}))) {
		if($title) {
			if($n == 0) {
				main::graph_header($title, $du->{graphs_per_row});
			}
			print("    <tr>\n");
		}
		for($n2 = 0; $n2 < $du->{graphs_per_row}; $n2++) {
			last unless $n < scalar(my @dl = split(',', $du->{list}));
			if($title) {
				print("    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
			}
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			my $e = 0;
			foreach my $i (split(',', $du->{desc}->{$n})) {
				$i = trim($i);
				$str = $du->{dirmap}->{$i} || $i;
				$str = sprintf("%-40s", substr($str, 0, 40));
				push(@tmp, "LINE2:d" . ($e + 1) . $LC[$e] . ":$str");
				push(@tmp, "GPRINT:d" . ($e + 1) . ":LAST: Current\\:%7.1lf%s\\n");
				push(@tmpz, "LINE2:d" . ($e + 1) . $LC[$e] . ":$str");
				$e++;
			}
			while($e < 9) {
				push(@tmp, "COMMENT: \\n");
				$e++;
			}
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{medium});
			$str = substr(trim($dl[$n]), 0, 25);
			$pic = $rrd{$version}->("$PNG_DIR" . "$PNG[$n]",
				"--title=$str  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=bytes",
				"--width=$width",
				"--height=$height",
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:dk1=$rrd:du" . $n . "_d1:AVERAGE",
				"DEF:dk2=$rrd:du" . $n . "_d2:AVERAGE",
				"DEF:dk3=$rrd:du" . $n . "_d3:AVERAGE",
				"DEF:dk4=$rrd:du" . $n . "_d4:AVERAGE",
				"DEF:dk5=$rrd:du" . $n . "_d5:AVERAGE",
				"DEF:dk6=$rrd:du" . $n . "_d6:AVERAGE",
				"DEF:dk7=$rrd:du" . $n . "_d7:AVERAGE",
				"DEF:dk8=$rrd:du" . $n . "_d8:AVERAGE",
				"DEF:dk9=$rrd:du" . $n . "_d9:AVERAGE",
				"CDEF:allvalues=dk1,dk2,dk3,dk4,dk5,dk6,dk7,dk8,dk9,+,+,+,+,+,+,+,+",
				"CDEF:d1=dk1,1024,*",
				"CDEF:d2=dk2,1024,*",
				"CDEF:d3=dk3,1024,*",
				"CDEF:d4=dk4,1024,*",
				"CDEF:d5=dk5,1024,*",
				"CDEF:d6=dk6,1024,*",
				"CDEF:d7=dk7,1024,*",
				"CDEF:d8=dk8,1024,*",
				"CDEF:d9=dk9,1024,*",
				@CDEF,
				@tmp);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG[$n]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$PNG_DIR" . "$PNGz[$n]",
					"--title=$str  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=PNG",
					"--vertical-label=bytes",
					"--width=$width",
					"--height=$height",
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$cgi->{version12_small}},
					@{$colors->{graph_colors}},
					"DEF:dk1=$rrd:du" . $n . "_d1:AVERAGE",
					"DEF:dk2=$rrd:du" . $n . "_d2:AVERAGE",
					"DEF:dk3=$rrd:du" . $n . "_d3:AVERAGE",
					"DEF:dk4=$rrd:du" . $n . "_d4:AVERAGE",
					"DEF:dk5=$rrd:du" . $n . "_d5:AVERAGE",
					"DEF:dk6=$rrd:du" . $n . "_d6:AVERAGE",
					"DEF:dk7=$rrd:du" . $n . "_d7:AVERAGE",
					"DEF:dk8=$rrd:du" . $n . "_d8:AVERAGE",
					"DEF:dk9=$rrd:du" . $n . "_d9:AVERAGE",
					"CDEF:allvalues=dk1,dk2,dk3,dk4,dk5,dk6,dk7,dk8,dk9,+,+,+,+,+,+,+,+",
					"CDEF:d1=dk1,1024,*",
					"CDEF:d2=dk2,1024,*",
					"CDEF:d3=dk3,1024,*",
					"CDEF:d4=dk4,1024,*",
					"CDEF:d5=dk5,1024,*",
					"CDEF:d6=dk6,1024,*",
					"CDEF:d7=dk7,1024,*",
					"CDEF:d8=dk8,1024,*",
					"CDEF:d9=dk9,1024,*",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				print("ERROR: while graphing $PNG_DIR" . "$PNGz[$n]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /du$n/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNGz[$n] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$n] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNGz[$n] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$n] . "' border='0'></a>\n");
					}
				} else {
					print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$n] . "'>\n");
				}
			}
			if($title) {
				print("    </td>\n");
			}
			$n++;
		}
		if($title) {
			print("    </tr>\n");
		}
	}
	if($title) {
		main::graph_footer();
	}
	print("  <br>\n");
	return;
}

1;
