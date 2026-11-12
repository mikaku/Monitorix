#
# amdgpu_top: a Monitorix module monitoring all time-series values provided
#             by the JSON output of the 'amdgpu_top' tool (-J -n 1).
#
# Written for Monitorix - https://monitorix.org
#
# Copyright (C) 2026 by Joachim von Thadden <thadden@web.de>
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

package amdgpu_top;

use strict;
use warnings;
use Monitorix;
use RRDs;
use JSON::PP;
use Exporter 'import';
our @EXPORT = qw(amdgpu_top_init amdgpu_top_update amdgpu_top_cgi);

my $max_number_of_gpus = 8;	# Changing this number destroys history.

# ---------------------------------------------------------------------------
# value helpers
# ---------------------------------------------------------------------------

# sanitize to plain number or undef
sub num {
	my ($v) = @_;
	return undef unless defined($v);
	return undef if(ref($v));
	return undef unless($v =~ /^-?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?$/);
	my $n = $v + 0;
	return undef if($n != $n);			# NaN
	return undef if($n == 9**9**9 || $n == -(9**9**9));
	return $n;
}

# numeric value of a {"unit": "...", "value": N} pair
sub uval {
	my ($node) = @_;
	return undef unless ref($node) eq "HASH";
	return num($node->{value});
}

# average of positive array values (0 = absent sensor); undef if none
sub avg_positive {
	my ($list) = @_;
	return undef unless ref($list) eq "ARRAY";
	my @v = grep { defined($_) && $_ > 0 } map { num($_) } @{$list};
	return undef unless scalar(@v);
	my $s = 0;
	$s += $_ for (@v);
	return $s / scalar(@v);
}

# average/max over "CPU Core freq" array entries {cur_freq => N}
sub cpu_freq_stat {
	my ($dev, $mode) = @_;
	my $arr = $dev->{"Sensors"}->{"CPU Core freq"};
	return undef unless ref($arr) eq "ARRAY";
	my @v = grep { defined($_) } map { num($_->{cur_freq}) } @{$arr};
	return undef unless scalar(@v);
	if($mode eq "max") {
		my $m = $v[0];
		foreach (@v) { $m = $_ if($_ > $m) }
		return $m;
	}
	my $s = 0;
	$s += $_ for (@v);
	return $s / scalar(@v);
}

sub gm {
	my ($dev, $key, $div) = @_;
	my $v = num($dev->{"gpu_metrics"}->{$key});
	return undef unless defined($v);
	return $v / $div if($div);
	return $v;
}

# ---------------------------------------------------------------------------
# DS spec: ordered list of [ ds-suffix, extractor ]; the suffix keeps the
# full name "e<k>d<n>_<suffix>" within RRD's 19-character DS name limit.
# The order defines the RRD data source creation order! (79 entries)
# ---------------------------------------------------------------------------
my @DSPEC = (
	# --- gpu_activity (3) ---
	["act_gfx",     sub { uval($_[0]{gpu_activity}{GFX}) }],
	["act_media",   sub { uval($_[0]{gpu_activity}{MediaEngine}) }],
	["act_mem",     sub { uval($_[0]{gpu_activity}{Memory}) }],

	# --- GRBM performance counters (8) ---
	["g_pipe",      sub { uval($_[0]{GRBM}{"Graphics Pipe"}) }],
	["t_pipe",      sub { uval($_[0]{GRBM}{"Texture Pipe"}) }],
	["prim_asm",    sub { uval($_[0]{GRBM}{"Primitive Assembly"}) }],
	["sh_export",   sub { uval($_[0]{GRBM}{"Shader Export"}) }],
	["sh_interp",   sub { uval($_[0]{GRBM}{"Shader Processor Interpolator"}) }],
	["color_blk",   sub { uval($_[0]{GRBM}{"Color Block"}) }],
	["depth_blk",   sub { uval($_[0]{GRBM}{"Depth Block"}) }],
	["geom_eng",    sub { uval($_[0]{GRBM}{"Geometry Engine"}) }],

	# --- GRBM2 performance counters (9) - note the double spaces in keys! ---
	["cp_gfx",      sub { uval($_[0]{GRBM2}{"Command Processor - Graphics"}) }],
	["cp_comp",     sub { uval($_[0]{GRBM2}{"Command Processor -  Compute"}) }],
	["cp_fetch",    sub { uval($_[0]{GRBM2}{"Command Processor -  Fetcher"}) }],
	["eff_arb",     sub { uval($_[0]{GRBM2}{"Efficiency Arbiter"}) }],
	["ring_ctrl",   sub { uval($_[0]{GRBM2}{"Ring List Controller"}) }],
	["sdma",        sub { uval($_[0]{GRBM2}{"SDMA"}) }],
	["tex_cache",   sub { uval($_[0]{GRBM2}{"Texture Cache per Pipe"}) }],
	["rb_memif",    sub { uval($_[0]{GRBM2}{"Render Backend Memory Interface"}) }],
	["utc_l2",      sub { uval($_[0]{GRBM2}{"Unified Translation Cache Level-2"}) }],

	# --- Sensors: temperatures (10) ---
	["t_edge",      sub { uval($_[0]{Sensors}{"Edge Temperature"}) }],
	["t_junc",      sub { uval($_[0]{Sensors}{"Junction Temperature"}) }],
	["t_mem",       sub { uval($_[0]{Sensors}{"Memory Temperature"}) }],
	["t_tctl",      sub { uval($_[0]{Sensors}{"CPU Tctl"}) }],
	["t_edg_crit",  sub { uval($_[0]{Sensors}{"Edge Critical Temperature"}) }],
	["t_jnc_crit",  sub { uval($_[0]{Sensors}{"Junction Critical Temperature"}) }],
	["t_mem_crit",  sub { uval($_[0]{Sensors}{"Memory Critical Temperature"}) }],
	["t_edg_emer",  sub { uval($_[0]{Sensors}{"Edge Emergency Temperature"}) }],
	["t_jnc_emer",  sub { uval($_[0]{Sensors}{"Junction Emergency Temperature"}) }],
	["t_mem_emer",  sub { uval($_[0]{Sensors}{"Memory Emergency Temperature"}) }],

	# --- Sensors: power (3) ---
	["p_avg",       sub { uval($_[0]{Sensors}{"Average Power"}) }],
	["p_input",     sub { uval($_[0]{Sensors}{"Input Power"}) }],
	["p_gfx",       sub { uval($_[0]{Sensors}{"GFX Power"}) }],

	# --- Sensors: clocks (2) ---
	["sclk",        sub { uval($_[0]{Sensors}{"GFX_SCLK"}) }],
	["mclk",        sub { uval($_[0]{Sensors}{"GFX_MCLK"}) }],

	# --- Sensors: voltage (2) ---
	["vddgfx",      sub { uval($_[0]{Sensors}{VDDGFX}) }],
	["vddnb",       sub { uval($_[0]{Sensors}{VDDNB}) }],

	# --- Sensors: fan / PCIe (2) ---
	["fan",         sub { uval($_[0]{Sensors}{Fan}) }],
	["pcie_lsp",    sub { uval($_[0]{Sensors}{"PCIe Link Speed"}) }],

	# --- Sensors: CPU core frequency array (2) ---
	["cpu_favg",    sub { cpu_freq_stat($_[0], "avg") }],
	["cpu_fmax",    sub { cpu_freq_stat($_[0], "max") }],

	# --- VRAM (4) ---
	["vram_tot",    sub { uval($_[0]{VRAM}{"Total VRAM"}) }],
	["vram_use",    sub { uval($_[0]{VRAM}{"Total VRAM Usage"}) }],
	["gtt_tot",     sub { uval($_[0]{VRAM}{"Total GTT"}) }],
	["gtt_use",     sub { uval($_[0]{VRAM}{"Total GTT Usage"}) }],

	# --- gpu_metrics: temperatures (7), raw values are x100 degC;
	#     temperature_core is an array with 0 = absent on APUs ---
	["gm_t_gfx",    sub { gm($_[0], "temperature_gfx", 100) }],
	["gm_t_soc",    sub { gm($_[0], "temperature_soc", 100) }],
	["gm_t_edge",   sub { gm($_[0], "temperature_edge", 100) }],
	["gm_t_hot",    sub { gm($_[0], "temperature_hotspot", 100) }],
	["gm_t_mem",    sub { gm($_[0], "temperature_mem", 100) }],
	["gm_t_l3",     sub { gm($_[0], "temperature_l3", 100) }],
	["gm_t_core",   sub { my $a = avg_positive($_[0]{gpu_metrics}{temperature_core});
	                      defined($a) ? $a / 100 : undef }],

	# --- gpu_metrics: average frequencies (6), MHz ---
	["gm_agfxclk",  sub { gm($_[0], "average_gfxclk_frequency", 0) }],
	["gm_afclk",    sub { gm($_[0], "average_fclk_frequency", 0) }],
	["gm_auclk",    sub { gm($_[0], "average_uclk_frequency", 0) }],
	["gm_asocclk",  sub { gm($_[0], "average_socclk_frequency", 0) }],
	["gm_avclk",    sub { gm($_[0], "average_vclk_frequency", 0) }],
	["gm_adclk",    sub { gm($_[0], "average_dclk_frequency", 0) }],

	# --- gpu_metrics: average powers (4), raw mW -> W ---
	["gm_p_sock",   sub { gm($_[0], "average_socket_power", 1000) }],
	["gm_p_cpu",    sub { gm($_[0], "average_cpu_power", 1000) }],
	["gm_p_gfx",    sub { gm($_[0], "average_gfx_power", 1000) }],
	["gm_p_soc",    sub { gm($_[0], "average_soc_power", 1000) }],

	# --- gpu_metrics: voltages (3), mV ---
	["gm_v_gfx",    sub { gm($_[0], "voltage_gfx", 0) }],
	["gm_v_soc",    sub { gm($_[0], "voltage_soc", 0) }],
	["gm_v_mem",    sub { gm($_[0], "voltage_mem", 0) }],

	# --- gpu_metrics: fan (1) ---
	["gm_fan_pwm",  sub { gm($_[0], "fan_pwm", 0) }],

	# --- fdinfo totals (12) + process count (1) ---
	["fd_cpu",      sub { uval($_[0]{"Total fdinfo"}{CPU}) }],
	["fd_comp",     sub { uval($_[0]{"Total fdinfo"}{Compute}) }],
	["fd_dma",      sub { uval($_[0]{"Total fdinfo"}{DMA}) }],
	["fd_dec",      sub { uval($_[0]{"Total fdinfo"}{Decode}) }],
	["fd_enc",      sub { uval($_[0]{"Total fdinfo"}{Encode}) }],
	["fd_gfx",      sub { uval($_[0]{"Total fdinfo"}{GFX}) }],
	["fd_media",    sub { uval($_[0]{"Total fdinfo"}{Media}) }],
	["fd_jpeg",     sub { uval($_[0]{"Total fdinfo"}{VCN_JPEG}) }],
	["fd_vcn",      sub { uval($_[0]{"Total fdinfo"}{VCN_Unified}) }],
	["fd_vpe",      sub { uval($_[0]{"Total fdinfo"}{VPE}) }],
	["fd_vram",     sub { uval($_[0]{"Total fdinfo"}{VRAM}) }],
	["fd_gtt",      sub { uval($_[0]{"Total fdinfo"}{GTT}) }],
	["proc_count",  sub { ref($_[0]{fdinfo}) eq "HASH" ? scalar(keys(%{$_[0]{fdinfo}})) : undef }],
);

my $number_of_values_per_gpu_in_rrd = scalar(@DSPEC);	# 79

# ---------------------------------------------------------------------------
# collect_json(cmd => ..., no_pc => 0|1, file => path) -> ($data, $error)
#
# One-shot invocation of amdgpu_top; '-n 1' must be part of cmd so the
# command terminates on its own. With 'file' the JSON document is read from
# that file instead (offline tests / dry runs).
# Returns the decoded document or an error.
# ---------------------------------------------------------------------------
sub collect_json {
	my ($myself, %o) = @_;

	my $raw;

	if($o{file}) {
		my $fh;
		unless(open($fh, "<", $o{file})) {
			return (undef, "unable to open '$o{file}': $!");
		}
		{
			local $/;
			$raw = <$fh>;
		}
		close($fh);
	}
	else {
		my $cmd = $o{cmd} || "amdgpu_top -J -n 1";
		my $cmd_timeout = (defined($o{timeout}) && $o{timeout} =~ /^\d+$/ && $o{timeout} > 0) ? $o{timeout} : 30;
		my @argv = (split(/\s+/, $cmd), ($o{no_pc} ? ("--no-pc") : ()));

		logger("$myself: executing '" . join(" ", @argv) . "'.") if $o{debug};

		# 'amdgpu_top' talks directly to the DRM ioctls and may block
		# indefinitely on a wedged GPU/driver (GPU reset, firmware hang).
		# Since the Monitorix update loop runs modules sequentially, such a
		# hang would stall the whole daemon - so enforce a hard timeout.
		my $fh;
		my $child = open($fh, "-|", @argv);
		unless(defined($child)) {
			return (undef, "unable to execute '" . join(" ", @argv) . "': $!");
		}

		my $timed_out = 0;
		eval {
			local $SIG{ALRM} = sub { $timed_out = 1; die };
			alarm($cmd_timeout);
			local $/;
			$raw = <$fh>;
			alarm(0);
			1;
		} or do {
			alarm(0);
			kill("SIGKILL", $child);
			waitpid($child, 0);
			close($fh);
			return (undef, $timed_out ?
				"'" . join(" ", @argv) . "' timed out after $cmd_timeout seconds (GPU or driver unresponsive?)" :
				"while reading from '" . join(" ", @argv) . "': $@");
		};
		unless(close($fh)) {
			return (undef, "'" . join(" ", @argv) . "' exited with status " . ($? >> 8));
		}
	}

	return (undef, "empty output") unless(defined($raw) && length($raw));

	my $data = eval { decode_json($raw) };
	if($@ || !defined($data)) {
		return (undef, "JSON parse error: " . ($@ || "undefined result"));
	}
	unless(ref($data) eq "HASH" && ref($data->{devices}) eq "ARRAY") {
		if(ref($data) eq "ARRAY") {	# normalize '--dump' style output
			return ({ devices => $data }, undef);
		}
		return (undef, "unexpected JSON structure");
	}
	return ($data, undef);
}

# extract_values($device_hashref) -> hashref { ds_suffix => number|undef }
sub extract_values {
	my ($dev) = @_;
	return undef unless ref($dev) eq "HASH";
	my %v;
	foreach my $s (@DSPEC) {
		my $val = eval { $s->[1]->($dev) };
		$v{$s->[0]} = num($val);
	}
	return \%v;
}

# ordered list of DS suffixes (public helper for the test harnesses)
sub ds_names {
	return map { $_->[0] } @DSPEC;
}

# ---------------------------------------------------------------------------
# module init
# ---------------------------------------------------------------------------
sub amdgpu_top_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $amdgpu_top = $config->{amdgpu_top};

	my $info;
	my @ds;
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

	if(!keys(%{$amdgpu_top->{list}})) {
		logger("$myself: ERROR: no <list>...</list> defined.");
		return;
	}

	# option defaults
	if(!defined($amdgpu_top->{cmd})) {
		$amdgpu_top->{cmd} = "amdgpu_top -J -n 1";
	}
	if(!defined($amdgpu_top->{cmd_timeout}) || $amdgpu_top->{cmd_timeout} !~ /^\d+$/ || $amdgpu_top->{cmd_timeout} == 0) {
		$amdgpu_top->{cmd_timeout} = 30;
	}

	# checks if the command works and returns parseable JSON
	{
		my ($data, $err) = collect_json($myself,
			cmd     => $amdgpu_top->{cmd},
			file    => $amdgpu_top->{file},
			timeout => $amdgpu_top->{cmd_timeout},
			no_pc   => lc($amdgpu_top->{no_pc} || "") eq "y" ? 1 : 0);
		if($err) {
			logger("$myself: ERROR: $err");
			return;
		}
		if(!scalar(@{$data->{devices}})) {
			logger("$myself: ERROR: amdgpu_top returned no AMD GPU device.");
			return;
		}
	}

	# total number of device slots over all groups
	my $total_number_of_gpus = 0;
	foreach my $k (sort keys %{$amdgpu_top->{list}}) {
		my @gpu_group = split(/\s*,\s*/, $amdgpu_top->{list}->{$k});
		$total_number_of_gpus += ($max_number_of_gpus < scalar(@gpu_group) ? $max_number_of_gpus : scalar(@gpu_group));
		if($max_number_of_gpus < scalar(@gpu_group)) {
			logger("$myself: WARNING: group $k has more than $max_number_of_gpus devices, only the first $max_number_of_gpus will be monitored.");
		}
	}

	if(-e $rrd) {
		my $rrd_n_values = 0;
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'ds[') == 0) {
				push(@ds, substr($key, 3, index($key, ']') - 3)) if(index($key, '.type') != -1);
				$rrd_n_values++ if(index($key, '.index') != -1);
			}
			if(index($key, 'rra[') == 0) {
				push(@rra, substr($key, 4, index($key, ']') - 4)) if(index($key, '.rows') != -1);
			}
		}
		if($rrd_n_values != $total_number_of_gpus * $number_of_values_per_gpu_in_rrd) {
			logger("$myself: Detected size mismatch between <list>...</list> (" . ($total_number_of_gpus * $number_of_values_per_gpu_in_rrd) . ") and $rrd (" . $rrd_n_values . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if(scalar(@rra) < 12 + (4 * $config->{max_historic_years})) {
			logger("$myself: Detected size mismatch between 'max_historic_years' (" . $config->{max_historic_years} . ") and $rrd (" . ((scalar(@rra) - 12) / 4) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		my @group_keys = sort keys %{$amdgpu_top->{list}};
		for(my $k = 0; $k < scalar(@group_keys); $k++) {
			my @gpu_group = split(/\s*,\s*/, $amdgpu_top->{list}->{$group_keys[$k]});
			for($n = 0; $n < scalar(@gpu_group) && $n < $max_number_of_gpus; $n++) {
				foreach my $s (@DSPEC) {
					# temperature DS allow negative values (min U), the
					# others cannot go below zero
					my $min = ($s->[0] =~ /^gm_t_/ || ($s->[0] =~ /^t_/ && $s->[0] ne "t_pipe")) ? "U" : "0";
					push(@tmp, "DS:e" . $k . "d" . $n . "_" . $s->[0] . ":GAUGE:120:" . $min . ":U");
				}
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

	$config->{amdgpu_top_hist} = ();
	push(@{$config->{func_update}}, $package);

	logger("$myself: Ok") if $debug;
}

# ---------------------------------------------------------------------------
# module update (called every minute by the Monitorix daemon)
# ---------------------------------------------------------------------------
sub amdgpu_top_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $amdgpu_top = $config->{amdgpu_top};

	my $use_nan_for_missing_data = lc($amdgpu_top->{use_nan_for_missing_data} || "") eq "y" ? 1 : 0;
	my $fill = $use_nan_for_missing_data ? "U" : "0";

	my ($data, $err) = collect_json($myself,
		cmd     => $amdgpu_top->{cmd},
		file    => $amdgpu_top->{file},
		timeout => $amdgpu_top->{cmd_timeout},
		no_pc   => lc($amdgpu_top->{no_pc} || "") eq "y" ? 1 : 0,
		debug   => $debug);

	if($err) {
		logger("$myself: WARNING: $err; writing missing values instead.");
	}

	my $devices = ref($data) eq "HASH" ? $data->{devices} : [];

	my $rrdata = "N";
	my %extract_cache;

	# iteration order must be identical to the RRD creation order in _init!
	my @group_keys = sort keys %{$amdgpu_top->{list}};
	for(my $k = 0; $k < scalar(@group_keys); $k++) {
		my @gpu_group = split(/\s*,\s*/, $amdgpu_top->{list}->{$group_keys[$k]});
		for(my $n = 0; $n < scalar(@gpu_group) && $n < $max_number_of_gpus; $n++) {
			# NOTE: do not use trim() here - Monitorix' trim() returns an
			# empty string for the (valid) device index "0".
			my $idx = defined($gpu_group[$n]) ? $gpu_group[$n] : "";
			$idx =~ s/^\s+//;
			$idx =~ s/\s+$//;
			$idx =~ s/^["']//;
			$idx =~ s/["']$//;

			my $vals;
			if($idx =~ /^\d+$/) {
				if(exists($extract_cache{$idx})) {
					$vals = $extract_cache{$idx};
				}
				else {
					$vals = extract_values($devices->[$idx]);
					$extract_cache{$idx} = $vals;
					if(!defined($vals) && defined($data)) {
						logger("$myself: WARNING: device index $idx not found in amdgpu_top output (group " . $group_keys[$k] . ").");
					}
				}
			}
			else {
				logger("$myself: ERROR: invalid device index '$gpu_group[$n]' in group " . $group_keys[$k] . ".");
			}

			foreach my $s (@DSPEC) {
				my $v = defined($vals) ? $vals->{$s->[0]} : undef;
				$rrdata .= ":" . (defined($v) ? $v : $fill);
			}
		}
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $rrderr = RRDs::error;
	logger("ERROR: while updating $rrd: $rrderr") if $rrderr;
}

# ---------------------------------------------------------------------------
# CGI mode
# ---------------------------------------------------------------------------

# map DS suffix -> position inside the per-device block of the RRD
my %DS_INDEX;
{
	my $i = 0;
	$DS_INDEX{$_->[0]} = $i++ foreach (@DSPEC);
}

# best-effort static device information for the text mode
# ('amdgpu_top -J --dump' terminates immediately; the CGI runs as an
# unprivileged user, so any failure is silently ignored)
sub collect_info {
	my ($config) = @_;

	my $cmd = $config->{amdgpu_top}->{cmd} || "amdgpu_top -J -n 1";
	my ($bin) = split(/\s+/, $cmd);
	$bin = "amdgpu_top" unless $bin;

	my ($data, $err) = collect_json("amdgpu_top_cgi",
		cmd     => "$bin -J --dump",
		timeout => $config->{amdgpu_top}->{cmd_timeout} || 30);
	return () if($err || ref($data) ne "HASH");

	my @lines;
	my $i = 0;
	foreach my $dev (@{$data->{devices}}) {
		next unless ref($dev) eq "HASH";
		# '--dump' flattens the 'Info' object into the device hash
		my $val = sub {
			my ($k) = @_;
			my $v = ref($dev->{Info}) eq "HASH" ? $dev->{Info}{$k} : undef;
			$v = $dev->{$k} unless defined($v);
			return $v;
		};
		my $av  = ref($dev->{amdgpu_top_version}) eq "HASH" ?
			"amdgpu_top " . join(".", map { $dev->{amdgpu_top_version}{$_} // 0 } qw(major minor patch)) : "";
		my $drm_h = $val->("drm_version");
		my $drm = ref($drm_h) eq "HASH" ?
			"drm " . join(".", map { $drm_h->{$_} // 0 } qw(major minor patchlevel)) : "";
		my $vram_sz = $val->("VRAM Size");
		$vram_sz = sprintf("%d MiB", $vram_sz / 1048576) if defined($vram_sz) && $vram_sz =~ /^\d+$/;

		my $label = amdgpu_top_dev_label($config, $i);
		push(@lines, sprintf("%s: %s (%s, %s, %s)", $label,
			$val->("DeviceName") // "?",
			$val->("ASIC Name")  // "?",
			$val->("GPU Type")   // "?",
			$val->("gfx_target_version") // "?"));
		push(@lines, sprintf("     VRAM: %s %s (%s bit) | CUs: %s | %s | %s",
			$vram_sz // "?",
			$val->("VRAM Type") // "?",
			$val->("VRAM Bit width") // "?",
			$val->("Total Compute Unit") // "?",
			$drm, $av));
		$i++;
	}
	return @lines;
}

sub amdgpu_top_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $amdgpu_top = $config->{amdgpu_top};
	my @rigid = split(',', ($amdgpu_top->{rigid} || ""));
	my @limit = split(',', ($amdgpu_top->{limit} || ""));
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};
	my $zoom = $config->{global_zoom};
	my %rrd = (
		'new' => \&RRDs::graphv,
		'old' => \&RRDs::graph,
		);
	my $version = "new";
	my @full_size_mode;
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
	my $n;
	my $n2;
	my $n_plot;
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
		"#FF8800",
		"#00B4B4",
		"#88CC44",
	);

	my $show_current_values = lc($amdgpu_top->{show_current_values} || "") eq "y" ? 1 : 0;

	$version = "old" if version->declare($RRDs::VERSION)->numify < version->declare(1.3)->numify;
	push(@full_size_mode, "--full-size-mode") if version->declare($RRDs::VERSION)->numify > version->declare(1.3)->numify;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $IMG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};
	my $imgfmt_uc = uc($config->{image_format});
	my $imgfmt_lc = lc($config->{image_format});
	foreach my $i (split(',', $config->{rrdtool_extra_options} || "")) {
		push(@extra, trim($i)) if trim($i);
	}

	$title = !$silent ? $title : "";

	# panel definitions (see docs/plan.md section 2.3): vertical axis
	# label, legend number format and the DS suffixes with legend labels.
	# An optional third element forces the draw style (and color) of a DS.
	my @PANELS = (
		{ vl => "Percent (%)", fmt => "%5.1lf%%", metrics => [
			["act_gfx",    "GFX"],
			["act_media",  "Media"],
			["act_mem",    "Memory"],
			["fd_gfx",     "fd GFX"],
			["fd_cpu",     "fd CPU"],
			["fd_comp",    "fd Compute"],
			["fd_dma",     "fd DMA"],
			["fd_media",   "fd Media"],
		]},
		{ vl => "Watt", fmt => "%6.1lf", metrics => [
			["p_avg",      "Average"],
			["p_input",    "Input"],
			["p_gfx",      "GFX"],
			["gm_p_sock",  "GM Socket"],
		]},
		{ vl => "MiB", fmt => "%8.0lf", metrics => [
			# capacity backdrops: the larger total (GTT, host memory) is
			# drawn first so the smaller one (VRAM) stays visible on top
			["gtt_tot",    "GTT total",  "LINE1:#7B7BB4:dashes"],
			["vram_tot",   "VRAM total", "LINE1:#9A9A9A:dashes"],
			["vram_use",   "VRAM used",  "LINE2"],
			["gtt_use",    "GTT used",   "LINE2"],
		]},
		{ vl => "Percent (%)", fmt => "%5.1lf%%", metrics => [
			["g_pipe",     "Graphics Pipe"],
			["t_pipe",     "Texture Pipe"],
			["prim_asm",   "Primitive Asm"],
			["sh_export",  "Shader Export"],
			["sh_interp",  "Shader Interpol"],
			["color_blk",  "Color Block"],
			["depth_blk",  "Depth Block"],
			["geom_eng",   "Geometry Engine"],
		]},
		{ vl => "Percent (%)", fmt => "%5.1lf%%", metrics => [
			["cp_gfx",     "Cmd Proc GFX"],
			["cp_comp",    "Cmd Proc Comp"],
			["cp_fetch",   "Cmd Proc Fetch"],
			["eff_arb",    "Efficiency Arb"],
			["ring_ctrl",  "Ring List Ctrl"],
			["sdma",       "SDMA"],
			["tex_cache",  "Tex Cache/Pipe"],
			["rb_memif",   "RB Mem If"],
			["utc_l2",     "UTC Level-2"],
		]},
		{ vl => "Celsius", fmt => "%5.1lf", temp => 1, metrics => [
			["t_edge",     "Edge"],
			["t_junc",     "Junction"],
			["t_mem",      "Memory"],
			["t_tctl",     "CPU Tctl"],
			["gm_t_gfx",   "GM GFX"],
			["gm_t_soc",   "GM SOC"],
			["gm_t_core",  "GM Core avg"],
			["gm_t_hot",   "GM Hotspot"],
		]},
		{ vl => "MHz", fmt => "%6.0lf", metrics => [
			["sclk",       "SCLK"],
			["mclk",       "MCLK"],
			["gm_agfxclk", "GM avg GFXclk"],
			["gm_afclk",   "GM avg FCLK"],
			["gm_auclk",   "GM avg UCLK"],
			["gm_asocclk", "GM avg SOCclk"],
		]},
		{ vl => "Millivolt (mV)", fmt => "%6.1lf", metrics => [
			["vddgfx",     "VDDGFX"],
			["vddnb",      "VDDNB"],
			["gm_v_gfx",   "GM GFX"],
			["gm_v_soc",   "GM SOC"],
			["gm_v_mem",   "GM Mem"],
		]},
		{ vl => "Percent (%)", fmt => "%5.1lf%%", metrics => [
			["fan",        "Fan"],
			["gm_fan_pwm", "GM fan PWM"],
		]},
		{ vl => "Percent (%)", fmt => "%5.1lf%%", metrics => [
			["fd_dec",     "Decode"],
			["fd_enc",     "Encode"],
			["fd_media",   "Media"],
			["fd_jpeg",    "JPEG"],
			["fd_vcn",     "VCN Unified"],
			["fd_vpe",     "VPE"],
		]},
	);
	my $number_of_plots = scalar(@PANELS);	# 10
	my $main_size_plots = 3;		# panels 1-3 use graph size 'main'

	# selectable panels (1-based panel numbers), default: all
	# disabled panels are only hidden in the CGI - ALL 79 DS keep being
	# recorded in the RRD, so a panel can be re-enabled later without
	# losing history (e.g. panels = 1, 2, 3, 4, 5, 6, 7, 10)
	my @panel_list;
	if(defined($amdgpu_top->{panels}) && $amdgpu_top->{panels} ne "") {
		foreach my $p (split(',', $amdgpu_top->{panels})) {
			$p =~ s/\s+//g;
			if($p =~ /^\d+$/ && $p >= 1 && $p <= $number_of_plots) {
				push(@panel_list, $p + 0);
			}
			elsif($p ne "") {
				push(@output, "ERROR: while parsing 'panels' option: ignoring invalid panel number '$p'\n");
			}
		}
	}
	@panel_list = (1 .. $number_of_plots) unless(@panel_list);
	my $number_of_visible_plots = scalar(@panel_list);
	# column break after the last 'main' panel (left column)
	my $left_column_plots = (grep { $_ <= $main_size_plots } @panel_list);

	# text mode
	#
	if(lc($config->{iface_mode}) eq "text") {
		if($title) {
			push(@output, main::graph_header($title, 2));
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		# the upstream CGI only defines tf->{res,tc,tb,ts} for the
		# day/week/month/year views; for the 'when=<n>hour' views that the
		# CGI's regex also accepts, render 5-minute rows over <n> hours
		if(!$tf->{res}) {
			$tf = { %$tf, res => 300, tc => 'h', tb => $tf->{nwhen}, ts => 12 };
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
		"--resolution=" . $tf->{res},
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"AVERAGE");
		$err = RRDs::error;
		push(@output, "ERROR: while fetching $rrd: $err\n") if $err;

		# subset of values for the text table:
		# [ DS suffix, table header, sprintf format, is temperature ]
		my @TEXT_COLS = (
			["act_gfx",    "GFX%",  "%6.0f", 0],
			["t_edge",     "Edge",  "%6.0f", 1],
			["t_tctl",     "Tctl",  "%6.0f", 1],
			["sclk",       "SCLK",  "%6.0f", 0],
			["mclk",       "MCLK",  "%6.0f", 0],
			["gm_p_sock",  "Pow W", "%6.1f", 0],
			["vram_use",   "VRAM",  "%6.0f", 0],
			["gtt_use",    "GTT",   "%6.0f", 0],
			["proc_count", "Proc",  "%6.0f", 0],
		);

		# walk groups/slots exactly like _update() does to know the
		# position of every device slot inside the fetched row
		my @groups;
		my @slot_base;
		my $seen = 0;
		foreach my $k (sort keys %{$amdgpu_top->{list}}) {
			my @d = split(/\s*,\s*/, $amdgpu_top->{list}->{$k});
			@d = @d[0 .. $max_number_of_gpus - 1] if(scalar(@d) > $max_number_of_gpus);
			push(@groups, \@d);
			push(@slot_base, $seen);
			$seen += scalar(@d);
		}

		my $line1;
		my $line2;
		my $line3;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		foreach my $g (0 .. $#groups) {
			for($n = 0; $n < scalar(@{$groups[$g]}); $n++) {
				$str = amdgpu_top_dev_label($config, $groups[$g][$n]);
				$line1 .= sprintf(" %-15s", substr($str, 0, 15));
				$line2 .= " " . join(" ", map { sprintf("%6s", $_->[1]) } @TEXT_COLS);
				$line3 .= "-" x (scalar(@TEXT_COLS) * 7);
			}
		}
		push(@output, "     $line1\n");
		push(@output, "Time $line2\n");
		push(@output, "-----$line3\n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			foreach my $g (0 .. $#groups) {
				for($n2 = 0; $n2 < scalar(@{$groups[$g]}); $n2++) {
					my $base = $slot_base[$g] + $n2 * $number_of_values_per_gpu_in_rrd;
					@row = ();
					foreach my $tc (@TEXT_COLS) {
						my $v = @$line[$base + $DS_INDEX{$tc->[0]}];
						$v = celsius_to($config, $v) if($tc->[3] && defined($v));
						push(@row, defined($v) ? sprintf($tc->[2], $v) : sprintf("%6s", "n/a"));
					}
					push(@output, " " . join(" ", @row));
				}
			}
			push(@output, "\n");
		}
		push(@output, "    </pre>\n");

		# optional static device info block (best-effort)
		if(lc($amdgpu_top->{show_info} || "") eq "y" && !$silent) {
			my @info = collect_info($config);
			if(@info) {
				push(@output, "    <br>\n");
				push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
				push(@output, "$_\n") foreach (@info);
				push(@output, "    </pre>\n");
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


	# graph mode
	#
	if($silent eq "yes" || $silent eq "imagetag") {
		$zoom = 1;	# force 'global_zoom' to 1 in Multihost viewer
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "_";
	}
	if($silent eq "imagetagbig") {
		$zoom = 1;	# force 'global_zoom' to 1 in Multihost viewer
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "";
	}
	my $global_zoom = "--zoom=" . $zoom;

	for($n = 0; $n < keys(%{$amdgpu_top->{list}}); $n++) {
		for($n2 = 0; $n2 < $number_of_visible_plots; $n2++) {
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
	foreach my $k (sort keys %{$amdgpu_top->{list}}) {
		my @d = split(/\s*,\s*/, $amdgpu_top->{list}->{$k});
		@d = @d[0 .. $max_number_of_gpus - 1] if(scalar(@d) > $max_number_of_gpus);

		# multihost imagetag selects images per group, like the built-in
		# modules do: $e2 is the 1-based group number (\b anchors the match
		# so group 1 does not also select group 10)
		$e2 = $e + 1;
		my $show_group = $title || ($silent =~ /imagetag/ && $graph =~ /amdgpu_top$e2\b/);
		if($title) {
			push(@output, main::graph_header($title, 2));
			push(@output, "    <tr>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}

		# Balance the two columns: the left one holds the main-size
		# panels, the right one the small panels. After drawing, the
		# measured image heights decide how much taller the main graphs
		# must be (see after the drawing loop).
		my @png_h;
		my @main_args;
		my @frag;
		for($n_plot = 0; $n_plot < $number_of_visible_plots; $n_plot++) {
			my $pn = $panel_list[$n_plot];	# original 1-based panel number

			my $panel = $PANELS[$pn - 1];
			my $fmt = $panel->{fmt};
			my $is_main = $pn <= $main_size_plots ? 1 : 0;
			my $temp_f = ($panel->{temp} && lc($config->{temperature_scale}) eq "f") ? 1 : 0;
			my $vlabel = $temp_f ? "Fahrenheit" : $panel->{vl};

			@riglim = @{setup_riglim($rigid[$pn - 1], $limit[$pn - 1])};
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			my @def;
			my $allvalues = "CDEF:allvalues=";
			my $ndef = 0;
			my $multi = scalar(@d) > 1 ? 1 : 0;

			# two rendering passes: AREAs (background style entries) first,
			# then all LINE plots, so no AREA can bury a previously drawn line
			for my $pass (1, 2) {
			for($n = 0; $n < scalar(@d); $n++) {
				my $dname = amdgpu_top_dev_label($config, $d[$n]);

				for($n2 = 0; $n2 < scalar(@{$panel->{metrics}}); $n2++) {
					my ($suffix, $mlabel, $style) = @{$panel->{metrics}[$n2]};
					my $is_area = (defined($style) && $style =~ /^AREA/) ? 1 : 0;
					next if(($pass == 1) != $is_area);
					my $vname = "e" . $e . "d" . $n . "_" . $suffix;
					my $tname = "t_" . $vname;

					push(@def, "DEF:" . $vname . "=$rrd:" . $vname . ":AVERAGE");
					$allvalues .= "," if($ndef++);
					$allvalues .= $vname . ",UN,0,1,IF";
					push(@CDEF, "CDEF:" . $tname . "=" . $vname . ($temp_f ? ",9,*,5,/,32,+" : ""));

					# draw style and color:
					# 'AREA:#rrggbb' / 'LINE\d[:#rrggbb][:dashes]'
					my ($kind, $col, $dashstr) = (undef, undef, "");
					if(defined($style) && $style =~ /^(AREA|LINE\d)(?::?(#.*?))?(?::(dashes))?$/) {
						$kind = $1;
						$col = $2 // $LC[($n2 + $n * 3) % scalar(@LC)];
						$dashstr = $3 ? ":dashes" : "";
					}
					else {
						$kind = $is_main ? "LINE2" : "LINE1";
						$col = $LC[($n2 + $n * 3) % scalar(@LC)];
					}

					my $lbl = ($multi ? $dname . " " : "") . $mlabel;
					if($is_main) {
						$str = sprintf("%-15s", substr($lbl, 0, 15));
						push(@tmp, "COMMENT: \\n") if($n_plot == 0 && $n == 0 && $n2 == 0);
					}
					else {
						$str = sprintf("%-13s", substr($lbl, 0, 13));
					}
					push(@tmp, $kind . ":" . $tname . $col . ":" . $str . $dashstr);
					push(@tmpz, $kind . ":" . $tname . $col . ":" . $lbl . $dashstr);

					if($is_main) {
						push(@tmp, "GPRINT:" . $tname . ":LAST:  Current\\:" . $fmt);
						push(@tmp, "GPRINT:" . $tname . ":AVERAGE: Average\\:" . $fmt);
						push(@tmp, "GPRINT:" . $tname . ":MIN: Min\\:" . $fmt);
						push(@tmp, "GPRINT:" . $tname . ":MAX: Max\\:" . $fmt . "\\n");
					}
					else {
						if($show_current_values) {
							push(@tmp, "GPRINT:" . $tname . ":LAST:\\: " . $fmt . "\\n");
						}
					}
				}
			}
			}
			$allvalues .= ",+" x ($ndef - 1);
			push(@CDEF, $allvalues);

			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}

			($width, $height) = split('x', $config->{graph_size}->{$is_main ? 'main' : 'small'});
			# make room for long legends (one line per DS and device)
			my $legend_lines = scalar(@d) * scalar(@{$panel->{metrics}});
			my $legend_extra = ($legend_lines > 1) ? ($is_main ? 13 : 10) * ($legend_lines - 1) : 0;
			$height += $legend_extra if($legend_extra);
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
				@tmp = @tmpz;
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}

			my $plot_title = $config->{graphs}->{'_amdgpu_top' . $pn};
			$plot_title = "Panel " . $pn unless defined($plot_title);

			my @picargs = ("$IMG_DIR" . $IMG[$e * $number_of_visible_plots + $n_plot],
				"--title=$plot_title ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=" . $vlabel,
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$global_zoom,
				@{$cgi->{version12}},
				$is_main ? () : @{$cgi->{version12_small}},
				@{ $colors->{graph_colors} || [] },
				@def,
				@CDEF,
				@tmp);
			$pic = $rrd{$version}->(@picargs);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . $IMG[$e * $number_of_visible_plots + $n_plot] . ": $err\n") if $err;

			# remember rendered height (graphv) and the arguments of the
			# main graphs for the possible column-balancing redraw below
			$png_h[$n_plot] = (ref($pic) eq "HASH") ? $pic->{image_height} : undef;
			$main_args[$n_plot] = \@picargs if($is_main && $title);

			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				# scale the legend margin with the zoom factor, too
				$height += $legend_extra * $zoom if($legend_extra);
				$picz = $rrd{$version}->("$IMG_DIR" . $IMGz[$e * $number_of_visible_plots + $n_plot],
					"--title=$plot_title  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=" . $vlabel,
					"--width=$width",
					"--height=$height",
					@full_size_mode,
					@extra,
					@riglim,
					$global_zoom,
					@{$cgi->{version12}},
					$is_main ? () : @{$cgi->{version12_small}},
					@{ $colors->{graph_colors} || [] },
					@def,
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . $IMGz[$e * $number_of_visible_plots + $n_plot] . ": $err\n") if $err;
			}

			# pre-build this panel's HTML fragment (emitted below,
			# after the possible column-balancing redraw)
			if($show_group) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						$frag[$n_plot] = "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * $number_of_visible_plots + $n_plot], IMG => $IMG[$e * $number_of_visible_plots + $n_plot]) . "\n";
					}
					else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $zoom;
							$picz_height = $picz->{image_height} * $zoom;
						}
						else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						$frag[$n_plot] = "      " . picz_js_a_element(width => $picz_width, height => $picz_height, config => $config, IMGz => $IMGz[$e * $number_of_visible_plots + $n_plot], IMG => $IMG[$e * $number_of_visible_plots + $n_plot]) . "\n";
					}
				}
				else {
					$frag[$n_plot] = "      " . img_element(config => $config, IMG => $IMG[$e * $number_of_visible_plots + $n_plot]) . "\n";
				}
			}
		}

		# Column balancing: if the right column (small panels) ended up
		# taller than the left one (main panels), redraw the main graphs
		# proportionally taller. RRDtool scales --height exactly by
		# --zoom, so this closes the grey margin below the left column
		# down to a few pixels.
		if($title && $version eq "new" && $left_column_plots && $left_column_plots < $number_of_visible_plots) {
			my ($sumL, $sumR, $ok) = (0, 0, 1);
			foreach my $i (0 .. $number_of_visible_plots - 1) {
				if(!defined($png_h[$i])) { $ok = 0; last; }
				$i < $left_column_plots ? ($sumL += $png_h[$i]) : ($sumR += $png_h[$i]);
			}
			if($ok && ($sumR - $sumL) > 10) {
				# graphv's image_height is the unzoomed one, and --height is
				# in the same unzoomed pixel unit, so no zoom correction here
				my $add = int(($sumR - $sumL) / $left_column_plots + 0.5);
				foreach my $i (grep { defined($main_args[$_]) } 0 .. $left_column_plots - 1) {
					$rrd{'new'}->(map { /^--height=(\d+)$/ ? '--height=' . ($1 + $add) : $_ } @{$main_args[$i]});
				}
			}
		}

		for($n_plot = 0; $n_plot < $number_of_visible_plots; $n_plot++) {
			if($title && $n_plot == $left_column_plots) {
				push(@output, "    </td>\n");
				push(@output, "    <td class='td-valign-top'>\n");
			}
			push(@output, $frag[$n_plot]) if(defined($frag[$n_plot]));
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");

			if($amdgpu_top->{desc}->{$k}) {
				push(@output, "    <tr>\n");
				push(@output, "      <td class='td-title' colspan='2'>\n");
				push(@output, "       <font size='-1'>\n");
				push(@output, "        <b>&nbsp;&nbsp;$amdgpu_top->{desc}->{$k}</b>\n");
				push(@output, "       </font>\n");
				push(@output, "      </td>\n");
				push(@output, "    </tr>\n");
			}
			push(@output, main::graph_footer());
		}
		$e++;
	}
	push(@output, "  <br>\n");
	return @output;
}

# display name of a device entry from <list> (honours <map>)
sub amdgpu_top_dev_label {
	my ($config, $entry) = @_;

	my $idx = defined($entry) ? $entry : "";
	$idx =~ s/^\s+//;
	$idx =~ s/\s+$//;
	$idx =~ s/^["']//;
	$idx =~ s/["']$//;

	if(defined($config->{amdgpu_top}->{map}->{$idx})) {
		return $config->{amdgpu_top}->{map}->{$idx};
	}
	return "GPU $idx";
}

1;
