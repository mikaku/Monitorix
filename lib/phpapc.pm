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

package phpapc;

use strict;
use warnings;
use Monitorix;
use RRDs;
use LWP::UserAgent;
use Exporter 'import';
our @EXPORT = qw(phpapc_init phpapc_update phpapc_cgi);

sub phpapc_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $phpapc = $config->{phpapc};

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
		if(scalar(@ds) / 14 != scalar(my @il = split(',', $phpapc->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @il = split(',', $phpapc->{list})) . ") and $rrd (" . scalar(@ds) / 14 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @il = split(',', $phpapc->{list})); $n++) {
			push(@tmp, "DS:phpapc" . $n . "_size:GAUGE:120:0:U");
			push(@tmp, "DS:phpapc" . $n . "_free:GAUGE:120:0:100");
			push(@tmp, "DS:phpapc" . $n . "_used:GAUGE:120:0:100");
			push(@tmp, "DS:phpapc" . $n . "_hits:GAUGE:120:0:100");
			push(@tmp, "DS:phpapc" . $n . "_miss:GAUGE:120:0:100");
			push(@tmp, "DS:phpapc" . $n . "_cachf:GAUGE:120:0:U");
			push(@tmp, "DS:phpapc" . $n . "_cachs:GAUGE:120:0:U");
			push(@tmp, "DS:phpapc" . $n . "_cachfps:GAUGE:120:0:U");
			push(@tmp, "DS:phpapc" . $n . "_frag:GAUGE:120:0:100");
			push(@tmp, "DS:phpapc" . $n . "_val01:GAUGE:120:0:U");
			push(@tmp, "DS:phpapc" . $n . "_val02:GAUGE:120:0:U");
			push(@tmp, "DS:phpapc" . $n . "_val03:GAUGE:120:0:U");
			push(@tmp, "DS:phpapc" . $n . "_val04:GAUGE:120:0:U");
			push(@tmp, "DS:phpapc" . $n . "_val05:GAUGE:120:0:U");
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

	$config->{phpapc_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub phpapc_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $phpapc = $config->{phpapc};

	my $n;
	my $rrdata = "N";

	my $e = 0;
	foreach(my @pl = split(',', $phpapc->{list})) {
		my $pls = trim($pl[$e]);
		my $ssl = "";

		$ssl = "ssl_opts => {verify_hostname => 0}"
			if lc($config->{accept_selfsigned_certs}) eq "y";

		my $ua = LWP::UserAgent->new(timeout => 30, $ssl);
		$ua->agent($config->{user_agent_id}) if $config->{user_agent_id} || "";
		my $response = $ua->request(HTTP::Request->new('GET', $pls));
		my $data = $response->content;

		if(!$response->is_success) {
			logger("$myself: ERROR: Unable to connect to '$pls'.");
			logger("$myself: " . $response->status_line);
		}

		$data =~ s/\n//g;
		my ($msize, $msize_suffix) = ($data =~ m/<td class=td-0>apc.shm_size<\/td><td>(\d+)([MG])<\/td>/);
		# convert msize to KB
		$msize *= 1024 * 1024 if(grep {$_ eq $msize_suffix} ("G", "GBytes"));
		$msize *= 1024 if(grep {$_ eq $msize_suffix} ("M", "MBytes"));

		my ($free) = ($data =~ m/<\/span>Free:\s+.*?\((\d+\.\d+)%\)<\/td>/) && ($1 || 0);
		my ($hits) = ($data =~ m/<\/span>Hits:\s+.*?\((\d+\.\d+)%\)<\/td>/) && ($1 || 0);
		my ($used) = ($data =~ m/<\/span>Used:\s+.*?\((\d+\.\d+)%\)<\/td>/) && ($1 || 0);
		my ($missed) = ($data =~ m/<\/span>Misses:\s+.*?\((\d+\.\d+)%\)<\/td>/) && ($1 || 0);

		my (undef, $cachf, $cachs, $cache_suffix) = ($data =~ m/<h2>.*?Cache Information<\/h2>.*?Cached (Files|Variables)<\/td><td>(\d+)\s+\(\s*(\d+\.\d+)\s+(\S*Bytes)\)/);
		my $str = $e . "cachf";
		my $cachfps = $cachf - ($config->{phpapc_hist}->{$str} || 0);
		$cachfps = 0 unless $cachfps != $cachf;
		$cachfps /= 60;
		$config->{phpapc_hist}->{$str} = $cachf;

		# convert cache size to KB
		$cachs *= 1024 * 1024 if ($cache_suffix || "") eq "GBytes";
		$cachs *= 1024 if ($cache_suffix || "") eq "MBytes";

		my ($frag) = ($data =~ m/<\/br>Fragmentation:\s+(\d+\.*\d*?)%/) && ($1 || 0);

		$rrdata .= ":$msize:$free:$used:$hits:$missed:$cachf:$cachs:$cachfps:$frag:0:0:0:0:0";
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub phpapc_cgi {
	my $myself = (caller(0))[3];
	my ($package, $config, $cgi) = @_;
	my @output;

	my $phpapc = $config->{phpapc};
	my @rigid = split(',', ($phpapc->{rigid} || ""));
	my @limit = split(',', ($phpapc->{limit} || ""));
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
		for($n = 0; $n < scalar(my @pl = split(',', $phpapc->{list})); $n++) {
			$line1 = "                                           ";
			$line2 .= "    Free   Used  Frag.   Hits  Miss. CacheF";
			$line3 .= "-------------------------------------------";
			if($line1) {
				my $i = length($line1);
				push(@output, sprintf(sprintf("%${i}s", sprintf("%s", trim($pl[$n])))));
			}
		}
		push(@output, "\n");
		push(@output, "Time$line2\n");
		push(@output, "----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc}", $time));
			for($n2 = 0; $n2 < scalar(my @pl = split(',', $phpapc->{list})); $n2++) {
				undef(@row);
				$from = $n2 * 14;
				$to = $from + 14;
				my (undef, $free, $used, $hits, $miss, $cachf, undef, undef, $frag) = @$line[$from..$to];
				push(@output, sprintf("  %5.1f%% %5.1f%% %5.1f%% %5.1f%% %5.1f%% %6d", $free || 0, $used || 0, $frag || 0, $hits || 0, $miss || 0, $cachf || 0));
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

	for($n = 0; $n < scalar(my @pl = split(',', $phpapc->{list})); $n++) {
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
	foreach my $url (my @pl = split(',', $phpapc->{list})) {

		# get additional information from APC
		my $pls = trim($pl[$e]);
		my $ua = LWP::UserAgent->new(timeout => 30);
		my $response = $ua->request(HTTP::Request->new('GET', $pls));
		my $data = $response->content;
		if(!$response->is_success) {
			logger("$myself: ERROR: Unable to connect to '$pls'.");
		}
		$data =~ s/\n//g;

		my ($msize, $msize_suffix) = ($data =~ m/<td class=td-0>apc.shm_size<\/td><td>(\d+)([MG])<\/td>/);
		$msize .= ($msize_suffix || "") . "B";

		my ($uptimeline) = ($data =~ m/Uptime<\/td><td>(.*?)<\/td>/) && ($1 || 0);
		if($RRDs::VERSION > 1.2) {
			$uptimeline = "COMMENT:uptime\\: " . trim($uptimeline) . "\\c";
		} else {
			$uptimeline = "COMMENT:uptime: " . trim($uptimeline) . "\\c";
		}

		if($e) {
			push(@output, "  <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}
		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:free#44EEEE:Free");
		push(@tmp, "GPRINT:phpapc" . $e . "_free:LAST:           Current\\: %4.1lf%%");
		push(@tmp, "GPRINT:phpapc" . $e . "_free:AVERAGE:   Average\\: %4.1lf%%");
		push(@tmp, "GPRINT:phpapc" . $e . "_free:MIN:   Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:phpapc" . $e . "_free:MAX:   Max\\: %4.1lf%%\\n");
		push(@tmp, "AREA:phpapc" . $e . "_used#4444EE:Used");
		push(@tmp, "GPRINT:phpapc" . $e . "_used:LAST:           Current\\: %4.1lf%%");
		push(@tmp, "GPRINT:phpapc" . $e . "_used:AVERAGE:   Average\\: %4.1lf%%");
		push(@tmp, "GPRINT:phpapc" . $e . "_used:MIN:   Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:phpapc" . $e . "_used:MAX:   Max\\: %4.1lf%%\\n");
		push(@tmp, "AREA:phpapc" . $e . "_frag#EE4444:Fragmentation");
		push(@tmp, "GPRINT:phpapc" . $e . "_frag:LAST:  Current\\: %4.1lf%%");
		push(@tmp, "GPRINT:phpapc" . $e . "_frag:AVERAGE:   Average\\: %4.1lf%%");
		push(@tmp, "GPRINT:phpapc" . $e . "_frag:MIN:   Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:phpapc" . $e . "_frag:MAX:   Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE1:phpapc" . $e . "_frag#EE0000");
		push(@tmp, "LINE1:phpapc" . $e . "_used#0000EE:");
		push(@tmpz, "AREA:free#44EEEE:Free");
		push(@tmpz, "AREA:phpapc" . $e . "_used#4444EE:Used");
		push(@tmpz, "AREA:phpapc" . $e . "_frag#EE4444:Fragmentation");
		push(@tmpz, "LINE2:phpapc" . $e . "_frag#EE0000");
		push(@tmpz, "LINE2:phpapc" . $e . "_used#0000EE");

		# If 'free' is UNKNOWN replace it with 'free' otherwise replace it with 100 (to fill up all the graph)
		push(@CDEF, "CDEF:free=phpapc" . $e . "_free,UN,phpapc" . $e . "_free,100,IF");

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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 3]",
			"--title=$config->{graphs}->{_phpapc1} ($msize)  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:phpapc" . $e . "_free=$rrd:phpapc" . $e . "_free:AVERAGE",
			"DEF:phpapc" . $e . "_used=$rrd:phpapc" . $e . "_used:AVERAGE",
			"DEF:phpapc" . $e . "_frag=$rrd:phpapc" . $e . "_frag:AVERAGE",
			"CDEF:allvalues=phpapc" . $e . "_free,phpapc" . $e . "_used,phpapc" . $e . "_frag,+,+",
			@CDEF,
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			$uptimeline);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3]",
				"--title=$config->{graphs}->{_phpapc1} ($msize)  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Percent (%)",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:phpapc" . $e . "_free=$rrd:phpapc" . $e . "_free:AVERAGE",
				"DEF:phpapc" . $e . "_used=$rrd:phpapc" . $e . "_used:AVERAGE",
				"DEF:phpapc" . $e . "_frag=$rrd:phpapc" . $e . "_frag:AVERAGE",
				"CDEF:allvalues=phpapc" . $e . "_free,phpapc" . $e . "_used,phpapc" . $e . "_frag,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /phpapc$e2/)) {
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
		push(@tmp, "AREA:phpapc" . $e . "_hits#4444EE:Hits");
		push(@tmp, "GPRINT:phpapc" . $e . "_hits:LAST:                 Current\\: %4.1lf%%\\n");
		push(@tmp, "AREA:phpapc" . $e . "_miss#EE44EE:Misses");
		push(@tmp, "GPRINT:phpapc" . $e . "_miss:LAST:               Current\\: %4.1lf%%\\n");
		push(@tmp, "LINE1:phpapc" . $e . "_hits#0000EE");
		push(@tmp, "LINE1:phpapc" . $e . "_miss#EE00EE");
		push(@tmpz, "AREA:phpapc" . $e . "_hits#4444EE:Hits");
		push(@tmpz, "AREA:phpapc" . $e . "_miss#EE44EE:Misses");
		push(@tmpz, "LINE1:phpapc" . $e . "_hits#0000EE");
		push(@tmpz, "LINE1:phpapc" . $e . "_miss#EE00EE");
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
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 3 + 1]",
			"--title=$config->{graphs}->{_phpapc2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:phpapc" . $e . "_hits=$rrd:phpapc" . $e . "_hits:AVERAGE",
			"DEF:phpapc" . $e . "_miss=$rrd:phpapc" . $e . "_miss:AVERAGE",
			"CDEF:allvalues=phpapc" . $e . "_hits,phpapc" . $e . "_miss,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3 + 1]",
				"--title=$config->{graphs}->{_phpapc2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Percent (%)",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:phpapc" . $e . "_hits=$rrd:phpapc" . $e . "_hits:AVERAGE",
				"DEF:phpapc" . $e . "_miss=$rrd:phpapc" . $e . "_miss:AVERAGE",
				"CDEF:allvalues=phpapc" . $e . "_hits,phpapc" . $e . "_miss,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /phpapc$e2/)) {
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
		push(@tmp, "AREA:phpapc" . $e . "_cachfps#44EE44:Cached files");
		push(@tmp, "GPRINT:phpapc" . $e . "_cachf:LAST:         Current\\: %1.0lf\\n");
		push(@tmp, "LINE1:phpapc" . $e . "_cachfps#00EE00");
		push(@tmpz, "AREA:phpapc" . $e . "_cachfps#44EE44:Cached files");
		push(@tmpz, "LINE1:phpapc" . $e . "_cachfps#00EE00");
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
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 3 + 2]",
			"--title=$config->{graphs}->{_phpapc3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Cached files/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:phpapc" . $e . "_cachf=$rrd:phpapc" . $e . "_cachf:AVERAGE",
			"DEF:phpapc" . $e . "_cachfps=$rrd:phpapc" . $e . "_cachfps:AVERAGE",
			"DEF:phpapc" . $e . "_cachs=$rrd:phpapc" . $e . "_cachs:AVERAGE",
			"CDEF:allvalues=phpapc" . $e . "_cachf,phpapc" . $e . "_cachfps,phpapc" . $e . "_cachs,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3 + 2]",
				"--title=$config->{graphs}->{_phpapc3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Cached files/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:phpapc" . $e . "_cachf=$rrd:phpapc" . $e . "_cachf:AVERAGE",
				"DEF:phpapc" . $e . "_cachfps=$rrd:phpapc" . $e . "_cachfps:AVERAGE",
				"DEF:phpapc" . $e . "_cachs=$rrd:phpapc" . $e . "_cachs:AVERAGE",
				"CDEF:allvalues=phpapc" . $e . "_cachf,phpapc" . $e . "_cachfps,phpapc" . $e . "_cachs,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /phpapc$e2/)) {
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
			push(@output, "        <b>&nbsp;&nbsp;<a href='" . trim($url) . "' style='color: " . $colors->{title_fg_color} . "'>" . trim($url) . "</a></b>\n");
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
