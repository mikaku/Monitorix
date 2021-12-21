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

package nfss;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(nfss_init nfss_update nfss_cgi);

sub nfss_init {
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

	if(grep {$_ eq $config->{os}} ("OpenBSD", "NetBSD")) {
		logger("$myself is not supported yet by your operating system ($config->{os}).");
		return;
	}

	if($config->{os} eq "Linux") {
		if(!(-e "/proc/net/rpc/nfsd")) {
			logger("$myself: it doesn't seems you have a NFS server running in this machine.");
			return;
		}
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
				"DS:nfss_0:COUNTER:120:0:U",
				"DS:nfss_1:COUNTER:120:0:U",
				"DS:nfss_2:COUNTER:120:0:U",
				"DS:nfss_3:COUNTER:120:0:U",
				"DS:nfss_4:COUNTER:120:0:U",
				"DS:nfss_5:COUNTER:120:0:U",
				"DS:nfss_6:COUNTER:120:0:U",
				"DS:nfss_7:COUNTER:120:0:U",
				"DS:nfss_8:COUNTER:120:0:U",
				"DS:nfss_9:COUNTER:120:0:U",
				"DS:nfss_10:COUNTER:120:0:U",
				"DS:nfss_11:COUNTER:120:0:U",
				"DS:nfss_12:COUNTER:120:0:U",
				"DS:nfss_13:COUNTER:120:0:U",
				"DS:nfss_14:COUNTER:120:0:U",
				"DS:nfss_15:COUNTER:120:0:U",
				"DS:nfss_16:COUNTER:120:0:U",
				"DS:nfss_17:COUNTER:120:0:U",
				"DS:nfss_18:COUNTER:120:0:U",
				"DS:nfss_19:COUNTER:120:0:U",
				"DS:nfss_20:COUNTER:120:0:U",
				"DS:nfss_21:COUNTER:120:0:U",
				"DS:nfss_22:COUNTER:120:0:U",
				"DS:nfss_23:COUNTER:120:0:U",
				"DS:nfss_24:COUNTER:120:0:U",
				"DS:nfss_25:COUNTER:120:0:U",
				"DS:nfss_26:COUNTER:120:0:U",
				"DS:nfss_27:COUNTER:120:0:U",
				"DS:nfss_28:COUNTER:120:0:U",
				"DS:nfss_29:COUNTER:120:0:U",
				"DS:nfss_30:COUNTER:120:0:U",
				"DS:nfss_31:COUNTER:120:0:U",
				"DS:nfss_32:COUNTER:120:0:U",
				"DS:nfss_33:COUNTER:120:0:U",
				"DS:nfss_34:COUNTER:120:0:U",
				"DS:nfss_35:COUNTER:120:0:U",
				"DS:nfss_36:COUNTER:120:0:U",
				"DS:nfss_37:COUNTER:120:0:U",
				"DS:nfss_38:COUNTER:120:0:U",
				"DS:nfss_39:COUNTER:120:0:U",
				"DS:nfss_40:COUNTER:120:0:U",
				"DS:nfss_41:COUNTER:120:0:U",
				"DS:nfss_42:COUNTER:120:0:U",
				"DS:nfss_43:COUNTER:120:0:U",
				"DS:nfss_44:COUNTER:120:0:U",
				"DS:nfss_45:COUNTER:120:0:U",
				"DS:nfss_46:COUNTER:120:0:U",
				"DS:nfss_47:COUNTER:120:0:U",
				"DS:nfss_48:COUNTER:120:0:U",
				"DS:nfss_49:COUNTER:120:0:U",
				"DS:nfss_rc_1:COUNTER:120:0:U",
				"DS:nfss_rc_2:COUNTER:120:0:U",
				"DS:nfss_rc_3:COUNTER:120:0:U",
				"DS:nfss_rc_4:COUNTER:120:0:U",
				"DS:nfss_rc_5:COUNTER:120:0:U",
				"DS:nfss_fh_1:COUNTER:120:0:U",
				"DS:nfss_fh_2:COUNTER:120:0:U",
				"DS:nfss_fh_3:COUNTER:120:0:U",
				"DS:nfss_fh_4:COUNTER:120:0:U",
				"DS:nfss_fh_5:COUNTER:120:0:U",
				"DS:nfss_io_1:COUNTER:120:0:U",
				"DS:nfss_io_2:COUNTER:120:0:U",
				"DS:nfss_io_3:COUNTER:120:0:U",
				"DS:nfss_th_0:COUNTER:120:0:U",
				"DS:nfss_th_1:COUNTER:120:0:U",
				"DS:nfss_th_2:COUNTER:120:0:U",
				"DS:nfss_th_3:COUNTER:120:0:U",
				"DS:nfss_th_4:COUNTER:120:0:U",
				"DS:nfss_th_5:COUNTER:120:0:U",
				"DS:nfss_th_6:COUNTER:120:0:U",
				"DS:nfss_th_7:COUNTER:120:0:U",
				"DS:nfss_th_8:COUNTER:120:0:U",
				"DS:nfss_th_9:COUNTER:120:0:U",
				"DS:nfss_th_10:COUNTER:120:0:U",
				"DS:nfss_net_1:COUNTER:120:0:U",
				"DS:nfss_net_2:COUNTER:120:0:U",
				"DS:nfss_net_3:COUNTER:120:0:U",
				"DS:nfss_net_4:COUNTER:120:0:U",
				"DS:nfss_net_5:COUNTER:120:0:U",
				"DS:nfss_rpc_1:COUNTER:120:0:U",
				"DS:nfss_rpc_2:COUNTER:120:0:U",
				"DS:nfss_rpc_3:COUNTER:120:0:U",
				"DS:nfss_rpc_4:COUNTER:120:0:U",
				"DS:nfss_rpc_5:COUNTER:120:0:U",
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

sub nfss_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nfss = $config->{nfss};

	my @rc;
	my @fh;
	my @io;
	my @th;
	my @net;
	my @rpc;
	my @nfss;

	my $n;
	my $rrdata = "N";

	if($config->{os} eq "Linux") {
		if(open(IN, "/proc/net/rpc/nfsd")) {
			while(<IN>) {
				if(/^rc\s+(\d+)\s+(\d+)\s+(\d+)$/) {
					@rc = ($1, $2, $3);
				}
				if(/^fh\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/) {
					@fh = ($1, $2, $3, $4, $5);
				}
				if(/^io\s+(\d+)\s+(\d+)$/) {
					@io = ($1, $2);
				}
				if(/^th /) {
					my @tmp = split(' ', $_);
					(undef, undef, @th) = @tmp;
				}
				if(/^net\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/) {
					@net = ($1, $2, $3, $4);
				}
				if(/^rpc\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/) {
					@rpc = ($1, $2, $3, $4, $5);
				}
				my $version = $nfss->{version};
				$version = "4ops" if $nfss->{version} eq "4";
				if(/^proc$version /) {
					my @tmp = split(' ', $_);
					(undef, undef, @nfss) = @tmp;
				}
			}
			close(IN);
		} else {
			logger("$myself: ERROR: Unable to open '/proc/net/rpc/nfsd'. $!.");
			return;
		}
	}

	# On FreeBSD run nfsstat(1) to get this info
	# We want to fill in the @rc, @fh, @io, @th, @net, @rpc, @nfss arrays
	# with the same types of data (or 0) that linux gets out of /proc

	if($config->{os} eq "FreeBSD") {
		my $stats = &parse_nfsstat();
		if (! $stats) {
			logger("$myself: ERROR: Unable to run and parse output from 'nfsstat'. $!.");
			return;
		}

		# Now shove the data into the arrays in the way the rest of
		# this plugin expects to find them

		# LINUX: @rc = reply cache = (hits, misses, nocache)
		# FreeBSD: Server Cache Stats: Inprog, idem, Non-idem, Misses
		@rc = (
			$stats->{'Idem'}, 
			$stats->{'Misses'}, 
			$stats->{'Non-idem'}
		); 

		# LINUX: @fh = file handles = (stale, total_lookups, anonlookups, dirnocache, nodirnocahe)
		# FreeBSD: No data
		@fh = (0,0,0,0,0);

		# LINUX: @io = I/O = (read, wright)
		# FreeBSD: Server Info: Read, Write
		@io = (
			$stats->{'Read'}, 
			$stats->{'Write'} 
		);

		# LINUX: @th = Threads = (11 values)
		# FreeBSD: Server Info: No data
		@th = (0,0,0,0,0,0,0,0,0,0,0);

		# LINUX: @net = Net = (netcount, udpcount, tcpcount, tcpconnect)
		# FreeBSD: Server Info: No data
		@net = (0,0,0,0);

		# LINUX: @rpc = RPC = (count, badcnt, badfmt, badauth, badcInt)
		# FreeBSD: Server Info: No data
		@rpc = (0,0,0,0,0);

		# LINUX: @nfss = Server stats = for v3, 22 stats:
		#   null / getattr / setattr / lookup / access 
		#   readlink / read / write / create / mkdir / symlink
		#   mknod / remove / rmdir / rename / link / readdir
		#   readdirplus / fsstat / fsinfo / pathconf / commit
		# FreeBSD: Server Info: has all those items with similar names
		@nfss = (
			0,
			$stats->{'Getattr'}, 
			$stats->{'Setattr'}, 
			$stats->{'Lookup'}, 
			$stats->{'Access'}, 
			$stats->{'Readlink'}, 
			$stats->{'Read'}, 
			$stats->{'Write'}, 
			$stats->{'Create'}, 
			$stats->{'Mkdir'}, 
			$stats->{'Symlink'}, 
			$stats->{'Mknod'}, 
			$stats->{'Remove'}, 
			$stats->{'Rmdir'}, 
			$stats->{'Rename'}, 
			$stats->{'Link'}, 
			$stats->{'Readdir'}, 
			$stats->{'RdirPlus'}, 
			$stats->{'Fsstat'}, 
			$stats->{'Fsinfo'}, 
			$stats->{'PathConf'}, 
			$stats->{'Commit'} 
		);

	}

	for($n = 0; $n < 50; $n++) {
		if(!defined($nfss[$n])) {
			$nfss[$n] = 0;
		}
		$rrdata .= ":" . $nfss[$n];
	}
	$rrdata .= ":$rc[0]:$rc[1]:$rc[2]:0:0";
	$rrdata .= ":$fh[0]:$fh[1]:$fh[2]:$fh[3]:$fh[4]";
	$rrdata .= ":$io[0]:$io[1]:0";
	for($n = 0; $n < 11; $n++) {
		$rrdata .= ":" . int($th[$n]);
	}
	$rrdata .= ":$net[0]:$net[1]:$net[2]:$net[3]:0";
	$rrdata .= ":$rpc[0]:$rpc[1]:$rpc[2]:$rpc[3]:$rpc[4]";
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub nfss_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $nfss = $config->{nfss};
	my @rigid = split(',', ($nfss->{rigid} || ""));
	my @limit = split(',', ($nfss->{limit} || ""));
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
	my @DEF;
	my @CDEF;
	my @allvalues;
	my @allsigns;
	my $n;
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
		"#963C74",
		"#CCCCCC",
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
		"#B4B444",
		"#888888",
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

	my @nfsv2 = ("null", "getattr", "setattr", "root", "lookup", "readlink", "read", "wrcache", "write", "create", "remove", "rename", "link", "symlink", "mkdir", "rmdir", "readdir", "fsstat");
	my @nfsv3 = ("null", "getattr", "setattr", "lookup", "access", "readlink", "read", "write", "create", "mkdir", "symlink", "mknod", "remove", "rmdir", "rename", "link", "readdir", "readdirplus", "fsstat", "fsinfo", "pathconf", "commit");
	my @nfssv4 = ("op0-unused", "op1-unused", "op2-future", "access", "close", "commit", "create", "delegpurge", "delegreturn", "getattr", "getfh", "link", "lock", "lockt", "locku", "lookup", "lookup_root", "nverify", "open", "openattr", "open_conf", "open_dgrd", "putfh", "putpubfh", "putrootfh", "read", "readdir", "readlink", "remove", "rename", "renew", "restorefh", "savefh", "secinfo", "setattr", "setcltid", "setcltidconf", "verify", "write", "rellockowner", "bc_ctl", "bind_conn", "exchange_id", "create_ses", "destroy_ses", "free_stateid", "getdirdeleg", "getdevinfo", "getdevlist", "layoutcommit", "layoutget", "layoutreturn", "secinfononam", "sequence", "set_ssv", "test_stateid", "want_deleg", "destroy_clid", "reclaim_comp");

	my @nfsv;

	# default version is NFS v3
	if($nfss->{version} eq "2") {
		@nfsv = @nfsv2;
	} elsif($nfss->{version} eq "4") {
		@nfsv = @nfssv4;
	} else {
		@nfsv = @nfsv3;
	}

	$title = !$silent ? $title : "";
	$title =~ s/NFS/NFS v$nfss->{version}/;


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
		my $str;
		my $line1;
		my $line2;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		foreach my $t (@nfsv) {
			$str = sprintf("%12s ", $t);
			$line1 .= $str;
			$line2 .= "-------------";
		}
		$line1 .= sprintf("%12s %12s %12s ", "hits", "misses", "nocache");
		$line2 .= "-------------" . "-------------" . "-------------";
		$line1 .= sprintf("%12s %12s %12s %12s %12s ", "lookup", "anon", "ncachedir", "ncachedir", "stale");
		$line2 .= "-------------" . "-------------" . "-------------" . "-------------" . "-------------";
		$line1 .= sprintf("%12s %12s ", "read", "written");
		$line2 .= "-------------" . "-------------";
		$line1 .= sprintf("%12s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s ", "threads", "<10%", "<20%", "<30%", "<40%", "<50%", "<60%", "<70%", "<80%", "<90%", "<100%");
		$line2 .= "-------------" . "-------" . "-------" . "-------" . "-------" . "-------" . "-------" . "-------" . "-------" . "-------" . "-------";
		$line1 .= sprintf("%12s %12s %12s %12s ", "packets", "udp", "tcp", "tcpconn");
		$line2 .= "-------------" . "-------------" . "-------------" . "-------------";
		$line1 .= sprintf("%12s %12s %12s %12s %12s ", "calls", "badcalls", "badauth", "badclnt", "xdrcall");
		$line2 .= "-------------" . "-------------" . "-------------" . "-------------" . "-------------";
		push(@output, "Time $line1\n");
		push(@output, "-----$line2\n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my @nfs;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			undef($line1);
			undef(@row);
			(@nfs) = @$line[0..scalar(@nfsv) - 1];
			for($n2 = 0; $n2 < scalar(@nfs);$n2++) {
				push(@row, $nfs[$n2]);
				$line1 .= "%12d ";
			}
			push(@row, @$line[50..52]);
			$line1 .= "%12d %12d %12d ";
			push(@row, @$line[55..59]);
			$line1 .= "%12d %12d %12d %12d %12d ";
			push(@row, @$line[60..61]);
			$line1 .= "%12d %12d ";
			push(@row, @$line[63..73]);
			$line1 .= "%12d %6d %6d %6d %6d %6d %6d %6d %6d %6d %6d ";
			push(@row, @$line[74..77]);
			$line1 .= "%12d %12d %12d %12d ";
			push(@row, @$line[79..83]);
			$line1 .= "%12d %12d %12d %12d %12d ";
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} $line1\n", $time, @row));
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
	my $IMG7 = $u . $package . "7." . $tf->{when} . ".$imgfmt_lc";
	my $IMG8 = $u . $package . "8." . $tf->{when} . ".$imgfmt_lc";
	my $IMG9 = $u . $package . "9." . $tf->{when} . ".$imgfmt_lc";
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG4z = $u . $package . "4z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG5z = $u . $package . "5z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG6z = $u . $package . "6z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG7z = $u . $package . "7z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG8z = $u . $package . "8z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG9z = $u . $package . "9z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3",
		"$IMG_DIR" . "$IMG4",
		"$IMG_DIR" . "$IMG5",
		"$IMG_DIR" . "$IMG6",
		"$IMG_DIR" . "$IMG7",
		"$IMG_DIR" . "$IMG8",
		"$IMG_DIR" . "$IMG9");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
			"$IMG_DIR" . "$IMG2z",
			"$IMG_DIR" . "$IMG3z",
			"$IMG_DIR" . "$IMG4z",
			"$IMG_DIR" . "$IMG5z",
			"$IMG_DIR" . "$IMG6z",
			"$IMG_DIR" . "$IMG7z",
			"$IMG_DIR" . "$IMG8z",
			"$IMG_DIR" . "$IMG9z");
	}
	if($title) {
		push(@output, main::graph_header($title, 2));
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td class='td-valign-top'>\n");
	}
	for($n = 0; $n < 10; $n++) {
		my $str = trim((split(',', $nfss->{graph_0}))[$n]) || "";
		if(grep {$_ eq $str} @nfsv) {
			my ($i) = grep {$nfsv[$_] eq $str} 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$rrd:nfss_$i:AVERAGE");
			push(@tmp, "LINE1:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@tmp, "GPRINT:nfs_$i:LAST:    Cur\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:AVERAGE:    Avg\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MIN:    Min\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MAX:    Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@allvalues, "nfs_$i");
			push(@allsigns, "+");
		} else {
			push(@tmp, "COMMENT: \\n");
		}
	}
	pop(@allsigns);
	push(@CDEF, "CDEF:allvalues=" . join(',', @allvalues, @allsigns));
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
		"--title=$config->{graphs}->{_nfss1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		@DEF,
		@CDEF,
		@tmp,
		"COMMENT: \\n");
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_nfss1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			@DEF,
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss1/)) {
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
	undef(@DEF);
	undef(@CDEF);
	undef(@allvalues);
	undef(@allsigns);
	for($n = 0; $n < 10; $n++) {
		my $str = trim((split(',', $nfss->{graph_1}))[$n]) || "";
		if(grep {$_ eq $str} @nfsv) {
			my ($i) = grep {$nfsv[$_] eq $str} 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$rrd:nfss_$i:AVERAGE");
			push(@tmp, "LINE1:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@tmp, "GPRINT:nfs_$i:LAST:    Cur\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:AVERAGE:    Avg\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MIN:    Min\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MAX:    Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@allvalues, "nfs_$i");
			push(@allsigns, "+");
		} else {
			push(@tmp, "COMMENT: \\n");
		}
	}
	pop(@allsigns);
	push(@CDEF, "CDEF:allvalues=" . join(',', @allvalues, @allsigns));
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_nfss2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		@DEF,
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_nfss2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			@DEF,
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss2/)) {
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

	@riglim = @{setup_riglim($rigid[2], $limit[2])};
	undef(@tmp);
	undef(@tmpz);
	undef(@DEF);
	undef(@CDEF);
	undef(@allvalues);
	undef(@allsigns);
	for($n = 0; $n < 10; $n++) {
		my $str = trim((split(',', $nfss->{graph_2}))[$n]) || "";
		if(grep {$_ eq $str} @nfsv) {
			my ($i) = grep {$nfsv[$_] eq $str} 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$rrd:nfss_$i:AVERAGE");
			push(@tmp, "LINE1:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@tmp, "GPRINT:nfs_$i:LAST:    Cur\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:AVERAGE:    Avg\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MIN:    Min\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MAX:    Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@allvalues, "nfs_$i");
			push(@allsigns, "+");
		} else {
			push(@tmp, "COMMENT: \\n");
		}
	}
	pop(@allsigns);
	push(@CDEF, "CDEF:allvalues=" . join(',', @allvalues, @allsigns));
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG3",
		"--title=$config->{graphs}->{_nfss3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		@DEF,
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_nfss3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			@DEF,
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss3/)) {
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
		push(@output, "    <td class='td-valign-top'>\n");
	}
	@riglim = @{setup_riglim($rigid[3], $limit[3])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:in#44EE44:Read");
	push(@tmp, "AREA:out#4444EE:Written");
	push(@tmp, "AREA:out#4444EE:");
	push(@tmp, "AREA:in#44EE44:");
	push(@tmp, "LINE1:out#0000EE");
	push(@tmp, "LINE1:in#00EE00");
	push(@tmpz, "AREA:in#44EE44:Read");
	push(@tmpz, "AREA:out#4444EE:Written");
	push(@tmpz, "AREA:out#4444EE:");
	push(@tmpz, "AREA:in#44EE44:");
	push(@tmpz, "LINE1:out#0000EE");
	push(@tmpz, "LINE1:in#00EE00");
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
		"--title=$config->{graphs}->{_nfss4}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:in=$rrd:nfss_io_1:AVERAGE",
		"DEF:out=$rrd:nfss_io_2:AVERAGE",
		"CDEF:allvalues=in,out,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG4z",
			"--title=$config->{graphs}->{_nfss4}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:in=$rrd:nfss_io_1:AVERAGE",
			"DEF:out=$rrd:nfss_io_2:AVERAGE",
			"CDEF:allvalues=in,out,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss4/)) {
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
	push(@tmp, "AREA:udp#44EEEE:UDP");
	push(@tmp, "GPRINT:udp:LAST:                  Current\\: %7.1lf\\n");
	push(@tmp, "AREA:tcp#4444EE:TCP");
	push(@tmp, "GPRINT:tcp:LAST:                  Current\\: %7.1lf\\n");
	push(@tmp, "AREA:tcpconn#EE44EE:TCP Connections");
	push(@tmp, "GPRINT:tcpconn:LAST:      Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:udp#00EEEE");
	push(@tmp, "LINE1:tcp#0000EE");
	push(@tmp, "LINE1:tcpconn#EE00EE");
	push(@tmpz, "AREA:udp#44EEEE:UDP");
	push(@tmpz, "AREA:tcp#4444EE:TCP");
	push(@tmpz, "AREA:tcpconn#EE44EE:TCP Connections");
	push(@tmpz, "LINE1:udp#00EEEE");
	push(@tmpz, "LINE1:tcp#0000EE");
	push(@tmpz, "LINE1:tcpconn#EE00EE");
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
		"--title=$config->{graphs}->{_nfss5}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:packets=$rrd:nfss_net_1:AVERAGE",
		"DEF:udp=$rrd:nfss_net_2:AVERAGE",
		"DEF:tcp=$rrd:nfss_net_3:AVERAGE",
		"DEF:tcpconn=$rrd:nfss_net_4:AVERAGE",
		"CDEF:allvalues=packets,udp,tcp,tcpconn,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG5z",
			"--title=$config->{graphs}->{_nfss5}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:packets=$rrd:nfss_net_1:AVERAGE",
			"DEF:udp=$rrd:nfss_net_2:AVERAGE",
			"DEF:tcp=$rrd:nfss_net_3:AVERAGE",
			"DEF:tcpconn=$rrd:nfss_net_4:AVERAGE",
			"CDEF:allvalues=packets,udp,tcp,tcpconn,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss5/)) {
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

	@riglim = @{setup_riglim($rigid[5], $limit[5])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE1:calls#FFA500:Calls");
	push(@tmp, "GPRINT:calls:LAST:                Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:badcalls#44EEEE:Badcalls");
	push(@tmp, "GPRINT:badcalls:LAST:             Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:badauth#44EE44:Badauth");
	push(@tmp, "GPRINT:badauth:LAST:              Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:badclnt#EE4444:Badclnt");
	push(@tmp, "GPRINT:badclnt:LAST:              Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:xdrcall#4444EE:XDRcall");
	push(@tmp, "GPRINT:xdrcall:LAST:              Current\\: %7.1lf\\n");
	push(@tmpz, "LINE1:calls#FFA500:Calls");
	push(@tmpz, "LINE1:badcalls#44EEEE:Badcalls");
	push(@tmpz, "LINE1:badauth#44EE44:Badauth");
	push(@tmpz, "LINE1:badclnt#EE4444:Badclnt");
	push(@tmpz, "LINE1:xdrcall#4444EE:XDRcall");
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
		"--title=$config->{graphs}->{_nfss6}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:calls=$rrd:nfss_rpc_1:AVERAGE",
		"DEF:badcalls=$rrd:nfss_rpc_2:AVERAGE",
		"DEF:badauth=$rrd:nfss_rpc_3:AVERAGE",
		"DEF:badclnt=$rrd:nfss_rpc_4:AVERAGE",
		"DEF:xdrcall=$rrd:nfss_rpc_4:AVERAGE",
		"CDEF:allvalues=calls,badcalls,badauth,badclnt,xdrcall,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG6: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG6z",
			"--title=$config->{graphs}->{_nfss6}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:calls=$rrd:nfss_rpc_1:AVERAGE",
			"DEF:badcalls=$rrd:nfss_rpc_2:AVERAGE",
			"DEF:badauth=$rrd:nfss_rpc_3:AVERAGE",
			"DEF:badclnt=$rrd:nfss_rpc_4:AVERAGE",
			"DEF:xdrcall=$rrd:nfss_rpc_4:AVERAGE",
			"CDEF:allvalues=calls,badcalls,badauth,badclnt,xdrcall,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG6z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss6/)) {
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

	@riglim = @{setup_riglim($rigid[6], $limit[6])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
#	push(@tmp, "LINE1:threads#444444:Threads usage");
#	push(@tmp, "GPRINT:threads:LAST:        Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:th1#33FF00:<10%\\g");
	push(@tmp, "GPRINT:th1:LAST:\\: %7.1lf        ");
	push(@tmp, "LINE1:th2#FFCC00:< 60%\\g");
	push(@tmp, "GPRINT:th2:LAST:\\: %7.1lf\\n");
	push(@tmp, "LINE1:th3#66FF00:<20%\\g");
	push(@tmp, "GPRINT:th3:LAST:\\: %7.1lf        ");
	push(@tmp, "LINE1:th4#FF9900:< 70%\\g");
	push(@tmp, "GPRINT:th4:LAST:\\: %7.1lf\\n");
	push(@tmp, "LINE1:th5#99FF00:<30%\\g");
	push(@tmp, "GPRINT:th5:LAST:\\: %7.1lf        ");
	push(@tmp, "LINE1:th6#FF6600:< 80%\\g");
	push(@tmp, "GPRINT:th6:LAST:\\: %7.1lf\\n");
	push(@tmp, "LINE1:th7#CCFF00:<40%\\g");
	push(@tmp, "GPRINT:th7:LAST:\\: %7.1lf        ");
	push(@tmp, "LINE1:th8#FF3300:< 90%\\g");
	push(@tmp, "GPRINT:th8:LAST:\\: %7.1lf\\n");
	push(@tmp, "LINE1:th9#FFFF00:<50%\\g");
	push(@tmp, "GPRINT:th9:LAST:\\: %7.1lf        ");
	push(@tmp, "LINE1:th10#FF0000:<100%\\g");
	push(@tmp, "GPRINT:th10:LAST:\\: %7.1lf\\n");
#	push(@tmpz, "LINE1:threads#444444:Threads usage");
	push(@tmpz, "LINE1:th1#33FF00:<10%");
	push(@tmpz, "LINE1:th3#66FF00:<20%");
	push(@tmpz, "LINE1:th5#99FF00:<30%");
	push(@tmpz, "LINE1:th7#CCFF00:<40%");
	push(@tmpz, "LINE1:th9#FFFF00:<50%");
	push(@tmpz, "LINE1:th2#FFCC00:<60%");
	push(@tmpz, "LINE1:th4#FF9900:<70%");
	push(@tmpz, "LINE1:th6#FF6600:<80%");
	push(@tmpz, "LINE1:th8#FF3300:<90%");
	push(@tmpz, "LINE1:th10#FF0000:<100%");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG7",
		"--title=$config->{graphs}->{_nfss7}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:threads=$rrd:nfss_th_0:AVERAGE",
		"DEF:th1=$rrd:nfss_th_1:AVERAGE",
		"DEF:th2=$rrd:nfss_th_2:AVERAGE",
		"DEF:th3=$rrd:nfss_th_3:AVERAGE",
		"DEF:th4=$rrd:nfss_th_4:AVERAGE",
		"DEF:th5=$rrd:nfss_th_5:AVERAGE",
		"DEF:th6=$rrd:nfss_th_6:AVERAGE",
		"DEF:th7=$rrd:nfss_th_7:AVERAGE",
		"DEF:th8=$rrd:nfss_th_8:AVERAGE",
		"DEF:th9=$rrd:nfss_th_9:AVERAGE",
		"DEF:th10=$rrd:nfss_th_10:AVERAGE",
		"CDEF:allvalues=threads,th1,th2,th3,th4,th5,th6,th7,th8,th9,th10,+,+,+,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG7: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG7z",
			"--title=$config->{graphs}->{_nfss7}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:threads=$rrd:nfss_th_0:AVERAGE",
			"DEF:th1=$rrd:nfss_th_1:AVERAGE",
			"DEF:th2=$rrd:nfss_th_2:AVERAGE",
			"DEF:th3=$rrd:nfss_th_3:AVERAGE",
			"DEF:th4=$rrd:nfss_th_4:AVERAGE",
			"DEF:th5=$rrd:nfss_th_5:AVERAGE",
			"DEF:th6=$rrd:nfss_th_6:AVERAGE",
			"DEF:th7=$rrd:nfss_th_7:AVERAGE",
			"DEF:th8=$rrd:nfss_th_8:AVERAGE",
			"DEF:th9=$rrd:nfss_th_9:AVERAGE",
			"DEF:th10=$rrd:nfss_th_10:AVERAGE",
			"CDEF:allvalues=threads,th1,th2,th3,th4,th5,th6,th7,th8,th9,th10,+,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG7z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss7/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG7z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG7 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG7z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG7 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG7 . "'>\n");
		}
	}

	@riglim = @{setup_riglim($rigid[7], $limit[7])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:hits#44EEEE:Hits");
	push(@tmp, "GPRINT:hits:LAST:                 Current\\: %7.1lf\\n");
	push(@tmp, "AREA:misses#4444EE:Misses");
	push(@tmp, "GPRINT:misses:LAST:               Current\\: %7.1lf\\n");
	push(@tmp, "AREA:nocache#EEEE44:Nocache");
	push(@tmp, "GPRINT:nocache:LAST:              Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:hits#00EEEE");
	push(@tmp, "LINE1:misses#0000EE");
	push(@tmp, "LINE1:nocache#EEEE44");
	push(@tmpz, "AREA:hits#44EEEE:Hits");
	push(@tmpz, "AREA:misses#4444EE:Misses");
	push(@tmpz, "AREA:nocache#EEEE44:Nocache");
	push(@tmpz, "LINE1:hits#00EEEE");
	push(@tmpz, "LINE1:misses#0000EE");
	push(@tmpz, "LINE1:nocache#EEEE44");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG8",
		"--title=$config->{graphs}->{_nfss8}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:hits=$rrd:nfss_rc_1:AVERAGE",
		"DEF:misses=$rrd:nfss_rc_2:AVERAGE",
		"DEF:nocache=$rrd:nfss_rc_3:AVERAGE",
		"CDEF:allvalues=hits,misses,nocache,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG8: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG8z",
			"--title=$config->{graphs}->{_nfss8}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:hits=$rrd:nfss_rc_1:AVERAGE",
			"DEF:misses=$rrd:nfss_rc_2:AVERAGE",
			"DEF:nocache=$rrd:nfss_rc_3:AVERAGE",
			"CDEF:allvalues=hits,misses,nocache,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG8z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss8/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG8z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG8 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG8z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG8 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG8 . "'>\n");
		}
	}

	@riglim = @{setup_riglim($rigid[8], $limit[8])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE1:lookup#FFA500:Lookups");
	push(@tmp, "GPRINT:lookup:LAST:              Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:anon#44EE44:Anonymous lockups");
	push(@tmp, "GPRINT:anon:LAST:    Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:ncachedir1#44EEEE:Ncachedir");
	push(@tmp, "GPRINT:ncachedir1:LAST:            Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:ncachedir2#4444EE:Ncachedir");
	push(@tmp, "GPRINT:ncachedir2:LAST:            Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:stale#EE4444:Stale");
	push(@tmp, "GPRINT:stale:LAST:                Current\\: %7.1lf\\n");
	push(@tmpz, "LINE1:lookup#FFA500:Lookup");
	push(@tmpz, "LINE1:anon#44EE44:Anonymous");
	push(@tmpz, "LINE1:ncachedir1#44EEEE:Ncachedir");
	push(@tmpz, "LINE1:ncachedir2#4444EE:Ncachedir");
	push(@tmpz, "LINE1:stale#EE4444:Stale");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG9",
		"--title=$config->{graphs}->{_nfss9}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:lookup=$rrd:nfss_fh_1:AVERAGE",
		"DEF:anon=$rrd:nfss_fh_2:AVERAGE",
		"DEF:ncachedir1=$rrd:nfss_fh_3:AVERAGE",
		"DEF:ncachedir2=$rrd:nfss_fh_4:AVERAGE",
		"DEF:stale=$rrd:nfss_fh_4:AVERAGE",
		"CDEF:allvalues=lookup,anon,ncachedir1,ncachedir2,stale,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG9: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG9z",
			"--title=$config->{graphs}->{_nfss9}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:lookup=$rrd:nfss_fh_1:AVERAGE",
			"DEF:anon=$rrd:nfss_fh_2:AVERAGE",
			"DEF:ncachedir1=$rrd:nfss_fh_3:AVERAGE",
			"DEF:ncachedir2=$rrd:nfss_fh_4:AVERAGE",
			"DEF:stale=$rrd:nfss_fh_4:AVERAGE",
			"CDEF:allvalues=lookup,anon,ncachedir1,ncachedir2,stale,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG9z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss9/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG9z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG9 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG9z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG9 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG9 . "'>\n");
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

# Returns a hashref full of server stats, or undef if anything went wrong
sub parse_nfsstat {
	my @heads;
	my @values;
	my $head;
	my $val;
	my $line;
	my $stats;
	my $i;

	if(! open(IN, "nfsstat -s |")) {
		return undef;
	}
	while(<IN>) {
		next if (/:/);		# Skip section heads
		next if (/^\s*$/);	# Skip blank lines
		s/^\s+//;		# Nuke leading spaces
		if (/[a-z]+\s+[a-z]+/i) {
			# This looks like a header line
			@heads = split(/\s+/, $_);
			# Pull the next line of data
			$line = <IN>;
			$line =~ s/^\s+//;	# Nuke leading spaces
			$line =~ s/Server /Server_/;	# Fix multiword
			@values = split(/\s+/, $line);
			for ($i = 0; $i <= $#values; $i++) {
				$val = $values[$i];
				if ($val < 0) {
					# Fix overflow?
					$val += 2**31;
				}
				$stats->{$heads[$i]} = $val;
			}
		}
	}
	close(IN);
	return $stats;
}

1;
