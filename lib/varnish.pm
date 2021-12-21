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

package varnish;

use strict;
use warnings;
use Monitorix;
use RRDs;
use IO::Socket;
use Exporter 'import';
our @EXPORT = qw(varnish_init varnish_update varnish_cgi);

sub varnish_init {
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
		push(@tmp, "DS:varn" . "0" . "_cconn:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_cdrop:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_creq:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_chit:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_chitp:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_cmiss:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_bconn:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_bunhe:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_bbusy:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_bfail:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_breus:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_btool:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_brecy:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_bretr:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_nwcre:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_nwfai:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_nwmax:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_nwque:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_nwdro:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_nlnuk:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_nlmov:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_nsob:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_nsoc:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_nsoh:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_nswl:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_hdrb:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_bodb:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_val01:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_val02:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_val03:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_val04:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_val05:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_val06:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_val07:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_val08:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_val09:GAUGE:120:0:U");
		push(@tmp, "DS:varn" . "0" . "_val10:GAUGE:120:0:U");
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

	$config->{varnish_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub varnish_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $varnish = $config->{varnish};

	my $n;
	my $rrdata = "N";

	my $cconn = 0;
	my $cdrop = 0;
	my $creq = 0;
	my $chit = 0;
	my $chitp = 0;
	my $cmiss = 0;
	my $bconn = 0;
	my $bunhe = 0;
	my $bbusy = 0;
	my $bfail = 0;
	my $breus = 0;
	my $btool = 0;
	my $brecy = 0;
	my $bretr = 0;
	my $nwcre = 0;
	my $nwfai = 0;
	my $nwmax = 0;
	my $nwque = 0;
	my $nwdro = 0;
	my $nlnuk = 0;
	my $nlmov = 0;
	my $nsob = 0;
	my $nsoc = 0;
	my $nsoh = 0;
	my $nswl = 0;
	my $hdrb = 0;
	my $bodb = 0;

	my $e = 0;
	my $str;

	open(IN, "varnishstat -1 |");
	while(<IN>) {
		if(/^(client_conn|MAIN.sess_conn)\s+(\d+)\s+/) {
			$str = $e . "cconn";
			$cconn = $2 - ($config->{varnish_hist}->{$str} || 0);
			$cconn = 0 unless $cconn != $2;
			$cconn /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(client_drop|MAIN.sess_drop)\s+(\d+)\s+/) {
			$str = $e . "cdrop";
			$cdrop = $2 - ($config->{varnish_hist}->{$str} || 0);
			$cdrop = 0 unless $cdrop != $2;
			$cdrop /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(client_req|MAIN.client_req)\s+(\d+)\s+/) {
			$str = $e . "creq";
			$creq = $2 - ($config->{varnish_hist}->{$str} || 0);
			$creq = 0 unless $creq != $2;
			$creq /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(cache_hit|MAIN.cache_hit)\s+(\d+)\s+/) {
			$str = $e . "chit";
			$chit = $2 - ($config->{varnish_hist}->{$str} || 0);
			$chit = 0 unless $chit != $2;
			$chit /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(cache_hitpass|MAIN.cache_hitpass)\s+(\d+)\s+/) {
			$str = $e . "chitp";
			$chitp = $2 - ($config->{varnish_hist}->{$str} || 0);
			$chitp = 0 unless $chitp != $2;
			$chitp /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(cache_miss|MAIN.cache_miss)\s+(\d+)\s+/) {
			$str = $e . "cmiss";
			$cmiss = $2 - ($config->{varnish_hist}->{$str} || 0);
			$cmiss = 0 unless $cmiss != $2;
			$cmiss /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(backend_conn|MAIN.backend_conn)\s+(\d+)\s+/) {
			$str = $e . "bconn";
			$bconn = $2 - ($config->{varnish_hist}->{$str} || 0);
			$bconn = 0 unless $bconn != $2;
			$bconn /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(backend_unhealthy|MAIN.backend_unhealthy)\s+(\d+)\s+/) {
			$str = $e . "bunhe";
			$bunhe = $2 - ($config->{varnish_hist}->{$str} || 0);
			$bunhe = 0 unless $bunhe != $2;
			$bunhe /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(backend_busy|MAIN.backend_busy)\s+(\d+)\s+/) {
			$str = $e . "bbusy";
			$bbusy = $2 - ($config->{varnish_hist}->{$str} || 0);
			$bbusy = 0 unless $bbusy != $2;
			$bbusy /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(backend_fail|MAIN.backend_fail)\s+(\d+)\s+/) {
			$str = $e . "bfail";
			$bfail = $2 - ($config->{varnish_hist}->{$str} || 0);
			$bfail = 0 unless $bfail != $2;
			$bfail /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(backend_reuse|MAIN.backend_reuse)\s+(\d+)\s+/) {
			$str = $e . "breus";
			$breus = $2 - ($config->{varnish_hist}->{$str} || 0);
			$breus = 0 unless $breus != $2;
			$breus /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(backend_toolate|MAIN.backend_toolate)\s+(\d+)\s+/) {
			$str = $e . "btool";
			$btool = $2 - ($config->{varnish_hist}->{$str} || 0);
			$btool = 0 unless $btool != $2;
			$btool /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(backend_recycle|MAIN.backend_recycle)\s+(\d+)\s+/) {
			$str = $e . "brecy";
			$brecy = $2 - ($config->{varnish_hist}->{$str} || 0);
			$brecy = 0 unless $brecy != $2;
			$brecy /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(backend_retry|MAIN.backend_retry)\s+(\d+)\s+/) {
			$str = $e . "bretr";
			$bretr = $2 - ($config->{varnish_hist}->{$str} || 0);
			$bretr = 0 unless $bretr != $2;
			$bretr /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^n_wrk_create\s+(\d+)\s+/) {
			$str = $e . "nwcre";
			$nwcre = $1 - ($config->{varnish_hist}->{$str} || 0);
			$nwcre = 0 unless $nwcre != $1;
			$nwcre /= 60;
			$config->{varnish_hist}->{$str} = $1;
		}
		if(/^n_wrk_failed\s+(\d+)\s+/) {
			$str = $e . "nwfai";
			$nwfai = $1 - ($config->{varnish_hist}->{$str} || 0);
			$nwfai = 0 unless $nwfai != $1;
			$nwfai /= 60;
			$config->{varnish_hist}->{$str} = $1;
		}
		if(/^n_wrk_max\s+(\d+)\s+/) {
			$str = $e . "nwmax";
			$nwmax = $1 - ($config->{varnish_hist}->{$str} || 0);
			$nwmax = 0 unless $nwmax != $1;
			$nwmax /= 60;
			$config->{varnish_hist}->{$str} = $1;
		}
		if(/^n_wrk_queued\s+(\d+)\s+/) {
			$str = $e . "nwque";
			$nwque = $1 - ($config->{varnish_hist}->{$str} || 0);
			$nwque = 0 unless $nwque != $1;
			$nwque /= 60;
			$config->{varnish_hist}->{$str} = $1;
		}
		if(/^n_wrk_drop\s+(\d+)\s+/) {
			$str = $e . "nwdro";
			$nwdro = $1 - ($config->{varnish_hist}->{$str} || 0);
			$nwdro = 0 unless $nwdro != $1;
			$nwdro /= 60;
			$config->{varnish_hist}->{$str} = $1;
		}
		if(/^(n_lru_nuked|MAIN.n_lru_nuked)\s+(\d+)\s+/) {
			$str = $e . "nlnuk";
			$nlnuk = $2 - ($config->{varnish_hist}->{$str} || 0);
			$nlnuk = 0 unless $nlnuk != $2;
			$nlnuk /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(n_lru_moved|MAIN.n_lru_moved)\s+(\d+)\s+/) {
			$str = $e . "nlmov";
			$nlmov = $2 - ($config->{varnish_hist}->{$str} || 0);
			$nlmov = 0 unless $nlmov != $2;
			$nlmov /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(MAIN.n_object|n_object)\s+(\d+)\s+/) {
			$nsob = $2;
		}
		if(/^(n_objectcore|MAIN.n_objectcore)\s+(\d+)\s+/) {
			$nsoc = $2;
		}
		if(/^(n_objecthead|MAIN.n_objecthead)\s+(\d+)\s+/) {
			$nsoh = $2;
		}
		if(/^(n_waitinglist|MAIN.n_waitinglist)\s+(\d+)\s+/) {
			$nswl = $2;
		}
		if(/^(s_hdrbytes|MAIN.s_resp_hdrbytes)\s+(\d+)\s+/) {
			$str = $e . "hdrb";
			$hdrb = $2 - ($config->{varnish_hist}->{$str} || 0);
			$hdrb = 0 unless $hdrb != $2;
			$hdrb /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}
		if(/^(s_bodybytes|MAIN.s_resp_bodybytes)\s+(\d+)\s+/) {
			$str = $e . "bodb";
			$bodb = $2 - ($config->{varnish_hist}->{$str} || 0);
			$bodb = 0 unless $bodb != $2;
			$bodb /= 60;
			$config->{varnish_hist}->{$str} = $2;
		}

	}
	close(IN);
	$rrdata .= ":$cconn:$cdrop:$creq:$chit:$chitp:$cmiss:$bconn:$bunhe:$bbusy:$bfail:$breus:$btool:$brecy:$bretr:$nwcre:$nwfai:$nwmax:$nwque:$nwdro:$nlnuk:$nlmov:$nsob:$nsoc:$nsoh:$nswl:$hdrb:$bodb:0:0:0:0:0:0:0:0:0:0";

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub varnish_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $varnish = $config->{varnish};
	my @rigid = split(',', ($varnish->{rigid} || ""));
	my @limit = split(',', ($varnish->{limit} || ""));
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
	my @tmp;
	my @tmpz;
	my @CDEF;
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
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		$line1 = "    Cli.Conn Cli.Drop Cli.Reqs Cac.Hits Cac.HitP Cac.Miss Bac.Conn Bac.Unhe Bac.Busy Bac.Fail Bac.Reus Bac.Tool Bac.Recy Bac.Retr N.W.Crea N.W.FAil  N.W.Max N.W.Queu N.W.Drop N.L.Nuke N.L.Move N.S.Obje N.S.ObjC N.S.ObjH N.S.Wait Bytes_Hdr Bytes_Bdy";
		$line2 = "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
		push(@output, "\n");
		push(@output, "Time$line1\n");
		push(@output, "----$line2 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc}", $time));
			undef(@row);
			my ($cconn, $cdrop, $creq, $chit, $chitp, $cmiss, $bconn, $bunhe, $bbusy, $bfail, $breus, $btool, $brecy, $bretr, $nwcre, $nwfai, $nwmax, $nwque, $nwdro, $nlnuk, $nlmov, $nsob, $nsoc, $nsoh, $nswl, $hdrb, $bodb) = @$line[0..37];
			push(@output, sprintf("    %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8d %8d %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %9d %9d", $cconn || 0, $cdrop || 0, $creq || 0, $chit || 0, $chitp || 0, $cmiss || 0, $bconn || 0, $bunhe || 0, $bbusy || 0, $bfail || 0, $breus || 0, $btool || 0, $brecy || 0, $bretr || 0, $nwcre || 0, $nwfai || 0, $nwmax || 0, $nwque || 0, $nwdro || 0, $nlnuk || 0, $nlmov || 0, $nsob || 0, $nsoc || 0, $nsoh || 0, $nswl || 0, $hdrb || 0, $bodb || 0));
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

	my $IMG1 = $u . $package . "1." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2 = $u . $package . "2." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3 = $u . $package . "3." . $tf->{when} . ".$imgfmt_lc";
	my $IMG4 = $u . $package . "4." . $tf->{when} . ".$imgfmt_lc";
	my $IMG5 = $u . $package . "5." . $tf->{when} . ".$imgfmt_lc";
	my $IMG6 = $u . $package . "6." . $tf->{when} . ".$imgfmt_lc";
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG4z = $u . $package . "4z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG5z = $u . $package . "5z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG6z = $u . $package . "6z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3",
		"$IMG_DIR" . "$IMG4",
		"$IMG_DIR" . "$IMG5",
		"$IMG_DIR" . "$IMG6");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
			"$IMG_DIR" . "$IMG2z",
			"$IMG_DIR" . "$IMG3z",
			"$IMG_DIR" . "$IMG4z",
			"$IMG_DIR" . "$IMG5z",
			"$IMG_DIR" . "$IMG6z");
	}

	my $uptimeline = 0;
	open(IN, "varnishstat -1 |");
	while(<IN>) {
		if(/^uptime\s+(\d+)\s+/) {
			$uptimeline = $1;
			last;
		}
	}
	close(IN);
	if($RRDs::VERSION > 1.2) {
		$uptimeline = "COMMENT:uptime\\: " . uptime2str(trim($uptimeline)) . "\\c";
	} else {
		$uptimeline = "COMMENT:uptime: " . uptime2str(trim($uptimeline)) . "\\c";
	}

	if($title) {
		push(@output, main::graph_header($title, 2));
		push(@output, "    <tr>\n");
		push(@output, "    <td class='td-valign-top'>\n");
	}

	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	push(@tmp, "LINE2:nwcre#44EE44:Worker threads created");
	push(@tmp, "GPRINT:nwcre:LAST:Current\\: %4.1lf");
	push(@tmp, "GPRINT:nwcre:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:nwcre:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:nwcre:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:nwfai#448844:Worker threads failed");
	push(@tmp, "GPRINT:nwfai:LAST: Current\\: %4.1lf");
	push(@tmp, "GPRINT:nwfai:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:nwfai:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:nwfai:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:nwmax#44EEEE:Worker threads limited");
	push(@tmp, "GPRINT:nwmax:LAST:Current\\: %4.1lf");
	push(@tmp, "GPRINT:nwmax:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:nwmax:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:nwmax:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:nwque#4444EE:Queued work requests");
	push(@tmp, "GPRINT:nwque:LAST:  Current\\: %4.1lf");
	push(@tmp, "GPRINT:nwque:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:nwque:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:nwque:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:nwdro#EE44EE:Dropped work requests");
	push(@tmp, "GPRINT:nwdro:LAST: Current\\: %4.1lf");
	push(@tmp, "GPRINT:nwdro:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:nwdro:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:nwdro:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:nlnuk#EE4444:LRU nuked objects");
	push(@tmp, "GPRINT:nlnuk:LAST:     Current\\: %4.1lf");
	push(@tmp, "GPRINT:nlnuk:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:nlnuk:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:nlnuk:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:nlmov#EEEE44:LRU moved objects");
	push(@tmp, "GPRINT:nlmov:LAST:     Current\\: %4.1lf");
	push(@tmp, "GPRINT:nlmov:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:nlmov:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:nlmov:MAX:  Max\\: %4.1lf\\n");
	push(@tmpz, "LINE2:nwcre#44EE44:Worker threads created");
	push(@tmpz, "LINE2:nwfai#448844:Worker threads failed");
	push(@tmpz, "LINE2:nwmax#44EEEE:Worker threads limited");
	push(@tmpz, "LINE2:nwque#4444EE:Queued work requests");
	push(@tmpz, "LINE2:nwdro#EE44EE:Dropped work requests");
	push(@tmpz, "LINE2:nlnuk#EE4444:LRU nuked objects");
	push(@tmpz, "LINE2:nlmov#EEEE44:LRU moved objects");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG1",
		"--title=$config->{graphs}->{_varnish1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Values/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:nwcre=$rrd:varn0" . "_nwcre:AVERAGE",
		"DEF:nwfai=$rrd:varn0" . "_nwfai:AVERAGE",
		"DEF:nwmax=$rrd:varn0" . "_nwmax:AVERAGE",
		"DEF:nwque=$rrd:varn0" . "_nwque:AVERAGE",
		"DEF:nwdro=$rrd:varn0" . "_nwdro:AVERAGE",
		"DEF:nlnuk=$rrd:varn0" . "_nlnuk:AVERAGE",
		"DEF:nlmov=$rrd:varn0" . "_nlmov:AVERAGE",
		"CDEF:allvalues=nwcre,nwfai,nwmax,nwque,nwdro,nlnuk,nlmov,+,+,+,+,+,+",
		@CDEF,
		@tmp,
		"COMMENT: \\n",
		$uptimeline);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_varnish1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Values/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:nwcre=$rrd:varn0" . "_nwcre:AVERAGE",
			"DEF:nwfai=$rrd:varn0" . "_nwfai:AVERAGE",
			"DEF:nwmax=$rrd:varn0" . "_nwmax:AVERAGE",
			"DEF:nwque=$rrd:varn0" . "_nwque:AVERAGE",
			"DEF:nwdro=$rrd:varn0" . "_nwdro:AVERAGE",
			"DEF:nlnuk=$rrd:varn0" . "_nlnuk:AVERAGE",
			"DEF:nlmov=$rrd:varn0" . "_nlmov:AVERAGE",
			"CDEF:allvalues=nwcre,nwfai,nwmax,nwque,nwdro,nlnuk,nlmov,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /varnish1/)) {
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

	@riglim = @{setup_riglim($rigid[1], $limit[1])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:bconn#44EEEE:Conn. success");
	push(@tmp, "GPRINT:bconn:LAST:         Current\\: %4.1lf");
	push(@tmp, "GPRINT:bconn:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:bconn:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:bconn:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:bunhe#4444EE:Conn. not attempted");
	push(@tmp, "GPRINT:bunhe:LAST:   Current\\: %4.1lf");
	push(@tmp, "GPRINT:bunhe:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:bunhe:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:bunhe:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:bbusy#EEEE44:Too many connections");
	push(@tmp, "GPRINT:bbusy:LAST:  Current\\: %4.1lf");
	push(@tmp, "GPRINT:bbusy:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:bbusy:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:bbusy:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:bfail#FFA500:Conn. failures");
	push(@tmp, "GPRINT:bfail:LAST:        Current\\: %4.1lf");
	push(@tmp, "GPRINT:bfail:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:bfail:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:bfail:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:breus#EE4444:Conn. reuses");
	push(@tmp, "GPRINT:breus:LAST:          Current\\: %4.1lf");
	push(@tmp, "GPRINT:breus:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:breus:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:breus:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:btool#EE44EE:Conn. was closed");
	push(@tmp, "GPRINT:btool:LAST:      Current\\: %4.1lf");
	push(@tmp, "GPRINT:btool:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:btool:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:btool:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:brecy#963C74:Conn. recycles");
	push(@tmp, "GPRINT:brecy:LAST:        Current\\: %4.1lf");
	push(@tmp, "GPRINT:brecy:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:brecy:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:brecy:MAX:  Max\\: %4.1lf\\n");
	push(@tmp, "LINE2:bretr#888888:Conn. retry");
	push(@tmp, "GPRINT:bretr:LAST:           Current\\: %4.1lf");
	push(@tmp, "GPRINT:bretr:AVERAGE:  Average\\: %4.1lf");
	push(@tmp, "GPRINT:bretr:MIN:  Min\\: %4.1lf");
	push(@tmp, "GPRINT:bretr:MAX:  Max\\: %4.1lf\\n");
	push(@tmpz, "LINE2:bconn#44EEEE:Conn. success");
	push(@tmpz, "LINE2:bunhe#4444EE:Conn. not attempted");
	push(@tmpz, "LINE2:bbusy#EEEE44:Too many connections");
	push(@tmpz, "LINE2:bfail#FFA500:Conn. failures");
	push(@tmpz, "LINE2:breus#EE4444:Conn. reuses");
	push(@tmpz, "LINE2:btool#EE44EE:Conn. was closed");
	push(@tmpz, "LINE2:brecy#963C74:Conn. recycles");
	push(@tmpz, "LINE2:bretr#888888:Conn. retry");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_varnish2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Values/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:bconn=$rrd:varn0" . "_bconn:AVERAGE",
		"DEF:bunhe=$rrd:varn0" . "_bunhe:AVERAGE",
		"DEF:bbusy=$rrd:varn0" . "_bbusy:AVERAGE",
		"DEF:bfail=$rrd:varn0" . "_bfail:AVERAGE",
		"DEF:breus=$rrd:varn0" . "_breus:AVERAGE",
		"DEF:btool=$rrd:varn0" . "_btool:AVERAGE",
		"DEF:brecy=$rrd:varn0" . "_brecy:AVERAGE",
		"DEF:bretr=$rrd:varn0" . "_bretr:AVERAGE",
		"CDEF:allvalues=bconn,bunhe,bbusy,bfail,breus,btool,brecy,bretr,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_varnish2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Values/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:bconn=$rrd:varn0" . "_bconn:AVERAGE",
			"DEF:bunhe=$rrd:varn0" . "_bunhe:AVERAGE",
			"DEF:bbusy=$rrd:varn0" . "_bbusy:AVERAGE",
			"DEF:bfail=$rrd:varn0" . "_bfail:AVERAGE",
			"DEF:breus=$rrd:varn0" . "_breus:AVERAGE",
			"DEF:btool=$rrd:varn0" . "_btool:AVERAGE",
			"DEF:brecy=$rrd:varn0" . "_brecy:AVERAGE",
			"DEF:bretr=$rrd:varn0" . "_bretr:AVERAGE",
			"CDEF:allvalues=bconn,bunhe,bbusy,bfail,breus,btool,brecy,bretr,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /varnish2/)) {
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

	if($title) {
		push(@output, "    </td>\n");
		push(@output, "    <td class='td-valign-top'>\n");
	}

	@riglim = @{setup_riglim($rigid[2], $limit[2])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:cconn#44EEEE:Conn. accepted");
	push(@tmp, "GPRINT:cconn:LAST:       Current\\: %5.1lf\\n");
	push(@tmp, "LINE2:cdrop#EE4444:Conn. dropped");
	push(@tmp, "GPRINT:cdrop:LAST:        Current\\: %5.1lf\\n");
	push(@tmp, "LINE2:creq#44EE44:Req. accepted");
	push(@tmp, "GPRINT:creq:LAST:        Current\\: %5.1lf\\n");
	push(@tmpz, "LINE2:cconn#44EEEE:Conn. accepted");
	push(@tmpz, "LINE2:cdrop#EE4444:Conn. dropped");
	push(@tmpz, "LINE2:creq#44EE44:Req. accepted");
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
		"--title=$config->{graphs}->{_varnish3}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:cconn=$rrd:varn0" . "_cconn:AVERAGE",
		"DEF:cdrop=$rrd:varn0" . "_cdrop:AVERAGE",
		"DEF:creq=$rrd:varn0" . "_creq:AVERAGE",
		"CDEF:allvalues=cconn,cdrop,creq,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_varnish3}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:cconn=$rrd:varn0" . "_cconn:AVERAGE",
			"DEF:cdrop=$rrd:varn0" . "_cdrop:AVERAGE",
			"DEF:creq=$rrd:varn0" . "_creq:AVERAGE",
			"CDEF:allvalues=cconn,cdrop,creq,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /varnish3/)) {
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

	@riglim = @{setup_riglim($rigid[3], $limit[3])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:chit#44EEEE:Hits");
	push(@tmp, "GPRINT:chit:LAST:                 Current\\: %5.1lf\\n");
	push(@tmp, "LINE2:chitp#4444EE:Hits for pass");
	push(@tmp, "GPRINT:chitp:LAST:        Current\\: %5.1lf\\n");
	push(@tmp, "LINE2:cmiss#EE44EE:Misses");
	push(@tmp, "GPRINT:cmiss:LAST:               Current\\: %5.1lf\\n");
	push(@tmpz, "LINE2:chit#44EEEE:Hits");
	push(@tmpz, "LINE2:chitp#4444EE:Hits for pass");
	push(@tmpz, "LINE2:cmiss#EE44EE:Misses");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG4",
		"--title=$config->{graphs}->{_varnish4}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Values/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:chit=$rrd:varn0" . "_chit:AVERAGE",
		"DEF:chitp=$rrd:varn0" . "_chitp:AVERAGE",
		"DEF:cmiss=$rrd:varn0" . "_cmiss:AVERAGE",
		"CDEF:allvalues=chit,chitp,cmiss,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG4z",
			"--title=$config->{graphs}->{_varnish4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Values/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:chit=$rrd:varn0" . "_chit:AVERAGE",
			"DEF:chitp=$rrd:varn0" . "_chitp:AVERAGE",
			"DEF:cmiss=$rrd:varn0" . "_cmiss:AVERAGE",
			"CDEF:allvalues=chit,chitp,cmiss,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /varnish4/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG4z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG4 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG4z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG4 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG4 . "'>\n");
		}
	}

	@riglim = @{setup_riglim($rigid[4], $limit[4])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:nsob#EEEE44:N struct object");
	push(@tmp, "GPRINT:nsob:LAST:      Current\\: %5.0lf\\n");
	push(@tmp, "LINE2:nsoc#44EEEE:N struct objectcore");
	push(@tmp, "GPRINT:nsoc:LAST:  Current\\: %5.0lf\\n");
	push(@tmp, "LINE2:nsoh#4444EE:N struct objecthead");
	push(@tmp, "GPRINT:nsoh:LAST:  Current\\: %5.0lf\\n");
	push(@tmp, "LINE2:nswl#EE44EE:N struct waitinglist");
	push(@tmp, "GPRINT:nswl:LAST: Current\\: %5.0lf\\n");
	push(@tmpz, "LINE2:nsob#EEEE44:N struct object");
	push(@tmpz, "LINE2:nsoc#44EEEE:N struct objectcore");
	push(@tmpz, "LINE2:nsoh#4444EE:N struct objecthead");
	push(@tmpz, "LINE2:nswl#EE44EE:N struct waitinglist");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG5",
		"--title=$config->{graphs}->{_varnish5}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Objects",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:nsob=$rrd:varn0" . "_nsob:AVERAGE",
		"DEF:nsoc=$rrd:varn0" . "_nsoc:AVERAGE",
		"DEF:nsoh=$rrd:varn0" . "_nsoh:AVERAGE",
		"DEF:nswl=$rrd:varn0" . "_nswl:AVERAGE",
		"CDEF:allvalues=nsob,nsoc,nsoh,nswl,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG5z",
			"--title=$config->{graphs}->{_varnish5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Objects",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:nsob=$rrd:varn0" . "_nsob:AVERAGE",
			"DEF:nsoc=$rrd:varn0" . "_nsoc:AVERAGE",
			"DEF:nsoh=$rrd:varn0" . "_nsoh:AVERAGE",
			"DEF:nswl=$rrd:varn0" . "_nswl:AVERAGE",
			"CDEF:allvalues=nsob,nsoc,nsoh,nswl,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /varnish5/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG5z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG5 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG5z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG5 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG5 . "'>\n");
		}
	}

	@riglim = @{setup_riglim($rigid[6], $limit[6])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:hdrb#EE44EE:Header");
	push(@tmp, "AREA:bodb#963C74:Body");
	push(@tmp, "AREA:bodb#963C74:");
	push(@tmp, "AREA:hdrb#EE44EE:");
	push(@tmp, "LINE1:bodb#963C74");
	push(@tmp, "LINE1:hdrb#EE00EE");
	push(@tmpz, "AREA:hdrb#EE44EE:Header");
	push(@tmpz, "AREA:bodb#963C74:Body");
	push(@tmpz, "AREA:bodb#963C74:");
	push(@tmpz, "AREA:hdrb#EE44EE:");
	push(@tmpz, "LINE1:bodb#963C74");
	push(@tmpz, "LINE1:hdrb#EE00EE");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG6",
		"--title=$config->{graphs}->{_varnish6}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=bytes/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:hdrb=$rrd:varn0" . "_hdrb:AVERAGE",
		"DEF:bodb=$rrd:varn0" . "_bodb:AVERAGE",
		"CDEF:allvalues=hdrb,bodb,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG6: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG6z",
			"--title=$config->{graphs}->{_varnish6}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=bytes/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:hdrb=$rrd:varn0" . "_hdrb:AVERAGE",
			"DEF:bodb=$rrd:varn0" . "_bodb:AVERAGE",
			"CDEF:allvalues=hdrb,bodb,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG6z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /varnish6/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG6z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG6 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG6z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG6 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG6 . "'>\n");
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
