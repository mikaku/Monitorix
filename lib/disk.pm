#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2013 by Jordi Sanfeliu <jordi@fibranet.cat>
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

package disk;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(disk_init disk_update disk_cgi);

sub disk_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $disk = $config->{disk};

	my $info;
	my @ds;
	my @tmp;
	my $n;

	if(-e $rrd) {
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'ds[') == 0) {
				if(index($key, '.type') != -1) {
					push(@ds, substr($key, 3, index($key, ']') - 3));
				}
			}
		}
		if(scalar(@ds) / 24 != keys(%{$disk->{list}})) {
			logger("Detected size mismatch between <list>...</list> (" . keys(%{$disk->{list}}) . ") and $rrd (" . scalar(@ds) / 24 . "). Resizing it accordingly. All historic data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
	}

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
		for($n = 0; $n < keys(%{$disk->{list}}); $n++) {
			push(@tmp, "DS:disk" . $n . "_hd0_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd0_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd0_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd1_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd1_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd1_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd2_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd2_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd2_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd3_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd3_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd3_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd4_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd4_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd4_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd5_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd5_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd5_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd6_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd6_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd6_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd7_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd7_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd7_smart2:GAUGE:120:0:U");
		}
		eval {
			RRDs::create($rrd,
				"--step=60",
				@tmp,
				"RRA:AVERAGE:0.5:1:1440",
				"RRA:AVERAGE:0.5:30:336",
				"RRA:AVERAGE:0.5:60:744",
				"RRA:AVERAGE:0.5:1440:365",
				"RRA:MIN:0.5:1:1440",
				"RRA:MIN:0.5:30:336",
				"RRA:MIN:0.5:60:744",
				"RRA:MIN:0.5:1440:365",
				"RRA:MAX:0.5:1:1440",
				"RRA:MAX:0.5:30:336",
				"RRA:MAX:0.5:60:744",
				"RRA:MAX:0.5:1440:365",
				"RRA:LAST:0.5:1:1440",
				"RRA:LAST:0.5:30:336",
				"RRA:LAST:0.5:60:744",
				"RRA:LAST:0.5:1440:365",
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

sub disk_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $disk = $config->{disk};

	my $temp;
	my $smart1;
	my $smart2;

	my $n;
	my $rrdata = "N";

	foreach my $k (sort keys %{$disk->{list}}) {
		my @dsk = split(',', $disk->{list}->{$k});
		for($n = 0; $n < 8; $n++) {
			$temp = 0;
			$smart1 = 0;
			$smart2 = 0;
			if($dsk[$n]) {
				my $d = trim($dsk[$n]);
	  			open(IN, "smartctl -A $d |");
				while(<IN>) {
					if(/^  5/ && /Reallocated_Sector_Ct/) {
						my @tmp = split(' ', $_);
						$smart1 = $tmp[9];
						chomp($smart1);
					}
					if(/^194/ && /Temperature_Celsius/) {
						my @tmp = split(' ', $_);
						$temp = $tmp[9];
						chomp($temp);
					}
					if(/^197/ && /Current_Pending_Sector/) {
						my @tmp = split(' ', $_);
						$smart2 = $tmp[9];
						chomp($smart2);
					}
					if(/^Current Drive Temperature: /) {
						my @tmp = split(' ', $_);
						$temp = $tmp[3] unless $temp;
						chomp($temp);
					}
				}
				close(IN);
				$temp = `hddtemp -wqn $d` unless $temp;
				chomp($temp);
			}
			$rrdata .= ":$temp";
			$rrdata .= ":$smart1";
			$rrdata .= ":$smart2";
		}
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub disk_cgi {
	my ($package, $config, $cgi) = @_;

	my $disk = $config->{disk};
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};

	my $u = "";
	my $width;
	my $height;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my $n;
	my $n2;
	my $e;
	my $e2;
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
		foreach my $k (sort keys %{$disk->{list}}) {
			my @d = split(',', $disk->{list}->{$k});
			for($n = 0; $n < scalar(@d); $n++) {
				$str = sprintf(" DISK %d               ", $n + 1);
				$line1 .= $str;
				$str = sprintf(" Temp Realloc Pending ");
				$line2 .= $str;
				$line3 .=      "----------------------";
			}
		}
		print("     $line1\n");
		print("Time $line2\n");
		print("-----$line3\n");
		my $line;
		my @row;
		my $time;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			printf(" %2d$tf->{tc} ", $time);
			$e = 0;
			foreach my $k (sort keys %{$disk->{list}}) {
				my @d = split(',', $disk->{list}->{$k});
				for($n2 = 0; $n2 < scalar(@d); $n2++) {
					$from = ($e * 8 * 3) + ($n2 * 3);
					$to = $from + 3;
					my ($temp, $realloc, $pending) = @$line[$from..$to];
					@row = ($temp, $realloc, $pending);
					printf(" %4.0f %7.0f %7.0f ", @row);
				}
				$e++;
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

	for($n = 0; $n < keys(%{$disk->{list}}); $n++) {
		for($n2 = 1; $n2 <= 8; $n2++) {
			$str = $u . $package . $n . $n2 . "." . $tf->{when} . ".png";
			push(@PNG, $str);
			unlink("$PNG_DIR" . $str);
			if(lc($config->{enable_zoom}) eq "y") {
				$str = $u . $package . $n . $n2 . "z." . $tf->{when} . ".png";
				push(@PNGz, $str);
				unlink("$PNG_DIR" . $str);
			}
		}
	}

	$e = 0;
	foreach my $k (sort keys %{$disk->{list}}) {
		my @d = split(',', $disk->{list}->{$k});

		if($e) {
			print("   <br>\n");
		}
		if($title) {
			main::graph_header($title, 2);
		}

		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "COMMENT: \\n");
		for($n = 0; $n < 8; $n++) {
			if($d[$n]) {
				my ($dstr) = (split /\s+/, trim($d[$n]));
				$str = sprintf("%-20s", $dstr);
				push(@tmp, "LINE2:hd" . $n . $LC[$n] . ":$str");
				push(@tmpz, "LINE2:hd" . $n . $LC[$n] . ":$dstr");
				push(@tmp, "GPRINT:hd" . $n . ":LAST:   Current\\: %2.0lf");
				push(@tmp, "GPRINT:hd" . $n . ":AVERAGE:   Average\\: %2.0lf");
				push(@tmp, "GPRINT:hd" . $n . ":MIN:   Min\\: %2.0lf");
				push(@tmp, "GPRINT:hd" . $n . ":MAX:   Max\\: %2.0lf\\n");
			}
		}
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		if(scalar(@d) && (scalar(@d) % 2)) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='$colors->{title_bg_color}'>\n");
		}
		($width, $height) = split('x', $config->{graph_size}->{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3]",
			"--title=$config->{graphs}->{_disk1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Celsius",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:hd0=$rrd:disk" . $e ."_hd0_temp:AVERAGE",
			"DEF:hd1=$rrd:disk" . $e ."_hd1_temp:AVERAGE",
			"DEF:hd2=$rrd:disk" . $e ."_hd2_temp:AVERAGE",
			"DEF:hd3=$rrd:disk" . $e ."_hd3_temp:AVERAGE",
			"DEF:hd4=$rrd:disk" . $e ."_hd4_temp:AVERAGE",
			"DEF:hd5=$rrd:disk" . $e ."_hd5_temp:AVERAGE",
			"DEF:hd6=$rrd:disk" . $e ."_hd6_temp:AVERAGE",
			"DEF:hd7=$rrd:disk" . $e ."_hd7_temp:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3]",
				"--title=$config->{graphs}->{_disk1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=Celsius",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:hd0=$rrd:disk" . $e ."_hd0_temp:AVERAGE",
				"DEF:hd1=$rrd:disk" . $e ."_hd1_temp:AVERAGE",
				"DEF:hd2=$rrd:disk" . $e ."_hd2_temp:AVERAGE",
				"DEF:hd3=$rrd:disk" . $e ."_hd3_temp:AVERAGE",
				"DEF:hd4=$rrd:disk" . $e ."_hd4_temp:AVERAGE",
				"DEF:hd5=$rrd:disk" . $e ."_hd5_temp:AVERAGE",
				"DEF:hd6=$rrd:disk" . $e ."_hd6_temp:AVERAGE",
				"DEF:hd7=$rrd:disk" . $e ."_hd7_temp:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /disk$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNGz[$e * 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$e * 3] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNGz[$e * 3] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$e * 3] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$e * 3] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 8; $n += 2) {
			if($d[$n]) {
				$str = sprintf("%-17s", substr($d[$n], 0, 17));
				push(@tmp, "LINE2:rsc" . $n . $LC[$n] . ":$str");
				push(@tmpz, "LINE2:rsc" . $n . $LC[$n] . ":$d[$n]\\g");
			}
			if($d[$n + 1]) {
				$str = sprintf("%-17s", substr($d[$n + 1], 0, 17));
				push(@tmp, "LINE2:rsc" . ($n + 1) . $LC[$n + 1] . ":$str\\n");
				push(@tmpz, "LINE2:rsc" . ($n + 1) . $LC[$n + 1] . ":$d[$n + 1]\\g");
			}
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
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 1]",
			"--title=$config->{graphs}->{_disk2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Sectors",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:rsc0=$rrd:disk" . $e . "_hd0_smart1:AVERAGE",
			"DEF:rsc1=$rrd:disk" . $e . "_hd1_smart1:AVERAGE",
			"DEF:rsc2=$rrd:disk" . $e . "_hd2_smart1:AVERAGE",
			"DEF:rsc3=$rrd:disk" . $e . "_hd3_smart1:AVERAGE",
			"DEF:rsc4=$rrd:disk" . $e . "_hd4_smart1:AVERAGE",
			"DEF:rsc5=$rrd:disk" . $e . "_hd5_smart1:AVERAGE",
			"DEF:rsc6=$rrd:disk" . $e . "_hd6_smart1:AVERAGE",
			"DEF:rsc7=$rrd:disk" . $e . "_hd7_smart1:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 1]",
				"--title=$config->{graphs}->{_disk2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=Sectors",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:rsc0=$rrd:disk" . $e . "_hd0_smart1:AVERAGE",
				"DEF:rsc1=$rrd:disk" . $e . "_hd1_smart1:AVERAGE",
				"DEF:rsc2=$rrd:disk" . $e . "_hd2_smart1:AVERAGE",
				"DEF:rsc3=$rrd:disk" . $e . "_hd3_smart1:AVERAGE",
				"DEF:rsc4=$rrd:disk" . $e . "_hd4_smart1:AVERAGE",
				"DEF:rsc5=$rrd:disk" . $e . "_hd5_smart1:AVERAGE",
				"DEF:rsc6=$rrd:disk" . $e . "_hd6_smart1:AVERAGE",
				"DEF:rsc7=$rrd:disk" . $e . "_hd7_smart1:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /disk$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNGz[$e * 3 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNGz[$e * 3 + 1] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$e * 3 + 1] . "'>\n");
			}
		}

		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 8; $n += 2) {
			if($d[$n]) {
				$str = sprintf("%-17s", substr($d[$n], 0, 17));
				push(@tmp, "LINE2:cps" . $n . $LC[$n] . ":$str");
				push(@tmpz, "LINE2:cps" . $n . $LC[$n] . ":$d[$n]\\g");
			}
			if($d[$n + 1]) {
				$str = sprintf("%-17s", substr($d[$n + 1], 0, 17));
				push(@tmp, "LINE2:cps" . ($n + 1) . $LC[$n + 1] . ":$str\\n");
				push(@tmpz, "LINE2:cps" . ($n + 1) . $LC[$n + 1] . ":$d[$n + 1]\\g");
			}
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
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 2]",
			"--title=$config->{graphs}->{_disk3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Sectors",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:cps0=$rrd:disk" . $e . "_hd0_smart2:AVERAGE",
			"DEF:cps1=$rrd:disk" . $e . "_hd1_smart2:AVERAGE",
			"DEF:cps2=$rrd:disk" . $e . "_hd2_smart2:AVERAGE",
			"DEF:cps3=$rrd:disk" . $e . "_hd3_smart2:AVERAGE",
			"DEF:cps4=$rrd:disk" . $e . "_hd4_smart2:AVERAGE",
			"DEF:cps5=$rrd:disk" . $e . "_hd5_smart2:AVERAGE",
			"DEF:cps6=$rrd:disk" . $e . "_hd6_smart2:AVERAGE",
			"DEF:cps7=$rrd:disk" . $e . "_hd7_smart2:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 2]",
				"--title=$config->{graphs}->{_disk3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=Sectors",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:cps0=$rrd:disk" . $e . "_hd0_smart2:AVERAGE",
				"DEF:cps1=$rrd:disk" . $e . "_hd1_smart2:AVERAGE",
				"DEF:cps2=$rrd:disk" . $e . "_hd2_smart2:AVERAGE",
				"DEF:cps3=$rrd:disk" . $e . "_hd3_smart2:AVERAGE",
				"DEF:cps4=$rrd:disk" . $e . "_hd4_smart2:AVERAGE",
				"DEF:cps5=$rrd:disk" . $e . "_hd5_smart2:AVERAGE",
				"DEF:cps6=$rrd:disk" . $e . "_hd6_smart2:AVERAGE",
				"DEF:cps7=$rrd:disk" . $e . "_hd7_smart2:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /disk$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNGz[$e * 3 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNGz[$e * 3 + 2] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$e * 3 + 2] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			main::graph_footer();
		}
		$e++;
	}
	print("  <br>\n");
	return;
}

1;
