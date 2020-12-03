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

package memcached;

use strict;
use warnings;
use Monitorix;
use RRDs;
use IO::Socket;
use Exporter 'import';
our @EXPORT = qw(memcached_init memcached_update memcached_cgi);

sub memcached_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $memcached = $config->{memcached};

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
		if(scalar(@ds) / 37 != scalar(my @il = split(',', $memcached->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @il = split(',', $memcached->{list})) . ") and $rrd (" . scalar(@ds) / 37 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @il = split(',', $memcached->{list})); $n++) {
			push(@tmp, "DS:memc" . $n . "_cconn:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_tconn:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_cstru:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_cmdset:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_cmdfls:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_gethit:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_getmis:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_delmis:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_delhit:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_incmis:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_inchit:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_decmis:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_dechit:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_casmis:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_cashit:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_casbad:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_autcmd:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_auterr:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_bread:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_bwrit:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_limmxb:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_thrds:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_bytes:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_evict:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_reclm:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_citems:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_titems:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_val01:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_val02:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_val03:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_val04:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_val05:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_val06:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_val07:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_val08:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_val09:GAUGE:120:0:U");
			push(@tmp, "DS:memc" . $n . "_val10:GAUGE:120:0:U");
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

	$config->{memcached_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub memcached_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $memcached = $config->{memcached};

	my $n;
	my $rrdata = "N";

	my $e = 0;
	foreach(my @ml = split(',', $memcached->{list})) {
		my $cconn = 0;
		my $tconn = 0;
		my $cstru = 0;
		my $cmdset = 0;
		my $cmdfls = 0;
		my $gethit = 0;
		my $getmis = 0;
		my $delmis = 0;
		my $delhit = 0;
		my $incmis = 0;
		my $inchit = 0;
		my $decmis = 0;
		my $dechit = 0;
		my $casmis = 0;
		my $cashit = 0;
		my $casbad = 0;
		my $autcmd = 0;
		my $auterr = 0;
		my $bread = 0;
		my $bwrit = 0;
		my $limmxb = 0;
		my $thrds = 0;
		my $bytes = 0;
		my $evict = 0;
		my $reclm = 0;
		my $citems = 0;
		my $titems = 0;
		my $str;

		my ($host, $port) = split(':', trim($ml[$e]));
		my $r = IO::Socket::INET->new(
			Proto		=> "tcp",
			PeerAddr	=> $host,
			PeerPort	=> $port,
		);
		if(!$r) {
			logger("$myself: unable to connect to port '$port' on host '$host'");
			$rrdata .= ":$cconn:$tconn:$cstru:$cmdset:$cmdfls:$gethit:$getmis:$delmis:$delhit:$incmis:$inchit:$decmis:$dechit:$casmis:$cashit:$casbad:$autcmd:$auterr:$bread:$bwrit:$limmxb:$thrds:$bytes:$evict:$reclm:$citems:$titems:0:0:0:0:0:0:0:0:0:0";
			next;
		}

		my $data;
		$r->send("stats\n");
		shutdown($r, 1);
		$r->recv($data, 4096);
		$r->close();

		$data =~ s/\r//g;	# remove DOS format
		foreach(my @l = split('\n', $data)) {
			if(/^STAT curr_connections (\d+)/) {
				$cconn = $1;
			}
			if(/^STAT total_connections (\d+)/) {
				$str = $e . "tconn";
				$tconn = $1 - ($config->{memcached_hist}->{$str} || 0);
				$tconn = 0 unless $tconn != $1;
				$tconn /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT connection_structures (\d+)/) {
				$cstru = $1;
			}
			if(/^STAT cmd_set (\d+)/) {
				$str = $e . "cmdset";
				$cmdset = $1 - ($config->{memcached_hist}->{$str} || 0);
				$cmdset = 0 unless $cmdset != $1;
				$cmdset /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT cmd_flush (\d+)/) {
				$str = $e . "cmdfls";
				$cmdfls = $1 - ($config->{memcached_hist}->{$str} || 0);
				$cmdfls = 0 unless $cmdfls != $1;
				$cmdfls /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT get_hits (\d+)/) {
				$str = $e . "gethit";
				$gethit = $1 - ($config->{memcached_hist}->{$str} || 0);
				$gethit = 0 unless $gethit != $1;
				$gethit /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT get_misses (\d+)/) {
				$str = $e . "getmis";
				$getmis = $1 - ($config->{memcached_hist}->{$str} || 0);
				$getmis = 0 unless $getmis != $1;
				$getmis /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT delete_misses (\d+)/) {
				$str = $e . "delmis";
				$delmis = $1 - ($config->{memcached_hist}->{$str} || 0);
				$delmis = 0 unless $delmis != $1;
				$delmis /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT delete_hits (\d+)/) {
				$str = $e . "delhit";
				$delhit = $1 - ($config->{memcached_hist}->{$str} || 0);
				$delhit = 0 unless $delhit != $1;
				$delhit /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT incr_misses (\d+)/) {
				$str = $e . "incmis";
				$incmis = $1 - ($config->{memcached_hist}->{$str} || 0);
				$incmis = 0 unless $incmis != $1;
				$incmis /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT incr_hits (\d+)/) {
				$str = $e . "inchit";
				$inchit = $1 - ($config->{memcached_hist}->{$str} || 0);
				$inchit = 0 unless $inchit != $1;
				$inchit /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT decr_misses (\d+)/) {
				$str = $e . "decmis";
				$decmis = $1 - ($config->{memcached_hist}->{$str} || 0);
				$decmis = 0 unless $decmis != $1;
				$decmis /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT decr_hits (\d+)/) {
				$str = $e . "dechit";
				$dechit = $1 - ($config->{memcached_hist}->{$str} || 0);
				$dechit = 0 unless $dechit != $1;
				$dechit /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT cas_misses (\d+)/) {
				$str = $e . "casmis";
				$casmis = $1 - ($config->{memcached_hist}->{$str} || 0);
				$casmis = 0 unless $casmis != $1;
				$casmis /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT cas_hits (\d+)/) {
				$str = $e . "cashit";
				$cashit = $1 - ($config->{memcached_hist}->{$str} || 0);
				$cashit = 0 unless $cashit != $1;
				$cashit /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT cas_badval (\d+)/) {
				$str = $e . "casbad";
				$casbad = $1 - ($config->{memcached_hist}->{$str} || 0);
				$casbad = 0 unless $casbad != $1;
				$casbad /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT auth_cmds (\d+)/) {
				$str = $e . "autcmd";
				$autcmd = $1 - ($config->{memcached_hist}->{$str} || 0);
				$autcmd = 0 unless $autcmd != $1;
				$autcmd /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT auth_errors (\d+)/) {
				$str = $e . "auterr";
				$auterr = $1 - ($config->{memcached_hist}->{$str} || 0);
				$auterr = 0 unless $auterr != $1;
				$auterr /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT bytes_read (\d+)/) {
				$str = $e . "bread";
				$bread = $1 - ($config->{memcached_hist}->{$str} || 0);
				$bread = 0 unless $bread != $1;
				$bread /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT bytes_written (\d+)/) {
				$str = $e . "bwrit";
				$bwrit = $1 - ($config->{memcached_hist}->{$str} || 0);
				$bwrit = 0 unless $bwrit != $1;
				$bwrit /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT limit_maxbytes (\d+)/) {
				$limmxb = $1;
			}
			if(/^STAT threads (\d+)/) {
				$thrds = $1;
			}
			if(/^STAT bytes (\d+)/) {
				$bytes = $1;
			}
			if(/^STAT evictions (\d+)/) {
				$str = $e . "evict";
				$evict = $1 - ($config->{memcached_hist}->{$str} || 0);
				$evict = 0 unless $evict != $1;
				$evict /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT reclaimed (\d+)/) {
				$str = $e . "reclm";
				$reclm = $1 - ($config->{memcached_hist}->{$str} || 0);
				$reclm = 0 unless $reclm != $1;
				$reclm /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
			if(/^STAT curr_items (\d+)/) {
				$citems = $1;
			}
			if(/^STAT total_items (\d+)/) {
				$str = $e . "titems";
				$titems = $1 - ($config->{memcached_hist}->{$str} || 0);
				$titems = 0 unless $titems != $1;
				$titems /= 60;
				$config->{memcached_hist}->{$str} = $1;
			}
		}
		$rrdata .= ":$cconn:$tconn:$cstru:$cmdset:$cmdfls:$gethit:$getmis:$delmis:$delhit:$incmis:$inchit:$decmis:$dechit:$casmis:$cashit:$casbad:$autcmd:$auterr:$bread:$bwrit:$limmxb:$thrds:$bytes:$evict:$reclm:$citems:$titems:0:0:0:0:0:0:0:0:0:0";
		$e++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub memcached_cgi {
	my $myself = (caller(0))[3];
	my ($package, $config, $cgi) = @_;
	my @output;

	my $memcached = $config->{memcached};
	my @rigid = split(',', ($memcached->{rigid} || ""));
	my @limit = split(',', ($memcached->{limit} || ""));
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
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		for($n = 0; $n < scalar(my @pl = split(',', $memcached->{list})); $n++) {
			$line1 .= "    Inc.Hits Inc:Miss Dec.Hits Dec.Miss Get.Hits Get.Miss Del.Hits Del.Miss Aut.Cmds Aut.Errs Cas.Hits Cas.Miss Cas.Bads Cmd.Sets Cmd.Flus CacheUsg    Items    Items Eviction Reclaimd Tot.Conn Conn.Now  Threads Bytes_Read Bytes_Writ";
			$line2 .= "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
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
			for($n2 = 0; $n2 < scalar(my @pl = split(',', $memcached->{list})); $n2++) {
				undef(@row);
				$from = $n2 * 37;
				$to = $from + 37;
				my ($cconn, $tconn, undef, $cmdset, $cmdfls, $gethit, $getmis, $delmis, $delhit, $incmis, $inchit, $decmis, $dechit, $casmis, $cashit, $casbad, $autcmd, $auterr, $bread, $bwrit, undef, $thrds, $bytes, $evict, $reclm, $citems, $titems) = @$line[$from..$to];
				push(@output, sprintf("    %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8d %8d %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %10d %10d", $inchit || 0, $incmis || 0, $dechit || 0, $decmis || 0, $gethit || 0, $getmis || 0, $delhit || 0, $delmis || 0, $autcmd || 0, $auterr || 0, $cashit || 0, $casmis || 0, $casbad || 0, $cmdset || 0, $cmdfls || 0, $bytes || 0, $citems || 0, $titems || 0, $evict || 0, $reclm || 0, $tconn || 0, $cconn || 0, $thrds || 0, $bread || 0, $bwrit || 0));
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

	for($n = 0; $n < scalar(my @ml = split(',', $memcached->{list})); $n++) {
		for($n2 = 1; $n2 <= 7; $n2++) {
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
	foreach my $url (my @ml = split(',', $memcached->{list})) {

		# get additional information from Memcached
		my ($host, $port) = split(':', trim($ml[$e]));
		my $r = IO::Socket::INET->new(
			Proto		=> "tcp",
			PeerAddr	=> $host,
			PeerPort	=> $port,
		);
		if(!$r) {
			logger("$myself: unable to connect to port '$port' on host '$host'.");
			next;
		}
		my $data;
		$r->send("stats\n");
		shutdown($r, 1);
		$r->recv($data, 4096);
		$r->close();
		$data =~ s/\r//g;	# remove DOS format
		my $uptimeline = 0;
		my $cachesize = 0;
		my $cachesizemb = 0;
		foreach(my @l = split('\n', $data)) {
			if(/^STAT uptime (\d+)/) {
				$uptimeline = $1;
				next;
			}
			if(/^STAT limit_maxbytes (\d+)/) {
				$cachesize = $1;
				next;
			}
		}
		$cachesizemb = int($cachesize / 1024 / 1024);
		if($RRDs::VERSION > 1.2) {
			$uptimeline = "COMMENT:uptime\\: " . uptime2str(trim($uptimeline)) . "\\c";
		} else {
			$uptimeline = "COMMENT:uptime: " . uptime2str(trim($uptimeline)) . "\\c";
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
			push(@output, "    <td class='td-valign-top'>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:inchit#EEEE44:Incr hits");
		push(@tmp, "GPRINT:inchit:LAST:       Current\\: %4.1lf");
		push(@tmp, "GPRINT:inchit:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:inchit:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:inchit:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:incmis#FFA500:Incr misses");
		push(@tmp, "GPRINT:incmis:LAST:     Current\\: %4.1lf");
		push(@tmp, "GPRINT:incmis:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:incmis:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:incmis:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:dechit#44EE44:Decr hits");
		push(@tmp, "GPRINT:dechit:LAST:       Current\\: %4.1lf");
		push(@tmp, "GPRINT:dechit:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:dechit:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:dechit:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:decmis#448844:Decr misses");
		push(@tmp, "GPRINT:decmis:LAST:     Current\\: %4.1lf");
		push(@tmp, "GPRINT:decmis:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:decmis:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:decmis:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:gethit#44EEEE:Get hits");
		push(@tmp, "GPRINT:gethit:LAST:        Current\\: %4.1lf");
		push(@tmp, "GPRINT:gethit:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:gethit:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:gethit:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:getmis#4444EE:Get misses");
		push(@tmp, "GPRINT:getmis:LAST:      Current\\: %4.1lf");
		push(@tmp, "GPRINT:getmis:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:getmis:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:getmis:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:delhit#EE44EE:Delete hits");
		push(@tmp, "GPRINT:delhit:LAST:     Current\\: %4.1lf");
		push(@tmp, "GPRINT:delhit:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:delhit:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:delhit:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:delmis#963C74:Delete misses");
		push(@tmp, "GPRINT:delmis:LAST:   Current\\: %4.1lf");
		push(@tmp, "GPRINT:delmis:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:delmis:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:delmis:MAX:   Max\\: %4.1lf\\n");
		push(@tmpz, "LINE2:inchit#EEEE44:Incr hits");
		push(@tmpz, "LINE2:incmis#FFA500:Incr misses");
		push(@tmpz, "LINE2:dechit#44EE44:Decr hits");
		push(@tmpz, "LINE2:decmis#448844:Decr misses");
		push(@tmpz, "LINE2:gethit#44EEEE:Get hits");
		push(@tmpz, "LINE2:getmis#4444EE:Get misses");
		push(@tmpz, "LINE2:delhit#EE44EE:Delete hits");
		push(@tmpz, "LINE2:delmis#963C74:Delete misses");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7]",
			"--title=$config->{graphs}->{_memcached1}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:inchit=$rrd:memc" . $e . "_inchit:AVERAGE",
			"DEF:incmis=$rrd:memc" . $e . "_incmis:AVERAGE",
			"DEF:dechit=$rrd:memc" . $e . "_dechit:AVERAGE",
			"DEF:decmis=$rrd:memc" . $e . "_decmis:AVERAGE",
			"DEF:gethit=$rrd:memc" . $e . "_gethit:AVERAGE",
			"DEF:getmis=$rrd:memc" . $e . "_getmis:AVERAGE",
			"DEF:delhit=$rrd:memc" . $e . "_delhit:AVERAGE",
			"DEF:delmis=$rrd:memc" . $e . "_delmis:AVERAGE",
			"CDEF:allvalues=inchit,incmis,dechit,decmis,gethit,getmis,delhit,delmis,+,+,+,+,+,+,+",
			@CDEF,
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			$uptimeline,
			"COMMENT: \\n");
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7]",
				"--title=$config->{graphs}->{_memcached1}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:inchit=$rrd:memc" . $e . "_inchit:AVERAGE",
				"DEF:incmis=$rrd:memc" . $e . "_incmis:AVERAGE",
				"DEF:dechit=$rrd:memc" . $e . "_dechit:AVERAGE",
				"DEF:decmis=$rrd:memc" . $e . "_decmis:AVERAGE",
				"DEF:gethit=$rrd:memc" . $e . "_gethit:AVERAGE",
				"DEF:getmis=$rrd:memc" . $e . "_getmis:AVERAGE",
				"DEF:delhit=$rrd:memc" . $e . "_delhit:AVERAGE",
				"DEF:delmis=$rrd:memc" . $e . "_delmis:AVERAGE",
				"CDEF:allvalues=inchit,incmis,dechit,decmis,gethit,getmis,delhit,delmis,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /memcached$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:autcmd#44EEEE:Auth cmds");
		push(@tmp, "GPRINT:autcmd:LAST:       Current\\: %4.1lf");
		push(@tmp, "GPRINT:autcmd:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:autcmd:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:autcmd:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:auterr#4444EE:Auth errors");
		push(@tmp, "GPRINT:auterr:LAST:     Current\\: %4.1lf");
		push(@tmp, "GPRINT:auterr:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:auterr:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:auterr:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:cashit#EEEE44:Cas hits");
		push(@tmp, "GPRINT:cashit:LAST:        Current\\: %4.1lf");
		push(@tmp, "GPRINT:cashit:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:cashit:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:cashit:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:casmis#FFA500:Cas misses");
		push(@tmp, "GPRINT:casmis:LAST:      Current\\: %4.1lf");
		push(@tmp, "GPRINT:casmis:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:casmis:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:casmis:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:casbad#EE4444:Cas badval");
		push(@tmp, "GPRINT:casbad:LAST:      Current\\: %4.1lf");
		push(@tmp, "GPRINT:casbad:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:casbad:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:casbad:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:cmdset#EE44EE:Cmd set");
		push(@tmp, "GPRINT:cmdset:LAST:         Current\\: %4.1lf");
		push(@tmp, "GPRINT:cmdset:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:cmdset:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:cmdset:MAX:   Max\\: %4.1lf\\n");
		push(@tmp, "LINE2:cmdfls#963C74:Cmd flush");
		push(@tmp, "GPRINT:cmdfls:LAST:       Current\\: %4.1lf");
		push(@tmp, "GPRINT:cmdfls:AVERAGE:   Average\\: %4.1lf");
		push(@tmp, "GPRINT:cmdfls:MIN:   Min\\: %4.1lf");
		push(@tmp, "GPRINT:cmdfls:MAX:   Max\\: %4.1lf\\n");
		push(@tmpz, "LINE2:autcmd#44EEEE:Auth cmd");
		push(@tmpz, "LINE2:auterr#4444EE:Auth errors");
		push(@tmpz, "LINE2:cashit#EEEE44:Cas hits");
		push(@tmpz, "LINE2:casmis#FFA500:Cas misses");
		push(@tmpz, "LINE2:casbad#EE4444:Cas badval");
		push(@tmpz, "LINE2:cmdset#EE44EE:Cmd set");
		push(@tmpz, "LINE2:cmdfls#963C74:Cmd flush");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 1]",
			"--title=$config->{graphs}->{_memcached2}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:autcmd=$rrd:memc" . $e . "_autcmd:AVERAGE",
			"DEF:auterr=$rrd:memc" . $e . "_auterr:AVERAGE",
			"DEF:cashit=$rrd:memc" . $e . "_cashit:AVERAGE",
			"DEF:casmis=$rrd:memc" . $e . "_casmis:AVERAGE",
			"DEF:casbad=$rrd:memc" . $e . "_casbad:AVERAGE",
			"DEF:cmdset=$rrd:memc" . $e . "_cmdset:AVERAGE",
			"DEF:cmdfls=$rrd:memc" . $e . "_cmdfls:AVERAGE",
			"CDEF:allvalues=autcmd,auterr,cashit,casmis,casbad,cmdset,cmdfls,+,+,+,+,+,+",
			@CDEF,
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			"COMMENT: \\n",
			"COMMENT: \\n",
			"COMMENT: \\n",
			"COMMENT: \\n");
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 1]",
				"--title=$config->{graphs}->{_memcached2}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:autcmd=$rrd:memc" . $e . "_autcmd:AVERAGE",
				"DEF:auterr=$rrd:memc" . $e . "_auterr:AVERAGE",
				"DEF:cashit=$rrd:memc" . $e . "_cashit:AVERAGE",
				"DEF:casmis=$rrd:memc" . $e . "_casmis:AVERAGE",
				"DEF:casbad=$rrd:memc" . $e . "_casbad:AVERAGE",
				"DEF:cmdset=$rrd:memc" . $e . "_cmdset:AVERAGE",
				"DEF:cmdfls=$rrd:memc" . $e . "_cmdfls:AVERAGE",
				"CDEF:allvalues=autcmd,auterr,cashit,casmis,casbad,cmdset,cmdfls,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /memcached$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 1] . "'>\n");
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
		push(@tmp, "AREA:bytes#44EEEE:Used");
		push(@tmp, "GPRINT:mb_perc:LAST:(%3.1lf%%)\\g");
		push(@tmp, "GPRINT:mb:LAST:           Current\\: %4.1lf\\n");
		push(@tmp, "LINE1:bytes#00EEEE");
		push(@tmpz, "AREA:bytes#44EEEE:Used");
		push(@tmpz, "LINE1:bytes#00EEEE");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 2]",
			"--title=$config->{graphs}->{_memcached3} (${cachesizemb}MB)  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Megabytes",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:bytes=$rrd:memc" . $e . "_bytes:AVERAGE",
			"DEF:limmxb=$rrd:memc" . $e . "_limmxb:AVERAGE",
			"CDEF:mb=bytes,1024,/,1024,/",
			"CDEF:mb_perc=bytes,100,*,limmxb,/",
			"CDEF:allvalues=bytes",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 2]",
				"--title=$config->{graphs}->{_memcached3} (${cachesizemb}MB)  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Megabytes",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:bytes=$rrd:memc" . $e . "_bytes:AVERAGE",
				"CDEF:allvalues=bytes",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /memcached$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 2] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[3], $limit[3])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:citems#44EEEE:Items");
		push(@tmp, "GPRINT:citems:LAST:                Current\\: %1.0lf\\n");
		push(@tmpz, "LINE2:citems#44EEEE:Items");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 3]",
			"--title=$config->{graphs}->{_memcached4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Items",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:citems=$rrd:memc" . $e . "_citems:AVERAGE",
			"CDEF:allvalues=citems",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 3]",
				"--title=$config->{graphs}->{_memcached4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Items",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:citems=$rrd:memc" . $e . "_citems:AVERAGE",
				"CDEF:allvalues=citems",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 3]: $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /memcached$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 3] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[4], $limit[4])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:titems#EEEE44:Items");
		push(@tmp, "GPRINT:titems:LAST:                Current\\: %3.1lf\\n");
		push(@tmp, "LINE2:evict#4444EE:Evictions");
		push(@tmp, "GPRINT:evict:LAST:            Current\\: %3.1lf\\n");
		push(@tmp, "LINE2:reclm#44EEEE:Reclaimed");
		push(@tmp, "GPRINT:reclm:LAST:            Current\\: %3.1lf\\n");
		push(@tmpz, "LINE2:titems#EEEE44:Items");
		push(@tmpz, "LINE2:evict#4444EE:Evictions");
		push(@tmpz, "LINE2:reclm#44EEEE:Reclaimed");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 4]",
			"--title=$config->{graphs}->{_memcached5}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:evict=$rrd:memc" . $e . "_evict:AVERAGE",
			"DEF:reclm=$rrd:memc" . $e . "_reclm:AVERAGE",
			"DEF:titems=$rrd:memc" . $e . "_titems:AVERAGE",
			"CDEF:allvalues=evict,reclm,titems,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 4]",
				"--title=$config->{graphs}->{_memcached5}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:evict=$rrd:memc" . $e . "_evict:AVERAGE",
				"DEF:reclm=$rrd:memc" . $e . "_reclm:AVERAGE",
				"DEF:titems=$rrd:memc" . $e . "_titems:AVERAGE",
				"CDEF:allvalues=evict,reclm,titems,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 4]: $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /memcached$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 4] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 4] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 4] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 4] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 4] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[5], $limit[5])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:tconn#4444EE:Total connections");
		push(@tmp, "GPRINT:tconn:LAST:    Current\\: %1.0lf\\n");
		push(@tmp, "LINE2:cconn#44EEEE:Connections now");
		push(@tmp, "GPRINT:cconn:LAST:      Current\\: %1.0lf\\n");
		push(@tmp, "LINE2:thrds#EE44EE:Threads");
		push(@tmp, "GPRINT:thrds:LAST:              Current\\: %1.0lf\\n");
		push(@tmpz, "LINE2:tconn#4444EE:Total connections");
		push(@tmpz, "LINE2:cconn#44EEEE:Connections");
		push(@tmpz, "LINE2:thrds#EE44EE:Threads");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 5]",
			"--title=$config->{graphs}->{_memcached6}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:tconn=$rrd:memc" . $e . "_tconn:AVERAGE",
			"DEF:cconn=$rrd:memc" . $e . "_cconn:AVERAGE",
			"DEF:thrds=$rrd:memc" . $e . "_thrds:AVERAGE",
			"CDEF:allvalues=tconn,cconn,thrds,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 5]",
				"--title=$config->{graphs}->{_memcached6}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:tconn=$rrd:memc" . $e . "_tconn:AVERAGE",
				"DEF:cconn=$rrd:memc" . $e . "_cconn:AVERAGE",
				"DEF:thrds=$rrd:memc" . $e . "_thrds:AVERAGE",
				"CDEF:allvalues=tconn,cconn,thrds,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 5]: $err\n") if $err;
		}
		$e2 = $e + 6;
		if($title || ($silent =~ /imagetag/ && $graph =~ /memcached$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 5] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 5] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 5] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 5] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 5] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[6], $limit[6])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:bread#44EE44:Bytes read");
		push(@tmp, "AREA:bwrit#4444EE:Bytes written");
		push(@tmp, "AREA:bwrit#4444EE:");
		push(@tmp, "AREA:bread#44EE44:");
		push(@tmp, "LINE1:bwrit#0000EE");
		push(@tmp, "LINE1:bread#00EE00");
		push(@tmpz, "AREA:bread#44EE44:Bytes read");
		push(@tmpz, "AREA:bwrit#4444EE:Bytes written");
		push(@tmpz, "AREA:bwrit#4444EE:");
		push(@tmpz, "AREA:bread#44EE44:");
		push(@tmpz, "LINE1:bwrit#0000EE");
		push(@tmpz, "LINE1:bread#00EE00");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 6]",
			"--title=$config->{graphs}->{_memcached7}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:bread=$rrd:memc" . $e . "_bread:AVERAGE",
			"DEF:bwrit=$rrd:memc" . $e . "_bwrit:AVERAGE",
			"CDEF:allvalues=bread,bwrit,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 6]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 6]",
				"--title=$config->{graphs}->{_memcached7}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:bread=$rrd:memc" . $e . "_bread:AVERAGE",
				"DEF:bwrit=$rrd:memc" . $e . "_bwrit:AVERAGE",
				"CDEF:allvalues=bread,bwrit,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 6]: $err\n") if $err;
		}
		$e2 = $e + 7;
		if($title || ($silent =~ /imagetag/ && $graph =~ /memcached$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 6] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 6] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 6] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 6] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 6] . "'>\n");
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
