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

package proc;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(proc_init proc_update proc_cgi);

sub proc_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $proc = $config->{proc};

	my $info;
	my @ds;
	my @tmp;
	my $n;

	if(!grep {$_ eq $config->{os}} ("Linux", "FreeBSD")) {
		logger("$myself is not supported yet by your operating system ($config->{os}).");
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
		}
		if(scalar(@ds) / 9 != $proc->{max}) {
			logger("Detected size mismatch between 'max = $proc->{max}' and $rrd (" . scalar(@ds) / 9 . "). Resizing it accordingly. All historic data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
	}

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
		for($n = 0; $n < $proc->{max}; $n++) {
			push(@tmp, "DS:proc" . $n . "_user:GAUGE:120:0:100");
			push(@tmp, "DS:proc" . $n . "_nice:GAUGE:120:0:100");
			push(@tmp, "DS:proc" . $n . "_sys:GAUGE:120:0:100");
			push(@tmp, "DS:proc" . $n . "_idle:GAUGE:120:0:100");
			push(@tmp, "DS:proc" . $n . "_iow:GAUGE:120:0:100");
			push(@tmp, "DS:proc" . $n . "_irq:GAUGE:120:0:100");
			push(@tmp, "DS:proc" . $n . "_sirq:GAUGE:120:0:100");
			push(@tmp, "DS:proc" . $n . "_steal:GAUGE:120:0:100");
			push(@tmp, "DS:proc" . $n . "_guest:GAUGE:120:0:100");
		}
		eval {
			RRDs::create($rrd,
				"--step=60",
				@tmp,
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

	$config->{proc_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub proc_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $proc = $config->{proc};

	my @procs;
	my $total;
	
	my $n;
	my @lastproc;

	my @p;
	my @l;
	my $rrdata = "N";

	# Read last processor usage data
	my $str;
	for($n = 0; $n < $proc->{max}; $n++) {
		$str = "cpu" . $n;
		if($config->{proc_hist}->{$str}) {
			push(@lastproc, $config->{proc_hist}->{$str});
		}
	}

	if($config->{os} eq "Linux") {
		open(IN, "/proc/stat");
		while(<IN>) {
			for($n = 0; $n < $proc->{max}; $n++) {
				$str = "cpu" . $n;
				if(/^cpu$n /) {
					$config->{proc_hist}->{$str} = $_;
					chomp($config->{proc_hist}->{$str});
					push(@procs, $config->{proc_hist}->{$str});
				}
			}
		}
		close(IN);
	} elsif($config->{os} eq "FreeBSD") {
		my $cptimes;
		my @tmp;
		my $from;
		my $to;
		my $ncpu = `sysctl -n hw.ncpu`;
		open(IN, "sysctl -n kern.cp_times |");
		my @data = split(' ', <IN>);
		close(IN);
		chomp($ncpu);
		for($n = 0; $n < $proc->{max}; $n++) {
			$str = "cpu" . $n;
			$from = $n * 5;
			$to = $from + 4;
			@tmp = @data[$from..$to];
			@tmp[0, 1, 2, 3, 4] = @tmp[0, 1, 2, 4, 3];
			$cptimes = join(' ', @tmp);
			chomp($cptimes);
			$cptimes = $str . " " . $cptimes;
			$config->{proc_hist}->{$str} = $cptimes;
			push(@procs, $cptimes);
		}
	}

	my @deltas;
	for($n = 0; $n < $proc->{max}; $n++) {
		if($procs[$n]) {
			@p = split(' ', $procs[$n]);
			@l = (0) x 10;
			@l = split(' ', $lastproc[$n]) if $lastproc[$n];
			@deltas = (

				# $p[0] and $l[0] are the 'cpu' word
				$p[1] - $l[1],	# user
				$p[2] - $l[2],	# nice
				$p[3] - $l[3],	# sys
				$p[4] - $l[4],	# idle
				$p[5] - $l[5],	# iow
				$p[6] - $l[6],	# irq
				$p[7] - $l[7],	# sirq
				$p[8] - $l[8],	# steal
				$p[9] - $l[9],	# guest
			);
			$total = $deltas[0] + $deltas[1] + $deltas[2] + $deltas[3] + $deltas[4] + $deltas[5] + $deltas[6] + $deltas[7] + $deltas[8];

			undef(@p);
			push(@p, $deltas[0] ? ($deltas[0] * 100) / $total : 0);
			push(@p, $deltas[1] ? ($deltas[1] * 100) / $total : 0);
			push(@p, $deltas[2] ? ($deltas[2] * 100) / $total : 0);
			push(@p, $deltas[3] ? ($deltas[3] * 100) / $total : 0);
			push(@p, $deltas[4] ? ($deltas[4] * 100) / $total : 0);
			push(@p, $deltas[5] ? ($deltas[5] * 100) / $total : 0);
			push(@p, $deltas[6] ? ($deltas[6] * 100) / $total : 0);
			push(@p, $deltas[7] ? ($deltas[7] * 100) / $total : 0);
			push(@p, $deltas[8] ? ($deltas[8] * 100) / $total : 0);
			$procs[$n] = join(' ', @p);
		} else {
			$procs[$n] = join(' ', (0, 0, 0, 0, 0, 0, 0, 0, 0));
		}
	}

	for($n = 0; $n < $proc->{max}; $n++) {
		@p = split(' ', $procs[$n]);
		$rrdata .= ":$p[0]:$p[1]:$p[2]:$p[3]:$p[4]:$p[5]:$p[6]:$p[7]:$p[8]";
	}
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub proc_cgi {
	my ($package, $config, $cgi) = @_;

	my $proc = $config->{proc};
	my $kern = $config->{kern};
	my @rigid = split(',', $proc->{rigid});
	my @limit = split(',', $proc->{limit});
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};

	my $u = "";
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
	my $n2;
	my $str;
	my $err;

	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	$title = !$silent ? $title : "";

	if($config->{os} eq "Linux") {
		$ncpu = `grep -w processor /proc/cpuinfo | tail -1 | awk '{ print \$3 }'`;
		chomp($ncpu);
		$ncpu++;
	} elsif($config->{os} eq "FreeBSD") {
		$ncpu = `/sbin/sysctl -n hw.ncpu`;
		chomp($ncpu);
	}
	$ncpu = $ncpu > $proc->{max} ? $proc->{max} : $ncpu;
	return unless $ncpu > 1;


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
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
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
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			printf(" %2d$tf->{tc} ", $time);
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

	for($n = 0; $n < $ncpu; $n++) {
		$str = $u . $package . $n . "." . $tf->{when} . ".png";
		push(@PNG, $str);
		unlink("$PNG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . $package . $n . "z." . $tf->{when} . ".png";
			push(@PNGz, $str);
			unlink("$PNG_DIR" . $str);
		}
	}

	if(trim($rigid[0]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[0]));
	} else {
		if(trim($rigid[0]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[0]));
			push(@riglim, "--rigid");
		}
	}
	$n = 0;
	while($n < $ncpu) {
		if($title) {
			if($n == 0) {
				main::graph_header($title, $proc->{graphs_per_row});
			}
			print("    <tr>\n");
		}
		for($n2 = 0; $n2 < $proc->{graphs_per_row}; $n2++) {
			last unless $n < $ncpu;
			if($title) {
				print("    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
			}
			undef(@tmp);
			undef(@tmpz);
			if(lc($kern->{graph_mode}) eq "r") {
				$vlabel = "Percent (%)";
				if(lc($kern->{list}->{user}) eq "y") {
					push(@tmp, "AREA:user#4444EE:user");
					push(@tmpz, "AREA:user#4444EE:user");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:user:LAST:    Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:user:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:user:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:user:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{nice}) eq "y") {
					push(@tmp, "AREA:nice#EEEE44:nice");
					push(@tmpz, "AREA:nice#EEEE44:nice");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:nice:LAST:    Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{sys}) eq "y") {
					push(@tmp, "AREA:sys#44EEEE:system");
					push(@tmpz, "AREA:sys#44EEEE:system");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:sys:LAST:  Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{iow}) eq "y") {
					push(@tmp, "AREA:iow#EE44EE:I/O wait");
					push(@tmpz, "AREA:iow#EE44EE:I/O wait");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:iow:LAST:Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{irq}) eq "y") {
					push(@tmp, "AREA:irq#888888:IRQ");
					push(@tmpz, "AREA:irq#888888:IRQ");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:irq:LAST:     Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{sirq}) eq "y") {
					push(@tmp, "AREA:sirq#E29136:softIRQ");
					push(@tmpz, "AREA:sirq#E29136:softIRQ");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:sirq:LAST: Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{steal}) eq "y") {
					push(@tmp, "AREA:steal#44EE44:steal");
					push(@tmpz, "AREA:steal#44EE44:steal");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:steal:LAST:   Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{guest}) eq "y") {
					push(@tmp, "AREA:guest#448844:guest");
					push(@tmpz, "AREA:guest#448844:guest");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:guest:LAST:   Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				push(@tmp, "LINE1:guest#1F881F") unless lc($kern->{list}->{guest}) ne "y";
				push(@tmpz, "LINE1:guest#1F881F") unless lc($kern->{list}->{guest}) ne "y";
				push(@tmp, "LINE1:steal#00EE00") unless lc($kern->{list}->{steal}) ne "y";
				push(@tmpz, "LINE1:steal#00EE00") unless lc($kern->{list}->{steal}) ne "y";
				push(@tmp, "LINE1:sirq#D86612") unless lc($kern->{list}->{sirq}) ne "y";
				push(@tmpz, "LINE1:sirq#D86612") unless lc($kern->{list}->{sirq}) ne "y";
				push(@tmp, "LINE1:irq#CCCCCC") unless lc($kern->{list}->{irq}) ne "y";
				push(@tmpz, "LINE1:irq#CCCCCC") unless lc($kern->{list}->{irq}) ne "y";
				push(@tmp, "LINE1:iow#EE00EE") unless lc($kern->{list}->{iow}) ne "y";
				push(@tmpz, "LINE1:iow#EE00EE") unless lc($kern->{list}->{iow}) ne "y";
				push(@tmp, "LINE1:sys#00EEEE") unless lc($kern->{list}->{sys}) ne "y";
				push(@tmpz, "LINE1:sys#00EEEE") unless lc($kern->{list}->{sys}) ne "y";
				push(@tmp, "LINE1:nice#EEEE00") unless lc($kern->{list}->{nice}) ne "y";
				push(@tmpz, "LINE1:nice#EEEE00") unless lc($kern->{list}->{nice}) ne "y";
				push(@tmp, "LINE1:user#0000EE") unless lc($kern->{list}->{user}) ne "y";
				push(@tmpz, "LINE1:user#0000EE") unless lc($kern->{list}->{user}) ne "y";
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
				if(lc($kern->{list}->{guest}) eq "y") {
					push(@tmp, "AREA:s_guest#E29136:guest");
					push(@tmpz, "AREA:s_guest#E29136:guest");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:guest:LAST:   Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:guest:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{steal}) eq "y") {
					push(@tmp, "AREA:s_steal#888888:steal");
					push(@tmpz, "AREA:s_steal#888888:steal");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:steal:LAST:   Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:steal:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{sirq}) eq "y") {
					push(@tmp, "AREA:s_sirq#448844:softIRQ");
					push(@tmpz, "AREA:s_sirq#448844:softIRQ");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:sirq:LAST: Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:sirq:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{irq}) eq "y") {
					push(@tmp, "AREA:s_irq#44EE44:IRQ");
					push(@tmpz, "AREA:s_irq#44EE44:IRQ");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:irq:LAST:     Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:irq:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{iow}) eq "y") {
					push(@tmp, "AREA:s_iow#EE44EE:I/O wait");
					push(@tmpz, "AREA:s_iow#EE44EE:I/O wait");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:iow:LAST:Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:iow:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{sys}) eq "y") {
					push(@tmp, "AREA:s_sys#44EEEE:system");
					push(@tmpz, "AREA:s_sys#44EEEE:system");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:sys:LAST:  Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:sys:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{nice}) eq "y") {
					push(@tmp, "AREA:s_nice#EEEE44:nice");
					push(@tmpz, "AREA:s_nice#EEEE44:nice");
					if(lc($proc->{data}) eq "y") {
						push(@tmp, "GPRINT:nice:LAST:    Cur\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:AVERAGE:  Avg\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:MIN:  Min\\: %4.1lf%%");
						push(@tmp, "GPRINT:nice:MAX:  Max\\: %4.1lf%%\\n");
					}
				}
				if(lc($kern->{list}->{user}) eq "y") {
					push(@tmp, "AREA:user#4444EE:user");
					push(@tmpz, "AREA:user#4444EE:user");
					if(lc($proc->{data}) eq "y") {
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
			($width, $height) = split('x', $config->{graph_size}->{$proc->{size}});
			RRDs::graph("$PNG_DIR" . "$PNG[$n]",
				"--title=$config->{graphs}->{_proc} $n  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@riglim,
				"--lower-limit=0",
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:user=$rrd:proc" . $n . "_user:AVERAGE",
				"DEF:nice=$rrd:proc" . $n . "_nice:AVERAGE",
				"DEF:sys=$rrd:proc" . $n . "_sys:AVERAGE",
				"DEF:iow=$rrd:proc" . $n . "_iow:AVERAGE",
				"DEF:irq=$rrd:proc" . $n . "_irq:AVERAGE",
				"DEF:sirq=$rrd:proc" . $n . "_sirq:AVERAGE",
				"DEF:steal=$rrd:proc" . $n . "_steal:AVERAGE",
				"DEF:guest=$rrd:proc" . $n . "_guest:AVERAGE",
				@tmp);
			$err = RRDs::error;
			print("ERROR: while graphing $PNG_DIR" . "$PNG[$n]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				RRDs::graph("$PNG_DIR" . "$PNGz[$n]",
					"--title=$config->{graphs}->{_proc} $n  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=PNG",
					"--vertical-label=$vlabel",
					"--width=$width",
					"--height=$height",
					@riglim,
					"--lower-limit=0",
					@{$cgi->{version12}},
					@{$cgi->{version12_small}},
					@{$colors->{graph_colors}},
					"DEF:user=$rrd:proc" . $n . "_user:AVERAGE",
					"DEF:nice=$rrd:proc" . $n . "_nice:AVERAGE",
					"DEF:sys=$rrd:proc" . $n . "_sys:AVERAGE",
					"DEF:iow=$rrd:proc" . $n . "_iow:AVERAGE",
					"DEF:irq=$rrd:proc" . $n . "_irq:AVERAGE",
					"DEF:sirq=$rrd:proc" . $n . "_sirq:AVERAGE",
					"DEF:steal=$rrd:proc" . $n . "_steal:AVERAGE",
					"DEF:guest=$rrd:proc" . $n . "_guest:AVERAGE",
					@tmpz);
				$err = RRDs::error;
				print("ERROR: while graphing $PNG_DIR" . "$PNGz[$n]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /proc$n/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNGz[$n] . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$n] . "' border='0'></a>\n");
					}
					else {
						print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNGz[$n] . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$n] . "' border='0'></a>\n");
					}
				} else {
					print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG[$n] . "'>\n");
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
		main::graph_footer();
	}
	print("  <br>\n");
	return;
}

1;
