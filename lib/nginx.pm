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

package nginx;

use strict;
use warnings;
use Monitorix;
use RRDs;
use LWP::UserAgent;
use Exporter 'import';
our @EXPORT = qw(nginx_init nginx_update nginx_cgi);

sub nginx_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nginx = $config->{nginx};

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
		eval {
			RRDs::create($rrd,
				"--step=60",
				"DS:nginx_requests:GAUGE:120:0:U",
				"DS:nginx_total:GAUGE:120:0:U",
				"DS:nginx_reading:GAUGE:120:0:U",
				"DS:nginx_writing:GAUGE:120:0:U",
				"DS:nginx_waiting:GAUGE:120:0:U",
				"DS:nginx_bytes_in:GAUGE:120:0:U",
				"DS:nginx_bytes_out:GAUGE:120:0:U",
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

	if(!defined($rrd)) {
		logger("$myself: ERROR: undefined 'port' option.");
		return 0;
	}

	if($config->{os} eq "Linux") {
		system("iptables -N monitorix_nginx_IN 2>/dev/null");
		system("iptables -I INPUT -p tcp --sport 1024:65535 --dport $nginx->{port} -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j monitorix_nginx_IN -c 0 0");
		system("iptables -I OUTPUT -p tcp --sport $nginx->{port} --dport 1024:65535 -m conntrack --ctstate ESTABLISHED,RELATED -j monitorix_nginx_IN -c 0 0");
	}
	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		system("ipfw delete $nginx->{rule} 2>/dev/null");
		system("ipfw -q add $nginx->{rule} count tcp from me $nginx->{port} to any");
		system("ipfw -q add $nginx->{rule} count tcp from any to me $nginx->{port}");
	}

	$config->{nginx_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub nginx_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nginx = $config->{nginx};

	my $reqs = 0;
	my $tot = 0;
	my $reads = 0;
	my $writes = 0;
	my $waits = 0;
	my $in = 0;
	my $out = 0;

	my $url = "http://127.0.0.1:" . $nginx->{port} . "/nginx_status";
	my $ua = LWP::UserAgent->new(timeout => 30);
	my $response = $ua->request(HTTP::Request->new('GET', $url));
	my $rrdata = "N";

	if(!$response->is_success) {
		logger("$myself: ERROR: Unable to connect to '$url'.");
	}

	foreach(split('\n', $response->content)) {
		if(/^Active connections:\s+(\d+)\s*/) {
			$tot = $1;
			next;
		}
		if(/^\s+(\d+)\s+(\d+)\s+(\d+)\s*/) {
			$reqs = $3 - ($config->{nginx_hist}->{'requests'} || 0);
			$reqs = 0 unless $reqs != $3;
			$config->{nginx_hist}->{'requests'} = $3;
		}
		if(/^Reading:\s+(\d+).*Writing:\s+(\d+).*Waiting:\s+(\d+)\s*/) {
			$reads = $1;
			$writes = $2;
			$waits = $3;
		}
	}

	if($config->{os} eq "Linux") {
		my $val;
		open(IN, "iptables -nxvL INPUT |");
		while(<IN>) {
			if(/ monitorix_nginx_IN /) {
				(undef, $val) = split(' ', $_);
				chomp($val);
				$in = $val - ($config->{nginx_hist}->{'in'} || 0);
				$in = 0 unless $in != $val;
				$config->{nginx_hist}->{'in'} = $val;
				$in /= 60;
				last;
			}
		}
		close(IN);
		open(IN, "iptables -nxvL OUTPUT |");
		while(<IN>) {
			if(/ monitorix_nginx_IN /) {
				(undef, $val) = split(' ', $_);
				chomp($val);
				$out = $val - ($config->{nginx_hist}->{'out'} || 0);
				$out = 0 unless $out != $val;
				$config->{nginx_hist}->{'out'} = $val;
				$out /= 60;
				last;
			}
		}
		close(IN);
	}
	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		my $val;
		open(IN, "ipfw show $nginx->{rule} 2>/dev/null |");
		while(<IN>) {
			if(/ from any to me dst-port $nginx->{port}$/) {
				(undef, undef, $val) = split(' ', $_);
				chomp($val);
				$in = $val - ($config->{nginx_hist}->{'in'} || 0);
				$in = 0 unless $in != $val;
				$config->{nginx_hist}->{'in'} = $val;
				$in /= 60;
			}
			if(/ from me $nginx->{port} to any$/) {
				(undef, undef, $val) = split(' ', $_);
				chomp($val);
				$out = $val - ($config->{nginx_hist}->{'out'} || 0);
				$out = 0 unless $out != $val;
				$config->{nginx_hist}->{'out'} = $val;
				$out /= 60;
			}
		}
		close(IN);
	}

	$rrdata .= ":$reqs:$tot:$reads:$writes:$waits:$in:$out";
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub nginx_cgi {
	my ($package, $config, $cgi) = @_;

	my $nginx = $config->{nginx};
	my @rigid = split(',', $nginx->{rigid});
	my @limit = split(',', $nginx->{limit});
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};
	my $zoom = "--zoom=" . $config->{global_zoom};

	my $u = "";
	my $width;
	my $height;
	my @riglim;
	my @warning;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $T = "B";
	my $vlabel = "bytes/s";
	my $n;
	my $err;

	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	$title = !$silent ? $title : "";

	if(lc($config->{netstats_in_bps}) eq "y") {
		$T = "b";
		$vlabel = "bits/s";
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
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		print("Time   Total  Reading  Writing  Waiting Requests   K$T/s_I   K$T/s_O\n");
		print("------------------------------------------------------------------ \n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			my ($req, $tot, $rea, $wri, $wai, $ki, $ko) = @$line;
			$ki /= 1024;
			$ko /= 1024;
			if(lc($config->{netstats_in_bps}) eq "y") {
				$ki *= 8;
				$ko *= 8;
			}
			@row = ($tot, $rea, $wri, $wai, $req, $ki, $ko);
			$time = $time - (1 / $tf->{ts});
			printf(" %2d$tf->{tc}  %6d   %6d   %6d   %6d   %6d   %6d   %6d\n", $time, @row);
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
	}
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
	push(@tmp, "AREA:total#44EEEE:Total");
	push(@tmp, "GPRINT:total:LAST:       Current\\: %5.0lf");
	push(@tmp, "GPRINT:total:AVERAGE:    Average\\: %5.0lf");
	push(@tmp, "GPRINT:total:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:total:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "AREA:reading#44EE44:Reading");
	push(@tmp, "GPRINT:reading:LAST:     Current\\: %5.0lf");
	push(@tmp, "GPRINT:reading:AVERAGE:    Average\\: %5.0lf");
	push(@tmp, "GPRINT:reading:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:reading:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "AREA:writing#4444EE:Writing");
	push(@tmp, "GPRINT:writing:LAST:     Current\\: %5.0lf");
	push(@tmp, "GPRINT:writing:AVERAGE:    Average\\: %5.0lf");
	push(@tmp, "GPRINT:writing:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:writing:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "AREA:waiting#EE44EE:Waiting");
	push(@tmp, "GPRINT:waiting:LAST:     Current\\: %5.0lf");
	push(@tmp, "GPRINT:waiting:AVERAGE:    Average\\: %5.0lf");
	push(@tmp, "GPRINT:waiting:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:waiting:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "LINE1:total#00EEEE");
	push(@tmp, "LINE1:reading#00EE00");
	push(@tmp, "LINE1:writing#0000EE");
	push(@tmp, "LINE1:waiting#EE00EE");
	push(@tmpz, "AREA:total#44EEEE:Total");
	push(@tmpz, "AREA:reading#44EE44:Reading");
	push(@tmpz, "AREA:writing#4444EE:Writing");
	push(@tmpz, "AREA:waiting#EE44EE:Waiting");
	push(@tmpz, "LINE1:total#00EEEE");
	push(@tmpz, "LINE1:reading#00EE00");
	push(@tmpz, "LINE1:writing#0000EE");
	push(@tmpz, "LINE1:waiting#EE00EE");
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
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$config->{graphs}->{_nginx1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Connections/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:total=$rrd:nginx_total:AVERAGE",
		"DEF:reading=$rrd:nginx_reading:AVERAGE",
		"DEF:writing=$rrd:nginx_writing:AVERAGE",
		"DEF:waiting=$rrd:nginx_waiting:AVERAGE",
		"CDEF:allvalues=total,reading,writing,waiting,+,+,+",
		@CDEF,
		@tmp,
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$config->{graphs}->{_nginx1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Connections/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:total=$rrd:nginx_total:AVERAGE",
			"DEF:reading=$rrd:nginx_reading:AVERAGE",
			"DEF:writing=$rrd:nginx_writing:AVERAGE",
			"DEF:waiting=$rrd:nginx_waiting:AVERAGE",
			"CDEF:allvalues=total,reading,writing,waiting,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nginx1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "'>\n");
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
	undef(@CDEF);
	push(@tmp, "AREA:requests#44EEEE:Requests");
	push(@tmp, "GPRINT:requests:LAST:             Current\\: %5.1lf\\n");
	push(@tmp, "LINE1:requests#00EEEE");
	push(@tmpz, "AREA:requests#44EEEE:Requests");
	push(@tmpz, "LINE1:requests#00EEEE");
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
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$config->{graphs}->{_nginx2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:requests=$rrd:nginx_requests:AVERAGE",
		"CDEF:allvalues=requests",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$config->{graphs}->{_nginx2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:requests=$rrd:nginx_requests:AVERAGE",
			"CDEF:allvalues=requests",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nginx2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "'>\n");
		}
	}

	undef(@warning);
	my $pnum;
	if($config->{os} eq "Linux") {
		open(IN, "netstat -nl --tcp |");
		while(<IN>) {
			(undef, undef, undef, $pnum) = split(' ', $_);
			chomp($pnum);
			$pnum =~ s/.*://;
			if($pnum eq $nginx->{port}) {
				last;
			}
		}
		close(IN);
	}
	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		open(IN, "netstat -anl -p tcp |");
		my $stat;
		while(<IN>) {
			(undef, undef, undef, $pnum, undef, $stat) = split(' ', $_);
			chomp($stat);
			if($stat eq "LISTEN") {
				chomp($pnum);
				($pnum) = ($pnum =~ m/^.*?(\.\d+$)/);
				$pnum =~ s/\.//;
				if($pnum eq $nginx->{port}) {
					last;
				}
			}
		}
		close(IN);
	}
	if($pnum ne $nginx->{port}) {
		push(@warning, $colors->{warning_color});
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
	undef(@CDEF);
	push(@tmp, "AREA:B_in#44EE44:Input");
	push(@tmp, "AREA:B_out#4444EE:Output");
	push(@tmp, "AREA:B_out#4444EE:");
	push(@tmp, "AREA:B_in#44EE44:");
	push(@tmp, "LINE1:B_out#0000EE");
	push(@tmp, "LINE1:B_in#00EE00");
	push(@tmpz, "AREA:B_in#44EE44:Input");
	push(@tmpz, "AREA:B_out#4444EE:Output");
	push(@tmpz, "AREA:B_out#4444EE:");
	push(@tmpz, "AREA:B_in#44EE44:");
	push(@tmpz, "LINE1:B_out#0000EE");
	push(@tmpz, "LINE1:B_in#00EE00");
	if(lc($config->{netstats_in_bps}) eq "y") {
		push(@CDEF, "CDEF:B_in=in,8,*");
		push(@CDEF, "CDEF:B_out=out,8,*");
	} else {
		push(@CDEF, "CDEF:B_in=in");
		push(@CDEF, "CDEF:B_out=out");
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
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$config->{graphs}->{_nginx3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		@warning,
		"DEF:in=$rrd:nginx_bytes_in:AVERAGE",
		"DEF:out=$rrd:nginx_bytes_out:AVERAGE",
		"CDEF:allvalues=in,out,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$config->{graphs}->{_nginx3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			@warning,
			"DEF:in=$rrd:nginx_bytes_in:AVERAGE",
			"DEF:out=$rrd:nginx_bytes_out:AVERAGE",
			"CDEF:allvalues=in,out,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nginx3/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "'>\n");
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
