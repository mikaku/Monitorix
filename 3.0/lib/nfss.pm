#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2012 by Jordi Sanfeliu <jordi@fibranet.cat>
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

#use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(nfss_init nfss_update nfss_cgi);

sub nfss_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $squid = $config->{squid};

	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		logger("$myself is not supported yet by your operating system ($config->{os}).");
		return;
	}

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
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
				my $version = "4ops" if $nfss->{version} eq "4";
				if(/^proc$version /) {
					my @tmp = split(' ', $_);
					(undef, undef, @nfss) = @tmp;
				}
			}
			close(IN);
		} else {
			logger("$myself: it doesn't appears you have a NFS server running in this machine.");
			return;
		}
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

	my $nfss = $config->{nfss};
	my @rigid = split(',', $nfss->{rigid});
	my @limit = split(',', $nfss->{limit});
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};

	my $u = "";
	my $width;
	my $height;
	my @riglim;
	my @tmp;
	my @tmpz;
	my $i;
	my @DEF;
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

	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

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
	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$NFSS_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $NFSS_RRD: $err\n") if $err;
		my $str;
		my $line1;
		my $line2;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
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
		print("Time $line1\n");
		print("-----$line2\n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my @nfs;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
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
			$time = $time - (1 / $ts);
			printf(" %2d$tc $line1\n", $time, @row);
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG4 = $u . $myself . "4." . $when . ".png";
	my $PNG5 = $u . $myself . "5." . $when . ".png";
	my $PNG6 = $u . $myself . "6." . $when . ".png";
	my $PNG7 = $u . $myself . "7." . $when . ".png";
	my $PNG8 = $u . $myself . "8." . $when . ".png";
	my $PNG9 = $u . $myself . "9." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";
	my $PNG4z = $u . $myself . "4z." . $when . ".png";
	my $PNG5z = $u . $myself . "5z." . $when . ".png";
	my $PNG6z = $u . $myself . "6z." . $when . ".png";
	my $PNG7z = $u . $myself . "7z." . $when . ".png";
	my $PNG8z = $u . $myself . "8z." . $when . ".png";
	my $PNG9z = $u . $myself . "9z." . $when . ".png";

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3",
		"$PNG_DIR" . "$PNG4",
		"$PNG_DIR" . "$PNG5",
		"$PNG_DIR" . "$PNG6",
		"$PNG_DIR" . "$PNG7",
		"$PNG_DIR" . "$PNG8",
		"$PNG_DIR" . "$PNG9");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z",
			"$PNG_DIR" . "$PNG4z",
			"$PNG_DIR" . "$PNG5z",
			"$PNG_DIR" . "$PNG6z",
			"$PNG_DIR" . "$PNG7z",
			"$PNG_DIR" . "$PNG8z",
			"$PNG_DIR" . "$PNG9z");
	}
	if($title) {
		graph_header($title, 2);
	}
	if($NFSS1_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSS1_LIMIT");
	} else {
		if($NFSS1_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSS1_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	if($title) {
		print("    <tr>\n");
		print("    <td valign='top' bgcolor='$title_bg_color'>\n");
	}
	for($n = 0; $n < 10; $n++) {
		if(grep {$_ eq $NFSS_GRAPH_1[$n]} @nfsv) {
			($i) = grep { $nfsv[$_] eq $NFSS_GRAPH_1[$n] } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$NFSS_RRD:nfss_$i:AVERAGE");
			push(@tmp, "LINE1:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSS_GRAPH_1[$n]));
			push(@tmp, "GPRINT:nfs_$i:LAST:    Cur\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:AVERAGE:    Avg\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MIN:    Min\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MAX:    Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSS_GRAPH_1[$n]));
		} else {
			push(@tmp, "COMMENT: \\n");
		}
	}
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$rgraphs{_nfss1}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		@DEF,
		@tmp,
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$rgraphs{_nfss1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			@DEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss1/)) {
		if($ENABLE_ZOOM eq "Y") {
			if($DISABLE_JAVASCRIPT_VOID eq "Y") {
				print("      <a href=\"" . $URL . $IMGS_DIR . $PNG1z . "\"><img src='" . $URL . $IMGS_DIR . $PNG1 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNG1z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG1 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $URL . $IMGS_DIR . $PNG1 . "'>\n");
		}
	}

	undef(@riglim);
	if($NFSS2_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSS2_LIMIT");
	} else {
		if($NFSS2_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSS2_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	undef(@DEF);
	for($n = 0; $n < 10; $n++) {
		if(grep {$_ eq $NFSS_GRAPH_2[$n]} @nfsv) {
			($i) = grep { $nfsv[$_] eq $NFSS_GRAPH_2[$n] } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$NFSS_RRD:nfss_$i:AVERAGE");
			push(@tmp, "LINE1:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSS_GRAPH_2[$n]));
			push(@tmp, "GPRINT:nfs_$i:LAST:    Cur\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:AVERAGE:    Avg\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MIN:    Min\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MAX:    Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSS_GRAPH_2[$n]));
		} else {
			push(@tmp, "COMMENT: \\n");
		}
	}
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$rgraphs{_nfss2}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		@DEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$rgraphs{_nfss2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			@DEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss2/)) {
		if($ENABLE_ZOOM eq "Y") {
			if($DISABLE_JAVASCRIPT_VOID eq "Y") {
				print("      <a href=\"" . $URL . $IMGS_DIR . $PNG2z . "\"><img src='" . $URL . $IMGS_DIR . $PNG2 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNG2z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG2 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $URL . $IMGS_DIR . $PNG2 . "'>\n");
		}
	}

	undef(@riglim);
	if($NFSS3_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSS3_LIMIT");
	} else {
		if($NFSS3_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSS3_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	undef(@DEF);
	for($n = 0; $n < 10; $n++) {
		if(grep {$_ eq $NFSS_GRAPH_3[$n]} @nfsv) {
			($i) = grep { $nfsv[$_] eq $NFSS_GRAPH_3[$n] } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$NFSS_RRD:nfss_$i:AVERAGE");
			push(@tmp, "LINE1:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSS_GRAPH_3[$n]));
			push(@tmp, "GPRINT:nfs_$i:LAST:    Cur\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:AVERAGE:    Avg\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MIN:    Min\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MAX:    Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSS_GRAPH_3[$n]));
		} else {
			push(@tmp, "COMMENT: \\n");
		}
	}
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$rgraphs{_nfss3}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		@DEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$rgraphs{_nfss3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			@DEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss3/)) {
		if($ENABLE_ZOOM eq "Y") {
			if($DISABLE_JAVASCRIPT_VOID eq "Y") {
				print("      <a href=\"" . $URL . $IMGS_DIR . $PNG3z . "\"><img src='" . $URL . $IMGS_DIR . $PNG3 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNG3z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG3 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $URL . $IMGS_DIR . $PNG3 . "'>\n");
		}
	}
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
	}

	undef(@riglim);
	if($NFSS4_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSS4_LIMIT");
	} else {
		if($NFSS4_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSS4_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
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
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG4",
		"--title=$rgraphs{_nfss4}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=bytes/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:in=$NFSS_RRD:nfss_io_1:AVERAGE",
		"DEF:out=$NFSS_RRD:nfss_io_2:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG4: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG4z",
			"--title=$rgraphs{_nfss4}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=bytes/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:in=$NFSS_RRD:nfss_io_1:AVERAGE",
			"DEF:out=$NFSS_RRD:nfss_io_2:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss4/)) {
		if($ENABLE_ZOOM eq "Y") {
			if($DISABLE_JAVASCRIPT_VOID eq "Y") {
				print("      <a href=\"" . $URL . $IMGS_DIR . $PNG4z . "\"><img src='" . $URL . $IMGS_DIR . $PNG4 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNG4z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG4 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $URL . $IMGS_DIR . $PNG4 . "'>\n");
		}
	}

	undef(@riglim);
	if($NFSS5_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSS5_LIMIT");
	} else {
		if($NFSS5_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSS5_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
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
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG5",
		"--title=$rgraphs{_nfss5}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Values/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:packets=$NFSS_RRD:nfss_net_1:AVERAGE",
		"DEF:udp=$NFSS_RRD:nfss_net_2:AVERAGE",
		"DEF:tcp=$NFSS_RRD:nfss_net_3:AVERAGE",
		"DEF:tcpconn=$NFSS_RRD:nfss_net_4:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG5: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG5z",
			"--title=$rgraphs{_nfss5}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Values/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:packets=$NFSS_RRD:nfss_net_1:AVERAGE",
			"DEF:udp=$NFSS_RRD:nfss_net_2:AVERAGE",
			"DEF:tcp=$NFSS_RRD:nfss_net_3:AVERAGE",
			"DEF:tcpconn=$NFSS_RRD:nfss_net_4:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss5/)) {
		if($ENABLE_ZOOM eq "Y") {
			if($DISABLE_JAVASCRIPT_VOID eq "Y") {
				print("      <a href=\"" . $URL . $IMGS_DIR . $PNG5z . "\"><img src='" . $URL . $IMGS_DIR . $PNG5 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNG5z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG5 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $URL . $IMGS_DIR . $PNG5 . "'>\n");
		}
	}

	undef(@riglim);
	if($NFSS6_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSS6_LIMIT");
	} else {
		if($NFSS6_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSS6_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
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
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG6",
		"--title=$rgraphs{_nfss6}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Values/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:calls=$NFSS_RRD:nfss_rpc_1:AVERAGE",
		"DEF:badcalls=$NFSS_RRD:nfss_rpc_2:AVERAGE",
		"DEF:badauth=$NFSS_RRD:nfss_rpc_3:AVERAGE",
		"DEF:badclnt=$NFSS_RRD:nfss_rpc_4:AVERAGE",
		"DEF:xdrcall=$NFSS_RRD:nfss_rpc_4:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG6: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG6z",
			"--title=$rgraphs{_nfss6}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Values/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:calls=$NFSS_RRD:nfss_rpc_1:AVERAGE",
			"DEF:badcalls=$NFSS_RRD:nfss_rpc_2:AVERAGE",
			"DEF:badauth=$NFSS_RRD:nfss_rpc_3:AVERAGE",
			"DEF:badclnt=$NFSS_RRD:nfss_rpc_4:AVERAGE",
			"DEF:xdrcall=$NFSS_RRD:nfss_rpc_4:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG6z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss6/)) {
		if($ENABLE_ZOOM eq "Y") {
			if($DISABLE_JAVASCRIPT_VOID eq "Y") {
				print("      <a href=\"" . $URL . $IMGS_DIR . $PNG6z . "\"><img src='" . $URL . $IMGS_DIR . $PNG6 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNG6z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG6 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $URL . $IMGS_DIR . $PNG6 . "'>\n");
		}
	}

	undef(@riglim);
	if($NFSS7_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSS7_LIMIT");
	} else {
		if($NFSS7_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSS7_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
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
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG7",
		"--title=$rgraphs{_nfss7}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Values/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:threads=$NFSS_RRD:nfss_th_0:AVERAGE",
		"DEF:th1=$NFSS_RRD:nfss_th_1:AVERAGE",
		"DEF:th2=$NFSS_RRD:nfss_th_2:AVERAGE",
		"DEF:th3=$NFSS_RRD:nfss_th_3:AVERAGE",
		"DEF:th4=$NFSS_RRD:nfss_th_4:AVERAGE",
		"DEF:th5=$NFSS_RRD:nfss_th_5:AVERAGE",
		"DEF:th6=$NFSS_RRD:nfss_th_6:AVERAGE",
		"DEF:th7=$NFSS_RRD:nfss_th_7:AVERAGE",
		"DEF:th8=$NFSS_RRD:nfss_th_8:AVERAGE",
		"DEF:th9=$NFSS_RRD:nfss_th_9:AVERAGE",
		"DEF:th10=$NFSS_RRD:nfss_th_10:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG7: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG7z",
			"--title=$rgraphs{_nfss7}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Values/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:threads=$NFSS_RRD:nfss_th_0:AVERAGE",
			"DEF:th1=$NFSS_RRD:nfss_th_1:AVERAGE",
			"DEF:th2=$NFSS_RRD:nfss_th_2:AVERAGE",
			"DEF:th3=$NFSS_RRD:nfss_th_3:AVERAGE",
			"DEF:th4=$NFSS_RRD:nfss_th_4:AVERAGE",
			"DEF:th5=$NFSS_RRD:nfss_th_5:AVERAGE",
			"DEF:th6=$NFSS_RRD:nfss_th_6:AVERAGE",
			"DEF:th7=$NFSS_RRD:nfss_th_7:AVERAGE",
			"DEF:th8=$NFSS_RRD:nfss_th_8:AVERAGE",
			"DEF:th9=$NFSS_RRD:nfss_th_9:AVERAGE",
			"DEF:th10=$NFSS_RRD:nfss_th_10:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG7z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss7/)) {
		if($ENABLE_ZOOM eq "Y") {
			if($DISABLE_JAVASCRIPT_VOID eq "Y") {
				print("      <a href=\"" . $URL . $IMGS_DIR . $PNG7z . "\"><img src='" . $URL . $IMGS_DIR . $PNG7 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNG7z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG7 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $URL . $IMGS_DIR . $PNG7 . "'>\n");
		}
	}

	undef(@riglim);
	if($NFSS8_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSS8_LIMIT");
	} else {
		if($NFSS8_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSS8_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
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
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG8",
		"--title=$rgraphs{_nfss8}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:hits=$NFSS_RRD:nfss_rc_1:AVERAGE",
		"DEF:misses=$NFSS_RRD:nfss_rc_2:AVERAGE",
		"DEF:nocache=$NFSS_RRD:nfss_rc_3:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG8: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG8z",
			"--title=$rgraphs{_nfss8}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:hits=$NFSS_RRD:nfss_rc_1:AVERAGE",
			"DEF:misses=$NFSS_RRD:nfss_rc_2:AVERAGE",
			"DEF:nocache=$NFSS_RRD:nfss_rc_3:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG8z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss8/)) {
		if($ENABLE_ZOOM eq "Y") {
			if($DISABLE_JAVASCRIPT_VOID eq "Y") {
				print("      <a href=\"" . $URL . $IMGS_DIR . $PNG8z . "\"><img src='" . $URL . $IMGS_DIR . $PNG8 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNG8z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG8 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $URL . $IMGS_DIR . $PNG8 . "'>\n");
		}
	}

	undef(@riglim);
	if($NFSS9_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSS9_LIMIT");
	} else {
		if($NFSS9_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSS9_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
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
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG9",
		"--title=$rgraphs{_nfss9}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Values/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:lookup=$NFSS_RRD:nfss_fh_1:AVERAGE",
		"DEF:anon=$NFSS_RRD:nfss_fh_2:AVERAGE",
		"DEF:ncachedir1=$NFSS_RRD:nfss_fh_3:AVERAGE",
		"DEF:ncachedir2=$NFSS_RRD:nfss_fh_4:AVERAGE",
		"DEF:stale=$NFSS_RRD:nfss_fh_4:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG9: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG9z",
			"--title=$rgraphs{_nfss9}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Values/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:lookup=$NFSS_RRD:nfss_fh_1:AVERAGE",
			"DEF:anon=$NFSS_RRD:nfss_fh_2:AVERAGE",
			"DEF:ncachedir1=$NFSS_RRD:nfss_fh_3:AVERAGE",
			"DEF:ncachedir2=$NFSS_RRD:nfss_fh_4:AVERAGE",
			"DEF:stale=$NFSS_RRD:nfss_fh_4:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG9z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfss9/)) {
		if($ENABLE_ZOOM eq "Y") {
			if($DISABLE_JAVASCRIPT_VOID eq "Y") {
				print("      <a href=\"" . $URL . $IMGS_DIR . $PNG9z . "\"><img src='" . $URL . $IMGS_DIR . $PNG9 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNG9z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG9 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $URL . $IMGS_DIR . $PNG9 . "'>\n");
		}
	}

	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

1;
