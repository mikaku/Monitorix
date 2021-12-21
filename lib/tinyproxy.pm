#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2021 by Jordi Sanfeliu <jordi@fibranet.cat>
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

package tinyproxy;

use strict;
use warnings;
use Monitorix;
use RRDs;
use LWP::UserAgent;
use XML::LibXML;
use Exporter 'import';
our @EXPORT = qw(tinyproxy_init tinyproxy_update tinyproxy_cgi);

sub tinyproxy_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $tinyproxy = $config->{tinyproxy};

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
		if(scalar(@ds) / 10 != scalar(my @il = split(',', $tinyproxy->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @il = split(',', $tinyproxy->{list})) . ") and $rrd (" . scalar(@ds) / 10 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @il = split(',', $tinyproxy->{list})); $n++) {
			push(@tmp, "DS:tinyproxy" . $n . "_ocon:GAUGE:120:0:U");
			push(@tmp, "DS:tinyproxy" . $n . "_reqs:GAUGE:120:0:U");
			push(@tmp, "DS:tinyproxy" . $n . "_bcon:GAUGE:120:0:U");
			push(@tmp, "DS:tinyproxy" . $n . "_dcon:GAUGE:120:0:U");
			push(@tmp, "DS:tinyproxy" . $n . "_rcon:GAUGE:120:0:U");
			push(@tmp, "DS:tinyproxy" . $n . "_val01:GAUGE:120:0:U");
			push(@tmp, "DS:tinyproxy" . $n . "_val02:GAUGE:120:0:U");
			push(@tmp, "DS:tinyproxy" . $n . "_val03:GAUGE:120:0:U");
			push(@tmp, "DS:tinyproxy" . $n . "_val04:GAUGE:120:0:U");
			push(@tmp, "DS:tinyproxy" . $n . "_val05:GAUGE:120:0:U");
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

	$config->{tinyproxy_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub tinyproxy_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $tinyproxy = $config->{tinyproxy};

	my $str;
	my $n;
	my $rrdata = "N";

	my $suppress_errors = 0;
	$suppress_errors = 1 if !$debug;

	my $e = 0;
	foreach(my @tl = split(',', $tinyproxy->{list})) {
		my $tls = trim($tl[$e]);
		my $ssl = "";

		my $ocon = 0;
		my $reqs = 0;
		my $bcon = 0;
		my $dcon = 0;
		my $rcon = 0;

		$ssl = "ssl_opts => {verify_hostname => 0}"
			if lc($config->{accept_selfsigned_certs}) eq "y";

		my $ua = LWP::UserAgent->new(timeout => 30, $ssl);
		$ua->proxy(http => $tls);
		my $url = $tinyproxy->{desc}->{$tls};
		my $response = $ua->request(HTTP::Request->new('GET', $url));

		if(!$response->is_success) {
			logger("$myself: ERROR: Unable to connect to '$tls'.");
			logger("$myself: " . $response->status_line);
		}

		my $data = XML::LibXML->new->load_html(
			string  => $response->content,
			recover => 1,
			suppress_errors => $suppress_errors
		);

		#print $data->toStringHTML();

		my $xpath = '//tr//td';
		my @stats;

		# This 'foreach' emulates the method 'to_literal_list' as it was
		# introduced in Perl-XML-LibXML version 2.0105 (2013-09-07), and
		# unfortunately not all systems have such a recent version.
		#
		# Some day in the future it should be changed by the line:
		# push(@stats, $_) foreach $data->findnodes($xpath)->to_literal_list;
		foreach($data->findnodes($xpath)->get_nodelist()) {
			my $node;
			($node = $_) =~ s@</?td>@@g;
			push(@stats, $node);
		}
		my %hstats = @stats;

		for my $key (keys %hstats) {
			if($key eq "Number of open connections") {
				$str = $e . "open";
				$ocon = $hstats{$key} - ($config->{tinyproxy_hist}->{$str} || 0);
				$ocon = 0 unless $ocon != $hstats{$key};
				$ocon /= 60;
				$config->{tinyproxy_hist}->{$str} = $hstats{$key};
			}
			if($key eq "Number of requests") {
				$str = $e . "reqs";
				$reqs = $hstats{$key} - ($config->{tinyproxy_hist}->{$str} || 0);
				$reqs = 0 unless $reqs != $hstats{$key};
				$reqs /= 60;
				$config->{tinyproxy_hist}->{$str} = $hstats{$key};
			}
			if($key eq "Number of bad connections") {
				$str = $e . "bcon";
				$bcon = $hstats{$key} - ($config->{tinyproxy_hist}->{$str} || 0);
				$bcon = 0 unless $bcon != $hstats{$key};
				$bcon /= 60;
				$config->{tinyproxy_hist}->{$str} = $hstats{$key};
			}
			if($key eq "Number of denied connections") {
				$str = $e . "dcon";
				$dcon = $hstats{$key} - ($config->{tinyproxy_hist}->{$str} || 0);
				$dcon = 0 unless $dcon != $hstats{$key};
				$dcon /= 60;
				$config->{tinyproxy_hist}->{$str} = $hstats{$key};
			}
			if($key eq "Number of refused connections due to high load") {
				$str = $e . "rcon";
				$rcon = $hstats{$key} - ($config->{tinyproxy_hist}->{$str} || 0);
				$rcon = 0 unless $rcon != $hstats{$key};
				$rcon /= 60;
				$config->{tinyproxy_hist}->{$str} = $hstats{$key};
			}
		}

		$rrdata .= ":$ocon:$reqs:$bcon:$dcon:$rcon:0:0:0:0:0";
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub tinyproxy_cgi {
	my $myself = (caller(0))[3];
	my ($package, $config, $cgi) = @_;
	my @output;

	my $tinyproxy = $config->{tinyproxy};
	my @rigid = split(',', ($tinyproxy->{rigid} || ""));
	my @limit = split(',', ($tinyproxy->{limit} || ""));
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
		for($n = 0; $n < scalar(my @pl = split(',', $tinyproxy->{list})); $n++) {
			$line1 = "                                    ";
			$line2 .= "   OConn  Reqts  BConn  DConn  RConn";
			$line3 .= "------------------------------------";
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
			for($n2 = 0; $n2 < scalar(my @tl = split(',', $tinyproxy->{list})); $n2++) {
				undef(@row);
				$from = $n2 * 10;
				$to = $from + 10;
				my ($ocon, $reqs, $bcon, $dcon, $rcon) = @$line[$from..$to];
				push(@output, sprintf("  %6.1f %6.1f %6.1f %6.1f %6.1f", $ocon || 0, $reqs || 0, $bcon || 0, $dcon || 0, $rcon || 0));
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

	for($n = 0; $n < scalar(my @tl = split(',', $tinyproxy->{list})); $n++) {
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
	foreach (my @tl = split(',', $tinyproxy->{list})) {
		my $url = trim($tl[$e]);

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
		push(@tmp, "LINE2:tinyproxy" . $e . "_reqs#44EEEE:Requests");
		push(@tmp, "GPRINT:tinyproxy" . $e . "_reqs:LAST:      Current\\: %4.0lf");
		push(@tmp, "GPRINT:tinyproxy" . $e . "_reqs:AVERAGE:   Average\\: %4.0lf");
		push(@tmp, "GPRINT:tinyproxy" . $e . "_reqs:MIN:   Min\\: %4.0lf");
		push(@tmp, "GPRINT:tinyproxy" . $e . "_reqs:MAX:   Max\\: %4.0lf\\n");
		push(@tmpz, "LINE2:tinyproxy" . $e . "_reqs#44EEEE:Requests");

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
			"--title=$config->{graphs}->{_tinyproxy1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Requests",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:tinyproxy" . $e . "_reqs=$rrd:tinyproxy" . $e . "_reqs:AVERAGE",
			"CDEF:allvalues=tinyproxy" . $e . "_reqs",
			@CDEF,
			"COMMENT: \\n",
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			"COMMENT: \\n",
			"COMMENT: \\n");
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3]",
				"--title=$config->{graphs}->{_tinyproxy1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Requests",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:tinyproxy" . $e . "_reqs=$rrd:tinyproxy" . $e . "_reqs:AVERAGE",
				"CDEF:allvalues=tinyproxy" . $e . "_reqs",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /tinyproxy$e2/)) {
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
		push(@tmp, "LINE2:tinyproxy" . $e . "_ocon#4444EE:Open");
		push(@tmp, "GPRINT:tinyproxy" . $e . "_ocon:LAST:                 Current\\: %4.0lf\\n");
		push(@tmpz, "LINE2:tinyproxy" . $e . "_ocon#4444EE:Open");
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
			"--title=$config->{graphs}->{_tinyproxy2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Connections",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:tinyproxy" . $e . "_ocon=$rrd:tinyproxy" . $e . "_ocon:AVERAGE",
			"CDEF:allvalues=tinyproxy" . $e . "_ocon",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3 + 1]",
				"--title=$config->{graphs}->{_tinyproxy2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Connections",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:tinyproxy" . $e . "_ocon=$rrd:tinyproxy" . $e . "_ocon:AVERAGE",
				"CDEF:allvalues=tinyproxy" . $e . "_ocon",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /tinyproxy$e2/)) {
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
		push(@tmp, "LINE2:tinyproxy" . $e . "_bcon#FFA500:Bad");
		push(@tmp, "GPRINT:tinyproxy" . $e . "_bcon:LAST:                  Current\\: %4.0lf\\n");
		push(@tmp, "LINE2:tinyproxy" . $e . "_dcon#EEEE44:Denied");
		push(@tmp, "GPRINT:tinyproxy" . $e . "_dcon:LAST:               Current\\: %4.0lf\\n");
		push(@tmp, "LINE2:tinyproxy" . $e . "_rcon#EE4444:Refused (high load)");
		push(@tmp, "GPRINT:tinyproxy" . $e . "_rcon:LAST:  Current\\: %4.0lf\\n");
		push(@tmpz, "LINE2:tinyproxy" . $e . "_bcon#FFA500:Bad");
		push(@tmpz, "LINE2:tinyproxy" . $e . "_dcon#EEEE44:Denied");
		push(@tmpz, "LINE2:tinyproxy" . $e . "_rcon#EE4444:Refused (high load)");
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
			"--title=$config->{graphs}->{_tinyproxy3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Connections",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:tinyproxy" . $e . "_bcon=$rrd:tinyproxy" . $e . "_bcon:AVERAGE",
			"DEF:tinyproxy" . $e . "_dcon=$rrd:tinyproxy" . $e . "_rcon:AVERAGE",
			"DEF:tinyproxy" . $e . "_rcon=$rrd:tinyproxy" . $e . "_dcon:AVERAGE",
			"CDEF:allvalues=tinyproxy" . $e . "_bcon,tinyproxy" . $e . "_dcon,tinyproxy" . $e . "_rcon,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3 + 2]",
				"--title=$config->{graphs}->{_tinyproxy3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Connections",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:tinyproxy" . $e . "_bcon=$rrd:tinyproxy" . $e . "_bcon:AVERAGE",
				"DEF:tinyproxy" . $e . "_dcon=$rrd:tinyproxy" . $e . "_rcon:AVERAGE",
				"DEF:tinyproxy" . $e . "_rcon=$rrd:tinyproxy" . $e . "_dcon:AVERAGE",
				"CDEF:allvalues=tinyproxy" . $e . "_bcon,tinyproxy" . $e . "_dcon,tinyproxy" . $e . "_rcon,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /tinyproxy$e2/)) {
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

			if(lc($tinyproxy->{show_url}) eq "y") {
				push(@output, "    <tr>\n");
				push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
				push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
				push(@output, "       <font size='-1'>\n");
				push(@output, "        <b>&nbsp;&nbsp;<a href='" . trim($url) . "' style='color: " . $colors->{title_fg_color} . "'>" . trim($url) . "</a></b>\n");
				push(@output, "       </font></font>\n");
				push(@output, "      </td>\n");
				push(@output, "    </tr>\n");
			}
			push(@output, main::graph_footer());
		}
		$e++;
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
