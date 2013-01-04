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

package apache;

use strict;
use warnings;
use Monitorix;
use RRDs;
use LWP::UserAgent;
use Exporter 'import';
our @EXPORT = qw(apache_init apache_update apache_cgi);

sub apache_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $apache = $config->{apache};

	my $info;
	my @ds;
	my @tmp;
	my $n;

	if(!scalar(my @al = split(',', $apache->{list}))) {
		logger("$myself: ERROR: missing or not defined 'list' option.");
		return 0;
	}

	if(-e $rrd) {
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'ds[') == 0) {
				if(index($key, '.type') != -1) {
					push(@ds, substr($key, 3, index($key, ']') - 3));
				}
			}
		}
		if(scalar(@ds) / 5 != scalar(my @al = split(',', $apache->{list}))) {
			logger("Detected size mismatch between 'list' option (" . scalar(my @al = split(',', $apache->{list})) . ") and $rrd (" . scalar(@ds) / 5 . "). Resizing it accordingly. All historic data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
	}

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
		for($n = 0; $n < scalar(my @al = split(',', $apache->{list})); $n++) {
			push(@tmp, "DS:apache" . $n . "_acc:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_kb:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_cpu:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_busy:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_idle:GAUGE:120:0:U");
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

	$config->{apache_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub apache_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $apache = $config->{apache};

	my $str;
	my $rrdata = "N";

	my $n = 0;
	foreach(my @al = split(',', $apache->{list})) {
		my $url = trim($_) . "/server-status?auto";
		my $ua = LWP::UserAgent->new(timeout => 30);
		my $response = $ua->request(HTTP::Request->new('GET', $url));

		my $acc = 0;
		my $kb = 0;
		my $cpu = 0;
		my $busy = 0;
		my $idle = 0;

		foreach(split('\n', $response->content)) {
			if(/^Total Accesses:\s+(\d+)$/) {
				$str = $n . "acc";
				$acc = $1 - ($config->{apache_hist}->{$str} || 0);
				$acc = 0 unless $acc != $1;
				$acc /= 60;
				$config->{apache_hist}->{$str} = $1;
				next;
			}
			if(/^Total kBytes:\s+(\d+)$/) {
				$str = $n . "kb";
				$kb = $1 - ($config->{apache_hist}->{$str} || 0);
				$kb = 0 unless $kb != $1;
				$config->{apache_hist}->{$str} = $1;
				next;
			}
			if(/^CPULoad:\s+(\d*\.\d+)$/) {
				$cpu = abs($1) || 0;
				next;
			}
			if(/^BusyWorkers:\s+(\d+)/ || /^BusyServers:\s+(\d+)/) {
				$busy = int($1) || 0;
				next;
			}
			if(/^IdleWorkers:\s+(\d+)/ || /^IdleServers:\s+(\d+)/) {
				$idle = int($1) || 0;
				last;
			}
		}
		$rrdata .= ":$acc:$kb:$cpu:$busy:$idle";
		$n++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub apache_cgi {
	my ($package, $config, $cgi) = @_;

	my $apache = $config->{apache};
	my @rigid = split(',', $apache->{rigid});
	my @limit = split(',', $apache->{limit});
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};

	my $u = "";
	my $width;
	my $height;
	my @riglim;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my $e;
	my $e2;
	my $n;
	my $n2;
	my $str;
	my $err;

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
		for($n = 0; $n < scalar(my @al = split(',', $apache->{list})); $n++) {
			$line1 = "                                          ";
			$line2 .= "   Acceses     kbytes      CPU  Busy  Idle";
			$line3 .= "------------------------------------------";
			if($line1) {
				my $i = length($line1);
				printf(sprintf("%${i}s", sprintf("%s", trim($al[$n]))));
			}
		}
		print("\n");
		print("Time$line2\n");
		print("----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			printf(" %2d$tf->{tc}", $time);
			for($n2 = 0; $n2 < scalar(my @al = split(',', $apache->{list})); $n2++) {
				undef(@row);
				$from = $n2 * 5;
				$to = $from + 5;
				push(@row, @$line[$from..$to]);
				printf("   %7d  %9d    %4.2f%%   %3d   %3d", @row);
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

	for($n = 0; $n < scalar(my @al = split(',', $apache->{list})); $n++) {
		for($n2 = 1; $n2 <= 3; $n2++) {
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
	foreach my $url (my @al = split(',', $apache->{list})) {
		if($e) {
			print("  <br>\n");
		}
		if($title) {
			main::graph_header($title, 2);
		}
		undef(@riglim);
		if(trim($rigid[0]) eq 1) {
			push(@riglim, "--upper-limit=" . trim($limit[0]));
		} else {
			if(trim($rigid[0]) eq 2) {
				push(@riglim, "--upper-limit=" . trim($limit[0]));
				push(@riglim, "--rigid");
			}
		}
		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='$colors->{title_bg_color}'>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:apache" . $e . "_idle#4444EE:Idle");
		push(@tmp, "GPRINT:apache" . $e . "_idle:LAST:            Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_idle:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_idle:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_idle:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "AREA:apache" . $e . "_busy#44EEEE:Busy");
		push(@tmp, "GPRINT:apache" . $e . "_busy:LAST:            Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_busy:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_busy:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_busy:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "LINE1:apache" . $e . "_idle#0000EE");
		push(@tmp, "LINE1:apache" . $e . "_busy#00EEEE");
		push(@tmp, "LINE1:apache" . $e . "_tot#EE0000");
		push(@tmpz, "AREA:apache" . $e . "_idle#4444EE:Idle");
		push(@tmpz, "AREA:apache" . $e . "_busy#44EEEE:Busy");
		push(@tmpz, "LINE2:apache" . $e . "_idle#0000EE");
		push(@tmpz, "LINE2:apache" . $e . "_busy#00EEEE");
		push(@tmpz, "LINE2:apache" . $e . "_tot#EE0000");
		($width, $height) = split('x', $config->{graph_size}->{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3]",
			"--title=$config->{graphs}->{_apache1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Workers",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:apache" . $e . "_busy=$rrd:apache" . $e . "_busy:AVERAGE",
			"DEF:apache" . $e . "_idle=$rrd:apache" . $e . "_idle:AVERAGE",
			"CDEF:apache" . $e . "_tot=apache" . $e . "_busy,apache" . $e . "_idle,+",
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			"COMMENT: \\n");
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3]",
				"--title=$config->{graphs}->{_apache1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=Workers",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:apache" . $e . "_busy=$rrd:apache" . $e . "_busy:AVERAGE",
				"DEF:apache" . $e . "_idle=$rrd:apache" . $e . "_idle:AVERAGE",
				"CDEF:apache" . $e . "_tot=apache" . $e . "_busy,apache" . $e . "_idle,+",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3] . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
		}
		undef(@riglim);
		if(trim($rigid[1]) eq 1) {
			push(@riglim, "--upper-limit=" . trim($limit[1]));
		} else {
			if(trim($rigid[1]) eq 2) {
				push(@riglim, "--upper-limit=" . trim($limit[1]));
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:apache" . $e . "_cpu#44AAEE:CPU");
		push(@tmp, "GPRINT:apache" . $e . "_cpu:LAST:                  Current\\: %5.2lf%%\\n");
		push(@tmp, "LINE1:apache" . $e . "_cpu#00EEEE");
		push(@tmpz, "AREA:apache" . $e . "_cpu#44AAEE:CPU");
		push(@tmpz, "LINE1:apache" . $e . "_cpu#00EEEE");
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
			"--title=$config->{graphs}->{_apache2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:apache" . $e . "_cpu=$rrd:apache" . $e . "_cpu:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 1]",
				"--title=$config->{graphs}->{_apache2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=Percent",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:apache" . $e . "_cpu=$rrd:apache" . $e . "_cpu:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3 + 1] . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3 + 1] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 1] . "'>\n");
			}
		}

		undef(@riglim);
		if(trim($rigid[2]) eq 1) {
			push(@riglim, "--upper-limit=" . trim($limit[2]));
		} else {
			if(trim($rigid[2]) eq 2) {
				push(@riglim, "--upper-limit=" . trim($limit[2]));
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:apache" . $e . "_acc#44EE44:Accesses");
		push(@tmp, "GPRINT:apache" . $e . "_acc:LAST:             Current\\: %5.2lf\\n");
		push(@tmp, "LINE1:apache" . $e . "_acc#00EE00");
		push(@tmpz, "AREA:apache" . $e . "_acc#44EE44:Accesses");
		push(@tmpz, "LINE1:apache" . $e . "_acc#00EE00");
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
			"--title=$config->{graphs}->{_apache3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Accesses/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:apache" . $e . "_acc=$rrd:apache" . $e . "_acc:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 2]",
				"--title=$config->{graphs}->{_apache3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=Accesses/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:apache" . $e . "_acc=$rrd:apache" . $e . "_acc:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3 + 2] . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNGz[$e * 3 + 2] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$e * 3 + 2] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    </tr>\n");

			print("    <tr>\n");
			print "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n";
			print "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n";
			print "       <font size='-1'>\n";
			print "        <b style='{color: " . $colors->{title_fg_color} . "}'>&nbsp;&nbsp;$url<b>\n";
			print "       </font></font>\n";
			print "      </td>\n";
			print("    </tr>\n");
			main::graph_footer();
		}
		$e++;
	}
	print("  <br>\n");
	return;
}

1;
