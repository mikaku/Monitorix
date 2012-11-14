package system;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(system_init system_update);

sub system_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
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

	if(lc($config->{enable_alerts}) eq "y") {
		if(! -x $config->{alert_loadavg_script}) {
			logger("$myself: ERROR: script '$config->{alert_loadavg_script}' doesn't exist or don't has execution permissions.");
		}
	}

	$config->{system_hist} = 0;
	push(@{$config->{func_update}}, $package);
	if($debug) {
		logger("$myself: Ok");
	}
}

sub system_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

	my $load1;
	my $load5;
	my $load15;
	my $nproc;
	my $npslp;
	my $nprun;
	my $npwio;
	my $npzom;
	my $npstp;
	my $npswp;
	my $mtotl;
	my $mbuff;
	my $mcach;
	my $mfree;
	my $macti;
	my $minac;
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
			if(/^Free Memory Pages:\s+(\d+)K$/) {
				$mfree = $1;
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
	if(lc($config->{enable_alerts}) eq "y") {
		if(!$config->{alert_loadavg_threshold} || $load15 < $config->{alert_loadavg_threshold}) {
			$config->{system_hist} = 0;
		} else {
			if(!$config->{system_hist}) {
				$config->{system_hist} = time;
			}
			if($config->{system_hist} > 0 && (time - $config->{system_hist}) > $config->{alert_loadavg_timeintvl}) {
				if(-x $config->{alert_loadavg_script}) {
					system($config->{alert_loadavg_script} . " " .$config->{alert_loadavg_timeintvl} . " " . $config->{alert_loadavg_threshold} . " " . $load15);
				}
				$config->{system_hist} = time;
			}
		}
	}

	$rrdata .= ":$load1:$load5:$load15:$nproc:$npslp:$nprun:$npwio:$npzom:$npstp:$npswp:$mtotl:$mbuff:$mcach:$mfree:$macti:$minac:$val01:$val02:$val03:$val04:$val05";
	RRDs::update($rrd, $rrdata);
	if($debug) {
		logger("$myself: $rrdata");
	}
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

1;
