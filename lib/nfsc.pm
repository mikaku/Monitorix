#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2014 by Jordi Sanfeliu <jordi@fibranet.cat>
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

package nfsc;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(nfsc_init nfsc_update nfsc_cgi);


sub nfsc_init {
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

	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		logger("$myself is not supported yet by your operating system ($config->{os}).");
		return;
	}

	if($config->{os} eq "Linux") {
		if(!(-e "/proc/net/rpc/nfs")) {
			logger("$myself: it doesn't seems you have a NFS client running in this machine.");
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
				"DS:nfsc_0:COUNTER:120:0:U",
				"DS:nfsc_1:COUNTER:120:0:U",
				"DS:nfsc_2:COUNTER:120:0:U",
				"DS:nfsc_3:COUNTER:120:0:U",
				"DS:nfsc_4:COUNTER:120:0:U",
				"DS:nfsc_5:COUNTER:120:0:U",
				"DS:nfsc_6:COUNTER:120:0:U",
				"DS:nfsc_7:COUNTER:120:0:U",
				"DS:nfsc_8:COUNTER:120:0:U",
				"DS:nfsc_9:COUNTER:120:0:U",
				"DS:nfsc_10:COUNTER:120:0:U",
				"DS:nfsc_11:COUNTER:120:0:U",
				"DS:nfsc_12:COUNTER:120:0:U",
				"DS:nfsc_13:COUNTER:120:0:U",
				"DS:nfsc_14:COUNTER:120:0:U",
				"DS:nfsc_15:COUNTER:120:0:U",
				"DS:nfsc_16:COUNTER:120:0:U",
				"DS:nfsc_17:COUNTER:120:0:U",
				"DS:nfsc_18:COUNTER:120:0:U",
				"DS:nfsc_19:COUNTER:120:0:U",
				"DS:nfsc_20:COUNTER:120:0:U",
				"DS:nfsc_21:COUNTER:120:0:U",
				"DS:nfsc_22:COUNTER:120:0:U",
				"DS:nfsc_23:COUNTER:120:0:U",
				"DS:nfsc_24:COUNTER:120:0:U",
				"DS:nfsc_25:COUNTER:120:0:U",
				"DS:nfsc_26:COUNTER:120:0:U",
				"DS:nfsc_27:COUNTER:120:0:U",
				"DS:nfsc_28:COUNTER:120:0:U",
				"DS:nfsc_29:COUNTER:120:0:U",
				"DS:nfsc_30:COUNTER:120:0:U",
				"DS:nfsc_31:COUNTER:120:0:U",
				"DS:nfsc_32:COUNTER:120:0:U",
				"DS:nfsc_33:COUNTER:120:0:U",
				"DS:nfsc_34:COUNTER:120:0:U",
				"DS:nfsc_35:COUNTER:120:0:U",
				"DS:nfsc_36:COUNTER:120:0:U",
				"DS:nfsc_37:COUNTER:120:0:U",
				"DS:nfsc_38:COUNTER:120:0:U",
				"DS:nfsc_39:COUNTER:120:0:U",
				"DS:nfsc_40:COUNTER:120:0:U",
				"DS:nfsc_41:COUNTER:120:0:U",
				"DS:nfsc_42:COUNTER:120:0:U",
				"DS:nfsc_43:COUNTER:120:0:U",
				"DS:nfsc_44:COUNTER:120:0:U",
				"DS:nfsc_45:COUNTER:120:0:U",
				"DS:nfsc_46:COUNTER:120:0:U",
				"DS:nfsc_47:COUNTER:120:0:U",
				"DS:nfsc_48:COUNTER:120:0:U",
				"DS:nfsc_49:COUNTER:120:0:U",
				"DS:nfsc_rpc_1:COUNTER:120:0:U",
				"DS:nfsc_rpc_2:COUNTER:120:0:U",
				"DS:nfsc_rpc_3:COUNTER:120:0:U",
				"DS:nfsc_rpc_4:COUNTER:120:0:U",
				"DS:nfsc_rpc_5:COUNTER:120:0:U",
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

sub nfsc_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nfsc = $config->{nfsc};

	my @rpc;
	my @nfsc;

	my $n;
	my $rrdata = "N";

	if($config->{os} eq "Linux") {
		if(open(IN, "/proc/net/rpc/nfs")) {
			while(<IN>) {
				if(/^rpc\s+(\d+)\s+(\d+)\s+(\d+)$/) {
					@rpc = ($1, $2, $3);
				}
				if(/^proc$nfsc->{version} /) {
					my @tmp = split(' ', $_);
					(undef, undef, @nfsc) = @tmp;
				}
			}
			close(IN);
		} else {
			logger("$myself: ERROR: Unable to open '/proc/net/rpc/nfs'. $!.");
			return;
		}
	}

	for($n = 0; $n < 50; $n++) {
		if(!defined($nfsc[$n])) {
			$nfsc[$n] = 0;
		}
		$rrdata .= ":" . $nfsc[$n];
	}

	$rrdata .= ":$rpc[0]:$rpc[1]:$rpc[2]:0:0";
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub nfsc_cgi {
	my ($package, $config, $cgi) = @_;

	my $nfsc = $config->{nfsc};
	my @rigid = split(',', $nfsc->{rigid});
	my @limit = split(',', $nfsc->{limit});
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};
	my $zoom = "--zoom=" . $config->{global_zoom};

	my $u = "";
	my $width;
	my $height;
	my @riglim;
	my @tmp;
	my @tmpz;
	my @tmp1;
	my @tmp2;
	my @tmp1z;
	my @tmp2z;
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

	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	my @nfsv2 = ("null", "getattr", "setattr", "root", "lookup", "readlink", "read", "wrcache", "write", "create", "remove", "rename", "link", "symlink", "mkdir", "rmdir", "readdir", "fsstat");
	my @nfsv3 = ("null", "getattr", "setattr", "lookup", "access", "readlink", "read", "write", "create", "mkdir", "symlink", "mknod", "remove", "rmdir", "rename", "link", "readdir", "readdirplus", "fsstat", "fsinfo", "pathconf", "commit");
	my @nfscv4 = ("null", "read", "write", "commit", "open", "open_conf", "open_noat", "open_dgrd", "close", "setattr", "fsinfo", "renew", "setclntid", "confirm", "lock", "lockt", "locku", "access", "getattr", "lookup", "lookup_root", "remove", "rename", "link", "symlink", "create", "pathconf", "statfs", "readlink", "readdir", "server_caps", "delegreturn", "getacl", "setacl", "fs_locations", "exchange_id", "create_ses", "destroy_ses", "sequence", "get_lease_t", "reclaim_comp", "layoutget", "layoutcommit", "layoutreturn", "getdevlist", "getdevinfo", "ds_write", "ds_commit");

	my @nfsv;

	# default version is NFS v3
	if($nfsc->{version} eq "2") {
		@nfsv = @nfsv2;
	} elsif($nfsc->{version} eq "4") {
		@nfsv = @nfscv4;
	} else {
		@nfsv = @nfsv3;
	}

	$title = !$silent ? $title : "";
	$title =~ s/NFS/NFS v$nfsc->{version}/;


	# text mode
	#
	if(lc($config->{iface_mode}) eq "text") {
		if($title) {
			main::graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$colors->{title_bg_color}'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"AVERAGE",
			"-r $tf->{res}");
		$err = RRDs::error;
		print("ERROR: while fetching $rrd: $err\n") if $err;
		my $str;
		my $line1;
		my $line2;
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		foreach my $t (@nfsv) {
			$str = sprintf("%12s ", $t);
			$line1 .= $str;
			$line2 .= "-------------";
		}
		$line1 .= sprintf("%12s %12s %12s", "calls", "retrans", "authrefrsh");
		$line2 .= "-------------" . "-------------" . "-------------";
		print("Time $line1\n");
		print("-----$line2\n");
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
			$time = $time - (1 / $tf->{ts});
			printf(" %2d$tf->{tc} $line1\n", $time, @row);
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			main::graph_footer();
		}
		print("  <br>\n");
		return;
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
	my $PNG1 = $u . $package . "1." . $tf->{when} . ".png";
	my $PNG2 = $u . $package . "2." . $tf->{when} . ".png";
	my $PNG3 = $u . $package . "3." . $tf->{when} . ".png";
	my $PNG4 = $u . $package . "4." . $tf->{when} . ".png";
	my $PNG5 = $u . $package . "5." . $tf->{when} . ".png";
	my $PNG6 = $u . $package . "6." . $tf->{when} . ".png";
	my $PNG1z = $u . $package . "1z." . $tf->{when} . ".png";
	my $PNG2z = $u . $package . "2z." . $tf->{when} . ".png";
	my $PNG3z = $u . $package . "3z." . $tf->{when} . ".png";
	my $PNG4z = $u . $package . "4z." . $tf->{when} . ".png";
	my $PNG5z = $u . $package . "5z." . $tf->{when} . ".png";
	my $PNG6z = $u . $package . "6z." . $tf->{when} . ".png";
	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3",
		"$PNG_DIR" . "$PNG4",
		"$PNG_DIR" . "$PNG5",
		"$PNG_DIR" . "$PNG6");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z",
			"$PNG_DIR" . "$PNG4z",
			"$PNG_DIR" . "$PNG5z",
			"$PNG_DIR" . "$PNG6z");
	}

	if($title) {
		main::graph_header($title, 2);
	}
	if(trim($rigid[0]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[0]));
	} else {
		if(trim($rigid[0]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[0]));
			push(@riglim, "--rigid");
		}
	}
	if($title) {
		print("    <tr>\n");
		print("    <td valign='top' bgcolor='$colors->{title_bg_color}'>\n");
	}
	for($n = 0; $n < 10; $n++) {
		my $str = trim((split(',', $nfsc->{graph_0}))[$n]) || "";
		if(grep { $_ eq $str } @nfsv) {
			my ($i) = grep { $nfsv[$_] eq $str } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$rrd:nfsc_$i:AVERAGE");
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
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$config->{graphs}->{_nfsc1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		@DEF,
		@CDEF,
		@tmp,
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$config->{graphs}->{_nfsc1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			@DEF,
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "'>\n");
		}
	}

	undef(@riglim);
	if(trim($rigid[1]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[1]));
	} else {
		if(trim($rigid[1]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[1]));
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	undef(@DEF);
	undef(@CDEF);
	undef(@allvalues);
	undef(@allsigns);
	for($n = 0; $n < 10; $n++) {
		my $str = trim((split(',', $nfsc->{graph_1}))[$n]) || "";
		if(grep { $_ eq $str } @nfsv) {
			my ($i) = grep { $nfsv[$_] eq $str } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$rrd:nfsc_$i:AVERAGE");
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
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$config->{graphs}->{_nfsc2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		@DEF,
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$config->{graphs}->{_nfsc2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			@DEF,
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "'>\n");
		}
	}

	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	undef(@riglim);
	if(trim($rigid[2]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[2]));
	} else {
		if(trim($rigid[2]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[2]));
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	undef(@tmp1);
	undef(@tmp2);
	undef(@tmp1z);
	undef(@tmp2z);
	undef(@DEF);
	undef(@CDEF);
	undef(@allvalues);
	undef(@allsigns);
	for($n = 0; $n < 4; $n++) {
		my $str = trim((split(',', $nfsc->{graph_2}))[$n]) || "";
		if(grep { $_ eq $str } @nfsv) {
			my ($i) = grep { $nfsv[$_] eq $str } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$rrd:nfsc_$i:AVERAGE");
			push(@tmp1, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@tmp1, "GPRINT:nfs_$i:LAST:         Current\\: %6.1lf\\n");
			push(@tmp2, "LINE1:nfs_$i$LC[$n]");
			push(@tmp1z, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@tmp2z, "LINE1:nfs_$i$LC[$n]");
			push(@allvalues, "nfs_$i");
			push(@allsigns, "+");
		} else {
			push(@tmp1, "COMMENT: \\n");
		}
	}
	@tmp = (@tmp1, @tmp2);
	@tmpz = (@tmp1z, @tmp2z);
	pop(@allsigns);
	push(@CDEF, "CDEF:allvalues=" . join(',', @allvalues, @allsigns));
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
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$config->{graphs}->{_nfsc3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		@DEF,
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$config->{graphs}->{_nfsc3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			@DEF,
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc3/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "'>\n");
		}
	}

	undef(@riglim);
	if(trim($rigid[3]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[3]));
	} else {
		if(trim($rigid[3]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[3]));
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	undef(@tmp1);
	undef(@tmp2);
	undef(@tmp1z);
	undef(@tmp2z);
	undef(@DEF);
	undef(@CDEF);
	undef(@allvalues);
	undef(@allsigns);
	for($n = 0; $n < 4; $n++) {
		my $str = trim((split(',', $nfsc->{graph_3}))[$n]) || "";
		if(grep { $_ eq $str } @nfsv) {
			my ($i) = grep { $nfsv[$_] eq $str } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$rrd:nfsc_$i:AVERAGE");
			push(@tmp1, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@tmp1, "GPRINT:nfs_$i:LAST:         Current\\: %6.1lf\\n");
			push(@tmp2, "LINE1:nfs_$i$LC[$n]");
			push(@tmp1z, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@tmp2z, "LINE1:nfs_$i$LC[$n]");
			push(@allvalues, "nfs_$i");
			push(@allsigns, "+");
		} else {
			push(@tmp1, "COMMENT: \\n");
		}
	}
	@tmp = (@tmp1, @tmp2);
	@tmpz = (@tmp1z, @tmp2z);
	pop(@allsigns);
	push(@CDEF, "CDEF:allvalues=" . join(',', @allvalues, @allsigns));
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
	RRDs::graph("$PNG_DIR" . "$PNG4",
		"--title=$config->{graphs}->{_nfsc4}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		@DEF,
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG4: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG4z",
			"--title=$config->{graphs}->{_nfsc4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			@DEF,
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc4/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG4z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG4 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG4z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG4 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG4 . "'>\n");
		}
	}

	undef(@riglim);
	if(trim($rigid[4]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[4]));
	} else {
		if(trim($rigid[4]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[4]));
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	undef(@tmp1);
	undef(@tmp2);
	undef(@tmp1z);
	undef(@tmp2z);
	undef(@DEF);
	undef(@CDEF);
	undef(@allvalues);
	undef(@allsigns);
	for($n = 0; $n < 4; $n++) {
		my $str = trim((split(',', $nfsc->{graph_4}))[$n]);
		if(grep { $_ eq $str } @nfsv) {
			my ($i) = grep { $nfsv[$_] eq $str } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$rrd:nfsc_$i:AVERAGE");
			push(@tmp1, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@tmp1, "GPRINT:nfs_$i:LAST:         Current\\: %6.1lf\\n");
			push(@tmp2, "LINE1:nfs_$i$LC[$n]");
			push(@tmp1z, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $str));
			push(@tmp2z, "LINE1:nfs_$i$LC[$n]");
			push(@allvalues, "nfs_$i");
			push(@allsigns, "+");
		} else {
			push(@tmp1, "COMMENT: \\n");
		}
	}
	@tmp = (@tmp1, @tmp2);
	@tmpz = (@tmp1z, @tmp2z);
	pop(@allsigns);
	push(@CDEF, "CDEF:allvalues=" . join(',', @allvalues, @allsigns));
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
	RRDs::graph("$PNG_DIR" . "$PNG5",
		"--title=$config->{graphs}->{_nfsc5}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		@DEF,
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG5: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG5z",
			"--title=$config->{graphs}->{_nfsc5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			@DEF,
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc5/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG5z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG5 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG5z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG5 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG5 . "'>\n");
		}
	}

	undef(@riglim);
	if(trim($rigid[5]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[5]));
	} else {
		if(trim($rigid[5]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[5]));
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:calls#44EEEE:Calls");
	push(@tmp, "GPRINT:calls:LAST:                Current\\: %7.1lf\\n");
	push(@tmp, "AREA:retrans#EEEE44:Retransmissions");
	push(@tmp, "GPRINT:retrans:LAST:      Current\\: %7.1lf\\n");
	push(@tmp, "AREA:authref#EE4444:Auth Refresh");
	push(@tmp, "GPRINT:authref:LAST:         Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:calls#00EEEE");
	push(@tmp, "LINE1:retrans#EEEE00");
	push(@tmp, "LINE1:authref#EE0000");
	push(@tmpz, "AREA:calls#44EEEE:Calls");
	push(@tmpz, "AREA:retrans#EEEE44:Retransmissions");
	push(@tmpz, "AREA:authref#EE4444:Auth Refresh");
	push(@tmpz, "LINE1:calls#00EEEE");
	push(@tmpz, "LINE1:retrans#EEEE00");
	push(@tmpz, "LINE1:authref#EE0000");
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
	RRDs::graph("$PNG_DIR" . "$PNG6",
		"--title=$config->{graphs}->{_nfsc6}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Requests/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:calls=$rrd:nfsc_rpc_1:AVERAGE",
		"DEF:retrans=$rrd:nfsc_rpc_2:AVERAGE",
		"DEF:authref=$rrd:nfsc_rpc_3:AVERAGE",
		"CDEF:allvalues=calls,retrans,authref,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG6: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG6z",
			"--title=$config->{graphs}->{_nfsc6}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:calls=$rrd:nfsc_rpc_1:AVERAGE",
			"DEF:retrans=$rrd:nfsc_rpc_2:AVERAGE",
			"DEF:authref=$rrd:nfsc_rpc_3:AVERAGE",
			"CDEF:allvalues=calls,retrans,authref,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG6z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc6/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG6z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG6 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG6z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG6 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG6 . "'>\n");
		}
	}

	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		main::graph_footer();
	}
	print("  <br>\n");
	return;
}

1;
