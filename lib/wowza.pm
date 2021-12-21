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

package wowza;

use strict;
use warnings;
use Monitorix;
use RRDs;
use base 'LWP::UserAgent';
use XML::Simple;
use Exporter 'import';
our @EXPORT = qw(wowza_init wowza_update wowza_cgi);

sub wowza_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $wowza = $config->{wowza};

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
		if(scalar(@ds) / 130 != scalar(my @il = split(',', $wowza->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @il = split(',', $wowza->{list})) . ") and $rrd (" . scalar(@ds) / 130 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @il = split(',', $wowza->{list})); $n++) {
			push(@tmp, "DS:wms" . $n . "_timerun:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_connt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_conncur:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_conntacc:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_conntrej:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_minbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_moutbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_val01:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_val02:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_val03:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_timerun:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_connt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_conncur:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_conntacc:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_conntrej:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_minbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_moutbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_sesrtsp:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_sessmoo:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_sescupe:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_sesflas:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_sessanj:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_sestot:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_val01:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a0_val02:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_timerun:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_connt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_conncur:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_conntacc:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_conntrej:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_minbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_moutbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_sesrtsp:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_sessmoo:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_sescupe:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_sesflas:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_sessanj:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_sestot:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_val01:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a1_val02:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_timerun:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_connt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_conncur:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_conntacc:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_conntrej:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_minbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_moutbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_sesrtsp:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_sessmoo:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_sescupe:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_sesflas:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_sessanj:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_sestot:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_val01:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a2_val02:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_timerun:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_connt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_conncur:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_conntacc:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_conntrej:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_minbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_moutbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_sesrtsp:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_sessmoo:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_sescupe:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_sesflas:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_sessanj:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_sestot:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_val01:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a3_val02:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_timerun:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_connt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_conncur:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_conntacc:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_conntrej:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_minbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_moutbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_sesrtsp:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_sessmoo:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_sescupe:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_sesflas:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_sessanj:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_sestot:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_val01:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a4_val02:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_timerun:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_connt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_conncur:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_conntacc:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_conntrej:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_minbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_moutbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_sesrtsp:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_sessmoo:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_sescupe:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_sesflas:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_sessanj:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_sestot:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_val01:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a5_val02:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_timerun:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_connt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_conncur:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_conntacc:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_conntrej:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_minbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_moutbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_sesrtsp:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_sessmoo:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_sescupe:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_sesflas:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_sessanj:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_sestot:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_val01:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a6_val02:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_timerun:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_connt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_conncur:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_conntacc:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_conntrej:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_minbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_moutbrt:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_sesrtsp:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_sessmoo:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_sescupe:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_sesflas:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_sessanj:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_sestot:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_val01:GAUGE:120:0:U");
			push(@tmp, "DS:wms" . $n . "_a7_val02:GAUGE:120:0:U");
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

	$config->{wowza_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub get_basic_credentials {
	my ($self, $realm, $url) = @_;
	my $user = "";
	my $pass = "";

	my ($auth) = ($url =~ m/^http:\/\/(\S*)@.*?$/);
	return ($user, $pass) = ($auth =~ m/^(\S+):(\S+)$/) if $auth;
}

sub wowza_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $wowza = $config->{wowza};

	my @ls;
	my @br;

	my $n;
	my $rrdata = "N";

	my $e = 0;
	foreach(my @wl = split(',', $wowza->{list})) {
		my $wls = trim($wl[$e]);
		my $ssl = "";

		$ssl = "ssl_opts => {verify_hostname => 0}"
			if lc($config->{accept_selfsigned_certs}) eq "y";

		my $ua = wowza->new(timeout => 30, $ssl);
		my $response = $ua->get($wls);
		my $data = XMLin($response->content);

		if(!$response->is_success) {
			logger("$myself: ERROR: Unable to connect to '$wls'.");
			logger("$myself: " . $response->status_line);
		}

		# main (VHost) stats
		$rrdata .= ":" . $data->{VHost}->{TimeRunning};
		$rrdata .= ":" . $data->{VHost}->{ConnectionsTotal};
		$rrdata .= ":" . $data->{VHost}->{ConnectionsCurrent};
		$rrdata .= ":" . $data->{VHost}->{ConnectionsTotalAccepted};
		$rrdata .= ":" . $data->{VHost}->{ConnectionsTotalRejected};
		$rrdata .= ":" . $data->{VHost}->{MessagesInBytesRate};
		$rrdata .= ":" . $data->{VHost}->{MessagesOutBytesRate};
		$rrdata .= ":" . "0:0:0";

		# application stats
		#
		# '$data->{VHost}->{Application}' may be a HASH or an ARRAY
		# depending if it has only one duplicate or if it has more than
		# one, respectively. We need to convert it to an array in all
		# cases.
		my @app;
		if(ref($data->{VHost}->{Application}) eq "HASH") {
			$app[0] = $data->{VHost}->{Application};
		} else {
			@app = @{$data->{VHost}->{Application}};
		}

		my $e2 = 0;
		foreach my $an (split(',', $wowza->{desc}->{$wls})) {
			my $found = 0;

			foreach my $entry (@app) {
				my $conntacc = 0;
				my $conntrej = 0;
				my $msginbytes = 0;
				my $msgoutbytes = 0;
				my $str;
				if($entry->{Name} eq trim($an)) {
					$str = $e . $e2 . "conntacc";
					$conntacc = $entry->{ConnectionsTotalAccepted} - ($config->{wowza_hist}->{$str} || 0);
					$conntacc = 0 unless $conntacc != $entry->{ConnectionsTotalAccepted};
					$conntacc /= 60;
					$config->{wowza_hist}->{$str} = $entry->{ConnectionsTotalAccepted};

					$str = $e . $e2 . "conntrej";
					$conntrej = $entry->{ConnectionsTotalRejected} - ($config->{wowza_hist}->{$str} || 0);
					$conntrej = 0 unless $conntrej != $entry->{ConnectionsTotalRejected};
					$conntrej /= 60;
					$config->{wowza_hist}->{$str} = $entry->{ConnectionsTotalRejected};

					$msginbytes = $entry->{MessagesInBytesRate};
					$msgoutbytes = $entry->{MessagesOutBytesRate};

					$rrdata .= ":" . $entry->{TimeRunning};
					$rrdata .= ":" . $entry->{ConnectionsTotal};
					$rrdata .= ":" . $entry->{ConnectionsCurrent};
					$rrdata .= ":" . $conntacc;
					$rrdata .= ":" . $conntrej;
					$rrdata .= ":" . $msginbytes;
					$rrdata .= ":" . $msgoutbytes;
					my $instance;
					if(ref($entry->{ApplicationInstance}) eq "ARRAY") {
						$instance = $entry->{ApplicationInstance}[0];
					} else {
						$instance = $entry->{ApplicationInstance};
					}
					my $stream;
					if(ref($instance->{Stream}) eq "ARRAY") {
						$stream = $instance->{Stream}[0];
					} else {
						$stream = $instance->{Stream};
					}
					$rrdata .= ":" . ($stream->{SessionsRTSP} || 0);
					$rrdata .= ":" . ($stream->{SessionsSmooth} || 0);
					$rrdata .= ":" . ($stream->{SessionsCupertino} || 0);
					$rrdata .= ":" . ($stream->{SessionsFlash} || 0);
					$rrdata .= ":" . ($stream->{SessionsSanJose} || 0);
					$rrdata .= ":" . ($stream->{SessionsTotal} || 0);
					$rrdata .= ":" . "0:0";
					$found = 1;
					last;
				}
			}
			$rrdata .= ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0" if !$found;
			$e2++;
		}
		while($e2 < 8) {
			$rrdata .= ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0";
			$e2++;
		}

		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub wowza_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $wowza = $config->{wowza};
	my @rigid = split(',', ($wowza->{rigid} || ""));
	my @limit = split(',', ($wowza->{limit} || ""));
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
		my $line4;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		for($n = 0; $n < scalar(my @wl = split(',', $wowza->{list})); $n++) {
			my $l = trim($wl[$n]);
			$line1 = " ";
			$line2 .= " ";
			$line3 .= " ";
			$line4 .= "-";
			foreach my $i (split(',', $wowza->{desc}->{$l})) {
				$line1 .= "                               ";
				$line2 .= sprintf(" %30s", trim($i));
				$line3 .= "  Con/s MRate Acc/s Rej/s Strms";
				$line4 .= "-------------------------------";
			}
			if($line1) {
				my $i = length($line1);
				push(@output, sprintf(sprintf("%${i}s", $l)));
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
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc}", $time));
			for($n2 = 0; $n2 < scalar(my @wl = split(',', $wowza->{list})); $n2++) {
				my $ls = trim($wl[$n2]);
				push(@output, " ");
				foreach (split(',', $wowza->{desc}->{$ls})) {
					$from = $n2 * 130 + (10);
					$to = $from + 15;
					my (undef, undef, $conncur, $conntacc, $conntrej, $minbrt, $moutbrt, undef, undef, undef, undef, undef, $sestot) = @$line[$from..$to];
					@row = ($conncur, $conntacc, $conntrej, $minbrt + $moutbrt, $sestot);
					push(@output, sprintf("  %5d %5d %5d %5d %5d", @row));
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

	for($n = 0; $n < scalar(my @wl = split(',', $wowza->{list})); $n++) {
		for($n2 = 1; $n2 <= 5; $n2++) {
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
	foreach my $url (my @wl = split(',', $wowza->{list})) {
		$url = trim($url);
		if($e) {
			push(@output, "   <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}

		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
			"--resolution=60",
			"--start=-1min",
			"AVERAGE");
		$err = RRDs::error;
		push(@output, "ERROR: while fetching $rrd: $err\n") if $err;
		my $line = @$data[0];
		my ($uptime) = @$line[$e * 130];
		my $uptimeline;
		if($RRDs::VERSION > 1.2) {
			$uptimeline = "COMMENT:uptime\\: " . uptime2str($uptime) . "\\c";
		} else {
			$uptimeline = "COMMENT:uptime: " . uptime2str($uptime) . "\\c";
		}

		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		$n = 0;
		foreach my $w (split(',', $wowza->{desc}->{$url})) {
			$w = trim($w);
			$str = sprintf("%-25s", substr($w, 0, 25));
			push(@tmp, "AREA:wms" . $e . "_a$n" . $AC[$n] . ":$str:STACK");
			push(@tmpz, "AREA:wms" . $e . "_a$n" . $AC[$n] . ":$w:STACK");
			push(@tmp, "GPRINT:wms" . $e . "_a$n" . ":LAST: Current\\:%3.0lf");
			push(@tmp, "GPRINT:wms" . $e . "_a$n" . ":AVERAGE:  Average\\:%3.0lf");
			push(@tmp, "GPRINT:wms" . $e . "_a$n" . ":MIN:  Min\\:%3.0lf");
			push(@tmp, "GPRINT:wms" . $e . "_a$n" . ":MAX:  Max\\:%3.0lf\\n");
			$n++;
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
		($width, $height) = split('x', $config->{graph_size}->{main});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 5]",
			"--title=$config->{graphs}->{_wowza1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Connections",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:wms" . $e . "_a0=$rrd:wms" . $e . "_a0_conncur:AVERAGE",
			"DEF:wms" . $e . "_a1=$rrd:wms" . $e . "_a1_conncur:AVERAGE",
			"DEF:wms" . $e . "_a2=$rrd:wms" . $e . "_a2_conncur:AVERAGE",
			"DEF:wms" . $e . "_a3=$rrd:wms" . $e . "_a3_conncur:AVERAGE",
			"DEF:wms" . $e . "_a4=$rrd:wms" . $e . "_a4_conncur:AVERAGE",
			"DEF:wms" . $e . "_a5=$rrd:wms" . $e . "_a5_conncur:AVERAGE",
			"DEF:wms" . $e . "_a6=$rrd:wms" . $e . "_a6_conncur:AVERAGE",
			"DEF:wms" . $e . "_a7=$rrd:wms" . $e . "_a7_conncur:AVERAGE",
			"CDEF:allvalues=wms" . $e . "_a0,wms" . $e . "_a1,wms" . $e . "_a2,wms" . $e . "_a3,wms" . $e . "_a4,wms" . $e . "_a5,wms" . $e . "_a6,wms" . $e . "_a7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp,
			"COMMENT: \\n",
			$uptimeline);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 5]",
				"--title=$config->{graphs}->{_wowza1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Connections",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:wms" . $e . "_a0=$rrd:wms" . $e . "_a0_conncur:AVERAGE",
				"DEF:wms" . $e . "_a1=$rrd:wms" . $e . "_a1_conncur:AVERAGE",
				"DEF:wms" . $e . "_a2=$rrd:wms" . $e . "_a2_conncur:AVERAGE",
				"DEF:wms" . $e . "_a3=$rrd:wms" . $e . "_a3_conncur:AVERAGE",
				"DEF:wms" . $e . "_a4=$rrd:wms" . $e . "_a4_conncur:AVERAGE",
				"DEF:wms" . $e . "_a5=$rrd:wms" . $e . "_a5_conncur:AVERAGE",
				"DEF:wms" . $e . "_a6=$rrd:wms" . $e . "_a6_conncur:AVERAGE",
				"DEF:wms" . $e . "_a7=$rrd:wms" . $e . "_a7_conncur:AVERAGE",
				"CDEF:allvalues=wms" . $e . "_a0,wms" . $e . "_a1,wms" . $e . "_a2,wms" . $e . "_a3,wms" . $e . "_a4,wms" . $e . "_a5,wms" . $e . "_a6,wms" . $e . "_a7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 5]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /wowza$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 5] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 5] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		$n = 0;
		foreach my $w (split(',', $wowza->{desc}->{$url})) {
			$w = trim($w);
			$str = sprintf("%-25s", substr($w, 0, 25));
			push(@tmp, "LINE2:B_wms" . $e . "_a$n" . $LC[$n] . ":$str");
			push(@tmpz, "LINE2:B_wms" . $e . "_a$n" . $LC[$n] . ":$w");
			push(@tmp, "GPRINT:K_wms" . $e . "_a$n" . ":LAST: Cur\\:%3.0lfK$T/s");
			push(@tmp, "GPRINT:K_wms" . $e . "_a$n" . ":AVERAGE: Avg\\:%3.0lfK$T/s");
			push(@tmp, "GPRINT:K_wms" . $e . "_a$n" . ":MIN: Min\\:%3.0lfK$T/s");
			push(@tmp, "GPRINT:K_wms" . $e . "_a$n" . ":MAX: Max\\:%3.0lfK$T/s\\n");
			if(lc($config->{netstats_in_bps}) eq "y") {
				push(@CDEF, "CDEF:wms" . $e . "_a$n=wms" . $e . "_a$n" . "i,wms" . $e . "_a$n" . "o,+");
				push(@CDEF, "CDEF:B_wms" . $e . "_a$n=wms" . $e . "_a$n,8,*");
			} else {
				push(@CDEF, "CDEF:wms" . $e . "_a$n=wms" . $e . "_a$n" . "i,wms" . $e . "_a$n" . "o,+");
				push(@CDEF, "CDEF:B_wms" . $e . "_a$n=wms" . $e . "_a$n");
			}
			push(@CDEF, "CDEF:K_wms" . $e . "_a$n=B_wms" . $e . "_a$n,1024,/");
			$n++;
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{main});
		$pic = $rrd{$version}->("$IMG_DIR" . $IMG[$e * 5 + 1],
			"--title=$config->{graphs}->{_wowza2}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:wms" . $e . "_a0i=$rrd:wms" . $e . "_a0_minbrt:AVERAGE",
			"DEF:wms" . $e . "_a0o=$rrd:wms" . $e . "_a0_moutbrt:AVERAGE",
			"DEF:wms" . $e . "_a1i=$rrd:wms" . $e . "_a1_minbrt:AVERAGE",
			"DEF:wms" . $e . "_a1o=$rrd:wms" . $e . "_a1_moutbrt:AVERAGE",
			"DEF:wms" . $e . "_a2i=$rrd:wms" . $e . "_a2_minbrt:AVERAGE",
			"DEF:wms" . $e . "_a2o=$rrd:wms" . $e . "_a2_moutbrt:AVERAGE",
			"DEF:wms" . $e . "_a3i=$rrd:wms" . $e . "_a3_minbrt:AVERAGE",
			"DEF:wms" . $e . "_a3o=$rrd:wms" . $e . "_a3_moutbrt:AVERAGE",
			"DEF:wms" . $e . "_a4i=$rrd:wms" . $e . "_a4_minbrt:AVERAGE",
			"DEF:wms" . $e . "_a4o=$rrd:wms" . $e . "_a4_moutbrt:AVERAGE",
			"DEF:wms" . $e . "_a5i=$rrd:wms" . $e . "_a5_minbrt:AVERAGE",
			"DEF:wms" . $e . "_a5o=$rrd:wms" . $e . "_a5_moutbrt:AVERAGE",
			"DEF:wms" . $e . "_a6i=$rrd:wms" . $e . "_a6_minbrt:AVERAGE",
			"DEF:wms" . $e . "_a6o=$rrd:wms" . $e . "_a6_moutbrt:AVERAGE",
			"DEF:wms" . $e . "_a7i=$rrd:wms" . $e . "_a7_minbrt:AVERAGE",
			"DEF:wms" . $e . "_a7o=$rrd:wms" . $e . "_a7_moutbrt:AVERAGE",
			"CDEF:allvalues=wms" . $e . "_a0i,wms" . $e . "_a0o,wms" . $e . "_a1i,wms" . $e . "_a1o,wms" . $e . "_a2i,wms" . $e . "_a2o,wms" . $e . "_a3i,wms" . $e . "_a3o,wms" . $e . "_a4i,wms" . $e . "_a4o,wms" . $e . "_a5i,wms" . $e . "_a5o,wms" . $e . "_a6i,wms" . $e . "_a6o,wms" . $e . "_a7i,wms" . $e . "_a7o,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . $IMG[$e * 5 + 1] . ": $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . $IMGz[$e * 5 + 1],
				"--title=$config->{graphs}->{_wowza2}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:wms" . $e . "_a0i=$rrd:wms" . $e . "_a0_minbrt:AVERAGE",
				"DEF:wms" . $e . "_a0o=$rrd:wms" . $e . "_a0_moutbrt:AVERAGE",
				"DEF:wms" . $e . "_a1i=$rrd:wms" . $e . "_a1_minbrt:AVERAGE",
				"DEF:wms" . $e . "_a1o=$rrd:wms" . $e . "_a1_moutbrt:AVERAGE",
				"DEF:wms" . $e . "_a2i=$rrd:wms" . $e . "_a2_minbrt:AVERAGE",
				"DEF:wms" . $e . "_a2o=$rrd:wms" . $e . "_a2_moutbrt:AVERAGE",
				"DEF:wms" . $e . "_a3i=$rrd:wms" . $e . "_a3_minbrt:AVERAGE",
				"DEF:wms" . $e . "_a3o=$rrd:wms" . $e . "_a3_moutbrt:AVERAGE",
				"DEF:wms" . $e . "_a4i=$rrd:wms" . $e . "_a4_minbrt:AVERAGE",
				"DEF:wms" . $e . "_a4o=$rrd:wms" . $e . "_a4_moutbrt:AVERAGE",
				"DEF:wms" . $e . "_a5i=$rrd:wms" . $e . "_a5_minbrt:AVERAGE",
				"DEF:wms" . $e . "_a5o=$rrd:wms" . $e . "_a5_moutbrt:AVERAGE",
				"DEF:wms" . $e . "_a6i=$rrd:wms" . $e . "_a6_minbrt:AVERAGE",
				"DEF:wms" . $e . "_a6o=$rrd:wms" . $e . "_a6_moutbrt:AVERAGE",
				"DEF:wms" . $e . "_a7i=$rrd:wms" . $e . "_a7_minbrt:AVERAGE",
				"DEF:wms" . $e . "_a7o=$rrd:wms" . $e . "_a7_moutbrt:AVERAGE",
				"CDEF:allvalues=wms" . $e . "_a0i,wms" . $e . "_a0o,wms" . $e . "_a1i,wms" . $e . "_a1o,wms" . $e . "_a2i,wms" . $e . "_a2o,wms" . $e . "_a3i,wms" . $e . "_a3o,wms" . $e . "_a4i,wms" . $e . "_a4o,wms" . $e . "_a5i,wms" . $e . "_a5o,wms" . $e . "_a6i,wms" . $e . "_a6o,wms" . $e . "_a7i,wms" . $e . "_a7o,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . $IMGz[$e * 5 + 1] . ": $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /wowza$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 5 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 5 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 1] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}

		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		$n = 0;
		foreach my $w (split(',', $wowza->{desc}->{$url})) {
			$w = trim($w);
			$str = sprintf("%-20s", substr($w, 0, 20));
			push(@tmp, "LINE2:wms" . $e . "_a$n" . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:wms" . $e . "_a$n" . ":LAST: Current\\:%6.2lf\\n");
			push(@tmpz, "LINE2:wms" . $e . "_a$n" . $LC[$n] . ":$w");
			$n++;
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . $IMG[$e * 5 + 2],
			"--title=$config->{graphs}->{_wowza3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Connections/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:wms" . $e . "_a0=$rrd:wms" . $e . "_a0_conntacc:AVERAGE",
			"DEF:wms" . $e . "_a1=$rrd:wms" . $e . "_a1_conntacc:AVERAGE",
			"DEF:wms" . $e . "_a2=$rrd:wms" . $e . "_a2_conntacc:AVERAGE",
			"DEF:wms" . $e . "_a3=$rrd:wms" . $e . "_a3_conntacc:AVERAGE",
			"DEF:wms" . $e . "_a4=$rrd:wms" . $e . "_a4_conntacc:AVERAGE",
			"DEF:wms" . $e . "_a5=$rrd:wms" . $e . "_a5_conntacc:AVERAGE",
			"DEF:wms" . $e . "_a6=$rrd:wms" . $e . "_a6_conntacc:AVERAGE",
			"DEF:wms" . $e . "_a7=$rrd:wms" . $e . "_a7_conntacc:AVERAGE",
			"CDEF:allvalues=wms" . $e . "_a0,wms" . $e . "_a1,wms" . $e . "_a2,wms" . $e . "_a3,wms" . $e . "_a4,wms" . $e . "_a5,wms" . $e . "_a6,wms" . $e . "_a7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . $IMG[$e * 5 + 2] . ": $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . $IMGz[$e * 5 + 2],
				"--title=$config->{graphs}->{_wowza3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Connections/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:wms" . $e . "_a0=$rrd:wms" . $e . "_a0_conntacc:AVERAGE",
				"DEF:wms" . $e . "_a1=$rrd:wms" . $e . "_a1_conntacc:AVERAGE",
				"DEF:wms" . $e . "_a2=$rrd:wms" . $e . "_a2_conntacc:AVERAGE",
				"DEF:wms" . $e . "_a3=$rrd:wms" . $e . "_a3_conntacc:AVERAGE",
				"DEF:wms" . $e . "_a4=$rrd:wms" . $e . "_a4_conntacc:AVERAGE",
				"DEF:wms" . $e . "_a5=$rrd:wms" . $e . "_a5_conntacc:AVERAGE",
				"DEF:wms" . $e . "_a6=$rrd:wms" . $e . "_a6_conntacc:AVERAGE",
				"DEF:wms" . $e . "_a7=$rrd:wms" . $e . "_a7_conntacc:AVERAGE",
				"CDEF:allvalues=wms" . $e . "_a0,wms" . $e . "_a1,wms" . $e . "_a2,wms" . $e . "_a3,wms" . $e . "_a4,wms" . $e . "_a5,wms" . $e . "_a6,wms" . $e . "_a7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . $IMGz[$e * 5 + 2] . ": $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /wowza$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 5 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 5 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 2] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[3], $limit[3])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		$n = 0;
		foreach my $w (split(',', $wowza->{desc}->{$url})) {
			$w = trim($w);
			$str = sprintf("%-20s", substr($w, 0, 20));
			push(@tmp, "LINE2:wms" . $e . "_a$n" . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:wms" . $e . "_a$n" . ":LAST: Current\\:%6.2lf\\n");
			push(@tmpz, "LINE2:wms" . $e . "_a$n" . $LC[$n] . ":$w");
			$n++;
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . $IMG[$e * 5 + 3],
			"--title=$config->{graphs}->{_wowza4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Connections/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:wms" . $e . "_a0=$rrd:wms" . $e . "_a0_conntrej:AVERAGE",
			"DEF:wms" . $e . "_a1=$rrd:wms" . $e . "_a1_conntrej:AVERAGE",
			"DEF:wms" . $e . "_a2=$rrd:wms" . $e . "_a2_conntrej:AVERAGE",
			"DEF:wms" . $e . "_a3=$rrd:wms" . $e . "_a3_conntrej:AVERAGE",
			"DEF:wms" . $e . "_a4=$rrd:wms" . $e . "_a4_conntrej:AVERAGE",
			"DEF:wms" . $e . "_a5=$rrd:wms" . $e . "_a5_conntrej:AVERAGE",
			"DEF:wms" . $e . "_a6=$rrd:wms" . $e . "_a6_conntrej:AVERAGE",
			"DEF:wms" . $e . "_a7=$rrd:wms" . $e . "_a7_conntrej:AVERAGE",
			"CDEF:allvalues=wms" . $e . "_a0,wms" . $e . "_a1,wms" . $e . "_a2,wms" . $e . "_a3,wms" . $e . "_a4,wms" . $e . "_a5,wms" . $e . "_a6,wms" . $e . "_a7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . $IMG[$e * 5 + 3] . ": $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . $IMGz[$e * 5 + 3],
				"--title=$config->{graphs}->{_wowza4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Connections/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:wms" . $e . "_a0=$rrd:wms" . $e . "_a0_conntrej:AVERAGE",
				"DEF:wms" . $e . "_a1=$rrd:wms" . $e . "_a1_conntrej:AVERAGE",
				"DEF:wms" . $e . "_a2=$rrd:wms" . $e . "_a2_conntrej:AVERAGE",
				"DEF:wms" . $e . "_a3=$rrd:wms" . $e . "_a3_conntrej:AVERAGE",
				"DEF:wms" . $e . "_a4=$rrd:wms" . $e . "_a4_conntrej:AVERAGE",
				"DEF:wms" . $e . "_a5=$rrd:wms" . $e . "_a5_conntrej:AVERAGE",
				"DEF:wms" . $e . "_a6=$rrd:wms" . $e . "_a6_conntrej:AVERAGE",
				"DEF:wms" . $e . "_a7=$rrd:wms" . $e . "_a7_conntrej:AVERAGE",
				"CDEF:allvalues=wms" . $e . "_a0,wms" . $e . "_a1,wms" . $e . "_a2,wms" . $e . "_a3,wms" . $e . "_a4,wms" . $e . "_a5,wms" . $e . "_a6,wms" . $e . "_a7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . $IMGz[$e * 5 + 3] . ": $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /wowza$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 5 + 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 5 + 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 3] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[4], $limit[4])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		$n = 0;
		foreach my $w (split(',', $wowza->{desc}->{$url})) {
			$w = trim($w);
			$str = sprintf("%-20s", substr($w, 0, 20));
			push(@tmp, "LINE2:wms" . $e . "_a$n" . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:wms" . $e . "_a$n" . ":LAST: Current\\:%3.0lf\\n");
			push(@tmpz, "LINE2:wms" . $e . "_a$n" . $LC[$n] . ":$w");
			$n++;
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . $IMG[$e * 5 + 4],
			"--title=$config->{graphs}->{_wowza5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Sessions",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:wms" . $e . "_a0=$rrd:wms" . $e . "_a0_sestot:AVERAGE",
			"DEF:wms" . $e . "_a1=$rrd:wms" . $e . "_a1_sestot:AVERAGE",
			"DEF:wms" . $e . "_a2=$rrd:wms" . $e . "_a2_sestot:AVERAGE",
			"DEF:wms" . $e . "_a3=$rrd:wms" . $e . "_a3_sestot:AVERAGE",
			"DEF:wms" . $e . "_a4=$rrd:wms" . $e . "_a4_sestot:AVERAGE",
			"DEF:wms" . $e . "_a5=$rrd:wms" . $e . "_a5_sestot:AVERAGE",
			"DEF:wms" . $e . "_a6=$rrd:wms" . $e . "_a6_sestot:AVERAGE",
			"DEF:wms" . $e . "_a7=$rrd:wms" . $e . "_a7_sestot:AVERAGE",
			"CDEF:allvalues=wms" . $e . "_a0,wms" . $e . "_a1,wms" . $e . "_a2,wms" . $e . "_a3,wms" . $e . "_a4,wms" . $e . "_a5,wms" . $e . "_a6,wms" . $e . "_a7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . $IMG[$e * 5 + 4] . ": $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . $IMGz[$e * 5 + 4],
				"--title=$config->{graphs}->{_wowza5}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Sessions",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:wms" . $e . "_a0=$rrd:wms" . $e . "_a0_sestot:AVERAGE",
				"DEF:wms" . $e . "_a1=$rrd:wms" . $e . "_a1_sestot:AVERAGE",
				"DEF:wms" . $e . "_a2=$rrd:wms" . $e . "_a2_sestot:AVERAGE",
				"DEF:wms" . $e . "_a3=$rrd:wms" . $e . "_a3_sestot:AVERAGE",
				"DEF:wms" . $e . "_a4=$rrd:wms" . $e . "_a4_sestot:AVERAGE",
				"DEF:wms" . $e . "_a5=$rrd:wms" . $e . "_a5_sestot:AVERAGE",
				"DEF:wms" . $e . "_a6=$rrd:wms" . $e . "_a6_sestot:AVERAGE",
				"DEF:wms" . $e . "_a7=$rrd:wms" . $e . "_a7_sestot:AVERAGE",
				"CDEF:allvalues=wms" . $e . "_a0,wms" . $e . "_a1,wms" . $e . "_a2,wms" . $e . "_a3,wms" . $e . "_a4,wms" . $e . "_a5,wms" . $e . "_a6,wms" . $e . "_a7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . $IMGz[$e * 5 + 4] . ": $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /wowza$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 5 + 4] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 4] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 5 + 4] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 4] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 5 + 4] . "'>\n");
			}
		}

		# remove authentication information from the URL
		my ($auth) = ($url =~ m/^http:\/\/(\S*)@.*?$/);
		$url =~ s/$auth@// if $auth;

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
