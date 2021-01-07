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

package redis;

use strict;
use warnings;
use Monitorix;
use RRDs;
use IO::Socket;
use IO::Select;
use Exporter 'import';
our @EXPORT = qw(redis_init redis_update redis_cgi);

sub redis_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $redis = $config->{redis};

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
		if(scalar(@ds) / 28 != scalar(my @il = split(',', $redis->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @il = split(',', $redis->{list})) . ") and $rrd (" . scalar(@ds) / 28 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @il = split(',', $redis->{list})); $n++) {
			push(@tmp, "DS:redis" . $n . "_uptime:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_connc:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_blocc:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_mused:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_murss:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_afrgr:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_arssr:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_aovhr:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_mfrgr:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_tconn:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_tcomm:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_netin:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_netout:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_rconn:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_ekeys:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_khits:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_kmiss:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_conns:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_val01:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_val02:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_val03:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_val04:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_val05:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_val06:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_val07:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_val08:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_val09:GAUGE:120:0:U");
			push(@tmp, "DS:redis" . $n . "_val10:GAUGE:120:0:U");
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

	$config->{redis_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub redis_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $redis = $config->{redis};

	my $n;
	my $rrdata = "N";

	my $e = 0;
	foreach(my @ml = split(',', $redis->{list})) {
		my $uptime = 0;
		my $connc = 0;
		my $blocc = 0;
		my $mused = 0;
		my $murss = 0;
		my $afrgr = 0;
		my $arssr = 0;
		my $aovhr = 0;
		my $mfrgr = 0;
		my $tconn = 0;
		my $tcomm = 0;
		my $netin = 0;
		my $netout = 0;
		my $rconn = 0;
		my $ekeys = 0;
		my $khits = 0;
		my $kmiss = 0;
		my $conns = 0;
		my $str;

		my ($host, $port) = split(':', trim($ml[$e]));
		my $s = new IO::Socket::INET (
			Domain		=> AF_INET,
			Type		=> SOCK_STREAM,
			Proto		=> "tcp",
			PeerHost	=> $host,
			PeerPort	=> $port,
			Timeout		=> 5,
		);
		if(!$s) {
			logger("$myself: unable to connect to port '$port' on host '$host': $!");
			$rrdata .= ":$uptime:$connc:$blocc:$mused:$murss:$afrgr:$arssr:$aovhr:$mfrgr:$tconn:$tcomm:$netin:$netout:$rconn:$ekeys:$khits:$kmiss:$conns:0:0:0:0:0:0:0:0:0:0";
			next;
		}

		# flush after every write
		$| = 1;

		my $select = new IO::Select();
		$select->add($s);

		$s->send("info\n");
		my ($data, @sockets_ready);
		$str = "";
		while (1) {
			my @sockets_ready = $select->can_read(1.0);
			if(!scalar(@sockets_ready)) {
				last;
			} else {
				foreach $s (@sockets_ready) {
					$s->recv($str, 1024);
					$data .= $str;
				}
			}
		}

		$s->close();
		$data =~ s/\r//g;	# remove DOS format

		foreach(my @l = split('\n', $data)) {
			if(/^uptime_in_seconds:\s*(\d+)$/) {
				$uptime = $1;
			}
			if(/^connected_clients:\s*(\d+)$/) {
				$connc = $1;
			}
			if(/^blocked_clients:\s*(\d+)$/) {
				$blocc = $1;
			}
			if(/^used_memory:\s*(\d+)$/) {
				$mused = $1;
			}
			if(/^used_memory_rss:\s*(\d+)$/) {
				$murss = $1;
			}
			if(/^allocator_frag_ratio:\s*(\d+.\d+)$/) {
				$afrgr = $1;
			}
			if(/^allocator_rss_ratio:\s*(\d+.\d+)$/) {
				$arssr = $1;
			}
			if(/^rss_overhead_ratio:\s*(\d+.\d+)$/) {
				$aovhr = $1;
			}
			if(/^mem_fragmentation_ratio:\s*(\d+.\d+)$/) {
				$mfrgr = $1;
			}
			if(/^total_connections_received:\s*(\d+)$/) {
				$str = $e . "tconn";
				$tconn = $1 - ($config->{redis_hist}->{$str} || 0);
				$tconn = 0 unless $tconn != $1;
				$tconn /= 60;
				$config->{redis_hist}->{$str} = $1;
			}
			if(/^total_commands_processed:\s*(\d+)$/) {
				$str = $e . "tcomm";
				$tcomm = $1 - ($config->{redis_hist}->{$str} || 0);
				$tcomm = 0 unless $tcomm != $1;
				$tcomm /= 60;
				$config->{redis_hist}->{$str} = $1;
			}
			if(/^total_net_input_bytes:\s*(\d+)$/) {
				$str = $e . "netin";
				$netin = $1 - ($config->{redis_hist}->{$str} || 0);
				$netin = 0 unless $netin != $1;
				$netin /= 60;
				$config->{redis_hist}->{$str} = $1;
			}
			if(/^total_net_output_bytes:\s*(\d+)$/) {
				$str = $e . "netout";
				$netout = $1 - ($config->{redis_hist}->{$str} || 0);
				$netout = 0 unless $netout != $1;
				$netout /= 60;
				$config->{redis_hist}->{$str} = $1;
			}
			if(/^rejected_connections:\s*(\d+)$/) {
				$str = $e . "rconn";
				$rconn = $1 - ($config->{redis_hist}->{$str} || 0);
				$rconn = 0 unless $rconn != $1;
				$rconn /= 60;
				$config->{redis_hist}->{$str} = $1;
			}
			if(/^evicted_keys:\s*(\d+)$/) {
				$str = $e . "ekeys";
				$ekeys = $1 - ($config->{redis_hist}->{$str} || 0);
				$ekeys = 0 unless $ekeys != $1;
				$ekeys /= 60;
				$config->{redis_hist}->{$str} = $1;
			}
			if(/^keyspace_hits:\s*(\d+)$/) {
				$str = $e . "khits";
				$khits = $1 - ($config->{redis_hist}->{$str} || 0);
				$khits = 0 unless $khits != $1;
				$khits /= 60;
				$config->{redis_hist}->{$str} = $1;
			}
			if(/^keyspace_misses:\s*(\d+)$/) {
				$str = $e . "kmiss";
				$kmiss = $1 - ($config->{redis_hist}->{$str} || 0);
				$kmiss = 0 unless $kmiss != $1;
				$kmiss /= 60;
				$config->{redis_hist}->{$str} = $1;
			}
			if(/^connected_slaves:\s*(\d+)$/) {
				$str = $e . "conns";
				$conns = $1 - ($config->{redis_hist}->{$str} || 0);
				$conns = 0 unless $conns != $1;
				$conns /= 60;
				$config->{redis_hist}->{$str} = $1;
			}
		}
		$rrdata .= ":$uptime:$connc:$blocc:$mused:$murss:$afrgr:$arssr:$aovhr:$mfrgr:$tconn:$tcomm:$netin:$netout:$rconn:$ekeys:$khits:$kmiss:$conns:0:0:0:0:0:0:0:0:0:0";
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub redis_cgi {
	my $myself = (caller(0))[3];
	my ($package, $config, $cgi) = @_;
	my @output;

	my $redis = $config->{redis};
	my @rigid = split(',', ($redis->{rigid} || ""));
	my @limit = split(',', ($redis->{limit} || ""));
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
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		for($n = 0; $n < scalar(my @pl = split(',', $redis->{list})); $n++) {
			$line1 .= "    Uptime Conn.Cli Blck.Cli Mem.Used  Mem.RSS AlFrg.Rt AlRSS.Rt AlOvh.Rt MFrag.Rt Conn.Rcv Comm.Pro  Net.Inp Net.Outp Conn.Rej Evic.Key Key.Hits Key.Miss Conn.Slv";
			$line2 .= "-------------------------------------------------------------------------------------------------------------------------------------------------------------------";
			if($line2) {
				my $i = length($line2);
				push(@output, sprintf(sprintf("%${i}s", sprintf("%s", trim($pl[$n])))));
			}
		}
		push(@output, "\n");
		push(@output, "Time$line1\n");
		push(@output, "----$line2 \n");
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
			for($n2 = 0; $n2 < scalar(my @pl = split(',', $redis->{list})); $n2++) {
				undef(@row);
				$from = $n2 * 28;
				$to = $from + 28;
				my ($uptime, $connc, $blocc, $mused, $murss, $afrgr, $arssr, $aovhr, $mfrgr, $tconn, $tcomm, $netin, $netout, $rconn, $ekeys, $khits, $kmiss, $conns) = @$line[$from..$to];
				$uptime = ($uptime || 0) / 60 / 60 / 24;	# convert from seconds to days
				push(@output, sprintf("    %6.2f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f", $uptime, $connc || 0, $blocc || 0, $mused || 0, $murss || 0, $afrgr || 0, $arssr || 0, $aovhr || 0, $mfrgr || 0, $tconn || 0, $tcomm || 0, $netin || 0, $netout || 0, $rconn || 0, $ekeys || 0, $khits || 0, $kmiss || 0, $conns || 0));
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

	for($n = 0; $n < scalar(my @ml = split(',', $redis->{list})); $n++) {
		for($n2 = 1; $n2 <= 6; $n2++) {
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
	foreach my $url (my @ml = split(',', $redis->{list})) {
		if($e) {
			push(@output, "  <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}
		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}

		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
			"--resolution=60",
			"--start=-1min",
			"AVERAGE");
		$err = RRDs::error;
		push(@output, "ERROR: while fetching $rrd: $err\n") if $err;
		my $line = @$data[0];
		my ($uptime) = @$line[$e * 28];
		my $uptimeline;
		if($RRDs::VERSION > 1.2) {
			$uptimeline = "COMMENT:uptime\\: " . uptime2str(trim($uptime)) . "\\c";
		} else {
			$uptimeline = "COMMENT:uptime: " . uptime2str(trim($uptime)) . "\\c";
		}

		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:tconn#44EEEE:Connections received");
		push(@tmp, "GPRINT:tconn:LAST:    Cur\\: %4.1lf");
		push(@tmp, "GPRINT:tconn:AVERAGE:   Avg\\: %4.1lf");
		push(@tmp, "GPRINT:tconn:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:tconn:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:tcomm#4444EE:Commands processed");
		push(@tmp, "GPRINT:tcomm:LAST:      Cur\\: %4.1lf");
		push(@tmp, "GPRINT:tcomm:AVERAGE:   Avg\\: %4.1lf");
		push(@tmp, "GPRINT:tcomm:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:tcomm:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:rconn#EE44EE:Connections rejected");
		push(@tmp, "GPRINT:rconn:LAST:    Cur\\: %4.1lf");
		push(@tmp, "GPRINT:rconn:AVERAGE:   Avg\\: %4.1lf");
		push(@tmp, "GPRINT:rconn:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:rconn:MAX:   Max\\: %4.1lf\\n");
		push(@tmpz, "LINE2:tconn#44EEEE:Connections received");
		push(@tmpz, "LINE2:tcomm#4444EE:Commands processed");
		push(@tmpz, "LINE2:rconn#EE44EE:Connections rejected");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6]",
			"--title=$config->{graphs}->{_redis1}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:tconn=$rrd:redis" . $e . "_tconn:AVERAGE",
			"DEF:tcomm=$rrd:redis" . $e . "_tcomm:AVERAGE",
			"DEF:rconn=$rrd:redis" . $e . "_rconn:AVERAGE",
			"CDEF:allvalues=tconn,tcomm,rconn,+,+",
			@CDEF,
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			$uptimeline,
			"COMMENT: \\n");
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6]",
				"--title=$config->{graphs}->{_redis1}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:tconn=$rrd:redis" . $e . "_tconn:AVERAGE",
				"DEF:tcomm=$rrd:redis" . $e . "_tcomm:AVERAGE",
				"DEF:rconn=$rrd:redis" . $e . "_rconn:AVERAGE",
				"CDEF:allvalues=tconn,tcomm,rconn,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /redis$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:afrgr#44EEEE:Allocator fragmentation");
		push(@tmp, "GPRINT:afrgr:LAST: Cur\\: %4.1lf");
		push(@tmp, "GPRINT:afrgr:AVERAGE:   Avg\\: %4.1lf");
		push(@tmp, "GPRINT:afrgr:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:afrgr:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:arssr#4444EE:Allocator RSS");
		push(@tmp, "GPRINT:arssr:LAST:           Cur\\: %4.1lf");
		push(@tmp, "GPRINT:arssr:AVERAGE:   Avg\\: %4.1lf");
		push(@tmp, "GPRINT:arssr:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:arssr:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:aovhr#EE44EE:RSS overhead");
		push(@tmp, "GPRINT:aovhr:LAST:            Cur\\: %4.1lf");
		push(@tmp, "GPRINT:aovhr:AVERAGE:   Avg\\: %4.1lf");
		push(@tmp, "GPRINT:aovhr:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:aovhr:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:mfrgr#EE4444:Memory fragmentation");
		push(@tmp, "GPRINT:mfrgr:LAST:    Cur\\: %4.1lf");
		push(@tmp, "GPRINT:mfrgr:AVERAGE:   Avg\\: %4.1lf");
		push(@tmp, "GPRINT:mfrgr:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:mfrgr:MAX:   Max\\: %4.1lf\\n");
		push(@tmpz, "LINE2:afrgr#44EEEE:Allocator fragmentation");
		push(@tmpz, "LINE2:arssr#4444EE:Allocator RSS");
		push(@tmpz, "LINE2:aovhr#EE44EE:RSS overhead");
		push(@tmpz, "LINE2:mfrgr#EE4444:Memory fragmentation");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 1]",
			"--title=$config->{graphs}->{_redis2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Ratio",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:afrgr=$rrd:redis" . $e . "_afrgr:AVERAGE",
			"DEF:arssr=$rrd:redis" . $e . "_arssr:AVERAGE",
			"DEF:aovhr=$rrd:redis" . $e . "_aovhr:AVERAGE",
			"DEF:mfrgr=$rrd:redis" . $e . "_mfrgr:AVERAGE",
			"CDEF:allvalues=afrgr,arssr,aovhr,mfrgr,+,+,+",
			@CDEF,
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			"COMMENT: \\n");
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 1]",
				"--title=$config->{graphs}->{_redis2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Ratio",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:afrgr=$rrd:redis" . $e . "_afrgr:AVERAGE",
				"DEF:arssr=$rrd:redis" . $e . "_arssr:AVERAGE",
				"DEF:aovhr=$rrd:redis" . $e . "_aovhr:AVERAGE",
				"DEF:mfrgr=$rrd:redis" . $e . "_mfrgr:AVERAGE",
				"CDEF:allvalues=afrgr,arssr,aovhr,mfrgr,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /redis$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "'>\n");
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
		push(@tmp, "LINE2:connc#44EE44:Connected");
		push(@tmp, "GPRINT:connc:LAST:            Current\\: %4.1lf\\n");
		push(@tmp, "LINE2:blocc#44EEEE:Blocked");
		push(@tmp, "GPRINT:blocc:LAST:              Current\\: %4.1lf\\n");
		push(@tmp, "LINE2:conns#FFA500:Connected slaves");
		push(@tmp, "GPRINT:conns:LAST:     Current\\: %4.1lf\\n");
		push(@tmpz, "LINE2:connc#44EE44:Connected");
		push(@tmpz, "LINE2:blocc#44EEEE:Blocked");
		push(@tmpz, "LINE2:conns#FFA500:Connected slaves");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 2]",
			"--title=$config->{graphs}->{_redis3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Clients",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:connc=$rrd:redis" . $e . "_connc:AVERAGE",
			"DEF:blocc=$rrd:redis" . $e . "_blocc:AVERAGE",
			"DEF:conns=$rrd:redis" . $e . "_conns:AVERAGE",
			"CDEF:allvalues=connc,blocc,conns,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 2]",
				"--title=$config->{graphs}->{_redis3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Clients",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:connc=$rrd:redis" . $e . "_connc:AVERAGE",
				"DEF:blocc=$rrd:redis" . $e . "_blocc:AVERAGE",
				"DEF:conns=$rrd:redis" . $e . "_conns:AVERAGE",
				"CDEF:allvalues=connc,blocc,conns,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /redis$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[3], $limit[3])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:mused#EEEE44:Redis memory");
		push(@tmp, "GPRINT:mused:LAST:         Current\\: %2.1lf%s\\n");
		push(@tmp, "LINE2:murss#44EEEE:System memory");
		push(@tmp, "GPRINT:murss:LAST:        Current\\: %2.1lf%s\\n");
		push(@tmpz, "LINE2:mused#EEEE44:Redis memory");
		push(@tmpz, "LINE2:murss#44EEEE:System memory");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 3]",
			"--title=$config->{graphs}->{_redis4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Bytes",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:mused=$rrd:redis" . $e . "_mused:AVERAGE",
			"DEF:murss=$rrd:redis" . $e . "_murss:AVERAGE",
			"CDEF:allvalues=mused,murss,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 3]",
				"--title=$config->{graphs}->{_redis4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Bytes",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:mused=$rrd:redis" . $e . "_mused:AVERAGE",
				"DEF:murss=$rrd:redis" . $e . "_murss:AVERAGE",
				"CDEF:allvalues=mused,murss,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 3]: $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /redis$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[4], $limit[4])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:ekeys#EEEE44:Evicted keys");
		push(@tmp, "GPRINT:ekeys:LAST:         Current\\: %3.1lf\\n");
		push(@tmp, "LINE2:khits#4444EE:Keyspace hits");
		push(@tmp, "GPRINT:khits:LAST:        Current\\: %3.1lf\\n");
		push(@tmp, "LINE2:kmiss#EE44EE:Keyspace misses");
		push(@tmp, "GPRINT:kmiss:LAST:      Current\\: %3.1lf\\n");
		push(@tmpz, "LINE2:ekeys#EEEE44:Evicted keys");
		push(@tmpz, "LINE2:khits#4444EE:Keyspace hits");
		push(@tmpz, "LINE2:kmiss#EE44EE:Keyspace misses");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 4]",
			"--title=$config->{graphs}->{_redis5}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:ekeys=$rrd:redis" . $e . "_ekeys:AVERAGE",
			"DEF:khits=$rrd:redis" . $e . "_khits:AVERAGE",
			"DEF:kmiss=$rrd:redis" . $e . "_kmiss:AVERAGE",
			"CDEF:allvalues=ekeys,khits,kmiss,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 4]",
				"--title=$config->{graphs}->{_redis5}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:ekeys=$rrd:redis" . $e . "_ekeys:AVERAGE",
				"DEF:khits=$rrd:redis" . $e . "_khits:AVERAGE",
				"DEF:kmiss=$rrd:redis" . $e . "_kmiss:AVERAGE",
				"CDEF:allvalues=ekeys,khits,kmiss,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 4]: $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /redis$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 4] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 4] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[5], $limit[5])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:B_in#44EE44:Input");
		push(@tmp, "AREA:B_out#4444EE:Output");
		push(@tmp, "AREA:B_out#4444EE");
		push(@tmp, "AREA:B_in#44EE44");
		push(@tmp, "LINE1:B_out#0000EE");
		push(@tmp, "LINE1:B_in#00EE00");
		push(@tmpz, "AREA:B_in#44EE44:Input");
		push(@tmpz, "AREA:B_out#4444EE:Output");
		push(@tmpz, "AREA:B_out#4444EE");
		push(@tmpz, "AREA:B_in#44EE44");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 5]",
			"--title=$config->{graphs}->{_redis6}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:in=$rrd:redis" . $e . "_netin:AVERAGE",
			"DEF:out=$rrd:redis" . $e . "_netout:AVERAGE",
			"CDEF:allvalues=in,out,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 5]",
				"--title=$config->{graphs}->{_redis6}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:in=$rrd:redis" . $e . "_netin:AVERAGE",
				"DEF:out=$rrd:redis" . $e . "_netout:AVERAGE",
				"CDEF:allvalues=in,out,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 5]: $err\n") if $err;
		}
		$e2 = $e + 6;
		if($title || ($silent =~ /imagetag/ && $graph =~ /redis$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 5] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 5] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");

			push(@output, "    <tr>\n");
			push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
			push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
			push(@output, "       <font size='-1'>\n");
			push(@output, "        <b style='{color: " . $colors->{title_fg_color} . "}'>&nbsp;&nbsp;" . trim($url) . "</b>\n");
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
