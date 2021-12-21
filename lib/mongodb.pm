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

package mongodb;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(mongodb_init mongodb_update mongodb_cgi);

sub mongodb_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $mongodb = $config->{mongodb};

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;
	my $n2;

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
		if(scalar(@ds) / (35 + (($mongodb->{max_db} || 1) * 12)) != scalar(my @ml = split(',', $mongodb->{list}))) {
			logger("$myself: Detected size mismatch between 'list+max_db' (" . scalar(my @ml = split(',', $mongodb->{list})) . " + $mongodb->{max_db}) and $rrd (" . scalar(@ds) / (35 + (($mongodb->{max_db} || 1) * 12)) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @ml = split(',', $mongodb->{list})); $n++) {
			push(@tmp, "DS:mongodb" . $n . "_uptime:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_asserts:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_bf_avrgms:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_bf_lastms:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_conn_curr:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_conn_totc:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_dur_commi:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_dur_io:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_ei_heapus:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_ei_pgfalt:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_gbl_currq:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_gbl_actcl:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_net_in:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_net_out:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_net_req:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_op_ins:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_op_que:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_op_upd:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_op_del:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_op_get:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_op_com:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_doc_del:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_doc_ins:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_doc_ret:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_doc_upd:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_val01:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_val02:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_val03:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_val04:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_val05:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_val06:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_val07:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_val08:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_val09:GAUGE:120:0:U");
			push(@tmp, "DS:mongodb" . $n . "_val10:GAUGE:120:0:U");
			for($n2 = 0; $n2 < ($mongodb->{max_db} || 1); $n2++) {
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_colls:GAUGE:120:0:U");
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_objcs:GAUGE:120:0:U");
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_dsize:GAUGE:120:0:U");
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_ssize:GAUGE:120:0:U");
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_nexte:GAUGE:120:0:U");
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_index:GAUGE:120:0:U");
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_fsize:GAUGE:120:0:U");
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_val1:GAUGE:120:0:U");
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_val2:GAUGE:120:0:U");
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_val3:GAUGE:120:0:U");
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_val4:GAUGE:120:0:U");
				push(@tmp, "DS:mongodb" . $n . "_" . $n2 . "_val5:GAUGE:120:0:U");
			}
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

	$config->{mongodb_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub mongodb_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $mongodb = $config->{mongodb};

	my $str;
	my $n;
	my $rrdata = "N";

	for($n = 0; $n < scalar(my @ml = split(',', $mongodb->{list})); $n++) {
		my $uptime = 0;
		my $asserts = 0;
		my $asserts_sum = 0;
		my $bf_avrgms = 0;
		my $bf_lastms = 0;
		my $conn_curr = 0;
		my $conn_totc = 0;
		my $dur_commi = 0;
		my $dur_io = 0;
		my $ei_heapus = 0;
		my $ei_pgfalt = 0;
		my $gbl_currq = 0;
		my $gbl_actcl = 0;
		my $net_in = 0;
		my $net_out = 0;
		my $net_req = 0;
		my $op_ins = 0;
		my $op_que = 0;
		my $op_upd = 0;
		my $op_del = 0;
		my $op_get = 0;
		my $op_com = 0;
		my $doc_del = 0;
		my $doc_ins = 0;
		my $doc_ret = 0;
		my $doc_upd = 0;

		my $mongo = trim($ml[$n]);
		my $host = $mongodb->{desc}->{$mongo}->{host} || "";
		my $port = $mongodb->{desc}->{$mongo}->{port} || "";
		my $user = $mongodb->{desc}->{$mongo}->{username} || "";
		my $pass = $mongodb->{desc}->{$mongo}->{password} || "";
		my $cmd = "mongo ";
		$cmd .= "--host $host " if $host;
		$cmd .= "--port $port " if $port;
		$cmd .= "-u $user " if $user;
		$cmd .= "-p $pass " if $pass;
		$cmd .= "--eval \"printjson(db.serverStatus())\"";

		if(open(IN, "$cmd |")) {
			my @data = <IN>;
			close(IN);

			my $start = "";
			foreach(@data) {
				if(/"uptime"\s+:\s+(\d+),/) {
					$uptime = $1;
					next;
				}
				if(/"asserts"\s+:\s*{/) {
					$start = "asserts";
					next;
				}
				if($start eq "asserts") {
					if(/"regular"\s+:\s+(\d+),/) {
						$asserts_sum = $1;
						next;
					}
					if(/"warning"\s+:\s+(\d+),/) {
						$asserts_sum += $1;
						next;
					}
					if(/"msg"\s+:\s+(\d+),/) {
						$asserts_sum += $1;
						next;
					}
					if(/"user"\s+:\s+(\d+),/) {
						$asserts_sum += $1;
						next;
					}
					if(/"rollovers"\s+:\s+(\d+),/) {
						$asserts_sum += $1;
						$str = $n . "asserts";
						$asserts = $asserts_sum - ($config->{mongodb_hist}->{$str} || 0);
						$asserts = 0 unless $asserts != $asserts_sum;
						$asserts /= 60;
						$config->{mongodb_hist}->{$str} = $asserts_sum;
						$start = "";
						next;
					}
				}
				if(/"backgroundFlushing"\s+:\s*{/) {
					$start = "backgroundFlushing";
					next;
				}
				if($start eq "backgroundFlushing") {
					if(/"average_ms"\s+:\s+(\d+.*\d*),/) {
						$bf_avrgms = $1;
						next;
					}
					if(/"last_ms"\s+:\s+(\d+),/) {
						$bf_lastms = $1;
						$start = "";
						next;
					}
				}
				if(/"connections"\s+:\s*{/) {
					$start = "connections";
					next;
				}
				if($start eq "connections") {
					if(/"current"\s+:\s+(\d+),/) {
						$conn_curr = $1;
						next;
					}
					if(/"totalCreated"\s+:\s+NumberLong\((\d+)\)/) {
						$str = $n . "conn_totc";
						$conn_totc = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$conn_totc = 0 unless $conn_totc != $1;
						$conn_totc /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						$start = "";
						next;
					}
				}
				if(/"dur"\s+:\s*{/) {
					$start = "dur";
					next;
				}
				if($start eq "dur") {
					if(/"commits"\s+:\s+(\d+),/) {
						$dur_commi = $1;
						next;
					}
					if(/"journaledMB"\s+:\s+(\d+.*\d*),/) {
						$dur_io = $1;
						next;
					}
					if(/"writeToDataFilesMB"\s+:\s+(\d+.*\d*),/) {
						$dur_io += $1;
						$dur_io *= 1000000;	# (journaledMB + writeToDataFilesMB) * 1000000 in bytes
						$start = "";
						next;
					}
				}
				if(/"extra_info"\s+:\s*{/) {
					$start = "extra_info";
					next;
				}
				if($start eq "extra_info") {
					if(/"heap_usage_bytes"\s+:\s+(\d+),/) {
						$ei_heapus = $1;
						next;
					}
					if(/"page_faults"\s+:\s+(\d+)/) {
						$ei_pgfalt = $1;
						$start = "";
						next;
					}
				}
				if(/"globalLock"\s+:\s*{/) {
					$start = "globalLock";
					next;
				}
				if($start eq "globalLock") {
					if(/"currentQueue"\s+:\s*{/) {
						$start = "globalLock.currentQueue";
						next;
					}
				}
				if($start eq "globalLock.currentQueue") {
					if(/"total"\s+:\s+(\d+),/) {
						$gbl_currq = $1;
						$start = "globalLock";
						next;
					}
				}
				if($start eq "globalLock") {
					if(/"activeClients"\s+:\s*{/) {
						$start = "globalLock.activeClients";
						next;
					}
				}
				if($start eq "globalLock.activeClients") {
					if(/"total"\s+:\s+(\d+),/) {
						$gbl_actcl = $1;
						$start = "";
						next;
					}
				}
				if(/"network"\s+:\s*{/) {
					$start = "network";
					next;
				}
				if($start eq "network") {
					if(/"bytesIn"\s+:\s+(\d+),/) {
						$str = $n . "net_in";
						$net_in = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$net_in = 0 unless $net_in != $1;
						$net_in /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						next;
					}
					if(/"bytesOut"\s+:\s+(\d+),/) {
						$str = $n . "net_out";
						$net_out = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$net_out = 0 unless $net_out != $1;
						$net_out /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						next;
					}
					if(/"numRequests"\s+:\s+(\d+)/) {
						$str = $n . "net_req";
						$net_req = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$net_req = 0 unless $net_req != $1;
						$net_req /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						$start = "";
						next;
					}
				}
				if(/"opcounters"\s+:\s*{/) {
					$start = "opcounters";
					next;
				}
				if($start eq "opcounters") {
					if(/"insert"\s+:\s+(\d+),/) {
						$str = $n . "op_ins";
						$op_ins = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$op_ins = 0 unless $op_ins != $1;
						$op_ins /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						next;
					}
					if(/"query"\s+:\s+(\d+),/) {
						$str = $n . "op_que";
						$op_que = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$op_que = 0 unless $op_que != $1;
						$op_que /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						next;
					}
					if(/"update"\s+:\s+(\d+),/) {
						$str = $n . "op_upd";
						$op_upd = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$op_upd = 0 unless $op_upd != $1;
						$op_upd /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						next;
					}
					if(/"delete"\s+:\s+(\d+),/) {
						$str = $n . "op_del";
						$op_del = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$op_del = 0 unless $op_del != $1;
						$op_del /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						next;
					}
					if(/"getmore"\s+:\s+(\d+),/) {
						$str = $n . "op_get";
						$op_get = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$op_get = 0 unless $op_get != $1;
						$op_get /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						next;
					}
					if(/"command"\s+:\s+(\d+)/) {
						$str = $n . "op_com";
						$op_com = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$op_com = 0 unless $op_com != $1;
						$op_com /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						$start = "";
						next;
					}
				}
				if(/"metrics"\s+:\s*{/) {
					$start = "metrics";
					next;
				}
				if($start eq "metrics") {
					if(/"document"\s+:\s*{/) {
						$start = "metrics.document";
						next;
					}
				}
				if($start eq "metrics.document") {
					if(/"deleted"\s+:\s+NumberLong\((\d+)\),/) {
						$str = $n . "doc_del";
						$doc_del = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$doc_del = 0 unless $doc_del != $1;
						$doc_del /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						next;
					}
					if(/"inserted"\s+:\s+NumberLong\((\d+)\),/) {
						$str = $n . "doc_ins";
						$doc_ins = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$doc_ins = 0 unless $doc_ins != $1;
						$doc_ins /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						next;
					}
					if(/"returned"\s+:\s+NumberLong\((\d+)\),/) {
						$str = $n . "doc_ret";
						$doc_ret = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$doc_ret = 0 unless $doc_ret != $1;
						$doc_ret /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						next;
					}
					if(/"updated"\s+:\s+NumberLong\((\d+)\)/) {
						$str = $n . "doc_upd";
						$doc_upd = $1 - ($config->{mongodb_hist}->{$str} || 0);
						$doc_upd = 0 unless $doc_upd != $1;
						$doc_upd /= 60;
						$config->{mongodb_hist}->{$str} = $1;
						$start = "";
						next;
					}
				}


			}
		} else {
			logger("$myself: unable to execute '$cmd'. $!");
		}

		$rrdata .= ":$uptime:$asserts:$bf_avrgms:$bf_lastms:$conn_curr:$conn_totc:$dur_commi:$dur_io:$ei_heapus:$ei_pgfalt:$gbl_currq:$gbl_actcl:$net_in:$net_out:$net_req:$op_ins:$op_que:$op_upd:$op_del:$op_get:$op_com:$doc_del:$doc_ins:$doc_ret:$doc_upd:0:0:0:0:0:0:0:0:0:0";

		my $e = 0;
		while($e < scalar(my @dbl = split(',', $mongodb->{desc}->{$mongo}->{db_list}))) {
			my $colls = 0;
			my $objcs = 0;
			my $dsize = 0;
			my $ssize = 0;
			my $nexte = 0;
			my $index = 0;
			my $fsize = 0;
			my $val1 = 0;
			my $val2 = 0;
			my $val3 = 0;
			my $val4 = 0;
			my $val5 = 0;

			my $db = trim($dbl[$e]);
			my $cmd = "mongo ";
			$cmd .= "--host $host " if $host;
			$cmd .= "--port $port " if $port;
			$cmd .= "--eval \"printjson(db.stats(1))\" $db";

			if(open(IN, "$cmd |")) {
				my @data = <IN>;
				close(IN);

				foreach(@data) {
					if(/"collections"\s+:\s+(\d+),/) {
						$colls = $1;
						next;
					}
					if(/"objects"\s+:\s+(\d+),/) {
						$objcs = $1;
						next;
					}
					if(/"dataSize"\s+:\s+(\d+),/) {
						$dsize = $1;
						next;
					}
					if(/"storageSize"\s+:\s+(\d+),/) {
						$ssize = $1;
						next;
					}
					if(/"numExtents"\s+:\s+(\d+),/) {
						$nexte = $1;
						next;
					}
					if(/"indexes"\s+:\s+(\d+),/) {
						$index = $1;
						next;
					}
					if(/"fileSize"\s+:\s+(\d+),/) {
						$fsize = $1;
						next;
					}

				}
			} else {
				logger("$myself: unable to execute '$cmd'. $!");
			}
			$rrdata .= ":$colls:$objcs:$dsize:$ssize:$nexte:$index:$fsize:0:0:0:0:0";
			$e++;
		}

		while($e < $mongodb->{max_db}) {
			$rrdata .= ":0:0:0:0:0:0:0:0:0:0:0:0";
			$e++;
		}
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub mongodb_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $mongodb = $config->{mongodb};
	my @rigid = split(',', ($mongodb->{rigid} || ""));
	my @limit = split(',', ($mongodb->{limit} || ""));
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
		my $line0;
		my $line1;
		my $line2;
		my $line3;
		my $n2;
		my $mongo;
		my $host;
		my $port;
		my $m;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		for($n = 0; $n < scalar(my @ml = split(',', $mongodb->{list})); $n++) {
			$line0 = "                                                                                                                                                                                                                                                  ";
			$line1 .= "  Asserts  BgFl_Avg BgFl_Last Conn_Curr Conn_TotC Dur_Comm Dur_IO_MB EI_Heap_Usg EI_PgFlt Gbl_CurrQu Gbl_ActCli  Net_Input Net_Output Net_Reqs OpCnt_Ins OpCnt_Que OpCnt_Upd OpCnt_Del OpCnt_Get OpCnt_Com MtDoc_del MtDoc_Ins MtDoc_Ret MtDoc_Upd";
			$line2 .= "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
			$mongo = trim($ml[$n]);
			$host = $mongodb->{desc}->{$mongo}->{host} || "";
			$port = $mongodb->{desc}->{$mongo}->{port} || "";
			for($n2 = 0; $n2 < scalar(my @dbl = split(',', $mongodb->{desc}->{$mongo}->{db_list})); $n2++) {
				my $db = trim($dbl[$n2]);
				my $i;
				$line1 .= "  Colls  Objects  Data_Size  Stor_Size Num_Ex Indexes   File_Size";
				$line2 .= "-----------------------------------------------------------------";
				$i = length($line1) if(!$n2);
				$m = length($line1) if(!$n2);
				$i = length($line1) - $i if($n2);
				$m += length($line1) - $i if($n2);
				$line3 .= sprintf("%${i}s", sprintf("DB: %s", $db));
			}
		}
		push(@output, sprintf(sprintf("%${m}s\n", sprintf("%s - (%s:%s)", $mongo, $host, $port))));
		push(@output, "    $line3\n");
		push(@output, "Time$line1\n");
		push(@output, "----$line2 \n");
		my $line;
		my @row;
		my $time;
		my $from;
		my $to;
		my $n3;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			my (undef, $asserts, $bf_avg, $bf_lastms, $conn_curr, $conn_totc, $dur_commi, $dur_io, $ei_heapus, $ei_pgfalt, $gbl_currq, $gbl_actcl, $net_in, $net_out, $net_req, $op_ins, $op_que, $op_upd, $op_del, $op_get, $op_com, $doc_del, $doc_ins, $doc_ret, $doc_upd) = @$line;

			$bf_avg /= 1000000;
			$bf_lastms /= 1000000;
			push(@output, sprintf(" %2d$tf->{tc}  %7d %9.6f %9.6f %9d %9d %8d %9d  %10d %8d %10d %10d %10d %10d %8d %9d %9d %9d %9d %9d %9d %9d %9d %9d %9d X", $time, $asserts, $bf_avg, $bf_lastms, $conn_curr, $conn_totc, $dur_commi, $dur_io, $ei_heapus, $ei_pgfalt, $gbl_currq, $gbl_actcl, $net_in, $net_out, $net_req, $op_ins, $op_que, $op_upd, $op_del, $op_get, $op_com, $doc_del, $doc_ins, $doc_ret, $doc_upd));
			for($n2 = 0; $n2 < scalar(my @ml = split(',', $mongodb->{list})); $n2++) {
				$mongo = trim($ml[$n2]);
				$from = (35 + 12) * $n2;
				$from += 35;
				for($n3 = 0; $n3 < scalar(my @dbl = split(',', $mongodb->{desc}->{$mongo}->{db_list})); $n3++) {
					$from += ($n3 * 12);
					$to = $from + 12;
					my ($colls, $objcs, $dsize, $ssize, $nexte, $index, $fsize) = @$line[$from..$to];
					push(@output, sprintf(" %4d %8d  %9d %10d %6d %7d %11d", $colls, $objcs, $dsize, $ssize, $nexte, $index, $fsize));
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

	for($n = 0; $n < scalar(my @ml = split(',', $mongodb->{list})); $n++) {
		for($n2 = 1; $n2 <= 6; $n2++) {
			my $str = $u . $package . $n . $n2 . "." . $tf->{when} . ".$imgfmt_lc";
			push(@IMG, $str);
			unlink("$IMG_DIR" . $str);
			if(lc($config->{enable_zoom}) eq "y") {
				my $str = $u . $package . $n . $n2 . "z." . $tf->{when} . ".$imgfmt_lc";
				push(@IMGz, $str);
				unlink("$IMG_DIR" . $str);
			}
		}
		my $n3;
		my $mongo = trim($ml[$n]);
		for($n3 = 0; $n3 < scalar(my @dbl = split(',', $mongodb->{desc}->{$mongo}->{db_list})); $n3++) {
			my $str = $u . $package . $n . $n2 . "." . $tf->{when} . ".$imgfmt_lc";
			push(@IMG, $str);
			unlink("$IMG_DIR" . $str);
			if(lc($config->{enable_zoom}) eq "y") {
				my $str = $u . $package . $n . $n2 . "z." . $tf->{when} . ".$imgfmt_lc";
				push(@IMGz, $str);
				unlink("$IMG_DIR" . $str);
			}
			$str = $u . $package . $n . ($n2 + 1) . "." . $tf->{when} . ".$imgfmt_lc";
			push(@IMG, $str);
			unlink("$IMG_DIR" . $str);
			if(lc($config->{enable_zoom}) eq "y") {
				my $str = $u . $package . $n . ($n2 + 1) . "z." . $tf->{when} . ".$imgfmt_lc";
				push(@IMGz, $str);
				unlink("$IMG_DIR" . $str);
			}
			$n2 += 2;
		}
	}

	$e = 0;
	foreach my $db (my @ml = split(',', $mongodb->{list})) {
		my $mongo = trim($db);

		if($e) {
			push(@output, "  <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:insert#44EE44:Insert");
		push(@tmp, "GPRINT:insert:LAST:       Cur\\: %5.1lf");
		push(@tmp, "GPRINT:insert:AVERAGE:    Avg\\: %5.1lf");
		push(@tmp, "GPRINT:insert:MIN:    Min\\: %5.1lf");
		push(@tmp, "GPRINT:insert:MAX:    Max\\: %5.1lf\\n");
		push(@tmp, "LINE2:query#EEEE44:Query");
		push(@tmp, "GPRINT:query:LAST:        Cur\\: %5.1lf");
		push(@tmp, "GPRINT:query:AVERAGE:    Avg\\: %5.1lf");
		push(@tmp, "GPRINT:query:MIN:    Min\\: %5.1lf");
		push(@tmp, "GPRINT:query:MAX:    Max\\: %5.1lf\\n");
		push(@tmp, "LINE2:update#EE44EE:Update");
		push(@tmp, "GPRINT:update:LAST:       Cur\\: %5.1lf");
		push(@tmp, "GPRINT:update:AVERAGE:    Avg\\: %5.1lf");
		push(@tmp, "GPRINT:update:MIN:    Min\\: %5.1lf");
		push(@tmp, "GPRINT:update:MAX:    Max\\: %5.1lf\\n");
		push(@tmp, "LINE2:delete#EE4444:Delete");
		push(@tmp, "GPRINT:delete:LAST:       Cur\\: %5.1lf");
		push(@tmp, "GPRINT:delete:AVERAGE:    Avg\\: %5.1lf");
		push(@tmp, "GPRINT:delete:MIN:    Min\\: %5.1lf");
		push(@tmp, "GPRINT:delete:MAX:    Max\\: %5.1lf\\n");
		push(@tmp, "LINE2:getmore#44EEEE:Getmore");
		push(@tmp, "GPRINT:getmore:LAST:      Cur\\: %5.1lf");
		push(@tmp, "GPRINT:getmore:AVERAGE:    Avg\\: %5.1lf");
		push(@tmp, "GPRINT:getmore:MIN:    Min\\: %5.1lf");
		push(@tmp, "GPRINT:getmore:MAX:    Max\\: %5.1lf\\n");
		push(@tmp, "LINE2:command#4444EE:Command");
		push(@tmp, "GPRINT:command:LAST:      Cur\\: %5.1lf");
		push(@tmp, "GPRINT:command:AVERAGE:    Avg\\: %5.1lf");
		push(@tmp, "GPRINT:command:MIN:    Min\\: %5.1lf");
		push(@tmp, "GPRINT:command:MAX:    Max\\: %5.1lf\\n");
		push(@tmpz, "LINE2:insert#44EE44:Insert");
		push(@tmpz, "LINE2:query#EEEE44:Query");
		push(@tmpz, "LINE2:update#EE44EE:Update");
		push(@tmpz, "LINE2:delete#EE4444:Delete");
		push(@tmpz, "LINE2:getmore#44EEEE:Getmore");
		push(@tmpz, "LINE2:command#4444EE:Command");
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
			"--title=$config->{graphs}->{_mongodb1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Operations/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:insert=$rrd:mongodb" . $e . "_op_ins:AVERAGE",
			"DEF:query=$rrd:mongodb" . $e . "_op_que:AVERAGE",
			"DEF:update=$rrd:mongodb" . $e . "_op_upd:AVERAGE",
			"DEF:delete=$rrd:mongodb" . $e . "_op_del:AVERAGE",
			"DEF:getmore=$rrd:mongodb" . $e . "_op_get:AVERAGE",
			"DEF:command=$rrd:mongodb" . $e . "_op_com:AVERAGE",
			"CDEF:allvalues=insert,query,update,delete,getmore,command,+,+,+,+,+",
			@CDEF,
			@tmp,
			"COMMENT: \\n");
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6]",
				"--title=$config->{graphs}->{_mongodb1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Operations/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:insert=$rrd:mongodb" . $e . "_op_ins:AVERAGE",
				"DEF:query=$rrd:mongodb" . $e . "_op_que:AVERAGE",
				"DEF:update=$rrd:mongodb" . $e . "_op_upd:AVERAGE",
				"DEF:delete=$rrd:mongodb" . $e . "_op_del:AVERAGE",
				"DEF:getmore=$rrd:mongodb" . $e . "_op_get:AVERAGE",
				"DEF:command=$rrd:mongodb" . $e . "_op_com:AVERAGE",
				"CDEF:allvalues=insert,query,update,delete,getmore,command,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mongodb$e2/)) {
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
		push(@tmp, "LINE2:deleted#EE4444:Deleted");
		push(@tmp, "GPRINT:deleted:LAST:      Cur\\: %5.1lf");
		push(@tmp, "GPRINT:deleted:AVERAGE:   Avg\\: %5.1lf");
		push(@tmp, "GPRINT:deleted:MIN:   Min\\: %5.1lf");
		push(@tmp, "GPRINT:deleted:MAX:   Max\\: %5.1lf\\n");
		push(@tmp, "LINE2:inserted#44EE44:Inserted");
		push(@tmp, "GPRINT:inserted:LAST:     Cur\\: %5.1lf");
		push(@tmp, "GPRINT:inserted:AVERAGE:   Avg\\: %5.1lf");
		push(@tmp, "GPRINT:inserted:MIN:   Min\\: %5.1lf");
		push(@tmp, "GPRINT:inserted:MAX:   Max\\: %5.1lf\\n");
		push(@tmp, "LINE2:returned#EEEE44:Returned");
		push(@tmp, "GPRINT:returned:LAST:     Cur\\: %5.1lf");
		push(@tmp, "GPRINT:returned:AVERAGE:   Avg\\: %5.1lf");
		push(@tmp, "GPRINT:returned:MIN:   Min\\: %5.1lf");
		push(@tmp, "GPRINT:returned:MAX:   Max\\: %5.1lf\\n");
		push(@tmp, "LINE2:updated#EE44EE:Updated");
		push(@tmp, "GPRINT:updated:LAST:      Cur\\: %5.1lf");
		push(@tmp, "GPRINT:updated:AVERAGE:   Avg\\: %5.1lf");
		push(@tmp, "GPRINT:updated:MIN:   Min\\: %5.1lf");
		push(@tmp, "GPRINT:updated:MAX:   Max\\: %5.1lf\\n");
		push(@tmpz, "LINE2:deleted#EE4444:Deleted");
		push(@tmpz, "LINE2:inserted#44EE44:Inserted");
		push(@tmpz, "LINE2:returned#EEEE44:Returned");
		push(@tmpz, "LINE2:updated#EE44EE:Updated");
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
			"--title=$config->{graphs}->{_mongodb2}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:deleted=$rrd:mongodb" . $e . "_doc_del:AVERAGE",
			"DEF:inserted=$rrd:mongodb" . $e . "_doc_ins:AVERAGE",
			"DEF:returned=$rrd:mongodb" . $e . "_doc_ret:AVERAGE",
			"DEF:updated=$rrd:mongodb" . $e . "_doc_upd:AVERAGE",
			"CDEF:allvalues=deleted,inserted,returned,updated,+,+,+",
			@CDEF,
			@tmp,
			"COMMENT: \\n");
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 1]",
				"--title=$config->{graphs}->{_mongodb2}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:deleted=$rrd:mongodb" . $e . "_doc_del:AVERAGE",
				"DEF:inserted=$rrd:mongodb" . $e . "_doc_ins:AVERAGE",
				"DEF:returned=$rrd:mongodb" . $e . "_doc_ret:AVERAGE",
				"DEF:updated=$rrd:mongodb" . $e . "_doc_upd:AVERAGE",
				"CDEF:allvalues=deleted,inserted,returned,updated,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mongodb$e2/)) {
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
		push(@tmp, "LINE2:average#44EEEE:Average (in ms)");
		push(@tmp, "GPRINT:average:LAST:      Current\\: %4.0lf\\n");
		push(@tmp, "LINE2:last#EE44EE:Last flush (in ms)");
		push(@tmp, "GPRINT:last:LAST:   Current\\: %4.0lf\\n");
		push(@tmpz, "LINE2:average#44EEEE:Average (in ms)");
		push(@tmpz, "LINE2:last#EE44EE:Last flush (in ms)");
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
			"--title=$config->{graphs}->{_mongodb3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=ms",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:average=$rrd:mongodb" . $e . "_bf_avrgms:AVERAGE",
			"DEF:last=$rrd:mongodb" . $e . "_bf_lastms:AVERAGE",
			"CDEF:allvalues=average,last,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 2]",
				"--title=$config->{graphs}->{_mongodb3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=ms",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:average=$rrd:mongodb" . $e . "_bf_avrgms:AVERAGE",
				"DEF:last=$rrd:mongodb" . $e . "_bf_lastms:AVERAGE",
				"CDEF:allvalues=average,last,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mongodb$e2/)) {
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
		push(@tmp, "LINE2:conns#44EEEE:Connections");
		push(@tmp, "GPRINT:conns:LAST:          Current\\: %4.0lf\\n");
		push(@tmp, "LINE2:total#EE44EE:Connections/s");
		push(@tmp, "GPRINT:total:LAST:        Current\\: %4.0lf\\n");
		push(@tmpz, "LINE2:conns#44EEEE:Connections");
		push(@tmpz, "LINE2:total#EE44EE:Connections/s");
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
			"--title=$config->{graphs}->{_mongodb4}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:conns=$rrd:mongodb" . $e . "_conn_curr:AVERAGE",
			"DEF:total=$rrd:mongodb" . $e . "_conn_totc:AVERAGE",
			"CDEF:allvalues=conns,total,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 3]",
				"--title=$config->{graphs}->{_mongodb4}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:conns=$rrd:mongodb" . $e . "_conn_curr:AVERAGE",
				"DEF:total=$rrd:mongodb" . $e . "_conn_totc:AVERAGE",
				"CDEF:allvalues=conns,total,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 3]: $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mongodb$e2/)) {
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
		push(@tmp, "LINE2:reqs#44EEEE:Requests");
		push(@tmp, "GPRINT:reqs:LAST:             Current\\: %4.0lf\\n");
		push(@tmp, "LINE2:asserts#EE44EE:Asserts");
		push(@tmp, "GPRINT:asserts:LAST:              Current\\: %4.0lf\\n");
		push(@tmpz, "LINE2:reqs#44EEEE:Requests");
		push(@tmpz, "LINE2:asserts#EE44EE:Asserts");
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
			"--title=$config->{graphs}->{_mongodb5}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:reqs=$rrd:mongodb" . $e . "_net_req:AVERAGE",
			"DEF:asserts=$rrd:mongodb" . $e . "_asserts:AVERAGE",
			"CDEF:allvalues=reqs,asserts,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 4]",
				"--title=$config->{graphs}->{_mongodb5}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:reqs=$rrd:mongodb" . $e . "_net_req:AVERAGE",
				"DEF:asserts=$rrd:mongodb" . $e . "_asserts:AVERAGE",
				"CDEF:allvalues=reqs,asserts,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 4]: $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mongodb$e2/)) {
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 5]",
			"--title=$config->{graphs}->{_mongodb6}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:in=$rrd:mongodb" . $e . "_net_in:AVERAGE",
			"DEF:out=$rrd:mongodb" . $e . "_net_out:AVERAGE",
			"CDEF:allvalues=in,out,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 5]",
				"--title=$config->{graphs}->{_mongodb6}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:in=$rrd:mongodb" . $e . "_net_in:AVERAGE",
				"DEF:out=$rrd:mongodb" . $e . "_net_out:AVERAGE",
				"CDEF:allvalues=in,out,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 5]: $err\n") if $err;
		}
		$e2 = $e + 6;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mongodb$e2/)) {
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


		# the following graphs will show the DBs monitored

		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
			push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
			push(@output, "       <font size='-1'>\n");
			push(@output, "        <b style='{color: " . $colors->{title_fg_color} . "}'>&nbsp;&nbsp;$mongo</b>\n");
			push(@output, "       </font></font>\n");
			push(@output, "      </td>\n");
			push(@output, "    </tr>\n");

			push(@output, "  </table>\n");
			push(@output, "  <table cellspacing='5' cellpadding='0' width='1' bgcolor='$colors->{graph_bg_color}' border='1'>\n");
		}

		my $e3 = 0;
		$e2 = 6;
		while($e3 < scalar(my @dbl = split(',', $mongodb->{desc}->{$mongo}->{db_list}))) {
			$str = trim($dbl[$e3]);

			if($title) {
				push(@output, "    <tr>\n");
				push(@output, "    <td>\n");
			}

			@riglim = @{setup_riglim($rigid[$e * 6 + $e2], $limit[$e * 6 + $e2])};
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			push(@tmp, "LINE2:colls#44EEEE:Collections");
			push(@tmp, "GPRINT:colls:LAST:                    Current\\: %5.1lf%S\\n");
			push(@tmp, "LINE2:nexte#EE44EE:Num. extents");
			push(@tmp, "GPRINT:nexte:LAST:                   Current\\: %5.1lf%S\\n");
			push(@tmp, "LINE2:index#EEEE44:Indexes");
			push(@tmp, "GPRINT:index:LAST:                        Current\\: %5.1lf%S\\n");
			push(@tmpz, "LINE2:colls#44EEEE:Collections");
			push(@tmpz, "LINE2:nexte#EE44EE:Num. extents");
			push(@tmpz, "LINE2:index#EEEE44:Indexes");
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{medium2});
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
				@tmp = @tmpz;
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + $e2]",
				"--title=DB: $str  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Values",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:colls=$rrd:mongodb" . $e . "_" . $e3 . "_colls:AVERAGE",
				"DEF:nexte=$rrd:mongodb" . $e . "_" . $e3 . "_nexte:AVERAGE",
				"DEF:index=$rrd:mongodb" . $e . "_" . $e3 . "_index:AVERAGE",
				"CDEF:allvalues=colls,nexte,index,+,+",
				@CDEF,
				@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + $e2]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + $e2]",
					"--title=DB: $str  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=Values",
					"--width=$width",
					"--height=$height",
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$cgi->{version12_small}},
					@{$colors->{graph_colors}},
					"DEF:colls=$rrd:mongodb" . $e . "_" . $e3 . "_colls:AVERAGE",
					"DEF:nexte=$rrd:mongodb" . $e . "_" . $e3 . "_nexte:AVERAGE",
					"DEF:index=$rrd:mongodb" . $e . "_" . $e3 . "_index:AVERAGE",
					"CDEF:allvalues=colls,nexte,index,+,+",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + $e2]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /mongodb/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "'>\n");
				}
			}

			if($title) {
				push(@output, "    </td>\n");
				push(@output, "    <td>\n");
			}

			$e2++;
			@riglim = @{setup_riglim($rigid[$e * 6 + $e2], $limit[$e * 6 + $e2])};
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			push(@tmp, "LINE2:dsize#44EEEE:dataSize");
			push(@tmp, "GPRINT:dsize:LAST:                       Current\\: %6.1lf%S\\n");
			push(@tmp, "LINE2:ssize#EE44EE:storageSize");
			push(@tmp, "GPRINT:ssize:LAST:                    Current\\: %6.1lf%S\\n");
			push(@tmp, "LINE2:fsize#EEEE44:fileSize");
			push(@tmp, "GPRINT:fsize:LAST:                       Current\\: %6.1lf%S\\n");
			push(@tmpz, "LINE2:dsize#44EEEE:dataSize");
			push(@tmpz, "LINE2:ssize#EE44EE:storageSize");
			push(@tmpz, "LINE2:fsize#EEEE44:fileSize");
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{medium2});
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
				@tmp = @tmpz;
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + $e2]",
				"--title=DB: $str  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=bytes",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:dsize=$rrd:mongodb" . $e . "_" . $e3 . "_dsize:AVERAGE",
				"DEF:ssize=$rrd:mongodb" . $e . "_" . $e3 . "_ssize:AVERAGE",
				"DEF:fsize=$rrd:mongodb" . $e . "_" . $e3 . "_fsize:AVERAGE",
				"CDEF:allvalues=dsize,ssize,fsize,+,+",
				@CDEF,
				@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + $e2]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + $e2]",
					"--title=DB: $str  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=bytes",
					"--width=$width",
					"--height=$height",
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$cgi->{version12_small}},
					@{$colors->{graph_colors}},
					"DEF:dsize=$rrd:mongodb" . $e . "_" . $e3 . "_dsize:AVERAGE",
					"DEF:ssize=$rrd:mongodb" . $e . "_" . $e3 . "_ssize:AVERAGE",
					"DEF:fsize=$rrd:mongodb" . $e . "_" . $e3 . "_fsize:AVERAGE",
					"CDEF:allvalues=dsize,ssize,fsize,+,+",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + $e2]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /mongodb/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + $e2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + $e2] . "'>\n");
				}
			}
			if($title) {
				push(@output, "    </td>\n");
				push(@output, "    </tr>\n");
			}
			$e2++;
			$e3++;
		}
		$e++;
	}

	if($title) {
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
