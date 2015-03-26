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

package hptemp;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(hptemp_init hptemp_update hptemp_cgi);

sub hptemp_init {
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

	# checks if 'hplog' does exists.
	if(!open(IN, "hplog -t |")) {
		logger("$myself: unable to execute 'hplog'. $!");
		return;
	}

	# save the output of 'hplog -t' since only 'root' is able to run it
	my @data = <IN>;
	close(IN);
	open(OUT, "> $config->{base_dir}/cgi/monitorix.hplog");
	print(OUT @data);
	close(OUT);

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
				"DS:hptemp1_1:GAUGE:120:0:100",
				"DS:hptemp1_2:GAUGE:120:0:100",
				"DS:hptemp1_3:GAUGE:120:0:100",
				"DS:hptemp1_4:GAUGE:120:0:100",
				"DS:hptemp1_5:GAUGE:120:0:100",
				"DS:hptemp1_6:GAUGE:120:0:100",
				"DS:hptemp1_7:GAUGE:120:0:100",
				"DS:hptemp1_8:GAUGE:120:0:100",
				"DS:hptemp2_1:GAUGE:120:0:100",
				"DS:hptemp2_2:GAUGE:120:0:100",
				"DS:hptemp2_3:GAUGE:120:0:100",
				"DS:hptemp2_4:GAUGE:120:0:100",
				"DS:hptemp2_5:GAUGE:120:0:100",
				"DS:hptemp2_6:GAUGE:120:0:100",
				"DS:hptemp3_1:GAUGE:120:0:100",
				"DS:hptemp3_2:GAUGE:120:0:100",
				"DS:hptemp3_3:GAUGE:120:0:100",
				"DS:hptemp3_4:GAUGE:120:0:100",
				"DS:hptemp3_5:GAUGE:120:0:100",
				"DS:hptemp3_6:GAUGE:120:0:100",
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

sub hptemp_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $hptemp = $config->{hptemp};

	my @hptemp1;
	my @hptemp2;
	my @hptemp3;

	my $l;
	my $n;
	my $rrdata = "N";

	if(!open(IN, "hplog -t |")) {
		logger("$myself: unable to execute 'hplog'. $!");
		return;
	}
	my @data = <IN>;
	close(IN);
	my $str;
	for($l = 0; $l < scalar(@data); $l++) {
		foreach my $t (split(',', ($hptemp->{graph_0} || ""))) {
			$str = sprintf("%2d", trim($t));
			if($data[$l] =~ m/^$str  /) {
				my $temp = trim(substr($data[$l], 47, 3));
				chomp($temp);
				$temp =~ s/C//;
				push(@hptemp1, map {$_ eq "---" ? 0 : $_} ($temp));
			}
		}
		foreach my $t (split(',', ($hptemp->{graph_1} || ""))) {
			$str = sprintf("%2d", trim($t));
			if($data[$l] =~ m/^$str  /) {
				my $temp = trim(substr($data[$l], 47, 3));
				chomp($temp);
				$temp =~ s/C//;
				push(@hptemp2, map {$_ eq "---" ? 0 : $_} ($temp));
			}
		}
		foreach my $t (split(',', ($hptemp->{graph_2} || ""))) {
			$str = sprintf("%2d", trim($t));
			if($data[$l] =~ m/^$str  /) {
				my $temp = trim(substr($data[$l], 47, 3));
				chomp($temp);
				$temp =~ s/C//;
				push(@hptemp3, map {$_ eq "---" ? 0 : $_} ($temp));
			}
		}
	}
	for($n = 0; $n < 8; $n++) {
		$hptemp1[$n] = 0 unless $hptemp1[$n];
		$rrdata .= ":$hptemp1[$n]";
	}
	for($n = 0; $n < 6; $n++) {
		$hptemp2[$n] = 0 unless $hptemp2[$n];
		$rrdata .= ":$hptemp2[$n]";
	}
	for($n = 0; $n < 6; $n++) {
		$hptemp3[$n] = 0 unless $hptemp3[$n];
		$rrdata .= ":$hptemp3[$n]";
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub hptemp_cgi {
	my ($package, $config, $cgi) = @_;

	my $hptemp = $config->{hptemp};
	my @rigid = split(',', ($hptemp->{rigid} || ""));
	my @limit = split(',', ($hptemp->{limit} || ""));
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
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $n;
	my $id;
	my $str;
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
	);

	$version = "old" if $RRDs::VERSION < 1.3;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	$title = !$silent ? $title : "";

	if(lc($config->{temperature_scale}) eq "f") {
		$temp_scale = "Fahrenheit";
	}

	open(IN, "monitorix.hplog");
	my @hplog = <IN>;
	close(IN);

	if(!scalar(@hplog)) {
		print("WARNING: 'hplog' command output is empty.");
	}


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
		my $str;
		my $line1;
		my $line2;
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		foreach my $t (split(',', $hptemp->{graph_0}), split(',', $hptemp->{graph_1}), split(',', $hptemp->{graph_2})) {
			$id = sprintf("%2d", trim($t));
			for($n = 0; $n < scalar(@hplog); $n++) {
				$_ = $hplog[$n];
				if(/^$id  /) {
					$str = substr($_, 17, 8);
					$str = sprintf("%8s", $str);
					$line1 .= "  ";
					$line1 .= $str;
					$line2 .= "----------";
				}
			}
		}
		print("Time $line1 \n");
		print("-----$line2\n");
		my $line;
		my @row;
		my $time;
		my $n2;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			printf(" %2d$tf->{tc} ", $time);
			undef($line1);
			undef(@row);
			for($n2 = 0; $n2 < scalar(my @hp = split(',', $hptemp->{graph_0})); $n2++) {
				my $temp = @$line[$n2];
				push(@row, celsius_to($config, $temp));
				$line1 .= " %8.0f ";
			}
			for($n2 = 0; $n2 < scalar(my @hp = split(',', $hptemp->{graph_1})); $n2++) {
				my $temp = @$line[8 + $n2];
				push(@row, celsius_to($config, $temp));
				$line1 .= " %8.0f ";
			}
			for($n2 = 0; $n2 < scalar(my @hp = split(',', $hptemp->{graph_2})); $n2++) {
				my $temp = @$line[8 + 3 + $n2];
				push(@row, celsius_to($config, $temp));
				$line1 .= " %8.0f ";
			}
			print(sprintf($line1, @row));
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

	my $PNG1 = $u . $package . "1." . $tf->{when} . ".png";
	my $PNG2 = $u . $package . "2." . $tf->{when} . ".png";
	my $PNG3 = $u . $package . "3." . $tf->{when} . ".png";
	my $PNG1z = $u . $package . "1z." . $tf->{when} . ".png";
	my $PNG2z = $u . $package . "2z." . $tf->{when} . ".png";
	my $PNG3z = $u . $package . "3z." . $tf->{when} . ".png";
	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	if($title) {
		main::graph_header($title, 2);
		print("    <tr>\n");
		print("    <td bgcolor='$colors->{title_bg_color}'>\n");
	}

	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	if(scalar(my @hptemp0 = split(',', ($hptemp->{graph_0} || "")))) {
		undef(@CDEF);
		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 8; $n++) {
			if($hptemp0[$n]) {
				foreach(@hplog) {
					$id = sprintf("%2d", trim($hptemp0[$n]));
					if(/^$id  /) {
						$str = substr($_, 17, 8);
						$str = sprintf("%-20s", $str);
						push(@tmp, "LINE2:temp_" . $n . $LC[$n] . ":$str");
						push(@tmp, "GPRINT:temp_" . $n . ":LAST:Current\\: %2.0lf");
						push(@tmp, "GPRINT:temp_" . $n . ":AVERAGE:   Average\\: %2.0lf");
						push(@tmp, "GPRINT:temp_" . $n . ":MIN:   Min\\: %2.0lf");
						push(@tmp, "GPRINT:temp_" . $n . ":MAX:   Max\\: %2.0lf\\n");
						$str =~ s/\s+$//;
						push(@tmpz, "LINE2:temp_" . $n . $LC[$n] . ":$str");
						last;
					}
				}
			} else {
				push(@tmp, "COMMENT: \\n");
			}
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
		} else {
			push(@CDEF, "CDEF:temp_0=temp0");
			push(@CDEF, "CDEF:temp_1=temp1");
			push(@CDEF, "CDEF:temp_2=temp2");
			push(@CDEF, "CDEF:temp_3=temp3");
			push(@CDEF, "CDEF:temp_4=temp4");
			push(@CDEF, "CDEF:temp_5=temp5");
			push(@CDEF, "CDEF:temp_6=temp6");
			push(@CDEF, "CDEF:temp_7=temp7");
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
		}
		$pic = $rrd{$version}->("$PNG_DIR" . "$PNG1",
			"--title=$config->{graphs}->{_hptemp1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:temp0=$rrd:hptemp1_1:AVERAGE",
			"DEF:temp1=$rrd:hptemp1_2:AVERAGE",
			"DEF:temp2=$rrd:hptemp1_3:AVERAGE",
			"DEF:temp3=$rrd:hptemp1_4:AVERAGE",
			"DEF:temp4=$rrd:hptemp1_5:AVERAGE",
			"DEF:temp5=$rrd:hptemp1_6:AVERAGE",
			"DEF:temp6=$rrd:hptemp1_7:AVERAGE",
			"DEF:temp7=$rrd:hptemp1_8:AVERAGE",
			"CDEF:allvalues=temp0,temp1,temp2,temp3,temp4,temp5,temp6,temp7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp,
			"COMMENT: \\n");
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$PNG_DIR" . "$PNG1z",
				"--title=$config->{graphs}->{_hptemp1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=$temp_scale",
				"--width=$width",
				"--height=$height",
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:temp0=$rrd:hptemp1_1:AVERAGE",
				"DEF:temp1=$rrd:hptemp1_2:AVERAGE",
				"DEF:temp2=$rrd:hptemp1_3:AVERAGE",
				"DEF:temp3=$rrd:hptemp1_4:AVERAGE",
				"DEF:temp4=$rrd:hptemp1_5:AVERAGE",
				"DEF:temp5=$rrd:hptemp1_6:AVERAGE",
				"DEF:temp6=$rrd:hptemp1_7:AVERAGE",
				"DEF:temp7=$rrd:hptemp1_8:AVERAGE",
				"CDEF:allvalues=temp0,temp1,temp2,temp3,temp4,temp5,temp6,temp7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /hptemp1/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "'>\n");
			}
		}
	}

	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	@riglim = @{setup_riglim($rigid[1], $limit[1])};
	if(scalar(my @hptemp1 = split(',', ($hptemp->{graph_1} || "")))) {
		undef(@CDEF);
		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 6; $n++) {
			if($hptemp1[$n]) {
				foreach(@hplog) {
					$id = sprintf("%2d", trim($hptemp1[$n]));
					if(/^$id  /) {
						$str = substr($_, 17, 8);
						$str = sprintf("%-8s", $str);
						push(@tmp, "LINE2:temp_" . $n . $LC[$n] . ":$str");
						push(@tmp, "GPRINT:temp_" . $n . ":LAST:\\: %2.0lf");
						if(!(($n + 1) % 2)) {
							push(@tmp, "COMMENT: \\n");
						} else {
							push(@tmp, "COMMENT:    ");
						}
						$str =~ s/\s+$//;
						push(@tmpz, "LINE2:temp_" . $n . $LC[$n] . ":$str");
						last;
					}
				}
			} else {
				push(@tmp, "COMMENT: \\n") unless ($n + 1) % 2;
			}
		}
		if(lc($config->{temperature_scale}) eq "f") {
			push(@CDEF, "CDEF:temp_0=9,5,/,temp0,*,32,+");
			push(@CDEF, "CDEF:temp_1=9,5,/,temp1,*,32,+");
			push(@CDEF, "CDEF:temp_2=9,5,/,temp2,*,32,+");
			push(@CDEF, "CDEF:temp_3=9,5,/,temp3,*,32,+");
			push(@CDEF, "CDEF:temp_4=9,5,/,temp4,*,32,+");
			push(@CDEF, "CDEF:temp_5=9,5,/,temp5,*,32,+");
		} else {
			push(@CDEF, "CDEF:temp_0=temp0");
			push(@CDEF, "CDEF:temp_1=temp1");
			push(@CDEF, "CDEF:temp_2=temp2");
			push(@CDEF, "CDEF:temp_3=temp3");
			push(@CDEF, "CDEF:temp_4=temp4");
			push(@CDEF, "CDEF:temp_5=temp5");
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
		$pic = $rrd{$version}->("$PNG_DIR" . "$PNG2",
			"--title=$config->{graphs}->{_hptemp2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:temp0=$rrd:hptemp2_1:AVERAGE",
			"DEF:temp1=$rrd:hptemp2_2:AVERAGE",
			"DEF:temp2=$rrd:hptemp2_3:AVERAGE",
			"DEF:temp3=$rrd:hptemp2_4:AVERAGE",
			"DEF:temp4=$rrd:hptemp2_5:AVERAGE",
			"DEF:temp5=$rrd:hptemp2_6:AVERAGE",
			"CDEF:allvalues=temp0,temp1,temp2,temp3,temp4,temp5,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$PNG_DIR" . "$PNG2z",
				"--title=$config->{graphs}->{_hptemp2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=$temp_scale",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:temp0=$rrd:hptemp2_1:AVERAGE",
				"DEF:temp1=$rrd:hptemp2_2:AVERAGE",
				"DEF:temp2=$rrd:hptemp2_3:AVERAGE",
				"DEF:temp3=$rrd:hptemp2_4:AVERAGE",
				"DEF:temp4=$rrd:hptemp2_5:AVERAGE",
				"DEF:temp5=$rrd:hptemp2_6:AVERAGE",
				"CDEF:allvalues=temp0,temp1,temp2,temp3,temp4,temp5,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /hptemp2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "'>\n");
			}
		}
	}

	@riglim = @{setup_riglim($rigid[2], $limit[2])};
	if(scalar(my @hptemp2 = split(',', ($hptemp->{graph_2} || "")))) {
		undef(@CDEF);
		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 6; $n++) {
			if($hptemp2[$n]) {
				foreach(@hplog) {
					$id = sprintf("%2d", trim($hptemp2[$n]));
					if(/^$id  /) {
						$str = substr($_, 17, 8);
						$str = sprintf("%-8s", $str);
						push(@tmp, "LINE2:temp_" . $n . $LC[$n] . ":$str");
						push(@tmp, "GPRINT:temp_" . $n . ":LAST:\\: %2.0lf");
						if(!(($n + 1) % 2)) {
							push(@tmp, "COMMENT: \\n");
						} else {
							push(@tmp, "COMMENT:    ");
						}
						$str =~ s/\s+$//;
						push(@tmpz, "LINE2:temp_" . $n . $LC[$n] . ":$str");
						last;
					}
				}
			} else {
				push(@tmp, "COMMENT: \\n") unless ($n + 1) % 2;
			}
		}
		if(lc($config->{temperature_scale}) eq "f") {
			push(@CDEF, "CDEF:temp_0=9,5,/,temp0,*,32,+");
			push(@CDEF, "CDEF:temp_1=9,5,/,temp1,*,32,+");
			push(@CDEF, "CDEF:temp_2=9,5,/,temp2,*,32,+");
			push(@CDEF, "CDEF:temp_3=9,5,/,temp3,*,32,+");
			push(@CDEF, "CDEF:temp_4=9,5,/,temp4,*,32,+");
			push(@CDEF, "CDEF:temp_5=9,5,/,temp5,*,32,+");
		} else {
			push(@CDEF, "CDEF:temp_0=temp0");
			push(@CDEF, "CDEF:temp_1=temp1");
			push(@CDEF, "CDEF:temp_2=temp2");
			push(@CDEF, "CDEF:temp_3=temp3");
			push(@CDEF, "CDEF:temp_4=temp4");
			push(@CDEF, "CDEF:temp_5=temp5");
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
		$pic = $rrd{$version}->("$PNG_DIR" . "$PNG3",
			"--title=$config->{graphs}->{_hptemp3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:temp0=$rrd:hptemp3_1:AVERAGE",
			"DEF:temp1=$rrd:hptemp3_2:AVERAGE",
			"DEF:temp2=$rrd:hptemp3_3:AVERAGE",
			"DEF:temp3=$rrd:hptemp3_4:AVERAGE",
			"DEF:temp4=$rrd:hptemp3_5:AVERAGE",
			"DEF:temp5=$rrd:hptemp3_6:AVERAGE",
			"CDEF:allvalues=temp0,temp1,temp2,temp3,temp4,temp5,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$PNG_DIR" . "$PNG3z",
				"--title=$config->{graphs}->{_hptemp3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=$temp_scale",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:temp0=$rrd:hptemp3_1:AVERAGE",
				"DEF:temp1=$rrd:hptemp3_2:AVERAGE",
				"DEF:temp2=$rrd:hptemp3_3:AVERAGE",
				"DEF:temp3=$rrd:hptemp3_4:AVERAGE",
				"DEF:temp4=$rrd:hptemp3_5:AVERAGE",
				"DEF:temp5=$rrd:hptemp3_6:AVERAGE",
				"CDEF:allvalues=temp0,temp1,temp2,temp3,temp4,temp5,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /hptemp3/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "'>\n");
			}
		}
	}

	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		main::graph_footer();
	}
	print("  <br>\n");
	return;
}

1;
