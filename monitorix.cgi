#!/usr/bin/env perl
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

no strict "vars";
no warnings "once";
use CGI qw/:standard/;
use POSIX;
use RRDs;

# load the path of the configuration file
open(IN, "< monitorix.conf.path");
my $opt_config = <IN>;
chomp($opt_config);
close(IN);
if(-f $opt_config) {
	require $opt_config;
} elsif(-f "/etc/monitorix.conf") {
	require "/etc/monitorix.conf";
} elsif(-f "/usr/local/etc/monitorix.conf") {
	require "/usr/local/etc/monitorix.conf";
} else {
	print("Content-Type: text/html\n");
	print("\n");
	print("Monitorix configuration file '$opt_config' not found!\n");
	print("Other possible locations also failed.\n");
	exit(1);
}

our $URL = $ENV{HTTPS} ? "https://" . $ENV{HTTP_HOST} : "http://" . $ENV{HTTP_HOST};
if(!($HOSTNAME)) {
	$HOSTNAME = $ENV{SERVER_NAME};
	if(!($HOSTNAME)) {	# called from the command line
		$HOSTNAME = "127.0.0.1";
		$URL = "http://127.0.0.1";
	}
}
$URL .= $BASE_URL . "/";

# get the current OS and kernel branch
my ($os, undef, $release) = uname();
my ($major, $minor) = split('\.', $release);
my $kernel_branch = $major . "." . $minor;

my $mode = defined(param('mode')) ? param('mode') : '';
my $graph = param('graph');
my $when = param('when');
my $color = param('color');
my $val = defined(param('val')) ? param('val') : '';
my $silent = defined(param('silent')) ? param('silent') : '';
if($mode ne "localhost") {
	($mode, $val)  = split(/\./, $mode);
}

my ($twhen) = ($when =~ m/(hour|day|week|month|year)$/);
(my $nwhen = $when) =~ s/$twhen// unless !$twhen;
$nwhen = 1 unless $nwhen;
$twhen = "day" unless $twhen;
$when = $nwhen . $twhen;

# toggle this to 1 if you want to maintain old (2.3-) Monitorix with Multihost
if($backwards_compat_old_multihost) {
	$when = $twhen;
}

our ($res, $tc, $tb, $ts);
($res, $tc, $tb, $ts) = (3600, 'h', 24, 1) if $twhen eq "day";
($res, $tc, $tb, $ts) = (108000, 'd', 7, 1) if $twhen eq "week";
($res, $tc, $tb, $ts) = (216000, 'd', 30, 1) if $twhen eq "month";
($res, $tc, $tb, $ts) = (5184000, 'd', 365, 1) if $twhen eq "year";

# Default colors (white theme)
our @graph_colors;
our $warning_color = "--color=CANVAS#880000";
our $bg_color = "#FFFFFF";
our $fg_color = "#000000";
our $title_bg_color = "#777777";
our $title_fg_color = "#CCCC00";
our $graph_bg_color = "#CCCCCC";

if($color) {
	if($color eq "black") {
		push(@graph_colors, "--color=CANVAS" . $BLACK{canvas});
		push(@graph_colors, "--color=BACK" . $BLACK{back});
		push(@graph_colors, "--color=FONT" . $BLACK{font});
		push(@graph_colors, "--color=MGRID" . $BLACK{mgrid});
		push(@graph_colors, "--color=GRID" . $BLACK{grid});
		push(@graph_colors, "--color=FRAME" . $BLACK{frame});
		push(@graph_colors, "--color=ARROW" . $BLACK{arrow});
		push(@graph_colors, "--color=SHADEA" . $BLACK{shadea});
		push(@graph_colors, "--color=SHADEB" . $BLACK{shadeb});
		push(@graph_colors, "--color=AXIS" . $BLACK{axis}) if defined($BLACK{axis});
		$bg_color = $BLACK{main_bg};
		$fg_color = $BLACK{main_fg};
		$title_bg_color = $BLACK{title_bg};
		$title_fg_color = $BLACK{title_fg};
		$graph_bg_color = $BLACK{graph_bg};
	}
}

my @VERSION12;
my @VERSION12_small;
if($RRDs::VERSION > 1.2) {
	push(@VERSION12, "--slope-mode");
	push(@VERSION12, "--font=LEGEND:7:");
	push(@VERSION12, "--font=TITLE:9:");
	push(@VERSION12, "--font=UNIT:8:");
	if($RRDs::VERSION >= 1.3) {
		push(@VERSION12, "--font=DEFAULT:0:Mono");
	}
	if($twhen eq "day") {
		push(@VERSION12, "--x-grid=HOUR:1:HOUR:6:HOUR:6:0:%R");
	}
	push(@VERSION12_small, "--font=TITLE:8:");
	push(@VERSION12_small, "--font=UNIT:7:");
	if($RRDs::VERSION >= 1.3) {
		push(@VERSION12_small, "--font=DEFAULT:0:Mono");
	}
} else {
	undef(@VERSION12);
	undef(@VERSION12_small);
}

our %rgraphs = reverse %GRAPHS;

my $u = "";
if($silent eq "yes" || $silent eq "imagetag") {
	$fg_color = "#000000";	# visible color for text mode
	$u = "_";
}
if($silent eq "imagetagbig") {
	$fg_color = "#000000";	# visible color for text mode
	$u = "";
}

our @nfsv2 = ("null", "getattr", "setattr", "root", "lookup", "readlink", "read", "wrcache", "write", "create", "remove", "rename", "link", "symlink", "mkdir", "rmdir", "readdir", "fsstat");
our @nfsv3 = ("null", "getattr", "setattr", "lookup", "access", "readlink", "read", "write", "create", "mkdir", "symlink", "mknod", "remove", "rmdir", "rename", "link", "readdir", "readdirplus", "fsstat", "fsinfo", "pathconf", "commit");
our @nfsv4 = ("null", "read", "write", "commit", "open", "open_conf", "open_noat", "open_dgrd", "close", "setattr", "fsinfo", "renew", "setclntid", "confirm", "lock", "lockt", "locku", "access", "getattr", "lookup", "lookup_root", "remove", "rename", "link", "symlink", "create", "pathconf", "statfs", "readlink", "readdir", "server_caps", "delegreturn", "getacl", "setacl", "fs_locations", "exchange_id", "create_ses", "destroy_ses", "sequence", "get_lease_t", "reclaim_comp", "layoutget", "layoutcommit", "layoutreturn", "getdevlist", "getdevinfo", "ds_write", "ds_commit");

sub get_uptime {
	my $str;
	my $uptime;

	if($os eq "Linux") {
		open(IN, "/proc/uptime");
		($uptime, undef) = split(' ', <IN>);
		close(IN);
	} elsif($os eq "FreeBSD") {
		open(IN, "/sbin/sysctl -n kern.boottime |");
		(undef, undef, undef, $uptime) = split(' ', <IN>);
		close(IN);
		$uptime =~ s/,//;
		$uptime = time - int($uptime);
	} elsif($os eq "OpenBSD" || $os eq "NetBSD") {
		open(IN, "/sbin/sysctl -n kern.boottime |");
		$uptime = <IN>;
		close(IN);
		chomp($uptime);
		$uptime = time - int($uptime);
	}

	my ($d, $h, $m);
	my ($d_string, $h_string, $m_string);

	$d = int($uptime / (60 * 60 * 24));
	$h = int($uptime / (60 * 60)) % 24;
	$m = int($uptime / 60) % 60;

	$d_string = $d ? sprintf("%d days,", $d) : "";
	$h_string = $h ? sprintf("%d", $h) : "";
	$m_string = $h ? sprintf("%sh %dm", $h, $m) : sprintf("%d min", $m);

	return "$d_string $m_string";
}

# SYSTEM graph
# ----------------------------------------------------------------------------
sub system {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @tmp;
	my @tmpz;
	my $n;
	my $err;

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";

	$title = !$silent ? $title : "";

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	if($os eq "Linux") {
		$MEMORY = `grep -w MemTotal: /proc/meminfo | awk '{print \$2}'`;
		chomp($MEMORY);
	} elsif(grep {$_ eq $os} ("FreeBSD", "OpenBSD", "NetBSD")) {
		$MEMORY = `/sbin/sysctl -n hw.physmem`;	# in bytes
		chomp($MEMORY);
		$MEMORY = int($MEMORY / 1024);		# in KB
	}
	$MEMORY = int($MEMORY / 1024);			# in MB

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$SYSTEM_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $SYSTEM_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("       CPU load average    Memory usage in MB     Processes\n");
		print("Time   1min  5min 15min    Used  Cached Buffers   Total   Run\n");
		print("------------------------------------------------------------- \n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			my ($load1, $load5, $load15, $nproc, $npslp, $nprun, $mtotl, $buff, $cach, $free) = @$line;
			$buff /= 1024;
			$cach /= 1024;
			$free /= 1024;
			@row = ($load1, $load5, $load15, $MEMORY - $free, $cach, $buff, $nproc, $nprun);
			$time = $time - (1 / $ts);
			printf(" %2d$tc   %4.1f  %4.1f  %4.1f  %6d  %6d  %6d   %5d %5d \n", $time, @row);
		}
		print("\n");
		print(" system uptime: " . get_uptime() . "\n");
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	if($title) {
		graph_header($title, 2);
	}
	if($SYSTEM1_RIGID eq 1) {
		push(@riglim, "--upper-limit=$SYSTEM1_LIMIT");
	} else {
		if($SYSTEM1_RIGID eq 2) {
			push(@riglim, "--upper-limit=$SYSTEM1_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	my $UPTIME = get_uptime();
	my $UPTIMELINE;
	if($RRDs::VERSION > 1.2) {
		$UPTIMELINE = "COMMENT:system uptime\\: " . $UPTIME . "\\c";
	} else {
		$UPTIMELINE = "COMMENT:system uptime: " . $UPTIME . "\\c";
	}

	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$title_bg_color'>\n");
	}
	push(@tmp, "AREA:load1#4444EE: 1 min average");
	push(@tmp, "GPRINT:load1:LAST:  Current\\: %4.2lf");
	push(@tmp, "GPRINT:load1:AVERAGE:   Average\\: %4.2lf");
	push(@tmp, "GPRINT:load1:MIN:   Min\\: %4.2lf");
	push(@tmp, "GPRINT:load1:MAX:   Max\\: %4.2lf\\n");
	push(@tmp, "LINE1:load1#0000EE");
	push(@tmp, "LINE1:load5#EEEE00: 5 min average");
	push(@tmp, "GPRINT:load5:LAST:  Current\\: %4.2lf");
	push(@tmp, "GPRINT:load5:AVERAGE:   Average\\: %4.2lf");
	push(@tmp, "GPRINT:load5:MIN:   Min\\: %4.2lf");
	push(@tmp, "GPRINT:load5:MAX:   Max\\: %4.2lf\\n");
	push(@tmp, "LINE1:load15#00EEEE:15 min average");
	push(@tmp, "GPRINT:load15:LAST:  Current\\: %4.2lf");
	push(@tmp, "GPRINT:load15:AVERAGE:   Average\\: %4.2lf");
	push(@tmp, "GPRINT:load15:MIN:   Min\\: %4.2lf");
	push(@tmp, "GPRINT:load15:MAX:   Max\\: %4.2lf\\n");
	push(@tmpz, "AREA:load1#4444EE: 1 min average");
	push(@tmpz, "LINE1:load1#0000EE");
	push(@tmpz, "LINE1:load5#EEEE00: 5 min average");
	push(@tmpz, "LINE1:load15#00EEEE:15 min average");
	if($os eq "FreeBSD") {
		push(@tmp, "COMMENT: \\n");
	}
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$rgraphs{_system1}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Load average",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		"DEF:load1=$SYSTEM_RRD:system_load1:AVERAGE",
		"DEF:load5=$SYSTEM_RRD:system_load5:AVERAGE",
		"DEF:load15=$SYSTEM_RRD:system_load15:AVERAGE",
		@tmp,
		"COMMENT: \\n",
		$UPTIMELINE);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$rgraphs{_system1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Load average",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:load1=$SYSTEM_RRD:system_load1:AVERAGE",
			"DEF:load5=$SYSTEM_RRD:system_load5:AVERAGE",
			"DEF:load15=$SYSTEM_RRD:system_load15:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /system1/)) {
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
	if($title) {
		print("    </td>\n");
		print("    <td bgcolor='" . $title_bg_color . "'>\n");
	}

	undef(@riglim);
	if($SYSTEM2_RIGID eq 1) {
		push(@riglim, "--upper-limit=$SYSTEM2_LIMIT");
	} else {
		if($SYSTEM2_RIGID eq 2) {
			push(@riglim, "--upper-limit=$SYSTEM2_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:npslp#44AAEE:Sleeping");
	push(@tmp, "AREA:nprun#EE4444:Running");
	push(@tmp, "LINE1:nprun#EE0000");
	push(@tmp, "LINE1:npslp#00EEEE");
	push(@tmp, "LINE1:nproc#EEEE00:Processes");
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$rgraphs{_system2}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Processes",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:nproc=$SYSTEM_RRD:system_nproc:AVERAGE",
		"DEF:npslp=$SYSTEM_RRD:system_npslp:AVERAGE",
		"DEF:nprun=$SYSTEM_RRD:system_nprun:AVERAGE",
		@tmp,
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$rgraphs{_system2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Processes",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:nproc=$SYSTEM_RRD:system_nproc:AVERAGE",
			"DEF:npslp=$SYSTEM_RRD:system_npslp:AVERAGE",
			"DEF:nprun=$SYSTEM_RRD:system_nprun:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /system2/)) {
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

	undef(@tmp);
	undef(@tmpz);
	if($os eq "Linux") {
		push(@tmp, "AREA:m_mused#EE4444:Used");
		push(@tmp, "AREA:m_mcach#44EE44:Cached");
		push(@tmp, "AREA:m_mbuff#CCCCCC:Buffers");
		push(@tmp, "LINE1:m_mbuff#888888");
		push(@tmp, "LINE1:m_mcach#00EE00");
		push(@tmp, "LINE1:m_mused#EE0000");
	} elsif($os eq "FreeBSD") {
		push(@tmp, "AREA:m_mused#EE4444:Used");
		push(@tmp, "AREA:m_mcach#44EE44:Cached");
		push(@tmp, "AREA:m_mbuff#CCCCCC:Buffers");
		push(@tmp, "AREA:m_macti#EEEE44:Active");
		push(@tmp, "AREA:m_minac#4444EE:Inactive");
		push(@tmp, "LINE1:m_minac#0000EE");
		push(@tmp, "LINE1:m_macti#EEEE00");
		push(@tmp, "LINE1:m_mbuff#888888");
		push(@tmp, "LINE1:m_mcach#00EE00");
		push(@tmp, "LINE1:m_mused#EE0000");
	} elsif($os eq "OpenBSD" || $os eq "NetBSD") {
		push(@tmp, "AREA:m_mused#EE4444:Used");
		push(@tmp, "AREA:m_macti#44EE44:Active");
		push(@tmp, "LINE1:m_macti#00EE00");
		push(@tmp, "LINE1:m_mused#EE0000");
	}
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$rgraphs{_system3} (${MEMORY}MB)  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Megabytes",
		"--width=$width",
		"--height=$height",
		"--upper-limit=$MEMORY",
		"--lower-limit=0",
		"--base=1024",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:mtotl=$SYSTEM_RRD:system_mtotl:AVERAGE",
		"DEF:mbuff=$SYSTEM_RRD:system_mbuff:AVERAGE",
		"DEF:mcach=$SYSTEM_RRD:system_mcach:AVERAGE",
		"DEF:mfree=$SYSTEM_RRD:system_mfree:AVERAGE",
		"DEF:macti=$SYSTEM_RRD:system_macti:AVERAGE",
		"DEF:minac=$SYSTEM_RRD:system_minac:AVERAGE",
		"CDEF:m_mtotl=mtotl,1024,/",
		"CDEF:m_mbuff=mbuff,1024,/",
		"CDEF:m_mcach=mcach,1024,/",
		"CDEF:m_mused=m_mtotl,mfree,1024,/,-",
		"CDEF:m_macti=macti,1024,/",
		"CDEF:m_minac=minac,1024,/",
		@tmp,
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$rgraphs{_system3} (${MEMORY}MB)  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Megabytes",
			"--width=$width",
			"--height=$height",
			"--upper-limit=$MEMORY",
			"--lower-limit=0",
			"--base=1024",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:mtotl=$SYSTEM_RRD:system_mtotl:AVERAGE",
			"DEF:mbuff=$SYSTEM_RRD:system_mbuff:AVERAGE",
			"DEF:mcach=$SYSTEM_RRD:system_mcach:AVERAGE",
			"DEF:mfree=$SYSTEM_RRD:system_mfree:AVERAGE",
			"DEF:macti=$SYSTEM_RRD:system_macti:AVERAGE",
			"DEF:minac=$SYSTEM_RRD:system_minac:AVERAGE",
			"CDEF:m_mtotl=mtotl,1024,/",
			"CDEF:m_mbuff=mbuff,1024,/",
			"CDEF:m_mcach=mcach,1024,/",
			"CDEF:m_mused=m_mtotl,mfree,1024,/,-",
			"CDEF:m_macti=macti,1024,/",
			"CDEF:m_minac=minac,1024,/",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /system3/)) {
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
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

# KERN graph
# ----------------------------------------------------------------------------
sub kern {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @tmp;
	my @tmpz;
	my $vlabel;
	my $n;
	my $err;

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";

	$title = !$silent ? $title : "";

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$KERN_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $KERN_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("       Kernel usage                                                                           VFS usage\n");
		print("Time   User   Nice    Sys   Idle   I/Ow    IRQ   sIRQ  Steal  Guest   Ctxt.Sw  Forks  VForks  dentry   file  inode\n");
		print("------------------------------------------------------------------------------------------------------------------\n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			my ($usr, $nic, $sys, $idle, $iow, $irq, $sirq, $steal, $guest, $cs, $dentry, $file, $inode, $forks, $vforks) = @$line;
			@row = ($usr, $nic, $sys, $idle, $iow, $irq, $sirq, $steal, $guest, $cs, $forks, $vforks, $dentry, $file, $inode);
			$time = $time - (1 / $ts);
			printf(" %2d$tc  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%   %7d %6d  %6d   %4.1f%%  %4.1f%%  %4.1f%% \n", $time, @row);
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	if($title) {
		graph_header($title, 2);
	}

	if($KERN1_RIGID eq 1) {
		push(@riglim, "--upper-limit=$KERN1_LIMIT");
	} else {
		if($KERN1_RIGID eq 2) {
			push(@riglim, "--upper-limit=$KERN1_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	if($KERN_GRAPH_MODE eq "R") {
		$vlabel = "Percent (%)";
		if($KERN_DATA{user} eq "Y") {
			push(@tmp, "AREA:user#4444EE:user");
			push(@tmpz, "AREA:user#4444EE:user");
			push(@tmp, "GPRINT:user:LAST:      Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:MAX:    Max\\: %4.1lf%%\\n");
		}
		if($KERN_DATA{nice} eq "Y") {
			push(@tmp, "AREA:nice#EEEE44:nice");
			push(@tmpz, "AREA:nice#EEEE44:nice");
			push(@tmp, "GPRINT:nice:LAST:      Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:MAX:    Max\\: %4.1lf%%\\n");
		}
		if($KERN_DATA{sys} eq "Y") {
			push(@tmp, "AREA:sys#44EEEE:system");
			push(@tmpz, "AREA:sys#44EEEE:system");
			push(@tmp, "GPRINT:sys:LAST:    Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:MAX:    Max\\: %4.1lf%%\\n");
		}
		if($KERN_DATA{iow} eq "Y") {
			push(@tmp, "AREA:iow#EE44EE:I/O wait");
			push(@tmpz, "AREA:iow#EE44EE:I/O wait");
			push(@tmp, "GPRINT:iow:LAST:  Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:MAX:    Max\\: %4.1lf%%\\n");
		}
		if($os eq "Linux") {
			if($KERN_DATA{irq} eq "Y") {
				push(@tmp, "AREA:irq#888888:IRQ");
				push(@tmpz, "AREA:irq#888888:IRQ");
				push(@tmp, "GPRINT:irq:LAST:       Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:MAX:    Max\\: %4.1lf%%\\n");
			}
			if($KERN_DATA{sirq} eq "Y") {
				push(@tmp, "AREA:sirq#E29136:softIRQ");
				push(@tmpz, "AREA:sirq#E29136:softIRQ");
				push(@tmp, "GPRINT:sirq:LAST:   Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:MAX:    Max\\: %4.1lf%%\\n");
			}
			if($KERN_DATA{steal} eq "Y") {
				push(@tmp, "AREA:steal#44EE44:steal");
				push(@tmpz, "AREA:steal#44EE44:steal");
				push(@tmp, "GPRINT:steal:LAST:     Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:MAX:    Max\\: %4.1lf%%\\n");
			}
			if($KERN_DATA{guest} eq "Y") {
				push(@tmp, "AREA:guest#448844:guest");
				push(@tmpz, "AREA:guest#448844:guest");
				push(@tmp, "GPRINT:guest:LAST:     Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:MAX:    Max\\: %4.1lf%%\\n");
			}
			push(@tmp, "LINE1:guest#1F881F") unless $KERN_DATA{guest} ne "Y";
			push(@tmpz, "LINE1:guest#1F881F") unless $KERN_DATA{guest} ne "Y";
			push(@tmp, "LINE1:steal#00EE00") unless $KERN_DATA{steal} ne "Y";
			push(@tmpz, "LINE1:steal#00EE00") unless $KERN_DATA{steal} ne "Y";
			push(@tmp, "LINE1:sirq#D86612") unless $KERN_DATA{sirq} ne "Y";
			push(@tmpz, "LINE1:sirq#D86612") unless $KERN_DATA{sirq} ne "Y";
			push(@tmp, "LINE1:irq#CCCCCC") unless $KERN_DATA{irq} ne "Y";
			push(@tmpz, "LINE1:irq#CCCCCC") unless $KERN_DATA{irq} ne "Y";
		}
		push(@tmp, "LINE1:iow#EE00EE") unless $KERN_DATA{iow} ne "Y";
		push(@tmpz, "LINE1:iow#EE00EE") unless $KERN_DATA{iow} ne "Y";
		push(@tmp, "LINE1:sys#00EEEE") unless $KERN_DATA{sys} ne "Y";
		push(@tmpz, "LINE1:sys#00EEEE") unless $KERN_DATA{sys} ne "Y";
		push(@tmp, "LINE1:nice#EEEE00") unless $KERN_DATA{nice} ne "Y";
		push(@tmpz, "LINE1:nice#EEEE00") unless $KERN_DATA{nice} ne "Y";
		push(@tmp, "LINE1:user#0000EE") unless $KERN_DATA{user} ne "Y";
		push(@tmpz, "LINE1:user#0000EE") unless $KERN_DATA{user} ne "Y";
	} else {
		$vlabel = "Stacked Percent (%)";
		push(@tmp, "CDEF:s_nice=user,nice,+");
		push(@tmpz, "CDEF:s_nice=user,nice,+");
		push(@tmp, "CDEF:s_sys=s_nice,sys,+");
		push(@tmpz, "CDEF:s_sys=s_nice,sys,+");
		push(@tmp, "CDEF:s_iow=s_sys,iow,+");
		push(@tmpz, "CDEF:s_iow=s_sys,iow,+");
		if($os eq "Linux") {
			push(@tmp, "CDEF:s_irq=s_iow,irq,+");
			push(@tmpz, "CDEF:s_irq=s_iow,irq,+");
			push(@tmp, "CDEF:s_sirq=s_irq,sirq,+");
			push(@tmpz, "CDEF:s_sirq=s_irq,sirq,+");
			push(@tmp, "CDEF:s_steal=s_sirq,steal,+");
			push(@tmpz, "CDEF:s_steal=s_sirq,steal,+");
			push(@tmp, "CDEF:s_guest=s_steal,guest,+");
			push(@tmpz, "CDEF:s_guest=s_steal,guest,+");
			if($KERN_DATA{guest} eq "Y") {
				push(@tmp, "AREA:s_guest#448844:guest");
				push(@tmpz, "AREA:s_guest#448844:guest");
				push(@tmp, "GPRINT:guest:LAST:     Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:MAX:    Max\\: %4.1lf%%\\n");
			}
			if($KERN_DATA{steal} eq "Y") {
				push(@tmp, "AREA:s_steal#44EE44:steal");
				push(@tmpz, "AREA:s_steal#44EE44:steal");
				push(@tmp, "GPRINT:steal:LAST:     Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:MAX:    Max\\: %4.1lf%%\\n");
			}
			if($KERN_DATA{sirq} eq "Y") {
				push(@tmp, "AREA:s_sirq#E29136:softIRQ");
				push(@tmpz, "AREA:s_sirq#E29136:softIRQ");
				push(@tmp, "GPRINT:sirq:LAST:   Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:MAX:    Max\\: %4.1lf%%\\n");
			}
			if($KERN_DATA{irq} eq "Y") {
				push(@tmp, "AREA:s_irq#888888:IRQ");
				push(@tmpz, "AREA:s_irq#888888:IRQ");
				push(@tmp, "GPRINT:irq:LAST:       Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:MAX:    Max\\: %4.1lf%%\\n");
			}
		}	
		if($KERN_DATA{iow} eq "Y") {
			push(@tmp, "AREA:s_iow#EE44EE:I/O wait");
			push(@tmpz, "AREA:s_iow#EE44EE:I/O wait");
			push(@tmp, "GPRINT:iow:LAST:  Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:MAX:    Max\\: %4.1lf%%\\n");
		}
		if($KERN_DATA{sys} eq "Y") {
			push(@tmp, "AREA:s_sys#44EEEE:system");
			push(@tmpz, "AREA:s_sys#44EEEE:system");
			push(@tmp, "GPRINT:sys:LAST:    Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:MAX:    Max\\: %4.1lf%%\\n");
		}
		if($KERN_DATA{nice} eq "Y") {
			push(@tmp, "AREA:s_nice#EEEE44:nice");
			push(@tmpz, "AREA:s_nice#EEEE44:nice");
			push(@tmp, "GPRINT:nice:LAST:      Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:MAX:    Max\\: %4.1lf%%\\n");
		}
		if($KERN_DATA{user} eq "Y") {
			push(@tmp, "AREA:user#4444EE:user");
			push(@tmpz, "AREA:user#4444EE:user");
			push(@tmp, "GPRINT:user:LAST:      Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:MAX:    Max\\: %4.1lf%%\\n");
		}
		if($os eq "Linux") {
			push(@tmp, "LINE1:s_guest#1F881F");
			push(@tmpz, "LINE1:s_guest#1F881F");
			push(@tmp, "LINE1:s_steal#00EE00");
			push(@tmpz, "LINE1:s_steal#00EE00");
			push(@tmp, "LINE1:s_sirq#D86612");
			push(@tmpz, "LINE1:s_sirq#D86612");
			push(@tmp, "LINE1:s_irq#CCCCCC");
			push(@tmpz, "LINE1:s_irq#CCCCCC");
		}	
		push(@tmp, "LINE1:s_iow#EE00EE");
		push(@tmpz, "LINE1:s_iow#EE00EE");
		push(@tmp, "LINE1:s_sys#00EEEE");
		push(@tmpz, "LINE1:s_sys#00EEEE");
		push(@tmp, "LINE1:s_nice#EEEE00");
		push(@tmpz, "LINE1:s_nice#EEEE00");
		push(@tmp, "LINE1:user#0000EE");
		push(@tmpz, "LINE1:user#0000EE");
	}
	if(grep {$_ eq $os} ("FreeBSD", "OpenBSD", "NetBSD")) {
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}

	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$title_bg_color'>\n");
	}
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$rgraphs{_kern1}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		"DEF:user=$KERN_RRD:kern_user:AVERAGE",
		"DEF:nice=$KERN_RRD:kern_nice:AVERAGE",
		"DEF:sys=$KERN_RRD:kern_sys:AVERAGE",
		"DEF:iow=$KERN_RRD:kern_iow:AVERAGE",
		"DEF:irq=$KERN_RRD:kern_irq:AVERAGE",
		"DEF:sirq=$KERN_RRD:kern_sirq:AVERAGE",
		"DEF:steal=$KERN_RRD:kern_steal:AVERAGE",
		"DEF:guest=$KERN_RRD:kern_guest:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$rgraphs{_kern1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:user=$KERN_RRD:kern_user:AVERAGE",
			"DEF:nice=$KERN_RRD:kern_nice:AVERAGE",
			"DEF:sys=$KERN_RRD:kern_sys:AVERAGE",
			"DEF:iow=$KERN_RRD:kern_iow:AVERAGE",
			"DEF:irq=$KERN_RRD:kern_irq:AVERAGE",
			"DEF:sirq=$KERN_RRD:kern_sirq:AVERAGE",
			"DEF:steal=$KERN_RRD:kern_steal:AVERAGE",
			"DEF:guest=$KERN_RRD:kern_guest:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /kern1/)) {
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
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
	}

	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:cs#44AAEE:Context switches");
	push(@tmpz, "AREA:cs#44AAEE:Context switches");
	push(@tmp, "GPRINT:cs:LAST:     Current\\: %6.0lf\\n");
	push(@tmp, "AREA:forks#4444EE:Forks");
	push(@tmpz, "AREA:forks#4444EE:Forks");
	push(@tmp, "GPRINT:forks:LAST:                Current\\: %6.0lf\\n");
	push(@tmp, "LINE1:cs#00EEEE");
	push(@tmp, "LINE1:forks#0000EE");
	push(@tmpz, "LINE1:cs#00EEEE");
	push(@tmpz, "LINE1:forks#0000EE");
	if($os eq "FreeBSD" || $os eq "OpenBSD") {
		push(@tmp, "AREA:vforks#EE4444:VForks");
		push(@tmpz, "AREA:vforks#EE4444:VForks");
		push(@tmp, "GPRINT:vforks:LAST:               Current\\: %6.0lf\\n");
		push(@tmp, "LINE1:vforks#EE0000");
		push(@tmpz, "LINE1:vforks#EE0000");
	}

	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$rgraphs{_kern2}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=CS & forks/s",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:cs=$KERN_RRD:kern_cs:AVERAGE",
		"DEF:forks=$KERN_RRD:kern_forks:AVERAGE",
		"DEF:vforks=$KERN_RRD:kern_vforks:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$rgraphs{_kern2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=CS & forks/s",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:cs=$KERN_RRD:kern_cs:AVERAGE",
			"DEF:forks=$KERN_RRD:kern_forks:AVERAGE",
			"DEF:vforks=$KERN_RRD:kern_vforks:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /kern2/)) {
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

	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:inode#4444EE:inode");
	push(@tmpz, "AREA:inode#4444EE:inode");
	push(@tmp, "GPRINT:inode:LAST:                Current\\:  %4.1lf%%\\n");
	if($os eq "Linux") {
		push(@tmp, "AREA:dentry#EEEE44:dentry");
		push(@tmpz, "AREA:dentry#EEEE44:dentry");
		push(@tmp, "GPRINT:dentry:LAST:               Current\\:  %4.1lf%%\\n");
	}
	push(@tmp, "AREA:file#EE44EE:file");
	push(@tmpz, "AREA:file#EE44EE:file");
	push(@tmp, "GPRINT:file:LAST:                 Current\\:  %4.1lf%%\\n");
	push(@tmp, "LINE2:inode#0000EE");
	push(@tmpz, "LINE2:inode#0000EE");
	if($os eq "Linux") {
		push(@tmp, "LINE2:dentry#EEEE00");
		push(@tmpz, "LINE2:dentry#EEEE00");
	}	
	push(@tmp, "LINE2:file#EE00EE");
	push(@tmpz, "LINE2:file#EE00EE");
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$rgraphs{_kern3}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Percent (%)",
		"--width=$width",
		"--height=$height",
		"--upper-limit=100",
		"--lower-limit=0",
		"--rigid",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:dentry=$KERN_RRD:kern_dentry:AVERAGE",
		"DEF:file=$KERN_RRD:kern_file:AVERAGE",
		"DEF:inode=$KERN_RRD:kern_inode:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$rgraphs{_kern3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			"--upper-limit=100",
			"--lower-limit=0",
			"--rigid",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:dentry=$KERN_RRD:kern_dentry:AVERAGE",
			"DEF:file=$KERN_RRD:kern_file:AVERAGE",
			"DEF:inode=$KERN_RRD:kern_inode:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /kern3/)) {
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
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

# PROC graph
# ----------------------------------------------------------------------------
sub proc {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my $vlabel;
	my $ncpu;
	my $n;
	my $str;
	my $err;

	if($os eq "Linux") {
		$ncpu = `grep -w processor /proc/cpuinfo | tail -1 | awk '{ print \$3 }'`;
		chomp($ncpu);
		$ncpu++;
	} elsif($os eq "FreeBSD") {
		$ncpu = `/sbin/sysctl -n hw.ncpu`;
		chomp($ncpu);
	}
	$ncpu = $ncpu > $PROC_MAX ? $PROC_MAX : $ncpu;
	return 0 unless $ncpu > 1;

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$PROC_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $PROC_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		for($n = 0; $n < $ncpu; $n++) {
			print("       Processor " . sprintf("%3d", $n) . "                                   ");
		}
		print("\nTime");
		for($n = 0; $n < $ncpu; $n++) {
			print("   User  Nice   Sys  Idle  I/Ow   IRQ  sIRQ Steal Guest");
		}
		print(" \n----");
		for($n = 0; $n < $ncpu; $n++) {
			print("-------------------------------------------------------");
		}
		print(" \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc ", $time);
			for($n2 = 0; $n2 < $ncpu; $n2++) {
				$from = $n2 * $ncpu;
				$to = $from + $ncpu;
				my ($usr, $nic, $sys, $idle, $iow, $irq, $sirq, $steal, $guest,) = @$line[$from..$to];
				@row = ($usr, $nic, $sys, $idle, $iow, $irq, $sirq, $steal, $guest);
				printf(" %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%% ", @row);
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	for($n = 0; $n < $ncpu; $n++) {
		$str = $u . $myself . $n . "." . $when . ".png";
		push(@PNG, $str);
		unlink("$PNG_DIR" . $str);
		if($ENABLE_ZOOM eq "Y") {
			$str = $u . $myself . $n . "z." . $when . ".png";
			push(@PNGz, $str);
			unlink("$PNG_DIR" . $str);
		}
	}

	if($PROC_RIGID eq 1) {
		push(@riglim, "--upper-limit=$PROC_LIMIT");
	} else {
		if($PROC_RIGID eq 2) {
			push(@riglim, "--upper-limit=$PROC_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	$n = 0;
	while($n < $ncpu) {
		if($title) {
			if($n == 0) {
				graph_header($title, $PROC_PER_ROW);
			}
			print("    <tr>\n");
		}
		for($n2 = 0; $n2 < $PROC_PER_ROW; $n2++) {
			last unless $n < $ncpu;
			if($title) {
				print("    <td bgcolor='" . $title_bg_color . "'>\n");
			}
			undef(@tmp);
			undef(@tmpz);
			if($KERN_GRAPH_MODE eq "R") {
				$vlabel = "Percent (%)";
				if($KERN_DATA{user} eq "Y") {
					push(@tmp, "AREA:user#4444EE:user");
					push(@tmpz, "AREA:user#4444EE:user");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:user:LAST:    Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:user:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:user:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:user:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{nice} eq "Y") {
					push(@tmp, "AREA:nice#EEEE44:nice");
					push(@tmpz, "AREA:nice#EEEE44:nice");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:nice:LAST:    Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{sys} eq "Y") {
					push(@tmp, "AREA:sys#44EEEE:system");
					push(@tmpz, "AREA:sys#44EEEE:system");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:sys:LAST:  Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{iow} eq "Y") {
					push(@tmp, "AREA:iow#EE44EE:I/O wait");
					push(@tmpz, "AREA:iow#EE44EE:I/O wait");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:iow:LAST:Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{irq} eq "Y") {
					push(@tmp, "AREA:irq#888888:IRQ");
					push(@tmpz, "AREA:irq#888888:IRQ");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:irq:LAST:     Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{sirq} eq "Y") {
					push(@tmp, "AREA:sirq#E29136:softIRQ");
					push(@tmpz, "AREA:sirq#E29136:softIRQ");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:sirq:LAST: Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{steal} eq "Y") {
					push(@tmp, "AREA:steal#44EE44:steal");
					push(@tmpz, "AREA:steal#44EE44:steal");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:steal:LAST:   Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{guest} eq "Y") {
					push(@tmp, "AREA:guest#448844:guest");
					push(@tmpz, "AREA:guest#448844:guest");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:guest:LAST:   Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				push(@tmp, "LINE1:guest#1F881F") unless $KERN_DATA{guest} ne "Y";
				push(@tmpz, "LINE1:guest#1F881F") unless $KERN_DATA{guest} ne "Y";
				push(@tmp, "LINE1:steal#00EE00") unless $KERN_DATA{steal} ne "Y";
				push(@tmpz, "LINE1:steal#00EE00") unless $KERN_DATA{steal} ne "Y";
				push(@tmp, "LINE1:sirq#D86612") unless $KERN_DATA{sirq} ne "Y";
				push(@tmpz, "LINE1:sirq#D86612") unless $KERN_DATA{sirq} ne "Y";
				push(@tmp, "LINE1:irq#CCCCCC") unless $KERN_DATA{irq} ne "Y";
				push(@tmpz, "LINE1:irq#CCCCCC") unless $KERN_DATA{irq} ne "Y";
				push(@tmp, "LINE1:iow#EE00EE") unless $KERN_DATA{iow} ne "Y";
				push(@tmpz, "LINE1:iow#EE00EE") unless $KERN_DATA{iow} ne "Y";
				push(@tmp, "LINE1:sys#00EEEE") unless $KERN_DATA{sys} ne "Y";
				push(@tmpz, "LINE1:sys#00EEEE") unless $KERN_DATA{sys} ne "Y";
				push(@tmp, "LINE1:nice#EEEE00") unless $KERN_DATA{nice} ne "Y";
				push(@tmpz, "LINE1:nice#EEEE00") unless $KERN_DATA{nice} ne "Y";
				push(@tmp, "LINE1:user#0000EE") unless $KERN_DATA{user} ne "Y";
				push(@tmpz, "LINE1:user#0000EE") unless $KERN_DATA{user} ne "Y";
			} else {
				$vlabel = "Stacked Percent (%)";
				push(@tmp, "CDEF:s_nice=user,nice,+");
				push(@tmpz, "CDEF:s_nice=user,nice,+");
				push(@tmp, "CDEF:s_sys=s_nice,sys,+");
				push(@tmpz, "CDEF:s_sys=s_nice,sys,+");
				push(@tmp, "CDEF:s_iow=s_sys,iow,+");
				push(@tmpz, "CDEF:s_iow=s_sys,iow,+");
				push(@tmp, "CDEF:s_irq=s_iow,irq,+");
				push(@tmpz, "CDEF:s_irq=s_iow,irq,+");
				push(@tmp, "CDEF:s_sirq=s_irq,sirq,+");
				push(@tmpz, "CDEF:s_sirq=s_irq,sirq,+");
				push(@tmp, "CDEF:s_steal=s_sirq,steal,+");
				push(@tmpz, "CDEF:s_steal=s_sirq,steal,+");
				push(@tmp, "CDEF:s_guest=s_steal,guest,+");
				push(@tmpz, "CDEF:s_guest=s_steal,guest,+");
				if($KERN_DATA{guest} eq "Y") {
					push(@tmp, "AREA:s_guest#E29136:guest");
					push(@tmpz, "AREA:s_guest#E29136:guest");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:guest:LAST:   Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{steal} eq "Y") {
					push(@tmp, "AREA:s_steal#888888:steal");
					push(@tmpz, "AREA:s_steal#888888:steal");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:steal:LAST:   Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{sirq} eq "Y") {
					push(@tmp, "AREA:s_sirq#448844:softIRQ");
					push(@tmpz, "AREA:s_sirq#448844:softIRQ");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:sirq:LAST: Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{irq} eq "Y") {
					push(@tmp, "AREA:s_irq#44EE44:IRQ");
					push(@tmpz, "AREA:s_irq#44EE44:IRQ");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:irq:LAST:     Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{iow} eq "Y") {
					push(@tmp, "AREA:s_iow#EE44EE:I/O wait");
					push(@tmpz, "AREA:s_iow#EE44EE:I/O wait");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:iow:LAST:Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{sys} eq "Y") {
					push(@tmp, "AREA:s_sys#44EEEE:system");
					push(@tmpz, "AREA:s_sys#44EEEE:system");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:sys:LAST:  Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{nice} eq "Y") {
					push(@tmp, "AREA:s_nice#EEEE44:nice");
					push(@tmpz, "AREA:s_nice#EEEE44:nice");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:nice:LAST:    Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if($KERN_DATA{user} eq "Y") {
					push(@tmp, "AREA:user#4444EE:user");
					push(@tmpz, "AREA:user#4444EE:user");
					if($PROC_DATA eq "Y") {
						push(@tmp, "GPRINT:user:LAST:    Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:user:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:user:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:user:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				push(@tmp, "LINE1:s_guest#D86612");
				push(@tmpz, "LINE1:s_guest#D86612");
				push(@tmp, "LINE1:s_steal#CCCCCC");
				push(@tmpz, "LINE1:s_steal#CCCCCC");
				push(@tmp, "LINE1:s_sirq#1F881F");
				push(@tmpz, "LINE1:s_sirq#1F881F");
				push(@tmp, "LINE1:s_irq#00EE00");
				push(@tmpz, "LINE1:s_irq#00EE00");
				push(@tmp, "LINE1:s_iow#EE00EE");
				push(@tmpz, "LINE1:s_iow#EE00EE");
				push(@tmp, "LINE1:s_sys#00EEEE");
				push(@tmpz, "LINE1:s_sys#00EEEE");
				push(@tmp, "LINE1:s_nice#EEEE00");
				push(@tmpz, "LINE1:s_nice#EEEE00");
				push(@tmp, "LINE1:user#0000EE");
				push(@tmpz, "LINE1:user#0000EE");
			}
			($width, $height) = split('x', $GRAPH_SIZE{$PROC_SIZE});
			RRDs::graph("$PNG_DIR" . "$PNG[$n]",
				"--title=$rgraphs{_proc} $n  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:user=$PROC_RRD:proc" . $n . "_user:AVERAGE",
				"DEF:nice=$PROC_RRD:proc" . $n . "_nice:AVERAGE",
				"DEF:sys=$PROC_RRD:proc" . $n . "_sys:AVERAGE",
				"DEF:iow=$PROC_RRD:proc" . $n . "_iow:AVERAGE",
				"DEF:irq=$PROC_RRD:proc" . $n . "_irq:AVERAGE",
				"DEF:sirq=$PROC_RRD:proc" . $n . "_sirq:AVERAGE",
				"DEF:steal=$PROC_RRD:proc" . $n . "_steal:AVERAGE",
				"DEF:guest=$PROC_RRD:proc" . $n . "_guest:AVERAGE",
				@tmp);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG[$n]: $err\n") if $err;
			if($ENABLE_ZOOM eq "Y") {
				($width, $height) = split('x', $GRAPH_SIZE{zoom});
				RRDs::graph("$PNG_DIR" . "$PNGz[$n]",
					"--title=$rgraphs{_proc} $n  ($nwhen$twhen)",
					"--start=-$nwhen$twhen",
					"--imgformat=PNG",
					"--vertical-label=$vlabel",
					"--width=$width",
					"--height=$height",
					@riglim,
					"--lower-limit=0",
					@VERSION12,
					@VERSION12_small,
					@graph_colors,
					"DEF:user=$PROC_RRD:proc" . $n . "_user:AVERAGE",
					"DEF:nice=$PROC_RRD:proc" . $n . "_nice:AVERAGE",
					"DEF:sys=$PROC_RRD:proc" . $n . "_sys:AVERAGE",
					"DEF:iow=$PROC_RRD:proc" . $n . "_iow:AVERAGE",
					"DEF:irq=$PROC_RRD:proc" . $n . "_irq:AVERAGE",
					"DEF:sirq=$PROC_RRD:proc" . $n . "_sirq:AVERAGE",
					"DEF:steal=$PROC_RRD:proc" . $n . "_steal:AVERAGE",
					"DEF:guest=$PROC_RRD:proc" . $n . "_guest:AVERAGE",
					@tmpz);
				$err = RRDs::error;
				print("ERROR: while graphing $PNG_DIR" . "$PNGz[$n]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /proc$n/)) {
				if($ENABLE_ZOOM eq "Y") {
					if($DISABLE_JAVASCRIPT_VOID eq "Y") {
						print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$n] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$n] . "' border='0'></a>\n");
					}
					else {
						print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$n] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$n] . "' border='0'></a>\n");
					}
				} else {
					print("      <img src='" . $URL . $IMGS_DIR . $PNG[$n] . "'>\n");
				}
			}
			if($title) {
				print("    </td>\n");
			}
			$n++;
		}
		if($title) {
			print("    </tr>\n");
		}
	}
	if($title) {
		graph_footer();
	}
	return 1;
}

# HPTEMP graph
# ----------------------------------------------------------------------------
sub hptemp {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @tmp;
	my @tmpz;
	my $n;
	my $id;
	my $str;
	my $err;
	my @LC = (
		"#FFA500",
		"#44EEEE",
		"#44EE44",
		"#4444EE",
		"#448844",
		"#EE4444",
		"#EE44EE",
		"#EEEE44",
	);

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";

	$title = !$silent ? $title : "";

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	open(IN, "monitorix.hplog");
	my @hplog = <IN>;
	close(IN);

	if(!scalar(@hplog)) {
		print("WARNING: 'hplog' command output is empty.");
	}
	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$HPTEMP_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $HPTEMP_RRD: $err\n") if $err;
		my $str;
		my $line1;
		my $line2;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		foreach my $t (@HPTEMP_1, @HPTEMP_2, @HPTEMP_3) {
			$id = sprintf("%2d", $t);
			for($n = 0; $n < scalar(@hplog); $n++) {
				$_ = $hplog[$n];
				if(/^$id  /) {
					$str = substr($_, 17, 8);
					$str = sprintf("%8s", $str);
					$line1 .= "  ";
					$line1 .= $str;
					$line2 .= "----------";
				}
			}
		}
		print("Time $line1 \n");
		print("-----$line2\n");
		my $line;
		my @row;
		my $time;
		my $n2;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc ", $time);
			undef($line1);
			undef(@row);
			for($n2 = 0; $n2 < scalar(@HPTEMP_1); $n2++) {
				my $temp = @$line[$n2];
				push(@row, $temp);
				$line1 .= " %8.0f ";
			}
			for($n2 = 0; $n2 < scalar(@HPTEMP_2); $n2++) {
				my $temp = @$line[8 + $n2];
				push(@row, $temp);
				$line1 .= " %8.0f ";
			}
			for($n2 = 0; $n2 < scalar(@HPTEMP_3); $n2++) {
				my $temp = @$line[8 + 3 + $n2];
				push(@row, $temp);
				$line1 .= " %8.0f ";
			}
			print(sprintf($line1, @row));
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	if($title) {
		graph_header($title, 2);
		print("    <tr>\n");
		print("    <td bgcolor='$title_bg_color'>\n");
	}

	if(scalar(@HPTEMP_1)) {
		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 8; $n++) {
			if($HPTEMP_1[$n]) {
				foreach $_ (@hplog) {
					$id = sprintf("%2d", $HPTEMP_1[$n]);
					if(/^$id  /) {
						$str = substr($_, 17, 8);
						$str = sprintf("%-20s", $str);
						push(@tmp, "LINE2:temp" . $n . $LC[$n] . ":$str");
						push(@tmp, "GPRINT:temp" . $n . ":LAST:Current\\: %2.0lf");
						push(@tmp, "GPRINT:temp" . $n . ":AVERAGE:   Average\\: %2.0lf");
						push(@tmp, "GPRINT:temp" . $n . ":MIN:   Min\\: %2.0lf");
						push(@tmp, "GPRINT:temp" . $n . ":MAX:   Max\\: %2.0lf\\n");
						$str =~ s/\s+$//;
						push(@tmpz, "LINE2:temp" . $n . $LC[$n] . ":$str");
						last;
					}
				}
			} else {
				push(@tmp, "COMMENT: \\n");
			}
		}
		($width, $height) = split('x', $GRAPH_SIZE{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		RRDs::graph("$PNG_DIR" . "$PNG1",
			"--title=$rgraphs{_hptemp1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Celsius",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:temp0=$HPTEMP_RRD:hptemp1_1:AVERAGE",
			"DEF:temp1=$HPTEMP_RRD:hptemp1_2:AVERAGE",
			"DEF:temp2=$HPTEMP_RRD:hptemp1_3:AVERAGE",
			"DEF:temp3=$HPTEMP_RRD:hptemp1_4:AVERAGE",
			"DEF:temp4=$HPTEMP_RRD:hptemp1_5:AVERAGE",
			"DEF:temp5=$HPTEMP_RRD:hptemp1_6:AVERAGE",
			"DEF:temp6=$HPTEMP_RRD:hptemp1_7:AVERAGE",
			"DEF:temp7=$HPTEMP_RRD:hptemp1_8:AVERAGE",
			@tmp,
			"COMMENT: \\n");
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNG1z",
				"--title=$rgraphs{_hptemp1}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Celsius",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@VERSION12,
				@graph_colors,
				"DEF:temp0=$HPTEMP_RRD:hptemp1_1:AVERAGE",
				"DEF:temp1=$HPTEMP_RRD:hptemp1_2:AVERAGE",
				"DEF:temp2=$HPTEMP_RRD:hptemp1_3:AVERAGE",
				"DEF:temp3=$HPTEMP_RRD:hptemp1_4:AVERAGE",
				"DEF:temp4=$HPTEMP_RRD:hptemp1_5:AVERAGE",
				"DEF:temp5=$HPTEMP_RRD:hptemp1_6:AVERAGE",
				"DEF:temp6=$HPTEMP_RRD:hptemp1_7:AVERAGE",
				"DEF:temp7=$HPTEMP_RRD:hptemp1_8:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /hptemp1/)) {
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
	}

	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
	}

	if(scalar(@HPTEMP_2)) {
		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 6; $n++) {
			if($HPTEMP_2[$n]) {
				foreach $_ (@hplog) {
					$id = sprintf("%2d", $HPTEMP_2[$n]);
					if(/^$id  /) {
						$str = substr($_, 17, 8);
						$str = sprintf("%-8s", $str);
						push(@tmp, "LINE2:temp" . $n . $LC[$n] . ":$str");
						push(@tmp, "GPRINT:temp" . $n . ":LAST:\\: %2.0lf");
						if(!(($n + 1) % 2)) {
							push(@tmp, "COMMENT: \\n");
						} else {
							push(@tmp, "COMMENT:    ");
						}
						$str =~ s/\s+$//;
						push(@tmpz, "LINE2:temp" . $n . $LC[$n] . ":$str");
						last;
					}
				}
			} else {
				push(@tmp, "COMMENT: \\n") unless ($n + 1) % 2;
			}
		}
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		RRDs::graph("$PNG_DIR" . "$PNG2",
			"--title=$rgraphs{_hptemp2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Celsius",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:temp0=$HPTEMP_RRD:hptemp2_1:AVERAGE",
			"DEF:temp1=$HPTEMP_RRD:hptemp2_2:AVERAGE",
			"DEF:temp2=$HPTEMP_RRD:hptemp2_3:AVERAGE",
			"DEF:temp3=$HPTEMP_RRD:hptemp2_4:AVERAGE",
			"DEF:temp4=$HPTEMP_RRD:hptemp2_5:AVERAGE",
			"DEF:temp5=$HPTEMP_RRD:hptemp2_6:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNG2z",
				"--title=$rgraphs{_hptemp2}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Celsius",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:temp0=$HPTEMP_RRD:hptemp2_1:AVERAGE",
				"DEF:temp1=$HPTEMP_RRD:hptemp2_2:AVERAGE",
				"DEF:temp2=$HPTEMP_RRD:hptemp2_3:AVERAGE",
				"DEF:temp3=$HPTEMP_RRD:hptemp2_4:AVERAGE",
				"DEF:temp4=$HPTEMP_RRD:hptemp2_5:AVERAGE",
				"DEF:temp5=$HPTEMP_RRD:hptemp2_6:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /hptemp2/)) {
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
	}

	if(scalar(@HPTEMP_3)) {
		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 6; $n++) {
			if($HPTEMP_3[$n]) {
				foreach $_ (@hplog) {
					$id = sprintf("%2d", $HPTEMP_3[$n]);
					if(/^$id  /) {
						$str = substr($_, 17, 8);
						$str = sprintf("%-8s", $str);
						push(@tmp, "LINE2:temp" . $n . $LC[$n] . ":$str");
						push(@tmp, "GPRINT:temp" . $n . ":LAST:\\: %2.0lf");
						if(!(($n + 1) % 2)) {
							push(@tmp, "COMMENT: \\n");
						} else {
							push(@tmp, "COMMENT:    ");
						}
						$str =~ s/\s+$//;
						push(@tmpz, "LINE2:temp" . $n . $LC[$n] . ":$str");
						last;
					}
				}
			} else {
				push(@tmp, "COMMENT: \\n") unless ($n + 1) % 2;
			}
		}
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		RRDs::graph("$PNG_DIR" . "$PNG3",
			"--title=$rgraphs{_hptemp3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Celsius",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:temp0=$HPTEMP_RRD:hptemp3_1:AVERAGE",
			"DEF:temp1=$HPTEMP_RRD:hptemp3_2:AVERAGE",
			"DEF:temp2=$HPTEMP_RRD:hptemp3_3:AVERAGE",
			"DEF:temp3=$HPTEMP_RRD:hptemp3_4:AVERAGE",
			"DEF:temp4=$HPTEMP_RRD:hptemp3_5:AVERAGE",
			"DEF:temp5=$HPTEMP_RRD:hptemp3_6:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNG3z",
				"--title=$rgraphs{_hptemp3}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Celsius",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:temp0=$HPTEMP_RRD:hptemp3_1:AVERAGE",
				"DEF:temp1=$HPTEMP_RRD:hptemp3_2:AVERAGE",
				"DEF:temp2=$HPTEMP_RRD:hptemp3_3:AVERAGE",
				"DEF:temp3=$HPTEMP_RRD:hptemp3_4:AVERAGE",
				"DEF:temp4=$HPTEMP_RRD:hptemp3_5:AVERAGE",
				"DEF:temp5=$HPTEMP_RRD:hptemp3_6:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /hptemp3/)) {
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
	}

	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

# LMSENS graph
# ----------------------------------------------------------------------------
sub lmsens {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @tmp;
	my @tmpz;
	my $vlabel;
	my $n;
	my $str;
	my $err;
	my @LC = (
		"#FFA500",
		"#44EEEE",
		"#44EE44",
		"#4444EE",
		"#448844",
		"#EE4444",
		"#EE44EE",
		"#EEEE44",
		"#444444",
		"#BB44EE",
		"#CCCCCC",
		"#B4B444",
		"#D3D701",
		"#E29136",
		"#DDAE8C",
		"#F29967",
	);

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG4 = $u . $myself . "4." . $when . ".png";
	my $PNG5 = $u . $myself . "5." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";
	my $PNG4z = $u . $myself . "4z." . $when . ".png";
	my $PNG5z = $u . $myself . "5z." . $when . ".png";

	$title = !$silent ? $title : "";

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3",
		"$PNG_DIR" . "$PNG4",
		"$PNG_DIR" . "$PNG5");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z",
			"$PNG_DIR" . "$PNG4z",
			"$PNG_DIR" . "$PNG5z");
	}

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$LMSENS_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $LMSENS_RRD: $err\n") if $err;
		my $line1;
		my $line2;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		for($n = 0; $n < 2; $n++) {
			$str = "MB" . $n;
			if($SENSORS_LIST{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($SENSORS_LIST{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		for($n = 0; $n < 4; $n++) {
			$str = "CPU" . $n;
			if($SENSORS_LIST{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($SENSORS_LIST{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		for($n = 0; $n < 9; $n++) {
			$str = "FAN" . $n;
			if($SENSORS_LIST{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($SENSORS_LIST{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		for($n = 0; $n < 16; $n++) {
			$str = "CORE" . $n;
			if($SENSORS_LIST{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($SENSORS_LIST{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		for($n = 0; $n < 12; $n++) {
			$str = "VOLT" . $n;
			if($SENSORS_LIST{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($SENSORS_LIST{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		for($n = 0; $n < 9; $n++) {
			$str = "GPU" . $n;
			if($SENSORS_LIST{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($SENSORS_LIST{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		print("Time $line1\n");
		print("-----$line2\n");
		my $l;
		my $line;
		my @row;
		my $time;
		my @mb;
		my @cpu;
		my @fan;
		my @core;
		my @volt;
		my @gpu;
		for($l = 0, $time = $tb; $l < ($tb * $ts); $l++) {
			$line1 = " %2d$tc ";
			undef(@row);
			$line = @$data[$l];
			(@mb[0..2-1], @cpu[0..4-1], @fan[0..10-1], @core[0..16-1], @volt[0..10-1], @gpu[0..8-1]) = @$line;
			for($n = 0; $n < 2; $n++) {
				$str = "MB" . $n;
				if($SENSORS_LIST{$str}) {
					push(@row, $mb[$n]);
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			for($n = 0; $n < 4; $n++) {
				$str = "CPU" . $n;
				if($SENSORS_LIST{$str}) {
					push(@row, $cpu[$n]);
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			for($n = 0; $n < 9; $n++) {
				$str = "FAN" . $n;
				if($SENSORS_LIST{$str}) {
					push(@row, $fan[$n]);
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			for($n = 0; $n < 16; $n++) {
				$str = "CORE" . $n;
				if($SENSORS_LIST{$str}) {
					push(@row, $core[$n]);
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			for($n = 0; $n < 12; $n++) {
				$str = "VOLT" . $n;
				if($SENSORS_LIST{$str}) {
					push(@row, $volt[$n]);
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			for($n = 0; $n < 9; $n++) {
				$str = "GPU" . $n;
				if($SENSORS_LIST{$str}) {
					push(@row, $gpu[$n]);
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			$time = $time - (1 / $ts);
			printf("$line1 \n", $time, @row);
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	if($title) {
		my $n2;
		graph_header($title, 2);
	}
	for($n = 0; $n < 4; $n++) {
		for($n2 = $n; $n2 < 16; $n2 += 4) {
			$str = "CORE" . $n2;
			if($SENSORS_LIST{$str}) {
				$str = sprintf("Core %2d", $n2);
				push(@tmp, "LINE2:core$n2" . $LC[$n2] . ":$str\\g");
				push(@tmp, "GPRINT:core$n2:LAST:\\:%3.0lf      ");
			}
		}
		push(@tmp, "COMMENT: \\n") unless !@tmp;
	}
	for($n = 0; $n < 16; $n++) {
		$str = "CORE" . $n;
		if($SENSORS_LIST{$str}) {
			$str = sprintf("Core %d", $n);
			push(@tmpz, "LINE2:core$n" . $LC[$n] . ":$str");
		}
	}
	# if no COREs are defined then create a blank graph
	if(!@tmp) {
		push(@tmp, "GPRINT:core0:LAST:%0.0lf");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmpz, "GPRINT:core0:LAST:%0.0lf");
	}
	if($title) {
		print("    <tr>\n");
		print("    <td valign='bottom' bgcolor='$title_bg_color'>\n");
	}
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$rgraphs{_lmsens1}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Celsius",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		"DEF:core0=$LMSENS_RRD:lmsens_core0:AVERAGE",
		"DEF:core1=$LMSENS_RRD:lmsens_core1:AVERAGE",
		"DEF:core2=$LMSENS_RRD:lmsens_core2:AVERAGE",
		"DEF:core3=$LMSENS_RRD:lmsens_core3:AVERAGE",
		"DEF:core4=$LMSENS_RRD:lmsens_core4:AVERAGE",
		"DEF:core5=$LMSENS_RRD:lmsens_core5:AVERAGE",
		"DEF:core6=$LMSENS_RRD:lmsens_core6:AVERAGE",
		"DEF:core7=$LMSENS_RRD:lmsens_core7:AVERAGE",
		"DEF:core8=$LMSENS_RRD:lmsens_core8:AVERAGE",
		"DEF:core9=$LMSENS_RRD:lmsens_core9:AVERAGE",
		"DEF:core10=$LMSENS_RRD:lmsens_core10:AVERAGE",
		"DEF:core11=$LMSENS_RRD:lmsens_core11:AVERAGE",
		"DEF:core12=$LMSENS_RRD:lmsens_core12:AVERAGE",
		"DEF:core13=$LMSENS_RRD:lmsens_core13:AVERAGE",
		"DEF:core14=$LMSENS_RRD:lmsens_core14:AVERAGE",
		"DEF:core15=$LMSENS_RRD:lmsens_core15:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$rgraphs{_lmsens1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Celsius",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:core0=$LMSENS_RRD:lmsens_core0:AVERAGE",
			"DEF:core1=$LMSENS_RRD:lmsens_core1:AVERAGE",
			"DEF:core2=$LMSENS_RRD:lmsens_core2:AVERAGE",
			"DEF:core3=$LMSENS_RRD:lmsens_core3:AVERAGE",
			"DEF:core4=$LMSENS_RRD:lmsens_core4:AVERAGE",
			"DEF:core5=$LMSENS_RRD:lmsens_core5:AVERAGE",
			"DEF:core6=$LMSENS_RRD:lmsens_core6:AVERAGE",
			"DEF:core7=$LMSENS_RRD:lmsens_core7:AVERAGE",
			"DEF:core8=$LMSENS_RRD:lmsens_core8:AVERAGE",
			"DEF:core9=$LMSENS_RRD:lmsens_core9:AVERAGE",
			"DEF:core10=$LMSENS_RRD:lmsens_core10:AVERAGE",
			"DEF:core11=$LMSENS_RRD:lmsens_core11:AVERAGE",
			"DEF:core12=$LMSENS_RRD:lmsens_core12:AVERAGE",
			"DEF:core13=$LMSENS_RRD:lmsens_core13:AVERAGE",
			"DEF:core14=$LMSENS_RRD:lmsens_core14:AVERAGE",
			"DEF:core15=$LMSENS_RRD:lmsens_core15:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens1/)) {
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

	undef(@tmp);
	undef(@tmpz);
	$SENSORS_LIST{'VOLT0'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT0'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT0'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt0#FFA500:$str\\g", "GPRINT:volt0:LAST:\\:%6.2lf   "));
	$SENSORS_LIST{'VOLT3'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT3'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT3'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt3#4444EE:$str\\g", "GPRINT:volt3:LAST:\\:%6.2lf   ")) unless !$str;
	$SENSORS_LIST{'VOLT6'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT6'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT6'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt6#EE44EE:$str\\g", "GPRINT:volt6:LAST:\\:%6.2lf   ")) unless !$str;
	$SENSORS_LIST{'VOLT9'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT9'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT9'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt9#94C36B:$str\\g", "GPRINT:volt9:LAST:\\:%6.2lf\\g")) unless !$str;
	push(@tmp, "COMMENT: \\n");
	$SENSORS_LIST{'VOLT1'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT1'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT1'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt1#44EEEE:$str\\g", "GPRINT:volt1:LAST:\\:%6.2lf   ")) unless !$str;
	$SENSORS_LIST{'VOLT4'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT4'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT4'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt4#448844:$str\\g", "GPRINT:volt4:LAST:\\:%6.2lf   ")) unless !$str;
	$SENSORS_LIST{'VOLT7'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT7'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT7'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt7#EEEE44:$str\\g", "GPRINT:volt7:LAST:\\:%6.2lf   ")) unless !$str;
	$SENSORS_LIST{'VOLT10'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT10'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT10'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt10#3CB5B0:$str\\g", "GPRINT:volt10:LAST:\\:%6.2lf\\g")) unless !$str;
	push(@tmp, "COMMENT: \\n");
	$SENSORS_LIST{'VOLT2'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT2'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT2'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt2#44EE44:$str\\g", "GPRINT:volt2:LAST:\\:%6.2lf   ")) unless !$str;
	$SENSORS_LIST{'VOLT5'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT5'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT5'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt5#EE4444:$str\\g", "GPRINT:volt5:LAST:\\:%6.2lf   ")) unless !$str;
	$SENSORS_LIST{'VOLT8'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT8'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT8'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt8#963C74:$str\\g", "GPRINT:volt8:LAST:\\:%6.2lf   ")) unless !$str;
	$SENSORS_LIST{'VOLT11'} =~ s/\\//;
	$str = $SENSORS_LIST{'VOLT11'} ? sprintf("%8s", substr($SENSORS_LIST{'VOLT11'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt11#597AB7:$str\\g", "GPRINT:volt11:LAST:\\:%6.2lf\\g")) unless !$str;
	push(@tmp, "COMMENT: \\n");
	$str = $SENSORS_LIST{'VOLT0'} ? substr($SENSORS_LIST{'VOLT0'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt0#FFA500:$str");
	$str = $SENSORS_LIST{'VOLT1'} ? substr($SENSORS_LIST{'VOLT1'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt1#44EEEE:$str")unless !$str;
	$str = $SENSORS_LIST{'VOLT2'} ? substr($SENSORS_LIST{'VOLT2'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt2#44EE44:$str")unless !$str;
	$str = $SENSORS_LIST{'VOLT3'} ? substr($SENSORS_LIST{'VOLT3'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt3#4444EE:$str")unless !$str;
	$str = $SENSORS_LIST{'VOLT4'} ? substr($SENSORS_LIST{'VOLT4'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt4#448844:$str")unless !$str;
	$str = $SENSORS_LIST{'VOLT5'} ? substr($SENSORS_LIST{'VOLT5'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt5#EE4444:$str")unless !$str;
	$str = $SENSORS_LIST{'VOLT6'} ? substr($SENSORS_LIST{'VOLT6'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt6#EE44EE:$str")unless !$str;
	$str = $SENSORS_LIST{'VOLT7'} ? substr($SENSORS_LIST{'VOLT7'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt7#EEEE44:$str")unless !$str;
	$str = $SENSORS_LIST{'VOLT8'} ? substr($SENSORS_LIST{'VOLT8'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt8#963C74:$str")unless !$str;
	$str = $SENSORS_LIST{'VOLT9'} ? substr($SENSORS_LIST{'VOLT9'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt9#94C36B:$str")unless !$str;
	$str = $SENSORS_LIST{'VOLT10'} ? substr($SENSORS_LIST{'VOLT10'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt10#3CB5B0:$str")unless !$str;
	$str = $SENSORS_LIST{'VOLT11'} ? substr($SENSORS_LIST{'VOLT11'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt11#597AB7:$str") unless !$str;
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$rgraphs{_lmsens2}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Volts",
		"--width=$width",
		"--height=$height",
		@VERSION12,
		@graph_colors,
		"DEF:volt0=$LMSENS_RRD:lmsens_volt0:AVERAGE",
		"DEF:volt1=$LMSENS_RRD:lmsens_volt1:AVERAGE",
		"DEF:volt2=$LMSENS_RRD:lmsens_volt2:AVERAGE",
		"DEF:volt3=$LMSENS_RRD:lmsens_volt3:AVERAGE",
		"DEF:volt4=$LMSENS_RRD:lmsens_volt4:AVERAGE",
		"DEF:volt5=$LMSENS_RRD:lmsens_volt5:AVERAGE",
		"DEF:volt6=$LMSENS_RRD:lmsens_volt6:AVERAGE",
		"DEF:volt7=$LMSENS_RRD:lmsens_volt7:AVERAGE",
		"DEF:volt8=$LMSENS_RRD:lmsens_volt8:AVERAGE",
		"DEF:volt9=$LMSENS_RRD:lmsens_volt9:AVERAGE",
		"DEF:volt10=$LMSENS_RRD:lmsens_volt10:AVERAGE",
		"DEF:volt11=$LMSENS_RRD:lmsens_volt11:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$rgraphs{_lmsens2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Volts",
			"--width=$width",
			"--height=$height",
			@VERSION12,
			@graph_colors,
			"DEF:volt0=$LMSENS_RRD:lmsens_volt0:AVERAGE",
			"DEF:volt1=$LMSENS_RRD:lmsens_volt1:AVERAGE",
			"DEF:volt2=$LMSENS_RRD:lmsens_volt2:AVERAGE",
			"DEF:volt3=$LMSENS_RRD:lmsens_volt3:AVERAGE",
			"DEF:volt4=$LMSENS_RRD:lmsens_volt4:AVERAGE",
			"DEF:volt5=$LMSENS_RRD:lmsens_volt5:AVERAGE",
			"DEF:volt6=$LMSENS_RRD:lmsens_volt6:AVERAGE",
			"DEF:volt7=$LMSENS_RRD:lmsens_volt7:AVERAGE",
			"DEF:volt8=$LMSENS_RRD:lmsens_volt8:AVERAGE",
			"DEF:volt9=$LMSENS_RRD:lmsens_volt9:AVERAGE",
			"DEF:volt10=$LMSENS_RRD:lmsens_volt10:AVERAGE",
			"DEF:volt11=$LMSENS_RRD:lmsens_volt11:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens2/)) {
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
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
	}

	undef(@tmp);
	undef(@tmpz);
	push(@tmp, ("LINE2:mb0#FFA500:MB 0\\g", "GPRINT:mb0:LAST:\\:%3.0lf   "));
	push(@tmp, ("LINE2:cpu0#4444EE:CPU 0\\g", "GPRINT:cpu0:LAST:\\:%3.0lf   ")) unless !$SENSORS_LIST{'CPU0'};
	push(@tmp, ("LINE2:cpu2#EE44EE:CPU 2\\g", "GPRINT:cpu2:LAST:\\:%3.0lf\\g")) unless !$SENSORS_LIST{'CPU2'};
	push(@tmp, "COMMENT: \\n");
	push(@tmp, ("LINE2:mb1#44EEEE:MB 1\\g", "GPRINT:mb1:LAST:\\:%3.0lf   ")) unless !$SENSORS_LIST{'MB1'};
	push(@tmp, ("LINE2:cpu1#EEEE44:CPU 1\\g", "GPRINT:cpu1:LAST:\\:%3.0lf   ")) unless !$SENSORS_LIST{'CPU1'};
	push(@tmp, ("LINE2:cpu3#44EE44:CPU 3\\g", "GPRINT:cpu3:LAST:\\:%3.0lf\\g")) unless !$SENSORS_LIST{'CPU3'};
	push(@tmp, "COMMENT: \\n");
	push(@tmpz, "LINE2:mb0#FFA500:MB 0");
	push(@tmpz, "LINE2:mb1#44EEEE:MB 1") unless !$SENSORS_LIST{'MB1'};
	push(@tmpz, "LINE2:cpu0#4444EE:CPU 0") unless !$SENSORS_LIST{'CPU0'};
	push(@tmpz, "LINE2:cpu1#EEEE44:CPU 1") unless !$SENSORS_LIST{'CPU1'};
	push(@tmpz, "LINE2:cpu2#EE44EE:CPU 2") unless !$SENSORS_LIST{'CPU2'};
	push(@tmpz, "LINE2:cpu3#44EE44:CPU 3") unless !$SENSORS_LIST{'CPU3'};
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$rgraphs{_lmsens3}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Celsius",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:mb0=$LMSENS_RRD:lmsens_mb0:AVERAGE",
		"DEF:mb1=$LMSENS_RRD:lmsens_mb1:AVERAGE",
		"DEF:cpu0=$LMSENS_RRD:lmsens_cpu0:AVERAGE",
		"DEF:cpu1=$LMSENS_RRD:lmsens_cpu1:AVERAGE",
		"DEF:cpu2=$LMSENS_RRD:lmsens_cpu2:AVERAGE",
		"DEF:cpu3=$LMSENS_RRD:lmsens_cpu3:AVERAGE",
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$rgraphs{_lmsens3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Celsius",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:mb0=$LMSENS_RRD:lmsens_mb0:AVERAGE",
			"DEF:mb1=$LMSENS_RRD:lmsens_mb1:AVERAGE",
			"DEF:cpu0=$LMSENS_RRD:lmsens_cpu0:AVERAGE",
			"DEF:cpu1=$LMSENS_RRD:lmsens_cpu1:AVERAGE",
			"DEF:cpu2=$LMSENS_RRD:lmsens_cpu2:AVERAGE",
			"DEF:cpu3=$LMSENS_RRD:lmsens_cpu3:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens3/)) {
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

	undef(@tmp);
	undef(@tmpz);
	push(@tmp, ("LINE2:fan0#FFA500:Fan 0\\g", "GPRINT:fan0:LAST:\\:%5.0lf"));
	push(@tmp, ("LINE2:fan3#4444EE:Fan 3\\g", "GPRINT:fan3:LAST:\\:%5.0lf")) unless !$SENSORS_LIST{'FAN3'};
	push(@tmp, ("LINE2:fan6#EE44EE:Fan 6\\g", "GPRINT:fan6:LAST:\\:%5.0lf\\g")) unless !$SENSORS_LIST{'FAN6'};
	push(@tmp, "COMMENT: \\n");
	push(@tmp, ("LINE2:fan1#44EEEE:Fan 1\\g", "GPRINT:fan1:LAST:\\:%5.0lf")) unless !$SENSORS_LIST{'FAN1'};
	push(@tmp, ("LINE2:fan4#448844:Fan 4\\g", "GPRINT:fan4:LAST:\\:%5.0lf")) unless !$SENSORS_LIST{'FAN4'};
	push(@tmp, ("LINE2:fan7#EEEE44:Fan 7\\g", "GPRINT:fan7:LAST:\\:%5.0lf\\g")) unless !$SENSORS_LIST{'FAN7'};
	push(@tmp, "COMMENT: \\n");
	push(@tmp, ("LINE2:fan2#44EE44:Fan 2\\g", "GPRINT:fan2:LAST:\\:%5.0lf")) unless !$SENSORS_LIST{'FAN2'};
	push(@tmp, ("LINE2:fan5#EE4444:Fan 5\\g", "GPRINT:fan5:LAST:\\:%5.0lf")) unless !$SENSORS_LIST{'FAN5'};
	push(@tmp, ("LINE2:fan8#963C74:Fan 8\\g", "GPRINT:fan8:LAST:\\:%5.0lf\\g")) unless !$SENSORS_LIST{'FAN8'};
	push(@tmp, "COMMENT: \\n");
	push(@tmpz, "LINE2:fan0#FFA500:Fan 0");
	push(@tmpz, "LINE2:fan1#44EEEE:Fan 1") unless !$SENSORS_LIST{'FAN1'};
	push(@tmpz, "LINE2:fan2#44EE44:Fan 2") unless !$SENSORS_LIST{'FAN2'};
	push(@tmpz, "LINE2:fan3#4444EE:Fan 3") unless !$SENSORS_LIST{'FAN3'};
	push(@tmpz, "LINE2:fan4#448844:Fan 4") unless !$SENSORS_LIST{'FAN4'};
	push(@tmpz, "LINE2:fan5#EE4444:Fan 5") unless !$SENSORS_LIST{'FAN5'};
	push(@tmpz, "LINE2:fan6#EE44EE:Fan 6") unless !$SENSORS_LIST{'FAN6'};
	push(@tmpz, "LINE2:fan7#EEEE44:Fan 7") unless !$SENSORS_LIST{'FAN7'};
	push(@tmpz, "LINE2:fan8#963C74:Fan 8") unless !$SENSORS_LIST{'FAN8'};
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG4",
		"--title=$rgraphs{_lmsens4}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=RPM",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:fan0=$LMSENS_RRD:lmsens_fan0:AVERAGE",
		"DEF:fan1=$LMSENS_RRD:lmsens_fan1:AVERAGE",
		"DEF:fan2=$LMSENS_RRD:lmsens_fan2:AVERAGE",
		"DEF:fan3=$LMSENS_RRD:lmsens_fan3:AVERAGE",
		"DEF:fan4=$LMSENS_RRD:lmsens_fan4:AVERAGE",
		"DEF:fan5=$LMSENS_RRD:lmsens_fan5:AVERAGE",
		"DEF:fan6=$LMSENS_RRD:lmsens_fan6:AVERAGE",
		"DEF:fan7=$LMSENS_RRD:lmsens_fan7:AVERAGE",
		"DEF:fan8=$LMSENS_RRD:lmsens_fan8:AVERAGE",
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG4: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG4z",
			"--title=$rgraphs{_lmsens4}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=RPM",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:fan0=$LMSENS_RRD:lmsens_fan0:AVERAGE",
			"DEF:fan1=$LMSENS_RRD:lmsens_fan1:AVERAGE",
			"DEF:fan2=$LMSENS_RRD:lmsens_fan2:AVERAGE",
			"DEF:fan3=$LMSENS_RRD:lmsens_fan3:AVERAGE",
			"DEF:fan4=$LMSENS_RRD:lmsens_fan4:AVERAGE",
			"DEF:fan5=$LMSENS_RRD:lmsens_fan5:AVERAGE",
			"DEF:fan6=$LMSENS_RRD:lmsens_fan6:AVERAGE",
			"DEF:fan7=$LMSENS_RRD:lmsens_fan7:AVERAGE",
			"DEF:fan8=$LMSENS_RRD:lmsens_fan8:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens4/)) {
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

	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "LINE2:gpu0#FFA500:GPU 0\\g");
	push(@tmp, "GPRINT:gpu0:LAST:\\:%3.0lf  ");
	push(@tmp, ("LINE2:gpu3#4444EE:GPU 3\\g", "GPRINT:gpu3:LAST:\\:%3.0lf  ")) unless !$SENSORS_LIST{'GPU3'};
	push(@tmp, ("LINE2:gpu6#EE44EE:GPU 6\\g", "GPRINT:gpu6:LAST:\\:%3.0lf\\g")) unless !$SENSORS_LIST{'GPU6'};
	push(@tmp, "COMMENT: \\n");
	push(@tmp, ("LINE2:gpu1#44EEEE:GPU 1\\g", "GPRINT:gpu1:LAST:\\:%3.0lf  ")) unless !$SENSORS_LIST{'GPU1'};
	push(@tmp, ("LINE2:gpu4#448844:GPU 4\\g", "GPRINT:gpu4:LAST:\\:%3.0lf  ")) unless !$SENSORS_LIST{'GPU4'};
	push(@tmp, ("LINE2:gpu7#EEEE44:GPU 7\\g", "GPRINT:gpu7:LAST:\\:%3.0lf\\g")) unless !$SENSORS_LIST{'GPU7'};
	push(@tmp, "COMMENT: \\n");
	push(@tmp, ("LINE2:gpu2#44EE44:GPU 2\\g", "GPRINT:gpu2:LAST:\\:%3.0lf  ")) unless !$SENSORS_LIST{'GPU2'};
	push(@tmp, ("LINE2:gpu5#EE4444:GPU 5\\g", "GPRINT:gpu5:LAST:\\:%3.0lf  ")) unless !$SENSORS_LIST{'GPU5'};
	push(@tmp, ("LINE2:gpu8#963C74:GPU 8\\g", "GPRINT:gpu8:LAST:\\:%3.0lf\\g")) unless !$SENSORS_LIST{'GPU8'};
	push(@tmp, "COMMENT: \\n");
	push(@tmpz, "LINE2:gpu0#FFA500:GPU 0\\g");
	push(@tmpz, "LINE2:gpu1#44EEEE:GPU 1\\g") unless !$SENSORS_LIST{'GPU1'};
	push(@tmpz, "LINE2:gpu2#44EE44:GPU 2\\g") unless !$SENSORS_LIST{'GPU2'};
	push(@tmpz, "LINE2:gpu3#4444EE:GPU 3\\g") unless !$SENSORS_LIST{'GPU3'};
	push(@tmpz, "LINE2:gpu4#448844:GPU 4\\g") unless !$SENSORS_LIST{'GPU4'};
	push(@tmpz, "LINE2:gpu5#EE4444:GPU 5\\g") unless !$SENSORS_LIST{'GPU5'};
	push(@tmpz, "LINE2:gpu6#EE44EE:GPU 6\\g") unless !$SENSORS_LIST{'GPU6'};
	push(@tmpz, "LINE2:gpu7#EEEE44:GPU 7\\g") unless !$SENSORS_LIST{'GPU7'};
	push(@tmpz, "LINE2:gpu8#963C74:GPU 8\\g") unless !$SENSORS_LIST{'GPU8'};
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG5",
		"--title=$rgraphs{_lmsens5}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Celsius",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:gpu0=$LMSENS_RRD:lmsens_gpu0:AVERAGE",
		"DEF:gpu1=$LMSENS_RRD:lmsens_gpu1:AVERAGE",
		"DEF:gpu2=$LMSENS_RRD:lmsens_gpu2:AVERAGE",
		"DEF:gpu3=$LMSENS_RRD:lmsens_gpu3:AVERAGE",
		"DEF:gpu4=$LMSENS_RRD:lmsens_gpu4:AVERAGE",
		"DEF:gpu5=$LMSENS_RRD:lmsens_gpu5:AVERAGE",
		"DEF:gpu6=$LMSENS_RRD:lmsens_gpu6:AVERAGE",
		"DEF:gpu7=$LMSENS_RRD:lmsens_gpu7:AVERAGE",
		"DEF:gpu8=$LMSENS_RRD:lmsens_gpu8:AVERAGE",
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG5: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG5z",
			"--title=$rgraphs{_lmsens5}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Celsius",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:gpu0=$LMSENS_RRD:lmsens_gpu0:AVERAGE",
			"DEF:gpu1=$LMSENS_RRD:lmsens_gpu1:AVERAGE",
			"DEF:gpu2=$LMSENS_RRD:lmsens_gpu2:AVERAGE",
			"DEF:gpu3=$LMSENS_RRD:lmsens_gpu3:AVERAGE",
			"DEF:gpu4=$LMSENS_RRD:lmsens_gpu4:AVERAGE",
			"DEF:gpu5=$LMSENS_RRD:lmsens_gpu5:AVERAGE",
			"DEF:gpu6=$LMSENS_RRD:lmsens_gpu6:AVERAGE",
			"DEF:gpu7=$LMSENS_RRD:lmsens_gpu7:AVERAGE",
			"DEF:gpu8=$LMSENS_RRD:lmsens_gpu8:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens5/)) {
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


	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

# NVIDIA graph
# ----------------------------------------------------------------------------
sub nvidia {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @tmp;
	my @tmpz;
	my $n;
	my $err;
	my @LC = (
		"#FFA500",
		"#44EEEE",
		"#44EE44",
		"#4444EE",
		"#448844",
		"#EE4444",
		"#EE44EE",
		"#EEEE44",
		"#963C74",
	);

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";

	$title = !$silent ? $title : "";

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$NVIDIA_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $NVIDIA_RRD: $err\n") if $err;
		my $line2;
		my $line3;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("    ");
		for($n = 0; $n < $NVIDIA_MAX; $n++) {
			print("   NVIDIA card $n ");
		}
		print("\n");
		for($n = 0; $n < $NVIDIA_MAX; $n++) {
			$line2 .= "   Temp  GPU  Mem";
			$line3 .= "-----------------";
		}
		print("Time$line2\n");
		print("----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc ", $time);
			undef($line1);
			undef(@row);
			for($n2 = 0; $n2 < $NVIDIA_MAX; $n2++) {
				push(@row, @$line[$n2]);
				push(@row, @$line[$n2 + 9]);
				push(@row, @$line[$n2 + 18]);
				$line1 .= "   %3d %3d%% %3d%%";
			}
			print(sprintf($line1, @row));
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	if($title) {
		graph_header($title, 2);
	}
	for($n = 0; $n < 9; $n++) {
		if($n < $NVIDIA_MAX) {
			push(@tmp, "LINE2:temp" . $n . $LC[$n] . ":Card $n");
			push(@tmpz, "LINE2:temp" . $n . $LC[$n] . ":Card $n");
			push(@tmp, "GPRINT:temp" . $n . ":LAST:             Current\\: %2.0lf");
			push(@tmp, "GPRINT:temp" . $n . ":AVERAGE:   Average\\: %2.0lf");
			push(@tmp, "GPRINT:temp" . $n . ":MIN:   Min\\: %2.0lf");
			push(@tmp, "GPRINT:temp" . $n . ":MAX:   Max\\: %2.0lf\\n");
		} else {
			push(@tmp, "COMMENT: \\n");
		}
	}

	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$title_bg_color'>\n");
	}
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$rgraphs{_nvidia1}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Celsius",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		"DEF:temp0=$NVIDIA_RRD:nvidia_temp0:AVERAGE",
		"DEF:temp1=$NVIDIA_RRD:nvidia_temp1:AVERAGE",
		"DEF:temp2=$NVIDIA_RRD:nvidia_temp2:AVERAGE",
		"DEF:temp3=$NVIDIA_RRD:nvidia_temp3:AVERAGE",
		"DEF:temp4=$NVIDIA_RRD:nvidia_temp4:AVERAGE",
		"DEF:temp5=$NVIDIA_RRD:nvidia_temp5:AVERAGE",
		"DEF:temp6=$NVIDIA_RRD:nvidia_temp6:AVERAGE",
		"DEF:temp7=$NVIDIA_RRD:nvidia_temp7:AVERAGE",
		"DEF:temp8=$NVIDIA_RRD:nvidia_temp8:AVERAGE",
		@tmp,
		"COMMENT: \\n",
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$rgraphs{_nvidia1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Celsius",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:temp0=$NVIDIA_RRD:nvidia_temp0:AVERAGE",
			"DEF:temp1=$NVIDIA_RRD:nvidia_temp1:AVERAGE",
			"DEF:temp2=$NVIDIA_RRD:nvidia_temp2:AVERAGE",
			"DEF:temp3=$NVIDIA_RRD:nvidia_temp3:AVERAGE",
			"DEF:temp4=$NVIDIA_RRD:nvidia_temp4:AVERAGE",
			"DEF:temp5=$NVIDIA_RRD:nvidia_temp5:AVERAGE",
			"DEF:temp6=$NVIDIA_RRD:nvidia_temp6:AVERAGE",
			"DEF:temp7=$NVIDIA_RRD:nvidia_temp7:AVERAGE",
			"DEF:temp8=$NVIDIA_RRD:nvidia_temp8:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nvidia1/)) {
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
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
	}

	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "LINE2:gpu0#FFA500:Card 0\\g");
	push(@tmp, "GPRINT:gpu0:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu3#4444EE:Card 3\\g");
	push(@tmp, "GPRINT:gpu3:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu6#EE44EE:Card 6\\g");
	push(@tmp, "GPRINT:gpu6:LAST:\\:%3.0lf%%\\n");
	push(@tmp, "LINE2:gpu1#44EEEE:Card 1\\g");
	push(@tmp, "GPRINT:gpu1:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu4#448844:Card 4\\g");
	push(@tmp, "GPRINT:gpu4:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu7#EEEE44:Card 7\\g");
	push(@tmp, "GPRINT:gpu7:LAST:\\:%3.0lf%%\\n");
	push(@tmp, "LINE2:gpu2#44EE44:Card 2\\g");
	push(@tmp, "GPRINT:gpu2:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu5#EE4444:Card 5\\g");
	push(@tmp, "GPRINT:gpu5:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:gpu8#963C74:Card 8\\g");
	push(@tmp, "GPRINT:gpu8:LAST:\\:%3.0lf%%\\n");
	push(@tmpz, "LINE2:gpu0#FFA500:Card 0");
	push(@tmpz, "LINE2:gpu3#4444EE:Card 3");
	push(@tmpz, "LINE2:gpu6#EE44EE:Card 6");
	push(@tmpz, "LINE2:gpu1#44EEEE:Card 1");
	push(@tmpz, "LINE2:gpu4#448844:Card 4");
	push(@tmpz, "LINE2:gpu7#EEEE44:Card 7");
	push(@tmpz, "LINE2:gpu2#44EE44:Card 2");
	push(@tmpz, "LINE2:gpu5#EE4444:Card 5");
	push(@tmpz, "LINE2:gpu8#963C74:Card 8");
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$rgraphs{_nvidia2}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Percent",
		"--width=$width",
		"--height=$height",
		"--upper-limit=100",
		"--lower-limit=0",
		"--rigid",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:gpu0=$NVIDIA_RRD:nvidia_gpu0:AVERAGE",
		"DEF:gpu1=$NVIDIA_RRD:nvidia_gpu1:AVERAGE",
		"DEF:gpu2=$NVIDIA_RRD:nvidia_gpu2:AVERAGE",
		"DEF:gpu3=$NVIDIA_RRD:nvidia_gpu3:AVERAGE",
		"DEF:gpu4=$NVIDIA_RRD:nvidia_gpu4:AVERAGE",
		"DEF:gpu5=$NVIDIA_RRD:nvidia_gpu5:AVERAGE",
		"DEF:gpu6=$NVIDIA_RRD:nvidia_gpu6:AVERAGE",
		"DEF:gpu7=$NVIDIA_RRD:nvidia_gpu7:AVERAGE",
		"DEF:gpu8=$NVIDIA_RRD:nvidia_gpu8:AVERAGE",
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$rgraphs{_nvidia2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Percent",
			"--width=$width",
			"--height=$height",
			"--upper-limit=100",
			"--lower-limit=0",
			"--rigid",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:gpu0=$NVIDIA_RRD:nvidia_gpu0:AVERAGE",
			"DEF:gpu1=$NVIDIA_RRD:nvidia_gpu1:AVERAGE",
			"DEF:gpu2=$NVIDIA_RRD:nvidia_gpu2:AVERAGE",
			"DEF:gpu3=$NVIDIA_RRD:nvidia_gpu3:AVERAGE",
			"DEF:gpu4=$NVIDIA_RRD:nvidia_gpu4:AVERAGE",
			"DEF:gpu5=$NVIDIA_RRD:nvidia_gpu5:AVERAGE",
			"DEF:gpu6=$NVIDIA_RRD:nvidia_gpu6:AVERAGE",
			"DEF:gpu7=$NVIDIA_RRD:nvidia_gpu7:AVERAGE",
			"DEF:gpu8=$NVIDIA_RRD:nvidia_gpu8:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nvidia2/)) {
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

	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "LINE2:mem0#FFA500:Card 0\\g");
	push(@tmp, "GPRINT:mem0:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem3#4444EE:Card 3\\g");
	push(@tmp, "GPRINT:mem3:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem6#EE44EE:Card 6\\g");
	push(@tmp, "GPRINT:mem6:LAST:\\:%3.0lf%%\\n");
	push(@tmp, "LINE2:mem1#44EEEE:Card 1\\g");
	push(@tmp, "GPRINT:mem1:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem4#448844:Card 4\\g");
	push(@tmp, "GPRINT:mem4:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem7#EEEE44:Card 7\\g");
	push(@tmp, "GPRINT:mem7:LAST:\\:%3.0lf%%\\n");
	push(@tmp, "LINE2:mem2#44EE44:Card 2\\g");
	push(@tmp, "GPRINT:mem2:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem5#EE4444:Card 5\\g");
	push(@tmp, "GPRINT:mem5:LAST:\\:%3.0lf%%");
	push(@tmp, "LINE2:mem8#963C74:Card 8\\g");
	push(@tmp, "GPRINT:mem8:LAST:\\:%3.0lf%%\\n");
	push(@tmpz, "LINE2:mem0#FFA500:Card 0");
	push(@tmpz, "LINE2:mem3#4444EE:Card 3");
	push(@tmpz, "LINE2:mem6#EE44EE:Card 6");
	push(@tmpz, "LINE2:mem1#44EEEE:Card 1");
	push(@tmpz, "LINE2:mem4#448844:Card 4");
	push(@tmpz, "LINE2:mem7#EEEE44:Card 7");
	push(@tmpz, "LINE2:mem2#44EE44:Card 2");
	push(@tmpz, "LINE2:mem5#EE4444:Card 5");
	push(@tmpz, "LINE2:mem8#963C74:Card 8");
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$rgraphs{_nvidia3}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Percent",
		"--width=$width",
		"--height=$height",
		"--upper-limit=100",
		"--lower-limit=0",
		"--rigid",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:mem0=$NVIDIA_RRD:nvidia_mem0:AVERAGE",
		"DEF:mem1=$NVIDIA_RRD:nvidia_mem1:AVERAGE",
		"DEF:mem2=$NVIDIA_RRD:nvidia_mem2:AVERAGE",
		"DEF:mem3=$NVIDIA_RRD:nvidia_mem3:AVERAGE",
		"DEF:mem4=$NVIDIA_RRD:nvidia_mem4:AVERAGE",
		"DEF:mem5=$NVIDIA_RRD:nvidia_mem5:AVERAGE",
		"DEF:mem6=$NVIDIA_RRD:nvidia_mem6:AVERAGE",
		"DEF:mem7=$NVIDIA_RRD:nvidia_mem7:AVERAGE",
		"DEF:mem8=$NVIDIA_RRD:nvidia_mem8:AVERAGE",
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$rgraphs{_nvidia3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Percent",
			"--width=$width",
			"--height=$height",
			"--upper-limit=100",
			"--lower-limit=0",
			"--rigid",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:mem0=$NVIDIA_RRD:nvidia_mem0:AVERAGE",
			"DEF:mem1=$NVIDIA_RRD:nvidia_mem1:AVERAGE",
			"DEF:mem2=$NVIDIA_RRD:nvidia_mem2:AVERAGE",
			"DEF:mem3=$NVIDIA_RRD:nvidia_mem3:AVERAGE",
			"DEF:mem4=$NVIDIA_RRD:nvidia_mem4:AVERAGE",
			"DEF:mem5=$NVIDIA_RRD:nvidia_mem5:AVERAGE",
			"DEF:mem6=$NVIDIA_RRD:nvidia_mem6:AVERAGE",
			"DEF:mem7=$NVIDIA_RRD:nvidia_mem7:AVERAGE",
			"DEF:mem8=$NVIDIA_RRD:nvidia_mem8:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nvidia3/)) {
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
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

# DISK graph
# ----------------------------------------------------------------------------
sub disk {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my $n;
	my $n2;
	my $e;
	my $e2;
	my $str;
	my $err;
	my @LC = (
		"#FFA500",
		"#44EEEE",
		"#44EE44",
		"#4444EE",
		"#448844",
		"#EE4444",
		"#EE44EE",
		"#EEEE44",
	);

	$title = !$silent ? $title : "";

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$DISK_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $DISK_RRD: $err\n") if $err;
		my $line1;
		my $line2;
		my $line3;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		foreach my $i (@DISK_LIST) {
			for($n = 0; $n < scalar(@$i); $n++) {
				$str = sprintf(" DISK %d               ", $n + 1);
				$line1 .= $str;
				$str = sprintf(" Temp Realloc Pending ", $n + 1);
				$line2 .= $str;
				$line3 .=      "----------------------";
			}
		}
		print("     $line1\n");
		print("Time $line2\n");
		print("-----$line3\n");
		my $line;
		my @row;
		my $time;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc ", $time);
			$e = 0;
			foreach my $i (@DISK_LIST) {
				for($n2 = 0; $n2 < scalar(@$i); $n2++) {
					$from = ($e * 8 * 3) + ($n2 * 3);
					$to = $from + 3;
					my ($temp, $realloc, $pending) = @$line[$from..$to];
					@row = ($temp, $realloc, $pending);
					printf(" %4.0f %7.0f %7.0f ", @row);
				}
				$e++;
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	for($n = 0; $n < scalar(@DISK_LIST); $n++) {
		for($n2 = 1; $n2 <= 8; $n2++) {
			$str = $u . $myself . $n . $n2 . "." . $when . ".png";
			push(@PNG, $str);
			unlink("$PNG_DIR" . $str);
			if($ENABLE_ZOOM eq "Y") {
				$str = $u . $myself . $n . $n2 . "z." . $when . ".png";
				push(@PNGz, $str);
				unlink("$PNG_DIR" . $str);
			}
		}
	}

	$e = 0;
	foreach my $i (@DISK_LIST) {
		if($e) {
			print("   <br>\n");
		}
		if($title) {
			graph_header($title, 2);
		}

		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "COMMENT: \\n");
		for($n = 0; $n < 8; $n++) {
			if(@$i[$n]) {
				my ($dstr) = (split /\s+/, @$i[$n]);
				$str = sprintf("%-20s", $dstr);
				push(@tmp, "LINE2:hd" . $n . $LC[$n] . ":$str");
				push(@tmpz, "LINE2:hd" . $n . $LC[$n] . ":$dstr");
				push(@tmp, "GPRINT:hd" . $n . ":LAST:   Current\\: %2.0lf");
				push(@tmp, "GPRINT:hd" . $n . ":AVERAGE:   Average\\: %2.0lf");
				push(@tmp, "GPRINT:hd" . $n . ":MIN:   Min\\: %2.0lf");
				push(@tmp, "GPRINT:hd" . $n . ":MAX:   Max\\: %2.0lf\\n");
			}
		}
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		if(scalar(@$i) && (scalar(@$i) % 2)) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		($width, $height) = split('x', $GRAPH_SIZE{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3]",
			"--title=$rgraphs{_disk1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Celsius",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:hd0=$DISK_RRD:disk" . $e ."_hd0_temp:AVERAGE",
			"DEF:hd1=$DISK_RRD:disk" . $e ."_hd1_temp:AVERAGE",
			"DEF:hd2=$DISK_RRD:disk" . $e ."_hd2_temp:AVERAGE",
			"DEF:hd3=$DISK_RRD:disk" . $e ."_hd3_temp:AVERAGE",
			"DEF:hd4=$DISK_RRD:disk" . $e ."_hd4_temp:AVERAGE",
			"DEF:hd5=$DISK_RRD:disk" . $e ."_hd5_temp:AVERAGE",
			"DEF:hd6=$DISK_RRD:disk" . $e ."_hd6_temp:AVERAGE",
			"DEF:hd7=$DISK_RRD:disk" . $e ."_hd7_temp:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3]",
				"--title=$rgraphs{_disk1}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Celsius",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@VERSION12,
				@graph_colors,
				"DEF:hd0=$DISK_RRD:disk" . $e ."_hd0_temp:AVERAGE",
				"DEF:hd1=$DISK_RRD:disk" . $e ."_hd1_temp:AVERAGE",
				"DEF:hd2=$DISK_RRD:disk" . $e ."_hd2_temp:AVERAGE",
				"DEF:hd3=$DISK_RRD:disk" . $e ."_hd3_temp:AVERAGE",
				"DEF:hd4=$DISK_RRD:disk" . $e ."_hd4_temp:AVERAGE",
				"DEF:hd5=$DISK_RRD:disk" . $e ."_hd5_temp:AVERAGE",
				"DEF:hd6=$DISK_RRD:disk" . $e ."_hd6_temp:AVERAGE",
				"DEF:hd7=$DISK_RRD:disk" . $e ."_hd7_temp:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /disk$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "'>\n");
			}
		}
		if($title) {
			print("    </td>\n");
			print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
		}

		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 8; $n += 2) {
			if(@$i[$n]) {
				$str = sprintf("%-17s", substr(@$i[$n], 0, 17));
				push(@tmp, "LINE2:rsc" . $n . $LC[$n] . ":$str");
				push(@tmpz, "LINE2:rsc" . $n . $LC[$n] . ":@$i[$n]\\g");
			}
			if(@$i[$n + 1]) {
				$str = sprintf("%-17s", substr(@$i[$n + 1], 0, 17));
				push(@tmp, "LINE2:rsc" . ($n + 1) . $LC[$n + 1] . ":$str\\n");
				push(@tmpz, "LINE2:rsc" . ($n + 1) . $LC[$n + 1] . ":@$i[$n + 1]\\g");
			}
		}
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 1]",
			"--title=$rgraphs{_disk2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Sectors",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:rsc0=$DISK_RRD:disk" . $e . "_hd0_smart1:AVERAGE",
			"DEF:rsc1=$DISK_RRD:disk" . $e . "_hd1_smart1:AVERAGE",
			"DEF:rsc2=$DISK_RRD:disk" . $e . "_hd2_smart1:AVERAGE",
			"DEF:rsc3=$DISK_RRD:disk" . $e . "_hd3_smart1:AVERAGE",
			"DEF:rsc4=$DISK_RRD:disk" . $e . "_hd4_smart1:AVERAGE",
			"DEF:rsc5=$DISK_RRD:disk" . $e . "_hd5_smart1:AVERAGE",
			"DEF:rsc6=$DISK_RRD:disk" . $e . "_hd6_smart1:AVERAGE",
			"DEF:rsc7=$DISK_RRD:disk" . $e . "_hd7_smart1:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 1]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 1]",
				"--title=$rgraphs{_disk2}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Sectors",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:rsc0=$DISK_RRD:disk" . $e . "_hd0_smart1:AVERAGE",
				"DEF:rsc1=$DISK_RRD:disk" . $e . "_hd1_smart1:AVERAGE",
				"DEF:rsc2=$DISK_RRD:disk" . $e . "_hd2_smart1:AVERAGE",
				"DEF:rsc3=$DISK_RRD:disk" . $e . "_hd3_smart1:AVERAGE",
				"DEF:rsc4=$DISK_RRD:disk" . $e . "_hd4_smart1:AVERAGE",
				"DEF:rsc5=$DISK_RRD:disk" . $e . "_hd5_smart1:AVERAGE",
				"DEF:rsc6=$DISK_RRD:disk" . $e . "_hd6_smart1:AVERAGE",
				"DEF:rsc7=$DISK_RRD:disk" . $e . "_hd7_smart1:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /disk$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 1] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 1] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "'>\n");
			}
		}

		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 8; $n += 2) {
			if(@$i[$n]) {
				$str = sprintf("%-17s", substr(@$i[$n], 0, 17));
				push(@tmp, "LINE2:cps" . $n . $LC[$n] . ":$str");
				push(@tmpz, "LINE2:cps" . $n . $LC[$n] . ":@$i[$n]\\g");
			}
			if(@$i[$n + 1]) {
				$str = sprintf("%-17s", substr(@$i[$n + 1], 0, 17));
				push(@tmp, "LINE2:cps" . ($n + 1) . $LC[$n + 1] . ":$str\\n");
				push(@tmpz, "LINE2:cps" . ($n + 1) . $LC[$n + 1] . ":@$i[$n + 1]\\g");
			}
		}
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 2]",
			"--title=$rgraphs{_disk3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Sectors",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:cps0=$DISK_RRD:disk" . $e . "_hd0_smart2:AVERAGE",
			"DEF:cps1=$DISK_RRD:disk" . $e . "_hd1_smart2:AVERAGE",
			"DEF:cps2=$DISK_RRD:disk" . $e . "_hd2_smart2:AVERAGE",
			"DEF:cps3=$DISK_RRD:disk" . $e . "_hd3_smart2:AVERAGE",
			"DEF:cps4=$DISK_RRD:disk" . $e . "_hd4_smart2:AVERAGE",
			"DEF:cps5=$DISK_RRD:disk" . $e . "_hd5_smart2:AVERAGE",
			"DEF:cps6=$DISK_RRD:disk" . $e . "_hd6_smart2:AVERAGE",
			"DEF:cps7=$DISK_RRD:disk" . $e . "_hd7_smart2:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 2]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 2]",
				"--title=$rgraphs{_disk3}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Sectors",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:cps0=$DISK_RRD:disk" . $e . "_hd0_smart2:AVERAGE",
				"DEF:cps1=$DISK_RRD:disk" . $e . "_hd1_smart2:AVERAGE",
				"DEF:cps2=$DISK_RRD:disk" . $e . "_hd2_smart2:AVERAGE",
				"DEF:cps3=$DISK_RRD:disk" . $e . "_hd3_smart2:AVERAGE",
				"DEF:cps4=$DISK_RRD:disk" . $e . "_hd4_smart2:AVERAGE",
				"DEF:cps5=$DISK_RRD:disk" . $e . "_hd5_smart2:AVERAGE",
				"DEF:cps6=$DISK_RRD:disk" . $e . "_hd6_smart2:AVERAGE",
				"DEF:cps7=$DISK_RRD:disk" . $e . "_hd7_smart2:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /disk$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 2] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 2] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		$e++;
	}
	return 1;
}

# FS graph
# ----------------------------------------------------------------------------
sub fs {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my $graph_title;
	my $vlabel;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my @riglim;
	my $n;
	my $n2;
	my $e;
	my $e2;
	my $str;
	my $err;
	my @LC = (
		"#FFA500",
		"#44EEEE",
		"#44EE44",
		"#4444EE",
		"#448844",
		"#5F04B4",
		"#EE44EE",
		"#EEEE44",
	);

	$title = !$silent ? $title : "";

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$FS_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $FS_RRD: $err\n") if $err;
		my $line1;
		my $line2;
		my $line3;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		foreach my $i (@FS_LIST) {
			for($n = 0; $n < scalar(@$i); $n++) {
				$str = sprintf("%23s", @$i[$n]);
				$line1 .= $str;
				$str = sprintf("   Use     I/O    Time ");
				$line2 .= $str;
				$line3 .=      "-----------------------";
			}
		}
		print("    $line1\n");
		print("Time $line2\n");
		print("-----$line3\n");
		my $line;
		my @row;
		my $time;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			my ($root, $swap) = @$line;
			printf(" %2d$tc ", $time);
			$e = 0;
			foreach my $i (@FS_LIST) {
				for($n2 = 0; $n2 < scalar(@$i); $n2++) {
					$from = ($e * 8 * 3) + ($n2 * 3);
					$to = $from + 3;
					my ($use, $ioa, $tim) = @$line[$from..$to];
					@row = ($use, $ioa, $tim);
					printf(" %4.1f%% %7.1f %7.1f ", @row);
				}
				$e++;
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	for($n = 0; $n < scalar(@FS_LIST); $n++) {
		for($n2 = 1; $n2 <= 8; $n2++) {
			$str = $u . $myself . $n . $n2 . "." . $when . ".png";
			push(@PNG, $str);
			unlink("$PNG_DIR" . $str);
			if($ENABLE_ZOOM eq "Y") {
				$str = $u . $myself . $n . $n2 . "z." . $when . ".png";
				push(@PNGz, $str);
				unlink("$PNG_DIR" . $str);
			}
		}
	}

	$e = 0;
	foreach my $i (@FS_LIST) {
		if($e) {
			print("   <br>\n");
		}
		if($title) {
			graph_header($title, 2);
		}

		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "COMMENT: \\n");
		for($n = 0; $n < 8; $n++) {
			if(@$i[$n]) {
				my $color;

				$str = $FS_DESC{@$i[$n]};
				$str = @$i[$n] unless $str;
				if($str eq "/") {
					$color = "#EE4444";
				} elsif($str eq "swap") {
					$color = "#CCCCCC";
				} elsif($str eq "/boot") {
					$color = "#666666";
				} else {
					$color = $LC[$n];
				}
				push(@tmpz, "LINE2:fs" . $n . $color . ":$str");
				$str = sprintf("%-23s", $str);
				push(@tmp, "LINE2:fs" . $n . $color . ":$str");
				push(@tmp, "GPRINT:fs" . $n . ":LAST:Cur\\: %4.1lf%%");
				push(@tmp, "GPRINT:fs" . $n . ":AVERAGE:   Avg\\: %4.1lf%%");
				push(@tmp, "GPRINT:fs" . $n . ":MIN:   Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:fs" . $n . ":MAX:   Max\\: %4.1lf%%\\n");
			}
		}
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		if(scalar(@$i) && (scalar(@$i) % 2)) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		($width, $height) = split('x', $GRAPH_SIZE{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@line, "COMMENT: \\n");
			push(@line, "COMMENT: \\n");
			push(@line, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3]",
			"--title=$rgraphs{_fs1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			"--upper-limit=100",
			"--lower-limit=0",
			"--rigid",
			@VERSION12,
			@graph_colors,
			"DEF:fs0=$FS_RRD:fs" . $e . "_use0:AVERAGE",
			"DEF:fs1=$FS_RRD:fs" . $e . "_use1:AVERAGE",
			"DEF:fs2=$FS_RRD:fs" . $e . "_use2:AVERAGE",
			"DEF:fs3=$FS_RRD:fs" . $e . "_use3:AVERAGE",
			"DEF:fs4=$FS_RRD:fs" . $e . "_use4:AVERAGE",
			"DEF:fs5=$FS_RRD:fs" . $e . "_use5:AVERAGE",
			"DEF:fs6=$FS_RRD:fs" . $e . "_use6:AVERAGE",
			"DEF:fs7=$FS_RRD:fs" . $e . "_use7:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3]",
				"--title=$rgraphs{_fs1}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Percent (%)",
				"--width=$width",
				"--height=$height",
				"--upper-limit=100",
				"--lower-limit=0",
				"--rigid",
				@VERSION12,
				@graph_colors,
				"DEF:fs0=$FS_RRD:fs" . $e . "_use0:AVERAGE",
				"DEF:fs1=$FS_RRD:fs" . $e . "_use1:AVERAGE",
				"DEF:fs2=$FS_RRD:fs" . $e . "_use2:AVERAGE",
				"DEF:fs3=$FS_RRD:fs" . $e . "_use3:AVERAGE",
				"DEF:fs4=$FS_RRD:fs" . $e . "_use4:AVERAGE",
				"DEF:fs5=$FS_RRD:fs" . $e . "_use5:AVERAGE",
				"DEF:fs6=$FS_RRD:fs" . $e . "_use6:AVERAGE",
				"DEF:fs7=$FS_RRD:fs" . $e . "_use7:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /fs$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "'>\n");
			}
		}
		if($title) {
			print("    </td>\n");
			print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
		}

		undef(@riglim);
		if($FS2_RIGID eq 1) {
			push(@riglim, "--upper-limit=$FS2_LIMIT");
		} else {
			if($FS2_RIGID eq 2) {
				push(@riglim, "--upper-limit=$FS2_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		for($n = 0; $n < 8; $n += 2) {
			my $color;
			if(@$i[$n]) {
				$str = $FS_DESC{@$i[$n]};
				$str = @$i[$n] unless $str;
				if($str eq "/") {
					$color = "#EE4444";
				} elsif($str eq "swap") {
					$color = "#CCCCCC";
				} elsif($str eq "/boot") {
					$color = "#666666";
				} else {
					$color = $LC[$n];
				}
				push(@tmpz, "LINE2:ioa" . $n . $color . ":$str\\g");
				$str = sprintf("%-17s", substr($str, 0, 17));
				push(@tmp, "LINE2:ioa" . $n . $color . ":$str");
			}
			if(@$i[$n + 1]) {
				$str = $FS_DESC{@$i[$n + 1]};
				$str = @$i[$n + 1] unless $str;
				if($str eq "/") {
					$color = "#EE4444";
				} elsif($str eq "swap") {
					$color = "#CCCCCC";
				} elsif($str eq "/boot") {
					$color = "#666666";
				} else {
					$color = $LC[$n + 1];
				}
				push(@tmpz, "LINE2:ioa" . ($n + 1) . $color . ":$str\\g");
				$str = sprintf("%-17s", substr($str, 0, 17));
				push(@tmp, "LINE2:ioa" . ($n + 1) . $color . ":$str\\n");
			}
		}
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 1]",
			"--title=$rgraphs{_fs2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Reads+Writes/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:ioa0=$FS_RRD:fs" . $e . "_ioa0:AVERAGE",
			"DEF:ioa1=$FS_RRD:fs" . $e . "_ioa1:AVERAGE",
			"DEF:ioa2=$FS_RRD:fs" . $e . "_ioa2:AVERAGE",
			"DEF:ioa3=$FS_RRD:fs" . $e . "_ioa3:AVERAGE",
			"DEF:ioa4=$FS_RRD:fs" . $e . "_ioa4:AVERAGE",
			"DEF:ioa5=$FS_RRD:fs" . $e . "_ioa5:AVERAGE",
			"DEF:ioa6=$FS_RRD:fs" . $e . "_ioa6:AVERAGE",
			"DEF:ioa7=$FS_RRD:fs" . $e . "_ioa7:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 1]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 1]",
				"--title=$rgraphs{_fs2}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Reads+Writes/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:ioa0=$FS_RRD:fs" . $e . "_ioa0:AVERAGE",
				"DEF:ioa1=$FS_RRD:fs" . $e . "_ioa1:AVERAGE",
				"DEF:ioa2=$FS_RRD:fs" . $e . "_ioa2:AVERAGE",
				"DEF:ioa3=$FS_RRD:fs" . $e . "_ioa3:AVERAGE",
				"DEF:ioa4=$FS_RRD:fs" . $e . "_ioa4:AVERAGE",
				"DEF:ioa5=$FS_RRD:fs" . $e . "_ioa5:AVERAGE",
				"DEF:ioa6=$FS_RRD:fs" . $e . "_ioa6:AVERAGE",
				"DEF:ioa7=$FS_RRD:fs" . $e . "_ioa7:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /fs$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 1] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 1] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "'>\n");
			}
		}

		undef(@riglim);
		if($FS3_RIGID eq 1) {
			push(@riglim, "--upper-limit=$FS3_LIMIT");
		} else {
			if($FS3_RIGID eq 2) {
				push(@riglim, "--upper-limit=$FS3_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		if($os eq "Linux") {
			if($kernel_branch > 2.4) {
	   			$graph_title = "$rgraphs{_fs3}  ($nwhen$twhen)";
				$vlabel = "Milliseconds";
			} else {
	   			$graph_title = "Disk sectors activity  ($nwhen$twhen)";
				$vlabel = "Sectors/s";
			}
			for($n = 0; $n < 8; $n += 2) {
				my $color;
				if(@$i[$n]) {
					$str = $FS_DESC{@$i[$n]};
					$str = @$i[$n] unless $str;
					if($str eq "/") {
						$color = "#EE4444";
					} elsif($str eq "swap") {
						$color = "#CCCCCC";
					} elsif($str eq "/boot") {
						$color = "#666666";
					} else {
						$color = $LC[$n];
					}
					push(@tmpz, "LINE2:tim" . $n . $color . ":$str\\g");
					$str = sprintf("%-17s", substr($str, 0, 17));
					push(@tmp, "LINE2:tim" . $n . $color . ":$str");
				}
				if(@$i[$n + 1]) {
					$str = $FS_DESC{@$i[$n + 1]};
					$str = @$i[$n + 1] unless $str;
					if($str eq "/") {
						$color = "#EE4444";
					} elsif($str eq "swap") {
						$color = "#CCCCCC";
					} elsif($str eq "/boot") {
						$color = "#666666";
					} else {
						$color = $LC[$n + 1];
					}
					push(@tmpz, "LINE2:tim" . ($n + 1) . $color . ":$str\\g");
					$str = sprintf("%-17s", substr($str, 0, 17));
					push(@tmp, "LINE2:tim" . ($n + 1) . $color . ":$str\\n");
				}
			}
		} elsif(grep {$_ eq $os} ("FreeBSD", "OpenBSD", "NetBSD")) {
	   		$graph_title = "Disk data activity  ($nwhen$twhen)";
			$vlabel = "KB/s";
			for($n = 0; $n < 8; $n += 2) {
				my $color;
				if(@$i[$n]) {
					$str = sprintf("%-17s", substr(@$i[$n], 0, 17));
					if($str eq "/") {
						$color = "#EE4444";
					} elsif($str eq "swap") {
						$color = "#CCCCCC";
					} elsif($str eq "/boot") {
						$color = "#666666";
					} else {
						$color = $LC[$n];
					}
					push(@tmp, "LINE2:tim" . $n . $color . ":$str");
					push(@tmpz, "LINE2:tim" . $n . $color . ":@$i[$n]\\g");
				}
				if(@$i[$n + 1]) {
					$str = sprintf("%-17s", substr(@$i[$n + 1], 0, 17));
					if($str eq "/") {
						$color = "#EE4444";
					} elsif($str eq "swap") {
						$color = "#CCCCCC";
					} elsif($str eq "/boot") {
						$color = "#666666";
					} else {
						$color = $LC[$n + 1];
					}
					push(@tmp, "LINE2:tim" . ($n + 1) . $color . ":$str\\n");
					push(@tmpz, "LINE2:tim" . ($n + 1) . $color . ":@$i[$n + 1]\\g");
				}
			}
		}
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 2]",
			"--title=$graph_title",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:tim0=$FS_RRD:fs" . $e . "_tim0:AVERAGE",
			"DEF:tim1=$FS_RRD:fs" . $e . "_tim1:AVERAGE",
			"DEF:tim2=$FS_RRD:fs" . $e . "_tim2:AVERAGE",
			"DEF:tim3=$FS_RRD:fs" . $e . "_tim3:AVERAGE",
			"DEF:tim4=$FS_RRD:fs" . $e . "_tim4:AVERAGE",
			"DEF:tim5=$FS_RRD:fs" . $e . "_tim5:AVERAGE",
			"DEF:tim6=$FS_RRD:fs" . $e . "_tim6:AVERAGE",
			"DEF:tim7=$FS_RRD:fs" . $e . "_tim7:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 2]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 2]",
				"--title=$graph_title",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:tim0=$FS_RRD:fs" . $e . "_tim0:AVERAGE",
				"DEF:tim1=$FS_RRD:fs" . $e . "_tim1:AVERAGE",
				"DEF:tim2=$FS_RRD:fs" . $e . "_tim2:AVERAGE",
				"DEF:tim3=$FS_RRD:fs" . $e . "_tim3:AVERAGE",
				"DEF:tim4=$FS_RRD:fs" . $e . "_tim4:AVERAGE",
				"DEF:tim5=$FS_RRD:fs" . $e . "_tim5:AVERAGE",
				"DEF:tim6=$FS_RRD:fs" . $e . "_tim6:AVERAGE",
				"DEF:tim7=$FS_RRD:fs" . $e . "_tim7:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /fs$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 2] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 2] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		$e++;
	}
	return 1;
}

# NET graph
# ----------------------------------------------------------------------------
sub net {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my $PNG1;
	my $PNG2;
	my $PNG3;
	my $PNG1z;
	my $PNG2z;
	my $PNG3z;
	my $netname;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $T = "B";
	my $vlabel = "bytes/s";
	my $n;
	my $str;
	my $err;

	$title = !$silent ? $title : "";

	if($NETSTATS_IN_BPS eq "Y") {
		$T = "b";
		$vlabel = "bits/s";
	}
	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$NET_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $NET_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("       ");
		for($n = 0; $n < scalar(@NET_LIST); $n++) {
			print("$NET_LIST[$n] ($NET_DESC[$n])                          ");
		}
		print("\nTime");
		for($n = 0; $n < scalar(@NET_LIST); $n++) {
			print("   K$T/s_I  K$T/s_O  Pk/s_I  Pk/s_O  Er/s_I  Er/s_O");
		}
		print(" \n----");
		for($n = 0; $n < scalar(@NET_LIST); $n++) {
			print("-------------------------------------------------");
		}
		print " \n";
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc", $time);
			for($n2 = 0; $n2 < scalar(@NET_LIST); $n2++) {
				$from = $n2 * 6;
				$to = $from + 6;
				my ($ki, $ko, $pi, $po, $ei, $eo) = @$line[$from..$to];
				$ki /= 1024;
				$ko /= 1024;
				$pi /= 1024;
				$po /= 1024;
				$ei /= 1024;
				$eo /= 1024;
				if($NETSTATS_IN_BPS eq "Y") {
					$ki *= 8;
					$ko *= 8;
				}
				@row = ($ki, $ko, $pi, $po, $ei, $eo);
				printf("   %6d  %6d  %6d  %6d  %6d  %6d", @row);
			}
			print(" \n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	for($n = 0; $n < scalar(@NET_LIST); $n++) {
		$PNG1 = $u . $myself . $n . "1." . $when . ".png";
		$PNG2 = $u . $myself . $n . "2." . $when . ".png";
		$PNG3 = $u . $myself . $n . "3." . $when . ".png";
		unlink("$PNG_DIR" . $PNG1);
		unlink("$PNG_DIR" . $PNG2);
		unlink("$PNG_DIR" . $PNG3);
		if($ENABLE_ZOOM eq "Y") {
			$PNG1z = $u . $myself . $n . "1z." . $when . ".png";
			$PNG2z = $u . $myself . $n . "2z." . $when . ".png";
			$PNG3z = $u . $myself . $n . "3z." . $when . ".png";
			unlink("$PNG_DIR" . $PNG1z);
			unlink("$PNG_DIR" . $PNG2z);
			unlink("$PNG_DIR" . $PNG3z);
		}

		if($title) {
			if($n) {
			print("    <br>\n");
			}
			graph_header($NET_LIST[$n] . " " . $title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}

		undef(@riglim);
		if($NET_RIGID[$n] eq 1) {
			push(@riglim, "--upper-limit=$NET_LIMIT[$n]");
		} else {
			if($NET_RIGID[$n] eq 2) {
				push(@riglim, "--upper-limit=$NET_LIMIT[$n]");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:B_in#44EE44:K$T/s Input");
		push(@tmp, "GPRINT:K_in:LAST:     Current\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:AVERAGE: Average\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:MIN:    Min\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:MAX:    Max\\: %5.0lf\\n");
		push(@tmp, "AREA:B_out#4444EE:K$T/s Output");
		push(@tmp, "GPRINT:K_out:LAST:    Current\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:AVERAGE: Average\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:MIN:    Min\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:MAX:    Max\\: %5.0lf\\n");
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
		if($NETSTATS_IN_BPS eq "Y") {
			push(@CDEF, "CDEF:B_in=in,8,*");
			push(@CDEF, "CDEF:B_out=out,8,*");
		} else {
			push(@CDEF, "CDEF:B_in=in");
			push(@CDEF, "CDEF:B_out=out");
		}
		($width, $height) = split('x', $GRAPH_SIZE{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG1",
			"--title=$NET_LIST[$n] $NET_DESC[$n] $rgraphs{_net1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:in=$NET_RRD:net" . $n . "_bytes_in:AVERAGE",
			"DEF:out=$NET_RRD:net" . $n . "_bytes_out:AVERAGE",
			@CDEF,
			"CDEF:K_in=B_in,1024,/",
			"CDEF:K_out=B_out,1024,/",
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			"COMMENT: \\n",
			);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNG1z",
				"--title=$NET_LIST[$n] $NET_DESC[$n] $rgraphs{_net1}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@graph_colors,
				"DEF:in=$NET_RRD:net" . $n . "_bytes_in:AVERAGE",
				"DEF:out=$NET_RRD:net" . $n . "_bytes_out:AVERAGE",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
		}
		$netname="net" . $n . "1";
		if($title || ($silent =~ /imagetag/ && $graph =~ /$netname/)) {
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
		if($title) {
			print("    </td>\n");
			print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
		}

		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:p_in#44EE44:Input");
		push(@tmp, "AREA:p_out#4444EE:Output");
		push(@tmp, "AREA:p_out#4444EE:");
		push(@tmp, "AREA:p_in#44EE44:");
		push(@tmp, "LINE1:p_out#0000EE");
		push(@tmp, "LINE1:p_in#00EE00");
		push(@tmpz, "AREA:p_in#44EE44:Input");
		push(@tmpz, "AREA:p_out#4444EE:Output");
		push(@tmpz, "AREA:p_out#4444EE:");
		push(@tmpz, "AREA:p_in#44EE44:");
		push(@tmpz, "LINE1:p_out#0000EE");
		push(@tmpz, "LINE1:p_in#00EE00");
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG2",
			"--title=$NET_LIST[$n] $rgraphs{_net2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Packets/s",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:p_in=$NET_RRD:net" . $n . "_packs_in:AVERAGE",
			"DEF:p_out=$NET_RRD:net" . $n . "_packs_out:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNG2z",
				"--title=$NET_LIST[$n] $rgraphs{_net2}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Packets/s",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:p_in=$NET_RRD:net" . $n . "_packs_in:AVERAGE",
				"DEF:p_out=$NET_RRD:net" . $n . "_packs_out:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
		}
		$netname="net" . $n . "2";
		if($title || ($silent =~ /imagetag/ && $graph =~ /$netname/)) {
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

		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:e_in#44EE44:Input");
		push(@tmp, "AREA:e_out#4444EE:Output");
		push(@tmp, "AREA:e_out#4444EE:");
		push(@tmp, "AREA:e_in#44EE44:");
		push(@tmp, "LINE1:e_out#0000EE");
		push(@tmp, "LINE1:e_in#00EE00");
		push(@tmpz, "AREA:e_in#44EE44:Input");
		push(@tmpz, "AREA:e_out#4444EE:Output");
		push(@tmpz, "AREA:e_out#4444EE:");
		push(@tmpz, "AREA:e_in#44EE44:");
		push(@tmpz, "LINE1:e_out#0000EE");
		push(@tmpz, "LINE1:e_in#00EE00");
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG3",
			"--title=$NET_LIST[$n] $rgraphs{_net3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Errors/s",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:e_in=$NET_RRD:net" . $n . "_error_in:AVERAGE",
			"DEF:e_out=$NET_RRD:net" . $n . "_error_out:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNG3z",
				"--title=$NET_LIST[$n] $rgraphs{_net3}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Errors/s",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:e_in=$NET_RRD:net" . $n . "_error_in:AVERAGE",
				"DEF:e_out=$NET_RRD:net" . $n . "_error_out:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
		}
		$netname="net" . $n . "3";
		if($title || ($silent =~ /imagetag/ && $graph =~ /$netname/)) {
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
			print("    </tr>\n");
			graph_footer();
		}
	}
	return 1;
}

# SERV graph
# ----------------------------------------------------------------------------
sub serv {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my $vlabel;
	my @tmp;
	my @tmpz;
	my $n;
	my $str;
	my $err;

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";

	$title = !$silent ? $title : "";

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$SERV_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $SERV_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		if($SERV_MODE eq "I") {
			print "Values expressed as incremental or cumulative hits.\n";
		}
		print("Time    SSH     FTP  Telnet   Samba     Fax    CUPS     F2B    IMAP    POP3    SMTP    Spam   Virus\n");
		print("--------------------------------------------------------------------------------------------------- \n");
		my $line;
		my @row;
		my $time;
		my $from = 0;
		my $to;
		if($SERV_MODE eq "L") {
			$from = 15;
		}
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			$to = $from + 10;
			my ($ssh, $ftp, $telnet, $imap, $smb, $fax, $cups, $pop3, $smtp, $spam, $virus, $f2b) = @$line[$from..$to];
			@row = ($ssh, $ftp, $telnet, $imap, $smb, $fax, $cups, $f2b, $pop3, $smtp, $spam, $virus);
			if($SERV_MODE eq "I") {
				printf(" %2d$tc %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d\n", $time, @row);
			} elsif($SERV_MODE eq "L") {
				printf(" %2d$tc %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f\n", $time, @row);
			}
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	if($title) {
		graph_header($title, 2);
	}
	if($SERV_MODE eq "L") {
		$vlabel = "Accesses/s";
		push(@tmp, "AREA:l_ssh#4444EE:SSH");
		push(@tmp, "GPRINT:l_ssh:LAST:        Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_ssh:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_ssh:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_ssh:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_ftp#44EE44:FTP");
		push(@tmp, "GPRINT:l_ftp:LAST:        Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_ftp:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_ftp:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_ftp:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_telnet#EE44EE:Telnet");
		push(@tmp, "GPRINT:l_telnet:LAST:     Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_telnet:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_telnet:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_telnet:MAX:   Max\\: %3.2lf\\n");
#		push(@tmp, "AREA:l_imap#44EEEE:IMAP");
#		push(@tmp, "GPRINT:l_imap:LAST:       Current\\: %3.2lf");
#		push(@tmp, "GPRINT:l_imap:AVERAGE:   Average\\: %3.2lf");
#		push(@tmp, "GPRINT:l_imap:MIN:   Min\\: %3.2lf");
#		push(@tmp, "GPRINT:l_imap:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_smb#EEEE44:Samba");
		push(@tmp, "GPRINT:l_smb:LAST:      Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_smb:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_smb:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_smb:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_fax#FFA500:Fax");
		push(@tmp, "GPRINT:l_fax:LAST:        Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_fax:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_fax:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_fax:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_cups#444444:CUPS");
		push(@tmp, "GPRINT:l_cups:LAST:       Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_cups:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_cups:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_cups:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_f2b#EE4444:Fail2ban");
		push(@tmp, "GPRINT:l_f2b:LAST:   Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_f2b:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_f2b:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_f2b:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "LINE2:l_ssh#4444EE");
		push(@tmp, "LINE2:l_ftp#44EE44");
		push(@tmp, "LINE2:l_telnet#EE44EE");
#		push(@tmp, "LINE2:l_imap#44EEEE");
		push(@tmp, "LINE2:l_smb#EEEE44");
		push(@tmp, "LINE2:l_fax#FFA500");
		push(@tmp, "LINE2:l_cups#444444");
		push(@tmp, "LINE2:l_f2b#EE4444");
		push(@tmp, "COMMENT: \\n");

		push(@tmpz, "AREA:l_ssh#4444EE:SSH");
		push(@tmpz, "AREA:l_ftp#44EE44:FTP");
		push(@tmpz, "AREA:l_telnet#EE44EE:Telnet");
#		push(@tmpz, "AREA:l_imap#44EEEE:IMAP");
		push(@tmpz, "AREA:l_smb#EEEE44:Samba");
		push(@tmpz, "AREA:l_fax#FFA500:Fax");
		push(@tmpz, "AREA:l_cups#444444:CUPS");
		push(@tmpz, "AREA:l_f2b#EE4444:Fail2ban");
		push(@tmpz, "LINE2:l_ssh#4444EE");
		push(@tmpz, "LINE2:l_ftp#44EE44");
		push(@tmpz, "LINE2:l_telnet#EE44EE");
#		push(@tmpz, "LINE2:l_imap#44EEEE");
		push(@tmpz, "LINE2:l_smb#EEEE44");
		push(@tmpz, "LINE2:l_fax#FFA500");
		push(@tmpz, "LINE2:l_cups#444444");
		push(@tmpz, "LINE2:l_f2b#EE4444");
	} else {
		$vlabel = "Incremental hits";
		push(@tmp, "AREA:i_ssh#4444EE:SSH");
		push(@tmp, "GPRINT:i_ssh:LAST:        Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_ssh:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_ssh:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_ssh:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_ftp#44EE44:FTP");
		push(@tmp, "GPRINT:i_ftp:LAST:        Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_ftp:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_ftp:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_ftp:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_telnet#EE44EE:Telnet");
		push(@tmp, "GPRINT:i_telnet:LAST:     Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_telnet:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_telnet:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_telnet:MAX:   Max\\: %5.0lf\\n");
#		push(@tmp, "AREA:i_imap#44EEEE:IMAP");
#		push(@tmp, "GPRINT:i_imap:LAST:       Current\\: %5.0lf");
#		push(@tmp, "GPRINT:i_imap:AVERAGE:   Average\\: %5.0lf");
#		push(@tmp, "GPRINT:i_imap:MIN:   Min\\: %5.0lf");
#		push(@tmp, "GPRINT:i_imap:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_smb#EEEE44:Samba");
		push(@tmp, "GPRINT:i_smb:LAST:      Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_smb:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_smb:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_smb:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_fax#FFA500:Fax");
		push(@tmp, "GPRINT:i_fax:LAST:        Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_fax:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_fax:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_fax:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_cups#444444:CUPS");
		push(@tmp, "GPRINT:i_cups:LAST:       Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_cups:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_cups:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_cups:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_f2b#EE4444:Fail2ban");
		push(@tmp, "GPRINT:i_f2b:LAST:   Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_f2b:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_f2b:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_f2b:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "LINE2:i_ssh#4444EE");
		push(@tmp, "LINE2:i_ftp#44EE44");
		push(@tmp, "LINE2:i_telnet#EE44EE");
#		push(@tmp, "LINE2:i_imap#44EEEE");
		push(@tmp, "LINE2:i_smb#EEEE44");
		push(@tmp, "LINE2:i_fax#FFA500");
		push(@tmp, "LINE2:i_cups#444444");
		push(@tmp, "LINE2:i_f2b#EE4444");
		push(@tmp, "COMMENT: \\n");

		push(@tmpz, "AREA:i_ssh#4444EE:SSH");
		push(@tmpz, "AREA:i_ftp#44EE44:FTP");
		push(@tmpz, "AREA:i_telnet#EE44EE:Telnet");
#		push(@tmpz, "AREA:i_imap#44EEEE:IMAP");
		push(@tmpz, "AREA:i_smb#EEEE44:Samba");
		push(@tmpz, "AREA:i_fax#FFA500:Fax");
		push(@tmpz, "AREA:i_cups#444444:CUPS");
		push(@tmpz, "AREA:i_f2b#EE4444:Fail2ban");
		push(@tmpz, "LINE2:i_ssh#4444EE");
		push(@tmpz, "LINE2:i_ftp#44EE44");
		push(@tmpz, "LINE2:i_telnet#EE44EE");
#		push(@tmpz, "LINE2:i_imap#44EEEE");
		push(@tmpz, "LINE2:i_smb#EEEE44");
		push(@tmpz, "LINE2:i_fax#FFA500");
		push(@tmpz, "LINE2:i_cups#444444");
		push(@tmpz, "LINE2:i_f2b#EE4444");
	}

	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$title_bg_color'>\n");
	}
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$rgraphs{_serv1}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		"DEF:i_ssh=$SERV_RRD:serv_i_ssh:AVERAGE",
		"DEF:i_ftp=$SERV_RRD:serv_i_ftp:AVERAGE",
		"DEF:i_telnet=$SERV_RRD:serv_i_telnet:AVERAGE",
		"DEF:i_imap=$SERV_RRD:serv_i_imap:AVERAGE",
		"DEF:i_smb=$SERV_RRD:serv_i_smb:AVERAGE",
		"DEF:i_fax=$SERV_RRD:serv_i_fax:AVERAGE",
		"DEF:i_cups=$SERV_RRD:serv_i_cups:AVERAGE",
		"DEF:i_f2b=$SERV_RRD:serv_i_f2b:AVERAGE",
		"DEF:l_ssh=$SERV_RRD:serv_l_ssh:AVERAGE",
		"DEF:l_ftp=$SERV_RRD:serv_l_ftp:AVERAGE",
		"DEF:l_telnet=$SERV_RRD:serv_l_telnet:AVERAGE",
		"DEF:l_imap=$SERV_RRD:serv_l_imap:AVERAGE",
		"DEF:l_smb=$SERV_RRD:serv_l_smb:AVERAGE",
		"DEF:l_fax=$SERV_RRD:serv_l_fax:AVERAGE",
		"DEF:l_cups=$SERV_RRD:serv_l_cups:AVERAGE",
		"DEF:l_f2b=$SERV_RRD:serv_l_f2b:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$rgraphs{_serv1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:i_ssh=$SERV_RRD:serv_i_ssh:AVERAGE",
			"DEF:i_ftp=$SERV_RRD:serv_i_ftp:AVERAGE",
			"DEF:i_telnet=$SERV_RRD:serv_i_telnet:AVERAGE",
			"DEF:i_imap=$SERV_RRD:serv_i_imap:AVERAGE",
			"DEF:i_smb=$SERV_RRD:serv_i_smb:AVERAGE",
			"DEF:i_fax=$SERV_RRD:serv_i_fax:AVERAGE",
			"DEF:i_cups=$SERV_RRD:serv_i_cups:AVERAGE",
			"DEF:i_f2b=$SERV_RRD:serv_i_f2b:AVERAGE",
			"DEF:l_ssh=$SERV_RRD:serv_l_ssh:AVERAGE",
			"DEF:l_ftp=$SERV_RRD:serv_l_ftp:AVERAGE",
			"DEF:l_telnet=$SERV_RRD:serv_l_telnet:AVERAGE",
			"DEF:l_imap=$SERV_RRD:serv_l_imap:AVERAGE",
			"DEF:l_smb=$SERV_RRD:serv_l_smb:AVERAGE",
			"DEF:l_fax=$SERV_RRD:serv_l_fax:AVERAGE",
			"DEF:l_cups=$SERV_RRD:serv_l_cups:AVERAGE",
			"DEF:l_f2b=$SERV_RRD:serv_l_f2b:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /serv1/)) {
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
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
	}

	undef(@tmp);
	undef(@tmpz);
	if($SERV_MODE eq "L") {
		$vlabel = "Accesses/s";
		push(@tmp, "AREA:l_imap#4444EE:IMAP");
		push(@tmp, "GPRINT:l_imap:LAST:                 Current\\: %4.2lf\\n");
		push(@tmp, "AREA:l_pop3#44EE44:POP3");
		push(@tmp, "GPRINT:l_pop3:LAST:                 Current\\: %4.2lf\\n");
		push(@tmp, "LINE1:l_imap#4444EE:");
		push(@tmp, "LINE1:l_pop3#44EE44:");
		push(@tmpz, "AREA:l_imap#4444EE:IMAP");
		push(@tmpz, "AREA:l_pop3#44EE44:POP3");
		push(@tmpz, "LINE2:l_imap#4444EE:");
		push(@tmpz, "LINE2:l_pop3#44EE44:");
	} else {
		$vlabel = "Incremental hits";
		push(@tmp, "AREA:i_imap#4444EE:IMAP");
		push(@tmp, "GPRINT:i_imap:LAST:                 Current\\: %5.0lf\\n");
		push(@tmp, "AREA:i_pop3#44EE44:POP3");
		push(@tmp, "GPRINT:i_pop3:LAST:                 Current\\: %5.0lf\\n");
		push(@tmp, "LINE1:i_imap#4444EE:");
		push(@tmp, "LINE1:i_pop3#44EE44:");
		push(@tmpz, "AREA:i_imap#4444EE:IMAP");
		push(@tmpz, "AREA:i_pop3#44EE44:POP3");
		push(@tmpz, "LINE2:i_imap#4444EE:");
		push(@tmpz, "LINE2:i_pop3#44EE44:");
	}
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$rgraphs{_serv2}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:i_imap=$SERV_RRD:serv_i_imap:AVERAGE",
		"DEF:l_imap=$SERV_RRD:serv_l_imap:AVERAGE",
		"DEF:i_pop3=$SERV_RRD:serv_i_pop3:AVERAGE",
		"DEF:l_pop3=$SERV_RRD:serv_l_pop3:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$rgraphs{_serv2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:i_imap=$SERV_RRD:serv_i_imap:AVERAGE",
			"DEF:l_imap=$SERV_RRD:serv_l_imap:AVERAGE",
			"DEF:i_pop3=$SERV_RRD:serv_i_pop3:AVERAGE",
			"DEF:l_pop3=$SERV_RRD:serv_l_pop3:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /serv2/)) {
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

	undef(@tmp);
	undef(@tmpz);
	if($SERV_MODE eq "L") {
		$vlabel = "Accesses/s";
		push(@tmp, "AREA:l_smtp#44EEEE:SMTP");
		push(@tmp, "GPRINT:l_smtp:LAST:                 Current\\: %4.2lf\\n");
		push(@tmp, "AREA:l_spam#EEEE44:Spam");
		push(@tmp, "GPRINT:l_spam:LAST:                 Current\\: %4.2lf\\n");
		push(@tmp, "AREA:l_virus#EE4444:Virus");
		push(@tmp, "GPRINT:l_virus:LAST:                Current\\: %4.2lf\\n");
		push(@tmp, "LINE2:l_smtp#44EEEE");
		push(@tmp, "LINE2:l_spam#EEEE44");
		push(@tmp, "LINE2:l_virus#EE4444");

		push(@tmpz, "AREA:l_smtp#44EEEE:SMTP");
		push(@tmpz, "AREA:l_spam#EEEE44:Spam");
		push(@tmpz, "AREA:l_virus#EE4444:Virus");
		push(@tmpz, "LINE2:l_smtp#44EEEE");
		push(@tmpz, "LINE2:l_spam#EEEE44");
		push(@tmpz, "LINE2:l_virus#EE4444");
	} else {
		$vlabel = "Incremental hits";
		push(@tmp, "AREA:i_smtp#44EEEE:SMTP");
		push(@tmp, "GPRINT:i_smtp:LAST:                 Current\\: %5.0lf\\n");
		push(@tmp, "AREA:i_spam#EEEE44:Spam");
		push(@tmp, "GPRINT:i_spam:LAST:                 Current\\: %5.0lf\\n");
		push(@tmp, "AREA:i_virus#EE4444:Virus");
		push(@tmp, "GPRINT:i_virus:LAST:                Current\\: %5.0lf\\n");
		push(@tmp, "LINE2:i_smtp#44EEEE");
		push(@tmp, "LINE2:i_spam#EEEE44");
		push(@tmp, "LINE2:i_virus#EE4444");

		push(@tmpz, "AREA:i_smtp#44EEEE:SMTP");
		push(@tmpz, "AREA:i_spam#EEEE44:Spam");
		push(@tmpz, "AREA:i_virus#EE4444:Virus");
		push(@tmpz, "LINE2:i_smtp#44EEEE");
		push(@tmpz, "LINE2:i_spam#EEEE44");
		push(@tmpz, "LINE2:i_virus#EE4444");
	}
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$rgraphs{_serv3}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:i_smtp=$SERV_RRD:serv_i_smtp:AVERAGE",
		"DEF:i_spam=$SERV_RRD:serv_i_spam:AVERAGE",
		"DEF:i_virus=$SERV_RRD:serv_i_virus:AVERAGE",
		"DEF:l_smtp=$SERV_RRD:serv_l_smtp:AVERAGE",
		"DEF:l_spam=$SERV_RRD:serv_l_spam:AVERAGE",
		"DEF:l_virus=$SERV_RRD:serv_l_virus:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		undef(@tmp);
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$rgraphs{_serv3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:i_smtp=$SERV_RRD:serv_i_smtp:AVERAGE",
			"DEF:i_spam=$SERV_RRD:serv_i_spam:AVERAGE",
			"DEF:i_virus=$SERV_RRD:serv_i_virus:AVERAGE",
			"DEF:l_smtp=$SERV_RRD:serv_l_smtp:AVERAGE",
			"DEF:l_spam=$SERV_RRD:serv_l_spam:AVERAGE",
			"DEF:l_virus=$SERV_RRD:serv_l_virus:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /serv3/)) {
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
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

# MAIL graph
# ----------------------------------------------------------------------------
sub mail {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my $T = "B";
	my $vlabel = "bytes/s";
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $n;
	my $str;
	my $err;

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG4 = $u . $myself . "4." . $when . ".png";
	my $PNG5 = $u . $myself . "5." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";
	my $PNG4z = $u . $myself . "4z." . $when . ".png";
	my $PNG5z = $u . $myself . "5z." . $when . ".png";

	$title = !$silent ? $title : "";

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3",
		"$PNG_DIR" . "$PNG4",
		"$PNG_DIR" . "$PNG5");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z",
			"$PNG_DIR" . "$PNG4z",
			"$PNG_DIR" . "$PNG5z");
	}

	if($NETSTATS_IN_BPS eq "Y") {
		$T = "b";
		$vlabel = "bits/s";
	}

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$MAIL_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $MAIL_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("Time  In.Conn Out.Conn  Receivd   Delivd  Bytes.R  Bytes.D  Rejectd  Bounced  Discard     Held  Forward     Spam    Virus   Queued  Queue.S\n");
		print("------------------------------------------------------------------------------------------------------------------------------------------- \n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			my ($in, $out, $recvd, $delvd, $bytes_recvd, $bytes_delvd, $rejtd, $spam, $virus, $bouncd, $queued, $discrd, $held, $forwrd, $queues) = @$line;
			@row = ($in, $out, $recvd, $delvd, $bytes_recvd, $bytes_delvd, $rejtd, $bouncd, $discrd, $held, $forwrd, $spam, $virus, $queued, $queues);
			printf(" %2d$tc  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f\n", $time, @row);
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	if($title) {
		graph_header($title, 2);
	}
	if(lc($MAIL_MTA) eq "sendmail") {
		push(@tmp, "AREA:in#44EE44:In Connections");
		push(@tmp, "GPRINT:in:LAST:    Cur\\: %5.2lf");
		push(@tmp, "GPRINT:in:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:in:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:in:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:rejtd#EE4444:Rejected");
		push(@tmp, "GPRINT:rejtd:LAST:          Cur\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:recvd#448844:Received");
		push(@tmp, "GPRINT:recvd:LAST:          Cur\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:spam#EEEE44:Spam");
		push(@tmp, "GPRINT:spam:LAST:              Cur\\: %5.2lf");
		push(@tmp, "GPRINT:spam:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:spam:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:spam:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:virus#EE44EE:Virus");
		push(@tmp, "GPRINT:virus:LAST:             Cur\\: %5.2lf");
		push(@tmp, "GPRINT:virus:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:virus:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:virus:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:n_delvd#4444EE:Delivered");
		push(@tmp, "GPRINT:delvd:LAST:         Cur\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:n_out#44EEEE:Out Connections");
		push(@tmp, "GPRINT:out:LAST:   Cur\\: %5.2lf");
		push(@tmp, "GPRINT:out:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:out:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:out:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "LINE1:in#00EE00");
		push(@tmp, "LINE1:rejtd#EE0000");
		push(@tmp, "LINE1:recvd#1F881F");
		push(@tmp, "LINE1:spam#EEEE00");
		push(@tmp, "LINE1:virus#EE00EE");
		push(@tmp, "LINE1:n_delvd#0000EE");
		push(@tmp, "LINE1:n_out#00EEEE");

		push(@tmpz, "AREA:in#44EE44:In Connections");
		push(@tmpz, "AREA:rejtd#EE4444:Rejected");
		push(@tmpz, "AREA:recvd#448844:Received");
		push(@tmpz, "AREA:spam#EEEE44:Spam");
		push(@tmpz, "AREA:virus#EE44EE:Virus");
		push(@tmpz, "AREA:n_delvd#4444EE:Delivered");
		push(@tmpz, "AREA:n_out#44EEEE:Out Connections");
		push(@tmpz, "LINE1:in#00EE00");
		push(@tmpz, "LINE1:rejtd#EE0000");
		push(@tmpz, "LINE1:recvd#1F881F");
		push(@tmpz, "LINE1:spam#EEEE00");
		push(@tmpz, "LINE1:virus#EE00EE");
		push(@tmpz, "LINE1:n_delvd#0000EE");
		push(@tmpz, "LINE1:n_out#00EEEE");
	} elsif(lc($MAIL_MTA eq "postfix")) {
		push(@tmp, "AREA:rejtd#EE4444:Rejected");
		push(@tmp, "GPRINT:rejtd:LAST:          Cur\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:recvd#448844:Received");
		push(@tmp, "GPRINT:recvd:LAST:          Cur\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:spam#EEEE44:Spam");
		push(@tmp, "GPRINT:spam:LAST:              Cur\\: %5.2lf");
		push(@tmp, "GPRINT:spam:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:spam:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:spam:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:virus#EE44EE:Virus");
		push(@tmp, "GPRINT:virus:LAST:             Cur\\: %5.2lf");
		push(@tmp, "GPRINT:virus:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:virus:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:virus:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:bouncd#FFA500:Bounced");
		push(@tmp, "GPRINT:bouncd:LAST:           Cur\\: %5.2lf");
		push(@tmp, "GPRINT:bouncd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:bouncd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:bouncd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:discrd#CCCCCC:Discarded");
		push(@tmp, "GPRINT:discrd:LAST:         Cur\\: %5.2lf");
		push(@tmp, "GPRINT:discrd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:discrd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:discrd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:held#44EE44:Held");
		push(@tmp, "GPRINT:held:LAST:              Cur\\: %5.2lf");
		push(@tmp, "GPRINT:held:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:held:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:held:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:n_forwrd#44EEEE:Forwarded");
		push(@tmp, "GPRINT:forwrd:LAST:         Cur\\: %5.2lf");
		push(@tmp, "GPRINT:forwrd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:forwrd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:forwrd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:n_delvd#4444EE:Delivered");
		push(@tmp, "GPRINT:delvd:LAST:         Cur\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "LINE1:rejtd#EE0000");
		push(@tmp, "LINE1:recvd#1F881F");
		push(@tmp, "LINE1:spam#EEEE00");
		push(@tmp, "LINE1:virus#EE00EE");
		push(@tmp, "LINE1:bouncd#FFA500");
		push(@tmp, "LINE1:discrd#888888");
		push(@tmp, "LINE1:held#00EE00");
		push(@tmp, "LINE1:n_forwrd#00EEEE");
		push(@tmp, "LINE1:n_delvd#0000EE");

		push(@tmpz, "AREA:rejtd#EE4444:Rejected");
		push(@tmpz, "AREA:recvd#448844:Received");
		push(@tmpz, "AREA:spam#EEEE44:Spam");
		push(@tmpz, "AREA:virus#EE44EE:Virus");
		push(@tmpz, "AREA:bouncd#FFA500:Bounced");
		push(@tmpz, "AREA:discrd#888888:Discarded");
		push(@tmpz, "AREA:held#44EE44:Held");
		push(@tmpz, "AREA:n_forwrd#44EEEE:Forwarded");
		push(@tmpz, "AREA:n_delvd#4444EE:Delivered");
		push(@tmpz, "LINE1:rejtd#EE0000");
		push(@tmpz, "LINE1:recvd#1F881F");
		push(@tmpz, "LINE1:spam#EEEE00");
		push(@tmpz, "LINE1:virus#EE00EE");
		push(@tmpz, "LINE1:bouncd#FFA500");
		push(@tmpz, "LINE1:discrd#888888");
		push(@tmpz, "LINE1:held#00EE00");
		push(@tmpz, "LINE1:n_forwrd#00EEEE");
		push(@tmpz, "LINE1:n_delvd#0000EE");
	}

	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$title_bg_color'>\n");
	}

	undef(@riglim);
	if($MAIL1_RIGID eq 1) {
		push(@riglim, "--upper-limit=$MAIL1_LIMIT");
	} else {
		if($MAIL1_RIGID eq 2) {
			push(@riglim, "--upper-limit=$MAIL1_LIMIT");
			push(@riglim, "--rigid");
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
		"--title=$rgraphs{_mail1}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Messages/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		"DEF:in=$MAIL_RRD:mail_in:AVERAGE",
		"DEF:out=$MAIL_RRD:mail_out:AVERAGE",
		"DEF:recvd=$MAIL_RRD:mail_recvd:AVERAGE",
		"DEF:delvd=$MAIL_RRD:mail_delvd:AVERAGE",
		"DEF:bytes_recvd=$MAIL_RRD:mail_bytes_recvd:AVERAGE",
		"DEF:bytes_delvd=$MAIL_RRD:mail_bytes_delvd:AVERAGE",
		"DEF:rejtd=$MAIL_RRD:mail_rejtd:AVERAGE",
		"DEF:spam=$MAIL_RRD:mail_spam:AVERAGE",
		"DEF:virus=$MAIL_RRD:mail_virus:AVERAGE",
		"DEF:bouncd=$MAIL_RRD:mail_bouncd:AVERAGE",
		"DEF:discrd=$MAIL_RRD:mail_discrd:AVERAGE",
		"DEF:held=$MAIL_RRD:mail_held:AVERAGE",
		"DEF:forwrd=$MAIL_RRD:mail_forwrd:AVERAGE",
		"CDEF:n_forwrd=forwrd,-1,*",
		"CDEF:n_delvd=delvd,-1,*",
		"CDEF:n_out=out,-1,*",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$rgraphs{_mail1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Messages/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:in=$MAIL_RRD:mail_in:AVERAGE",
			"DEF:out=$MAIL_RRD:mail_out:AVERAGE",
			"DEF:recvd=$MAIL_RRD:mail_recvd:AVERAGE",
			"DEF:delvd=$MAIL_RRD:mail_delvd:AVERAGE",
			"DEF:bytes_recvd=$MAIL_RRD:mail_bytes_recvd:AVERAGE",
			"DEF:bytes_delvd=$MAIL_RRD:mail_bytes_delvd:AVERAGE",
			"DEF:rejtd=$MAIL_RRD:mail_rejtd:AVERAGE",
			"DEF:spam=$MAIL_RRD:mail_spam:AVERAGE",
			"DEF:virus=$MAIL_RRD:mail_virus:AVERAGE",
			"DEF:bouncd=$MAIL_RRD:mail_bouncd:AVERAGE",
			"DEF:discrd=$MAIL_RRD:mail_discrd:AVERAGE",
			"DEF:held=$MAIL_RRD:mail_held:AVERAGE",
			"DEF:forwrd=$MAIL_RRD:mail_forwrd:AVERAGE",
			"CDEF:n_forwrd=forwrd,-1,*",
			"CDEF:n_delvd=delvd,-1,*",
			"CDEF:n_out=out,-1,*",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail1/)) {
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
	if($MAIL2_RIGID eq 1) {
		push(@riglim, "--upper-limit=$MAIL2_LIMIT");
	} else {
		if($MAIL2_RIGID eq 2) {
			push(@riglim, "--upper-limit=$MAIL2_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:B_in#44EE44:K$T/s Received");
	push(@tmp, "GPRINT:K_in:LAST:      Cur\\: %5.0lf");
	push(@tmp, "GPRINT:K_in:AVERAGE:    Avg\\: %5.0lf");
	push(@tmp, "GPRINT:K_in:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:K_in:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "AREA:B_out#4444EE:K$T/s Delivered");
	push(@tmp, "GPRINT:K_out:LAST:     Cur\\: %5.0lf");
	push(@tmp, "GPRINT:K_out:AVERAGE:    Avg\\: %5.0lf");
	push(@tmp, "GPRINT:K_out:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:K_out:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "AREA:B_out#4444EE:");
	push(@tmp, "AREA:B_in#44EE44:");
	push(@tmp, "LINE1:B_out#0000EE");
	push(@tmp, "LINE1:B_in#00EE00");
	push(@tmpz, "AREA:B_in#44EE44:Received");
	push(@tmpz, "AREA:B_out#4444EE:Delivered");
	push(@tmpz, "AREA:B_out#4444EE:");
	push(@tmpz, "AREA:B_in#44EE44:");
	push(@tmpz, "LINE1:B_out#0000EE");
	push(@tmpz, "LINE1:B_in#00EE00");
	if($NETSTATS_IN_BPS eq "Y") {
		push(@CDEF, "CDEF:B_in=in,8,*");
		push(@CDEF, "CDEF:B_out=out,8,*");
	} else {
		push(@CDEF, "CDEF:B_in=in");
		push(@CDEF, "CDEF:B_out=out");
	}
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
	}

	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$rgraphs{_mail2}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		"DEF:in=$MAIL_RRD:mail_bytes_recvd:AVERAGE",
		"DEF:out=$MAIL_RRD:mail_bytes_delvd:AVERAGE",
		@CDEF,
		"CDEF:K_in=B_in,1024,/",
		"CDEF:K_out=B_out,1024,/",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$rgraphs{_mail2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:in=$MAIL_RRD:mail_bytes_recvd:AVERAGE",
			"DEF:out=$MAIL_RRD:mail_bytes_delvd:AVERAGE",
			@CDEF,
			"CDEF:K_in=B_in,1024,/",
			"CDEF:K_out=B_out,1024,/",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail2/)) {
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
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
	}

	undef(@riglim);
	if($MAIL3_RIGID eq 1) {
		push(@riglim, "--upper-limit=$MAIL3_LIMIT");
	} else {
		if($MAIL3_RIGID eq 2) {
			push(@riglim, "--upper-limit=$MAIL3_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:queued#EEEE44:Queued");
	push(@tmp, "LINE1:queued#EEEE00");
	push(@tmp, "GPRINT:queued:LAST:               Current\\: %5.0lf\\n");
	push(@tmpz, "AREA:queued#EEEE44:Queued");
	push(@tmpz, "LINE1:queued#EEEE00");
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$rgraphs{_mail3}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Messages",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:queued=$MAIL_RRD:mail_queued:AVERAGE",
		"COMMENT: \\n",
		@tmp,
		"COMMENT: \\n",
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$rgraphs{_mail3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Messages",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:queued=$MAIL_RRD:mail_queued:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail3/)) {
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

	undef(@riglim);
	if($MAIL4_RIGID eq 1) {
		push(@riglim, "--upper-limit=$MAIL4_LIMIT");
	} else {
		if($MAIL4_RIGID eq 2) {
			push(@riglim, "--upper-limit=$MAIL4_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:queues#44AAEE:Size in KB");
	push(@tmp, "LINE1:queues#00AAEE");
	push(@tmp, "GPRINT:K_queues:LAST:           Current\\: %5.1lf\\n");
	push(@tmpz, "AREA:queues#44AAEE:Size");
	push(@tmpz, "LINE1:queues#00AAEE");
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
		"--title=$rgraphs{_mail4}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Bytes",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:queues=$MAIL_RRD:mail_queues:AVERAGE",
		"CDEF:K_queues=queues,1024,/",
		"COMMENT: \\n",
		@tmp,
		"COMMENT: \\n",
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG4: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG4z",
			"--title=$rgraphs{_mail4}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Bytes",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:queues=$MAIL_RRD:mail_queues:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail4/)) {
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
	if($MAIL5_RIGID eq 1) {
		push(@riglim, "--upper-limit=$MAIL5_LIMIT");
	} else {
		if($MAIL5_RIGID eq 2) {
			push(@riglim, "--upper-limit=$MAIL5_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:greylisted#4444EE:Greylisted");
	push(@tmp, "GPRINT:greylisted:LAST:           Current\\: %5.0lf\\n");
	push(@tmp, "AREA:whitelisted#44EEEE:Whitelisted");
	push(@tmp, "GPRINT:whitelisted:LAST:          Current\\: %5.0lf\\n");
	push(@tmp, "LINE1:greylisted#0000EE");
	push(@tmp, "LINE1:whitelisted#00EEEE");
	push(@tmp, "LINE1:records#EE0000:Records");
	push(@tmp, "GPRINT:records:LAST:              Current\\: %5.0lf\\n");
	push(@tmpz, "AREA:greylisted#4444EE:Greylisted");
	push(@tmpz, "AREA:whitelisted#44EEEE:Whitelisted");
	push(@tmpz, "LINE2:greylisted#0000EE");
	push(@tmpz, "LINE2:whitelisted#00EEEE");
	push(@tmpz, "LINE2:records#EE0000:Records");
	if(lc($MAIL_MTA eq "postfix")) {
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
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
		"--title=$rgraphs{_mail5}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Messages",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:records=$MAIL_RRD:mail_val07:AVERAGE",
		"DEF:greylisted=$MAIL_RRD:mail_val08:AVERAGE",
		"DEF:whitelisted=$MAIL_RRD:mail_val09:AVERAGE",
		"COMMENT: \\n",
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG5: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG5z",
			"--title=$rgraphs{_mail5}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Messages",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:records=$MAIL_RRD:mail_val07:AVERAGE",
			"DEF:greylisted=$MAIL_RRD:mail_val08:AVERAGE",
			"DEF:whitelisted=$MAIL_RRD:mail_val09:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail5/)) {
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

	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

# PORT graph
# ----------------------------------------------------------------------------
sub port {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @warning;
	my @PNG;
	my @PNGz;
	my $addr;
	my $stat;
	my $name;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $T = "B";
	my $vlabel = "bytes/s";
	my $n;
	my $str;
	my $err;

	my $PORT_PER_ROW = 3;
	$title = !$silent ? $title : "";

	if($NETSTATS_IN_BPS eq "Y") {
		$T = "b";
		$vlabel = "bits/s";
	}
	if($IFACE_MODE eq "text") {
		my $line2;
		my $line3;
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$PORT_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $PORT_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("    ");
		for($n = 0; $n < $PORT_MAX && $n < scalar(@PORT_LIST); $n++) {
			printf("   %-5s %-8s", $PORT_LIST[$n], substr($PORT_NAME[$n], 0, 8));
			$line2 .= "   K$T/s_I  K$T/s_O";
			$line3 .= "-----------------";
		}
		print("\n");
		print("Time$line2\n");
		print("----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc ", $time);
			for($n2 = 0; $n2 < $PORT_MAX && $n2 < scalar(@PORT_LIST); $n2++) {
				$from = $n2 * 2;
				$to = $from + 1;
				my ($kin, $kout) = @$line[$from..$to];
				$kin /= 1024;
				$kout /= 1024;
				if($NETSTATS_IN_BPS eq "Y") {
					$kin *= 8;
					$kout *= 8;
				}
				@row = ($kin, $kout);
				printf("  %6d  %6d ", @row);
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	for($n = 0; $n < $PORT_MAX; $n++) {
		$str = $u . $myself . $n . "." . $when . ".png";
		push(@PNG, $str);
		unlink("$PNG_DIR" . $str);
		if($ENABLE_ZOOM eq "Y") {
			$str = $u . $myself . $n . "z." . $when . ".png";
			push(@PNGz, $str);
			unlink("$PNG_DIR" . $str);
		}
	}

	$n = 0;
	while($n < $PORT_MAX && $n < scalar(@PORT_LIST)) {
		if($title) {
			if($n == 0) {
				graph_header($title, $PORT_PER_ROW);
			}
			print("    <tr>\n");
		}
		for($n2 = 0; $n2 < $PORT_PER_ROW; $n2++) {
			last unless ($n < $PORT_MAX && $n < scalar(@PORT_LIST));
			if($title) {
				print("    <td bgcolor='" . $title_bg_color . "'>\n");
			}
			undef(@riglim);
			if($PORT_RIGID[$n] eq 1) {
				push(@riglim, "--upper-limit=$PORT_LIMIT[$n]");
			} else {
				if($PORT_RIGID[$n] eq 2) {
					push(@riglim, "--upper-limit=$PORT_LIMIT[$n]");
					push(@riglim, "--rigid");
				}
			}

			undef(@warning);
			if($os eq "Linux") {
				open(IN, "netstat -nl --$PORT_PROT[$n] |");
				while(<IN>) {
					(undef, undef, undef, $addr) = split(' ', $_);
					chomp($addr);
					$addr =~ s/.*://;
					if($addr eq $PORT_LIST[$n]) {
						last;
					}
				}
				close(IN);
			}
			if($os eq "FreeBSD" || $os eq "OpenBSD") {
				open(IN, "netstat -anl -p $PORT_PROT[$n] |");
				while(<IN>) {
					(undef, undef, undef, $addr, undef, $stat) = split(' ', $_);
					chomp($stat);
					if($stat eq "LISTEN") {
						chomp($addr);
						($addr) = ($addr =~ m/^.*?(\.\d+$)/);
						$addr =~ s/\.//;
						if($addr eq $PORT_LIST[$n]) {
							last;
						}
					}
				}
				close(IN);
			}
			if($addr ne $PORT_LIST[$n]) {
				push(@warning, $warning_color);
			}

			$name = substr($PORT_NAME[$n], 0, 15);
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
			if($NETSTATS_IN_BPS eq "Y") {
				push(@CDEF, "CDEF:B_in=in,8,*");
				push(@CDEF, "CDEF:B_out=out,8,*");
			} else {
				push(@CDEF, "CDEF:B_in=in");
				push(@CDEF, "CDEF:B_out=out");
			}
			($width, $height) = split('x', $GRAPH_SIZE{mini});
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}
			RRDs::graph("$PNG_DIR" . "$PNG[$n]",
				"--title=$name traffic  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				@warning,
				"DEF:in=$PORT_RRD:port" . $n . "_in:AVERAGE",
				"DEF:out=$PORT_RRD:port" . $n . "_out:AVERAGE",
				@CDEF,
				@tmp);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG[$n]: $err\n") if $err;
			if($ENABLE_ZOOM eq "Y") {
				($width, $height) = split('x', $GRAPH_SIZE{zoom});
				RRDs::graph("$PNG_DIR" . "$PNGz[$n]",
					"--title=$name traffic  ($nwhen$twhen)",
					"--start=-$nwhen$twhen",
					"--imgformat=PNG",
					"--vertical-label=$vlabel",
					"--width=$width",
					"--height=$height",
					@riglim,
					"--lower-limit=0",
					@VERSION12,
					@VERSION12_small,
					@graph_colors,
					@warning,
					"DEF:in=$PORT_RRD:port" . $n . "_in:AVERAGE",
					"DEF:out=$PORT_RRD:port" . $n . "_out:AVERAGE",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				print("ERROR: while graphing $PNG_DIR" . "$PNGz[$n]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /port$n/)) {
				if($ENABLE_ZOOM eq "Y") {
					if($DISABLE_JAVASCRIPT_VOID eq "Y") {
						print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$n] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$n] . "' border='0'></a>\n");
					}
					else {
						print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$n] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$n] . "' border='0'></a>\n");
					}
				} else {
					print("      <img src='" . $URL . $IMGS_DIR . $PNG[$n] . "'>\n");
				}
			}
			if($title) {
				print("    </td>\n");
			}
			$n++;
		}
		if($title) {
			print("    </tr>\n");
		}
	}
	if($title) {
		graph_footer();
	}
	return 1;
}

# USER graph
# ----------------------------------------------------------------------------
sub user {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @tmp;
	my @tmpz;
	my $n;
	my $err;

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";

	$title = !$silent ? $title : "";

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$USER_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $USER_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("Time    Logged In     Samba  Netatalk\n");
		print("------------------------------------- \n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			my ($sys, $smb, $mac) = @$line;
			@row = ($sys, $smb, $mac);
			$time = $time - (1 / $ts);
			printf(" %2d$tc       %6d    %6d    %6d\n", $time, @row);
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	if($title) {
		graph_header($title, 2);
	}
	if($USER1_RIGID eq 1) {
		push(@riglim, "--upper-limit=$USER1_LIMIT");
	} else {
		if($USER1_RIGID eq 2) {
			push(@riglim, "--upper-limit=$USER1_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$title_bg_color'>\n");
	}
	push(@tmp, "AREA:sys#44EE44:Logged In");
	push(@tmp, "GPRINT:sys:LAST:        Current\\: %3.0lf");
	push(@tmp, "GPRINT:sys:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:sys:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:sys:MAX:   Max\\: %3.0lf\\n");
	push(@tmp, "LINE1:sys#00EE00");
	push(@tmpz, "AREA:sys#44EE44:Logged In");
	push(@tmpz, "LINE1:sys#00EE00");
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$rgraphs{_user1}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Users",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		"DEF:sys=$USER_RRD:user_sys:AVERAGE",
		"COMMENT: \\n",
		@tmp,
		"COMMENT: \\n",
		"COMMENT: \\n",
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$rgraphs{_user1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Users",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:sys=$USER_RRD:user_sys:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /user1/)) {
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
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
	}

	undef(@riglim);
	if($USER2_RIGID eq 1) {
		push(@riglim, "--upper-limit=$USER2_LIMIT");
	} else {
		if($USER2_RIGID eq 2) {
			push(@riglim, "--upper-limit=$USER2_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:smb#EEEE44:Samba");
	push(@tmp, "GPRINT:smb:LAST:                Current\\: %3.0lf\\n");
	push(@tmp, "LINE1:smb#EEEE00");
	push(@tmpz, "AREA:smb#EEEE44:Samba");
	push(@tmpz, "LINE2:smb#EEEE00");
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$rgraphs{_user2}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Users",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:smb=$USER_RRD:user_smb:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$rgraphs{_user2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Users",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:smb=$USER_RRD:user_smb:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /user2/)) {
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
	if($USER3_RIGID eq 1) {
		push(@riglim, "--upper-limit=$USER3_LIMIT");
	} else {
		if($USER3_RIGID eq 2) {
			push(@riglim, "--upper-limit=$USER3_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:mac#EE4444:Netatalk");
	push(@tmp, "GPRINT:mac:LAST:             Current\\: %3.0lf\\n");
	push(@tmp, "LINE1:mac#EE0000");
	push(@tmpz, "AREA:mac#EE4444:Netatalk");
	push(@tmpz, "LINE2:mac#EE0000");
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$rgraphs{_user3}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Users",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:mac=$USER_RRD:user_mac:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$rgraphs{_user3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Users",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:mac=$USER_RRD:user_mac:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /user3/)) {
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
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

# APACHE graph
# ----------------------------------------------------------------------------
sub apache {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my $e;
	my $e2;
	my $n;
	my $n2;
	my $str;
	my $err;

	$title = !$silent ? $title : "";

	if($IFACE_MODE eq "text") {
		my $line1;
		my $line2;
		my $line3;
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$APACHE_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $APACHE_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("    ");
		for($n = 0; $n < scalar(@APACHE_LIST); $n++) {
			$line1 = "                                          ";
			$line2 .= "   Acceses     kbytes      CPU  Busy  Idle";
			$line3 .= "------------------------------------------";
			if($line1) {
				$i = length($line1);
				printf(sprintf("%${i}s", sprintf("%s", $APACHE_LIST[$n])));
			}
		}
		print("\n");
		print("Time$line2\n");
		print("----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc", $time);
			for($n2 = 0; $n2 < scalar(@APACHE_LIST); $n2++) {
				undef(@row);
				$from = $n2 * 5;
				$to = $from + 5;
				push(@row, @$line[$from..$to]);
				printf("   %7d  %9d    %4.2f%%   %3d   %3d", @row);
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	for($n = 0; $n < scalar(@APACHE_LIST); $n++) {
		for($n2 = 1; $n2 <= 3; $n2++) {
			$str = $u . $myself . $n . $n2 . "." . $when . ".png";
			push(@PNG, $str);
			unlink("$PNG_DIR" . $str);
			if($ENABLE_ZOOM eq "Y") {
				$str = $u . $myself . $n . $n2 . "z." . $when . ".png";
				push(@PNGz, $str);
				unlink("$PNG_DIR" . $str);
			}
		}
	}

	$e = 0;
	foreach my $url (@APACHE_LIST) {
		if($e) {
			print("  <br>\n");
		}
		if($title) {
			graph_header($title, 2);
		}
		undef(@riglim);
		if($APACHE1_RIGID eq 1) {
			push(@riglim, "--upper-limit=$APACHE1_LIMIT");
		} else {
			if($APACHE1_RIGID eq 2) {
				push(@riglim, "--upper-limit=$APACHE1_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:apache" . $e . "_idle#4444EE:Idle");
		push(@tmp, "GPRINT:apache" . $e . "_idle:LAST:            Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_idle:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_idle:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_idle:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "AREA:apache" . $e . "_busy#44EEEE:Busy");
		push(@tmp, "GPRINT:apache" . $e . "_busy:LAST:            Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_busy:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_busy:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_busy:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "LINE1:apache" . $e . "_idle#0000EE");
		push(@tmp, "LINE1:apache" . $e . "_busy#00EEEE");
		push(@tmp, "LINE1:apache" . $e . "_tot#EE0000");
		push(@tmpz, "AREA:apache" . $e . "_idle#4444EE:Idle");
		push(@tmpz, "AREA:apache" . $e . "_busy#44EEEE:Busy");
		push(@tmpz, "LINE2:apache" . $e . "_idle#0000EE");
		push(@tmpz, "LINE2:apache" . $e . "_busy#00EEEE");
		push(@tmpz, "LINE2:apache" . $e . "_tot#EE0000");
		($width, $height) = split('x', $GRAPH_SIZE{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3]",
			"--title=$rgraphs{_apache1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Workers",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:apache" . $e . "_busy=$APACHE_RRD:apache" . $e . "_busy:AVERAGE",
			"DEF:apache" . $e . "_idle=$APACHE_RRD:apache" . $e . "_idle:AVERAGE",
			"CDEF:apache" . $e . "_tot=apache" . $e . "_busy,apache" . $e . "_idle,+",
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			"COMMENT: \\n");
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3]",
				"--title=$rgraphs{_apache1}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Workers",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@graph_colors,
				"DEF:apache" . $e . "_busy=$APACHE_RRD:apache" . $e . "_busy:AVERAGE",
				"DEF:apache" . $e . "_idle=$APACHE_RRD:apache" . $e . "_idle:AVERAGE",
				"CDEF:apache" . $e . "_tot=apache" . $e . "_busy,apache" . $e . "_idle,+",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "'>\n");
			}
		}
		if($title) {
			print("    </td>\n");
			print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
		}

		undef(@riglim);
		if($APACHE2_RIGID eq 1) {
			push(@riglim, "--upper-limit=$APACHE2_LIMIT");
		} else {
			if($APACHE2_RIGID eq 2) {
				push(@riglim, "--upper-limit=$APACHE2_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:apache" . $e . "_cpu#44AAEE:CPU");
		push(@tmp, "GPRINT:apache" . $e . "_cpu:LAST:                  Current\\: %5.2lf%%\\n");
		push(@tmp, "LINE1:apache" . $e . "_cpu#00EEEE");
		push(@tmpz, "AREA:apache" . $e . "_cpu#44AAEE:CPU");
		push(@tmpz, "LINE1:apache" . $e . "_cpu#00EEEE");
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 1]",
			"--title=$rgraphs{_apache2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:apache" . $e . "_cpu=$APACHE_RRD:apache" . $e . "_cpu:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 1]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 1]",
				"--title=$rgraphs{_apache2}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Percent",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:apache" . $e . "_cpu=$APACHE_RRD:apache" . $e . "_cpu:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 1] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 1] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "'>\n");
			}
		}

		undef(@riglim);
		if($APACHE3_RIGID eq 1) {
			push(@riglim, "--upper-limit=$APACHE3_LIMIT");
		} else {
			if($APACHE3_RIGID eq 2) {
				push(@riglim, "--upper-limit=$APACHE3_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:apache" . $e . "_acc#44EE44:Accesses");
		push(@tmp, "GPRINT:apache" . $e . "_acc:LAST:             Current\\: %5.2lf\\n");
		push(@tmp, "LINE1:apache" . $e . "_acc#00EE00");
		push(@tmpz, "AREA:apache" . $e . "_acc#44EE44:Accesses");
		push(@tmpz, "LINE1:apache" . $e . "_acc#00EE00");
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 2]",
			"--title=$rgraphs{_apache3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Accesses/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:apache" . $e . "_acc=$APACHE_RRD:apache" . $e . "_acc:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 2]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 2]",
				"--title=$rgraphs{_apache3}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Accesses/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:apache" . $e . "_acc=$APACHE_RRD:apache" . $e . "_acc:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 2] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 2] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    </tr>\n");

			print("    <tr>\n");
			print "      <td bgcolor='$title_bg_color' colspan='2'>\n";
			print "       <font face='Verdana, sans-serif' color='$title_fg_color'>\n";
			print "       <font size='-1'>\n";
			print "        <b style='{color: $title_fg_color}'>&nbsp;&nbsp;$url<b>\n";
			print "       </font></font>\n";
			print "      </td>\n";
			print("    </tr>\n");
			graph_footer();
		}
		$e++;
	}
	return 1;
}

# NGINX graph
# ----------------------------------------------------------------------------
sub nginx {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @warning;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $T = "B";
	my $vlabel = "bytes/s";
	my $addr;
	my $n;
	my $err;

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";

	$title = !$silent ? $title : "";

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	if($NETSTATS_IN_BPS eq "Y") {
		$T = "b";
		$vlabel = "bits/s";
	}
	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$NGINX_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $NGINX_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("Time   Total  Reading  Writing  Waiting Requests   K$T/s_I   K$T/s_O\n");
		print("------------------------------------------------------------------ \n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			my ($req, $tot, $rea, $wri, $wai, $ki, $ko) = @$line;
			$ki /= 1024;
			$ko /= 1024;
			if($NETSTATS_IN_BPS eq "Y") {
				$ki *= 8;
				$ko *= 8;
			}
			@row = ($tot, $rea, $wri, $wai, $req, $ki, $ko);
			$time = $time - (1 / $ts);
			printf(" %2d$tc  %6d   %6d   %6d   %6d   %6d   %6d   %6d\n", $time, @row);
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	if($title) {
		graph_header($title, 2);
	}
	if($NGINX1_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NGINX1_LIMIT");
	} else {
		if($NGINX1_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NGINX1_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$title_bg_color'>\n");
	}
	push(@tmp, "AREA:total#44EEEE:Total");
	push(@tmp, "GPRINT:total:LAST:       Current\\: %5.0lf");
	push(@tmp, "GPRINT:total:AVERAGE:    Average\\: %5.0lf");
	push(@tmp, "GPRINT:total:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:total:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "AREA:reading#44EE44:Reading");
	push(@tmp, "GPRINT:reading:LAST:     Current\\: %5.0lf");
	push(@tmp, "GPRINT:reading:AVERAGE:    Average\\: %5.0lf");
	push(@tmp, "GPRINT:reading:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:reading:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "AREA:writing#4444EE:Writing");
	push(@tmp, "GPRINT:writing:LAST:     Current\\: %5.0lf");
	push(@tmp, "GPRINT:writing:AVERAGE:    Average\\: %5.0lf");
	push(@tmp, "GPRINT:writing:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:writing:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "AREA:waiting#EE44EE:Waiting");
	push(@tmp, "GPRINT:waiting:LAST:     Current\\: %5.0lf");
	push(@tmp, "GPRINT:waiting:AVERAGE:    Average\\: %5.0lf");
	push(@tmp, "GPRINT:waiting:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:waiting:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "LINE1:total#00EEEE");
	push(@tmp, "LINE1:reading#00EE00");
	push(@tmp, "LINE1:writing#0000EE");
	push(@tmp, "LINE1:waiting#EE00EE");
	push(@tmpz, "AREA:total#44EEEE:Total");
	push(@tmpz, "AREA:reading#44EE44:Reading");
	push(@tmpz, "AREA:writing#4444EE:Writing");
	push(@tmpz, "AREA:waiting#EE44EE:Waiting");
	push(@tmpz, "LINE1:total#00EEEE");
	push(@tmpz, "LINE1:reading#00EE00");
	push(@tmpz, "LINE1:writing#0000EE");
	push(@tmpz, "LINE1:waiting#EE00EE");
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$rgraphs{_nginx1}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Connections/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		"DEF:total=$NGINX_RRD:nginx_total:AVERAGE",
		"DEF:reading=$NGINX_RRD:nginx_reading:AVERAGE",
		"DEF:writing=$NGINX_RRD:nginx_writing:AVERAGE",
		"DEF:waiting=$NGINX_RRD:nginx_waiting:AVERAGE",
		@tmp,
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$rgraphs{_nginx1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Connections/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:total=$NGINX_RRD:nginx_total:AVERAGE",
			"DEF:reading=$NGINX_RRD:nginx_reading:AVERAGE",
			"DEF:writing=$NGINX_RRD:nginx_writing:AVERAGE",
			"DEF:waiting=$NGINX_RRD:nginx_waiting:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nginx1/)) {
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
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
	}

	undef(@riglim);
	if($NGINX2_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NGINX2_LIMIT");
	} else {
		if($NGINX2_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NGINX2_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:requests#44EEEE:Requests");
	push(@tmp, "GPRINT:requests:LAST:             Current\\: %5.1lf\\n");
	push(@tmp, "LINE1:requests#00EEEE");
	push(@tmpz, "AREA:requests#44EEEE:Requests");
	push(@tmpz, "LINE1:requests#00EEEE");
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$rgraphs{_nginx2}  ($nwhen$twhen)",
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
		"DEF:requests=$NGINX_RRD:nginx_requests:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$rgraphs{_nginx2}  ($nwhen$twhen)",
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
			"DEF:requests=$NGINX_RRD:nginx_requests:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nginx2/)) {
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

	undef(@warning);
	if($os eq "Linux") {
		open(IN, "netstat -nl --tcp |");
		while(<IN>) {
			(undef, undef, undef, $addr) = split(' ', $_);
			chomp($addr);
			$addr =~ s/.*://;
			if($addr eq $NGINX_PORT) {
				last;
			}
		}
		close(IN);
	}
	if($os eq "FreeBSD" || $os eq "OpenBSD") {
		open(IN, "netstat -anl -p tcp |");
		while(<IN>) {
			(undef, undef, undef, $addr, undef, $stat) = split(' ', $_);
			chomp($stat);
			if($stat eq "LISTEN") {
				chomp($addr);
				($addr) = ($addr =~ m/^.*?(\.\d+$)/);
				$addr =~ s/\.//;
				if($addr eq $NGINX_PORT) {
					last;
				}
			}
		}
		close(IN);
	}
	if($addr ne $NGINX_PORT) {
		push(@warning, $warning_color);
	}

	undef(@riglim);
	if($NGINX3_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NGINX3_LIMIT");
	} else {
		if($NGINX3_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NGINX3_LIMIT");
			push(@riglim, "--rigid");
		}
	}
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
	if($NETSTATS_IN_BPS eq "Y") {
		push(@CDEF, "CDEF:B_in=in,8,*");
		push(@CDEF, "CDEF:B_out=out,8,*");
	} else {
		push(@CDEF, "CDEF:B_in=in");
		push(@CDEF, "CDEF:B_out=out");
	}
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$rgraphs{_nginx3}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		@warning,
		"DEF:in=$NGINX_RRD:nginx_bytes_in:AVERAGE",
		"DEF:out=$NGINX_RRD:nginx_bytes_out:AVERAGE",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$rgraphs{_nginx3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			@warning,
			"DEF:in=$NGINX_RRD:nginx_bytes_in:AVERAGE",
			"DEF:out=$NGINX_RRD:nginx_bytes_out:AVERAGE",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nginx3/)) {
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
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

# LIGHTTPD graph
# ----------------------------------------------------------------------------
sub lighttpd {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $vlabel = "bytes/s";
	my $e;
	my $e2;
	my $n;
	my $n2;
	my $str;
	my $err;

	$title = !$silent ? $title : "";

	if($NETSTATS_IN_BPS eq "Y") {
		$vlabel = "bits/s";
	}
	if($IFACE_MODE eq "text") {
		my $line1;
		my $line2;
		my $line3;
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$LIGHTTPD_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $LIGHTTPD_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("    ");
		for($n = 0; $n < scalar(@LIGHTTPD_LIST); $n++) {
			$line1 = "                                    ";
			$line2 .= "   Acceses     kbytes     Busy  Idle";
			$line3 .= "------------------------------------";
			if($line1) {
				$i = length($line1);
				printf(sprintf("%${i}s", sprintf("%s", $LIGHTTPD_LIST[$n])));
			}
		}
		print("\n");
		print("Time$line2\n");
		print("----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc", $time);
			for($n2 = 0; $n2 < scalar(@LIGHTTPD_LIST); $n2++) {
				undef(@row);
				$from = $n2 * 9;
				$to = $from + 9;
				push(@row, @$line[$from..$to]);
				printf("   %7d  %9d      %3d   %3d", @row);
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	for($n = 0; $n < scalar(@LIGHTTPD_LIST); $n++) {
		for($n2 = 1; $n2 <= 3; $n2++) {
			$str = $u . $myself . $n . $n2 . "." . $when . ".png";
			push(@PNG, $str);
			unlink("$PNG_DIR" . $str);
			if($ENABLE_ZOOM eq "Y") {
				$str = $u . $myself . $n . $n2 . "z." . $when . ".png";
				push(@PNGz, $str);
				unlink("$PNG_DIR" . $str);
			}
		}
	}

	$e = 0;
	foreach my $url (@LIGHTTPD_LIST) {
		if($e) {
			print("  <br>\n");
		}
		if($title) {
			graph_header($title, 2);
		}
		undef(@riglim);
		if($LIGHTTPD1_RIGID eq 1) {
			push(@riglim, "--upper-limit=$LIGHTTPD1_LIMIT");
		} else {
			if($LIGHTTPD1_RIGID eq 2) {
				push(@riglim, "--upper-limit=$LIGHTTPD1_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:lighttpd" . $e . "_idle#4444EE:Idle");
		push(@tmp, "GPRINT:lighttpd" . $e . "_idle:LAST:            Current\\: %3.0lf");
		push(@tmp, "GPRINT:lighttpd" . $e . "_idle:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:lighttpd" . $e . "_idle:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:lighttpd" . $e . "_idle:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "AREA:lighttpd" . $e . "_busy#44EEEE:Busy");
		push(@tmp, "GPRINT:lighttpd" . $e . "_busy:LAST:            Current\\: %3.0lf");
		push(@tmp, "GPRINT:lighttpd" . $e . "_busy:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:lighttpd" . $e . "_busy:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:lighttpd" . $e . "_busy:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "LINE1:lighttpd" . $e . "_idle#0000EE");
		push(@tmp, "LINE1:lighttpd" . $e . "_busy#00EEEE");
		push(@tmp, "LINE1:lighttpd" . $e . "_tot#EE0000");
		push(@tmpz, "AREA:lighttpd" . $e . "_idle#4444EE:Idle");
		push(@tmpz, "AREA:lighttpd" . $e . "_busy#44EEEE:Busy");
		push(@tmpz, "LINE2:lighttpd" . $e . "_idle#0000EE");
		push(@tmpz, "LINE2:lighttpd" . $e . "_busy#00EEEE");
		push(@tmpz, "LINE2:lighttpd" . $e . "_tot#EE0000");
		($width, $height) = split('x', $GRAPH_SIZE{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3]",
			"--title=$rgraphs{_lighttpd1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Workers",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:lighttpd" . $e . "_busy=$LIGHTTPD_RRD:lighttpd" . $e . "_busy:AVERAGE",
			"DEF:lighttpd" . $e . "_idle=$LIGHTTPD_RRD:lighttpd" . $e . "_idle:AVERAGE",
			"CDEF:lighttpd" . $e . "_tot=lighttpd" . $e . "_busy,lighttpd" . $e . "_idle,+",
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			"COMMENT: \\n");
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3]",
				"--title=$rgraphs{_lighttpd1}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Workers",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@graph_colors,
				"DEF:lighttpd" . $e . "_busy=$LIGHTTPD_RRD:lighttpd" . $e . "_busy:AVERAGE",
				"DEF:lighttpd" . $e . "_idle=$LIGHTTPD_RRD:lighttpd" . $e . "_idle:AVERAGE",
				"CDEF:lighttpd" . $e . "_tot=lighttpd" . $e . "_busy,lighttpd" . $e . "_idle,+",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /lighttpd$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "'>\n");
			}
		}
		if($title) {
			print("    </td>\n");
			print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
		}

		undef(@riglim);
		if($LIGHTTPD2_RIGID eq 1) {
			push(@riglim, "--upper-limit=$LIGHTTPD2_LIMIT");
		} else {
			if($LIGHTTPD2_RIGID eq 2) {
				push(@riglim, "--upper-limit=$LIGHTTPD2_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:Bytes#44AAEE:KBytes");
		push(@tmp, "GPRINT:lighttpd" . $e . "_kb:LAST:               Current\\: %6.1lf\\n");
		push(@tmp, "LINE1:lighttpd" . $e . "_kb#00EEEE");
		push(@tmpz, "AREA:Bytes#44AAEE:Bytes");
		push(@tmpz, "LINE1:lighttpd" . $e . "_kb#00EEEE");
		if($NETSTATS_IN_BPS eq "Y") {
			push(@CDEF, "CDEF:Bytes=lighttpd" . $e . "_kb,8,*,1024,*");
		} else {
			push(@CDEF, "CDEF:Bytes=lighttpd" . $e . "_kb,1024,*");
		}
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 1]",
			"--title=$rgraphs{_lighttpd2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:lighttpd" . $e . "_kb=$LIGHTTPD_RRD:lighttpd" . $e . "_kb:AVERAGE",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 1]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 1]",
				"--title=$rgraphs{_lighttpd2}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:lighttpd" . $e . "_kb=$LIGHTTPD_RRD:lighttpd" . $e . "_kb:AVERAGE",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /lighttpd$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 1] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 1] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "'>\n");
			}
		}

		undef(@riglim);
		if($LIGHTTPD3_RIGID eq 1) {
			push(@riglim, "--upper-limit=$LIGHTTPD3_LIMIT");
		} else {
			if($LIGHTTPD3_RIGID eq 2) {
				push(@riglim, "--upper-limit=$LIGHTTPD3_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:lighttpd" . $e . "_acc#44EE44:Accesses");
		push(@tmp, "GPRINT:lighttpd" . $e . "_acc:LAST:             Current\\: %5.2lf\\n");
		push(@tmp, "LINE1:lighttpd" . $e . "_acc#00EE00");
		push(@tmpz, "AREA:lighttpd" . $e . "_acc#44EE44:Accesses");
		push(@tmpz, "LINE1:lighttpd" . $e . "_acc#00EE00");
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3 + 2]",
			"--title=$rgraphs{_lighttpd3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Accesses/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:lighttpd" . $e . "_acc=$LIGHTTPD_RRD:lighttpd" . $e . "_acc:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3 + 2]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3 + 2]",
				"--title=$rgraphs{_lighttpd3}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Accesses/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:lighttpd" . $e . "_acc=$LIGHTTPD_RRD:lighttpd" . $e . "_acc:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /lighttpd$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 2] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 2] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    </tr>\n");

			print("    <tr>\n");
			print "      <td bgcolor='$title_bg_color' colspan='2'>\n";
			print "       <font face='Verdana, sans-serif' color='$title_fg_color'>\n";
			print "       <font size='-1'>\n";
			print "        <b style='{color: $title_fg_color}'>&nbsp;&nbsp;$url<b>\n";
			print "       </font></font>\n";
			print "      </td>\n";
			print("    </tr>\n");
			graph_footer();
		}
		$e++;
	}
	return 1;
}

# MYSQL graph
# ----------------------------------------------------------------------------
sub mysql {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $T = "B";
	my $vlabel = "bytes/s";
	my $e;
	my $e2;
	my $n;
	my $n2;
	my $num;
	my $err;

	$title = !$silent ? $title : "";

	if($NETSTATS_IN_BPS eq "Y") {
		$T = "b";
		$vlabel = "bits/s";
	}
	$MYSQL_CONN_TYPE = $MYSQL_CONN_TYPE || "Host";
	if(lc($MYSQL_CONN_TYPE) eq "host") {
		$num = scalar(@MYSQL_HOST_LIST);
	}
	if(lc($MYSQL_CONN_TYPE) eq "socket") {
		$num = scalar(@MYSQL_SOCK_LIST);
	}
	if($IFACE_MODE eq "text") {
		my $line1;
		my $line2;
		my $line3;
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$MYSQL_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $MYSQL_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("    ");
		for($n = 0; $n < $num; $n++) {
			$line1 = "                                                                                                                                                                                                                          ";
			$line2 .= "   Select  Commit  Delete  Insert  Insert_S  Update  Replace  Replace_S  Rollback  TCacheHit  QCache_U  Conns_U  KeyBuf_U  InnoDB_U  OpenedTbl  TLocks_W  Queries  SlowQrs  Conns  AbrtCli  AbrtConn  BytesRecv  BytesSent";
			$line3 .= "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
			if($line1) {
				$i = length($line1);
				if(lc($MYSQL_CONN_TYPE) eq "host") {
					printf(sprintf("%${i}s", sprintf("%s:%s", $MYSQL_HOST_LIST[$n], $MYSQL_PORT_LIST[$n])));
				}
				if(lc($MYSQL_CONN_TYPE) eq "socket") {
					printf(sprintf("%${i}s", sprintf("socket: %s", $MYSQL_SOCK_LIST[$n])));
				}
			}
		}
		print("\n");
		print("Time$line2\n");
		print("----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc", $time);
			for($n2 = 0; $n2 < $num; $n2++) {
				undef(@row);
				$from = $n2 * 38;
				$to = $from + 38;
				push(@row, @$line[$from..$to]);
				printf("   %6d  %6d  %6d  %6d  %8d  %6d  %7d   %8d  %8d        %2d%%       %2d%%      %2d%%       %2d%%       %2d%%     %6d    %6d   %6d   %6d %6d   %6d    %6d  %9d  %9d", @row);
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	$e = 0;
	for($n = 0; $n < $num; $n++) {
		for($n2 = 1; $n2 <= 6; $n2++) {
			$str = $u . $myself . $n . $n2 . "." . $when . ".png";
			push(@PNG, $str);
			unlink("$PNG_DIR" . $str);
			if($ENABLE_ZOOM eq "Y") {
				$str = $u . $myself . $n . $n2 . "z." . $when . ".png";
				push(@PNGz, $str);
				unlink("$PNG_DIR" . $str);
			}
		}

		if(lc($MYSQL_CONN_TYPE) eq "host") {
	        	$str = $MYSQL_HOST_LIST[$e] . ":" . $MYSQL_PORT_LIST[$e];
		}
		if(lc($MYSQL_CONN_TYPE) eq "socket") {
	        	$str = "socket: " . $MYSQL_SOCK_LIST[$e];
		}

		if($e) {
			print("  <br>\n");
		}
		if($title) {
			graph_header($title, 2);
		}
		undef(@riglim);
		if($MYSQL1_RIGID eq 1) {
			push(@riglim, "--upper-limit=$MYSQL1_LIMIT");
		} else {
			if($MYSQL1_RIGID eq 2) {
				push(@riglim, "--upper-limit=$MYSQL1_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		if($title) {
			print("    <tr>\n");
			print("    <td valign='top' bgcolor='$title_bg_color'>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "LINE1:com_select#FFA500:Select");
		push(@tmp, "GPRINT:com_select:LAST:         Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_select:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_select:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_select:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE1:com_commit#EEEE44:Commit");
		push(@tmp, "GPRINT:com_commit:LAST:         Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_commit:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_commit:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_commit:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE1:com_delete#EE4444:Delete");
		push(@tmp, "GPRINT:com_delete:LAST:         Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_delete:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_delete:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_delete:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE1:com_insert#44EE44:Insert");
		push(@tmp, "GPRINT:com_insert:LAST:         Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE1:com_insert_s#448844:Insert Select");
		push(@tmp, "GPRINT:com_insert_s:LAST:  Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert_s:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert_s:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_insert_s:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE1:com_update#EE44EE:Update");
		push(@tmp, "GPRINT:com_update:LAST:         Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_update:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_update:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_update:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE1:com_replace#44EEEE:Replace");
		push(@tmp, "GPRINT:com_replace:LAST:        Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE1:com_replace_s#4444EE:Replace Select");
		push(@tmp, "GPRINT:com_replace_s:LAST: Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace_s:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace_s:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_replace_s:MAX:    Max\\: %6.1lf\\n");
		push(@tmp, "LINE1:com_rollback#444444:Rollback");
		push(@tmp, "GPRINT:com_rollback:LAST:       Cur\\: %6.1lf");
		push(@tmp, "GPRINT:com_rollback:AVERAGE:    Avg\\: %6.1lf");
		push(@tmp, "GPRINT:com_rollback:MIN:    Min\\: %6.1lf");
		push(@tmp, "GPRINT:com_rollback:MAX:    Max\\: %6.1lf\\n");
		push(@tmpz, "LINE2:com_select#FFA500:Select");
		push(@tmpz, "LINE2:com_commit#EEEE44:Commit");
		push(@tmpz, "LINE2:com_delete#EE4444:Delete");
		push(@tmpz, "LINE2:com_insert#44EE44:Insert");
		push(@tmpz, "LINE2:com_insert_s#448844:Insert Sel");
		push(@tmpz, "LINE2:com_update#EE44EE:Update");
		push(@tmpz, "LINE2:com_replace#44EEEE:Replace");
		push(@tmpz, "LINE2:com_replace_s#4444EE:Replace Sel");
		push(@tmpz, "LINE2:com_rollback#444444:Rollback");
		($width, $height) = split('x', $GRAPH_SIZE{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 6]",
			"--title=$rgraphs{_mysql1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Queries/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:com_select=$MYSQL_RRD:mysql" . $e . "_csel:AVERAGE",
			"DEF:com_commit=$MYSQL_RRD:mysql" . $e . "_ccom:AVERAGE",
			"DEF:com_delete=$MYSQL_RRD:mysql" . $e . "_cdel:AVERAGE",
			"DEF:com_insert=$MYSQL_RRD:mysql" . $e . "_cins:AVERAGE",
			"DEF:com_insert_s=$MYSQL_RRD:mysql" . $e . "_cinss:AVERAGE",
			"DEF:com_update=$MYSQL_RRD:mysql" . $e . "_cupd:AVERAGE",
			"DEF:com_replace=$MYSQL_RRD:mysql" . $e . "_crep:AVERAGE",
			"DEF:com_replace_s=$MYSQL_RRD:mysql" . $e . "_creps:AVERAGE",
			"DEF:com_rollback=$MYSQL_RRD:mysql" . $e . "_crol:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 6]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 6]",
				"--title=$rgraphs{_mysql1}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Queries/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@graph_colors,
				"DEF:com_select=$MYSQL_RRD:mysql" . $e . "_csel:AVERAGE",
				"DEF:com_commit=$MYSQL_RRD:mysql" . $e . "_ccom:AVERAGE",
				"DEF:com_delete=$MYSQL_RRD:mysql" . $e . "_cdel:AVERAGE",
				"DEF:com_insert=$MYSQL_RRD:mysql" . $e . "_cins:AVERAGE",
				"DEF:com_insert_s=$MYSQL_RRD:mysql" . $e . "_cinss:AVERAGE",
				"DEF:com_update=$MYSQL_RRD:mysql" . $e . "_cupd:AVERAGE",
				"DEF:com_replace=$MYSQL_RRD:mysql" . $e . "_crep:AVERAGE",
				"DEF:com_replace_s=$MYSQL_RRD:mysql" . $e . "_creps:AVERAGE",
				"DEF:com_rollback=$MYSQL_RRD:mysql" . $e . "_crol:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 6]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 6] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 6] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 6] . "'>\n");
			}
		}

		undef(@riglim);
		if($MYSQL2_RIGID eq 1) {
			push(@riglim, "--upper-limit=$MYSQL2_LIMIT");
		} else {
			if($MYSQL2_RIGID eq 2) {
				push(@riglim, "--upper-limit=$MYSQL2_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "LINE1:tcache_hit_r#FFA500:Thread Cache Hit Rate");
		push(@tmp, "GPRINT:tcache_hit_r:LAST:  Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:tcache_hit_r:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:tcache_hit_r:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:tcache_hit_r:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE1:qcache_usage#44EEEE:Query Cache Usage");
		push(@tmp, "GPRINT:qcache_usage:LAST:      Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:qcache_usage:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:qcache_usage:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:qcache_usage:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE1:conns_u#44EE44:Connections Usage");
		push(@tmp, "GPRINT:conns_u:LAST:      Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:conns_u:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:conns_u:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:conns_u:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE1:key_buf_u#EE4444:Key Buffer Usage");
		push(@tmp, "GPRINT:key_buf_u:LAST:       Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:key_buf_u:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:key_buf_u:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:key_buf_u:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmp, "LINE1:innodb_buf_u#EE44EE:InnoDB Buffer P. Usage");
		push(@tmp, "GPRINT:innodb_buf_u:LAST: Cur\\: %4.1lf%%");
		push(@tmp, "GPRINT:innodb_buf_u:AVERAGE:  Avg\\: %4.1lf%%");
		push(@tmp, "GPRINT:innodb_buf_u:MIN:  Min\\: %4.1lf%%");
		push(@tmp, "GPRINT:innodb_buf_u:MAX:  Max\\: %4.1lf%%\\n");
		push(@tmpz, "LINE2:tcache_hit_r#FFA500:Thread Cache Hit Rate");
		push(@tmpz, "LINE2:qcache_usage#44EEEE:Query Cache Usage");
		push(@tmpz, "LINE2:conns_u#44EE44:Connections Usage");
		push(@tmpz, "LINE2:key_buf_u#EE4444:Key Buffer Usage");
		push(@tmpz, "LINE2:innodb_buf_u#EE44EE:Innodb Buffer P. Usage");
		($width, $height) = split('x', $GRAPH_SIZE{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 6 + 1]",
			"--title=$rgraphs{_mysql2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:tcache_hit_r=$MYSQL_RRD:mysql" . $e . "_tchr:AVERAGE",
			"DEF:qcache_usage=$MYSQL_RRD:mysql" . $e . "_qcu:AVERAGE",
			"DEF:conns_u=$MYSQL_RRD:mysql" . $e . "_conns_u:AVERAGE",
			"DEF:key_buf_u=$MYSQL_RRD:mysql" . $e . "_kbu:AVERAGE",
			"DEF:innodb_buf_u=$MYSQL_RRD:mysql" . $e . "_innbu:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 6 + 1]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 6 + 1]",
				"--title=$rgraphs{_mysql2}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Percent (%)",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@graph_colors,
				"DEF:tcache_hit_r=$MYSQL_RRD:mysql" . $e . "_tchr:AVERAGE",
				"DEF:qcache_usage=$MYSQL_RRD:mysql" . $e . "_qcu:AVERAGE",
				"DEF:conns_u=$MYSQL_RRD:mysql" . $e . "_conns_u:AVERAGE",
				"DEF:key_buf_u=$MYSQL_RRD:mysql" . $e . "_kbu:AVERAGE",
				"DEF:innodb_buf_u=$MYSQL_RRD:mysql" . $e . "_innbu:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 6 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 6 + 1] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 1] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 6 + 1] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 1] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 1] . "'>\n");
			}
		}
		if($title) {
			print("    </td>\n");
			print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
		}

		undef(@riglim);
		if($MYSQL3_RIGID eq 1) {
			push(@riglim, "--upper-limit=$MYSQL3_LIMIT");
		} else {
			if($MYSQL3_RIGID eq 2) {
				push(@riglim, "--upper-limit=$MYSQL3_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:opened_tbl#44EEEE:Opened Tables");
		push(@tmp, "GPRINT:opened_tbl:LAST:        Current\\: %7.1lf\\n");
		push(@tmp, "AREA:tlocks_w#4444EE:Table Locks Waited");
		push(@tmp, "GPRINT:tlocks_w:LAST:   Current\\: %7.1lf\\n");
		push(@tmp, "LINE1:opened_tbl#00EEEE");
		push(@tmp, "LINE1:tlocks_w#0000EE");
		push(@tmpz, "AREA:opened_tbl#44EEEE:Opened Tables");
		push(@tmpz, "AREA:tlocks_w#4444EE:Table Locks Waited");
		push(@tmpz, "LINE1:opened_tbl#00EEEE");
		push(@tmpz, "LINE1:tlocks_w#0000EE");
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 6 + 2]",
			"--title=$rgraphs{_mysql3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Open & Locks/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:opened_tbl=$MYSQL_RRD:mysql" . $e . "_ot:AVERAGE",
			"DEF:tlocks_w=$MYSQL_RRD:mysql" . $e . "_tlw:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 6 + 2]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 6 + 2]",
				"--title=$rgraphs{_mysql3}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Open & Locks/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:opened_tbl=$MYSQL_RRD:mysql" . $e . "_ot:AVERAGE",
				"DEF:tlocks_w=$MYSQL_RRD:mysql" . $e . "_tlw:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 6 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 6 + 2] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 2] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 6 + 2] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 2] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 2] . "'>\n");
			}
		}

		undef(@riglim);
		if($MYSQL4_RIGID eq 1) {
			push(@riglim, "--upper-limit=$MYSQL4_LIMIT");
		} else {
			if($MYSQL4_RIGID eq 2) {
				push(@riglim, "--upper-limit=$MYSQL4_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:qrs#44EEEE:Queries");
		push(@tmp, "GPRINT:qrs:LAST:              Current\\: %7.1lf\\n");
		push(@tmp, "AREA:sqrs#4444EE:Slow Queries");
		push(@tmp, "GPRINT:sqrs:LAST:         Current\\: %7.1lf\\n");
		push(@tmp, "LINE1:qrs#00EEEE");
		push(@tmp, "LINE1:sqrs#0000EE");
		push(@tmpz, "AREA:qrs#44EEEE:Queries");
		push(@tmpz, "AREA:sqrs#4444EE:Slow Queries");
		push(@tmpz, "LINE1:qrs#00EEEE");
		push(@tmpz, "LINE1:sqrs#0000EE");
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 6 + 3]",
			"--title=$rgraphs{_mysql4}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Queries/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:qrs=$MYSQL_RRD:mysql" . $e . "_queries:AVERAGE",
			"DEF:sqrs=$MYSQL_RRD:mysql" . $e . "_sq:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 6 + 3]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 6 + 3]",
				"--title=$rgraphs{_mysql4}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Queries/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:qrs=$MYSQL_RRD:mysql" . $e . "_queries:AVERAGE",
				"DEF:sqrs=$MYSQL_RRD:mysql" . $e . "_sq:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 6 + 3]: $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 6 + 3] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 3] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 6 + 3] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 3] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 3] . "'>\n");
			}
		}

		undef(@riglim);
		if($MYSQL5_RIGID eq 1) {
			push(@riglim, "--upper-limit=$MYSQL5_LIMIT");
		} else {
			if($MYSQL5_RIGID eq 2) {
				push(@riglim, "--upper-limit=$MYSQL5_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "AREA:conns#44EEEE:Connections");
		push(@tmp, "GPRINT:conns:LAST:          Current\\: %7.1lf\\n");
		push(@tmp, "AREA:acli#EEEE44:Aborted Clients");
		push(@tmp, "GPRINT:acli:LAST:      Current\\: %7.1lf\\n");
		push(@tmp, "AREA:acon#EE4444:Aborted Connects");
		push(@tmp, "GPRINT:acon:LAST:     Current\\: %7.1lf\\n");
		push(@tmp, "LINE1:conns#00EEEE");
		push(@tmp, "LINE1:acli#EEEE00");
		push(@tmp, "LINE1:acon#EE0000");
		push(@tmpz, "AREA:conns#44EEEE:Connections");
		push(@tmpz, "AREA:acli#EEEE44:Aborted Clients");
		push(@tmpz, "AREA:acon#EE4444:Aborted Connects");
		push(@tmpz, "LINE1:conns#00EEEE");
		push(@tmpz, "LINE1:acli#EEEE00");
		push(@tmpz, "LINE1:acon#EE0000");
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 6 + 4]",
			"--title=$rgraphs{_mysql5}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Connectionss/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:conns=$MYSQL_RRD:mysql" . $e . "_conns:AVERAGE",
			"DEF:acli=$MYSQL_RRD:mysql" . $e . "_acli:AVERAGE",
			"DEF:acon=$MYSQL_RRD:mysql" . $e . "_acon:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 6 + 4]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 6 + 4]",
				"--title=$rgraphs{_mysql5}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Connectionss/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:conns=$MYSQL_RRD:mysql" . $e . "_conns:AVERAGE",
				"DEF:acli=$MYSQL_RRD:mysql" . $e . "_acli:AVERAGE",
				"DEF:acon=$MYSQL_RRD:mysql" . $e . "_acon:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 6 + 4]: $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 6 + 4] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 4] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 6 + 4] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 4] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 4] . "'>\n");
			}
		}

		undef(@riglim);
		if($MYSQL6_RIGID eq 1) {
			push(@riglim, "--upper-limit=$MYSQL6_LIMIT");
		} else {
			if($MYSQL6_RIGID eq 2) {
				push(@riglim, "--upper-limit=$MYSQL6_LIMIT");
				push(@riglim, "--rigid");
			}
		}
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
		if($NETSTATS_IN_BPS eq "Y") {
			push(@CDEF, "CDEF:B_in=in,8,*");
			push(@CDEF, "CDEF:B_out=out,8,*");
		} else {
			push(@CDEF, "CDEF:B_in=in");
			push(@CDEF, "CDEF:B_out=out");
		}
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 6 + 5]",
			"--title=$rgraphs{_mysql6}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:in=$MYSQL_RRD:mysql" . $e . "_brecv:AVERAGE",
			"DEF:out=$MYSQL_RRD:mysql" . $e . "_bsent:AVERAGE",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 6 + 5]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 6 + 5]",
				"--title=$rgraphs{_mysql6}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:in=$MYSQL_RRD:mysql" . $e . "_brecv:AVERAGE",
				"DEF:out=$MYSQL_RRD:mysql" . $e . "_bsent:AVERAGE",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 6 + 5]: $err\n") if $err;
		}
		$e2 = $e + 6;
		if($title || ($silent =~ /imagetag/ && $graph =~ /mysql$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 6 + 5] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 5] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 6 + 5] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 5] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 6 + 5] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    </tr>\n");

			print("    <tr>\n");
			print "      <td bgcolor='$title_bg_color' colspan='2'>\n";
			print "       <font face='Verdana, sans-serif' color='$title_fg_color'>\n";
			print "       <font size='-1'>\n";
			print "        <b style='{color: $title_fg_color}'>&nbsp;&nbsp;$str<b>\n";
			print "       </font></font>\n";
			print "      </td>\n";
			print("    </tr>\n");
			graph_footer();
		}
		$e++;
	}
	return 1;
}

# SQUID graph
# ----------------------------------------------------------------------------
sub squid {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @tmp;
	my @tmpz;
	my $i;
	my @DEF;
	my $n;
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

	$title = !$silent ? $title : "";

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

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$SQUID_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $SQUID_RRD: $err\n") if $err;
		my $str;
		my $line1;
		my $line2;
		my $line3;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		for($n = 0; $n < scalar(@SQUID_GRAPH_1); $n++) {
			$line2 .= sprintf("%6d", $n + 1);
			$str .= "------";
		}
		$line3 .= $str;
		$i = length($str);
		$line1 .= sprintf(" %${i}s", "Statistics graph 1");
		undef($str);
		$line2 .= " ";
		$line3 .= "-";
		for($n = 0; $n < scalar(@SQUID_GRAPH_2); $n++) {
			$line2 .= sprintf("%6d", $n + 1);
			$str .= "------";
		}
		$line3 .= $str;
		$i = length($str);
		$line1 .= sprintf(" %${i}s", "Statistics graph 2");
		$line1 .= "                                              Overall I/O";
		$line2 .= "  cHTTPr cHTTPh sHTTPr  sFTPr sOther Abortr SwpFcl Unlnkr";
		$line3 .= "---------------------------------------------------------";
		$line1 .= "     Memory usage (MB)";
		$line2 .= "   Alloct   InUse  %  ";
		$line3 .= "----------------------";
		$line1 .= "      Storage usage (MB)";
		$line2 .= "    Alloct    InUse  %  ";
		$line3 .= "------------------------";
		$line1 .= "        IP Cache";
		$line2 .= "  Reqs Hits Miss";
		$line3 .= "----------------";
		$line1 .= "    Network Protocols";
		$line2 .= "  HTTP  FTP Goph WAIS";
		$line3 .= "---------------------";
		$line1 .= "  Client Traffic";
		$line2 .= "    Input Output";
		$line3 .= "----------------";
		$line1 .= "  Server Traffic";
		$line2 .= "    Input Output";
		$line3 .= "----------------";
		print("    $line1\n");
		print("Time $line2\n");
		print("-----$line3 \n");
		my $line;
		my @row;
		my $time;
		my @g1;
		my @g2;
		my $n2;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			undef($line1);
			undef(@row);
			(@g1) = @$line[0..scalar(@SQUID_GRAPH_1) - 1];
			for($n2 = 0; $n2 < scalar(@SQUID_GRAPH_1); $n2++) {
				push(@row, $g1[$n2]);
				$line1 .= "%5d ";
			}
			(@g2) = @$line[9..9 + scalar(@SQUID_GRAPH_2) - 1];
			$line1 .= " ";
			for($n2 = 0; $n2 < scalar(@SQUID_GRAPH_2); $n2++) {
				push(@row, $g2[$n2]);
				$line1 .= "%5d ";
			}
			$line1 .= " ";
			push(@row, @$line[18..25]);
			$line1 .= "%6d %6d %6d %6d %6d %6d %6d %6d ";
			$line1 .= " ";
			push(@row, @$line[27..28]);
			push(@row, (@$line[28] * 100) / @$line[27]);
			$line1 .= "%7d %7d %3.1f ";
			$line1 .= " ";
			push(@row, @$line[43..44]);
			push(@row, (@$line[44] * 100) / @$line[43]);
			$line1 .= "%8d %8d %3.1f ";
			$line1 .= " ";
			push(@row, @$line[32..34]);
			$line1 .= "%4d %4d %4d ";
			$line1 .= " ";
			push(@row, @$line[37..40]);
			$line1 .= "%4d %4d %4d %4d ";
			$line1 .= " ";
			push(@row, @$line[47..48]);
			$line1 .= " %6d %6d ";
			$line1 .= " ";
			push(@row, @$line[50..51]);
			$line1 .= " %6d %6d ";
			$time = $time - (1 / $ts);
			printf(" %2d$tc  $line1\n", $time, @row);
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	if($title) {
		graph_header($title, 2);
	}
	if($SQUID1_RIGID eq 1) {
		push(@riglim, "--upper-limit=$SQUID1_LIMIT");
	} else {
		if($SQUID1_RIGID eq 2) {
			push(@riglim, "--upper-limit=$SQUID1_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	if($title) {
		print("    <tr>\n");
		print("    <td valign='top' bgcolor='$title_bg_color'>\n");
	}
	for($n = 0, $i = 1; $n < 9; $n++, $i++) {
		if($SQUID_GRAPH_1[$n]) {
			$str = sprintf("%-34s", $SQUID_GRAPH_1[$n]);
			$str = substr($str, 0, 23);
			push(@DEF, "DEF:squid_g1_$i=$SQUID_RRD:squid_g1_$i:AVERAGE");
			push(@tmp, "LINE1:squid_g1_$i$AC[$n]:$str");
			push(@tmp, "GPRINT:squid_g1_$i:LAST:Cur\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g1_$i:AVERAGE:  Avg\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g1_$i:MIN:  Min\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g1_$i:MAX:  Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:squid_g1_$i$AC[$n]:$SQUID_GRAPH_1[$n]");
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
		"--title=$rgraphs{_squid1}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Values/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		@DEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$rgraphs{_squid1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Values/s",
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
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid1/)) {
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
	if($SQUID2_RIGID eq 1) {
		push(@riglim, "--upper-limit=$SQUID2_LIMIT");
	} else {
		if($SQUID2_RIGID eq 2) {
			push(@riglim, "--upper-limit=$SQUID2_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	undef(@DEF);
	for($n = 0, $i = 1; $n < 9; $n++, $i++) {
		if($SQUID_GRAPH_2[$n]) {
			$str = sprintf("%-34s", $SQUID_GRAPH_2[$n]);
			$str = substr($str, 0, 23);
			push(@DEF, "DEF:squid_g2_$i=$SQUID_RRD:squid_g2_$i:AVERAGE");
			push(@tmp, "LINE1:squid_g2_$i$AC[$n]:$str");
			push(@tmp, "GPRINT:squid_g2_$i:LAST:Cur\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g2_$i:AVERAGE:  Avg\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g2_$i:MIN:  Min\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g2_$i:MAX:  Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:squid_g2_$i$AC[$n]:$SQUID_GRAPH_2[$n]");
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
		"--title=$rgraphs{_squid2}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Values/s",
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
			"--title=$rgraphs{_squid2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Values/s",
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
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid2/)) {
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
	if($SQUID3_RIGID eq 1) {
		push(@riglim, "--upper-limit=$SQUID3_LIMIT");
	} else {
		if($SQUID3_RIGID eq 2) {
			push(@riglim, "--upper-limit=$SQUID3_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	undef(@DEF);
	push(@tmp, "LINE1:squid_rq_1$AC[0]:Client HTTP requests");
	push(@tmp, "GPRINT:squid_rq_1:LAST:  Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_1:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_1:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_1:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE1:squid_rq_2$AC[1]:Client HTTP hits");
	push(@tmp, "GPRINT:squid_rq_2:LAST:      Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_2:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_2:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_2:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE1:squid_rq_3$AC[2]:Server HTTP requests");
	push(@tmp, "GPRINT:squid_rq_3:LAST:  Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_3:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_3:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_3:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE1:squid_rq_4$AC[3]:Server FTP requests");
	push(@tmp, "GPRINT:squid_rq_4:LAST:   Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_4:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_4:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_4:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE1:squid_rq_5$AC[4]:Server Other requests");
	push(@tmp, "GPRINT:squid_rq_5:LAST: Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_5:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_5:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_5:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE1:squid_rq_6$AC[5]:Aborted requests");
	push(@tmp, "GPRINT:squid_rq_6:LAST:      Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_6:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_6:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_6:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE1:squid_rq_7$AC[6]:Swap files cleaned");
	push(@tmp, "GPRINT:squid_rq_7:LAST:    Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_7:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_7:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_7:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE1:squid_rq_8$AC[7]:Unlink requests");
	push(@tmp, "GPRINT:squid_rq_8:LAST:       Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_8:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_8:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_8:MAX:  Max\\: %6.1lf\\n");
	push(@tmpz, "LINE2:squid_rq_1$AC[0]:Client HTTP requests");
	push(@tmpz, "LINE2:squid_rq_2$AC[1]:Client HTTP hits");
	push(@tmpz, "LINE2:squid_rq_3$AC[2]:Server HTTP requests");
	push(@tmpz, "LINE2:squid_rq_4$AC[3]:Server FTP requests");
	push(@tmpz, "LINE2:squid_rq_5$AC[4]:Server Other requests");
	push(@tmpz, "LINE2:squid_rq_6$AC[5]:Aborted requests");
	push(@tmpz, "LINE2:squid_rq_7$AC[6]:Swap files cleaned");
	push(@tmpz, "LINE2:squid_rq_8$AC[7]:Unlink requests");
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$rgraphs{_squid3}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Values/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		"DEF:squid_rq_1=$SQUID_RRD:squid_rq_1:AVERAGE",
		"DEF:squid_rq_2=$SQUID_RRD:squid_rq_2:AVERAGE",
		"DEF:squid_rq_3=$SQUID_RRD:squid_rq_3:AVERAGE",
		"DEF:squid_rq_4=$SQUID_RRD:squid_rq_4:AVERAGE",
		"DEF:squid_rq_5=$SQUID_RRD:squid_rq_5:AVERAGE",
		"DEF:squid_rq_6=$SQUID_RRD:squid_rq_6:AVERAGE",
		"DEF:squid_rq_7=$SQUID_RRD:squid_rq_7:AVERAGE",
		"DEF:squid_rq_8=$SQUID_RRD:squid_rq_8:AVERAGE",
		"DEF:squid_rq_9=$SQUID_RRD:squid_rq_9:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$rgraphs{_squid3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Values/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:squid_rq_1=$SQUID_RRD:squid_rq_1:AVERAGE",
			"DEF:squid_rq_2=$SQUID_RRD:squid_rq_2:AVERAGE",
			"DEF:squid_rq_3=$SQUID_RRD:squid_rq_3:AVERAGE",
			"DEF:squid_rq_4=$SQUID_RRD:squid_rq_4:AVERAGE",
			"DEF:squid_rq_5=$SQUID_RRD:squid_rq_5:AVERAGE",
			"DEF:squid_rq_6=$SQUID_RRD:squid_rq_6:AVERAGE",
			"DEF:squid_rq_7=$SQUID_RRD:squid_rq_7:AVERAGE",
			"DEF:squid_rq_8=$SQUID_RRD:squid_rq_8:AVERAGE",
			"DEF:squid_rq_9=$SQUID_RRD:squid_rq_9:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid3/)) {
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
	if($SQUID4_RIGID eq 1) {
		push(@riglim, "--upper-limit=$SQUID4_LIMIT");
	} else {
		if($SQUID4_RIGID eq 2) {
			push(@riglim, "--upper-limit=$SQUID4_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "LINE1:m_alloc#EEEE44:Allocated");
	push(@tmp, "GPRINT:m_alloc:LAST:            Current\\: %7.1lf\\n");
	push(@tmp, "AREA:m_inuse#44AAEE:In use");
	push(@tmp, "LINE1:m_inuse#00AAEE:");
	push(@tmp, "GPRINT:m_inuse:LAST:               Current\\: %7.1lf\\n");
	push(@tmp, "GPRINT:m_perc:LAST:                          In use\\:   %5.1lf%%\\n");
	push(@tmpz, "LINE2:m_alloc#EEEE44:Allocated");
	push(@tmpz, "AREA:m_inuse#44AAEE:In use");
	push(@tmpz, "LINE2:m_inuse#00AAEE:");
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
		"--title=$rgraphs{_squid4}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Megabytes",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:squid_m_1=$SQUID_RRD:squid_m_1:AVERAGE",
		"DEF:squid_m_2=$SQUID_RRD:squid_m_2:AVERAGE",
		"CDEF:m_alloc=squid_m_1,1024,/",
		"CDEF:m_inuse=squid_m_2,1024,/",
		"CDEF:m_perc=squid_m_2,100,*,squid_m_1,/",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG4: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG4z",
			"--title=$rgraphs{_squid4}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Megabytes",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:squid_m_1=$SQUID_RRD:squid_m_1:AVERAGE",
			"DEF:squid_m_2=$SQUID_RRD:squid_m_2:AVERAGE",
			"CDEF:m_alloc=squid_m_1,1024,/",
			"CDEF:m_inuse=squid_m_2,1024,/",
			"CDEF:m_perc=squid_m_2,100,*,squid_m_1,/",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid4/)) {
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
	if($SQUID5_RIGID eq 1) {
		push(@riglim, "--upper-limit=$SQUID5_LIMIT");
	} else {
		if($SQUID5_RIGID eq 2) {
			push(@riglim, "--upper-limit=$SQUID5_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "LINE1:s_alloc#EEEE44:Allocated");
	push(@tmp, "GPRINT:s_alloc:LAST:            Current\\: %7.1lf\\n");
	push(@tmp, "AREA:s_inuse#44AAEE:In use");
	push(@tmp, "GPRINT:s_inuse:LAST:               Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:s_inuse#00AAEE:");
	push(@tmp, "GPRINT:s_perc:LAST:                          In use\\:   %5.1lf%%\\n");
	push(@tmpz, "LINE2:s_alloc#EEEE44:Allocated");
	push(@tmpz, "AREA:s_inuse#44AAEE:In use");
	push(@tmpz, "LINE2:s_inuse#00AAEE:");
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
		"--title=$rgraphs{_squid5}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Megabytes",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:squid_s_2=$SQUID_RRD:squid_s_2:AVERAGE",
		"DEF:squid_s_3=$SQUID_RRD:squid_s_3:AVERAGE",
		"CDEF:s_alloc=squid_s_2,1024,/",
		"CDEF:s_inuse=squid_s_3,1024,/",
		"CDEF:s_perc=squid_s_3,100,*,squid_s_2,/",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG5: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG5z",
			"--title=$rgraphs{_squid5}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Megabytes",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:squid_s_2=$SQUID_RRD:squid_s_2:AVERAGE",
			"DEF:squid_s_3=$SQUID_RRD:squid_s_3:AVERAGE",
			"CDEF:s_alloc=squid_s_2,1024,/",
			"CDEF:s_inuse=squid_s_3,1024,/",
			"CDEF:s_perc=squid_s_3,100,*,squid_s_2,/",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid5/)) {
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
	if($SQUID6_RIGID eq 1) {
		push(@riglim, "--upper-limit=$SQUID6_LIMIT");
	} else {
		if($SQUID6_RIGID eq 2) {
			push(@riglim, "--upper-limit=$SQUID6_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:ic_requests#44EEEE:Requests");
	push(@tmp, "GPRINT:ic_requests:LAST:             Current\\: %7.1lf\\n");
	push(@tmp, "AREA:ic_hits#4444EE:Hits");
	push(@tmp, "GPRINT:ic_hits:LAST:                 Current\\: %7.1lf\\n");
	push(@tmp, "AREA:ic_misses#EE44EE:Misses");
	push(@tmp, "GPRINT:ic_misses:LAST:               Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:ic_requests#00EEEE");
	push(@tmp, "LINE1:ic_hits#0000EE");
	push(@tmp, "LINE1:ic_misses#EE00EE");
	push(@tmpz, "AREA:ic_requests#44EEEE:Requests");
	push(@tmpz, "AREA:ic_hits#4444EE:Hits");
	push(@tmpz, "AREA:ic_misses#EE44EE:Misses");
	push(@tmpz, "LINE1:ic_requests#00EEEE");
	push(@tmpz, "LINE1:ic_hits#0000EE");
	push(@tmpz, "LINE1:ic_misses#EE00EE");
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
		"--title=$rgraphs{_squid6}  ($nwhen$twhen)",
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
		"DEF:ic_requests=$SQUID_RRD:squid_ic_1:AVERAGE",
		"DEF:ic_hits=$SQUID_RRD:squid_ic_2:AVERAGE",
		"DEF:ic_misses=$SQUID_RRD:squid_ic_3:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG6: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG6z",
			"--title=$rgraphs{_squid6}  ($nwhen$twhen)",
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
			"DEF:ic_requests=$SQUID_RRD:squid_ic_1:AVERAGE",
			"DEF:ic_hits=$SQUID_RRD:squid_ic_2:AVERAGE",
			"DEF:ic_misses=$SQUID_RRD:squid_ic_3:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG6z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid6/)) {
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
	if($SQUID7_RIGID eq 1) {
		push(@riglim, "--upper-limit=$SQUID7_LIMIT");
	} else {
		if($SQUID7_RIGID eq 2) {
			push(@riglim, "--upper-limit=$SQUID7_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:io_http#44EEEE:HTTP");
	push(@tmp, "GPRINT:io_http:LAST:                 Current\\: %7.1lf\\n");
	push(@tmp, "AREA:io_ftp#4444EE:FTP");
	push(@tmp, "GPRINT:io_ftp:LAST:                  Current\\: %7.1lf\\n");
	push(@tmp, "AREA:io_gopher#EE44EE:Gopher");
	push(@tmp, "GPRINT:io_gopher:LAST:               Current\\: %7.1lf\\n");
	push(@tmp, "AREA:io_wais#EEEE44:WAIS");
	push(@tmp, "GPRINT:io_wais:LAST:                 Current\\: %7.1lf\\n");
	push(@tmp, "LINE1:io_http#00EEEE");
	push(@tmp, "LINE1:io_ftp#0000EE");
	push(@tmp, "LINE1:io_gopher#EE00EE");
	push(@tmp, "LINE1:io_wais#EEEE00");
	push(@tmpz, "AREA:io_http#44EEEE:HTTP");
	push(@tmpz, "AREA:io_ftp#4444EE:FTP");
	push(@tmpz, "AREA:io_gopher#EE44EE:Gopher");
	push(@tmpz, "AREA:io_wais#EEEE44:WAIS");
	push(@tmpz, "LINE1:io_http#44EEEE");
	push(@tmpz, "LINE1:io_ftp#4444EE");
	push(@tmpz, "LINE1:io_gopher#EE44EE");
	push(@tmpz, "LINE1:io_wais#EEEE44");
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
		"--title=$rgraphs{_squid7}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Reads/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		"DEF:io_http=$SQUID_RRD:squid_io_1:AVERAGE",
		"DEF:io_ftp=$SQUID_RRD:squid_io_2:AVERAGE",
		"DEF:io_gopher=$SQUID_RRD:squid_io_3:AVERAGE",
		"DEF:io_wais=$SQUID_RRD:squid_io_4:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG7: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG7z",
			"--title=$rgraphs{_squid7}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Reads/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:io_http=$SQUID_RRD:squid_io_1:AVERAGE",
			"DEF:io_ftp=$SQUID_RRD:squid_io_2:AVERAGE",
			"DEF:io_gopher=$SQUID_RRD:squid_io_3:AVERAGE",
			"DEF:io_wais=$SQUID_RRD:squid_io_4:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG7z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid7/)) {
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
	if($SQUID8_RIGID eq 1) {
		push(@riglim, "--upper-limit=$SQUID8_LIMIT");
	} else {
		if($SQUID8_RIGID eq 2) {
			push(@riglim, "--upper-limit=$SQUID8_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:in#44EE44:Input");
	push(@tmp, "AREA:out#4444EE:Output");
	push(@tmp, "AREA:out#4444EE:");
	push(@tmp, "AREA:in#44EE44:");
	push(@tmp, "LINE1:out#0000EE");
	push(@tmp, "LINE1:in#00EE00");
	push(@tmpz, "AREA:in#44EE44:Input");
	push(@tmpz, "AREA:out#4444EE:Output");
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
	RRDs::graph("$PNG_DIR" . "$PNG8",
		"--title=$rgraphs{_squid8}  ($nwhen$twhen)",
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
		"DEF:in=$SQUID_RRD:squid_tc_1:AVERAGE",
		"DEF:out=$SQUID_RRD:squid_tc_2:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG8: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG8z",
			"--title=$rgraphs{_squid8}  ($nwhen$twhen)",
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
			"DEF:in=$SQUID_RRD:squid_tc_1:AVERAGE",
			"DEF:out=$SQUID_RRD:squid_tc_2:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG8z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid8/)) {
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
	if($SQUID9_RIGID eq 1) {
		push(@riglim, "--upper-limit=$SQUID9_LIMIT");
	} else {
		if($SQUID9_RIGID eq 2) {
			push(@riglim, "--upper-limit=$SQUID9_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:in#44EE44:Input");
	push(@tmp, "AREA:out#4444EE:Output");
	push(@tmp, "AREA:out#4444EE:");
	push(@tmp, "AREA:in#44EE44:");
	push(@tmp, "LINE1:out#0000EE");
	push(@tmp, "LINE1:in#00EE00");
	push(@tmpz, "AREA:in#44EE44:Input");
	push(@tmpz, "AREA:out#4444EE:Output");
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
	RRDs::graph("$PNG_DIR" . "$PNG9",
		"--title=$rgraphs{_squid9}  ($nwhen$twhen)",
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
		"DEF:in=$SQUID_RRD:squid_ts_1:AVERAGE",
		"DEF:out=$SQUID_RRD:squid_ts_2:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG9: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG9z",
			"--title=$rgraphs{_squid9}  ($nwhen$twhen)",
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
			"DEF:in=$SQUID_RRD:squid_ts_1:AVERAGE",
			"DEF:out=$SQUID_RRD:squid_ts_2:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG9z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid9/)) {
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

# NFSS graph
# ----------------------------------------------------------------------------
sub nfss {
	my ($myself, $title) = @_;

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

	my @nfsv;
	if($NFSS_VERSION eq "2") {
		@nfsv = @nfsv2;
	} elsif($NFSS_VERSION eq "4") {
		@nfsv = @nfsv4;
	} else {
		@nfsv = @nfsv3;
	}

	$title = !$silent ? $title : "";
	$title =~ s/NFS/NFS v$NFSS_VERSION/;

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

# NFSC graph
# ----------------------------------------------------------------------------
sub nfsc {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @tmp;
	my @tmpz;
	my @tmp1;
	my @tmp2;
	my @tmp1z;
	my @tmp2z;
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

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG4 = $u . $myself . "4." . $when . ".png";
	my $PNG5 = $u . $myself . "5." . $when . ".png";
	my $PNG6 = $u . $myself . "6." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";
	my $PNG4z = $u . $myself . "4z." . $when . ".png";
	my $PNG5z = $u . $myself . "5z." . $when . ".png";
	my $PNG6z = $u . $myself . "6z." . $when . ".png";

	my @nfsv;
	if($NFSC_VERSION eq "2") {
		@nfsv = @nfsv2;
	} elsif($NFSC_VERSION eq "4") {
		@nfsv = @nfsv4;
	} else {
		@nfsv = @nfsv3;
	}

	$title = !$silent ? $title : "";
	$title =~ s/NFS/NFS v$NFSC_VERSION/;

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3",
		"$PNG_DIR" . "$PNG4",
		"$PNG_DIR" . "$PNG5",
		"$PNG_DIR" . "$PNG6");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z",
			"$PNG_DIR" . "$PNG4z",
			"$PNG_DIR" . "$PNG5z",
			"$PNG_DIR" . "$PNG6z");
	}

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$NFSC_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $NFSC_RRD: $err\n") if $err;
		my $str;
		my $line1;
		my $line2;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
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

	if($title) {
		graph_header($title, 2);
	}
	if($NFSC1_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSC1_LIMIT");
	} else {
		if($NFSC1_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSC1_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	if($title) {
		print("    <tr>\n");
		print("    <td valign='top' bgcolor='$title_bg_color'>\n");
	}
	for($n = 0; $n < 10; $n++) {
		if(grep {$_ eq $NFSC_GRAPH_1[$n]} @nfsv) {
			($i) = grep { $nfsv[$_] eq $NFSC_GRAPH_1[$n] } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$NFSC_RRD:nfsc_$i:AVERAGE");
			push(@tmp, "LINE1:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSC_GRAPH_1[$n]));
			push(@tmp, "GPRINT:nfs_$i:LAST:    Cur\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:AVERAGE:    Avg\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MIN:    Min\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MAX:    Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSC_GRAPH_1[$n]));
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
		"--title=$rgraphs{_nfsc1}  ($nwhen$twhen)",
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
			"--title=$rgraphs{_nfsc1}  ($nwhen$twhen)",
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
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc1/)) {
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
	if($NFSC2_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSC2_LIMIT");
	} else {
		if($NFSC2_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSC2_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	undef(@DEF);
	for($n = 0; $n < 10; $n++) {
		if(grep {$_ eq $NFSC_GRAPH_2[$n]} @nfsv) {
			($i) = grep { $nfsv[$_] eq $NFSC_GRAPH_2[$n] } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$NFSC_RRD:nfsc_$i:AVERAGE");
			push(@tmp, "LINE1:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSC_GRAPH_2[$n]));
			push(@tmp, "GPRINT:nfs_$i:LAST:    Cur\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:AVERAGE:    Avg\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MIN:    Min\\: %6.1lf");
			push(@tmp, "GPRINT:nfs_$i:MAX:    Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSC_GRAPH_2[$n]));
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
		"--title=$rgraphs{_nfsc2}  ($nwhen$twhen)",
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
			"--title=$rgraphs{_nfsc2}  ($nwhen$twhen)",
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
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc2/)) {
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
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
	}

	undef(@riglim);
	if($NFSC3_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSC3_LIMIT");
	} else {
		if($NFSC3_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSC3_LIMIT");
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
	for($n = 0; $n < 4; $n++) {
		if(grep {$_ eq $NFSC_GRAPH_3[$n]} @nfsv) {
			($i) = grep { $nfsv[$_] eq $NFSC_GRAPH_3[$n] } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$NFSC_RRD:nfsc_$i:AVERAGE");
			push(@tmp1, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSC_GRAPH_3[$n]));
			push(@tmp1, "GPRINT:nfs_$i:LAST:         Current\\: %6.1lf\\n");
			push(@tmp2, "LINE1:nfs_$i$LC[$n]");
			push(@tmp1z, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSC_GRAPH_3[$n]));
			push(@tmp2z, "LINE1:nfs_$i$LC[$n]");
		} else {
			push(@tmp1, "COMMENT: \\n");
		}
	}
	@tmp = (@tmp1, @tmp2);
	@tmpz = (@tmp1z, @tmp2z);
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$rgraphs{_nfsc3}  ($nwhen$twhen)",
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
		@DEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$rgraphs{_nfsc3}  ($nwhen$twhen)",
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
			@DEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc3/)) {
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

	undef(@riglim);
	if($NFSC4_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSC4_LIMIT");
	} else {
		if($NFSC4_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSC4_LIMIT");
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
	for($n = 0; $n < 4; $n++) {
		if(grep {$_ eq $NFSC_GRAPH_4[$n]} @nfsv) {
			($i) = grep { $nfsv[$_] eq $NFSC_GRAPH_4[$n] } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$NFSC_RRD:nfsc_$i:AVERAGE");
			push(@tmp1, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSC_GRAPH_4[$n]));
			push(@tmp1, "GPRINT:nfs_$i:LAST:         Current\\: %6.1lf\\n");
			push(@tmp2, "LINE1:nfs_$i$LC[$n]");
			push(@tmp1z, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSC_GRAPH_4[$n]));
			push(@tmp2z, "LINE1:nfs_$i$LC[$n]");
		} else {
			push(@tmp1, "COMMENT: \\n");
		}
	}
	@tmp = (@tmp1, @tmp2);
	@tmpz = (@tmp1z, @tmp2z);
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
		"--title=$rgraphs{_nfsc4}  ($nwhen$twhen)",
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
		@DEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG4: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG4z",
			"--title=$rgraphs{_nfsc4}  ($nwhen$twhen)",
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
			@DEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc4/)) {
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
	if($NFSC5_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSC5_LIMIT");
	} else {
		if($NFSC5_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSC5_LIMIT");
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
	for($n = 0; $n < 4; $n++) {
		if(grep {$_ eq $NFSC_GRAPH_5[$n]} @nfsv) {
			($i) = grep { $nfsv[$_] eq $NFSC_GRAPH_5[$n] } 0..$#nfsv;
			push(@DEF, "DEF:nfs_$i=$NFSC_RRD:nfsc_$i:AVERAGE");
			push(@tmp1, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSC_GRAPH_5[$n]));
			push(@tmp1, "GPRINT:nfs_$i:LAST:         Current\\: %6.1lf\\n");
			push(@tmp2, "LINE1:nfs_$i$LC[$n]");
			push(@tmp1z, "AREA:nfs_$i$AC[$n]:" . sprintf("%-12s", $NFSC_GRAPH_5[$n]));
			push(@tmp2z, "LINE1:nfs_$i$LC[$n]");
		} else {
			push(@tmp1, "COMMENT: \\n");
		}
	}
	@tmp = (@tmp1, @tmp2);
	@tmpz = (@tmp1z, @tmp2z);
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
		"--title=$rgraphs{_nfsc5}  ($nwhen$twhen)",
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
		@DEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG5: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG5z",
			"--title=$rgraphs{_nfsc5}  ($nwhen$twhen)",
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
			@DEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc5/)) {
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
	if($NFSC6_RIGID eq 1) {
		push(@riglim, "--upper-limit=$NFSC6_LIMIT");
	} else {
		if($NFSC6_RIGID eq 2) {
			push(@riglim, "--upper-limit=$NFSC6_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
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
		"--title=$rgraphs{_nfsc6}  ($nwhen$twhen)",
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
		"DEF:calls=$NFSC_RRD:nfsc_rpc_1:AVERAGE",
		"DEF:retrans=$NFSC_RRD:nfsc_rpc_2:AVERAGE",
		"DEF:authref=$NFSC_RRD:nfsc_rpc_3:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG6: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG6z",
			"--title=$rgraphs{_nfsc6}  ($nwhen$twhen)",
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
			"DEF:calls=$NFSC_RRD:nfsc_rpc_1:AVERAGE",
			"DEF:retrans=$NFSC_RRD:nfsc_rpc_2:AVERAGE",
			"DEF:authref=$NFSC_RRD:nfsc_rpc_3:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG6z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /nfsc6/)) {
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

	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

# BIND graph
# ----------------------------------------------------------------------------
sub bind {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my $e;
	my $n;
	my $str;
	my $err;
	my @LC = (
		"#FFA500",
		"#4444EE",
		"#EEEE44",
		"#44EEEE",
		"#EE44EE",
		"#888888",
		"#5F04B4",
		"#44EE44",
		"#448844",
		"#EE4444",
		"#444444",
		"#E29136",
		"#CCCCCC",
		"#AEB404",
		"#8A2908",
		"#8C7000",
		"#DDAE8C",
		"#037C8C",
		"#48D4D4",
		"#9048D4",
	);

	if($IFACE_MODE eq "text") {
		my $line0;
		my $line1;
		my $line2;
		my $line3;
		my $n2;
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$BIND_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $BIND_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("    ");
		$line0 = "                                                                                                                                                $rgraphs{_bind1}                                                                                                                                                $rgraphs{_bind2}                                                                                                                                                                                                                                                                                                          $rgraphs{_bind3}                                                                                                                                                                                                                                                                                                  $rgraphs{_bind4}                                                                                                                                      $rgraphs{_bind5}                                           $rgraphs{_bind6}                     $rgraphs{_bind7}";
		for($n = 0; $n < scalar(@BIND_URL_LIST); $n++) {
			$line1 .= $line0;
			$line3 .= "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
			$n2 = 0;
			foreach my $i (@BIND_IN_QUERIES_LIST[$n]) {
				foreach(@$i) {
					$str = sprintf("%7s", substr($_, 0, 7));
					$line2 .= sprintf(" %7s", $str);
					$n2++;
				}
			}
			for(; $n2 < 20; $n2++) {
				$str = sprintf("%7s", substr($_, 0, 7));
				$line2 .= sprintf(" %7s", $str);
			}

			$n2 = 0;
			foreach my $i (@BIND_OUT_QUERIES_LIST[$n]) {
				foreach(@$i) {
					$str = sprintf("%7s", substr($_, 0, 7));
					$line2 .= sprintf(" %7s", $str);
					$n2++;
				}
			}
			for(; $n2 < 20; $n2++) {
				$str = sprintf("%7s", substr($_, 0, 7));
				$line2 .= sprintf(" %7s", $str);
			}

			$n2 = 0;
			foreach my $i (@BIND_SERVER_STATS_LIST[$n]) {
				foreach(@$i) {
					$str = sprintf("%15s", substr($_, 0, 15));
					$line2 .= sprintf(" %15s", $str);
					$n2++;
				}
			}
			for(; $n2 < 20; $n2++) {
				$str = sprintf("%15s", substr($_, 0, 15));
				$line2 .= sprintf(" %15s", $str);
			}

			$n2 = 0;
			foreach my $i (@BIND_RESOLVER_STATS_LIST[$n]) {
				foreach(@$i) {
					$str = sprintf("%15s", substr($_, 0, 15));
					$line2 .= sprintf(" %15s", $str);
					$n2++;
				}
			}
			for(; $n2 < 20; $n2++) {
				$str = sprintf("%15s", substr($_, 0, 15));
				$line2 .= sprintf(" %15s", $str);
			}

			$n2 = 0;
			foreach my $i (@BIND_CACHE_RRSETS_LIST[$n]) {
				foreach(@$i) {
					$str = sprintf("%7s", substr($_, 0, 7));
					$line2 .= sprintf(" %7s", $str);
					$n2++;
				}
			}
			for(; $n2 < 20; $n2++) {
				$str = sprintf("%7s", substr($_, 0, 7));
				$line2 .= sprintf(" %7s", $str);
			}

			foreach ("TotalUse", "InUse", "BlockSize", "ContxtSize", "Lost") {
				$str = sprintf("%10s", substr($_, 0, 10));
				$line2 .= sprintf(" %10s", $str);
			}

			foreach ("WorkerThds", "DefQuantum", "TasksRunng") {
				$str = sprintf("%10s", substr($_, 0, 10));
				$line2 .= sprintf(" %10s", $str);
			}

			$i = length($line0);
			printf(sprintf("%${i}s", sprintf("BIND server: %s", $BIND_URL_LIST[$n])));
		}
		print("\n");
		print("    $line1\n");
		print("Time$line2 \n");
		print("----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			$from = 1;
			printf(" %2d$tc ", $time);
			for($n2 = 0; $n2 < scalar(@BIND_URL_LIST); $n2++) {
				# inq
				$from += $n2 * 95;
				$to = $from + 20;
				@row = @$line[$from..$to];
				printf("%7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row);
				# ouq
				$from = $to;
				$to = $from + 20;
				@row = @$line[$from..$to];
				printf("%7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row);
				# ss
				$from = $to;
				$to = $from + 20;
				@row = @$line[$from..$to];
				printf("%15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d ", @row);
				# rs
				$from = $to;
				$to = $from + 20;
				@row = @$line[$from..$to];
				printf("%15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d ", @row);
				# crr
				$from = $to;
				$to = $from + 20;
				@row = @$line[$from..$to];
				printf("%7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row);
				# mem
				$from = $to;
				$to = $from + 8;
				@row = @$line[$from..$to];
				printf("%10d %10d %10d %10d %10d ", @row);
				# tsk
				$from = $to;
				$to = $from + 6;
				@row = @$line[$from..$to];
				printf("%10d %10d %10d ", @row);
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	for($n = 0; $n < scalar(@BIND_URL_LIST); $n++) {
		for($n2 = 1; $n2 <= 7; $n2++) {
			$str = $u . $myself . $n . $n2 . "." . $when . ".png";
			push(@PNG, $str);
			unlink("$PNG_DIR" . $str);
			if($ENABLE_ZOOM eq "Y") {
				$str = $u . $myself . $n . $n2 . "z." . $when . ".png";
				push(@PNGz, $str);
				unlink("$PNG_DIR" . $str);
			}
		}
	}

	$e = 0;
	foreach my $host (@BIND_URL_LIST) {
		if($e) {
			print("   <br>\n");
		}
		if($title) {
			graph_header($title, 2);
		}
		undef(@riglim);
		if($BIND1_RIGID eq 1) {
			push(@riglim, "--upper-limit=$BIND1_LIMIT");
		} else {
			if($BIND1_RIGID eq 2) {
				push(@riglim, "--upper-limit=$BIND1_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		my $i = $BIND_IN_QUERIES_LIST[$e];
		for($n = 0; $n < scalar(@$i); $n += 2) {
			$str = sprintf("%-8s", substr(@$i[$n], 0, 8));
			push(@tmp, "LINE1:inq" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:inq" . $n . ":LAST: Current\\:%5.1lf       ");
			push(@tmpz, "LINE2:inq" . $n . $LC[$n] . ":$str");
			$str = sprintf("%-8s", substr(@$i[$n + 1], 0, 8));
			push(@tmp, "LINE1:inq" . ($n + 1) . $LC[$n + 1] . ":$str");
			push(@tmp, "GPRINT:inq" . ($n + 1) . ":LAST: Current\\:%5.1lf\\n");
			push(@tmpz, "LINE2:inq" . ($n + 1) . $LC[$n + 1] . ":$str");
		}
		for(; $n < 20; $n += 2) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='" . $title_bg_color . "'>\n");
		}
		($width, $height) = split('x', $GRAPH_SIZE{medium});
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 7]",
			"--title=$rgraphs{_bind1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Queries/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:inq0=$BIND_RRD:bind" . $e . "_inq01:AVERAGE",
			"DEF:inq1=$BIND_RRD:bind" . $e . "_inq02:AVERAGE",
			"DEF:inq2=$BIND_RRD:bind" . $e . "_inq03:AVERAGE",
			"DEF:inq3=$BIND_RRD:bind" . $e . "_inq04:AVERAGE",
			"DEF:inq4=$BIND_RRD:bind" . $e . "_inq05:AVERAGE",
			"DEF:inq5=$BIND_RRD:bind" . $e . "_inq06:AVERAGE",
			"DEF:inq6=$BIND_RRD:bind" . $e . "_inq07:AVERAGE",
			"DEF:inq7=$BIND_RRD:bind" . $e . "_inq08:AVERAGE",
			"DEF:inq8=$BIND_RRD:bind" . $e . "_inq09:AVERAGE",
			"DEF:inq9=$BIND_RRD:bind" . $e . "_inq10:AVERAGE",
			"DEF:inq10=$BIND_RRD:bind" . $e . "_inq11:AVERAGE",
			"DEF:inq11=$BIND_RRD:bind" . $e . "_inq12:AVERAGE",
			"DEF:inq12=$BIND_RRD:bind" . $e . "_inq13:AVERAGE",
			"DEF:inq13=$BIND_RRD:bind" . $e . "_inq14:AVERAGE",
			"DEF:inq14=$BIND_RRD:bind" . $e . "_inq15:AVERAGE",
			"DEF:inq15=$BIND_RRD:bind" . $e . "_inq16:AVERAGE",
			"DEF:inq16=$BIND_RRD:bind" . $e . "_inq17:AVERAGE",
			"DEF:inq17=$BIND_RRD:bind" . $e . "_inq18:AVERAGE",
			"DEF:inq18=$BIND_RRD:bind" . $e . "_inq19:AVERAGE",
			"DEF:inq19=$BIND_RRD:bind" . $e . "_inq20:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 7]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 7]",
				"--title=$rgraphs{_bind1}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Queries/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:inq0=$BIND_RRD:bind" . $e . "_inq01:AVERAGE",
				"DEF:inq1=$BIND_RRD:bind" . $e . "_inq02:AVERAGE",
				"DEF:inq2=$BIND_RRD:bind" . $e . "_inq03:AVERAGE",
				"DEF:inq3=$BIND_RRD:bind" . $e . "_inq04:AVERAGE",
				"DEF:inq4=$BIND_RRD:bind" . $e . "_inq05:AVERAGE",
				"DEF:inq5=$BIND_RRD:bind" . $e . "_inq06:AVERAGE",
				"DEF:inq6=$BIND_RRD:bind" . $e . "_inq07:AVERAGE",
				"DEF:inq7=$BIND_RRD:bind" . $e . "_inq08:AVERAGE",
				"DEF:inq8=$BIND_RRD:bind" . $e . "_inq09:AVERAGE",
				"DEF:inq9=$BIND_RRD:bind" . $e . "_inq10:AVERAGE",
				"DEF:inq10=$BIND_RRD:bind" . $e . "_inq11:AVERAGE",
				"DEF:inq11=$BIND_RRD:bind" . $e . "_inq12:AVERAGE",
				"DEF:inq12=$BIND_RRD:bind" . $e . "_inq13:AVERAGE",
				"DEF:inq13=$BIND_RRD:bind" . $e . "_inq14:AVERAGE",
				"DEF:inq14=$BIND_RRD:bind" . $e . "_inq15:AVERAGE",
				"DEF:inq15=$BIND_RRD:bind" . $e . "_inq16:AVERAGE",
				"DEF:inq16=$BIND_RRD:bind" . $e . "_inq17:AVERAGE",
				"DEF:inq17=$BIND_RRD:bind" . $e . "_inq18:AVERAGE",
				"DEF:inq18=$BIND_RRD:bind" . $e . "_inq19:AVERAGE",
				"DEF:inq19=$BIND_RRD:bind" . $e . "_inq20:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 7]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind1/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 7] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 7] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 7] . "'>\n");
			}
		}
		if($title) {
			print("    </td>\n");
		}

		undef(@riglim);
		if($BIND2_RIGID eq 1) {
			push(@riglim, "--upper-limit=$BIND2_LIMIT");
		} else {
			if($BIND2_RIGID eq 2) {
				push(@riglim, "--upper-limit=$BIND2_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		$i = $BIND_OUT_QUERIES_LIST[$e];
		for($n = 0; $n < scalar(@$i); $n += 2) {
			$str = sprintf("%-8s", substr(@$i[$n], 0, 8));
			push(@tmp, "LINE1:ouq" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:ouq" . $n . ":LAST: Current\\:%5.1lf       ");
			push(@tmpz, "LINE2:ouq" . $n . $LC[$n] . ":$str");
			$str = sprintf("%-8s", substr(@$i[$n + 1], 0, 8));
			push(@tmp, "LINE1:ouq" . ($n + 1) . $LC[$n + 1] . ":$str");
			push(@tmp, "GPRINT:ouq" . ($n + 1) . ":LAST: Current\\:%5.1lf\\n");
			push(@tmpz, "LINE2:ouq" . ($n + 1) . $LC[$n + 1] . ":$str");
		}
		for(; $n < 20; $n += 2) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			print("    <td bgcolor='" . $title_bg_color . "'>\n");
		}
		($width, $height) = split('x', $GRAPH_SIZE{medium});
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 7 + 1]",
			"--title=$rgraphs{_bind2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Queries/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:ouq0=$BIND_RRD:bind" . $e . "_ouq01:AVERAGE",
			"DEF:ouq1=$BIND_RRD:bind" . $e . "_ouq02:AVERAGE",
			"DEF:ouq2=$BIND_RRD:bind" . $e . "_ouq03:AVERAGE",
			"DEF:ouq3=$BIND_RRD:bind" . $e . "_ouq04:AVERAGE",
			"DEF:ouq4=$BIND_RRD:bind" . $e . "_ouq05:AVERAGE",
			"DEF:ouq5=$BIND_RRD:bind" . $e . "_ouq06:AVERAGE",
			"DEF:ouq6=$BIND_RRD:bind" . $e . "_ouq07:AVERAGE",
			"DEF:ouq7=$BIND_RRD:bind" . $e . "_ouq08:AVERAGE",
			"DEF:ouq8=$BIND_RRD:bind" . $e . "_ouq09:AVERAGE",
			"DEF:ouq9=$BIND_RRD:bind" . $e . "_ouq10:AVERAGE",
			"DEF:ouq10=$BIND_RRD:bind" . $e . "_ouq11:AVERAGE",
			"DEF:ouq11=$BIND_RRD:bind" . $e . "_ouq12:AVERAGE",
			"DEF:ouq12=$BIND_RRD:bind" . $e . "_ouq13:AVERAGE",
			"DEF:ouq13=$BIND_RRD:bind" . $e . "_ouq14:AVERAGE",
			"DEF:ouq14=$BIND_RRD:bind" . $e . "_ouq15:AVERAGE",
			"DEF:ouq15=$BIND_RRD:bind" . $e . "_ouq16:AVERAGE",
			"DEF:ouq16=$BIND_RRD:bind" . $e . "_ouq17:AVERAGE",
			"DEF:ouq17=$BIND_RRD:bind" . $e . "_ouq18:AVERAGE",
			"DEF:ouq18=$BIND_RRD:bind" . $e . "_ouq19:AVERAGE",
			"DEF:ouq19=$BIND_RRD:bind" . $e . "_ouq20:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 7 + 1]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 7 + 1]",
				"--title=$rgraphs{_bind2}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Queries/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:ouq0=$BIND_RRD:bind" . $e . "_ouq01:AVERAGE",
				"DEF:ouq1=$BIND_RRD:bind" . $e . "_ouq02:AVERAGE",
				"DEF:ouq2=$BIND_RRD:bind" . $e . "_ouq03:AVERAGE",
				"DEF:ouq3=$BIND_RRD:bind" . $e . "_ouq04:AVERAGE",
				"DEF:ouq4=$BIND_RRD:bind" . $e . "_ouq05:AVERAGE",
				"DEF:ouq5=$BIND_RRD:bind" . $e . "_ouq06:AVERAGE",
				"DEF:ouq6=$BIND_RRD:bind" . $e . "_ouq07:AVERAGE",
				"DEF:ouq7=$BIND_RRD:bind" . $e . "_ouq08:AVERAGE",
				"DEF:ouq8=$BIND_RRD:bind" . $e . "_ouq09:AVERAGE",
				"DEF:ouq9=$BIND_RRD:bind" . $e . "_ouq10:AVERAGE",
				"DEF:ouq10=$BIND_RRD:bind" . $e . "_ouq11:AVERAGE",
				"DEF:ouq11=$BIND_RRD:bind" . $e . "_ouq12:AVERAGE",
				"DEF:ouq12=$BIND_RRD:bind" . $e . "_ouq13:AVERAGE",
				"DEF:ouq13=$BIND_RRD:bind" . $e . "_ouq14:AVERAGE",
				"DEF:ouq14=$BIND_RRD:bind" . $e . "_ouq15:AVERAGE",
				"DEF:ouq15=$BIND_RRD:bind" . $e . "_ouq16:AVERAGE",
				"DEF:ouq16=$BIND_RRD:bind" . $e . "_ouq17:AVERAGE",
				"DEF:ouq17=$BIND_RRD:bind" . $e . "_ouq18:AVERAGE",
				"DEF:ouq18=$BIND_RRD:bind" . $e . "_ouq19:AVERAGE",
				"DEF:ouq19=$BIND_RRD:bind" . $e . "_ouq20:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 7 + 1]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 1] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 1] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 1] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 1] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 1] . "'>\n");
			}
		}

		undef(@riglim);
		if($BIND3_RIGID eq 1) {
			push(@riglim, "--upper-limit=$BIND3_LIMIT");
		} else {
			if($BIND3_RIGID eq 2) {
				push(@riglim, "--upper-limit=$BIND3_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		$i = $BIND_SERVER_STATS_LIST[$e];
		for($n = 0; $n < scalar(@$i); $n += 2) {
			$str = sprintf("%-14s", substr(@$i[$n], 0, 14));
			push(@tmp, "LINE1:ss" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:ss" . $n . ":LAST:Cur\\:%5.1lf     ");
			push(@tmpz, "LINE2:ss" . $n . $LC[$n] . ":$str");
			$str = sprintf("%-14s", substr(@$i[$n + 1], 0, 14));
			push(@tmp, "LINE1:ss" . ($n + 1) . $LC[$n + 1] . ":$str");
			push(@tmp, "GPRINT:ss" . ($n + 1) . ":LAST:Cur\\:%5.1lf\\n");
			push(@tmpz, "LINE2:ss" . ($n + 1) . $LC[$n + 1] . ":$str");
		}
		for(; $n < 20; $n += 2) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='" . $title_bg_color . "'>\n");
		}
		($width, $height) = split('x', $GRAPH_SIZE{medium});
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 7 + 2]",
			"--title=$rgraphs{_bind3}  ($nwhen$twhen)",
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
			"DEF:ss0=$BIND_RRD:bind" . $e . "_ss01:AVERAGE",
			"DEF:ss1=$BIND_RRD:bind" . $e . "_ss02:AVERAGE",
			"DEF:ss2=$BIND_RRD:bind" . $e . "_ss03:AVERAGE",
			"DEF:ss3=$BIND_RRD:bind" . $e . "_ss04:AVERAGE",
			"DEF:ss4=$BIND_RRD:bind" . $e . "_ss05:AVERAGE",
			"DEF:ss5=$BIND_RRD:bind" . $e . "_ss06:AVERAGE",
			"DEF:ss6=$BIND_RRD:bind" . $e . "_ss07:AVERAGE",
			"DEF:ss7=$BIND_RRD:bind" . $e . "_ss08:AVERAGE",
			"DEF:ss8=$BIND_RRD:bind" . $e . "_ss09:AVERAGE",
			"DEF:ss9=$BIND_RRD:bind" . $e . "_ss10:AVERAGE",
			"DEF:ss10=$BIND_RRD:bind" . $e . "_ss11:AVERAGE",
			"DEF:ss11=$BIND_RRD:bind" . $e . "_ss12:AVERAGE",
			"DEF:ss12=$BIND_RRD:bind" . $e . "_ss13:AVERAGE",
			"DEF:ss13=$BIND_RRD:bind" . $e . "_ss14:AVERAGE",
			"DEF:ss14=$BIND_RRD:bind" . $e . "_ss15:AVERAGE",
			"DEF:ss15=$BIND_RRD:bind" . $e . "_ss16:AVERAGE",
			"DEF:ss16=$BIND_RRD:bind" . $e . "_ss17:AVERAGE",
			"DEF:ss17=$BIND_RRD:bind" . $e . "_ss18:AVERAGE",
			"DEF:ss18=$BIND_RRD:bind" . $e . "_ss19:AVERAGE",
			"DEF:ss19=$BIND_RRD:bind" . $e . "_ss20:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 7 + 2]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 7 + 2]",
				"--title=$rgraphs{_bind3}  ($nwhen$twhen)",
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
				"DEF:ss0=$BIND_RRD:bind" . $e . "_ss01:AVERAGE",
				"DEF:ss1=$BIND_RRD:bind" . $e . "_ss02:AVERAGE",
				"DEF:ss2=$BIND_RRD:bind" . $e . "_ss03:AVERAGE",
				"DEF:ss3=$BIND_RRD:bind" . $e . "_ss04:AVERAGE",
				"DEF:ss4=$BIND_RRD:bind" . $e . "_ss05:AVERAGE",
				"DEF:ss5=$BIND_RRD:bind" . $e . "_ss06:AVERAGE",
				"DEF:ss6=$BIND_RRD:bind" . $e . "_ss07:AVERAGE",
				"DEF:ss7=$BIND_RRD:bind" . $e . "_ss08:AVERAGE",
				"DEF:ss8=$BIND_RRD:bind" . $e . "_ss09:AVERAGE",
				"DEF:ss9=$BIND_RRD:bind" . $e . "_ss10:AVERAGE",
				"DEF:ss10=$BIND_RRD:bind" . $e . "_ss11:AVERAGE",
				"DEF:ss11=$BIND_RRD:bind" . $e . "_ss12:AVERAGE",
				"DEF:ss12=$BIND_RRD:bind" . $e . "_ss13:AVERAGE",
				"DEF:ss13=$BIND_RRD:bind" . $e . "_ss14:AVERAGE",
				"DEF:ss14=$BIND_RRD:bind" . $e . "_ss15:AVERAGE",
				"DEF:ss15=$BIND_RRD:bind" . $e . "_ss16:AVERAGE",
				"DEF:ss16=$BIND_RRD:bind" . $e . "_ss17:AVERAGE",
				"DEF:ss17=$BIND_RRD:bind" . $e . "_ss18:AVERAGE",
				"DEF:ss18=$BIND_RRD:bind" . $e . "_ss19:AVERAGE",
				"DEF:ss19=$BIND_RRD:bind" . $e . "_ss20:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 7 + 2]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind3/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 2] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 2] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 2] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 2] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 2] . "'>\n");
			}
		}
		if($title) {
			print("    </td>\n");
		}

		undef(@riglim);
		if($BIND4_RIGID eq 1) {
			push(@riglim, "--upper-limit=$BIND4_LIMIT");
		} else {
			if($BIND4_RIGID eq 2) {
				push(@riglim, "--upper-limit=$BIND4_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		$i = $BIND_RESOLVER_STATS_LIST[$e];
		for($n = 0; $n < scalar(@$i); $n += 2) {
			$str = sprintf("%-14s", substr(@$i[$n], 0, 14));
			push(@tmp, "LINE1:rs" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:rs" . $n . ":LAST:Cur\\:%5.1lf     ");
			push(@tmpz, "LINE2:rs" . $n . $LC[$n] . ":$str");
			$str = sprintf("%-14s", substr(@$i[$n + 1], 0, 14));
			push(@tmp, "LINE1:rs" . ($n + 1) . $LC[$n + 1] . ":$str");
			push(@tmp, "GPRINT:rs" . ($n + 1) . ":LAST:Cur\\:%5.1lf\\n");
			push(@tmpz, "LINE2:rs" . ($n + 1) . $LC[$n + 1] . ":$str");
		}
		for(; $n < 20; $n += 2) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			print("    <td bgcolor='" . $title_bg_color . "'>\n");
		}
		($width, $height) = split('x', $GRAPH_SIZE{medium});
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 7 + 3]",
			"--title=$rgraphs{_bind4}  ($nwhen$twhen)",
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
			"DEF:rs0=$BIND_RRD:bind" . $e . "_rs01:AVERAGE",
			"DEF:rs1=$BIND_RRD:bind" . $e . "_rs02:AVERAGE",
			"DEF:rs2=$BIND_RRD:bind" . $e . "_rs03:AVERAGE",
			"DEF:rs3=$BIND_RRD:bind" . $e . "_rs04:AVERAGE",
			"DEF:rs4=$BIND_RRD:bind" . $e . "_rs05:AVERAGE",
			"DEF:rs5=$BIND_RRD:bind" . $e . "_rs06:AVERAGE",
			"DEF:rs6=$BIND_RRD:bind" . $e . "_rs07:AVERAGE",
			"DEF:rs7=$BIND_RRD:bind" . $e . "_rs08:AVERAGE",
			"DEF:rs8=$BIND_RRD:bind" . $e . "_rs09:AVERAGE",
			"DEF:rs9=$BIND_RRD:bind" . $e . "_rs10:AVERAGE",
			"DEF:rs10=$BIND_RRD:bind" . $e . "_rs11:AVERAGE",
			"DEF:rs11=$BIND_RRD:bind" . $e . "_rs12:AVERAGE",
			"DEF:rs12=$BIND_RRD:bind" . $e . "_rs13:AVERAGE",
			"DEF:rs13=$BIND_RRD:bind" . $e . "_rs14:AVERAGE",
			"DEF:rs14=$BIND_RRD:bind" . $e . "_rs15:AVERAGE",
			"DEF:rs15=$BIND_RRD:bind" . $e . "_rs16:AVERAGE",
			"DEF:rs16=$BIND_RRD:bind" . $e . "_rs17:AVERAGE",
			"DEF:rs17=$BIND_RRD:bind" . $e . "_rs18:AVERAGE",
			"DEF:rs18=$BIND_RRD:bind" . $e . "_rs19:AVERAGE",
			"DEF:rs19=$BIND_RRD:bind" . $e . "_rs20:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 7 + 3]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 7 + 3]",
				"--title=$rgraphs{_bind4}  ($nwhen$twhen)",
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
				"DEF:rs0=$BIND_RRD:bind" . $e . "_rs01:AVERAGE",
				"DEF:rs1=$BIND_RRD:bind" . $e . "_rs02:AVERAGE",
				"DEF:rs2=$BIND_RRD:bind" . $e . "_rs03:AVERAGE",
				"DEF:rs3=$BIND_RRD:bind" . $e . "_rs04:AVERAGE",
				"DEF:rs4=$BIND_RRD:bind" . $e . "_rs05:AVERAGE",
				"DEF:rs5=$BIND_RRD:bind" . $e . "_rs06:AVERAGE",
				"DEF:rs6=$BIND_RRD:bind" . $e . "_rs07:AVERAGE",
				"DEF:rs7=$BIND_RRD:bind" . $e . "_rs08:AVERAGE",
				"DEF:rs8=$BIND_RRD:bind" . $e . "_rs09:AVERAGE",
				"DEF:rs9=$BIND_RRD:bind" . $e . "_rs10:AVERAGE",
				"DEF:rs10=$BIND_RRD:bind" . $e . "_rs11:AVERAGE",
				"DEF:rs11=$BIND_RRD:bind" . $e . "_rs12:AVERAGE",
				"DEF:rs12=$BIND_RRD:bind" . $e . "_rs13:AVERAGE",
				"DEF:rs13=$BIND_RRD:bind" . $e . "_rs14:AVERAGE",
				"DEF:rs14=$BIND_RRD:bind" . $e . "_rs15:AVERAGE",
				"DEF:rs15=$BIND_RRD:bind" . $e . "_rs16:AVERAGE",
				"DEF:rs16=$BIND_RRD:bind" . $e . "_rs17:AVERAGE",
				"DEF:rs17=$BIND_RRD:bind" . $e . "_rs18:AVERAGE",
				"DEF:rs18=$BIND_RRD:bind" . $e . "_rs19:AVERAGE",
				"DEF:rs19=$BIND_RRD:bind" . $e . "_rs20:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 7 + 3]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind4/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 3] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 3] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 3] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 3] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 3] . "'>\n");
			}
		}

		undef(@riglim);
		if($BIND5_RIGID eq 1) {
			push(@riglim, "--upper-limit=$BIND5_LIMIT");
		} else {
			if($BIND5_RIGID eq 2) {
				push(@riglim, "--upper-limit=$BIND5_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		$i = $BIND_CACHE_RRSETS_LIST[$e];
		for($n = 0; $n < scalar(@$i); $n += 2) {
			$str = sprintf("%-8s", substr(@$i[$n], 0, 8));
			push(@tmp, "LINE1:crr" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:crr" . $n . ":LAST:  Cur\\:%8.1lf       ");
			push(@tmpz, "LINE2:crr" . $n . $LC[$n] . ":$str");
			$str = sprintf("%-8s", substr(@$i[$n + 1], 0, 8));
			push(@tmp, "LINE1:crr" . ($n + 1) . $LC[$n + 1] . ":$str");
			push(@tmp, "GPRINT:crr" . ($n + 1) . ":LAST: Cur\\:%8.1lf\\n");
			push(@tmpz, "LINE2:crr" . ($n + 1) . $LC[$n + 1] . ":$str");
		}
		for(; $n < 20; $n += 2) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='" . $title_bg_color . "'>\n");
		}
		($width, $height) = split('x', $GRAPH_SIZE{medium});
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 7 + 4]",
			"--title=$rgraphs{_bind5}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=RRsets",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:crr0=$BIND_RRD:bind" . $e . "_crr01:AVERAGE",
			"DEF:crr1=$BIND_RRD:bind" . $e . "_crr02:AVERAGE",
			"DEF:crr2=$BIND_RRD:bind" . $e . "_crr03:AVERAGE",
			"DEF:crr3=$BIND_RRD:bind" . $e . "_crr04:AVERAGE",
			"DEF:crr4=$BIND_RRD:bind" . $e . "_crr05:AVERAGE",
			"DEF:crr5=$BIND_RRD:bind" . $e . "_crr06:AVERAGE",
			"DEF:crr6=$BIND_RRD:bind" . $e . "_crr07:AVERAGE",
			"DEF:crr7=$BIND_RRD:bind" . $e . "_crr08:AVERAGE",
			"DEF:crr8=$BIND_RRD:bind" . $e . "_crr09:AVERAGE",
			"DEF:crr9=$BIND_RRD:bind" . $e . "_crr10:AVERAGE",
			"DEF:crr10=$BIND_RRD:bind" . $e . "_crr11:AVERAGE",
			"DEF:crr11=$BIND_RRD:bind" . $e . "_crr12:AVERAGE",
			"DEF:crr12=$BIND_RRD:bind" . $e . "_crr13:AVERAGE",
			"DEF:crr13=$BIND_RRD:bind" . $e . "_crr14:AVERAGE",
			"DEF:crr14=$BIND_RRD:bind" . $e . "_crr15:AVERAGE",
			"DEF:crr15=$BIND_RRD:bind" . $e . "_crr16:AVERAGE",
			"DEF:crr16=$BIND_RRD:bind" . $e . "_crr17:AVERAGE",
			"DEF:crr17=$BIND_RRD:bind" . $e . "_crr18:AVERAGE",
			"DEF:crr18=$BIND_RRD:bind" . $e . "_crr19:AVERAGE",
			"DEF:crr19=$BIND_RRD:bind" . $e . "_crr20:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 7 + 4]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 7 + 4]",
				"--title=$rgraphs{_bind5}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=RRsets",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:crr0=$BIND_RRD:bind" . $e . "_crr01:AVERAGE",
				"DEF:crr1=$BIND_RRD:bind" . $e . "_crr02:AVERAGE",
				"DEF:crr2=$BIND_RRD:bind" . $e . "_crr03:AVERAGE",
				"DEF:crr3=$BIND_RRD:bind" . $e . "_crr04:AVERAGE",
				"DEF:crr4=$BIND_RRD:bind" . $e . "_crr05:AVERAGE",
				"DEF:crr5=$BIND_RRD:bind" . $e . "_crr06:AVERAGE",
				"DEF:crr6=$BIND_RRD:bind" . $e . "_crr07:AVERAGE",
				"DEF:crr7=$BIND_RRD:bind" . $e . "_crr08:AVERAGE",
				"DEF:crr8=$BIND_RRD:bind" . $e . "_crr09:AVERAGE",
				"DEF:crr9=$BIND_RRD:bind" . $e . "_crr10:AVERAGE",
				"DEF:crr10=$BIND_RRD:bind" . $e . "_crr11:AVERAGE",
				"DEF:crr11=$BIND_RRD:bind" . $e . "_crr12:AVERAGE",
				"DEF:crr12=$BIND_RRD:bind" . $e . "_crr13:AVERAGE",
				"DEF:crr13=$BIND_RRD:bind" . $e . "_crr14:AVERAGE",
				"DEF:crr14=$BIND_RRD:bind" . $e . "_crr15:AVERAGE",
				"DEF:crr15=$BIND_RRD:bind" . $e . "_crr16:AVERAGE",
				"DEF:crr16=$BIND_RRD:bind" . $e . "_crr17:AVERAGE",
				"DEF:crr17=$BIND_RRD:bind" . $e . "_crr18:AVERAGE",
				"DEF:crr18=$BIND_RRD:bind" . $e . "_crr19:AVERAGE",
				"DEF:crr19=$BIND_RRD:bind" . $e . "_crr20:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 7 + 4]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind5/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 4] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 4] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 4] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 4] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 4] . "'>\n");
			}
		}
		if($title) {
			print("    </td>\n");
		}

		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "LINE1:mem_tu#EEEE44:TotalUse");
		push(@tmp, "GPRINT:mem_tu_mb" . ":LAST: Cur\\:%6.1lf MB    ");
		push(@tmpz, "LINE2:mem_tu#EEEE44:TotalUse");
		push(@tmp, "LINE1:mem_iu#4444EE:InUse");
		push(@tmp, "GPRINT:mem_iu_mb" . ":LAST:      Cur\\:%5.1lf MB\\n");
		push(@tmpz, "LINE2:mem_iu#4444EE:InUse");
		push(@tmp, "LINE1:mem_bs#44EEEE:BlockSize");
		push(@tmp, "GPRINT:mem_bs_mb" . ":LAST:Cur\\:%6.1lf MB    ");
		push(@tmpz, "LINE2:mem_bs#44EEEE:BlockSize");
		push(@tmp, "LINE1:mem_cs#EE44EE:ContextSize");
		push(@tmp, "GPRINT:mem_cs_mb" . ":LAST:Cur\\:%5.1lf MB\\n");
		push(@tmpz, "LINE2:mem_cs#EE44EE:ContextSize");
		push(@tmp, "LINE1:mem_l#EE4444:Lost");
		push(@tmp, "GPRINT:mem_l_mb" . ":LAST:     Cur\\:%6.1lf MB\\n");
		push(@tmpz, "LINE2:mem_l#EE4444:Lost");
		if($title) {
			print("    <td bgcolor='" . $title_bg_color . "'>\n");
		}
		($width, $height) = split('x', $GRAPH_SIZE{medium2});
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 7 + 5]",
			"--title=$rgraphs{_bind6}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=bytes",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:mem_tu=$BIND_RRD:bind" . $e . "_mem_totaluse:AVERAGE",
			"DEF:mem_iu=$BIND_RRD:bind" . $e . "_mem_inuse:AVERAGE",
			"DEF:mem_bs=$BIND_RRD:bind" . $e . "_mem_blksize:AVERAGE",
			"DEF:mem_cs=$BIND_RRD:bind" . $e . "_mem_ctxtsize:AVERAGE",
			"DEF:mem_l=$BIND_RRD:bind" . $e . "_mem_lost:AVERAGE",
			"CDEF:mem_tu_mb=mem_tu,1024,/,1024,/",
			"CDEF:mem_iu_mb=mem_iu,1024,/,1024,/",
			"CDEF:mem_bs_mb=mem_bs,1024,/,1024,/",
			"CDEF:mem_cs_mb=mem_cs,1024,/,1024,/",
			"CDEF:mem_l_mb=mem_l,1024,/,1024,/",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 7 + 5]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 7 + 5]",
				"--title=$rgraphs{_bind6}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=bytes",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:mem_tu=$BIND_RRD:bind" . $e . "_mem_totaluse:AVERAGE",
				"DEF:mem_iu=$BIND_RRD:bind" . $e . "_mem_inuse:AVERAGE",
				"DEF:mem_bs=$BIND_RRD:bind" . $e . "_mem_blksize:AVERAGE",
				"DEF:mem_cs=$BIND_RRD:bind" . $e . "_mem_ctxtsize:AVERAGE",
				"DEF:mem_l=$BIND_RRD:bind" . $e . "_mem_lost:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 7 + 5]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind6/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 5] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 5] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 5] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 5] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 5] . "'>\n");
			}
		}

		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "LINE1:tsk_dq#EEEE44:Default Quantum");
		push(@tmp, "GPRINT:tsk_dq" . ":LAST:        Current\\:%4.0lf\\n");
		push(@tmpz, "LINE2:tsk_dq#EEEE44:Default Quantum");
		push(@tmp, "LINE1:tsk_wt#4444EE:Worker Threads");
		push(@tmp, "GPRINT:tsk_wt" . ":LAST:         Current\\:%4.0lf\\n");
		push(@tmpz, "LINE2:tsk_wt#4444EE:Worker Threads");
		push(@tmp, "LINE1:tsk_tr#44EEEE:Tasks Running");
		push(@tmp, "GPRINT:tsk_tr" . ":LAST:          Current\\:%4.0lf\\n");
		push(@tmpz, "LINE2:tsk_tr#44EEEE:Tasks Running");
		($width, $height) = split('x', $GRAPH_SIZE{medium2});
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 7 + 6]",
			"--title=$rgraphs{_bind7}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Tasks",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:tsk_wt=$BIND_RRD:bind" . $e . "_tsk_workthrds:AVERAGE",
			"DEF:tsk_dq=$BIND_RRD:bind" . $e . "_tsk_defquantm:AVERAGE",
			"DEF:tsk_tr=$BIND_RRD:bind" . $e . "_tsk_tasksrun:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 7 + 6]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 7 + 6]",
				"--title=$rgraphs{_bind7}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Tasks",
				"--width=$width",
				"--height=$height",
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:tsk_wt=$BIND_RRD:bind" . $e . "_tsk_workthrds:AVERAGE",
				"DEF:tsk_dq=$BIND_RRD:bind" . $e . "_tsk_defquantm:AVERAGE",
				"DEF:tsk_tr=$BIND_RRD:bind" . $e . "_tsk_tasksrun:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 7 + 6]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind7/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 6] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 6] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 7 + 6] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 6] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 7 + 6] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    </tr>\n");

			print("    <tr>\n");
			print "      <td bgcolor='$title_bg_color' colspan='2'>\n";
			print "       <font face='Verdana, sans-serif' color='$title_fg_color'>\n";
			print "       <font size='-1'>\n";
			print "        <b>&nbsp;&nbsp;<a href='" . $host . "' style='{color: $title_fg_color}'>$host</a><b>\n";
			print "       </font></font>\n";
			print "      </td>\n";
			print("    </tr>\n");
			graph_footer();
		}
		$e++;
	}
	return 1;
}

# NTP graph
# ----------------------------------------------------------------------------
sub ntp {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
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
		"#B4B444",
		"#444444",
	);

	$title = !$silent ? $title : "";

	if($IFACE_MODE eq "text") {
		my $line1;
		my $line2;
		my $line3;
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$NTP_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $NTP_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("    ");
		for($n = 0; $n < scalar(@NTP_HOST_LIST); $n++) {
			$line1 = "                                  ";
			$line2 .= "     Delay   Offset   Jitter   Str";
			$line3 .= "----------------------------------";
			foreach my $i (@NTP_CODE_LIST[$n]) {
				foreach(@$i) {
					$line1 .= "     ";
					$line2 .= sprintf(" %4s", $_);
					$line3 .= "-----";
				}
			}
			if($line1) {
				$i = length($line1);
				printf(sprintf("%${i}s", sprintf("NTP Server: %s", $NTP_HOST_LIST[$n])));
			}
		}
		print("\n");
		print("Time$line2\n");
		print("----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $n3;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc", $time);
			for($n2 = 0; $n2 < scalar(@NTP_HOST_LIST); $n2++) {
				undef(@row);
				$from = $n2 * 14;
				$to = $from + 4;
				push(@row, @$line[$from..$to]);
				printf("  %8.3f %8.3f %8.3f   %2d ", @row);
				foreach my $i (@NTP_CODE_LIST[$n2]) {
					for($n3 = 0; $n3 < scalar(@$i); $n3++) {
						$from = $n2 * 14 + 4 + $n3;
						my ($c) = @$line[$from];
						printf(" %4d", $c);
					}
				}
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	for($n = 0; $n < scalar(@NTP_HOST_LIST); $n++) {
		for($n2 = 1; $n2 <= 3; $n2++) {
			$str = $u . $myself . $n . $n2 . "." . $when . ".png";
			push(@PNG, $str);
			unlink("$PNG_DIR" . $str);
			if($ENABLE_ZOOM eq "Y") {
				$str = $u . $myself . $n . $n2 . "z." . $when . ".png";
				push(@PNGz, $str);
				unlink("$PNG_DIR" . $str);
			}
		}
	}

	$e = 0;
	foreach my $host (@NTP_HOST_LIST) {
		if($e) {
			print("   <br>\n");
		}
		if($title) {
			graph_header($title, 2);
		}
		undef(@riglim);
		if($NTP1_RIGID eq 1) {
			push(@riglim, "--upper-limit=$NTP1_LIMIT");
		} else {
			if($NTP1_RIGID eq 2) {
				push(@riglim, "--upper-limit=$NTP1_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "LINE2:ntp" . $e . "_del#4444EE:Delay");
		push(@tmp, "GPRINT:ntp" . $e . "_del" . ":LAST:     Current\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_del" . ":AVERAGE:    Average\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_del" . ":MIN:    Min\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_del" . ":MAX:    Max\\:%6.3lf\\n");
		push(@tmp, "LINE2:ntp" . $e . "_off#44EEEE:Offset");
		push(@tmp, "GPRINT:ntp" . $e . "_off" . ":LAST:    Current\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_off" . ":AVERAGE:    Average\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_off" . ":MIN:    Min\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_off" . ":MAX:    Max\\:%6.3lf\\n");
		push(@tmp, "LINE2:ntp" . $e . "_jit#EE4444:Jitter");
		push(@tmp, "GPRINT:ntp" . $e . "_jit" . ":LAST:    Current\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_jit" . ":AVERAGE:    Average\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_jit" . ":MIN:    Min\\:%6.3lf");
		push(@tmp, "GPRINT:ntp" . $e . "_jit" . ":MAX:    Max\\:%6.3lf\\n");
		push(@tmpz, "LINE2:ntp" . $e . "_del#4444EE:Delay");
		push(@tmpz, "LINE2:ntp" . $e . "_off#44EEEE:Offset");
		push(@tmpz, "LINE2:ntp" . $e . "_jit#EE4444:Jitter");
		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='" . $title_bg_color . "'>\n");
		}
		($width, $height) = split('x', $GRAPH_SIZE{main});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 3]",
			"--title=$rgraphs{_ntp1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Seconds",
			"--width=$width",
			"--height=$height",
			@riglim,
			@VERSION12,
			@graph_colors,
			"DEF:ntp" . $e . "_del=$NTP_RRD:ntp" . $e . "_del:AVERAGE",
			"DEF:ntp" . $e . "_off=$NTP_RRD:ntp" . $e . "_off:AVERAGE",
			"DEF:ntp" . $e . "_jit=$NTP_RRD:ntp" . $e . "_jit:AVERAGE",
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			"COMMENT: \\n",);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 3]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 3]",
				"--title=$rgraphs{_ntp1}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Seconds",
				"--width=$width",
				"--height=$height",
				@riglim,
				@VERSION12,
				@graph_colors,
				"DEF:ntp" . $e . "_del=$NTP_RRD:ntp" . $e . "_del:AVERAGE",
				"DEF:ntp" . $e . "_off=$NTP_RRD:ntp" . $e . "_off:AVERAGE",
				"DEF:ntp" . $e . "_jit=$NTP_RRD:ntp" . $e . "_jit:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /ntp$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3] . "'>\n");
			}
		}
		if($title) {
			print("    </td>\n");
			print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
		}

		undef(@riglim);
		if($NTP2_RIGID eq 1) {
			push(@riglim, "--upper-limit=$NTP2_LIMIT");
		} else {
			if($NTP2_RIGID eq 2) {
				push(@riglim, "--upper-limit=$NTP2_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "LINE2:ntp" . $e . "_str#44EEEE:Stratum");
		push(@tmp, "GPRINT:ntp" . $e . "_str" . ":LAST:              Current\\:%2.0lf\\n");
		push(@tmpz, "LINE2:ntp" . $e . "_str#44EEEE:Stratum");
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		RRDs::graph("$PNG_DIR" . $PNG[$e * 3 + 1],
			"--title=$rgraphs{_ntp2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Level",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:ntp" . $e . "_str=$NTP_RRD:ntp" . $e . "_str:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . $PNG[$e * 3 + 1] . ": $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . $PNGz[$e * 3 + 1],
				"--title=$rgraphs{_ntp2}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Level",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:ntp" . $e . "_str=$NTP_RRD:ntp" . $e . "_str:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . $PNGz[$e * 3 + 1] . ": $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /ntp$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 1] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 1] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 1] . "'>\n");
			}
		}

		undef(@tmp);
		undef(@tmpz);
		$i = @NTP_CODE_LIST[$e];
		for($n = 0; $n < 10; $n++) {
			if(@$i[$n]) {
				$str = sprintf("%-4s", @$i[$n]);
				push(@tmp, "LINE2:ntp" . $e . "_c" . sprintf("%02d", ($n + 1)) . $AC[$n] . ":$str");
				push(@tmp, "COMMENT:   \\g");
				push(@tmpz, "LINE2:ntp" . $e . "_c" . sprintf("%02d", ($n + 1)) . $AC[$n] . ":$str");
				if(!(($n + 1) % 5)) {
					push(@tmp, ("COMMENT: \\n"));
				}
			}
		}
		($width, $height) = split('x', $GRAPH_SIZE{small});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
		}
		RRDs::graph("$PNG_DIR" . $PNG[$e * 3 + 2],
			"--title=$rgraphs{_ntp3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Hits",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			"DEF:ntp" . $e . "_c01=$NTP_RRD:ntp" . $e . "_c01:AVERAGE",
			"DEF:ntp" . $e . "_c02=$NTP_RRD:ntp" . $e . "_c02:AVERAGE",
			"DEF:ntp" . $e . "_c03=$NTP_RRD:ntp" . $e . "_c03:AVERAGE",
			"DEF:ntp" . $e . "_c04=$NTP_RRD:ntp" . $e . "_c04:AVERAGE",
			"DEF:ntp" . $e . "_c05=$NTP_RRD:ntp" . $e . "_c05:AVERAGE",
			"DEF:ntp" . $e . "_c06=$NTP_RRD:ntp" . $e . "_c06:AVERAGE",
			"DEF:ntp" . $e . "_c07=$NTP_RRD:ntp" . $e . "_c07:AVERAGE",
			"DEF:ntp" . $e . "_c08=$NTP_RRD:ntp" . $e . "_c08:AVERAGE",
			"DEF:ntp" . $e . "_c09=$NTP_RRD:ntp" . $e . "_c09:AVERAGE",
			"DEF:ntp" . $e . "_c10=$NTP_RRD:ntp" . $e . "_c10:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . $PNG[$e * 3 + 2] . ": $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . $PNGz[$e * 3 + 2],
				"--title=$rgraphs{_ntp3}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Hits",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:ntp" . $e . "_c01=$NTP_RRD:ntp" . $e . "_c01:AVERAGE",
				"DEF:ntp" . $e . "_c02=$NTP_RRD:ntp" . $e . "_c02:AVERAGE",
				"DEF:ntp" . $e . "_c03=$NTP_RRD:ntp" . $e . "_c03:AVERAGE",
				"DEF:ntp" . $e . "_c04=$NTP_RRD:ntp" . $e . "_c04:AVERAGE",
				"DEF:ntp" . $e . "_c05=$NTP_RRD:ntp" . $e . "_c05:AVERAGE",
				"DEF:ntp" . $e . "_c06=$NTP_RRD:ntp" . $e . "_c06:AVERAGE",
				"DEF:ntp" . $e . "_c07=$NTP_RRD:ntp" . $e . "_c07:AVERAGE",
				"DEF:ntp" . $e . "_c08=$NTP_RRD:ntp" . $e . "_c08:AVERAGE",
				"DEF:ntp" . $e . "_c09=$NTP_RRD:ntp" . $e . "_c09:AVERAGE",
				"DEF:ntp" . $e . "_c10=$NTP_RRD:ntp" . $e . "_c10:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . $PNGz[$e * 3 + 2] . ": $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /ntp$e2/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 2] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 3 + 2] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 3 + 2] . "'>\n");
			}
		}

		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
	
			print("    <tr>\n");
			print "      <td bgcolor='$title_bg_color' colspan='2'>\n";
			print "       <font face='Verdana, sans-serif' color='$title_fg_color'>\n";
			print "       <font size='-1'>\n";
			print "        <b style='{color: $title_fg_color}'>&nbsp;&nbsp;$host<b>\n";
			print "       </font></font>\n";
			print "      </td>\n";
			print("    </tr>\n");
			graph_footer();
		}
		$e++;
	}
	return 1;
}

# FAIL2BAN graph
# ----------------------------------------------------------------------------
sub fail2ban {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my $n;
	my $str;
	my $err;
	my @LC = (
		"#4444EE",
		"#EEEE44",
		"#44EEEE",
		"#EE44EE",
		"#888888",
		"#E29136",
		"#44EE44",
		"#448844",
		"#EE4444",
	);

	if($IFACE_MODE eq "text") {
		my $line1;
		my $line2;
		my $line3;
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$FAIL2BAN_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $FAIL2BAN_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("    ");
		for($n = 0; $n < scalar(@FAIL2BAN_LIST); $n++) {
			$line1 = "";
			foreach my $i (@FAIL2BAN_LIST[$n]) {
				foreach(@$i) {
					$str = sprintf("%20s", substr($_, 0, 20));
					$line1 .= "                     ";
					$line2 .= sprintf(" %20s", $str);
					$line3 .= "---------------------";
				}
			}
			if($line1) {
				$i = length($line1);
				printf(sprintf("%${i}s", sprintf("%s", $FAIL2BAN_DESC[$n])));
			}
		}
		print("\n");
		print("Time$line2\n");
		print("----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $n3;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc ", $time);
			for($n2 = 0; $n2 < scalar(@FAIL2BAN_LIST); $n2++) {
				foreach my $i (@FAIL2BAN_LIST[$n2]) {
					for($n3 = 0; $n3 < scalar(@$i); $n3++) {
						$from = $n2 * 9 + $n3;
						$to = $from + 1;
						my ($j) = @$line[$from..$to];
						@row = ($j);
						printf("%20d ", @row);
					}
				}
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	for($n = 0; $n < scalar(@FAIL2BAN_LIST); $n++) {
		$str = $u . $myself . $n . "." . $when . ".png";
		push(@PNG, $str);
		unlink("$PNG_DIR" . $str);
		if($ENABLE_ZOOM eq "Y") {
			$str = $u . $myself . $n . "z." . $when . ".png";
			push(@PNGz, $str);
			unlink("$PNG_DIR" . $str);
		}
	}

	if($FAIL2BAN_RIGID eq 1) {
		push(@riglim, "--upper-limit=$FAIL2BAN_LIMIT");
	} else {
		if($FAIL2BAN_RIGID eq 2) {
			push(@riglim, "--upper-limit=$FAIL2BAN_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	$n = 0;
	while($n < scalar(@FAIL2BAN_LIST)) {
		if($title) {
			if($n == 0) {
				graph_header($title, $FAIL2BAN_PER_ROW);
			}
			print("    <tr>\n");
		}
		for($n2 = 0; $n2 < $FAIL2BAN_PER_ROW; $n2++) {
			last unless $n < scalar(@FAIL2BAN_LIST);
			if($title) {
				print("    <td bgcolor='" . $title_bg_color . "'>\n");
			}
			undef(@tmp);
			undef(@tmpz);
			foreach my $i ($FAIL2BAN_LIST[$n]) {
				my $e = 0;
				foreach(@$i) {
					$str = sprintf("%-25s", substr($_, 0, 25));
					push(@tmp, "LINE1:j" . ($e + 1) . $LC[$e] . ":$str");
					push(@tmp, "GPRINT:j" . ($e + 1) . ":LAST: Cur\\:%2.0lf\\g");
					push(@tmp, "GPRINT:j" . ($e + 1) . ":AVERAGE:   Avg\\:%2.0lf\\g");
					push(@tmp, "GPRINT:j" . ($e + 1) . ":MIN:   Min\\:%2.0lf\\g");
					push(@tmp, "GPRINT:j" . ($e + 1) . ":MAX:   Max\\:%2.0lf\\n");
					push(@tmpz, "LINE2:j" . ($e + 1) . $LC[$e] . ":$str");
					$e++;
				}
				for($e = scalar(@$i); $e < 9; $e++) {
					push(@tmp, "COMMENT: \\n");
				}
			}
			($width, $height) = split('x', $GRAPH_SIZE{medium});
			$str = substr($FAIL2BAN_DESC[$n2], 0, 25);
			RRDs::graph("$PNG_DIR" . "$PNG[$n]",
				"--title=$str  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=bans/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				"DEF:j1=$FAIL2BAN_RRD:fail2ban" . $n . "_j1:AVERAGE",
				"DEF:j2=$FAIL2BAN_RRD:fail2ban" . $n . "_j2:AVERAGE",
				"DEF:j3=$FAIL2BAN_RRD:fail2ban" . $n . "_j3:AVERAGE",
				"DEF:j4=$FAIL2BAN_RRD:fail2ban" . $n . "_j4:AVERAGE",
				"DEF:j5=$FAIL2BAN_RRD:fail2ban" . $n . "_j5:AVERAGE",
				"DEF:j6=$FAIL2BAN_RRD:fail2ban" . $n . "_j6:AVERAGE",
				"DEF:j7=$FAIL2BAN_RRD:fail2ban" . $n . "_j7:AVERAGE",
				"DEF:j8=$FAIL2BAN_RRD:fail2ban" . $n . "_j8:AVERAGE",
				"DEF:j9=$FAIL2BAN_RRD:fail2ban" . $n . "_j9:AVERAGE",
				@tmp);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG[$n]: $err\n") if $err;
			if($ENABLE_ZOOM eq "Y") {
				($width, $height) = split('x', $GRAPH_SIZE{zoom});
				RRDs::graph("$PNG_DIR" . "$PNGz[$n]",
					"--title=$str  ($nwhen$twhen)",
					"--start=-$nwhen$twhen",
					"--imgformat=PNG",
					"--vertical-label=bans/s",
					"--width=$width",
					"--height=$height",
					@riglim,
					"--lower-limit=0",
					@VERSION12,
					@VERSION12_small,
					@graph_colors,
					"DEF:j1=$FAIL2BAN_RRD:fail2ban" . $n . "_j1:AVERAGE",
					"DEF:j2=$FAIL2BAN_RRD:fail2ban" . $n . "_j2:AVERAGE",
					"DEF:j3=$FAIL2BAN_RRD:fail2ban" . $n . "_j3:AVERAGE",
					"DEF:j4=$FAIL2BAN_RRD:fail2ban" . $n . "_j4:AVERAGE",
					"DEF:j5=$FAIL2BAN_RRD:fail2ban" . $n . "_j5:AVERAGE",
					"DEF:j6=$FAIL2BAN_RRD:fail2ban" . $n . "_j6:AVERAGE",
					"DEF:j7=$FAIL2BAN_RRD:fail2ban" . $n . "_j7:AVERAGE",
					"DEF:j8=$FAIL2BAN_RRD:fail2ban" . $n . "_j8:AVERAGE",
					"DEF:j9=$FAIL2BAN_RRD:fail2ban" . $n . "_j9:AVERAGE",
					@tmpz);
				$err = RRDs::error;
				print("ERROR: while graphing $PNG_DIR" . "$PNGz[$n]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /fail2ban$n/)) {
				if($ENABLE_ZOOM eq "Y") {
					if($DISABLE_JAVASCRIPT_VOID eq "Y") {
						print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$n] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$n] . "' border='0'></a>\n");
					}
					else {
						print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$n] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$n] . "' border='0'></a>\n");
					}
				} else {
					print("      <img src='" . $URL . $IMGS_DIR . $PNG[$n] . "'>\n");
				}
			}
			if($title) {
				print("    </td>\n");
			}
			$n++;
		}
		if($title) {
			print("    </tr>\n");
		}
	}
	if($title) {
		graph_footer();
	}
	return 1;
}

# ICECAST graph
# ----------------------------------------------------------------------------
sub icecast {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my $e;
	my $n;
	my $str;
	my $stack;
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

	$title = !$silent ? $title : "";

	if($IFACE_MODE eq "text") {
		my $line1;
		my $line2;
		my $line3;
		my $line4;
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$ICECAST_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $ICECAST_RRD: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("    ");
		for($n = 0; $n < scalar(@ICECAST_URL_LIST); $n++) {
			$line1 = "  ";
			$line2 .= "  ";
			$line3 .= "  ";
			$line4 .= "--";
			foreach my $i (@ICECAST_MP_LIST[$n]) {
				foreach(@$i) {
					$line1 .= "           ";
					$line2 .= sprintf(" %10s", $_);
					$line3 .= "  List BitR";
					$line4 .= "-----------";
				}
			}
			if($line1) {
				$i = length($line1);
				printf(sprintf("%${i}s", sprintf("Icecast Server %2d", $n)));
			}
		}
		print("\n");
		print("    $line2");
		print("\n");
		print("Time$line3\n");
		print("----$line4 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $n3;
		my $from;
		my $to;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $ts);
			printf(" %2d$tc", $time);
			for($n2 = 0; $n2 < scalar(@ICECAST_URL_LIST); $n2++) {
				print("  ");
				foreach my $i (@ICECAST_MP_LIST[$n2]) {
					for($n3 = 0; $n3 < scalar(@$i); $n3++) {
						$from = $n2 * 36 + ($n3 * 4);
						$to = $from + 4;
						my ($l, $b, undef, undef) = @$line[$from..$to];
						@row = ($l, $b);
						printf("  %4d %4d", @row);
					}
				}
			}
			print("\n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	for($n = 0; $n < scalar(@ICECAST_URL_LIST); $n++) {
		$str = $u . $myself . $n . "1." . $when . ".png";
		push(@PNG, $str);
		unlink("$PNG_DIR" . $str);
		$str = $u . $myself . $n . "2." . $when . ".png";
		push(@PNG, $str);
		unlink("$PNG_DIR" . $str);
		if($ENABLE_ZOOM eq "Y") {
			$str = $u . $myself . $n . "1z." . $when . ".png";
			push(@PNGz, $str);
			unlink("$PNG_DIR" . $str);
			$str = $u . $myself . $n . "2z." . $when . ".png";
			push(@PNGz, $str);
			unlink("$PNG_DIR" . $str);
		}
	}

	$e = 0;
	foreach my $url (@ICECAST_URL_LIST) {
		if($e) {
			print("   <br>\n");
		}
		if($title) {
			graph_header($title, 2);
		}
		undef(@riglim);
		if($ICECAST1_RIGID eq 1) {
			push(@riglim, "--upper-limit=$ICECAST1_LIMIT");
		} else {
			if($ICECAST1_RIGID eq 2) {
				push(@riglim, "--upper-limit=$ICECAST1_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		foreach my $i (@ICECAST_MP_LIST[$e]) {
			for($n = 0; $n < scalar(@$i); $n++) {
				$str = sprintf("%-15s", substr(@$i[$n], 0, 15));
				if($ICECAST_GRAPH_MODE eq "S") {
					$stack = ":STACK";
				}
				push(@tmp, "AREA:ice" . $e . "_mp$n" . $AC[$n] . ":$str" . $stack);
				push(@tmpz, "AREA:ice" . $e . "_mp$n" . $AC[$n] . ":@$i[$n]" . $stack);
				push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":LAST: Cur\\:%4.0lf");
				push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":AVERAGE: Avg\\:%4.0lf");
				push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":MIN: Min\\:%4.0lf");
				push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":MAX: Max\\:%4.0lf\\n");
			}
		}
		if($ICECAST_GRAPH_MODE ne "S") {
			foreach my $i (@ICECAST_MP_LIST[$e]) {
				for($n = 0; $n < scalar(@$i); $n++) {
					push(@tmp, "LINE1:ice" . $e . "_mp$n" . $LC[$n]);
					push(@tmpz, "LINE2:ice" . $e . "_mp$n" . $LC[$n]);
				}
			}
		}

		if($title) {
			print("    <tr>\n");
			print("    <td bgcolor='" . $title_bg_color . "'>\n");
		}
		($width, $height) = split('x', $GRAPH_SIZE{medium});
		RRDs::graph("$PNG_DIR" . "$PNG[$e * 2]",
			"--title=$rgraphs{_icecast1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Listeners",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:ice" . $e . "_mp0=$ICECAST_RRD:icecast" . $e . "_mp0_ls:AVERAGE",
			"DEF:ice" . $e . "_mp1=$ICECAST_RRD:icecast" . $e . "_mp1_ls:AVERAGE",
			"DEF:ice" . $e . "_mp2=$ICECAST_RRD:icecast" . $e . "_mp2_ls:AVERAGE",
			"DEF:ice" . $e . "_mp3=$ICECAST_RRD:icecast" . $e . "_mp3_ls:AVERAGE",
			"DEF:ice" . $e . "_mp4=$ICECAST_RRD:icecast" . $e . "_mp4_ls:AVERAGE",
			"DEF:ice" . $e . "_mp5=$ICECAST_RRD:icecast" . $e . "_mp5_ls:AVERAGE",
			"DEF:ice" . $e . "_mp6=$ICECAST_RRD:icecast" . $e . "_mp6_ls:AVERAGE",
			"DEF:ice" . $e . "_mp7=$ICECAST_RRD:icecast" . $e . "_mp7_ls:AVERAGE",
			"DEF:ice" . $e . "_mp8=$ICECAST_RRD:icecast" . $e . "_mp8_ls:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$e * 2]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$e * 2]",
				"--title=$rgraphs{_icecast1}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Listeners",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@graph_colors,
				"DEF:ice" . $e . "_mp0=$ICECAST_RRD:icecast" . $e . "_mp0_ls:AVERAGE",
				"DEF:ice" . $e . "_mp1=$ICECAST_RRD:icecast" . $e . "_mp1_ls:AVERAGE",
				"DEF:ice" . $e . "_mp2=$ICECAST_RRD:icecast" . $e . "_mp2_ls:AVERAGE",
				"DEF:ice" . $e . "_mp3=$ICECAST_RRD:icecast" . $e . "_mp3_ls:AVERAGE",
				"DEF:ice" . $e . "_mp4=$ICECAST_RRD:icecast" . $e . "_mp4_ls:AVERAGE",
				"DEF:ice" . $e . "_mp5=$ICECAST_RRD:icecast" . $e . "_mp5_ls:AVERAGE",
				"DEF:ice" . $e . "_mp6=$ICECAST_RRD:icecast" . $e . "_mp6_ls:AVERAGE",
				"DEF:ice" . $e . "_mp7=$ICECAST_RRD:icecast" . $e . "_mp7_ls:AVERAGE",
				"DEF:ice" . $e . "_mp8=$ICECAST_RRD:icecast" . $e . "_mp8_ls:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$e * 2]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /icecast$e/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 2] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 2] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 2] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 2] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 2] . "'>\n");
			}
		}
		if($title) {
			print("    </td>\n");
		}

		undef(@riglim);
		if($ICECAST2_RIGID eq 1) {
			push(@riglim, "--upper-limit=$ICECAST2_LIMIT");
		} else {
			if($ICECAST2_RIGID eq 2) {
				push(@riglim, "--upper-limit=$ICECAST2_LIMIT");
				push(@riglim, "--rigid");
			}
		}
		undef(@tmp);
		undef(@tmpz);
		foreach my $i (@ICECAST_MP_LIST[$e]) {
			for($n = 0; $n < scalar(@$i); $n++) {
				$str = sprintf("%-15s", @$i[$n]);
				push(@tmp, "LINE1:ice" . $e . "_mp$n" . $LC[$n] . ":$str");
				push(@tmpz, "LINE2:ice" . $e . "_mp$n" . $LC[$n] . ":@$i[$n]");
				push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":LAST: Cur\\:%3.0lf");
				push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":AVERAGE:  Avg\\:%3.0lf");
				push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":MIN:  Min\\:%3.0lf");
				push(@tmp, "GPRINT:ice" . $e . "_mp$n" . ":MAX:  Max\\:%3.0lf\\n");
			}
		}

		if($title) {
			print("    <td bgcolor='" . $title_bg_color . "'>\n");
		}
		($width, $height) = split('x', $GRAPH_SIZE{medium});
		RRDs::graph("$PNG_DIR" . $PNG[$e * 2 + 1],
			"--title=$rgraphs{_icecast2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Bitrate",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:ice" . $e . "_mp0=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
			"DEF:ice" . $e . "_mp1=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
			"DEF:ice" . $e . "_mp2=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
			"DEF:ice" . $e . "_mp3=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
			"DEF:ice" . $e . "_mp4=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
			"DEF:ice" . $e . "_mp5=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
			"DEF:ice" . $e . "_mp6=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
			"DEF:ice" . $e . "_mp7=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
			"DEF:ice" . $e . "_mp8=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . $PNG[$e * 2 + 1] . ": $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . $PNGz[$e * 2 + 1],
				"--title=$rgraphs{_icecast2}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Bitrate",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@graph_colors,
				"DEF:ice" . $e . "_mp0=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
				"DEF:ice" . $e . "_mp1=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
				"DEF:ice" . $e . "_mp2=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
				"DEF:ice" . $e . "_mp3=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
				"DEF:ice" . $e . "_mp4=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
				"DEF:ice" . $e . "_mp5=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
				"DEF:ice" . $e . "_mp6=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
				"DEF:ice" . $e . "_mp7=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
				"DEF:ice" . $e . "_mp8=$ICECAST_RRD:icecast" . $e . "_mp0_br:AVERAGE",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . $PNGz[$e * 2 + 1] . ": $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /icecast$e/)) {
			if($ENABLE_ZOOM eq "Y") {
				if($DISABLE_JAVASCRIPT_VOID eq "Y") {
					print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$e * 2 + 1] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 2 + 1] . "' border='0'></a>\n");
				}
				else {
					print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$e * 2 + 1] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$e * 2 + 1] . "' border='0'></a>\n");
				}
			} else {
				print("      <img src='" . $URL . $IMGS_DIR . $PNG[$e * 2 + 1] . "'>\n");
			}
		}
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
	
			print("    <tr>\n");
			print "      <td bgcolor='$title_bg_color' colspan='2'>\n";
			print "       <font face='Verdana, sans-serif' color='$title_fg_color'>\n";
			print "       <font size='-1'>\n";
			print "        <b>&nbsp;&nbsp;<a href='" . $url . "' style='{color: $title_fg_color}'>$url</a><b>\n";
			print "       </font></font>\n";
			print "      </td>\n";
			print("    </tr>\n");
			graph_footer();
		}
		$e++;
	}
	return 1;
}

# INT graph
# ----------------------------------------------------------------------------
sub int {
	my ($myself, $title) = @_;

	my $width;
	my $height;
	my @riglim;
	my $n;
	my $err;

	my @INT;
	my @NAME;
	my @DEF1;
	my @AREA1;
	my @LINE1;
	my @DEF2;
	my @AREA2;
	my @LINE2;
	my @DEF3;
	my @AREA3;
	my @LINE3;
	my $n1;
	my $n2;
	my $n3;
	my @ACOLOR1 =  ("#FFA500",
			"#44EEEE",
			"#CCCCCC",
			"#B4B444",
			"#4444EE",
			"#44EE44",
			"#EEEE44",
			"#444444",
			"#EE44EE",
			"#EE4444",
			"#448844",
			"#BB44EE",
			"#D3D701",
			"#E29136",
			"#DDAE8C",
			"#F29967",
			"#996952",
			"#EB6C75",
			"#B84F6B",
			"#963C74",
			"#A68BBC",
			"#597AB7",
			"#8CB4CE",
			"#63BEE0",
			"#3CB5B0",
			"#7EB97C",
			"#94C36B",
			"#884632",

			"#CD5C5C",
			"#F08080",
			"#FA8072",
			"#E9967A",
			"#FFA07A",
			"#DC143C",
			"#B22222",
			"#8B0000",
			"#FFC0CB",
			"#FF69B4",
			"#FF1493",
			"#C71585",
			"#DB7093",
			"#FFA07A",
			"#FF7F50",
			"#FF6347",
			"#FF4500",
			"#FF8C00",
			"#FFD700",
			"#FFFFE0",
			"#FFFACD",
			"#FFEFD5",
			"#FFE4B5",
			"#FFDAB9",
			"#EEE8AA",
			"#F0E68C",
			"#BDB76B",
			"#E6E6FA",
			"#D8BFD8",
			"#DDA0DD",
			"#EE82EE",
			"#DA70D6",
			"#BA55D3",
			"#9370DB",
			"#9966CC",
			"#8A2BE2",
			"#9400D3",
			"#9932CC",
			"#8B008B",
			"#4B0082",
			"#6A5ACD",
			"#483D8B",
			"#7B68EE",
			"#ADFF2F",
			"#7FFF00",
			"#32CD32",
			"#98FB98",
			"#90EE90",
			"#00FA9A",
			"#00FF7F",
			"#3CB371",
			"#2E8B57",
			"#228B22",
			"#9ACD32",
			"#6B8E23",
			"#808000",
			"#556B2F",
			"#66CDAA",
			"#8FBC8F",
			"#20B2AA",
			"#008B8B",
			"#007070",
			"#E0FFFF",
			"#AFEEEE",
			"#7FFFD4",
			"#40E0D0",
			"#48D1CC",
			"#00CED1",
			"#5F9EA0",
			"#4682B4",
			"#B0C4DE",
			"#B0E0E6",
			"#ADD8E6",
			"#87CEEB",
			"#00BFFF",
			"#1E90FF",
			"#6495ED",
			"#7B68EE",
			"#4169E1",
			"#191970",
			"#FFF8DC",
			"#FFEBCD",
			"#FFDEAD",
			"#F5DEB3",
			"#DEB887",
			"#D2B48C",
			"#BC8F8F",
			"#F4A460",
			"#DAA520",
			"#B8860B",
			"#CD853F",
			"#D2691E",
			"#8B4513",
			"#A0522D",
			"#A52A2A",
			"#800000",
			"#FFFAFA",
			"#F0FFF0",
			"#F0F8FF",
			"#F5F5F5",
			"#FDF5E6",
			"#F5F5DC",
			"#FAEBD7",
			"#FFE4E1",
			"#DCDCDC",
			"#696969",
			"#A9A9A9",
			"#708090",
			"#2F4F4F",
			"#000066",
			"#006633",
			"#660033",
			"#66FFCC",
			"#990066",
			"#996633",
			"#99CCCC",
			"#CC3366",
			"#CC6633",
			"#CC6699",
			"#CC9933",
			"#CC9999",
			"#CCCC33",
			"#CCCC99",
			"#CCFF99",
			"#FF0099",
			"#FF6666",
			"#FF9999",
			"#FFCC99",
			"#FFFF99");

	my @LCOLOR1 =  ("#DDA500",
			"#00EEEE",
			"#888888",
			"#B4B400",
			"#0000EE",
			"#00EE00",
			"#EEEE00",
			"#444444",
			"#EE00EE",
			"#EE0000",
			"#008800",
			"#BB00EE",
			"#C8D200",
			"#DB6612",
			"#CE8248",
			"#EB6A39",
			"#8F4C30",
			"#E20045",
			"#B50C51",
			"#7B0059",
			"#684894",
			"#125AA3",
			"#518FBA",
			"#00AADA",
			"#009790",
			"#359B52",
			"#56AB27",
			"#782F1E",

			"#CD5C5C",
			"#F08080",
			"#FA8072",
			"#E9967A",
			"#FFA07A",
			"#DC143C",
			"#B22222",
			"#8B0000",
			"#FFC0CB",
			"#FF69B4",
			"#FF1493",
			"#C71585",
			"#DB7093",
			"#FFA07A",
			"#FF7F50",
			"#FF6347",
			"#FF4500",
			"#FF8C00",
			"#FFD700",
			"#FFFFE0",
			"#FFFACD",
			"#FFEFD5",
			"#FFE4B5",
			"#FFDAB9",
			"#EEE8AA",
			"#F0E68C",
			"#BDB76B",
			"#E6E6FA",
			"#D8BFD8",
			"#DDA0DD",
			"#EE82EE",
			"#DA70D6",
			"#BA55D3",
			"#9370DB",
			"#9966CC",
			"#8A2BE2",
			"#9400D3",
			"#9932CC",
			"#8B008B",
			"#4B0082",
			"#6A5ACD",
			"#483D8B",
			"#7B68EE",
			"#ADFF2F",
			"#7FFF00",
			"#32CD32",
			"#98FB98",
			"#90EE90",
			"#00FA9A",
			"#00FF7F",
			"#3CB371",
			"#2E8B57",
			"#228B22",
			"#9ACD32",
			"#6B8E23",
			"#808000",
			"#556B2F",
			"#66CDAA",
			"#8FBC8F",
			"#20B2AA",
			"#008B8B",
			"#007070",
			"#E0FFFF",
			"#AFEEEE",
			"#7FFFD4",
			"#40E0D0",
			"#48D1CC",
			"#00CED1",
			"#5F9EA0",
			"#4682B4",
			"#B0C4DE",
			"#B0E0E6",
			"#ADD8E6",
			"#87CEEB",
			"#00BFFF",
			"#1E90FF",
			"#6495ED",
			"#7B68EE",
			"#4169E1",
			"#191970",
			"#FFF8DC",
			"#FFEBCD",
			"#FFDEAD",
			"#F5DEB3",
			"#DEB887",
			"#D2B48C",
			"#BC8F8F",
			"#F4A460",
			"#DAA520",
			"#B8860B",
			"#CD853F",
			"#D2691E",
			"#8B4513",
			"#A0522D",
			"#A52A2A",
			"#800000",
			"#FFFAFA",
			"#F0FFF0",
			"#F0F8FF",
			"#F5F5F5",
			"#FDF5E6",
			"#F5F5DC",
			"#FAEBD7",
			"#FFE4E1",
			"#DCDCDC",
			"#696969",
			"#A9A9A9",
			"#708090",
			"#2F4F4F",
			"#000066",
			"#006633",
			"#660033",
			"#66FFCC",
			"#990066",
			"#996633",
			"#99CCCC",
			"#CC3366",
			"#CC6633",
			"#CC6699",
			"#CC9933",
			"#CC9999",
			"#CCCC33",
			"#CCCC99",
			"#CCFF99",
			"#FF0099",
			"#FF6666",
			"#FF9999",
			"#FFCC99",
			"#FFFF99");

	my @ACOLOR2 =  ("#44EEEE",
			"#4444EE",
			"#44EE44",
			"#EE44EE",
			"#EE4444",
			"#EEEE44");
	my @LCOLOR2 =  ("#00EEEE",
			"#0000EE",
			"#00EE00",
			"#EE00EE",
			"#EE0000",
			"#EEEE00");

	my @ACOLOR3 =  ("#44EE44",
			"#4444EE",
			"#44EEEE",
			"#EE4444",
			"#EE44EE",
			"#EEEE44");
	my @LCOLOR3 =  ("#00EE00",
			"#0000EE",
			"#00EEEE",
			"#EE0000",
			"#EE00EE",
			"#EEEE00");

	my $PNG1 = $u . $myself . "1." . $when . ".png";
	my $PNG2 = $u . $myself . "2." . $when . ".png";
	my $PNG3 = $u . $myself . "3." . $when . ".png";
	my $PNG1z = $u . $myself . "1z." . $when . ".png";
	my $PNG2z = $u . $myself . "2z." . $when . ".png";
	my $PNG3z = $u . $myself . "3z." . $when . ".png";

	$title = !$silent ? $title : "";

	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if($ENABLE_ZOOM eq "Y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	if($os eq "Linux") {
		open(IN, "/proc/interrupts");
		my $timer_pos = 0;
		my $i8042_pos = 0;
		my $good_pos = 0;
		my $num;
		my $name;
		while(<IN>) {
			if(/Dynamic-irq/) {
				next;
			}
			if(/[0-9]:/) {
				# Assuming int 0 will be only for timer
				if(/\s+0:/ || /^256:/) {
					$timer_pos = index($_, "timer", 0);
				}
				# Assuming int 1 will be only for i8042
				if(/\s+1:/) {
					$i8042_pos = index($_, "i8042", 0);
				}
				$timer_pos = $timer_pos == 0 ? 999 : $timer_pos;
				$i8042_pos = $i8042_pos == -1 ? 0 : $i8042_pos;
				$good_pos = $timer_pos > $i8042_pos ? $i8042_pos : $timer_pos;
				$good_pos = $good_pos ? $good_pos : $timer_pos;
				$num = unpack("A4", $_);
				undef($name);
				if(length($_) >= $good_pos) {
					$name = substr($_, $good_pos);
					$name = defined($name) ? $name : "";
				}
				chomp($num, $name);
				$name =~ s/^\s+//;
				$num =~ s/^\s+//;
				$num =~ s/:.*//;
				$n = $num;
				$num = $num > 255 ? $num % 256 : $num;
				$INT[$num] = defined($INT[$num]) ? $INT[$num] . "," : "";
				$NAME[$num] = defined($NAME[$num]) ? $NAME[$num] . ", " : "";
				$INT[$num] .= $n;
				$NAME[$num] .= $name;
			}
		}
		close(IN);
	} elsif ($os eq "FreeBSD" || $os eq "OpenBSD") {
		open(IN, "vmstat -i | sort |");
		my @allfields;
		my $num;
		my $name;
		while(<IN>) {
			if(/^\D{3}\d+/) {
				@allfields = split(' ', $_);
				$num = $allfields[0];
				$name = "";
				for($n = 1; $n <= $#allfields - 2; $n++) {
					$name .= $allfields[$n] . " ";
				}
				$num =~ s/^\D{3}//;
				$num =~ s/://;
				$name =~ s/\s+$//;

				# only the first timer (cpu0) is covered
				if($name eq "timer") {
					if($num != 0) {
						next;
					}
				}

				$n = $num;
				$num = $num > 255 ? $num % 256 : $num;
				$INT[$num] = defined($INT[$num]) ? $INT[$num] . "," : "";
				$NAME[$num] = defined($NAME[$num]) ? $NAME[$num] . ", " : "";
				$INT[$num] .= $n;
				$NAME[$num] .= $name;
			}
		}
		close(IN);

		chomp(@NAME);
		# strip all blank spaces at the end of the strings
		for($n = 0; $n < 256; $n++) {
			if(defined($NAME[$n])) {
				$NAME[$n] =~ s/\s+$//;
			}
		}
	}

	if($IFACE_MODE eq "text") {
		if($title) {
			graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$title_bg_color'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$INT_RRD",
			"--start=-$nwhen$twhen",
			"AVERAGE",
			"-r $res");
		$err = RRDs::error;
		print("ERROR: while fetching $INT_RRD: $err\n") if $err;
		my $line1;
		print("    <pre style='font-size: 12px; color: $fg_color';>\n");
		print("Time   ");
		for($n = 0; $n < 256; $n++) {
			if(defined($INT[$n])) {
				printf(" %8s", $INT[$n]);
				$line1 .= "---------";
			}
		}
		print(" \n");
		print("-------$line1\n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tb; $n < ($tb * $ts); $n++) {
			$line = @$data[$n];
			@row = @$line;
			$time = $time - (1 / $ts);
			printf(" %2d$tc   ", $time);
			for($n2 = 0; $n2 < 256; $n2++) {
				if(defined($INT[$n2])) {
					printf(" %8d", $row[$n2]);
				}
			}
			print(" \n");
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			graph_footer();
		}
		return 1;
	}

	if($title) {
		graph_header($title, 2);
	}

	my $i;
	for($n = 0, $n1 = 0, $n2 = 0, $n3 = 0; $n < 256; $n++) {
		if(defined($NAME[$n])) {
			# We need to escape colons to support RRDtool v1.2+
			if($RRDs::VERSION > 1.2) {
				$NAME[$n] =~ s/:/\\:/g;
			}
		}
		if(defined($INT[$n])) {
			if(index($INT[$n], ",", 0) < 0) {
				$i = $INT[$n];
			} else {
				($i) = split(',', $INT[$n]);
			}
			if($i < 3 || $NAME[$n] =~ /timer/) {
				push(@DEF2, ("DEF:int" . $n . "=" . $INT_RRD . ":int_" . $n . ":AVERAGE"));
				push(@AREA2, ("AREA:int" . $n . $ACOLOR2[$n2] . ":(" . $INT[$n] . ")" . $NAME[$n]));
				push(@LINE2, ("LINE1:int" . $n . $LCOLOR2[$n2]));
				$n2++;
			} elsif($i < 6 || $NAME[$n] =~ /^xen/) {
				push(@DEF3, ("DEF:int" . $n . "=" . $INT_RRD . ":int_" . $n . ":AVERAGE"));
				push(@AREA3, ("AREA:int" . $n . $ACOLOR3[$n3] . ":(" . $INT[$n] . ")" . $NAME[$n]));
				push(@LINE3, ("LINE1:int" . $n . $LCOLOR3[$n3]));
				$n3++;
			} else {
				push(@DEF1, ("DEF:int" . $n . "=" . $INT_RRD . ":int_" . $n . ":AVERAGE"));
				push(@AREA1, ("AREA:int" . $n . $ACOLOR1[$n1] . ":(" . $INT[$n] . ")" . $NAME[$n]));
				push(@LINE1, ("LINE1:int" . $n . $LCOLOR1[$n1]));
				$n1++;
				if(!($n1 % 3)) {
					push(@AREA1, ("COMMENT: \\n"));
				}
			}
		}
	}
	push(@AREA1, ("COMMENT: \\n"));
	if($INT1_RIGID eq 1) {
		push(@riglim, "--upper-limit=$INT1_LIMIT");
	} else {
		if($INT1_RIGID eq 2) {
			push(@riglim, "--upper-limit=$INT1_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$title_bg_color'>\n");
	}
	($width, $height) = split('x', $GRAPH_SIZE{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$rgraphs{_int1}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Ticks/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@graph_colors,
		@DEF1,
		@AREA1,
		@LINE1);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$rgraphs{_int1}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Ticks/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			@DEF1,
			@AREA1,
			@LINE1);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /int1/)) {
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
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $title_bg_color . "'>\n");
	}

	undef(@riglim);
	if($INT2_RIGID eq 1) {
		push(@riglim, "--upper-limit=$INT2_LIMIT");
	} else {
		if($INT2_RIGID eq 2) {
			push(@riglim, "--upper-limit=$INT2_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$rgraphs{_int2}  ($nwhen$twhen)",
		"--start=-$nwhen$twhen",
		"--imgformat=PNG",
		"--vertical-label=Ticks/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@VERSION12,
		@VERSION12_small,
		@graph_colors,
		@DEF2,
		@AREA2,
		@LINE2);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if($ENABLE_ZOOM eq "Y") {
		($width, $height) = split('x', $GRAPH_SIZE{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$rgraphs{_int2}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Ticks/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			@DEF2,
			@AREA2,
			@LINE2);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /int2/)) {
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
	if($INT3_RIGID eq 1) {
		push(@riglim, "--upper-limit=$INT3_LIMIT");
	} else {
		if($INT3_RIGID eq 2) {
			push(@riglim, "--upper-limit=$INT3_LIMIT");
			push(@riglim, "--rigid");
		}
	}
	($width, $height) = split('x', $GRAPH_SIZE{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $GRAPH_SIZE{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $GRAPH_SIZE{main}) if $silent eq "imagetagbig";
	}
	if(@DEF3 && @AREA3 && @LINE3) {
		RRDs::graph("$PNG_DIR" . "$PNG3",
			"--title=$rgraphs{_int3}  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=Ticks/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@VERSION12_small,
			@graph_colors,
			@DEF3,
			@AREA3,
			@LINE3);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNG3z",
				"--title=$rgraphs{_int3}  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=Ticks/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@VERSION12_small,
				@graph_colors,
				@DEF3,
				@AREA3,
				@LINE3);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /int3/)) {
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
	}
	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		graph_footer();
	}
	return 1;
}

# Multihost
# ----------------------------------------------------------------------------
sub multihost {
	my $n;
	my $n2;
	my $m;
	my $m2;
	my $gnum;
	my @HOST;
	my @URL;
	my @TEMP_LIST;

	if($val eq "all") {
		for($n = 0; $n < scalar(@REMOTEHOST_LIST); $n += 2) {
			push(@HOST, $REMOTEHOST_LIST[$n]);
			push(@URL, $REMOTEHOST_LIST[$n + 1]);
		}
	} else {
		$gnum = substr($val, 5, length($val));
		@TEMP_LIST = split(':', $REMOTEGROUP_LIST[2 * $gnum + 1]);
		$gnum = scalar(@TEMP_LIST);
		$gnum = scalar(@REMOTEHOST_LIST);
		for($m = 0; $m < scalar(@TEMP_LIST); $m += 1) {
			for($m2 = 0; $m2 < scalar(@REMOTEHOST_LIST); $m2 += 2) {
				if($TEMP_LIST[$m] eq $REMOTEHOST_LIST[$m2]) {
					push(@HOST, $REMOTEHOST_LIST[$m2]);
					push(@URL, $REMOTEHOST_LIST[$m2 + 1]);
				}
			}
		}
	}

	$MULTIHOST_IMGS_PER_ROW = 1 unless $MULTIHOST_IMGS_PER_ROW > 1;
	$graph = ($graph eq "all" || $graph =~ m/group\[0-9]*/) ? "_system1" : $graph;

	if($val eq "all" || $val =~ m/group[0-9]*/) {
		for($n = 0; $n < scalar(@HOST); $n += $MULTIHOST_IMGS_PER_ROW) {
			print "<table cellspacing='5' cellpadding='0' width='1' bgcolor='$graph_bg_color' border='1'>\n";
			print " <tr>\n";
			for($n2 = 0; $n2 < $MULTIHOST_IMGS_PER_ROW; $n2++) {
				if($n < scalar(@HOST)) {
					print "  <td bgcolor='$title_bg_color'>\n";
					print "   <font face='Verdana, sans-serif' color='$fg_color'>\n";
					print "   <b>&nbsp;&nbsp;" . $HOST[$n] . "<b>\n";
					print "   </font>\n";
					print "  </td>\n";
				}
				$n++;
			}
			print " </tr>\n";
			print " <tr>\n";
			for($n2 = 0, $n = $n - $MULTIHOST_IMGS_PER_ROW; $n2 < $MULTIHOST_IMGS_PER_ROW; $n2++) {
				if($n < scalar(@HOST)) {
					print "  <td bgcolor='$title_bg_color' style='vertical-align: top; height: 10%; width: 10%;'>\n";
					print "   <iframe src=$URL[$n]$BASE_CGI/monitorix.cgi?mode=localhost&when=$when&graph=$graph&color=$color&silent=imagetag height=201 width=397 frameborder=0 marginwidth=0 marginheight=0 scrolling=no></iframe>\n";
					print "  </td>\n";

				}
				$n++;
			}
			print " </tr>\n";
			print " <tr>\n";
			for($n2 = 0, $n = $n - $MULTIHOST_IMGS_PER_ROW; $n2 < $MULTIHOST_IMGS_PER_ROW; $n2++) {
				if($n < scalar(@HOST)) {
				if($MULTIHOST_FOOTER) {
					print "  <td bgcolor='$title_bg_color'>\n";
					print "   <font face='Verdana, sans-serif' color='$title_fg_color'>\n";
					print "   <font size='-1'>\n";
					print "    <b>&nbsp;&nbsp;<a href='" . $URL[$n] . $BASE_URL . "/' style='{color: $title_fg_color}'>$URL[$n]</a><b>\n";
					print "   </font></font>\n";
					print "  </td>\n";
				}
				}
				$n++;
			}
			$n = $n - $MULTIHOST_IMGS_PER_ROW;
			print " </tr>\n";
			print "</table>\n";
			print "<br>\n";
		}
	} else {
		print "  <table cellspacing='5' cellpadding='0' width='1' bgcolor='$graph_bg_color' border='1'>\n";
		print "   <tr>\n";
		print "    <td bgcolor='$title_bg_color'>\n";
		print "    <font face='Verdana, sans-serif' color='$fg_color'>\n";
		print "    <b>&nbsp;&nbsp;" . $HOST[$val] . "<b>\n";
		print "    </font>\n";
		print "    </td>\n";
		print "   </tr>\n";
		print "   <tr>\n";
		print "    <td bgcolor='$title_bg_color' style='vertical-align: top; height: 10%; width: 10%;'>\n";
		print "     <iframe src=$URL[$val]$BASE_CGI/monitorix.cgi?mode=localhost&when=$when&graph=$graph&color=$color&silent=imagetagbig height=249 width=545 frameborder=0 marginwidth=0 marginheight=0 scrolling=no></iframe>\n";
		print "    </td>\n";
		print "   </tr>\n";
		print "   <tr>\n";
		if($MULTIHOST_FOOTER) {
			print "   <td bgcolor='$title_bg_color'>\n";
			print "    <font face='Verdana, sans-serif' color='$title_fg_color'>\n";
			print "    <font size='-1'>\n";
			print "    <b>&nbsp;&nbsp;<a href='" . $URL[$val] . "/monitorix/' style='{color: $title_fg_color}'>$URL[$val]</a><b>\n";
			print "    </font></font>\n";
			print "   </td>\n";
		}
		print "   </tr>\n";
		print "  </table>\n";
		print "  <br>\n";
	}
}

sub pc {
	my $width;
	my $height;
	my @riglim;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $T = "B";
	my $vlabel = "bytes/s";
	my $n;
	my $n2;
	my $str;
	my $err;

	for($n = 0; $n < $PC_MAX; $n++) {
		$str = $u . "pc" . $n . ".$when" . ".png";
		push(@PNG, $str);
		unlink("$PNG_DIR" . $str);
		if($ENABLE_ZOOM eq "Y") {
			$str = $u . "pc" . $n . "z.$when" . ".png";
			push(@PNGz, $str);
			unlink("$PNG_DIR" . $str);
		}
	}
	if($PC_RIGID eq 1) {
		$riglim[0] = "--upper-limit=$PC_LIMIT";
	} else {
		if($PC_RIGID eq 2) {
			$riglim[0] = "--upper-limit=$PC_LIMIT";
			$riglim[1] = "--rigid";
		}
	}

	if($NETSTATS_IN_BPS eq "Y") {
		$T = "b";
		$vlabel = "bits/s";
	}
	$PC_IMGS_PER_ROW = 1 unless $PC_IMGS_PER_ROW > 1;
	if($val eq "all") {
		print("  <table cellspacing='5' cellpadding='0' width='1' bgcolor='$graph_bg_color' border='1'>\n");
		print("  <tr>\n");
		print("  <td bgcolor='$title_bg_color' colspan='" . $PC_IMGS_PER_ROW  . "'>\n");
		print("  <font face='Verdana, sans-serif' color='$title_fg_color'>\n");
		print("    <b>&nbsp;&nbsp;Internet traffic and usage<b>\n");
		print("  </font>\n");
		print("  </td>\n");
		print("  </tr>\n");
		$n = 0;
		while($n < $PC_MAX) {
			last unless $PC_LIST[$n];
			print("  <tr>\n");
			for($n2 = 0; $n2 < $PC_IMGS_PER_ROW; $n2++) {
				last unless ($n < $PC_MAX && $n < scalar(@PC_LIST));
				print("  <td bgcolor='$title_bg_color'>\n");
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
				if($NETSTATS_IN_BPS eq "Y") {
					push(@CDEF, "CDEF:B_in=in,8,*");
					push(@CDEF, "CDEF:B_out=out,8,*");
				} else {
					push(@CDEF, "CDEF:B_in=in");
					push(@CDEF, "CDEF:B_out=out");
				}
				($width, $height) = split('x', $GRAPH_SIZE{remote});
				RRDs::graph("$PNG_DIR" . "$PNG[$n]",
					"--title=$PC_LIST[$n] traffic  ($nwhen$twhen)",
					"--start=-$nwhen$twhen",
					"--imgformat=PNG",
					"--vertical-label=$vlabel",
					"--width=$width",
					"--height=$height",
					@riglim,
					"--lower-limit=0",
					@VERSION12,
					@VERSION12_small,
					@graph_colors,
					"DEF:in=$PC_RRD:pc" . $n . "_in:AVERAGE",
					"DEF:out=$PC_RRD:pc" . $n . "_out:AVERAGE",
					@CDEF,
					@tmp);
				$err = RRDs::error;
				print("ERROR: while graphing $PNG_DIR" . "$PNG[$n]: $err\n") if $err;
				if($ENABLE_ZOOM eq "Y") {
					($width, $height) = split('x', $GRAPH_SIZE{zoom});
					RRDs::graph("$PNG_DIR" . "$PNGz[$n]",
						"--title=$PC_LIST[$n] traffic  ($nwhen$twhen)",
						"--start=-$nwhen$twhen",
						"--imgformat=PNG",
						"--vertical-label=$vlabel",
						"--width=$width",
						"--height=$height",
						@riglim,
						"--lower-limit=0",
						@VERSION12,
						@VERSION12_small,
						@graph_colors,
						"DEF:in=$PC_RRD:pc" . $n . "_in:AVERAGE",
						"DEF:out=$PC_RRD:pc" . $n . "_out:AVERAGE",
						@CDEF,
						@tmpz);
					$err = RRDs::error;
					print("ERROR: while graphing $PNG_DIR" . "$PNGz[$n]: $err\n") if $err;
				}
				if($ENABLE_ZOOM eq "Y") {
					if($DISABLE_JAVASCRIPT_VOID eq "Y") {
						print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$n] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$n] . "' border='0'></a>\n");
					}
					else {
						print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$n] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$n] . "' border='0'></a>\n");
					}
				} else {
					print("      <img src='" . $URL . $IMGS_DIR . $PNG[$n] . "'>\n");
				}
				print("  </td>\n");
				$n++;
			}
			print("  </tr>\n");
		}
		print "  </table>\n";
	} else {
		return unless $PC_LIST[$val];
		if(!$silent) {
			print("  <table cellspacing='5' cellpadding='0' width='1' bgcolor='$graph_bg_color' border='1'>\n");
			print("  <tr>\n");
			print("  <td bgcolor='$title_bg_color' colspan='1'>\n");
			print("  <font face='Verdana, sans-serif' color='$title_fg_color'>\n");
			print("    <b>&nbsp;&nbsp;Internet traffic and usage<b>\n");
			print("  </font>\n");
			print("  </td>\n");
			print("  </tr>\n");
			print("  <tr>\n");
			print("  <td bgcolor='$title_bg_color'>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:B_in#44EE44:K$T/s Input");
		push(@tmp, "GPRINT:K_in:LAST:     Current\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:AVERAGE: Average\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:MIN:    Min\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:MAX:    Max\\: %5.0lf\\n");
		push(@tmp, "AREA:B_out#4444EE:K$T/s Output");
		push(@tmp, "GPRINT:K_out:LAST:    Current\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:AVERAGE: Average\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:MIN:    Min\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:MAX:    Max\\: %5.0lf\\n");
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
		if($NETSTATS_IN_BPS eq "Y") {
			push(@CDEF, "CDEF:B_in=in,8,*");
			push(@CDEF, "CDEF:B_out=out,8,*");
		} else {
			push(@CDEF, "CDEF:B_in=in");
			push(@CDEF, "CDEF:B_out=out");
		}
		($width, $height) = split('x', $GRAPH_SIZE{main});
		RRDs::graph("$PNG_DIR" . "$PNG[$val]",
			"--title=$PC_LIST[$val] traffic  ($nwhen$twhen)",
			"--start=-$nwhen$twhen",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@VERSION12,
			@graph_colors,
			"DEF:in=$PC_RRD:pc" . $val . "_in:AVERAGE",
			"DEF:out=$PC_RRD:pc" . $val . "_out:AVERAGE",
			@CDEF,
			"CDEF:K_in=B_in,1024,/",
			"CDEF:K_out=B_out,1024,/",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG[$val]: $err\n") if $err;
		if($ENABLE_ZOOM eq "Y") {
			($width, $height) = split('x', $GRAPH_SIZE{zoom});
			RRDs::graph("$PNG_DIR" . "$PNGz[$val]",
				"--title=$PC_LIST[$val] traffic  ($nwhen$twhen)",
				"--start=-$nwhen$twhen",
				"--imgformat=PNG",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@VERSION12,
				@graph_colors,
				"DEF:in=$PC_RRD:pc" . $val . "_in:AVERAGE",
				"DEF:out=$PC_RRD:pc" . $val . "_out:AVERAGE",
				@CDEF,
				"CDEF:K_in=B_in,1024,/",
				"CDEF:K_out=B_out,1024,/",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNGz[$val]: $err\n") if $err;
		}
		if($ENABLE_ZOOM eq "Y") {
			if($DISABLE_JAVASCRIPT_VOID eq "Y") {
				print("      <a href=\"" . $URL . $IMGS_DIR . $PNGz[$val] . "\"><img src='" . $URL . $IMGS_DIR . $PNG[$val] . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $URL . $IMGS_DIR . $PNGz[$val] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $URL . $IMGS_DIR . $PNG[$val] . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $URL . $IMGS_DIR . $PNG[$val] . "'>\n");
		}
		if(!$silent) {
			print("  </td>\n");
			print "  </td>\n";
			print "  </tr>\n";
			print "  </table>\n";
		}
	}
}

sub graph_header {
	my ($title, $colspan) = @_;
	print("\n");
	print("  <table cellspacing='5' cellpadding='0' width='1' bgcolor='$graph_bg_color' border='1'>\n");
	print("    <tr>\n");
	print("      <td bgcolor='$title_bg_color' colspan='$colspan'>\n");
	print("        <font face='Verdana, sans-serif' color='$title_fg_color'>\n");
	print("          <b>&nbsp;&nbsp;$title<b>\n");
	print("        </font>\n");
	print("      </td>\n");
	print("    </tr>\n");
}

sub graph_footer {
	print("  </table>\n");
}


# MAIN
# ----------------------------------------------------------------------------
print("Content-Type: text/html\n");
print("\n");
if(!$silent) {
	my $title;
	my $str;

	print("<html>\n");
	print("  <head>\n");
	print("    <title>$TITLE</title>\n");
	print("    <link rel='shortcut icon' href='" . $FAVICON . "'>\n");
	if($REFRESH_RATE) {
		print("    <meta http-equiv='Refresh' content='" . $REFRESH_RATE . "'>\n");
	}
	print("  </head>\n");
	print("  <body bgcolor='" . $bg_color . "' vlink='#888888' link='#888888'>\n");
	print("  <center>\n");
	print("  <table cellspacing='5' cellpadding='0' bgcolor='" . $graph_bg_color . "' border='1'>\n");
	print("  <tr>\n");
	if(($val ne "all" || $val ne "group") && $mode ne "multihost") {
		print("  <td bgcolor='" . $title_bg_color . "'>\n");
		print("  <font face='Verdana, sans-serif' color='" . $title_fg_color . "'>\n");
		print("    <font size='5'><b>&nbsp;&nbsp;Host:&nbsp;<b></font>\n");
		print("  </font>\n");
		print("  </td>\n");
	}
	if($val =~ m/group[0-9]+/) {
		my $gnum = substr($val, 5, length($val));
		my $gname = $REMOTEGROUP_LIST[2 * $gnum];
		print("  <td bgcolor='" . $title_bg_color . "'>\n");
		print("  <font face='Verdana, sans-serif' color='" . $title_fg_color . "'>\n");
		print("    <font size='5'><b>&nbsp;&nbsp;$gname&nbsp;<b></font>\n");
		print("  </font>\n");
		print("  </td>\n");
	}
	print("  <td bgcolor='" . $bg_color . "'>\n");
	print("  <font face='Verdana, sans-serif' color='" . $fg_color . "'>\n");
	if($mode eq "localhost" || $mode eq "pc") {
		$title = $HOSTNAME;
	} elsif($mode eq "multihost") {
		$graph = $graph eq "all" ? "_system1" : $graph;
		if(substr($graph, 0, 4) eq "_net") {
			$str = "_net" . substr($graph, 5, 1);
			$title = $rgraphs{$str};
		} elsif(substr($graph, 0, 5) eq "_port") {
			$str = substr($graph, 0, 5);
			$n = substr($graph, 5, 1);
			$title = $rgraphs{$str};
			$title .= " " . $PORT_LIST[$n];
			$title .= " (" . $PORT_NAME[$n] . ")";
		} else {
			$title = $rgraphs{$graph};
		}
	}
	$title =~ s/ /&nbsp;/g;
	print("    <font size='5'><b>&nbsp;&nbsp;$title&nbsp;&nbsp;</b></font>\n");
	print("  </font>\n");
	print("  </td>\n");
		print("  <td bgcolor='" . $title_bg_color . "'>\n");
		print("  <font face='Verdana, sans-serif' color='" . $title_fg_color . "'>\n");
		print("    <font size='5'><b>&nbsp;&nbsp;last&nbsp;$twhen&nbsp;&nbsp;<b></font>\n");
		print("  </font>\n");
		print("  </td>\n");
	print("  </tr>\n");
	print("  </table>\n");
	print("  <font face='Verdana, sans-serif' color='" . $fg_color . "'>\n");
	print("    <h4><font color='#888888'>" . strftime("%a %b %e %H:%M:%S %Z %Y", localtime) . "</font></h4>\n");
}

if($mode eq "localhost") {
	foreach my $g (@GRAPH_NAME) {
		if($GRAPH_ENABLE{$g} eq "Y") {
			if($graph eq "all" || $graph =~ /_$g/) {
				if(eval {&$g($g, $GRAPH_TITLE{$g});}) {
					print("  <br>\n");
				}
			}
		}
	}
} elsif($mode eq "multihost") {
	multihost();
} elsif($mode eq "pc") {
	pc();
}

if(!$silent) {
	print("\n");
	print("  </font>\n");
	print("  </center>\n");
	print("  <p>\n");
	print("  <a href='http://www.monitorix.org'><img src='" . $URL . "logo_bot.png' border='0'></a>\n");
	print("  <br>\n");
	print("  <font face='Verdana, sans-serif' color='" . $fg_color . "' size='-2'>\n");
	print("Copyright &copy; 2005-2012 Jordi Sanfeliu\n");
	print("  </font>\n");
	print("  </body>\n");
	print("</html>\n");
}

exit(0);
