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

	my $info;
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	my $table = $config->{ip_default_table};

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

	if(!defined($rrd)) {
		logger("$myself: ERROR: undefined 'port' option.");
		return 0;
	}

	if(lc($config->{use_external_firewall} || "") eq "n") {
		if($config->{os} eq "Linux") {
			system("iptables -t $table -N monitorix_nginx_IN 2>/dev/null");
			system("iptables -t $table -I INPUT -p tcp --sport 1024:65535 --dport $nginx->{port} -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j monitorix_nginx_IN -c 0 0");
			system("iptables -t $table -I OUTPUT -p tcp --sport $nginx->{port} --dport 1024:65535 -m conntrack --ctstate ESTABLISHED,RELATED -j monitorix_nginx_IN -c 0 0");
		}
		if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
			system("ipfw delete $nginx->{rule} 2>/dev/null");
			system("ipfw -q add $nginx->{rule} count tcp from me $nginx->{port} to any");
			system("ipfw -q add $nginx->{rule} count tcp from any to me $nginx->{port}");
		}
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

	my $table = $config->{ip_default_table};
	my $reqs = 0;
	my $tot = 0;
	my $reads = 0;
	my $writes = 0;
	my $waits = 0;
	my $in = 0;
	my $out = 0;

	my $ssl = "";
	$ssl = "ssl_opts => {verify_hostname => 0}"
		if lc($config->{accept_selfsigned_certs}) eq "y";

	my $url;

	if($nginx->{url}) {
		$url = $nginx->{url};
	} else {
		$url = "http://127.0.0.1:" . $nginx->{port} . "/nginx_status";
	}
	my $ua = LWP::UserAgent->new(timeout => 30, $ssl);
	$ua->agent($config->{user_agent_id}) if $config->{user_agent_id} || "";
	my $response = $ua->request(HTTP::Request->new('GET', $url));
	my $rrdata = "N";

	if(!$response->is_success) {
		logger("$myself: ERROR: Unable to connect to '$url'.");
		logger("$myself: " . $response->status_line);
	}

	foreach(split('\n', $response->content)) {
		if(/^Active connections:\s+(\d+)\s*/) {
			$tot = $1;
			next;
		}
		if(/^\s+(\d+)\s+(\d+)\s+(\d+)\s*/) {
			$reqs = $3 - ($config->{nginx_hist}->{'requests'} || 0);
			$reqs = 0 unless $reqs != $3;
			$reqs /= 60;
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
		open(IN, "iptables -t $table -nxvL INPUT |");
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
		open(IN, "iptables -t $table -nxvL OUTPUT |");
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
	my @output;

	my $nginx = $config->{nginx};
	my @rigid = split(',', ($nginx->{rigid} || ""));
	my @limit = split(',', ($nginx->{limit} || ""));
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
	my @warning;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $T = "B";
	my $vlabel = "bytes/s";
	my $n;
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
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "Time   Total  Reading  Writing  Waiting Requests   K$T/s_I   K$T/s_O\n");
		push(@output, "------------------------------------------------------------------ \n");
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
			push(@output, sprintf(" %2d$tf->{tc}  %6d   %6d   %6d   %6d   %6d   %6d   %6d\n", $time, @row));
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

	my $IMG1 = $u . $package . "1." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2 = $u . $package . "2." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3 = $u . $package . "3." . $tf->{when} . ".$imgfmt_lc";
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
			"$IMG_DIR" . "$IMG2z",
			"$IMG_DIR" . "$IMG3z");
	}

	if($title) {
		push(@output, main::graph_header($title, 2));
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td>\n");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG1",
		"--title=$config->{graphs}->{_nginx1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Connections/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
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
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_nginx1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Connections/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
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
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nginx1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "'>\n");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_nginx2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:requests=$rrd:nginx_requests:AVERAGE",
		"CDEF:allvalues=requests",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_nginx2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:requests=$rrd:nginx_requests:AVERAGE",
			"CDEF:allvalues=requests",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nginx2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "'>\n");
		}
	}

	undef(@warning);
	my $pnum;
	if($config->{os} eq "Linux") {
		my $cmd = $nginx->{cmd} || "";
		if(!$cmd || $cmd eq "ss") {
			open(IN, "ss -nl --tcp |");
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
		if($cmd eq "netstat") {
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

	@riglim = @{setup_riglim($rigid[2], $limit[2])};
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
		if(lc($config->{netstats_mode} || "") eq "separated") {
			push(@CDEF, "CDEF:B_out=out,8,*,-1,*");
		} else {
			push(@CDEF, "CDEF:B_out=out,8,*");
		}
	} else {
		push(@CDEF, "CDEF:B_in=in");
		if(lc($config->{netstats_mode} || "") eq "separated") {
			push(@CDEF, "CDEF:B_out=out,-1,*");
		} else {
			push(@CDEF, "CDEF:B_out=out");
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
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG3",
		"--title=$config->{graphs}->{_nginx3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
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
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_nginx3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
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
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nginx3/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "'>\n");
		}
	}

	if($title) {
		push(@output, "    </td>\n");
		push(@output, "    </tr>\n");
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
