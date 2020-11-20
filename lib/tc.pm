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

package tc;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(tc_init tc_update tc_cgi);

sub tc_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $tc = $config->{tc};

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
		if(scalar(@ds) / 90 != scalar(my @nl = split(',', $tc->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @nl = split(',', $tc->{list})) . ") and $rrd (" . scalar(@ds) / 90 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @nl = split(',', $tc->{list})); $n++) {
			push(@tmp, "DS:tc" . $n . "_q1_sent:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q1_pack:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q1_drop:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q1_over:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q1_requ:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q1_v01:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q1_v02:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q1_v03:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q1_v04:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q1_v05:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q2_sent:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q2_pack:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q2_drop:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q2_over:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q2_requ:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q2_v01:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q2_v02:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q2_v03:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q2_v04:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q2_v05:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q3_sent:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q3_pack:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q3_drop:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q3_over:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q3_requ:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q3_v01:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q3_v02:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q3_v03:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q3_v04:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q3_v05:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q4_sent:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q4_pack:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q4_drop:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q4_over:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q4_requ:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q4_v01:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q4_v02:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q4_v03:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q4_v04:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q4_v05:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q5_sent:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q5_pack:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q5_drop:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q5_over:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q5_requ:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q5_v01:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q5_v02:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q5_v03:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q5_v04:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q5_v05:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q6_sent:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q6_pack:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q6_drop:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q6_over:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q6_requ:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q6_v01:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q6_v02:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q6_v03:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q6_v04:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q6_v05:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q7_sent:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q7_pack:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q7_drop:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q7_over:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q7_requ:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q7_v01:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q7_v02:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q7_v03:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q7_v04:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q7_v05:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q8_sent:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q8_pack:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q8_drop:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q8_over:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q8_requ:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q8_v01:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q8_v02:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q8_v03:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q8_v04:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q8_v05:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q9_sent:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q9_pack:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q9_drop:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q9_over:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q9_requ:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q9_v01:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q9_v02:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q9_v03:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q9_v04:GAUGE:120:0:U");
			push(@tmp, "DS:tc" . $n . "_q9_v05:GAUGE:120:0:U");
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

	$config->{tc_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub tc_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $tc = $config->{tc};
	my $args = $tc->{extra_args} || "";

	my @data;
	my $sent;
	my $pack;
	my $drop;
	my $over;
	my $requ;

	my $str;
	my $n;
	my $rrdata = "N";

	my $e = 0;
	foreach my $d (split(',', $tc->{list})) {
		my $match = 0;
		my $e2 = 0;

		$d = trim($d);
		open(IN, "tc -s -d qdisc show dev $d |");
		@data = <IN>;
		close(IN);
		foreach my $qdisc (split(',', $tc->{desc}->{$d})) {
			my ($q1, $q2) = ($qdisc =~ m/\s*(\S+)\s*(.*)\s*/);
			my $q = $q1 . ($q2 ? " $q2" : "");
			$sent = $pack = $drop = $over = $requ = 0;
			foreach(@data) {
				if(!$match) {
					if(/^qdisc $q: .*?/) {
						$match = 1;
					}
				} else {
					if(/^ Sent (\d+) bytes (\d+) pkt \(dropped (\d+), overlimits (\d+) requeues (\d+)\)/) {
						$str = $e . "_" . $e2 . "sent";
						$sent = $1 - ($config->{tc_hist}->{$str} || 0);
						$sent = 0 unless $sent != $1;
						$sent /= 60;
						$config->{tc_hist}->{$str} = $1;
						$str = $e . "_" . $e2 . "pack";
						$pack = $2 - ($config->{tc_hist}->{$str} || 0);
						$pack = 0 unless $pack != $2;
						$pack /= 60;
						$config->{tc_hist}->{$str} = $2;
						$str = $e . "_" . $e2 . "drop";
						$drop = $3 - ($config->{tc_hist}->{$str} || 0);
						$drop = 0 unless $drop != $3;
						$drop /= 60;
						$config->{tc_hist}->{$str} = $3;
						$str = $e . "_" . $e2 . "over";
						$over = $4 - ($config->{tc_hist}->{$str} || 0);
						$over = 0 unless $over != $4;
						$over /= 60;
						$config->{tc_hist}->{$str} = $4;
						$str = $e . "_" . $e2 . "requ";
						$requ = $5 - ($config->{tc_hist}->{$str} || 0);
						$requ = 0 unless $requ != $5;
						$requ /= 60;
						$config->{tc_hist}->{$str} = $5;
						$match = 0;
					}
				}
			}
			$e2++;
			$rrdata .= ":$sent:$pack:$drop:$over:$requ:0:0:0:0:0";
		}
		for(; $e2 < 9; $e2++) {
			$rrdata .= ":0:0:0:0:0:0:0:0:0:0";
		}
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub tc_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $tc = $config->{tc};
	my @rigid = split(',', ($tc->{rigid} || ""));
	my @limit = split(',', ($tc->{limit} || ""));
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
	my $T = "B";
	my $vlabel = "bytes/s";
	my $e;
	my $e2;
	my $n;
	my $n2;
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
		"#B4B444",	#5F04B4
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

	if(lc($config->{netstats_in_bps}) eq "y") {
		$T = "b";
		$vlabel = "bits/s";
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
		foreach my $dev (split(',', $tc->{list})) {
			$dev = trim($dev);
			my @qdisc = split(',', $tc->{desc}->{$dev});
			for($n = 0; $n < scalar(@qdisc); $n++) {
				my ($q1, $q2) = (($qdisc[$n] || "") =~ m/\s*(\S+)\s*(.*)\s*/);
				$str = "      Sent   Packets   Dropped   Overlim   Requeue";
				$line2 .= $str;
				my $i = length($str);
				$str = ($q1 || "") . ($q2 ? " $q2" : "");
				$line1 .= sprintf("%${i}s", $str);
				$line3 .= "--------------------------------------------------";
			}
			if($line3) {
				my $i = length($line3);
				push(@output, sprintf(sprintf("%${i}s", sprintf("Interface: %s", $dev))));
			}
		}
		push(@output, "\n");
		push(@output, "    $line1\n");
		push(@output, "Time$line2\n");
		push(@output, "----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n3;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc}", $time));
			for($n2 = 0; $n2 < scalar(my @dev = split(',', $tc->{list})); $n2++) {
				my $d = trim($dev[$n2]);
				for($n3 = 0; $n3 < scalar(my @i = (split(',', $tc->{desc}->{$d}))); $n3++) {
					undef(@row);
					$from = ($n2 * 90) + (10 * $n3);
					$to = $from + 10;
					push(@row, @$line[$from..$to]);
					push(@output, sprintf(" %9d %9d %9d %9d %9d", @row));
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

	for($n = 0; $n < scalar(my @nl = split(',', $tc->{list})); $n++) {
		for($n2 = 1; $n2 <= 4; $n2++) {
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

	$e = $e2 = 0;
	foreach my $dev (split(',', $tc->{list})) {
		$dev = trim($dev);
		if($e) {
			push(@output, "   <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($dev . " " . $title, 2));
		}

		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		my @qdisc = split(',', $tc->{desc}->{$dev});
		for($n = 0; $n < 9; $n++) {
			my ($q1, $q2) = (($qdisc[$n] || "") =~ m/\s*(\S+)\s*(.*)\s*/);
			my $str = ($q1 || "") . ($q2 ? " $q2" : "");
			if($str) {
				if($tc->{map}->{$dev}->{$n} || "" eq $str) {
					$str = $tc->{map}->{$dev}->{$n};
				}
				push(@tmpz, "LINE2:sent" . $n . $LC[$n] . ":$str");
				$str = sprintf("%-19s", substr($str, 0, 19));
				push(@tmp, "LINE2:sent" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:b_sent" . $n . ":LAST:Cur\\: %4.0lf%s");
				push(@tmp, "GPRINT:b_sent" . $n . ":MIN:  Min\\: %4.0lf%s");
				push(@tmp, "GPRINT:b_sent" . $n . ":MAX:  Max\\: %4.0lf%s\\n");
			}
		}
		if(lc($config->{netstats_in_bps}) eq "y") {
			push(@CDEF, "CDEF:b_sent0=sent0,8,*");
			push(@CDEF, "CDEF:b_sent1=sent1,8,*");
			push(@CDEF, "CDEF:b_sent2=sent2,8,*");
			push(@CDEF, "CDEF:b_sent3=sent3,8,*");
			push(@CDEF, "CDEF:b_sent4=sent4,8,*");
			push(@CDEF, "CDEF:b_sent5=sent5,8,*");
			push(@CDEF, "CDEF:b_sent6=sent6,8,*");
			push(@CDEF, "CDEF:b_sent7=sent7,8,*");
			push(@CDEF, "CDEF:b_sent8=sent8,8,*");
		} else {
			push(@CDEF, "CDEF:b_sent0=sent0");
			push(@CDEF, "CDEF:b_sent1=sent1");
			push(@CDEF, "CDEF:b_sent2=sent2");
			push(@CDEF, "CDEF:b_sent3=sent3");
			push(@CDEF, "CDEF:b_sent4=sent4");
			push(@CDEF, "CDEF:b_sent5=sent5");
			push(@CDEF, "CDEF:b_sent6=sent6");
			push(@CDEF, "CDEF:b_sent7=sent7");
			push(@CDEF, "CDEF:b_sent8=sent8");
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
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 4]",
			"--title=$dev $config->{graphs}->{_tc1}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:sent0=$rrd:tc" . $e . "_q1_sent:AVERAGE",
			"DEF:sent1=$rrd:tc" . $e . "_q2_sent:AVERAGE",
			"DEF:sent2=$rrd:tc" . $e . "_q3_sent:AVERAGE",
			"DEF:sent3=$rrd:tc" . $e . "_q4_sent:AVERAGE",
			"DEF:sent4=$rrd:tc" . $e . "_q5_sent:AVERAGE",
			"DEF:sent5=$rrd:tc" . $e . "_q6_sent:AVERAGE",
			"DEF:sent6=$rrd:tc" . $e . "_q7_sent:AVERAGE",
			"DEF:sent7=$rrd:tc" . $e . "_q8_sent:AVERAGE",
			"DEF:sent8=$rrd:tc" . $e . "_q9_sent:AVERAGE",
			"CDEF:allvalues=sent0,sent1,sent2,sent3,sent4,sent5,sent6,sent7,sent8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4]",
				"--title=$dev $config->{graphs}->{_tc1}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:sent0=$rrd:tc" . $e . "_q1_sent:AVERAGE",
				"DEF:sent1=$rrd:tc" . $e . "_q2_sent:AVERAGE",
				"DEF:sent2=$rrd:tc" . $e . "_q3_sent:AVERAGE",
				"DEF:sent3=$rrd:tc" . $e . "_q4_sent:AVERAGE",
				"DEF:sent4=$rrd:tc" . $e . "_q5_sent:AVERAGE",
				"DEF:sent5=$rrd:tc" . $e . "_q6_sent:AVERAGE",
				"DEF:sent6=$rrd:tc" . $e . "_q7_sent:AVERAGE",
				"DEF:sent7=$rrd:tc" . $e . "_q8_sent:AVERAGE",
				"DEF:sent8=$rrd:tc" . $e . "_q9_sent:AVERAGE",
				"CDEF:allvalues=sent0,sent1,sent2,sent3,sent4,sent5,sent6,sent7,sent8,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4]: $err\n") if $err;
		}
		$e2 = $e . "1";
		if($title || ($silent =~ /imagetag/ && $graph =~ /tc$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4] . "'>\n");
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
		for($n = 0; $n < 9; $n++) {
			my ($q1, $q2) = (($qdisc[$n] || "") =~ m/\s*(\S+)\s*(.*)\s*/);
			my $str = ($q1 || "") . ($q2 ? " $q2" : "");
			if($str) {
				if($tc->{map}->{$dev}->{$n} || "" eq $str) {
					$str = $tc->{map}->{$dev}->{$n};
				}
				push(@tmpz, "LINE2:drop" . $n . $LC[$n] . ":$str");
				$str = sprintf("%-19s", substr($str, 0, 19));
				push(@tmp, "LINE2:drop" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:drop" . $n . ":LAST:Cur\\: %5.0lf");
				push(@tmp, "GPRINT:drop" . $n . ":MIN:  Min\\: %5.0lf");
				push(@tmp, "GPRINT:drop" . $n . ":MAX:  Max\\: %5.0lf\\n");
			}
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 4 + 1]",
			"--title=$dev $config->{graphs}->{_tc2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Packets/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:drop0=$rrd:tc" . $e . "_q1_drop:AVERAGE",
			"DEF:drop1=$rrd:tc" . $e . "_q2_drop:AVERAGE",
			"DEF:drop2=$rrd:tc" . $e . "_q3_drop:AVERAGE",
			"DEF:drop3=$rrd:tc" . $e . "_q4_drop:AVERAGE",
			"DEF:drop4=$rrd:tc" . $e . "_q5_drop:AVERAGE",
			"DEF:drop5=$rrd:tc" . $e . "_q6_drop:AVERAGE",
			"DEF:drop6=$rrd:tc" . $e . "_q7_drop:AVERAGE",
			"DEF:drop7=$rrd:tc" . $e . "_q8_drop:AVERAGE",
			"DEF:drop8=$rrd:tc" . $e . "_q9_drop:AVERAGE",
			"CDEF:allvalues=drop0,drop1,drop2,drop3,drop4,drop5,drop6,drop7,drop8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4 + 1]",
				"--title=$dev $config->{graphs}->{_tc2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Packets/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:drop0=$rrd:tc" . $e . "_q1_drop:AVERAGE",
				"DEF:drop1=$rrd:tc" . $e . "_q2_drop:AVERAGE",
				"DEF:drop2=$rrd:tc" . $e . "_q3_drop:AVERAGE",
				"DEF:drop3=$rrd:tc" . $e . "_q4_drop:AVERAGE",
				"DEF:drop4=$rrd:tc" . $e . "_q5_drop:AVERAGE",
				"DEF:drop5=$rrd:tc" . $e . "_q6_drop:AVERAGE",
				"DEF:drop6=$rrd:tc" . $e . "_q7_drop:AVERAGE",
				"DEF:drop7=$rrd:tc" . $e . "_q8_drop:AVERAGE",
				"DEF:drop8=$rrd:tc" . $e . "_q9_drop:AVERAGE",
				"CDEF:allvalues=drop0,drop1,drop2,drop3,drop4,drop5,drop6,drop7,drop8,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4 + 1]: $err\n") if $err;
		}
		$e2 = $e . "2";
		if($title || ($silent =~ /imagetag/ && $graph =~ /tc$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 1] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < 9; $n++) {
			my ($q1, $q2) = (($qdisc[$n] || "") =~ m/\s*(\S+)\s*(.*)\s*/);
			my $str = ($q1 || "") . ($q2 ? " $q2" : "");
			if($str) {
				if($tc->{map}->{$dev}->{$n} || "" eq $str) {
					$str = $tc->{map}->{$dev}->{$n};
				}
				push(@tmpz, "LINE2:over" . $n . $LC[$n] . ":$str");
				$str = sprintf("%-19s", substr($str, 0, 19));
				push(@tmp, "LINE2:over" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:over" . $n . ":LAST:Cur\\: %5.0lf");
				push(@tmp, "GPRINT:over" . $n . ":MIN:  Min\\: %5.0lf");
				push(@tmp, "GPRINT:over" . $n . ":MAX:  Max\\: %5.0lf\\n");
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
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 4 + 2]",
			"--title=$dev $config->{graphs}->{_tc3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Packets/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:over0=$rrd:tc" . $e . "_q1_over:AVERAGE",
			"DEF:over1=$rrd:tc" . $e . "_q2_over:AVERAGE",
			"DEF:over2=$rrd:tc" . $e . "_q3_over:AVERAGE",
			"DEF:over3=$rrd:tc" . $e . "_q4_over:AVERAGE",
			"DEF:over4=$rrd:tc" . $e . "_q5_over:AVERAGE",
			"DEF:over5=$rrd:tc" . $e . "_q6_over:AVERAGE",
			"DEF:over6=$rrd:tc" . $e . "_q7_over:AVERAGE",
			"DEF:over7=$rrd:tc" . $e . "_q8_over:AVERAGE",
			"DEF:over8=$rrd:tc" . $e . "_q9_over:AVERAGE",
			"CDEF:allvalues=over0,over1,over2,over3,over4,over5,over6,over7,over8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4 + 2]",
				"--title=$dev $config->{graphs}->{_tc3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Packets/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:over0=$rrd:tc" . $e . "_q1_over:AVERAGE",
				"DEF:over1=$rrd:tc" . $e . "_q2_over:AVERAGE",
				"DEF:over2=$rrd:tc" . $e . "_q3_over:AVERAGE",
				"DEF:over3=$rrd:tc" . $e . "_q4_over:AVERAGE",
				"DEF:over4=$rrd:tc" . $e . "_q5_over:AVERAGE",
				"DEF:over5=$rrd:tc" . $e . "_q6_over:AVERAGE",
				"DEF:over6=$rrd:tc" . $e . "_q7_over:AVERAGE",
				"DEF:over7=$rrd:tc" . $e . "_q8_over:AVERAGE",
				"DEF:over8=$rrd:tc" . $e . "_q9_over:AVERAGE",
				"CDEF:allvalues=over0,over1,over2,over3,over4,over5,over6,over7,over8,+,+,+,+,+,+,+,+",
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4 + 2]: $err\n") if $err;
		}
		$e2 = $e . "3";
		if($title || ($silent =~ /imagetag/ && $graph =~ /tc$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 2] . "' border='0'></a>\n");
				}
				else { if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 2] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}
		@riglim = @{setup_riglim($rigid[3], $limit[3])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < 9; $n++) {
			my ($q1, $q2) = (($qdisc[$n] || "") =~ m/\s*(\S+)\s*(.*)\s*/);
			my $str = ($q1 || "") . ($q2 ? " $q2" : "");
			if($str) {
				if($tc->{map}->{$dev}->{$n} || "" eq $str) {
					$str = $tc->{map}->{$dev}->{$n};
				}
				push(@tmpz, "LINE2:requ" . $n . $LC[$n] . ":$str");
				$str = sprintf("%-19s", substr($str, 0, 19));
				push(@tmp, "LINE2:requ" . $n . $LC[$n] . ":$str");
				push(@tmp, "GPRINT:requ" . $n . ":LAST:Cur\\: %5.0lf");
				push(@tmp, "GPRINT:requ" . $n . ":MIN:  Min\\: %5.0lf");
				push(@tmp, "GPRINT:requ" . $n . ":MAX:  Max\\: %5.0lf\\n");
			}
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 4 + 3]",
			"--title=$dev $config->{graphs}->{_tc4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Packets/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:requ0=$rrd:tc" . $e . "_q1_requ:AVERAGE",
			"DEF:requ1=$rrd:tc" . $e . "_q2_requ:AVERAGE",
			"DEF:requ2=$rrd:tc" . $e . "_q3_requ:AVERAGE",
			"DEF:requ3=$rrd:tc" . $e . "_q4_requ:AVERAGE",
			"DEF:requ4=$rrd:tc" . $e . "_q5_requ:AVERAGE",
			"DEF:requ5=$rrd:tc" . $e . "_q6_requ:AVERAGE",
			"DEF:requ6=$rrd:tc" . $e . "_q7_requ:AVERAGE",
			"DEF:requ7=$rrd:tc" . $e . "_q8_requ:AVERAGE",
			"DEF:requ8=$rrd:tc" . $e . "_q9_requ:AVERAGE",
			"CDEF:allvalues=requ0,requ1,requ2,requ3,requ4,requ5,requ6,requ7,requ8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 4 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 4 + 3]",
				"--title=$dev $config->{graphs}->{_tc4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Packets/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:requ0=$rrd:tc" . $e . "_q1_requ:AVERAGE",
				"DEF:requ1=$rrd:tc" . $e . "_q2_requ:AVERAGE",
				"DEF:requ2=$rrd:tc" . $e . "_q3_requ:AVERAGE",
				"DEF:requ3=$rrd:tc" . $e . "_q4_requ:AVERAGE",
				"DEF:requ4=$rrd:tc" . $e . "_q5_requ:AVERAGE",
				"DEF:requ5=$rrd:tc" . $e . "_q6_requ:AVERAGE",
				"DEF:requ6=$rrd:tc" . $e . "_q7_requ:AVERAGE",
				"DEF:requ7=$rrd:tc" . $e . "_q8_requ:AVERAGE",
				"DEF:requ8=$rrd:tc" . $e . "_q9_requ:AVERAGE",
				"CDEF:allvalues=requ0,requ1,requ2,requ3,requ4,requ5,requ6,requ7,requ8,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 4 + 3]: $err\n") if $err;
		}
		$e2 = $e . "4";
		if($title || ($silent =~ /imagetag/ && $graph =~ /tc$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 4 + 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 4 + 3] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");
			push(@output, main::graph_footer());
		}
		$e++;
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
