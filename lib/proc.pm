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
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

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
			if(index($key, 'rra[') == 0) {
				if(index($key, '.rows') != -1) {
					push(@rra, substr($key, 4, index($key, ']') - 4));
				}
			}
		}
		if(scalar(@ds) / 9 != $proc->{max}) {
			logger("$myself: Detected size mismatch between 'max = $proc->{max}' and $rrd (" . scalar(@ds) / 9 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		$ncpu = min($ncpu, $proc->{max});
		for($n = 0; $n < $ncpu; $n++) {
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
				($p[1] || 0) - ($l[1] || 0),	# user
				($p[2] || 0) - ($l[2] || 0),	# nice
				($p[3] || 0) - ($l[3] || 0),	# sys
				($p[4] || 0) - ($l[4] || 0),	# idle
				($p[5] || 0) - ($l[5] || 0),	# iow
				($p[6] || 0) - ($l[6] || 0),	# irq
				($p[7] || 0) - ($l[7] || 0),	# sirq
				($p[8] || 0) - ($l[8] || 0),	# steal
				($p[9] || 0) - ($l[9] || 0),	# guest
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
	my @output;

	my $proc = $config->{proc};
	my $kern = $config->{kern};
	my @rigid = split(',', ($proc->{rigid} || ""));
	my @limit = split(',', ($proc->{limit} || ""));
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
	my $vlabel;
	my $ncpu;
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

	if($config->{os} eq "Linux") {
		$ncpu = `grep -e '^processor[[:space:]]*: [0-9]*' /proc/cpuinfo | tail -1 | awk '{ print \$3 }'`;
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
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		for($n = 0; $n < $ncpu; $n++) {
			push(@output, "       Processor " . sprintf("%3d", $n) . "                                   ");
		}
		push(@output, "\nTime");
		for($n = 0; $n < $ncpu; $n++) {
			push(@output, "   User  Nice   Sys  Idle  I/Ow   IRQ  sIRQ Steal Guest");
		}
		push(@output, " \n----");
		for($n = 0; $n < $ncpu; $n++) {
			push(@output, "-------------------------------------------------------");
		}
		push(@output, " \n");
		my $line;
		my @row;
		my $time;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			for($n2 = 0; $n2 < $ncpu; $n2++) {
				$from = $n2 * $ncpu;
				$to = $from + $ncpu;
				my ($usr, $nic, $sys, $idle, $iow, $irq, $sirq, $steal, $guest,) = @$line[$from..$to];
				@row = ($usr, $nic, $sys, $idle, $iow, $irq, $sirq, $steal, $guest);
				push(@output, sprintf(" %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%% ", @row));
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

	for($n = 0; $n < $ncpu; $n++) {
		$str = $u . $package . $n . "." . $tf->{when} . ".$imgfmt_lc";
		push(@IMG, $str);
		unlink("$IMG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . $package . $n . "z." . $tf->{when} . ".$imgfmt_lc";
			push(@IMGz, $str);
			unlink("$IMG_DIR" . $str);
		}
	}

	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	$n = 0;
	while($n < $ncpu) {
		if($title) {
			if($n == 0) {
				push(@output, main::graph_header($title, $proc->{graphs_per_row}));
			}
			push(@output, "    <tr>\n");
		}
		for($n2 = 0; $n2 < $proc->{graphs_per_row}; $n2++) {
			last unless $n < $ncpu;
			if($title) {
				push(@output, "    <td>\n");
			}
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
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
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}

			($width, $height) = split('x', $config->{graph_size}->{$proc->{size}});
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$n]",
				"--title=$config->{graphs}->{_proc} $n  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:user=$rrd:proc" . $n . "_user:AVERAGE",
				"DEF:nice=$rrd:proc" . $n . "_nice:AVERAGE",
				"DEF:sys=$rrd:proc" . $n . "_sys:AVERAGE",
				"DEF:iow=$rrd:proc" . $n . "_iow:AVERAGE",
				"DEF:irq=$rrd:proc" . $n . "_irq:AVERAGE",
				"DEF:sirq=$rrd:proc" . $n . "_sirq:AVERAGE",
				"DEF:steal=$rrd:proc" . $n . "_steal:AVERAGE",
				"DEF:guest=$rrd:proc" . $n . "_guest:AVERAGE",
				"CDEF:allvalues=user,nice,sys,iow,irq,sirq,steal,guest,+,+,+,+,+,+,+",
				@CDEF,
				@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$n]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$n]",
					"--title=$config->{graphs}->{_proc} $n  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=$vlabel",
					"--width=$width",
					"--height=$height",
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$colors->{graph_colors}},
					"DEF:user=$rrd:proc" . $n . "_user:AVERAGE",
					"DEF:nice=$rrd:proc" . $n . "_nice:AVERAGE",
					"DEF:sys=$rrd:proc" . $n . "_sys:AVERAGE",
					"DEF:iow=$rrd:proc" . $n . "_iow:AVERAGE",
					"DEF:irq=$rrd:proc" . $n . "_irq:AVERAGE",
					"DEF:sirq=$rrd:proc" . $n . "_sirq:AVERAGE",
					"DEF:steal=$rrd:proc" . $n . "_steal:AVERAGE",
					"DEF:guest=$rrd:proc" . $n . "_guest:AVERAGE",
					"CDEF:allvalues=user,nice,sys,iow,irq,sirq,steal,guest,+,+,+,+,+,+,+",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$n]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /proc$n/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$n] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$n] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n] . "'>\n");
				}
			}
			if($title) {
				push(@output, "    </td>\n");
			}
			$n++;
		}
		if($title) {
			push(@output, "    </tr>\n");
		}
	}
	if($title) {
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
