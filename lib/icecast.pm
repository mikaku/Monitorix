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

package icecast;

use strict;
use warnings;
use Monitorix;
use RRDs;
use LWP::UserAgent;
use Exporter 'import';
our @EXPORT = qw(icecast_init icecast_update icecast_cgi);

sub icecast_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $icecast = $config->{icecast};

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
		if(scalar(@ds) / 36 != scalar(my @il = split(',', $icecast->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @il = split(',', $icecast->{list})) . ") and $rrd (" . scalar(@ds) / 36 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @il = split(',', $icecast->{list})); $n++) {
			push(@tmp, "DS:icecast" . $n . "_mp0_ls:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp0_br:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp0_v0:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp0_v1:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp1_ls:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp1_br:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp1_v0:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp1_v1:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp2_ls:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp2_br:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp2_v0:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp2_v1:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp3_ls:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp3_br:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp3_v0:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp3_v1:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp4_ls:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp4_br:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp4_v0:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp4_v1:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp5_ls:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp5_br:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp5_v0:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp5_v1:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp6_ls:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp6_br:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp6_v0:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp6_v1:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp7_ls:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp7_br:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp7_v0:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp7_v1:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp8_ls:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp8_br:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp8_v0:GAUGE:120:0:U");
			push(@tmp, "DS:icecast" . $n . "_mp8_v1:GAUGE:120:0:U");
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

sub icecast_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $icecast = $config->{icecast};

	my $n;
	my $rrdata = "N";

	my $e = 0;
	foreach(my @il = split(',', $icecast->{list})) {
		my $ils = trim($il[$e]);
		my $ssl = "";

		$ssl = "ssl_opts => {verify_hostname => 0}"
			if lc($config->{accept_selfsigned_certs}) eq "y";

		my $ua = LWP::UserAgent->new(timeout => 30, $ssl);
		$ua->agent($config->{user_agent_id}) if $config->{user_agent_id} || "";
		my $response = $ua->request(HTTP::Request->new('GET', $ils));
		my $data = $response->content;

		if(!$response->is_success) {
			logger("$myself: ERROR: Unable to connect to '$ils'.");
			logger("$myself: " . $response->status_line);
		}

		$data =~ s/\n//g;

		my $iceold;
		my $icenew;
		my @bl_pairs;
		my @ls;
		my @br;

		foreach my $i (split(',', $icecast->{desc}->{$ils})) {
			$i = trim($i);
			$i =~ s/\//\\\//g;
			$iceold .= '<td><h3>Mount Point ' . $i . '<\/h3><\/td>.*?(?:<tr><td>Bitrate:<\/td><td class=\"streamdata\">(\d*?)<\/td><\/tr>)?<tr><td>Current Listeners:<\/td><td class=\"streamdata\">(\d*?)<\/td><\/tr>.*?<\/table>.*?';
			$icenew .= '<h3 class=\"mount\">Mount Point ' . $i . '<\/h3>.*?(?:<tr><td>Bitrate:<\/td><td class=\"streamstats\">(\d*?)<\/td><\/tr>)?<tr><td>Listeners \(current\):<\/td><td class=\"streamstats\">(\d*?)<\/td><\/tr>.*?<\/table>.*?';
		}
		(@bl_pairs) = ($data =~ m/$iceold/);
		(@bl_pairs) = ($data =~ m/$icenew/) if !scalar(@bl_pairs);

		while(my ($b, $l) = splice(@bl_pairs, 0, 2)) {
			push(@ls, $l);
			push(@br, $b);
		}
		for($n = 0; $n < 9; $n++) {
			$ls[$n] = 0 unless defined($ls[$n]);
			$br[$n] = 0 unless defined($br[$n]);
			$rrdata .= ":" . $ls[$n];
			$rrdata .= ":" . $br[$n];
			$rrdata .= ":" . "0";
			$rrdata .= ":" . "0";
		}
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub icecast_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $icecast = $config->{icecast};
	my @rigid = split(',', ($icecast->{rigid} || ""));
	my @limit = split(',', ($icecast->{limit} || ""));
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
	my $n;
	my $str;
	my $stack;
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
		"#444444",
	);
	my @LC = (
		"#FFA500",
		"#00EEEE",
		"#00EE00",
		"#0000EE",
		"#448844",
		"#EE0000",
		"#EE00EE",
		"#EEEE00",
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
		my $line4;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		for($n = 0; $n < scalar(my @il = split(',', $icecast->{list})); $n++) {
			my $l = trim($il[$n]);
			$line1 = "  ";
			$line2 .= "  ";
			$line3 .= "  ";
			$line4 .= "--";
			foreach my $i (split(',', $icecast->{desc}->{$l})) {
				$line1 .= "           ";
				$line2 .= sprintf(" %10s", trim($i));
				$line3 .= "  List BitR";
				$line4 .= "-----------";
			}
			if($line1) {
				my $i = length($line1);
				push(@output, sprintf(sprintf("%${i}s", sprintf("Icecast Server %2d", $n))));
			}
		}
		push(@output, "\n");
		push(@output, "    $line2");
		push(@output, "\n");
		push(@output, "Time$line3\n");
		push(@output, "----$line4 \n");
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
			for($n2 = 0; $n2 < scalar(my @il = split(',', $icecast->{list})); $n2++) {
				my $ls = trim($il[$n2]);
				push(@output, "  ");
				$n3 = 0;
				foreach my $i (split(',', $icecast->{desc}->{$ls})) {
					$from = $n2 * 36 + ($n3++ * 4);
					$to = $from + 4;
					my ($l, $b, undef, undef) = @$line[$from..$to];
					@row = ($l, $b);
					push(@output, sprintf("  %4d %4d", @row));
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

	for($n = 0; $n < scalar(my @il = split(',', $icecast->{list})); $n++) {
		$str = $u . $package . $n . "1." . $tf->{when} . ".$imgfmt_lc";
		push(@IMG, $str);
		unlink("$IMG_DIR" . $str);
		$str = $u . $package . $n . "2." . $tf->{when} . ".$imgfmt_lc";
		push(@IMG, $str);
		unlink("$IMG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . $package . $n . "1z." . $tf->{when} . ".$imgfmt_lc";
			push(@IMGz, $str);
			unlink("$IMG_DIR" . $str);
			$str = $u . $package . $n . "2z." . $tf->{when} . ".$imgfmt_lc";
			push(@IMGz, $str);
			unlink("$IMG_DIR" . $str);
		}
	}

	$e = 0;
	foreach my $url (my @il = split(',', $icecast->{list})) {
		$url = trim($url);
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
		$n = 0;
		foreach my $i (split(',', $icecast->{desc}->{$url})) {
			$i = trim($i);
			$str = sprintf("%-15s", substr($i, 0, 15));
			$stack = "";
			if(lc($icecast->{graph_mode}) eq "s") {
				$stack = ":STACK";
			}
			push(@tmp, "AREA:ice" . $e . "_mp$n" . $AC[$n] . ":$str" . $stack);
			push(@tmpz, "AREA:ice" . $e . "_mp$n" . $AC[$n] . ":$i" . $stack);
			push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":LAST: Cur\\:%4.0lf");
			push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":AVERAGE: Avg\\:%4.0lf");
			push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":MIN: Min\\:%4.0lf");
			push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":MAX: Max\\:%4.0lf\\n");
			$n++;
		}
		$n = 0;
		if(lc($icecast->{graph_mode}) ne "s") {
			foreach my $i (split(',', $icecast->{desc}->{$url})) {
				push(@tmp, "LINE2:ice" . $e . "_mp$n" . $LC[$n]);
				push(@tmpz, "LINE2:ice" . $e . "_mp$n" . $LC[$n]);
				$n++;
			}
		}

		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 2]",
			"--title=$config->{graphs}->{_icecast1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Listeners",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:ice" . $e . "_mp0=$rrd:icecast" . $e . "_mp0_ls:AVERAGE",
			"DEF:ice" . $e . "_mp1=$rrd:icecast" . $e . "_mp1_ls:AVERAGE",
			"DEF:ice" . $e . "_mp2=$rrd:icecast" . $e . "_mp2_ls:AVERAGE",
			"DEF:ice" . $e . "_mp3=$rrd:icecast" . $e . "_mp3_ls:AVERAGE",
			"DEF:ice" . $e . "_mp4=$rrd:icecast" . $e . "_mp4_ls:AVERAGE",
			"DEF:ice" . $e . "_mp5=$rrd:icecast" . $e . "_mp5_ls:AVERAGE",
			"DEF:ice" . $e . "_mp6=$rrd:icecast" . $e . "_mp6_ls:AVERAGE",
			"DEF:ice" . $e . "_mp7=$rrd:icecast" . $e . "_mp7_ls:AVERAGE",
			"DEF:ice" . $e . "_mp8=$rrd:icecast" . $e . "_mp8_ls:AVERAGE",
			"CDEF:allvalues=ice" . $e . "_mp0,ice" . $e . "_mp1,ice" . $e . "_mp2,ice" . $e . "_mp3,ice" . $e . "_mp4,ice" . $e . "_mp5,ice" . $e . "_mp6,ice" . $e . "_mp7,ice" . $e . "_mp8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 2]",
				"--title=$config->{graphs}->{_icecast1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Listeners",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:ice" . $e . "_mp0=$rrd:icecast" . $e . "_mp0_ls:AVERAGE",
				"DEF:ice" . $e . "_mp1=$rrd:icecast" . $e . "_mp1_ls:AVERAGE",
				"DEF:ice" . $e . "_mp2=$rrd:icecast" . $e . "_mp2_ls:AVERAGE",
				"DEF:ice" . $e . "_mp3=$rrd:icecast" . $e . "_mp3_ls:AVERAGE",
				"DEF:ice" . $e . "_mp4=$rrd:icecast" . $e . "_mp4_ls:AVERAGE",
				"DEF:ice" . $e . "_mp5=$rrd:icecast" . $e . "_mp5_ls:AVERAGE",
				"DEF:ice" . $e . "_mp6=$rrd:icecast" . $e . "_mp6_ls:AVERAGE",
				"DEF:ice" . $e . "_mp7=$rrd:icecast" . $e . "_mp7_ls:AVERAGE",
				"DEF:ice" . $e . "_mp8=$rrd:icecast" . $e . "_mp8_ls:AVERAGE",
				"CDEF:allvalues=ice" . $e . "_mp0,ice" . $e . "_mp1,ice" . $e . "_mp2,ice" . $e . "_mp3,ice" . $e . "_mp4,ice" . $e . "_mp5,ice" . $e . "_mp6,ice" . $e . "_mp7,ice" . $e . "_mp8,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 2]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /icecast$e/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 2] . "'>\n");
			}
		}
		if($title) {
			push(@output, "    </td>\n");
		}

		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		$n = 0;
		foreach my $i (split(',', $icecast->{desc}->{$url})) {
			$i = trim($i);
			$str = sprintf("%-15s", substr($i, 0, 15));
			push(@tmp, "LINE2:ice" . $e . "_mp$n" . $LC[$n] . ":$str");
			push(@tmpz, "LINE2:ice" . $e . "_mp$n" . $LC[$n] . ":$i");
			push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":LAST: Cur\\:%3.0lf");
			push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":AVERAGE:  Avg\\:%3.0lf");
			push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":MIN:  Min\\:%3.0lf");
			push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":MAX:  Max\\:%3.0lf\\n");
			$n++;
		}

		if($title) {
			push(@output, "    <td>\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium});
		$pic = $rrd{$version}->("$IMG_DIR" . $IMG[$e * 2 + 1],
			"--title=$config->{graphs}->{_icecast2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Bitrate",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:ice" . $e . "_mp0=$rrd:icecast" . $e . "_mp0_br:AVERAGE",
			"DEF:ice" . $e . "_mp1=$rrd:icecast" . $e . "_mp1_br:AVERAGE",
			"DEF:ice" . $e . "_mp2=$rrd:icecast" . $e . "_mp2_br:AVERAGE",
			"DEF:ice" . $e . "_mp3=$rrd:icecast" . $e . "_mp3_br:AVERAGE",
			"DEF:ice" . $e . "_mp4=$rrd:icecast" . $e . "_mp4_br:AVERAGE",
			"DEF:ice" . $e . "_mp5=$rrd:icecast" . $e . "_mp5_br:AVERAGE",
			"DEF:ice" . $e . "_mp6=$rrd:icecast" . $e . "_mp6_br:AVERAGE",
			"DEF:ice" . $e . "_mp7=$rrd:icecast" . $e . "_mp7_br:AVERAGE",
			"DEF:ice" . $e . "_mp8=$rrd:icecast" . $e . "_mp8_br:AVERAGE",
			"CDEF:allvalues=ice" . $e . "_mp0,ice" . $e . "_mp1,ice" . $e . "_mp2,ice" . $e . "_mp3,ice" . $e . "_mp4,ice" . $e . "_mp5,ice" . $e . "_mp6,ice" . $e . "_mp7,ice" . $e . "_mp8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . $IMG[$e * 2 + 1] . ": $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . $IMGz[$e * 2 + 1],
				"--title=$config->{graphs}->{_icecast2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Bitrate",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:ice" . $e . "_mp0=$rrd:icecast" . $e . "_mp0_br:AVERAGE",
				"DEF:ice" . $e . "_mp1=$rrd:icecast" . $e . "_mp1_br:AVERAGE",
				"DEF:ice" . $e . "_mp2=$rrd:icecast" . $e . "_mp2_br:AVERAGE",
				"DEF:ice" . $e . "_mp3=$rrd:icecast" . $e . "_mp3_br:AVERAGE",
				"DEF:ice" . $e . "_mp4=$rrd:icecast" . $e . "_mp4_br:AVERAGE",
				"DEF:ice" . $e . "_mp5=$rrd:icecast" . $e . "_mp5_br:AVERAGE",
				"DEF:ice" . $e . "_mp6=$rrd:icecast" . $e . "_mp6_br:AVERAGE",
				"DEF:ice" . $e . "_mp7=$rrd:icecast" . $e . "_mp7_br:AVERAGE",
				"DEF:ice" . $e . "_mp8=$rrd:icecast" . $e . "_mp8_br:AVERAGE",
				"CDEF:allvalues=ice" . $e . "_mp0,ice" . $e . "_mp1,ice" . $e . "_mp2,ice" . $e . "_mp3,ice" . $e . "_mp4,ice" . $e . "_mp5,ice" . $e . "_mp6,ice" . $e . "_mp7,ice" . $e . "_mp8,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . $IMGz[$e * 2 + 1] . ": $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /icecast$e/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 2 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 2 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 2 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 2 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 2 + 1] . "'>\n");
			}
		}
		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");
	
			push(@output, "    <tr>\n");
			push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
			push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
			push(@output, "       <font size='-1'>\n");
			push(@output, "        <b>&nbsp;&nbsp;<a href='" . $url . "' style='color: " . $colors->{title_fg_color} . "'>$url</a><b>\n");
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
