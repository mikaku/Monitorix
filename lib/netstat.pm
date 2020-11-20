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

package netstat;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(netstat_init netstat_update netstat_cgi);

sub netstat_init {
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

	if($config->{os} eq "NetBSD") {
		logger("$myself is not supported yet by your operating system ($config->{os}).");
		return;
	}

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
				"DS:nstat4_closed:GAUGE:120:0:U",
				"DS:nstat4_listen:GAUGE:120:0:U",
				"DS:nstat4_synsent:GAUGE:120:0:U",
				"DS:nstat4_synrecv:GAUGE:120:0:U",
				"DS:nstat4_estblshd:GAUGE:120:0:U",
				"DS:nstat4_finwait1:GAUGE:120:0:U",
				"DS:nstat4_finwait2:GAUGE:120:0:U",
				"DS:nstat4_closing:GAUGE:120:0:U",
				"DS:nstat4_timewait:GAUGE:120:0:U",
				"DS:nstat4_closewait:GAUGE:120:0:U",
				"DS:nstat4_lastack:GAUGE:120:0:U",
				"DS:nstat4_unknown:GAUGE:120:0:U",
				"DS:nstat4_udp:GAUGE:120:0:U",
				"DS:nstat4_val1:GAUGE:120:0:U",
				"DS:nstat4_val2:GAUGE:120:0:U",
				"DS:nstat4_val3:GAUGE:120:0:U",
				"DS:nstat4_val4:GAUGE:120:0:U",
				"DS:nstat4_val5:GAUGE:120:0:U",
				"DS:nstat6_closed:GAUGE:120:0:U",
				"DS:nstat6_listen:GAUGE:120:0:U",
				"DS:nstat6_synsent:GAUGE:120:0:U",
				"DS:nstat6_synrecv:GAUGE:120:0:U",
				"DS:nstat6_estblshd:GAUGE:120:0:U",
				"DS:nstat6_finwait1:GAUGE:120:0:U",
				"DS:nstat6_finwait2:GAUGE:120:0:U",
				"DS:nstat6_closing:GAUGE:120:0:U",
				"DS:nstat6_timewait:GAUGE:120:0:U",
				"DS:nstat6_closewait:GAUGE:120:0:U",
				"DS:nstat6_lastack:GAUGE:120:0:U",
				"DS:nstat6_unknown:GAUGE:120:0:U",
				"DS:nstat6_udp:GAUGE:120:0:U",
				"DS:nstat6_val1:GAUGE:120:0:U",
				"DS:nstat6_val2:GAUGE:120:0:U",
				"DS:nstat6_val3:GAUGE:120:0:U",
				"DS:nstat6_val4:GAUGE:120:0:U",
				"DS:nstat6_val5:GAUGE:120:0:U",
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

sub netstat_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

	my $i4_closed = 0;
	my $i4_listen = 0;
	my $i4_synsent = 0;
	my $i4_synrecv = 0;
	my $i4_estblshd = 0;
	my $i4_finwait1 = 0;
	my $i4_finwait2 = 0;
	my $i4_closing = 0;
	my $i4_timewait = 0;
	my $i4_closewait = 0;
	my $i4_lastack = 0;
	my $i4_unknown = 0;
	my $i4_udp = 0;
	my $i6_closed = 0;
	my $i6_listen = 0;
	my $i6_synsent = 0;
	my $i6_synrecv = 0;
	my $i6_estblshd = 0;
	my $i6_finwait1 = 0;
	my $i6_finwait2 = 0;
	my $i6_closing = 0;
	my $i6_timewait = 0;
	my $i6_closewait = 0;
	my $i6_lastack = 0;
	my $i6_unknown = 0;
	my $i6_udp = 0;

	my $rrdata = "N";

	if($config->{os} eq "Linux") {
		my $cmd = $config->{netstat}->{cmd} || "";
		if(!$cmd || $cmd eq "ss") {
			if(open(IN, "ss -naut -f inet |")) {
				while(<IN>) {
					m/^(\S+)\s+(\S+)/;
					my $proto = $1 || '';
					my $state = $2 || '';
					if ($proto eq 'tcp') {
						if    ($state eq "LISTEN")     { $i4_listen++ }
						elsif ($state eq "ESTAB")      { $i4_estblshd++ }
						elsif ($state eq "TIME-WAIT")  { $i4_timewait++ }
						elsif ($state eq "CLOSE-WAIT") { $i4_closewait++ }
						elsif ($state eq "FIN-WAIT-1")  { $i4_finwait1++ }
						elsif ($state eq "FIN-WAIT-2")  { $i4_finwait2++ }
						elsif ($state eq "SYN-SENT")   { $i4_synsent++ }
						elsif ($state eq "SYN-RECV")   { $i4_synrecv++ }
						elsif ($state eq "CLOSING")    { $i4_closing++ }
						elsif ($state eq "LAST-ACK")   { $i4_lastack++ }
						elsif ($state eq "UNCONN")     { $i4_closed++ }
						elsif ($state eq "UNKNOWN")    { $i4_unknown++ }
					} elsif ($proto eq 'udp') {
						$i4_udp++;
					}
				}
				close(IN);
			}
			if(open(IN, "ss -naut -f inet6 |")) {
				while(<IN>) {
					m/^(\S+)\s+(\S+)/;
					my $proto = $1 || '';
					my $state = $2 || '';
					if ($proto eq 'tcp') {
						if    ($state eq "LISTEN")     { $i6_listen++ }
						elsif ($state eq "ESTAB")      { $i6_estblshd++ }
						elsif ($state eq "TIME-WAIT")  { $i6_timewait++ }
						elsif ($state eq "CLOSE-WAIT") { $i6_closewait++ }
						elsif ($state eq "FIN-WAIT-1")  { $i6_finwait1++ }
						elsif ($state eq "FIN-WAIT-2")  { $i6_finwait2++ }
						elsif ($state eq "SYN-SENT")   { $i6_synsent++ }
						elsif ($state eq "SYN-RECV")   { $i6_synrecv++ }
						elsif ($state eq "CLOSING")    { $i6_closing++ }
						elsif ($state eq "LAST-ACK")   { $i6_lastack++ }
						elsif ($state eq "UNCONN")     { $i6_closed++ }
						elsif ($state eq "UNKNOWN")    { $i6_unknown++ }
					} elsif ($proto eq 'udp') {
						$i6_udp++;
					}
				}
				close(IN);
			}
		}
		if($cmd eq "netstat") {
			if(open(IN, "netstat -tn -A inet |")) {
				while(<IN>) {
					my $last = (split(' ', $_))[-1];
					$i4_closed++ if trim($last) eq "CLOSED";
					$i4_synsent++ if trim($last) eq "SYN_SENT";
					$i4_synrecv++ if trim($last) eq "SYN_RECV";
					$i4_estblshd++ if trim($last) eq "ESTABLISHED";
					$i4_finwait1++ if trim($last) eq "FIN_WAIT1";
					$i4_finwait2++ if trim($last) eq "FIN_WAIT2";
					$i4_closing++ if trim($last) eq "CLOSING";
					$i4_timewait++ if trim($last) eq "TIME_WAIT";
					$i4_closewait++ if trim($last) eq "CLOSE_WAIT";
					$i4_lastack++ if trim($last) eq "LAST_ACK";
					$i4_unknown++ if trim($last) eq "UNKNOWN";
				}
				close(IN);
			}
			if(open(IN, "netstat -ltn -A inet |")) {
				while(<IN>) {
					my $last = (split(' ', $_))[-1];
					$i4_listen++ if trim($last) eq "LISTEN";
				}
				close(IN);
			}
			if(open(IN, "netstat -lun -A inet |")) {
				while(<IN>) {
					$i4_udp++ if /^udp\s+/;
				}
				close(IN);
			}
			if(open(IN, "netstat -tn -A inet6 |")) {
				while(<IN>) {
					my $last = (split(' ', $_))[-1];
					$i6_closed++ if trim($last) eq "CLOSED";
					$i6_synsent++ if trim($last) eq "SYN_SENT";
					$i6_synrecv++ if trim($last) eq "SYN_RECV";
					$i6_estblshd++ if trim($last) eq "ESTABLISHED";
					$i6_finwait1++ if trim($last) eq "FIN_WAIT1";
					$i6_finwait2++ if trim($last) eq "FIN_WAIT2";
					$i6_closing++ if trim($last) eq "CLOSING";
					$i6_timewait++ if trim($last) eq "TIME_WAIT";
					$i6_closewait++ if trim($last) eq "CLOSE_WAIT";
					$i6_lastack++ if trim($last) eq "LAST_ACK";
					$i6_unknown++ if trim($last) eq "UNKNOWN";
				}
				close(IN);
			}
			if(open(IN, "netstat -ltn -A inet6 |")) {
				while(<IN>) {
					my $last = (split(' ', $_))[-1];
					$i6_listen++ if trim($last) eq "LISTEN";
				}
				close(IN);
			}
			if(open(IN, "netstat -lun -A inet6 |")) {
				while(<IN>) {
					$i6_udp++ if /^udp[ 6]\s+/;
				}
				close(IN);
			}
		}
	} elsif(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD")) {
		if(open(IN, "netstat -na -p tcp -f inet |")) {
			while(<IN>) {
				my $last = (split(' ', $_))[-1];
				$i4_closed++ if trim($last) eq "CLOSED";
				$i4_listen++ if trim($last) eq "LISTEN";
				$i4_synsent++ if trim($last) eq "SYN_SENT";
				$i4_synrecv++ if trim($last) eq "SYN_RCVD";
				$i4_estblshd++ if trim($last) eq "ESTABLISHED";
				$i4_finwait1++ if trim($last) eq "FIN_WAIT_1";
				$i4_finwait2++ if trim($last) eq "FIN_WAIT_2";
				$i4_closing++ if trim($last) eq "CLOSING";
				$i4_timewait++ if trim($last) eq "TIME_WAIT";
				$i4_closewait++ if trim($last) eq "CLOSE_WAIT";
				$i4_lastack++ if trim($last) eq "LAST_ACK";
				$i4_unknown++ if trim($last) eq "UNKNOWN";
			}
			close(IN);
		}
		if(open(IN, "netstat -na -p udp -f inet |")) {
			while(<IN>) {
				$i4_udp++ if /^udp.\s+/;
			}
			close(IN);
		}
		if(open(IN, "netstat -na -p tcp -f inet6 |")) {
			while(<IN>) {
				my $last = (split(' ', $_))[-1];
				$i6_closed++ if trim($last) eq "CLOSED";
				$i6_listen++ if trim($last) eq "LISTEN";
				$i6_synsent++ if trim($last) eq "SYN_SENT";
				$i6_synrecv++ if trim($last) eq "SYN_RCVD";
				$i6_estblshd++ if trim($last) eq "ESTABLISHED";
				$i6_finwait1++ if trim($last) eq "FIN_WAIT_1";
				$i6_finwait2++ if trim($last) eq "FIN_WAIT_2";
				$i6_closing++ if trim($last) eq "CLOSING";
				$i6_timewait++ if trim($last) eq "TIME_WAIT";
				$i6_closewait++ if trim($last) eq "CLOSE_WAIT";
				$i6_lastack++ if trim($last) eq "LAST_ACK";
				$i6_unknown++ if trim($last) eq "UNKNOWN";
			}
			close(IN);
		}
		if(open(IN, "netstat -na -p udp -f inet6 |")) {
			while(<IN>) {
				$i6_udp++ if /^udp.\s+/;
			}
			close(IN);
		}
	}

	$rrdata .= ":$i4_closed:$i4_listen:$i4_synsent:$i4_synrecv:$i4_estblshd:$i4_finwait1:$i4_finwait2:$i4_closing:$i4_timewait:$i4_closewait:$i4_lastack:$i4_unknown:$i4_udp:0:0:0:0:0:$i6_closed:$i6_listen:$i6_synsent:$i6_synrecv:$i6_estblshd:$i6_finwait1:$i6_finwait2:$i6_closing:$i6_timewait:$i6_closewait:$i6_lastack:$i6_unknown:$i6_udp:0:0:0:0:0";
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub netstat_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $netstat = $config->{netstat};
	my @rigid = split(',', ($netstat->{rigid} || ""));
	my @limit = split(',', ($netstat->{limit} || ""));
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
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "                                                                                            IPv4                                                                                        IPv6\n");
		push(@output, "Time  CLOSED LISTEN SYNSEN SYNREC ESTBLS FINWA1 FINWA2 CLOSIN TIMEWA CLOSEW LASTAC UNKNOW    UDP  CLOSED LISTEN SYNSEN SYNREC ESTBLS FINWA1 FINWA2 CLOSIN TIMEWA CLOSEW LASTAC UNKNOW    UDP\n");
		push(@output, "-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- \n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			my ($i4_closed, $i4_listen, $i4_synsent, $i4_syncrecv, $i4_estblshd, $i4_finwait1, $i4_finwait2, $i4_closing, $i4_timewait, $i4_closewait, $i4_lastack, $i4_unknown, $i4_udp, $i6_closed, $i6_listen, $i6_synsent, $i6_syncrecv, $i6_estblshd, $i6_finwait1, $i6_finwait2, $i6_closing, $i6_timewait, $i6_closewait, $i6_lastack, $i6_unknown, $i6_udp) = @$line;
			@row = ($i4_closed || 0, $i4_listen || 0, $i4_synsent || 0, $i4_syncrecv || 0, $i4_estblshd || 0, $i4_finwait1 || 0, $i4_finwait2 || 0, $i4_closing || 0, $i4_timewait || 0, $i4_closewait || 0, $i4_lastack || 0, $i4_unknown || 0, $i4_udp || 0, $i6_closed || 0, $i6_listen || 0, $i6_synsent || 0, $i6_syncrecv || 0, $i6_estblshd || 0, $i6_finwait1 || 0, $i6_finwait2 || 0, $i6_closing || 0, $i6_timewait || 0, $i6_closewait || 0, $i6_lastack || 0, $i6_unknown || 0, $i6_udp || 0);
			push(@output, sprintf(" %2d$tf->{tc}  %6d %6d %6d %6d %6d %6d %6d %6d %6d %6d %6d %6d %6d  %6d %6d %6d %6d %6d %6d %6d %6d %6d %6d %6d %6d %6d\n", $time, @row));
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
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG4z = $u . $package . "4z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG5z = $u . $package . "5z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3",
		"$IMG_DIR" . "$IMG4",
		"$IMG_DIR" . "$IMG5");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
			"$IMG_DIR" . "$IMG2z",
			"$IMG_DIR" . "$IMG3z",
			"$IMG_DIR" . "$IMG4z",
			"$IMG_DIR" . "$IMG5z");
	}

	if($title) {
		push(@output, main::graph_header($title, 2));
		push(@output, "    <tr>\n");
		push(@output, "    <td>\n");
	}

	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	push(@tmp, "LINE2:i4_closed#FFA500:CLOSED");
	push(@tmp, "GPRINT:i4_closed:LAST:        Current\\: %3.0lf");
	push(@tmp, "GPRINT:i4_closed:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i4_closed:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i4_closed:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i4_listen#44EEEE:LISTEN");
	push(@tmp, "GPRINT:i4_listen:LAST:        Current\\: %3.0lf");
	push(@tmp, "GPRINT:i4_listen:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i4_listen:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i4_listen:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i4_synsent#44EE44:SYN_SENT");
	push(@tmp, "GPRINT:i4_synsent:LAST:      Current\\: %3.0lf");
	push(@tmp, "GPRINT:i4_synsent:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i4_synsent:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i4_synsent:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i4_synrecv#4444EE:SYN_RECV");
	push(@tmp, "GPRINT:i4_synrecv:LAST:      Current\\: %3.0lf");
	push(@tmp, "GPRINT:i4_synrecv:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i4_synrecv:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i4_synrecv:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i4_estblshd#EE4444:ESTABLISHED");
	push(@tmp, "GPRINT:i4_estblshd:LAST:   Current\\: %3.0lf");
	push(@tmp, "GPRINT:i4_estblshd:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i4_estblshd:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i4_estblshd:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i4_finwait1#EE44EE:FIN_WAIT1");
	push(@tmp, "GPRINT:i4_finwait1:LAST:     Current\\: %3.0lf");
	push(@tmp, "GPRINT:i4_finwait1:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i4_finwait1:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i4_finwait1:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i4_finwait2#EEEE44:FIN_WAIT2");
	push(@tmp, "GPRINT:i4_finwait2:LAST:     Current\\: %3.0lf");
	push(@tmp, "GPRINT:i4_finwait2:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i4_finwait2:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i4_finwait2:MAX:    Max\\: %3.0lf\\n");
	push(@tmpz, "LINE2:i4_closed#FFA500:CLOSED");
	push(@tmpz, "LINE2:i4_listen#44EEEE:LISTEN");
	push(@tmpz, "LINE2:i4_synsent#44EE44:SYN_SENT");
	push(@tmpz, "LINE2:i4_synrecv#4444EE:SYN_RECV");
	push(@tmpz, "LINE2:i4_estblshd#EE4444:ESTABLISHED");
	push(@tmpz, "LINE2:i4_finwait1#EE44EE:FIN_WAIT1");
	push(@tmpz, "LINE2:i4_finwait2#EEEE44:FIN_WAIT2");
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
		"--title=$config->{graphs}->{_netstat1}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:i4_closed=$rrd:nstat4_closed:AVERAGE",
		"DEF:i4_listen=$rrd:nstat4_listen:AVERAGE",
		"DEF:i4_synsent=$rrd:nstat4_synsent:AVERAGE",
		"DEF:i4_synrecv=$rrd:nstat4_synrecv:AVERAGE",
		"DEF:i4_estblshd=$rrd:nstat4_estblshd:AVERAGE",
		"DEF:i4_finwait1=$rrd:nstat4_finwait1:AVERAGE",
		"DEF:i4_finwait2=$rrd:nstat4_finwait2:AVERAGE",
		"CDEF:allvalues=i4_closed,i4_listen,i4_synsent,i4_synrecv,i4_estblshd,i4_finwait1,i4_finwait2,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_netstat1}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:i4_closed=$rrd:nstat4_closed:AVERAGE",
			"DEF:i4_listen=$rrd:nstat4_listen:AVERAGE",
			"DEF:i4_synsent=$rrd:nstat4_synsent:AVERAGE",
			"DEF:i4_synrecv=$rrd:nstat4_synrecv:AVERAGE",
			"DEF:i4_estblshd=$rrd:nstat4_estblshd:AVERAGE",
			"DEF:i4_finwait1=$rrd:nstat4_finwait1:AVERAGE",
			"DEF:i4_finwait2=$rrd:nstat4_finwait2:AVERAGE",
			"CDEF:allvalues=i4_closed,i4_listen,i4_synsent,i4_synrecv,i4_estblshd,i4_finwait1,i4_finwait2,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /netstat1/)) {
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
	push(@tmp, "LINE2:i6_closed#FFA500:CLOSED");
	push(@tmp, "GPRINT:i6_closed:LAST:        Current\\: %3.0lf");
	push(@tmp, "GPRINT:i6_closed:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i6_closed:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i6_closed:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_listen#44EEEE:LISTEN");
	push(@tmp, "GPRINT:i6_listen:LAST:        Current\\: %3.0lf");
	push(@tmp, "GPRINT:i6_listen:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i6_listen:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i6_listen:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_synsent#44EE44:SYN_SENT");
	push(@tmp, "GPRINT:i6_synsent:LAST:      Current\\: %3.0lf");
	push(@tmp, "GPRINT:i6_synsent:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i6_synsent:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i6_synsent:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_synrecv#4444EE:SYN_RECV");
	push(@tmp, "GPRINT:i6_synrecv:LAST:      Current\\: %3.0lf");
	push(@tmp, "GPRINT:i6_synrecv:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i6_synrecv:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i6_synrecv:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_estblshd#EE4444:ESTABLISHED");
	push(@tmp, "GPRINT:i6_estblshd:LAST:   Current\\: %3.0lf");
	push(@tmp, "GPRINT:i6_estblshd:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i6_estblshd:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i6_estblshd:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_finwait1#EE44EE:FIN_WAIT1");
	push(@tmp, "GPRINT:i6_finwait1:LAST:     Current\\: %3.0lf");
	push(@tmp, "GPRINT:i6_finwait1:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i6_finwait1:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i6_finwait1:MAX:    Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_finwait2#EEEE44:FIN_WAIT2");
	push(@tmp, "GPRINT:i6_finwait2:LAST:     Current\\: %3.0lf");
	push(@tmp, "GPRINT:i6_finwait2:AVERAGE:    Average\\: %3.0lf");
	push(@tmp, "GPRINT:i6_finwait2:MIN:    Min\\: %3.0lf");
	push(@tmp, "GPRINT:i6_finwait2:MAX:    Max\\: %3.0lf\\n");
	push(@tmpz, "LINE2:i6_closed#FFA500:CLOSED");
	push(@tmpz, "LINE2:i6_listen#44EEEE:LISTEN");
	push(@tmpz, "LINE2:i6_synsent#44EE44:SYN_SENT");
	push(@tmpz, "LINE2:i6_synrecv#4444EE:SYN_RECV");
	push(@tmpz, "LINE2:i6_estblshd#EE4444:ESTABLISHED");
	push(@tmpz, "LINE2:i6_finwait1#EE44EE:FIN_WAIT1");
	push(@tmpz, "LINE2:i6_finwait2#EEEE44:FIN_WAIT2");
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
		"--title=$config->{graphs}->{_netstat2}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:i6_closed=$rrd:nstat6_closed:AVERAGE",
		"DEF:i6_listen=$rrd:nstat6_listen:AVERAGE",
		"DEF:i6_synsent=$rrd:nstat6_synsent:AVERAGE",
		"DEF:i6_synrecv=$rrd:nstat6_synrecv:AVERAGE",
		"DEF:i6_estblshd=$rrd:nstat6_estblshd:AVERAGE",
		"DEF:i6_finwait1=$rrd:nstat6_finwait1:AVERAGE",
		"DEF:i6_finwait2=$rrd:nstat6_finwait2:AVERAGE",
		"CDEF:allvalues=i6_closed,i6_listen,i6_synsent,i6_synrecv,i6_estblshd,i6_finwait1,i6_finwait2,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_netstat2}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:i6_closed=$rrd:nstat6_closed:AVERAGE",
			"DEF:i6_listen=$rrd:nstat6_listen:AVERAGE",
			"DEF:i6_synsent=$rrd:nstat6_synsent:AVERAGE",
			"DEF:i6_synrecv=$rrd:nstat6_synrecv:AVERAGE",
			"DEF:i6_estblshd=$rrd:nstat6_estblshd:AVERAGE",
			"DEF:i6_finwait1=$rrd:nstat6_finwait1:AVERAGE",
			"DEF:i6_finwait2=$rrd:nstat6_finwait2:AVERAGE",
			"CDEF:allvalues=i6_closed,i6_listen,i6_synsent,i6_synrecv,i6_estblshd,i6_finwait1,i6_finwait2,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /netstat2/)) {
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
	push(@tmp, "LINE2:i4_closing#44EEEE:CLOSING ipv4");
	push(@tmp, "GPRINT:i4_closing:LAST:         Current\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_closing#4444EE:CLOSING ipv6");
	push(@tmp, "GPRINT:i6_closing:LAST:         Current\\: %3.0lf\\n");
	push(@tmp, "COMMENT: \\n");
	push(@tmp, "LINE2:i4_timewait#44EE44:TIME_WAIT ipv4");
	push(@tmp, "GPRINT:i4_timewait:LAST:       Current\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_timewait#448844:TIME_WAIT ipv6");
	push(@tmp, "GPRINT:i6_timewait:LAST:       Current\\: %3.0lf\\n");
	push(@tmpz, "LINE2:i4_closing#44EEEE:CLOSING ipv4");
	push(@tmpz, "LINE2:i6_closing#4444EE:CLOSING ipv6");
	push(@tmpz, "LINE2:i4_timewait#44EE44:TIME_WAIT ipv4");
	push(@tmpz, "LINE2:i6_timewait#448844:TIME_WAIT ipv6");
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
		"--title=$config->{graphs}->{_netstat3}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:i4_closing=$rrd:nstat4_closing:AVERAGE",
		"DEF:i6_closing=$rrd:nstat6_closing:AVERAGE",
		"DEF:i4_timewait=$rrd:nstat4_timewait:AVERAGE",
		"DEF:i6_timewait=$rrd:nstat6_timewait:AVERAGE",
		"CDEF:allvalues=i4_closing,i6_closing,i4_timewait,i6_timewait,+,+,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_netstat3}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:i4_closing=$rrd:nstat4_closing:AVERAGE",
			"DEF:i6_closing=$rrd:nstat6_closing:AVERAGE",
			"DEF:i4_timewait=$rrd:nstat4_timewait:AVERAGE",
			"DEF:i6_timewait=$rrd:nstat6_timewait:AVERAGE",
			"CDEF:allvalues=i4_closing,i6_closing,i4_timewait,i6_timewait,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /netstat3/)) {
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
	push(@tmp, "LINE2:i4_closewait#44EEEE:CLOSE_WAIT ipv4");
	push(@tmp, "GPRINT:i4_closewait:LAST:      Current\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_closewait#4444EE:CLOSE_WAIT ipv6");
	push(@tmp, "GPRINT:i6_closewait:LAST:      Current\\: %3.0lf\\n");
	push(@tmp, "COMMENT: \\n");
	push(@tmp, "LINE2:i4_lastack#44EE44:LAST_ACK ipv4");
	push(@tmp, "GPRINT:i4_lastack:LAST:        Current\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_lastack#448844:LAST_ACK ipv6");
	push(@tmp, "GPRINT:i6_lastack:LAST:        Current\\: %3.0lf\\n");
	push(@tmp, "COMMENT: \\n");
	push(@tmp, "LINE2:i4_unknown#EEEE44:UNKNOWN ipv4");
	push(@tmp, "GPRINT:i4_unknown:LAST:         Current\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_unknown#FFA500:UNKNOWN ipv6");
	push(@tmp, "GPRINT:i6_unknown:LAST:         Current\\: %3.0lf\\n");
	push(@tmpz, "LINE2:i4_closewait#44EEEE:CLOSE_WAIT ipv4");
	push(@tmpz, "LINE2:i6_closewait#4444EE:CLOSE_WAIT ipv6");
	push(@tmpz, "LINE2:i4_lastack#44EE44:LAST_ACK ipv4");
	push(@tmpz, "LINE2:i6_lastack#448844:LAST_ACK ipv6");
	push(@tmpz, "LINE2:i4_unknown#EEEE44:UNKNOWN ipv4");
	push(@tmpz, "LINE2:i6_unknown#FFA500:UNKNOWN ipv6");
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
		"--title=$config->{graphs}->{_netstat4}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:i4_closewait=$rrd:nstat4_closewait:AVERAGE",
		"DEF:i6_closewait=$rrd:nstat6_closewait:AVERAGE",
		"DEF:i4_lastack=$rrd:nstat4_lastack:AVERAGE",
		"DEF:i6_lastack=$rrd:nstat6_lastack:AVERAGE",
		"DEF:i4_unknown=$rrd:nstat4_unknown:AVERAGE",
		"DEF:i6_unknown=$rrd:nstat6_unknown:AVERAGE",
		"CDEF:allvalues=i4_closewait,i6_closewait,i4_lastack,i6_lastack,i4_unknown,i6_unknown,+,+,+,+,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG4z",
			"--title=$config->{graphs}->{_netstat4}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:i4_closewait=$rrd:nstat4_closewait:AVERAGE",
			"DEF:i6_closewait=$rrd:nstat6_closewait:AVERAGE",
			"DEF:i4_lastack=$rrd:nstat4_lastack:AVERAGE",
			"DEF:i6_lastack=$rrd:nstat6_lastack:AVERAGE",
			"DEF:i4_unknown=$rrd:nstat4_unknown:AVERAGE",
			"DEF:i6_unknown=$rrd:nstat6_unknown:AVERAGE",
			"CDEF:allvalues=i4_closewait,i6_closewait,i4_lastack,i6_lastack,i4_unknown,i6_unknown,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /netstat4/)) {
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
	push(@tmp, "LINE2:i4_udp#EE44EE:UDP ipv4");
	push(@tmp, "GPRINT:i4_udp:LAST:             Current\\: %3.0lf\\n");
	push(@tmp, "LINE2:i6_udp#963C74:UDP ipv6");
	push(@tmp, "GPRINT:i6_udp:LAST:             Current\\: %3.0lf\\n");
	push(@tmpz, "LINE2:i4_udp#EE44EE:UDP ipv4");
	push(@tmpz, "LINE2:i6_udp#963C74:UDP ipv6");
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
		"--title=$config->{graphs}->{_netstat5}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Listen",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:i4_udp=$rrd:nstat4_udp:AVERAGE",
		"DEF:i6_udp=$rrd:nstat6_udp:AVERAGE",
		"CDEF:allvalues=i4_udp,i6_udp,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG5z",
			"--title=$config->{graphs}->{_netstat5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Listen",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:i4_udp=$rrd:nstat4_udp:AVERAGE",
			"DEF:i6_udp=$rrd:nstat6_udp:AVERAGE",
			"CDEF:allvalues=i4_udp,i6_udp,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /netstat5/)) {
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

	if($title) {
		push(@output, "    </td>\n");
		push(@output, "    </tr>\n");
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
