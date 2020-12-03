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

package ntp;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(ntp_init ntp_update ntp_cgi);

sub ntp_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $ntp = $config->{ntp};

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
		if(scalar(@ds) / 14 != scalar(my @nl = split(',', $ntp->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @nl = split(',', $ntp->{list})) . ") and $rrd (" . scalar(@ds) / 14 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @nl = split(',', $ntp->{list})); $n++) {
			push(@tmp, "DS:ntp" . $n . "_del:GAUGE:120:U:U");
			push(@tmp, "DS:ntp" . $n . "_off:GAUGE:120:U:U");
			push(@tmp, "DS:ntp" . $n . "_jit:GAUGE:120:U:U");
			push(@tmp, "DS:ntp" . $n . "_str:GAUGE:120:0:U");
			push(@tmp, "DS:ntp" . $n . "_c01:GAUGE:120:0:U");
			push(@tmp, "DS:ntp" . $n . "_c02:GAUGE:120:0:U");
			push(@tmp, "DS:ntp" . $n . "_c03:GAUGE:120:0:U");
			push(@tmp, "DS:ntp" . $n . "_c04:GAUGE:120:0:U");
			push(@tmp, "DS:ntp" . $n . "_c05:GAUGE:120:0:U");
			push(@tmp, "DS:ntp" . $n . "_c06:GAUGE:120:0:U");
			push(@tmp, "DS:ntp" . $n . "_c07:GAUGE:120:0:U");
			push(@tmp, "DS:ntp" . $n . "_c08:GAUGE:120:0:U");
			push(@tmp, "DS:ntp" . $n . "_c09:GAUGE:120:0:U");
			push(@tmp, "DS:ntp" . $n . "_c10:GAUGE:120:0:U");
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

sub ntp_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $ntp = $config->{ntp};
	my $args = $ntp->{extra_args} || "";

	my @data;
	my $del;
	my $off;
	my $jit;
	my $str;
	my $cod;

	my $n;
	my $rrdata = "N";

	my $e = 0;
	foreach my $h (split(',', $ntp->{list})) {
		$h = trim($h);
		open(IN, "ntpq -pn $args $h |");
		@data = <IN>;
		close(IN);
		# sorts @data in reverse order to let 'o' take precedence over '*'.
		@data = sort {$b cmp $a} @data;
		$cod = $str = $del = $off = $jit = 0;
		foreach(@data) {
			# select the first peer with Status Word as '*' or 'o'
			if(/^[\*o]/) {
				(undef, $cod, $str, undef, undef, undef, undef, $del, $off, $jit) = split(' ', $_);
				$cod =~ s/\.//g;
				chomp($jit);
				last;
			}
		}
		$del = 0 unless defined($del);
		$off = 0 unless defined($off);
		$jit = 0 unless defined($jit);
		$str = 0 unless defined($str);
		$del /= 1000;
		$off /= 1000;
		$jit /= 1000;
		$rrdata .= ":$del:$off:$jit:$str";
		my @i = split(',', $ntp->{desc}->{$h});
		for($n = 0; $n < 10; $n++) {
			if($cod eq trim($i[$n])) {
				$rrdata .= ":1";
			} else {
				$rrdata .= ":0";
			}
		}
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub ntp_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $ntp = $config->{ntp};
	my @rigid = split(',', ($ntp->{rigid} || ""));
	my @limit = split(',', ($ntp->{limit} || ""));
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
	my @AC = (
		"#FFA500",
		"#44EEEE",
		"#44EE44",
		"#4444EE",
		"#448844",
		"#EE4444",
		"#EE44EE",
		"#EEEE44",
		"#B4B444",
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
		for($n = 0; $n < scalar(my @nl = split(',', $ntp->{list})); $n++) {
			my $l = trim($nl[$n]);
			$line1 = "                                  ";
			$line2 .= "     Delay   Offset   Jitter   Str";
			$line3 .= "----------------------------------";
			foreach (split(',', $ntp->{desc}->{$l})) {
				$line1 .= "     ";
				$line2 .= sprintf(" %4s", trim($_));
				$line3 .= "-----";
			}
			if($line1) {
				my $i = length($line1);
				push(@output, sprintf(sprintf("%${i}s", sprintf("NTP Server: %s", $l))));
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
			push(@output, sprintf(" %2d$tf->{tc}", $time));
			for($n2 = 0; $n2 < scalar(my @nl = split(',', $ntp->{list})); $n2++) {
				my $l = trim($nl[$n2]);
				undef(@row);
				$from = $n2 * 14;
				$to = $from + 4;
				push(@row, @$line[$from..$to]);
				push(@output, sprintf("  %8.3f %8.3f %8.3f   %2d ", @row));
				for($n3 = 0; $n3 < scalar(my @i = (split(',', $ntp->{desc}->{$l}))); $n3++) {
					$from = $n2 * 14 + 4 + $n3;
					my ($c) = @$line[$from] || 0;
					push(@output, sprintf(" %4d", $c));
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

	for($n = 0; $n < scalar(my @nl = split(',', $ntp->{list})); $n++) {
		for($n2 = 1; $n2 <= 3; $n2++) {
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
	foreach my $host (split(',', $ntp->{list})) {
		$host = trim($host);
		if($e) {
			push(@output, "   <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}
		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:ntp" . $e . "_del#4444EE:Delay");
		push(@tmp, "GPRINT:ntp" . $e . "_del" . ":LAST:     Current\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_del" . ":AVERAGE:    Average\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_del" . ":MIN:    Min\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_del" . ":MAX:    Max\\:%6.3lf\\n");
		push(@tmp, "LINE2:ntp" . $e . "_off#44EEEE:Offset");
		push(@tmp, "GPRINT:ntp" . $e . "_off" . ":LAST:    Current\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_off" . ":AVERAGE:    Average\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_off" . ":MIN:    Min\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_off" . ":MAX:    Max\\:%6.3lf\\n");
		push(@tmp, "LINE2:ntp" . $e . "_jit#EE4444:Jitter");
		push(@tmp, "GPRINT:ntp" . $e . "_jit" . ":LAST:    Current\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_jit" . ":AVERAGE:    Average\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_jit" . ":MIN:    Min\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_jit" . ":MAX:    Max\\:%6.3lf\\n");
		push(@tmpz, "LINE2:ntp" . $e . "_del#4444EE:Delay");
		push(@tmpz, "LINE2:ntp" . $e . "_off#44EEEE:Offset");
		push(@tmpz, "LINE2:ntp" . $e . "_jit#EE4444:Jitter");
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata_p#$colors->{gap}:");
			push(@tmp, "AREA:wrongdata_m#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata_p#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata_m#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata_p=allvalues_p,UN,INF,UNKN,IF");
			push(@CDEF, "CDEF:wrongdata_m=allvalues_m,0,LT,INF,-1,*,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 3]",
			"--title=$config->{graphs}->{_ntp1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Seconds",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:ntp" . $e . "_del=$rrd:ntp" . $e . "_del:AVERAGE",
			"DEF:ntp" . $e . "_off=$rrd:ntp" . $e . "_off:AVERAGE",
			"DEF:ntp" . $e . "_jit=$rrd:ntp" . $e . "_jit:AVERAGE",
			"CDEF:allvalues_p=ntp" . $e . "_del,ntp" . $e . "_off,ntp" . $e . "_jit,+,+",
			"CDEF:allvalues_m=allvalues_p,UN,-1,UNKN,IF",
			@CDEF,
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			"COMMENT: \\n",);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3]",
				"--title=$config->{graphs}->{_ntp1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Seconds",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:ntp" . $e . "_del=$rrd:ntp" . $e . "_del:AVERAGE",
				"DEF:ntp" . $e . "_off=$rrd:ntp" . $e . "_off:AVERAGE",
				"DEF:ntp" . $e . "_jit=$rrd:ntp" . $e . "_jit:AVERAGE",
				"CDEF:allvalues_p=ntp" . $e . "_del,ntp" . $e . "_off,ntp" . $e . "_jit,+,+",
				"CDEF:allvalues_m=allvalues_p,UN,-1,UNKN,IF",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /ntp$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3] . "'>\n");
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
		push(@tmp, "LINE2:ntp" . $e . "_str#44EEEE:Stratum");
		push(@tmp, "GPRINT:ntp" . $e . "_str" . ":LAST:              Current\\:%2.0lf\\n");
		push(@tmpz, "LINE2:ntp" . $e . "_str#44EEEE:Stratum");
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
		}
		$pic = $rrd{$version}->("$IMG_DIR" . $IMG[$e * 3 + 1],
			"--title=$config->{graphs}->{_ntp2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Level",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:ntp" . $e . "_str=$rrd:ntp" . $e . "_str:AVERAGE",
			"CDEF:allvalues=ntp" . $e . "_str",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . $IMG[$e * 3 + 1] . ": $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . $IMGz[$e * 3 + 1],
				"--title=$config->{graphs}->{_ntp2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Level",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:ntp" . $e . "_str=$rrd:ntp" . $e . "_str:AVERAGE",
				"CDEF:allvalues=ntp" . $e . "_str",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . $IMGz[$e * 3 + 1] . ": $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /ntp$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 1] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		my @i = split(',', $ntp->{desc}->{$host});
		for($n = 0; $n < 10; $n++) {
			if(trim($i[$n])) {
				$str = sprintf("%-4s", trim($i[$n]));
				push(@tmp, "LINE2:ntp" . $e . "_c" . sprintf("%02d", ($n + 1)) . $AC[$n] . ":$str");
				push(@tmp, "COMMENT:   \\g");
				push(@tmpz, "LINE2:ntp" . $e . "_c" . sprintf("%02d", ($n + 1)) . $AC[$n] . ":$str");
				if(!(($n + 1) % 5)) {
					push(@tmp, ("COMMENT: \\n"));
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
		}
		$pic = $rrd{$version}->("$IMG_DIR" . $IMG[$e * 3 + 2],
			"--title=$config->{graphs}->{_ntp3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Hits",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:ntp" . $e . "_c01=$rrd:ntp" . $e . "_c01:AVERAGE",
			"DEF:ntp" . $e . "_c02=$rrd:ntp" . $e . "_c02:AVERAGE",
			"DEF:ntp" . $e . "_c03=$rrd:ntp" . $e . "_c03:AVERAGE",
			"DEF:ntp" . $e . "_c04=$rrd:ntp" . $e . "_c04:AVERAGE",
			"DEF:ntp" . $e . "_c05=$rrd:ntp" . $e . "_c05:AVERAGE",
			"DEF:ntp" . $e . "_c06=$rrd:ntp" . $e . "_c06:AVERAGE",
			"DEF:ntp" . $e . "_c07=$rrd:ntp" . $e . "_c07:AVERAGE",
			"DEF:ntp" . $e . "_c08=$rrd:ntp" . $e . "_c08:AVERAGE",
			"DEF:ntp" . $e . "_c09=$rrd:ntp" . $e . "_c09:AVERAGE",
			"DEF:ntp" . $e . "_c10=$rrd:ntp" . $e . "_c10:AVERAGE",
			"CDEF:allvalues=ntp" . $e . "_c01,ntp" . $e . "_c02,ntp" . $e . "_c03,ntp" . $e . "_c04,ntp" . $e . "_c05,ntp" . $e . "_c06,ntp" . $e . "_c07,ntp" . $e . "_c08,ntp" . $e . "_c09,ntp" . $e . "_c10,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . $IMG[$e * 3 + 2] . ": $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . $IMGz[$e * 3 + 2],
				"--title=$config->{graphs}->{_ntp3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Hits",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:ntp" . $e . "_c01=$rrd:ntp" . $e . "_c01:AVERAGE",
				"DEF:ntp" . $e . "_c02=$rrd:ntp" . $e . "_c02:AVERAGE",
				"DEF:ntp" . $e . "_c03=$rrd:ntp" . $e . "_c03:AVERAGE",
				"DEF:ntp" . $e . "_c04=$rrd:ntp" . $e . "_c04:AVERAGE",
				"DEF:ntp" . $e . "_c05=$rrd:ntp" . $e . "_c05:AVERAGE",
				"DEF:ntp" . $e . "_c06=$rrd:ntp" . $e . "_c06:AVERAGE",
				"DEF:ntp" . $e . "_c07=$rrd:ntp" . $e . "_c07:AVERAGE",
				"DEF:ntp" . $e . "_c08=$rrd:ntp" . $e . "_c08:AVERAGE",
				"DEF:ntp" . $e . "_c09=$rrd:ntp" . $e . "_c09:AVERAGE",
				"DEF:ntp" . $e . "_c10=$rrd:ntp" . $e . "_c10:AVERAGE",
				"CDEF:allvalues=ntp" . $e . "_c01,ntp" . $e . "_c02,ntp" . $e . "_c03,ntp" . $e . "_c04,ntp" . $e . "_c05,ntp" . $e . "_c06,ntp" . $e . "_c07,ntp" . $e . "_c08,ntp" . $e . "_c09,ntp" . $e . "_c10,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . $IMGz[$e * 3 + 2] . ": $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /ntp$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 2] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");
	
			push(@output, "    <tr>\n");
			push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
			push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
			push(@output, "       <font size='-1'>\n");
			push(@output, "        <b style='{color: " . $colors->{title_fg_color} . "}'>&nbsp;&nbsp;$host</b>\n");
			push(@output, "       </font></font>\n");
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
