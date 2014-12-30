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

package system;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(system_init system_update system_cgi);

sub system_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $system = $config->{system};

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
		eval {
			RRDs::create($rrd,
				"--step=60",
				"DS:system_load1:GAUGE:120:0:U",
				"DS:system_load5:GAUGE:120:0:U",
				"DS:system_load15:GAUGE:120:0:U",
				"DS:system_nproc:GAUGE:120:0:U",
				"DS:system_npslp:GAUGE:120:0:U",
				"DS:system_nprun:GAUGE:120:0:U",
				"DS:system_npwio:GAUGE:120:0:U",
				"DS:system_npzom:GAUGE:120:0:U",
				"DS:system_npstp:GAUGE:120:0:U",
				"DS:system_npswp:GAUGE:120:0:U",
				"DS:system_mtotl:GAUGE:120:0:U",
				"DS:system_mbuff:GAUGE:120:0:U",
				"DS:system_mcach:GAUGE:120:0:U",
				"DS:system_mfree:GAUGE:120:0:U",
				"DS:system_macti:GAUGE:120:0:U",
				"DS:system_minac:GAUGE:120:0:U",
				"DS:system_val01:GAUGE:120:0:U",
				"DS:system_val02:GAUGE:120:0:U",
				"DS:system_val03:GAUGE:120:0:U",
				"DS:system_val04:GAUGE:120:0:U",
				"DS:system_val05:GAUGE:120:0:U",
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

	# check dependencies
	if(lc($system->{alerts}->{loadavg_enabled}) eq "y") {
		if(! -x $system->{alerts}->{loadavg_script}) {
			logger("$myself: ERROR: script '$system->{alerts}->{loadavg_script}' doesn't exist or don't has execution permissions.");
		}
	}

	$config->{system_hist_alert1} = 0;
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub system_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $system = $config->{system};

	my $load1 = 0;
	my $load5 = 0;
	my $load15 = 0;
	my $nproc = 0;
	my $npslp = 0;
	my $nprun = 0;
	my $npwio = 0;
	my $npzom = 0;
	my $npstp = 0;
	my $npswp = 0;
	my $mtotl = 0;
	my $mbuff = 0;
	my $mcach = 0;
	my $mfree = 0;
	my $macti = 0;
	my $minac = 0;
	my $val01 = 0;
	my $val02 = 0;
	my $val03 = 0;
	my $val04 = 0;
	my $val05 = 0;

	my $rrdata = "N";

	$npwio = $npzom = $npstp = $npswp = 0;

	if($config->{os} eq "Linux") {
		open(IN, "/proc/loadavg");
		while(<IN>) {
			if(/^(\d+\.\d+) (\d+\.\d+) (\d+\.\d+) (\d+)\/(\d+)/) {
				$load1 = $1;
				$load5 = $2;
				$load15 = $3;
				$nprun = $4;
				$npslp = $5;
			}
		}
		close(IN);
		$nproc = $npslp + $nprun;

		open(IN, "/proc/meminfo");
		while(<IN>) {
			if(/^MemTotal:\s+(\d+) kB$/) {
				$mtotl = $1;
				next;
			}
			if(/^MemFree:\s+(\d+) kB$/) {
				$mfree = $1;
				next;
			}
			if(/^Buffers:\s+(\d+) kB$/) {
				$mbuff = $1;
				next;
			}
			if(/^Cached:\s+(\d+) kB$/) {
				$mcach = $1;
				last;
			}
		}
		close(IN);
		$macti = $minac = "";
	} elsif($config->{os} eq "FreeBSD") {
		my $page_size;
		open(IN, "sysctl -n vm.loadavg |");
		while(<IN>) {
			if(/^\{ (\d+\.\d+) (\d+\.\d+) (\d+\.\d+) \}$/) {
				$load1 = $1;
				$load5 = $2;
				$load15 = $3;
			}
		}
		close(IN);
		open(IN, "sysctl vm.vmtotal |");
		while(<IN>) {
			if(/^Processes:\s+\(RUNQ:\s+(\d+) Disk.*? Sleep:\s+(\d+)\)$/) {
				$nprun = $1;
				$npslp = $2;
			}
			if(/^(Free Memory Pages:|Free Memory:)\s+(\d+)K$/) {
				$mfree = $2;
			}
		}
		close(IN);
		$nproc = $npslp + $nprun;
		$mtotl = `sysctl -n hw.realmem`;
		$mbuff = `sysctl -n vfs.bufspace`;
		$mcach = `sysctl -n vm.stats.vm.v_cache_count`;

		chomp($mbuff);
		$mbuff = $mbuff / 1024;
		chomp($mtotl);
		$mtotl = $mtotl / 1024;
		$page_size = `sysctl -n vm.stats.vm.v_page_size`;
		$macti = `sysctl -n vm.stats.vm.v_active_count`;
		$minac = `sysctl -n vm.stats.vm.v_inactive_count`;
		chomp($page_size, $mcach, $macti, $minac);
		$mcach = ($page_size * $mcach) / 1024;
		$macti = ($page_size * $macti) / 1024;
		$minac = ($page_size * $minac) / 1024;
	} elsif($config->{os} eq "OpenBSD" || $config->{os} eq "NetBSD") {
		open(IN, "sysctl -n vm.loadavg |");
		while(<IN>) {
			if(/^(\d+\.\d+) (\d+\.\d+) (\d+\.\d+)$/) {
				$load1 = $1;
				$load5 = $2;
				$load15 = $3;
			}
		}
		close(IN);
		open(IN, "top -b |");
		while(<IN>) {
			if(/ processes:/) {
				$_ =~ s/:/,/;
				my (@tmp) = split(',', $_);
				foreach(@tmp) {
					my ($num, $desc) = split(' ', $_);
					$nproc = $num unless $desc ne "processes";
					if(grep {$_ eq $desc} ("idle", "sleeping", "stopped", "zombie")) {
						$npslp += $num;
					}
					if($desc eq "running" || $desc eq "on") {
						$nprun += $num;
					}
				}
			}
			if($config->{os} eq "OpenBSD") {
				if(/^Memory: Real: (\d+)\w\/\d+\w act\/tot  Free: (\d+)\w  /) {
					$macti = $1;
					$mfree = $2;
					$macti = int($macti) * 1024;
					$mfree = int($mfree) * 1024;
					last;
				}
			}
			if($config->{os} eq "NetBSD") {
				if(/^Memory: (\d+)\w Act, .*, (\d+)\w Free/) {
					$macti = $1;
					$mfree = $2;
					$macti = int($macti) * 1024;
					$mfree = int($mfree) * 1024;
					last;
				}
			}
		}	
		close(IN);
		$mtotl = `sysctl -n hw.physmem`;
		chomp($mtotl);
		$mtotl = $mtotl / 1024;
	}

	chomp(
		$load1,
		$load5,
		$load15,
		$nproc,
		$npslp,
		$nprun,
		$npwio,
		$npzom,
		$npstp,
		$npswp,
		$mtotl,
		$mbuff,
		$mcach,
		$mfree,
		$macti,
		$minac,
	);

	# SYSTEM alert
	if(lc($system->{alerts}->{loadavg_enabled}) eq "y") {
		if(!$system->{alerts}->{loadavg_threshold} || $load15 < $system->{alerts}->{loadavg_threshold}) {
			$config->{system_hist_alert1} = 0;
		} else {
			if(!$config->{system_hist_alert1}) {
				$config->{system_hist_alert1} = time;
			}
			if($config->{system_hist_alert1} > 0 && (time - $config->{system_hist_alert1}) >= $system->{alerts}->{loadavg_timeintvl}) {
				if(-x $system->{alerts}->{loadavg_script}) {
					logger("$myself: ALERT: executing script '$system->{alerts}->{loadavg_script}'.");
					system($system->{alerts}->{loadavg_script} . " " .$system->{alerts}->{loadavg_timeintvl} . " " . $system->{alerts}->{loadavg_threshold} . " " . $load15);
				} else {
					logger("$myself: ERROR: script '$system->{alerts}->{loadavg_script}' doesn't exist or don't has execution permissions.");
				}
				$config->{system_hist_alert1} = time;
			}
		}
	}

	$rrdata .= ":$load1:$load5:$load15:$nproc:$npslp:$nprun:$npwio:$npzom:$npstp:$npswp:$mtotl:$mbuff:$mcach:$mfree:$macti:$minac:$val01:$val02:$val03:$val04:$val05";
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub system_cgi {
	no strict "refs";

	my ($package, $config, $cgi) = @_;

	my $system = $config->{system};
	my @rigid = split(',', ($system->{rigid} || ""));
	my @limit = split(',', ($system->{limit} || ""));
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
	my @riglim;
	my @tmp;
	my @tmpz;
	my @CDEF,
	my $n;
	my $err;

	$version = "old" if $RRDs::VERSION < 1.3;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};


	$title = !$silent ? $title : "";

	my $total_mem;

	if($config->{os} eq "Linux") {
		$total_mem = `grep -w MemTotal: /proc/meminfo | awk '{print \$2}'`;
		chomp($total_mem);
	} elsif(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		$total_mem = `/sbin/sysctl -n hw.physmem`;	# in bytes
		chomp($total_mem);
		$total_mem = int($total_mem / 1024);		# in KB
	}
	$total_mem = int($total_mem / 1024);			# in MB


	# text mode
	#
	if(lc($config->{iface_mode}) eq "text") {
		if($title) {
			main::graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$colors->{title_bg_color}'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch($rrd,
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"AVERAGE",
			"-r $tf->{res}");
		$err = RRDs::error;
		print("ERROR: while fetching $rrd: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		print("       CPU load average    Memory usage in MB     Processes\n");
		print("Time   1min  5min 15min    Used  Cached Buffers   Total   Run\n");
		print("------------------------------------------------------------- \n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			my ($load1, $load5, $load15, $nproc, $npslp, $nprun, $mtotl, $buff, $cach, $free) = @$line;
			$buff /= 1024;
			$cach /= 1024;
			$free /= 1024;
			@row = ($load1, $load5, $load15, $total_mem - $free, $cach, $buff, $nproc, $nprun);
			$time = $time - (1 / $tf->{ts});
			printf(" %2d$tf->{tc}   %4.1f  %4.1f  %4.1f  %6d  %6d  %6d   %5d %5d \n", $time, @row);
		}
		print("\n");
		print(" system uptime: " . get_uptime($config) . "\n");
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
	my $PNG1z = $u . $package . "1z." . $tf->{when} . ".png";
	my $PNG2z = $u . $package . "2z." . $tf->{when} . ".png";
	my $PNG3z = $u . $package . "3z." . $tf->{when} . ".png";
	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	if($title) {
		main::graph_header($title, 2);
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	my $uptimeline;
	if($RRDs::VERSION > 1.2) {
		$uptimeline = "COMMENT:system uptime\\: " . get_uptime($config) . "\\c";
	} else {
		$uptimeline = "COMMENT:system uptime: " . get_uptime($config) . "\\c";
	}

	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$colors->{title_bg_color}'>\n");
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
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	if($config->{os} eq "FreeBSD") {
		push(@tmp, "COMMENT: \\n");
	}
	($width, $height) = split('x', $config->{graph_size}->{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$PNG_DIR" . "$PNG1",
		"--title=$config->{graphs}->{_system1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Load average",
		"--width=$width",
		"--height=$height",
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:load1=$rrd:system_load1:AVERAGE",
		"DEF:load5=$rrd:system_load5:AVERAGE",
		"DEF:load15=$rrd:system_load15:AVERAGE",
		"CDEF:allvalues=load1,load5,load15,+,+",
		@CDEF,
		@tmp,
		"COMMENT: \\n",
		$uptimeline);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$PNG_DIR" . "$PNG1z",
			"--title=$config->{graphs}->{_system1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Load average",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:load1=$rrd:system_load1:AVERAGE",
			"DEF:load5=$rrd:system_load5:AVERAGE",
			"DEF:load15=$rrd:system_load15:AVERAGE",
			"CDEF:allvalues=load1,load5,load15,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /system1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
			else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "'>\n");
		}
	}

	if($title) {
		print("    </td>\n");
		print("    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	@riglim = @{setup_riglim($rigid[1], $limit[1])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:npslp#44AAEE:Sleeping");
	push(@tmp, "AREA:nprun#EE4444:Running");
	push(@tmp, "LINE1:nprun#EE0000");
	push(@tmp, "LINE1:npslp#00EEEE");
	push(@tmp, "LINE1:nproc#EEEE00:Processes");
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$PNG_DIR" . "$PNG2",
		"--title=$config->{graphs}->{_system2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Processes",
		"--width=$width",
		"--height=$height",
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:nproc=$rrd:system_nproc:AVERAGE",
		"DEF:npslp=$rrd:system_npslp:AVERAGE",
		"DEF:nprun=$rrd:system_nprun:AVERAGE",
		"CDEF:allvalues=nproc,npslp,nprun,+,+",
		@CDEF,
		@tmp,
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$PNG_DIR" . "$PNG2z",
			"--title=$config->{graphs}->{_system2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Processes",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:nproc=$rrd:system_nproc:AVERAGE",
			"DEF:npslp=$rrd:system_npslp:AVERAGE",
			"DEF:nprun=$rrd:system_nprun:AVERAGE",
			"CDEF:allvalues=nproc,npslp,nprun,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /system2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
			else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "'>\n");
		}
	}

	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	if($config->{os} eq "Linux") {
		push(@tmp, "AREA:m_mused#EE4444:Used");
		push(@tmp, "AREA:m_mcach#44EE44:Cached");
		push(@tmp, "AREA:m_mbuff#CCCCCC:Buffers");
		push(@tmp, "LINE1:m_mbuff#888888");
		push(@tmp, "LINE1:m_mcach#00EE00");
		push(@tmp, "LINE1:m_mused#EE0000");
	} elsif($config->{os} eq "FreeBSD") {
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
	} elsif($config->{os} eq "OpenBSD" || $config->{os} eq "NetBSD") {
		push(@tmp, "AREA:m_mused#EE4444:Used");
		push(@tmp, "AREA:m_macti#44EE44:Active");
		push(@tmp, "LINE1:m_macti#00EE00");
		push(@tmp, "LINE1:m_mused#EE0000");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$PNG_DIR" . "$PNG3",
		"--title=$config->{graphs}->{_system3} (${total_mem}MB)  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Megabytes",
		"--width=$width",
		"--height=$height",
		"--upper-limit=$total_mem",
		"--lower-limit=0",
		"--base=1024",
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:mtotl=$rrd:system_mtotl:AVERAGE",
		"DEF:mbuff=$rrd:system_mbuff:AVERAGE",
		"DEF:mcach=$rrd:system_mcach:AVERAGE",
		"DEF:mfree=$rrd:system_mfree:AVERAGE",
		"DEF:macti=$rrd:system_macti:AVERAGE",
		"DEF:minac=$rrd:system_minac:AVERAGE",
		"CDEF:m_mtotl=mtotl,1024,/",
		"CDEF:m_mbuff=mbuff,1024,/",
		"CDEF:m_mcach=mcach,1024,/",
		"CDEF:m_mused=m_mtotl,mfree,1024,/,-",
		"CDEF:m_macti=macti,1024,/",
		"CDEF:m_minac=minac,1024,/",
		"CDEF:allvalues=mtotl,mbuff,mcach,mfree,macti,minac,+,+,+,+,+",
		@CDEF,
		@tmp,
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$PNG_DIR" . "$PNG3z",
			"--title=$config->{graphs}->{_system3} (${total_mem}MB)  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Megabytes",
			"--width=$width",
			"--height=$height",
			"--upper-limit=$total_mem",
			"--lower-limit=0",
			"--base=1024",
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:mtotl=$rrd:system_mtotl:AVERAGE",
			"DEF:mbuff=$rrd:system_mbuff:AVERAGE",
			"DEF:mcach=$rrd:system_mcach:AVERAGE",
			"DEF:mfree=$rrd:system_mfree:AVERAGE",
			"DEF:macti=$rrd:system_macti:AVERAGE",
			"DEF:minac=$rrd:system_minac:AVERAGE",
			"CDEF:m_mtotl=mtotl,1024,/",
			"CDEF:m_mbuff=mbuff,1024,/",
			"CDEF:m_mcach=mcach,1024,/",
			"CDEF:m_mused=m_mtotl,mfree,1024,/,-",
			"CDEF:m_macti=macti,1024,/",
			"CDEF:m_minac=minac,1024,/",
			"CDEF:allvalues=mtotl,mbuff,mcach,mfree,macti,minac,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /system3/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
			else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "'>\n");
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

sub get_uptime {
	my $config = shift;
	my $str;
	my $uptime;

	if($config->{os} eq "Linux") {
		open(IN, "/proc/uptime");
		($uptime, undef) = split(' ', <IN>);
		close(IN);
	} elsif($config->{os} eq "FreeBSD") {
		open(IN, "/sbin/sysctl -n kern.boottime |");
		(undef, undef, undef, $uptime) = split(' ', <IN>);
		close(IN);
		$uptime =~ s/,//;
		$uptime = time - int($uptime);
	} elsif($config->{os} eq "OpenBSD" || $config->{os} eq "NetBSD") {
		open(IN, "/sbin/sysctl -n kern.boottime |");
		$uptime = <IN>;
		close(IN);
		chomp($uptime);
		$uptime = time - int($uptime);
	}

	return uptime2str($uptime);
}

1;
