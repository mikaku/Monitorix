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

package mysql;

use strict;
use warnings;
use Monitorix;
use RRDs;
use DBI;
use Exporter 'import';
our @EXPORT = qw(mysql_init mysql_update mysql_cgi);

sub mysql_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $mysql = $config->{mysql};

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	if(!grep {$_ eq lc($mysql->{conn_type})} ("host", "socket")) {
		logger("$myself: ERROR: invalid value in 'conn_type' option.");
		return;
	}

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
		if(scalar(@ds) / 38 != scalar(my @ml = split(',', $mysql->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @ml = split(',', $mysql->{list})) . ") and $rrd (" . scalar(@ds) / 38 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @ml = split(',', $mysql->{list})); $n++) {
			push(@tmp, "DS:mysql" . $n . "_queries:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_sq:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_tchr:GAUGE:120:0:100");
			push(@tmp, "DS:mysql" . $n . "_qcu:GAUGE:120:0:100");
			push(@tmp, "DS:mysql" . $n . "_ot:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_conns_u:GAUGE:120:0:100");
			push(@tmp, "DS:mysql" . $n . "_conns:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_tlw:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_kbu:GAUGE:120:0:100");
			push(@tmp, "DS:mysql" . $n . "_innbu:GAUGE:120:0:100");
			push(@tmp, "DS:mysql" . $n . "_csel:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_ccom:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_cdel:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_cins:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_cinss:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_cupd:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_crep:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_creps:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_crol:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_acli:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_acon:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_brecv:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_bsent:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_qchr:GAUGE:120:0:100");
			push(@tmp, "DS:mysql" . $n . "_cstmtex:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_tttd:GAUGE:120:0:100");
			push(@tmp, "DS:mysql" . $n . "_val04:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_val05:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_val06:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_val07:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_val08:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_val09:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_val10:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_val11:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_val12:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_val13:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_val14:GAUGE:120:0:U");
			push(@tmp, "DS:mysql" . $n . "_val15:GAUGE:120:0:U");
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

	# Since 3.0.0 the new values are used (Query_cache_hit_rate, Com_stmt_execute)
	for($n = 0; $n < scalar(my @ml = split(',', $mysql->{list})); $n++) {
		RRDs::tune($rrd,
			"--data-source-rename=mysql" . $n . "_val01:mysql" . $n . "_qchr",
			"--data-source-rename=mysql" . $n . "_val02:mysql" . $n . "_cstmtex",
			"--data-source-rename=mysql" . $n . "_val03:mysql" . $n . "_tttd",
			"--maximum=mysql" . $n . "_qchr:100",
			"--maximum=mysql" . $n . "_tttd:100",
		);
	}

	$config->{mysql_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub mysql_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $mysql = $config->{mysql};

	my $str;
	my $n = 0;
	my $rrdata = "N";

	my $print_error = 0;
	$print_error = 1 if $debug;

	for($n = 0; $n < scalar(my @ml = split(',', $mysql->{list})); $n++) {
		$ml[$n] = trim($ml[$n]);
		my $host = $ml[$n];
		my $sock = $ml[$n];
		my $port = trim((split(',', $mysql->{desc}->{$ml[$n]}))[0]);
		my $user = trim((split(',', $mysql->{desc}->{$ml[$n]}))[1]);
		my $pass = trim((split(',', $mysql->{desc}->{$ml[$n]}))[2]);
		my $dbh;
		if(lc($mysql->{conn_type}) eq "host") {
			unless ($host && $port && $user && $pass) {
				logger("$myself: ERROR: undefined configuration in 'host' connection.");
				next;
			}
			$dbh = DBI->connect(
				"DBI:mysql:host=$host;port=$port",
				$user,
				$pass,
				{ PrintError => $print_error, }
			) or logger("$myself: Cannot connect to MySQL '$host:$port'.") and next;
		}
		if(lc($mysql->{conn_type}) eq "socket") {
			unless ($sock) {
				logger("$myself: ERROR: undefined configuration in 'socket' connection");
				next;
			}
			$dbh = DBI->connect(
				"DBI:mysql:mysql_socket=$sock",
				$user,
				$pass,
				{ PrintError => $print_error, }
			) or logger("$myself: Cannot connect to MySQL '$sock'.") and next;
		}

		# SHOW GLOBAL STATUS
		my $aborted_clients = 0;
		my $aborted_connects = 0;
		my $connections = 0;
		my $connections_real = 0;
		my $innodb_buffer_pool_pages_free = 0;
		my $innodb_buffer_pool_pages_total = 0;
		my $key_blocks_used = 0;
		my $key_blocks_unused = 0;
		my $max_used_connections = 0;
		my $qcache_free_memory = 0;
		my $qcache_hits = 0;
		my $qcache_inserts = 0;
		my $queries = 0;
		my $opened_tables = 0;
		my $slow_queries = 0;
		my $table_locks_waited = 0;
		my $threads_created = 0;
		my $created_tmp_disk_tables = 0;
		my $created_tmp_tables = 0;

		my $bytes_received = 0;
		my $bytes_sent = 0;
		my $com_commit = 0;
		my $com_delete = 0;
		my $com_insert = 0;
		my $com_insert_s = 0;
		my $com_replace = 0;
		my $com_replace_s = 0;
		my $com_rollback = 0;
		my $Com_select = 0;
		my $com_select = 0;
		my $com_update = 0;
		my $com_stmtex = 0;
		my $sql = "show global status";
		my $sth = $dbh->prepare($sql);
		$sth->execute;
		while(my ($name, $value) = $sth->fetchrow_array) {
			if($name eq "Aborted_clients") {
				$str = $n . "aborted_clients";
				$aborted_clients = $value - ($config->{mysql_hist}->{$str} || 0);
				$aborted_clients = 0 unless $aborted_clients != $value;
				$aborted_clients /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Aborted_connects") {
				$str = $n . "aborted_connects";
				$aborted_connects = $value - ($config->{mysql_hist}->{$str} || 0);
				$aborted_connects = 0 unless $aborted_connects != $value;
				$aborted_connects /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Connections") {
				$str = $n . "connections";
				$connections_real = int($value);
				$connections = $value - ($config->{mysql_hist}->{$str} || 0);
				$connections = 0 unless $connections != $value;
				$connections /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Innodb_buffer_pool_pages_free") {
				$innodb_buffer_pool_pages_free = int($value);
			}
			if($name eq "Innodb_buffer_pool_pages_total") {
				$innodb_buffer_pool_pages_total = int($value);
			}
			if($name eq "Key_blocks_unused") {
				$key_blocks_unused = int($value);
			}
			if($name eq "Key_blocks_used") {
				$key_blocks_used = int($value);
			}
			if($name eq "Max_used_connections") {
				$max_used_connections = int($value);
			}
			if($name eq "Opened_tables") {
				$str = $n . "opened_tables";
				$opened_tables = $value - ($config->{mysql_hist}->{$str} || 0);
				$opened_tables = 0 unless $opened_tables != $value;
#				$opened_tables /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Qcache_free_memory") {
				$qcache_free_memory = int($value);
			}
			if($name eq "Qcache_hits") {
				$qcache_hits = int($value);
			}
			if($name eq "Qcache_inserts") {
				$qcache_inserts = int($value);
			}
			if($name eq "Queries") {
				$str = $n . "queries";
				$queries = $value - ($config->{mysql_hist}->{$str} || 0);
				$queries = 0 unless $queries != $value;
				$queries /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Slow_queries") {
				$str = $n . "slow_queries";
				$slow_queries = $value - ($config->{mysql_hist}->{$str} || 0);
				$slow_queries = 0 unless $slow_queries != $value;
				$slow_queries /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Table_locks_waited") {
				$str = $n . "table_locks_waited";
				$table_locks_waited = $value - ($config->{mysql_hist}->{$str} || 0);
				$table_locks_waited = 0 unless $table_locks_waited != $value;
#				$table_locks_waited /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Threads_created") {
				$threads_created = int($value);
			}
			if($name eq "Created_tmp_disk_tables") {
				$created_tmp_disk_tables = int($value);
			}
			if($name eq "Created_tmp_tables") {
				$created_tmp_tables = int($value);
			}

			if($name eq "Bytes_received") {
				$str = $n . "bytes_received";
				$bytes_received = $value - ($config->{mysql_hist}->{$str} || 0);
				$bytes_received = 0 unless $bytes_received != $value;
				$bytes_received /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Bytes_sent") {
				$str = $n . "bytes_sent";
				$bytes_sent = $value - ($config->{mysql_hist}->{$str} || 0);
				$bytes_sent = 0 unless $bytes_sent != $value;
				$bytes_sent /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Com_commit") {
				$str = $n . "com_commit";
				$com_commit = $value - ($config->{mysql_hist}->{$str} || 0);
				$com_commit = 0 unless $com_commit != $value;
				$com_commit /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Com_delete") {
				$str = $n . "com_delete";
				$com_delete = $value - ($config->{mysql_hist}->{$str} || 0);
				$com_delete = 0 unless $com_delete != $value;
				$com_delete /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Com_insert") {
				$str = $n . "com_insert";
				$com_insert = $value - ($config->{mysql_hist}->{$str} || 0);
				$com_insert = 0 unless $com_insert != $value;
				$com_insert /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Com_insert_select") {
				$str = $n . "com_insert_s";
				$com_insert_s = $value - ($config->{mysql_hist}->{$str} || 0);
				$com_insert_s = 0 unless $com_insert_s != $value;
				$com_insert_s /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Com_replace") {
				$str = $n . "com_replace";
				$com_replace = $value - ($config->{mysql_hist}->{$str} || 0);
				$com_replace = 0 unless $com_replace != $value;
				$com_replace /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Com_replace_select") {
				$str = $n . "com_replace_s";
				$com_replace_s = $value - ($config->{mysql_hist}->{$str} || 0);
				$com_replace_s = 0 unless $com_replace_s != $value;
				$com_replace_s /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Com_rollback") {
				$str = $n . "com_rollback";
				$com_rollback = $value - ($config->{mysql_hist}->{$str} || 0);
				$com_rollback = 0 unless $com_rollback != $value;
				$com_rollback /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Com_select") {
				$str = $n . "com_select";
				$Com_select = $value;
				$value += $qcache_hits;
				$com_select = $value - ($config->{mysql_hist}->{$str} || 0);
				$com_select = 0 unless $com_select != $value;
				$com_select /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Com_update") {
				$str = $n . "com_update";
				$com_update = $value - ($config->{mysql_hist}->{$str} || 0);
				$com_update = 0 unless $com_update != $value;
				$com_update /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
			if($name eq "Com_stmt_execute") {
				$str = $n . "com_stmtex";
				$com_stmtex = $value - ($config->{mysql_hist}->{$str} || 0);
				$com_stmtex = 0 unless $com_stmtex != $value;
				$com_stmtex /= 60;
				$config->{mysql_hist}->{$str} = $value;
			}
		}
		$sth->finish;

		# SHOW VARIABLES
		my $query_cache_size = 0;
		my $max_connections = 0;
		$sql = "show variables";
		$sth = $dbh->prepare($sql);
		$sth->execute;
		while(my ($name, $value) = $sth->fetchrow_array) {
			if($name eq "max_connections") {
				$max_connections = int($value);
			}
			if($name eq "query_cache_size") {
				$query_cache_size = int($value);
			}
		}
		$sth->finish;
		$dbh->disconnect;

		my $tcache_hit_rate = 0;
		my $qcache_usage = 0;
		my $connections_usage = 0;
		my $key_buffer_usage = 0;
		my $innodb_buffer_pool_usage = 0;
		my $qcache_hit_rate = 0;
		my $temp_tables_to_disk = 0;

		$tcache_hit_rate = (1 - ($threads_created / $connections_real)) * 100
			unless !$connections_real;
		$qcache_usage = (1 - ($qcache_free_memory / $query_cache_size)) * 100
			unless !$query_cache_size;
		$connections_usage = ($max_used_connections / $max_connections) * 100
			unless !$max_connections;
		$key_buffer_usage = ($key_blocks_used / ($key_blocks_used + $key_blocks_unused)) * 100
			unless !($key_blocks_used + $key_blocks_unused);
		$innodb_buffer_pool_usage = (1 - ($innodb_buffer_pool_pages_free / $innodb_buffer_pool_pages_total)) * 100
			unless !$innodb_buffer_pool_pages_total;

		$connections_usage = $connections_usage > 100 ? 100 : $connections_usage;
		if($qcache_hits + $Com_select == 0) {
			$qcache_hit_rate = 0;
		} else {
			$qcache_hit_rate = $qcache_hits / ($qcache_hits + $Com_select) * 100;
		}
		$temp_tables_to_disk = $created_tmp_disk_tables / ($created_tmp_disk_tables + $created_tmp_tables) * 100;

		$rrdata .= ":$queries:$slow_queries:$tcache_hit_rate:$qcache_usage:$opened_tables:$connections_usage:$connections:$table_locks_waited:$key_buffer_usage:$innodb_buffer_pool_usage:$com_select:$com_commit:$com_delete:$com_insert:$com_insert_s:$com_update:$com_replace:$com_replace_s:$com_rollback:$aborted_clients:$aborted_connects:$bytes_received:$bytes_sent:$qcache_hit_rate:$com_stmtex:$temp_tables_to_disk:0:0:0:0:0:0:0:0:0:0:0:0";
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub mysql_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $mysql = $config->{mysql};
	my @rigid = split(',', ($mysql->{rigid} || ""));
	my @limit = split(',', ($mysql->{limit} || ""));
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
		my $line3;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		for($n = 0; $n < scalar(my @ml = split(',', $mysql->{list})); $n++) {
			$line1 = "                                                                                                                                                                                                                          ";
			$line2 .= "   Select  Commit  Delete  Insert  Insert_S  Update  Replace  Replace_S  Rollback  TCacheHit  QCache_U  Conns_U  KeyBuf_U  InnoDB_U  OpenedTbl  TLocks_W  Queries  SlowQrs  Conns  AbrtCli  AbrtConn  BytesRecv  BytesSent QCacheHitR StmtExec TmpTbToDsk";
			$line3 .= "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
			if($line1) {
				my $i = length($line1);
				if(lc($mysql->{conn_type}) eq "host") {
					push(@output, sprintf(sprintf("%${i}s", sprintf("%s:%s", $ml[$n], trim((split(',', $mysql->{desc}->{$ml[$n]}))[0])))));
				}
				if(lc($mysql->{conn_type}) eq "socket") {
					push(@output, sprintf(sprintf("%${i}s", sprintf("socket: %s", $ml[$n]))));
				}
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
			for($n2 = 0; $n2 < scalar(my @ml = split(',', $mysql->{list})); $n2++) {
				undef(@row);
				$from = $n2 * 38;
				$to = $from + 38;
				push(@row, @$line[$from..$to]);
				push(@output, sprintf("   %6d  %6d  %6d  %6d  %8d  %6d  %7d   %8d  %8d        %2d%%       %2d%%      %2d%%       %2d%%       %2d%%     %6d    %6d   %6d   %6d %6d   %6d    %6d  %9d  %9d        %2d%%   %6d        %2d%%", @row));
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

	for($n = 0; $n < scalar(my @ml = split(',', $mysql->{list})); $n++) {
		for($n2 = 1; $n2 <= 6; $n2++) {
			my $str = $u . $package . $n . $n2 . "." . $tf->{when} . ".$imgfmt_lc";
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
	foreach (my @ml = split(',', $mysql->{list})) {
		my $uri;
		if(lc($mysql->{conn_type}) eq "host") {
	        	$uri = $_ . ":" . trim((split(',', $mysql->{desc}->{$_}))[0]);
		}
		if(lc($mysql->{conn_type}) eq "socket") {
	        	$uri = "socket: " . $_;
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
		push(@tmp, "LINE2:com_select#FFA500:Select");
		push(@tmp, "GPRINT:com_select:LAST:         Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_select:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_select:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_select:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE2:com_commit#EEEE44:Commit");
		push(@tmp, "GPRINT:com_commit:LAST:         Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_commit:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_commit:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_commit:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE2:com_delete#EE4444:Delete");
		push(@tmp, "GPRINT:com_delete:LAST:         Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_delete:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_delete:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_delete:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE2:com_insert#44EE44:Insert");
		push(@tmp, "GPRINT:com_insert:LAST:         Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE2:com_insert_s#448844:Insert Select");
		push(@tmp, "GPRINT:com_insert_s:LAST:  Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert_s:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert_s:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert_s:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE2:com_update#EE44EE:Update");
		push(@tmp, "GPRINT:com_update:LAST:         Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_update:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_update:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_update:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE2:com_replace#44EEEE:Replace");
		push(@tmp, "GPRINT:com_replace:LAST:        Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE2:com_replace_s#4444EE:Replace Select");
		push(@tmp, "GPRINT:com_replace_s:LAST: Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace_s:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace_s:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace_s:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE2:com_rollback#444444:Rollback");
		push(@tmp, "GPRINT:com_rollback:LAST:       Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_rollback:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_rollback:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_rollback:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE2:com_stmtex#888888:Prep.Stmt.Exec");
		push(@tmp, "GPRINT:com_stmtex:LAST: Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_stmtex:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_stmtex:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_stmtex:MAX:    Max\\: %6.1lf\\n");
		push(@tmpz, "LINE2:com_select#FFA500:Select");
		push(@tmpz, "LINE2:com_commit#EEEE44:Commit");
		push(@tmpz, "LINE2:com_delete#EE4444:Delete");
		push(@tmpz, "LINE2:com_insert#44EE44:Insert");
		push(@tmpz, "LINE2:com_insert_s#448844:Insert Sel");
		push(@tmpz, "LINE2:com_update#EE44EE:Update");
		push(@tmpz, "LINE2:com_replace#44EEEE:Replace");
		push(@tmpz, "LINE2:com_replace_s#4444EE:Replace Sel");
		push(@tmpz, "LINE2:com_rollback#444444:Rollback");
		push(@tmpz, "LINE2:com_stmtex#888888:Prep.Stmt.Exec");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6]",
			"--title=$config->{graphs}->{_mysql1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Queries/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:com_select=$rrd:mysql" . $e . "_csel:AVERAGE",
			"DEF:com_commit=$rrd:mysql" . $e . "_ccom:AVERAGE",
			"DEF:com_delete=$rrd:mysql" . $e . "_cdel:AVERAGE",
			"DEF:com_insert=$rrd:mysql" . $e . "_cins:AVERAGE",
			"DEF:com_insert_s=$rrd:mysql" . $e . "_cinss:AVERAGE",
			"DEF:com_update=$rrd:mysql" . $e . "_cupd:AVERAGE",
			"DEF:com_replace=$rrd:mysql" . $e . "_crep:AVERAGE",
			"DEF:com_replace_s=$rrd:mysql" . $e . "_creps:AVERAGE",
			"DEF:com_rollback=$rrd:mysql" . $e . "_crol:AVERAGE",
			"DEF:com_stmtex=$rrd:mysql" . $e . "_cstmtex:AVERAGE",
			"CDEF:allvalues=com_select,com_commit,com_delete,com_insert,com_insert_s,com_update,com_replace,com_replace_s,com_rollback,com_stmtex,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6]",
				"--title=$config->{graphs}->{_mysql1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Queries/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:com_select=$rrd:mysql" . $e . "_csel:AVERAGE",
				"DEF:com_commit=$rrd:mysql" . $e . "_ccom:AVERAGE",
				"DEF:com_delete=$rrd:mysql" . $e . "_cdel:AVERAGE",
				"DEF:com_insert=$rrd:mysql" . $e . "_cins:AVERAGE",
				"DEF:com_insert_s=$rrd:mysql" . $e . "_cinss:AVERAGE",
				"DEF:com_update=$rrd:mysql" . $e . "_cupd:AVERAGE",
				"DEF:com_replace=$rrd:mysql" . $e . "_crep:AVERAGE",
				"DEF:com_replace_s=$rrd:mysql" . $e . "_creps:AVERAGE",
				"DEF:com_rollback=$rrd:mysql" . $e . "_crol:AVERAGE",
				"DEF:com_stmtex=$rrd:mysql" . $e . "_cstmtex:AVERAGE",
				"CDEF:allvalues=com_select,com_commit,com_delete,com_insert,com_insert_s,com_update,com_replace,com_replace_s,com_rollback,com_stmtex,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
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
		push(@tmp, "LINE2:tcache_hit_r#FFA500:Thread Cache Hit Rate");
		push(@tmp, "GPRINT:tcache_hit_r:LAST:  Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:tcache_hit_r:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:tcache_hit_r:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:tcache_hit_r:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE2:qcache_hitr#4444EE:Query Cache Hit Rate");
		push(@tmp, "GPRINT:qcache_hitr:LAST:   Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:qcache_hitr:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:qcache_hitr:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:qcache_hitr:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE2:qcache_usage#44EEEE:Query Cache Usage");
		push(@tmp, "GPRINT:qcache_usage:LAST:      Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:qcache_usage:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:qcache_usage:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:qcache_usage:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE2:conns_u#44EE44:Connections Usage");
		push(@tmp, "GPRINT:conns_u:LAST:      Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:conns_u:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:conns_u:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:conns_u:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE2:key_buf_u#EE4444:Key Buffer Usage");
		push(@tmp, "GPRINT:key_buf_u:LAST:       Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:key_buf_u:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:key_buf_u:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:key_buf_u:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE2:innodb_buf_u#EE44EE:InnoDB Buffer P. Usage");
		push(@tmp, "GPRINT:innodb_buf_u:LAST: Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:innodb_buf_u:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:innodb_buf_u:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:innodb_buf_u:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE2:tmptbltodsk#888888:Temp. Tables to Disk");
		push(@tmp, "GPRINT:tmptbltodsk:LAST:   Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:tmptbltodsk:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:tmptbltodsk:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:tmptbltodsk:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmpz, "LINE2:tcache_hit_r#FFA500:Thread Cache Hit Rate");
		push(@tmpz, "LINE2:qcache_hitr#4444EE:Query Cache Hit Rate");
		push(@tmpz, "LINE2:qcache_usage#44EEEE:Query Cache Usage");
		push(@tmpz, "LINE2:conns_u#44EE44:Connections Usage");
		push(@tmpz, "LINE2:key_buf_u#EE4444:Key Buffer Usage");
		push(@tmpz, "LINE2:innodb_buf_u#EE44EE:Innodb Buffer P. Usage");
		push(@tmpz, "LINE2:tmptbltodsk#888888:Temp. Tables to Disk");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 1]",
			"--title=$config->{graphs}->{_mysql2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:tcache_hit_r=$rrd:mysql" . $e . "_tchr:AVERAGE",
			"DEF:qcache_hitr=$rrd:mysql" . $e . "_qchr:AVERAGE",
			"DEF:qcache_usage=$rrd:mysql" . $e . "_qcu:AVERAGE",
			"DEF:conns_u=$rrd:mysql" . $e . "_conns_u:AVERAGE",
			"DEF:key_buf_u=$rrd:mysql" . $e . "_kbu:AVERAGE",
			"DEF:innodb_buf_u=$rrd:mysql" . $e . "_innbu:AVERAGE",
			"DEF:tmptbltodsk=$rrd:mysql" . $e . "_tttd:AVERAGE",
			"CDEF:allvalues=tcache_hit_r,qcache_hitr,qcache_usage,conns_u,key_buf_u,innodb_buf_u,tmptbltodsk,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 1]",
				"--title=$config->{graphs}->{_mysql2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Percent (%)",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:tcache_hit_r=$rrd:mysql" . $e . "_tchr:AVERAGE",
				"DEF:qcache_hitr=$rrd:mysql" . $e . "_qchr:AVERAGE",
				"DEF:qcache_usage=$rrd:mysql" . $e . "_qcu:AVERAGE",
				"DEF:conns_u=$rrd:mysql" . $e . "_conns_u:AVERAGE",
				"DEF:key_buf_u=$rrd:mysql" . $e . "_kbu:AVERAGE",
				"DEF:innodb_buf_u=$rrd:mysql" . $e . "_innbu:AVERAGE",
				"DEF:tmptbltodsk=$rrd:mysql" . $e . "_tttd:AVERAGE",
				"CDEF:allvalues=tcache_hit_r,qcache_hitr,qcache_usage,conns_u,key_buf_u,innodb_buf_u,tmptbltodsk,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
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
		push(@tmp, "AREA:opened_tbl#44EEEE:Opened Tables");
		push(@tmp, "GPRINT:opened_tbl:LAST:        Current\\: %7.1lf\\n");
		push(@tmp, "AREA:tlocks_w#4444EE:Table Locks Waited");
		push(@tmp, "GPRINT:tlocks_w:LAST:   Current\\: %7.1lf\\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "LINE1:opened_tbl#00EEEE");
		push(@tmp, "LINE1:tlocks_w#0000EE");
		push(@tmpz, "AREA:opened_tbl#44EEEE:Opened Tables");
		push(@tmpz, "AREA:tlocks_w#4444EE:Table Locks Waited");
		push(@tmpz, "LINE1:opened_tbl#00EEEE");
		push(@tmpz, "LINE1:tlocks_w#0000EE");
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
			"--title=$config->{graphs}->{_mysql3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Open & Locks/min",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:opened_tbl=$rrd:mysql" . $e . "_ot:AVERAGE",
			"DEF:tlocks_w=$rrd:mysql" . $e . "_tlw:AVERAGE",
			"CDEF:allvalues=opened_tbl,tlocks_w,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 2]",
				"--title=$config->{graphs}->{_mysql3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Open & Locks/min",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:opened_tbl=$rrd:mysql" . $e . "_ot:AVERAGE",
				"DEF:tlocks_w=$rrd:mysql" . $e . "_tlw:AVERAGE",
				"CDEF:allvalues=opened_tbl,tlocks_w,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
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
		push(@tmp, "AREA:qrs#44EEEE:Queries");
		push(@tmp, "GPRINT:qrs:LAST:              Current\\: %7.1lf\\n");
		push(@tmp, "AREA:sqrs#4444EE:Slow Queries");
		push(@tmp, "GPRINT:sqrs:LAST:         Current\\: %7.1lf\\n");
		push(@tmp, "LINE1:qrs#00EEEE");
		push(@tmp, "LINE1:sqrs#0000EE");
		push(@tmp, "COMMENT: \\n");
		push(@tmpz, "AREA:qrs#44EEEE:Queries");
		push(@tmpz, "AREA:sqrs#4444EE:Slow Queries");
		push(@tmpz, "LINE1:qrs#00EEEE");
		push(@tmpz, "LINE1:sqrs#0000EE");
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
			"--title=$config->{graphs}->{_mysql4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Queries/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:qrs=$rrd:mysql" . $e . "_queries:AVERAGE",
			"DEF:sqrs=$rrd:mysql" . $e . "_sq:AVERAGE",
			"CDEF:allvalues=qrs,sqrs,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 3]",
				"--title=$config->{graphs}->{_mysql4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Queries/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:qrs=$rrd:mysql" . $e . "_queries:AVERAGE",
				"DEF:sqrs=$rrd:mysql" . $e . "_sq:AVERAGE",
				"CDEF:allvalues=qrs,sqrs,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 3]: $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
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
		push(@tmp, "AREA:conns#44EEEE:Connections");
		push(@tmp, "GPRINT:conns:LAST:          Current\\: %7.1lf\\n");
		push(@tmp, "AREA:acli#EEEE44:Aborted Clients");
		push(@tmp, "GPRINT:acli:LAST:      Current\\: %7.1lf\\n");
		push(@tmp, "AREA:acon#EE4444:Aborted Connects");
		push(@tmp, "GPRINT:acon:LAST:     Current\\: %7.1lf\\n");
		push(@tmp, "LINE1:conns#00EEEE");
		push(@tmp, "LINE1:acli#EEEE00");
		push(@tmp, "LINE1:acon#EE0000");
		push(@tmp, "COMMENT: \\n");
		push(@tmpz, "AREA:conns#44EEEE:Connections");
		push(@tmpz, "AREA:acli#EEEE44:Aborted Clients");
		push(@tmpz, "AREA:acon#EE4444:Aborted Connects");
		push(@tmpz, "LINE1:conns#00EEEE");
		push(@tmpz, "LINE1:acli#EEEE00");
		push(@tmpz, "LINE1:acon#EE0000");
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
			"--title=$config->{graphs}->{_mysql5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Connectionss/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:conns=$rrd:mysql" . $e . "_conns:AVERAGE",
			"DEF:acli=$rrd:mysql" . $e . "_acli:AVERAGE",
			"DEF:acon=$rrd:mysql" . $e . "_acon:AVERAGE",
			"CDEF:allvalues=conns,acli,acon,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 4]",
				"--title=$config->{graphs}->{_mysql5}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Connectionss/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:conns=$rrd:mysql" . $e . "_conns:AVERAGE",
				"DEF:acli=$rrd:mysql" . $e . "_acli:AVERAGE",
				"DEF:acon=$rrd:mysql" . $e . "_acon:AVERAGE",
				"CDEF:allvalues=conns,acli,acon,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 4]: $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
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
			"--title=$config->{graphs}->{_mysql6}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:in=$rrd:mysql" . $e . "_brecv:AVERAGE",
			"DEF:out=$rrd:mysql" . $e . "_bsent:AVERAGE",
			"CDEF:allvalues=in,out,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 5]",
				"--title=$config->{graphs}->{_mysql6}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:in=$rrd:mysql" . $e . "_brecv:AVERAGE",
				"DEF:out=$rrd:mysql" . $e . "_bsent:AVERAGE",
				"CDEF:allvalues=in,out,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 5]: $err\n") if $err;
		}
		$e2 = $e + 6;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
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
			push(@output, "        <b style='{color: " . $colors->{title_fg_color} . "}'>&nbsp;&nbsp;$uri</b>\n");
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
