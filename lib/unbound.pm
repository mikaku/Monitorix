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

package unbound;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(unbound_init unbound_update unbound_cgi);

sub unbound_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $unbound = $config->{unbound};

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
		push(@tmp, "DS:unbound_tnumquer:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_tnumchit:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_tnumcmis:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_tnumrecr:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_treqavg:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_treqmax:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_treqove:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_treqexc:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_treqall:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype01:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype02:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype03:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype04:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype05:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype06:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype07:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype08:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype09:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype10:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype11:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype12:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype13:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype14:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype15:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype16:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype17:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype18:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype19:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qtype20:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_trtavg:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_trtmed:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_uptime:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qflagqr:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qflagaa:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qflagtc:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qflagrd:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qflagra:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qflagz:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qflagad:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qflagcd:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qflagepr:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_qflagedo:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_mcrrset:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_mcmessg:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_mmitera:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_mmvalid:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_nanoerr:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_naforme:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_naservf:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_nanxdom:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_nanotim:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_narefus:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_nanodat:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_nasecur:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_nabogus:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_narsbog:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_unwquer:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_unwrepl:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_nqtcp:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_nqtls:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_nqipv6:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h0uto2m:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h2mto4m:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h4mto8m:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h8mto16m:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h16mto32m:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h32mto64m:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h64mto128m:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h128mto256m:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h256mto512m:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h512mto1s:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h1sto2s:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h2sto4s:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h4sto8s:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h8sto16s:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h16sto32s:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h32sto64s:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h64sto128s:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h128sto256s:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h256sto512s:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_h512stomore:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_val01:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_val02:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_val03:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_val04:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_val05:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_val06:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_val07:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_val08:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_val09:GAUGE:120:0:U");
		push(@tmp, "DS:unbound_val10:GAUGE:120:0:U");
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

	# check for missing options
	if(!$unbound->{cmd}) {
		logger("$myself: INFO: the 'cmd' option doesn't exist, defaulting to 'unbound-control'.");
		$unbound->{cmd} = "unbound-control";
	}

	$config->{unbound_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub unbound_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $unbound = $config->{unbound};

	my $tnumquer = 0;
	my $tnumchit = 0;
	my $tnumcmis = 0;
	my $tnumrecr = 0;
	my $treqavg = 0;
	my $treqmax = 0;
	my $treqove = 0;
	my $treqexc = 0;
	my $treqall = 0;
	my @qtype = ();
	my $trtavg = 0;
	my $trtmed = 0;
	my $uptime = 0;
	my $qflagqr = 0;
	my $qflagaa = 0;
	my $qflagtc = 0;
	my $qflagrd = 0;
	my $qflagra = 0;
	my $qflagz = 0;
	my $qflagad = 0;
	my $qflagcd = 0;
	my $qflagepr = 0;
	my $qflagedo = 0;
	my $mcrrset = 0;
	my $mcmessg = 0;
	my $mmitera = 0;
	my $mmvalid = 0;
	my $nanoerr = 0;
	my $naforme = 0;
	my $naservf = 0;
	my $nanxdom = 0;
	my $nanotim = 0;
	my $narefus = 0;
	my $nanodat = 0;
	my $nasecur = 0;
	my $nabogus = 0;
	my $narsbog = 0;
	my $unwquer = 0;
	my $unwrepl = 0;
	my $nqtcp = 0;
	my $nqtls = 0;
	my $nqipv6 = 0;
	my $h0uto2m_acum = 0;
	my $h0uto2m = 0;
	my $h2mto4m = 0;
	my $h4mto8m = 0;
	my $h8mto16m = 0;
	my $h16mto32m = 0;
	my $h32mto64m = 0;
	my $h64mto128m = 0;
	my $h128mto256m = 0;
	my $h256mto512m = 0;
	my $h512mto1s = 0;
	my $h1sto2s = 0;
	my $h2sto4s = 0;
	my $h4sto8s = 0;
	my $h8sto16s = 0;
	my $h16sto32s = 0;
	my $h32sto64s = 0;
	my $h64sto128s = 0;
	my $h128sto256s = 0;
	my $h256sto512s = 0;
	my $h512stomore_acum = 0;
	my $h512stomore = 0;
	my $str;
	my $n;
	my $rrdata = "N";

	my @t = split(',', $unbound->{queries_type});
	for($n = 0; $n < 20; $n++) {
		$t[$n] = trim($t[$n]) if $t[$n];
		$qtype[$n] = 0;
	}

	open(IN, "$unbound->{cmd} stats_noreset |");
	while(<IN>) {
		if(/^total\.num\.queries=(\d+)$/) {
			$tnumquer = $1 - ($config->{unbound_hist}->{'tnumquer'} || 0);
			$tnumquer = 0 unless $tnumquer != $1;
			$tnumquer /= 60;
			$config->{unbound_hist}->{'tnumquer'} = $1;
			next;
		}
		if(/^total\.num\.cachehits=(\d+)$/) {
			$tnumchit = $1 - ($config->{unbound_hist}->{'tnumchit'} || 0);
			$tnumchit = 0 unless $tnumchit != $1;
			$tnumchit /= 60;
			$config->{unbound_hist}->{'tnumchit'} = $1;
			next;
		}
		if(/^total\.num\.cachemiss=(\d+)$/) {
			$tnumcmis = $1 - ($config->{unbound_hist}->{'tnumcmis'} || 0);
			$tnumcmis = 0 unless $tnumcmis != $1;
			$tnumcmis /= 60;
			$config->{unbound_hist}->{'tnumcmis'} = $1;
			next;
		}
		if(/^total\.num\.recursivereplies=(\d+)$/) {
			$tnumrecr = $1 - ($config->{unbound_hist}->{'tnumrecr'} || 0);
			$tnumrecr = 0 unless $tnumrecr != $1;
			$tnumrecr /= 60;
			$config->{unbound_hist}->{'tnumrecr'} = $1;
			next;
		}
		if(/^total\.requestlist\.avg=(\d+)$/) {
			$treqavg = $1 - ($config->{unbound_hist}->{'treqavg'} || 0);
			$treqavg = 0 unless $treqavg != $1;
			$treqavg /= 60;
			$config->{unbound_hist}->{'treqavg'} = $1;
			next;
		}
		if(/^total\.requestlist\.overwritten=(\d+)$/) {
			$treqove = $1 - ($config->{unbound_hist}->{'treqove'} || 0);
			$treqove = 0 unless $treqove != $1;
			$treqove /= 60;
			$config->{unbound_hist}->{'treqove'} = $1;
			next;
		}
		if(/^total\.requestlist\.max=(\d+)$/) {
			$treqmax = $1 - ($config->{unbound_hist}->{'treqmax'} || 0);
			$treqmax = 0 unless $treqmax != $1;
			$treqmax /= 60;
			$config->{unbound_hist}->{'treqmax'} = $1;
			next;
		}
		if(/^total\.requestlist\.exceeded=(\d+)$/) {
			$treqexc = $1 - ($config->{unbound_hist}->{'treqexc'} || 0);
			$treqexc = 0 unless $treqexc != $1;
			$treqexc /= 60;
			$config->{unbound_hist}->{'treqexc'} = $1;
			next;
		}
		if(/^total\.requestlist\.current\.all=(\d+)$/) {
			$treqall = $1 - ($config->{unbound_hist}->{'treqall'} || 0);
			$treqall = 0 unless $treqall != $1;
			$treqall /= 60;
			$config->{unbound_hist}->{'treqall'} = $1;
			next;
		}

		for($n = 0; $n < 20; $n++) {
			if(/^num\.query\.type\.$t[$n]=(\d+)$/) {
				$str = "qtype" . $n;
				$qtype[$n] = $1;
				$qtype[$n] = $1 - ($config->{unbound_hist}->{$str} || 0);
				$qtype[$n] = 0 unless $treqall != $1;
				$qtype[$n] /= 60;
				$config->{unbound_hist}->{$str} = $1;
				next;
			}
		}

		if(/^total\.recursion\.time\.avg=(\d+.\d+)$/) {
			$trtavg = $1;
			next;
		}
		if(/^total\.recursion\.time\.median=(\d+.\d+)$/) {
			$trtmed = $1;
			next;
		}
		if(/^time\.up=(\d+\.\d+)$/) {
			$uptime = $1;
			next;
		}

		if(/^num\.query\.flags\.QR=(\d+)$/) {
			$qflagqr = $1 - ($config->{unbound_hist}->{'qflagqr'} || 0);
			$qflagqr = 0 unless $qflagqr != $1;
			$qflagqr /= 60;
			$config->{unbound_hist}->{'qflagqr'} = $1;
			next;
		}
		if(/^num\.query\.flags\.AA=(\d+)$/) {
			$qflagaa = $1 - ($config->{unbound_hist}->{'qflagaa'} || 0);
			$qflagaa = 0 unless $qflagaa != $1;
			$qflagaa /= 60;
			$config->{unbound_hist}->{'qflagaa'} = $1;
			next;
		}
		if(/^num\.query\.flags\.TC=(\d+)$/) {
			$qflagtc = $1 - ($config->{unbound_hist}->{'qflagtc'} || 0);
			$qflagtc = 0 unless $qflagtc != $1;
			$qflagtc /= 60;
			$config->{unbound_hist}->{'qflagtc'} = $1;
			next;
		}
		if(/^num\.query\.flags\.RD=(\d+)$/) {
			$qflagrd = $1 - ($config->{unbound_hist}->{'qflagrd'} || 0);
			$qflagrd = 0 unless $qflagrd != $1;
			$qflagrd /= 60;
			$config->{unbound_hist}->{'qflagrd'} = $1;
			next;
		}
		if(/^num\.query\.flags\.RA=(\d+)$/) {
			$qflagra = $1 - ($config->{unbound_hist}->{'qflagra'} || 0);
			$qflagra = 0 unless $qflagra != $1;
			$qflagra /= 60;
			$config->{unbound_hist}->{'qflagra'} = $1;
			next;
		}
		if(/^num\.query\.flags\.Z=(\d+)$/) {
			$qflagz = $1 - ($config->{unbound_hist}->{'qflagz'} || 0);
			$qflagz = 0 unless $qflagz != $1;
			$qflagz /= 60;
			$config->{unbound_hist}->{'qflagz'} = $1;
			next;
		}
		if(/^num\.query\.flags\.AD=(\d+)$/) {
			$qflagad = $1 - ($config->{unbound_hist}->{'qflagad'} || 0);
			$qflagad = 0 unless $qflagad != $1;
			$qflagad /= 60;
			$config->{unbound_hist}->{'qflagad'} = $1;
			next;
		}
		if(/^num\.query\.flags\.CD=(\d+)$/) {
			$qflagcd = $1 - ($config->{unbound_hist}->{'qflagcd'} || 0);
			$qflagcd = 0 unless $qflagcd != $1;
			$qflagcd /= 60;
			$config->{unbound_hist}->{'qflagcd'} = $1;
			next;
		}
		if(/^num\.query\.edns\.present=(\d+)$/) {
			$qflagepr = $1 - ($config->{unbound_hist}->{'qflagepr'} || 0);
			$qflagepr = 0 unless $qflagepr != $1;
			$qflagepr /= 60;
			$config->{unbound_hist}->{'qflagepr'} = $1;
			next;
		}
		if(/^num\.query\.edns\.DO=(\d+)$/) {
			$qflagedo = $1 - ($config->{unbound_hist}->{'qflagedo'} || 0);
			$qflagedo = 0 unless $qflagedo != $1;
			$qflagedo /= 60;
			$config->{unbound_hist}->{'qflagedo'} = $1;
			next;
		}

		if(/^mem\.cache\.rrset=(\d+)$/) {
			$mcrrset = $1;
			next;
		}
		if(/^mem\.cache\.message=(\d+)$/) {
			$mcmessg = $1;
			next;
		}
		if(/^mem\.mod\.iterator=(\d+)$/) {
			$mmitera = $1;
			next;
		}
		if(/^mem\.mod\.validator=(\d+)$/) {
			$mmvalid = $1;
			next;
		}

		if(/^num\.answer\.rcode\.NOERROR=(\d+)$/) {
			$nanoerr = $1 - ($config->{unbound_hist}->{'nanoerr'} || 0);
			$nanoerr = 0 unless $nanoerr != $1;
			$nanoerr /= 60;
			$config->{unbound_hist}->{'nanoerr'} = $1;
			next;
		}
		if(/^num\.answer\.rcode\.FORMERR=(\d+)$/) {
			$naforme = $1 - ($config->{unbound_hist}->{'naforme'} || 0);
			$naforme = 0 unless $naforme != $1;
			$naforme /= 60;
			$config->{unbound_hist}->{'naforme'} = $1;
			next;
		}
		if(/^num\.answer\.rcode\.SERVFAIL=(\d+)$/) {
			$naservf = $1 - ($config->{unbound_hist}->{'naservf'} || 0);
			$naservf = 0 unless $naservf != $1;
			$naservf /= 60;
			$config->{unbound_hist}->{'naservf'} = $1;
			next;
		}
		if(/^num\.answer\.rcode\.NXDOMAIN=(\d+)$/) {
			$nanxdom = $1 - ($config->{unbound_hist}->{'nanxdom'} || 0);
			$nanxdom = 0 unless $nanxdom != $1;
			$nanxdom /= 60;
			$config->{unbound_hist}->{'nanxdom'} = $1;
			next;
		}
		if(/^num\.answer\.rcode\.NOTIMPL=(\d+)$/) {
			$nanotim = $1 - ($config->{unbound_hist}->{'nanotim'} || 0);
			$nanotim = 0 unless $nanotim != $1;
			$nanotim /= 60;
			$config->{unbound_hist}->{'nanotim'} = $1;
			next;
		}
		if(/^num\.answer\.rcode\.REFUSED=(\d+)$/) {
			$narefus = $1 - ($config->{unbound_hist}->{'narefus'} || 0);
			$narefus = 0 unless $narefus != $1;
			$narefus /= 60;
			$config->{unbound_hist}->{'narefus'} = $1;
			next;
		}
		if(/^num\.answer\.rcode\.nodata=(\d+)$/) {
			$nanodat = $1 - ($config->{unbound_hist}->{'nanodat'} || 0);
			$nanodat = 0 unless $nanodat != $1;
			$nanodat /= 60;
			$config->{unbound_hist}->{'nanodat'} = $1;
			next;
		}
		if(/^num\.answer\.secure=(\d+)$/) {
			$nasecur = $1 - ($config->{unbound_hist}->{'nasecur'} || 0);
			$nasecur = 0 unless $nasecur != $1;
			$nasecur /= 60;
			$config->{unbound_hist}->{'nasecur'} = $1;
			next;
		}
		if(/^num\.answer\.bogus=(\d+)$/) {
			$nabogus = $1 - ($config->{unbound_hist}->{'nabogus'} || 0);
			$nabogus = 0 unless $nabogus != $1;
			$nabogus /= 60;
			$config->{unbound_hist}->{'nabogus'} = $1;
			next;
		}

		if(/^unwanted\.queries=(\d+)$/) {
			$unwquer = $1 - ($config->{unbound_hist}->{'unwquer'} || 0);
			$unwquer = 0 unless $unwquer != $1;
			$unwquer /= 60;
			$config->{unbound_hist}->{'unwquer'} = $1;
			next;
		}
		if(/^unwanted\.replies=(\d+)$/) {
			$unwrepl = $1 - ($config->{unbound_hist}->{'unwrepl'} || 0);
			$unwrepl = 0 unless $unwrepl != $1;
			$unwrepl /= 60;
			$config->{unbound_hist}->{'unwrepl'} = $1;
			next;
		}
		if(/^num\.query\.tcp=(\d+)$/) {
			$nqtcp = $1 - ($config->{unbound_hist}->{'nqtcp'} || 0);
			$nqtcp = 0 unless $nqtcp != $1;
			$nqtcp /= 60;
			$config->{unbound_hist}->{'nqtcp'} = $1;
			next;
		}
		if(/^num\.query\.tls=(\d+)$/) {
			$nqtls = $1 - ($config->{unbound_hist}->{'nqtls'} || 0);
			$nqtls = 0 unless $nqtls != $1;
			$nqtls /= 60;
			$config->{unbound_hist}->{'nqtls'} = $1;
			next;
		}
		if(/^num\.query\.ipv6=(\d+)$/) {
			$nqipv6 = $1 - ($config->{unbound_hist}->{'nqipv6'} || 0);
			$nqipv6 = 0 unless $nqipv6 != $1;
			$nqipv6 /= 60;
			$config->{unbound_hist}->{'nqipv6'} = $1;
			next;
		}

		if(/^histogram\.000000\.000000\.to\.000000\.000001=(\d+)$/) {
			$h0uto2m_acum = $1;
			next;
		}
		if(/^histogram\.000000\.000001\.to\.000000\.000002=(\d+)$/) {
			$h0uto2m_acum += $1;
			next;
		}
		if(/^histogram\.000000\.000002\.to\.000000\.000004=(\d+)$/) {
			$h0uto2m_acum += $1;
			next;
		}
		if(/^histogram\.000000\.000004\.to\.000000\.000008=(\d+)$/) {
			$h0uto2m_acum += $1;
			next;
		}
		if(/^histogram\.000000\.000008\.to\.000000\.000016=(\d+)$/) {
			$h0uto2m_acum += $1;
			next;
		}
		if(/^histogram\.000000\.000016\.to\.000000\.000032=(\d+)$/) {
			$h0uto2m_acum += $1;
			next;
		}
		if(/^histogram\.000000\.000032\.to\.000000\.000064=(\d+)$/) {
			$h0uto2m_acum += $1;
			next;
		}
		if(/^histogram\.000000\.000064\.to\.000000\.000128=(\d+)$/) {
			$h0uto2m_acum += $1;
			next;
		}
		if(/^histogram\.000000\.000128\.to\.000000\.000256=(\d+)$/) {
			$h0uto2m_acum += $1;
			next;
		}
		if(/^histogram\.000000\.000256\.to\.000000\.000512=(\d+)$/) {
			$h0uto2m_acum += $1;
			next;
		}
		if(/^histogram\.000000\.000512\.to\.000000\.001024=(\d+)$/) {
			$h0uto2m_acum += $1;
			next;
		}
		if(/^histogram\.000000\.001024\.to\.000000\.002048=(\d+)$/) {
			$h0uto2m_acum += $1;
			$h0uto2m = $h0uto2m_acum - ($config->{unbound_hist}->{'h0uto2m'} || 0);
			$h0uto2m = 0 unless $h0uto2m != $h0uto2m_acum;
			$h0uto2m /= 60;
			$config->{unbound_hist}->{'h0uto2m'} = $h0uto2m_acum;
			next;
		}
		if(/^histogram\.000000\.002048\.to\.000000\.004096=(\d+)$/) {
			$h2mto4m = $1 - ($config->{unbound_hist}->{'h2mto4m'} || 0);
			$h2mto4m = 0 unless $h2mto4m != $1;
			$h2mto4m /= 60;
			$config->{unbound_hist}->{'h2mto4m'} = $1;
			next;
		}
		if(/^histogram\.000000\.004096\.to\.000000\.008192=(\d+)$/) {
			$h4mto8m = $1 - ($config->{unbound_hist}->{'h4mto8m'} || 0);
			$h4mto8m = 0 unless $h4mto8m != $1;
			$h4mto8m /= 60;
			$config->{unbound_hist}->{'h4mto8m'} = $1;
			next;
		}
		if(/^histogram\.000000\.008192\.to\.000000\.016384=(\d+)$/) {
			$h8mto16m = $1 - ($config->{unbound_hist}->{'h8mto16m'} || 0);
			$h8mto16m = 0 unless $h8mto16m != $1;
			$h8mto16m /= 60;
			$config->{unbound_hist}->{'h8mto16m'} = $1;
			next;
		}
		if(/^histogram\.000000\.016384\.to\.000000\.032768=(\d+)$/) {
			$h16mto32m = $1 - ($config->{unbound_hist}->{'h16mto32m'} || 0);
			$h16mto32m = 0 unless $h16mto32m != $1;
			$h16mto32m /= 60;
			$config->{unbound_hist}->{'h16mto32m'} = $1;
			next;
		}
		if(/^histogram\.000000\.032768\.to\.000000\.065536=(\d+)$/) {
			$h32mto64m = $1 - ($config->{unbound_hist}->{'h32mto64m'} || 0);
			$h32mto64m = 0 unless $h32mto64m != $1;
			$h32mto64m /= 60;
			$config->{unbound_hist}->{'h32mto64m'} = $1;
			next;
		}
		if(/^histogram\.000000\.065536\.to\.000000\.131072=(\d+)$/) {
			$h64mto128m = $1 - ($config->{unbound_hist}->{'h64mto128m'} || 0);
			$h64mto128m = 0 unless $h64mto128m != $1;
			$h64mto128m /= 60;
			$config->{unbound_hist}->{'h64mto128m'} = $1;
			next;
		}
		if(/^histogram\.000000\.131072\.to\.000000\.262144=(\d+)$/) {
			$h128mto256m = $1 - ($config->{unbound_hist}->{'h128mto256m'} || 0);
			$h128mto256m = 0 unless $h128mto256m != $1;
			$h128mto256m /= 60;
			$config->{unbound_hist}->{'h128mto256m'} = $1;
			next;
		}
		if(/^histogram\.000000\.262144\.to\.000000\.524288=(\d+)$/) {
			$h256mto512m = $1 - ($config->{unbound_hist}->{'h256mto512m'} || 0);
			$h256mto512m = 0 unless $h256mto512m != $1;
			$h256mto512m /= 60;
			$config->{unbound_hist}->{'h256mto512m'} = $1;
			next;
		}
		if(/^histogram\.000000\.524288\.to\.000001\.000000=(\d+)$/) {
			$h512mto1s = $1 - ($config->{unbound_hist}->{'h512mto1s'} || 0);
			$h512mto1s = 0 unless $h512mto1s != $1;
			$h512mto1s /= 60;
			$config->{unbound_hist}->{'h512mto1s'} = $1;
			next;
		}
		if(/^histogram\.000001\.000000\.to\.000002\.000000=(\d+)$/) {
			$h1sto2s = $1 - ($config->{unbound_hist}->{'h1sto2s'} || 0);
			$h1sto2s = 0 unless $h1sto2s != $1;
			$h1sto2s /= 60;
			$config->{unbound_hist}->{'h1sto2s'} = $1;
			next;
		}
		if(/^histogram\.000002\.000000\.to\.000004\.000000=(\d+)$/) {
			$h2sto4s = $1 - ($config->{unbound_hist}->{'h2sto4s'} || 0);
			$h2sto4s = 0 unless $h2sto4s != $1;
			$h2sto4s /= 60;
			$config->{unbound_hist}->{'h2sto4s'} = $1;
			next;
		}
		if(/^histogram\.000004\.000000\.to\.000008\.000000=(\d+)$/) {
			$h4sto8s = $1 - ($config->{unbound_hist}->{'h4sto8s'} || 0);
			$h4sto8s = 0 unless $h4sto8s != $1;
			$h4sto8s /= 60;
			$config->{unbound_hist}->{'h4sto8s'} = $1;
			next;
		}
		if(/^histogram\.000008\.000000\.to\.000016\.000000=(\d+)$/) {
			$h8sto16s = $1 - ($config->{unbound_hist}->{'h8sto16s'} || 0);
			$h8sto16s = 0 unless $h8sto16s != $1;
			$h8sto16s /= 60;
			$config->{unbound_hist}->{'h8sto16s'} = $1;
			next;
		}
		if(/^histogram\.000016\.000000\.to\.000032\.000000=(\d+)$/) {
			$h16sto32s = $1 - ($config->{unbound_hist}->{'h16sto32s'} || 0);
			$h16sto32s = 0 unless $h16sto32s != $1;
			$h16sto32s /= 60;
			$config->{unbound_hist}->{'h16sto32s'} = $1;
			next;
		}
		if(/^histogram\.000032\.000000\.to\.000064\.000000=(\d+)$/) {
			$h32sto64s = $1 - ($config->{unbound_hist}->{'h32sto64s'} || 0);
			$h32sto64s = 0 unless $h32sto64s != $1;
			$h32sto64s /= 60;
			$config->{unbound_hist}->{'h32sto64s'} = $1;
			next;
		}
		if(/^histogram\.000064\.000000\.to\.000128\.000000=(\d+)$/) {
			$h64sto128s = $1 - ($config->{unbound_hist}->{'h64sto128s'} || 0);
			$h64sto128s = 0 unless $h64sto128s != $1;
			$h64sto128s /= 60;
			$config->{unbound_hist}->{'h64sto128s'} = $1;
			next;
		}
		if(/^histogram\.000128\.000000\.to\.000256\.000000=(\d+)$/) {
			$h128sto256s = $1 - ($config->{unbound_hist}->{'h128sto256s'} || 0);
			$h128sto256s = 0 unless $h128sto256s != $1;
			$h128sto256s /= 60;
			$config->{unbound_hist}->{'h128sto256s'} = $1;
			next;
		}
		if(/^histogram\.000256\.000000\.to\.000512\.000000=(\d+)$/) {
			$h256sto512s = $1 - ($config->{unbound_hist}->{'h256sto512s'} || 0);
			$h256sto512s = 0 unless $h256sto512s != $1;
			$h256sto512s /= 60;
			$config->{unbound_hist}->{'h256sto512s'} = $1;
			next;
		}
		if(/^histogram\.000512\.000000\.to\.001024\.000000=(\d+)$/) {
			$h512stomore_acum = $1;
			next;
		}
		if(/^histogram\.001024\.000000\.to\.002048\.000000=(\d+)$/) {
			$h512stomore_acum += $1;
			next;
		}
		if(/^histogram\.002048\.000000\.to\.004096\.000000=(\d+)$/) {
			$h512stomore_acum += $1;
			next;
		}
		if(/^histogram\.004096\.000000\.to\.008192\.000000=(\d+)$/) {
			$h512stomore_acum += $1;
			next;
		}
		if(/^histogram\.008192\.000000\.to\.016384\.000000=(\d+)$/) {
			$h512stomore_acum += $1;
			next;
		}
		if(/^histogram\.016384\.000000\.to\.032768\.000000=(\d+)$/) {
			$h512stomore_acum += $1;
			next;
		}
		if(/^histogram\.032768\.000000\.to\.065536\.000000=(\d+)$/) {
			$h512stomore_acum += $1;
			next;
		}
		if(/^histogram\.065536\.000000\.to\.131072\.000000=(\d+)$/) {
			$h512stomore_acum += $1;
			next;
		}
		if(/^histogram\.131072\.000000\.to\.262144\.000000=(\d+)$/) {
			$h512stomore_acum += $1;
			next;
		}
		if(/^histogram\.262144\.000000\.to\.524288\.000000=(\d+)$/) {
			$h512stomore_acum += $1;
			$h512stomore = $h512stomore_acum - ($config->{unbound_hist}->{'h512stomore'} || 0);
			$h512stomore = 0 unless $h512stomore != $h512stomore_acum;
			$h512stomore /= 60;
			$config->{unbound_hist}->{'h512stomore'} = $h512stomore_acum;
			next;
		}
	}
	close(IN);

	$rrdata .= ":$tnumquer:$tnumchit:$tnumcmis:$tnumrecr:$treqavg:$treqove:$treqmax:$treqexc:$treqall";
	for($n = 0; $n < 20; $n++) {
		$rrdata .= ":$qtype[$n]";
	}
	$rrdata .= ":$trtavg:$trtmed";
	$rrdata .= ":$uptime";
	$rrdata .= ":$qflagqr:$qflagaa:$qflagtc:$qflagrd:$qflagra:$qflagz:$qflagad:$qflagcd:$qflagepr:$qflagedo";
	$rrdata .= ":$mcrrset:$mcmessg:$mmitera:$mmvalid";
	$rrdata .= ":$nanoerr:$naforme:$naservf:$nanxdom:$nanotim:$narefus:$nanodat:$nasecur:$nabogus:$narsbog";
	$rrdata .= ":$unwquer:$unwrepl:$nqtcp:$nqtls:$nqipv6";
	$rrdata .= ":$h0uto2m:$h2mto4m:$h4mto8m:$h8mto16m:$h16mto32m:$h32mto64m:$h64mto128m:$h128mto256m:$h256mto512m:$h512mto1s";
	$rrdata .= ":$h1sto2s:$h2sto4s:$h4sto8s:$h8sto16s:$h16sto32s:$h32sto64s:$h64sto128s:$h128sto256s:$h256sto512s:$h512stomore";
	$rrdata .= ":0:0:0:0:0:0:0:0:0:0";

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub unbound_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $unbound = $config->{unbound};
	my @rigid = split(',', ($unbound->{rigid} || ""));
	my @limit = split(',', ($unbound->{limit} || ""));
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
	my @CDEF;
	my $str;
	my $n;
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


	# text mode
	#
	if(lc($config->{iface_mode}) eq "text") {
		if($title) {
			push(@output, main::graph_header($title, 2));
			push(@output, "    <tr>\n");
			push(@output, "    <td bgcolor='$colors->{title_bg_color}'>\n");
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
		my $line3;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		$line1 = "                                                   $config->{graphs}->{_unbound1}                                                                                                                                                 $config->{graphs}->{_unbound2}  $config->{graphs}->{_unbound3}                                                                        $config->{graphs}->{_unbound5}                     $config->{graphs}->{_unbound6}                                                     $config->{graphs}->{_unbound7}                        $config->{graphs}->{_unbound8}                                                     $config->{graphs}->{_unbound9}                                                     $config->{graphs}->{_unbound10}";
		$line3 = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
		$line2 = sprintf(" %7s %7s %7s %7s %7s %7s %7s %7s %7s", "Queries", "CacheHi", "CacheMi", "RecursR", "ReqLAvg", "ReqLMax", "ReqLOve", "ReqLExc", "ReqLAll");
		foreach (split(',', $unbound->{queries_type})) {
			$str = sprintf("%7s", substr(trim($_), 0, 7));
			$line2 .= sprintf(" %7s", $str);
		}
		$line2 .= sprintf(" %7s %7s", "RTimeAv", "RTimeMe");
		$line2 .= sprintf(" %7s", " Uptime");
		$line2 .= sprintf(" %7s %7s %7s %7s %7s %7s %7s %7s %7s %7s", "Flag-QR", "Flag-AA", "Flag-TC", "Flag-RD", "Flag-RA", " Flag-Z", "Flag-AD", "Flag-CD", "EDNSPre", "EDNS-DO");
		$line2 .= sprintf(" %7s %7s %7s %7s", "C.rrset", "C.messg", "Mod.Ite", "Mod.Val");
		$line2 .= sprintf(" %7s %7s %7s %7s %7s %7s %7s %7s %7s %7s", "NOERROR", "FORMERR", "SERVFAI", "NXDOMAI", "NOTIMPL", "REFUSED", " NODATA", " Secure", "A.Bogus", "RRBogus");
		$line2 .= sprintf(" %7s %7s %7s %7s %7s", "UnwantQ", "UnwantR", "    TCP", "    TSL", "   IPv6");
		$line2 .= sprintf(" %7s %7s %7s %7s %7s %7s %7s %7s %7s %7s", "  0u-2m", "   2-4m", "   4-8m", "  8-16m", " 16-32m", " 32-64m", "64-128m", "128-256", "256-512", "512m-1s");
		$line2 .= sprintf(" %7s %7s %7s %7s %7s %7s %7s %7s %7s %7s", "   1-2s", "   2-4s", "   4-8s", "  8-16s", " 16-32s", " 32-64s", "64-128s", "128-256", "256-512", "512s-..");

		push(@output, "    $line1\n");
		push(@output, "Time$line2 \n");
		push(@output, "----$line3 \n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			@row = @$line[1..9];
			push(@output, sprintf("%7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row));
			@row = @$line[10..29];
			push(@output, sprintf("%7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row));
			@row = @$line[30..32];
			push(@output, sprintf("%7d %7d %7d ", $row[0], $row[1], $row[2] / 86400));
			@row = @$line[33..42];
			push(@output, sprintf("%7d %7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row));
			@row = @$line[43..46];
			push(@output, sprintf("%7d %7d %7d %7d ", @row));
			@row = @$line[47..56];
			push(@output, sprintf("%7d %7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row));
			@row = @$line[57..61];
			push(@output, sprintf("%7d %7d %7d %7d %7d ", @row));
			@row = @$line[62..71];
			push(@output, sprintf("%7d %7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row));
			@row = @$line[72..81];
			push(@output, sprintf("%7d %7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row));
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

	my $IMG1 = $u . $package . "1." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2 = $u . $package . "2." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3 = $u . $package . "3." . $tf->{when} . ".$imgfmt_lc";
	my $IMG4 = $u . $package . "4." . $tf->{when} . ".$imgfmt_lc";
	my $IMG5 = $u . $package . "5." . $tf->{when} . ".$imgfmt_lc";
	my $IMG6 = $u . $package . "6." . $tf->{when} . ".$imgfmt_lc";
	my $IMG7 = $u . $package . "7." . $tf->{when} . ".$imgfmt_lc";
	my $IMG8 = $u . $package . "8." . $tf->{when} . ".$imgfmt_lc";
	my $IMG9 = $u . $package . "9." . $tf->{when} . ".$imgfmt_lc";
	my $IMG10 = $u . $package . "10." . $tf->{when} . ".$imgfmt_lc";
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG4z = $u . $package . "4z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG5z = $u . $package . "5z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG6z = $u . $package . "6z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG7z = $u . $package . "7z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG8z = $u . $package . "8z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG9z = $u . $package . "9z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG10z = $u . $package . "10z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3",
		"$IMG_DIR" . "$IMG4",
		"$IMG_DIR" . "$IMG5",
		"$IMG_DIR" . "$IMG6",
		"$IMG_DIR" . "$IMG7",
		"$IMG_DIR" . "$IMG8",
		"$IMG_DIR" . "$IMG9",
		"$IMG_DIR" . "$IMG10");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
    			"$IMG_DIR" . "$IMG2z",
    			"$IMG_DIR" . "$IMG3z",
    			"$IMG_DIR" . "$IMG4z",
    			"$IMG_DIR" . "$IMG5z",
    			"$IMG_DIR" . "$IMG6z",
    			"$IMG_DIR" . "$IMG7z",
    			"$IMG_DIR" . "$IMG8z",
    			"$IMG_DIR" . "$IMG9z",
    			"$IMG_DIR" . "$IMG10z");
	}

	my $e;		# ??????????
	my $l;		# ??????????
	my @IMG;	# ??????????
	my @IMGz;	# ??????????

	if($title) {
		push(@output, main::graph_header($title, 2));
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:tnumquer#FFA500:Queries");
	push(@tmp, "GPRINT:tnumquer:LAST:          Cur\\:%5.1lf");
	push(@tmp, "GPRINT:tnumquer:AVERAGE:Avg\\:%5.1lf");
	push(@tmp, "GPRINT:tnumquer:MIN:Min\\:%5.1lf");
	push(@tmp, "GPRINT:tnumquer:MAX:Max\\:%5.1lf\\n");
	push(@tmp, "LINE2:tnumchit#00EEEE:Cache Hits");
	push(@tmp, "GPRINT:tnumchit:LAST:       Cur\\:%5.1lf");
	push(@tmp, "GPRINT:tnumchit:AVERAGE:Avg\\:%5.1lf");
	push(@tmp, "GPRINT:tnumchit:MIN:Min\\:%5.1lf");
	push(@tmp, "GPRINT:tnumchit:MAX:Max\\:%5.1lf\\n");
	push(@tmp, "LINE2:tnumcmis#00EE00:Cache Miss");
	push(@tmp, "GPRINT:tnumcmis:LAST:       Cur\\:%5.1lf");
	push(@tmp, "GPRINT:tnumcmis:AVERAGE:Avg\\:%5.1lf");
	push(@tmp, "GPRINT:tnumcmis:MIN:Min\\:%5.1lf");
	push(@tmp, "GPRINT:tnumcmis:MAX:Max\\:%5.1lf\\n");
	push(@tmp, "LINE2:tnumrecr#0000EE:Recursive Replies");
	push(@tmp, "GPRINT:tnumrecr:LAST:Cur\\:%5.1lf");
	push(@tmp, "GPRINT:tnumrecr:AVERAGE:Avg\\:%5.1lf");
	push(@tmp, "GPRINT:tnumrecr:MIN:Min\\:%5.1lf");
	push(@tmp, "GPRINT:tnumrecr:MAX:Max\\:%5.1lf\\n");
	push(@tmp, "LINE2:treqavg#448844:Req. List Avg");
	push(@tmp, "GPRINT:treqavg:LAST:    Cur\\:%5.1lf");
	push(@tmp, "GPRINT:treqavg:AVERAGE:Avg\\:%5.1lf");
	push(@tmp, "GPRINT:treqavg:MIN:Min\\:%5.1lf");
	push(@tmp, "GPRINT:treqavg:MAX:Max\\:%5.1lf\\n");
	push(@tmp, "LINE2:treqmax#EE0000:Req. List Max");
	push(@tmp, "GPRINT:treqmax:LAST:    Cur\\:%5.1lf");
	push(@tmp, "GPRINT:treqmax:AVERAGE:Avg\\:%5.1lf");
	push(@tmp, "GPRINT:treqmax:MIN:Min\\:%5.1lf");
	push(@tmp, "GPRINT:treqmax:MAX:Max\\:%5.1lf\\n");
	push(@tmp, "LINE2:treqove#EE00EE:Req. List Over");
	push(@tmp, "GPRINT:treqove:LAST:   Cur\\:%5.1lf");
	push(@tmp, "GPRINT:treqove:AVERAGE:Avg\\:%5.1lf");
	push(@tmp, "GPRINT:treqove:MIN:Min\\:%5.1lf");
	push(@tmp, "GPRINT:treqove:MAX:Max\\:%5.1lf\\n");
	push(@tmp, "LINE2:treqexc#EEEE00:Req. List Exc");
	push(@tmp, "GPRINT:treqexc:LAST:    Cur\\:%5.1lf");
	push(@tmp, "GPRINT:treqexc:AVERAGE:Avg\\:%5.1lf");
	push(@tmp, "GPRINT:treqexc:MIN:Min\\:%5.1lf");
	push(@tmp, "GPRINT:treqexc:MAX:Max\\:%5.1lf\\n");
	push(@tmp, "LINE2:treqall#B4B444:Req. List Cur All");
	push(@tmp, "GPRINT:treqall:LAST:Cur\\:%5.1lf");
	push(@tmp, "GPRINT:treqall:AVERAGE:Avg\\:%5.1lf");
	push(@tmp, "GPRINT:treqall:MIN:Min\\:%5.1lf");
	push(@tmp, "GPRINT:treqall:MAX:Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:tnumquer#FFA500:Queries");
	push(@tmpz, "LINE2:tnumchit#00EEEE:Cache Hits");
	push(@tmpz, "LINE2:tnumcmis#00EE00:Cache Miss");
	push(@tmpz, "LINE2:tnumrecr#0000EE:Recursive Replies");
	push(@tmpz, "LINE2:treqavg#448844:Req. List Average");
	push(@tmpz, "LINE2:treqmax#EE0000:Req. List Max");
	push(@tmpz, "LINE2:treqove#EE00EE:Req. List Over");
	push(@tmpz, "LINE2:treqexc#EEEE00:Req. List Exc");
	push(@tmpz, "LINE2:treqall#B4B444:Req. List Cur All");
	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG1",
		"--title=$config->{graphs}->{_unbound1}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:tnumquer=$rrd:unbound_tnumquer:AVERAGE",
		"DEF:tnumchit=$rrd:unbound_tnumchit:AVERAGE",
		"DEF:tnumcmis=$rrd:unbound_tnumcmis:AVERAGE",
		"DEF:tnumrecr=$rrd:unbound_tnumrecr:AVERAGE",
		"DEF:treqavg=$rrd:unbound_treqavg:AVERAGE",
		"DEF:treqmax=$rrd:unbound_treqmax:AVERAGE",
		"DEF:treqove=$rrd:unbound_treqove:AVERAGE",
		"DEF:treqexc=$rrd:unbound_treqexc:AVERAGE",
		"DEF:treqall=$rrd:unbound_treqall:AVERAGE",
		"CDEF:allvalues=tnumquer,tnumchit,tnumcmis,tnumrecr,treqavg,treqmax,treqove,treqexc,treqall,+,+,+,+,+,+,+,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_unbound1}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:tnumquer=$rrd:unbound_tnumquer:AVERAGE",
			"DEF:tnumchit=$rrd:unbound_tnumchit:AVERAGE",
			"DEF:tnumcmis=$rrd:unbound_tnumcmis:AVERAGE",
			"DEF:tnumrecr=$rrd:unbound_tnumrecr:AVERAGE",
			"DEF:treqavg=$rrd:unbound_treqavg:AVERAGE",
			"DEF:treqmax=$rrd:unbound_treqmax:AVERAGE",
			"DEF:treqove=$rrd:unbound_treqove:AVERAGE",
			"DEF:treqexc=$rrd:unbound_treqexc:AVERAGE",
			"DEF:treqall=$rrd:unbound_treqall:AVERAGE",
			"CDEF:allvalues=tnumquer,tnumchit,tnumcmis,tnumrecr,treqavg,treqmax,treqove,treqexc,treqall,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /unbound1/)) {
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
	if($title) {
		push(@output, "    </td>\n");
	}

	@riglim = @{setup_riglim($rigid[1], $limit[1])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	my @i = split(',', $unbound->{queries_type});
	for($n = 0; $n < scalar(@i); $n += 2) {
		$str = sprintf("%-8s", substr(trim($i[$n]), 0, 8));
		push(@tmp, "LINE2:qtype" . $n . $LC[$n] . ":$str");
		push(@tmp, "GPRINT:qtype" . $n . ":LAST: Current\\:%5.1lf       ");
		push(@tmpz, "LINE2:qtype" . $n . $LC[$n] . ":$str");
		$str = sprintf("%-8s", substr(trim($i[$n + 1]), 0, 8));
		push(@tmp, "LINE2:qtype" . ($n + 1) . $LC[$n + 1] . ":$str");
		push(@tmp, "GPRINT:qtype" . ($n + 1) . ":LAST: Current\\:%5.1lf\\n");
		push(@tmpz, "LINE2:qtype" . ($n + 1) . $LC[$n + 1] . ":$str");
	}
	for(; $n < 20; $n += 2) {
		push(@tmp, "COMMENT: \\n");
	}
	if($title) {
		push(@output, "    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_unbound2}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:qtype0=$rrd:unbound_qtype01:AVERAGE",
		"DEF:qtype1=$rrd:unbound_qtype02:AVERAGE",
		"DEF:qtype2=$rrd:unbound_qtype03:AVERAGE",
		"DEF:qtype3=$rrd:unbound_qtype04:AVERAGE",
		"DEF:qtype4=$rrd:unbound_qtype05:AVERAGE",
		"DEF:qtype5=$rrd:unbound_qtype06:AVERAGE",
		"DEF:qtype6=$rrd:unbound_qtype07:AVERAGE",
		"DEF:qtype7=$rrd:unbound_qtype08:AVERAGE",
		"DEF:qtype8=$rrd:unbound_qtype09:AVERAGE",
		"DEF:qtype9=$rrd:unbound_qtype10:AVERAGE",
		"DEF:qtype10=$rrd:unbound_qtype11:AVERAGE",
		"DEF:qtype11=$rrd:unbound_qtype12:AVERAGE",
		"DEF:qtype12=$rrd:unbound_qtype13:AVERAGE",
		"DEF:qtype13=$rrd:unbound_qtype14:AVERAGE",
		"DEF:qtype14=$rrd:unbound_qtype15:AVERAGE",
		"DEF:qtype15=$rrd:unbound_qtype16:AVERAGE",
		"DEF:qtype16=$rrd:unbound_qtype17:AVERAGE",
		"DEF:qtype17=$rrd:unbound_qtype18:AVERAGE",
		"DEF:qtype18=$rrd:unbound_qtype19:AVERAGE",
		"DEF:qtype19=$rrd:unbound_qtype20:AVERAGE",
		"CDEF:allvalues=qtype0,qtype1,qtype2,qtype3,qtype4,qtype5,qtype6,qtype7,qtype8,qtype9,qtype10,qtype11,qtype12,qtype13,qtype14,qtype15,qtype16,qtype17,qtype18,qtype19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_unbound2}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:qtype0=$rrd:unbound_qtype01:AVERAGE",
			"DEF:qtype1=$rrd:unbound_qtype02:AVERAGE",
			"DEF:qtype2=$rrd:unbound_qtype03:AVERAGE",
			"DEF:qtype3=$rrd:unbound_qtype04:AVERAGE",
			"DEF:qtype4=$rrd:unbound_qtype05:AVERAGE",
			"DEF:qtype5=$rrd:unbound_qtype06:AVERAGE",
			"DEF:qtype6=$rrd:unbound_qtype07:AVERAGE",
			"DEF:qtype7=$rrd:unbound_qtype08:AVERAGE",
			"DEF:qtype8=$rrd:unbound_qtype09:AVERAGE",
			"DEF:qtype9=$rrd:unbound_qtype10:AVERAGE",
			"DEF:qtype10=$rrd:unbound_qtype11:AVERAGE",
			"DEF:qtype11=$rrd:unbound_qtype12:AVERAGE",
			"DEF:qtype12=$rrd:unbound_qtype13:AVERAGE",
			"DEF:qtype13=$rrd:unbound_qtype14:AVERAGE",
			"DEF:qtype14=$rrd:unbound_qtype15:AVERAGE",
			"DEF:qtype15=$rrd:unbound_qtype16:AVERAGE",
			"DEF:qtype16=$rrd:unbound_qtype17:AVERAGE",
			"DEF:qtype17=$rrd:unbound_qtype18:AVERAGE",
			"DEF:qtype18=$rrd:unbound_qtype19:AVERAGE",
			"DEF:qtype19=$rrd:unbound_qtype20:AVERAGE",
			"CDEF:allvalues=qtype0,qtype1,qtype2,qtype3,qtype4,qtype5,qtype6,qtype7,qtype8,qtype9,qtype10,qtype11,qtype12,qtype13,qtype14,qtype15,qtype16,qtype17,qtype18,qtype19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /unbound2/)) {
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
	if($title) {
		push(@output, "    </td>\n");
	}

	@riglim = @{setup_riglim($rigid[2], $limit[2])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:trtavg#FFA500:Average");
	push(@tmp, "GPRINT:trtavg:LAST:  Cur\\:%5.1lf");
	push(@tmp, "GPRINT:trtavg:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:trtavg:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:trtavg:MAX: Max\\:%5.1lf\\n");
	push(@tmp, "LINE2:trtmed#00EEEE:Median");
	push(@tmp, "GPRINT:trtmed:LAST:   Cur\\:%5.1lf");
	push(@tmp, "GPRINT:trtmed:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:trtmed:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:trtmed:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:trtavg#FFA500:Average");
	push(@tmpz, "LINE2:trtmed#00EEEE:Median");
	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium2});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG3",
		"--title=$config->{graphs}->{_unbound3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Seconds",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:trtavg=$rrd:unbound_trtavg:AVERAGE",
		"DEF:trtmed=$rrd:unbound_trtmed:AVERAGE",
		"CDEF:allvalues=trtavg,trtmed,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_unbound3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Seconds",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:trtavg=$rrd:unbound_trtavg:AVERAGE",
			"DEF:trtmed=$rrd:unbound_trtmed:AVERAGE",
			"CDEF:allvalues=trtavg,trtmed,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /unbound3/)) {
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
	}

	@riglim = @{setup_riglim($rigid[3], $limit[3])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:uptime_days#EE44EE:Uptime");
	push(@tmp, "GPRINT:uptime_days:LAST:   Cur\\:%5.1lf");
	push(@tmp, "GPRINT:uptime_days:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:uptime_days:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:uptime_days:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:uptime_days#EE44EE:Uptime");
	if($title) {
		push(@output, "    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium2});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG4",
		"--title=$config->{graphs}->{_unbound4}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Days",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:uptime=$rrd:unbound_uptime:AVERAGE",
		"CDEF:uptime_days=uptime,86400,/",
		"CDEF:allvalues=uptime",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG4z",
			"--title=$config->{graphs}->{_unbound4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Days",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:uptime=$rrd:unbound_uptime:AVERAGE",
			"CDEF:uptime_days=uptime,86400,/",
			"CDEF:allvalues=uptime",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /unbound4/)) {
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
	if($title) {
		push(@output, "    </td>\n");
	}

	@riglim = @{setup_riglim($rigid[4], $limit[4])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:unwquer#EEEE00:Unwanted Queries");
	push(@tmp, "GPRINT:unwquer" . ":LAST: Cur\\:%4.0lf%s");
	push(@tmp, "GPRINT:unwquer" . ":AVERAGE:Avg\\:%4.0lf%s");
	push(@tmp, "GPRINT:unwquer" . ":MIN:Min\\:%4.0lf%s");
	push(@tmp, "GPRINT:unwquer" . ":MAX:Max\\:%4.0lf%s\\n");
	push(@tmpz, "LINE2:unwquer#EEEE00:Unwanted Queries");
	push(@tmp, "LINE2:unwrepl#0000EE:Unwanted Replies");
	push(@tmp, "GPRINT:unwrepl" . ":LAST: Cur\\:%4.0lf%s");
	push(@tmp, "GPRINT:unwrepl" . ":AVERAGE:Avg\\:%4.0lf%s");
	push(@tmp, "GPRINT:unwrepl" . ":MIN:Min\\:%4.0lf%s");
	push(@tmp, "GPRINT:unwrepl" . ":MAX:Max\\:%4.0lf%s\\n");
	push(@tmpz, "LINE2:unwrepl#0000EE:Unwanted Replies");
	push(@tmp, "LINE2:nqtcp#00EEEE:TCP");
	push(@tmp, "GPRINT:nqtcp" . ":LAST:              Cur\\:%4.0lf%s");
	push(@tmp, "GPRINT:nqtcp" . ":AVERAGE:Avg\\:%4.0lf%s");
	push(@tmp, "GPRINT:nqtcp" . ":MIN:Min\\:%4.0lf%s");
	push(@tmp, "GPRINT:nqtcp" . ":MAX:Max\\:%4.0lf%s\\n");
	push(@tmpz, "LINE2:nqtcp#00EEEE:TCP");
	push(@tmp, "LINE2:nqtls#00EE00:TLS");
	push(@tmp, "GPRINT:nqtls" . ":LAST:              Cur\\:%4.0lf%s");
	push(@tmp, "GPRINT:nqtls" . ":AVERAGE:Avg\\:%4.0lf%s");
	push(@tmp, "GPRINT:nqtls" . ":MIN:Min\\:%4.0lf%s");
	push(@tmp, "GPRINT:nqtls" . ":MAX:Max\\:%4.0lf%s\\n");
	push(@tmpz, "LINE2:nqtls#00EE00:TLS");
	push(@tmp, "LINE2:nqipv6#EE00EE:IPv6");
	push(@tmp, "GPRINT:nqipv6" . ":LAST:             Cur\\:%4.0lf%s");
	push(@tmp, "GPRINT:nqipv6" . ":AVERAGE:Avg\\:%4.0lf%s");
	push(@tmp, "GPRINT:nqipv6" . ":MIN:Min\\:%4.0lf%s");
	push(@tmp, "GPRINT:nqipv6" . ":MAX:Max\\:%4.0lf%s\\n");
	push(@tmpz, "LINE2:nqipv6#EE00EE:IPv6");
	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium2});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG5",
		"--title=$config->{graphs}->{_unbound5}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:unwquer=$rrd:unbound_unwquer:AVERAGE",
		"DEF:unwrepl=$rrd:unbound_unwrepl:AVERAGE",
		"DEF:nqtcp=$rrd:unbound_nqtcp:AVERAGE",
		"DEF:nqtls=$rrd:unbound_nqtls:AVERAGE",
		"DEF:nqipv6=$rrd:unbound_nqipv6:AVERAGE",
		"CDEF:allvalues=unwquer,unwrepl,nqtcp,nqtls,nqipv6,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG5z",
			"--title=$config->{graphs}->{_unbound5}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:unwquer=$rrd:unbound_unwquer:AVERAGE",
			"DEF:unwrepl=$rrd:unbound_unwrepl:AVERAGE",
			"DEF:nqtcp=$rrd:unbound_nqtcp:AVERAGE",
			"DEF:nqtls=$rrd:unbound_nqtls:AVERAGE",
			"DEF:nqipv6=$rrd:unbound_nqipv6:AVERAGE",
			"CDEF:allvalues=unwquer,unwrepl,nqtcp,nqtls,nqipv6,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /unbound5/)) {
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
	if($title) {
		push(@output, "    </td>\n");
	}

	@riglim = @{setup_riglim($rigid[5], $limit[5])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:mcrrset#EEEE00:Cache RRset:STACK");
	push(@tmp, "GPRINT:mcrrset" . ":LAST:     Cur\\:%4.0lf%s");
	push(@tmp, "GPRINT:mcrrset" . ":AVERAGE:Avg\\:%4.0lf%s");
	push(@tmp, "GPRINT:mcrrset" . ":MIN:Min\\:%4.0lf%s");
	push(@tmp, "GPRINT:mcrrset" . ":MAX:Max\\:%4.0lf%s\\n");
	push(@tmpz, "AREA:mcrrset#EEEE00:Cache RRset:STACK");
	push(@tmp, "AREA:mcmessg#0000EE:Cache Messages:STACK");
	push(@tmp, "GPRINT:mcmessg" . ":LAST:  Cur\\:%4.0lf%s");
	push(@tmp, "GPRINT:mcmessg" . ":AVERAGE:Avg\\:%4.0lf%s");
	push(@tmp, "GPRINT:mcmessg" . ":MIN:Min\\:%4.0lf%s");
	push(@tmp, "GPRINT:mcmessg" . ":MAX:Max\\:%4.0lf%s\\n");
	push(@tmpz, "AREA:mcmessg#0000EE:Cache Messages:STACK");
	push(@tmp, "AREA:mmitera#00EEEE:Module Iterator:STACK");
	push(@tmp, "GPRINT:mmitera" . ":LAST: Cur\\:%4.0lf%s");
	push(@tmp, "GPRINT:mmitera" . ":AVERAGE:Avg\\:%4.0lf%s");
	push(@tmp, "GPRINT:mmitera" . ":MIN:Min\\:%4.0lf%s");
	push(@tmp, "GPRINT:mmitera" . ":MAX:Max\\:%4.0lf%s\\n");
	push(@tmpz, "AREA:mmitera#00EEEE:Module Iterator:STACK");
	push(@tmp, "AREA:mmvalid#EE00EE:Module Validator:STACK");
	push(@tmp, "GPRINT:mmvalid" . ":LAST:Cur\\:%4.0lf%s");
	push(@tmp, "GPRINT:mmvalid" . ":AVERAGE:Avg\\:%4.0lf%s");
	push(@tmp, "GPRINT:mmvalid" . ":MIN:Min\\:%4.0lf%s");
	push(@tmp, "GPRINT:mmvalid" . ":MAX:Max\\:%4.0lf%s\\n");
	push(@tmpz, "AREA:mmvalid#EE00EE:Module Validator:STACK");
	if($title) {
		push(@output, "    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium2});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG6",
		"--title=$config->{graphs}->{_unbound6}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=bytes",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:mcrrset=$rrd:unbound_mcrrset:AVERAGE",
		"DEF:mcmessg=$rrd:unbound_mcmessg:AVERAGE",
		"DEF:mmitera=$rrd:unbound_mmitera:AVERAGE",
		"DEF:mmvalid=$rrd:unbound_mmvalid:AVERAGE",
		"CDEF:allvalues=mcrrset,mcmessg,mmitera,mmvalid,+,+,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG6: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG6z",
			"--title=$config->{graphs}->{_unbound6}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=bytes",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:mcrrset=$rrd:unbound_mcrrset:AVERAGE",
			"DEF:mcmessg=$rrd:unbound_mcmessg:AVERAGE",
			"DEF:mmitera=$rrd:unbound_mmitera:AVERAGE",
			"DEF:mmvalid=$rrd:unbound_mmvalid:AVERAGE",
			"CDEF:allvalues=mcrrset,mcmessg,mmitera,mmvalid,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG6z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /unbound6/)) {
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
	if($title) {
		push(@output, "    </td>\n");
	}

	@riglim = @{setup_riglim($rigid[6], $limit[6])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:nanoerr#FFA500:NOERROR");
	push(@tmp, "GPRINT:nanoerr:LAST:      Cur\\:%5.1lf");
	push(@tmp, "GPRINT:nanoerr:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:nanoerr:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:nanoerr:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:nanoerr#FFA500:NOERROR");
	push(@tmp, "LINE2:naforme#00EE00:FORMERR");
	push(@tmp, "GPRINT:naforme:LAST:      Cur\\:%5.1lf");
	push(@tmp, "GPRINT:naforme:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:naforme:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:naforme:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:naforme#00EE00:FORMERR");
	push(@tmp, "LINE2:naservf#448844:SERVFAIL");
	push(@tmp, "GPRINT:naservf:LAST:     Cur\\:%5.1lf");
	push(@tmp, "GPRINT:naservf:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:naservf:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:naservf:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:naservf#448844:SERVFAIL");
	push(@tmp, "LINE2:nanxdom#EE00EE:NXDOMAIN");
	push(@tmp, "GPRINT:nanxdom:LAST:     Cur\\:%5.1lf");
	push(@tmp, "GPRINT:nanxdom:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:nanxdom:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:nanxdom:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:nanxdom#EE00EE:NXDOMAIN");
	push(@tmp, "LINE2:nanotim#B4B444:NOTIMPL");
	push(@tmp, "GPRINT:nanotim:LAST:      Cur\\:%5.1lf");
	push(@tmp, "GPRINT:nanotim:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:nanotim:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:nanotim:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:nanotim#B4B444:NOTIMPL");
	push(@tmp, "LINE2:narefus#00EEEE:REFUSED");
	push(@tmp, "GPRINT:narefus:LAST:      Cur\\:%5.1lf");
	push(@tmp, "GPRINT:narefus:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:narefus:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:narefus:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:narefus#00EEEE:REFUSED");
	push(@tmp, "LINE2:nanodat#0000EE:nodata");
	push(@tmp, "GPRINT:nanodat:LAST:       Cur\\:%5.1lf");
	push(@tmp, "GPRINT:nanodat:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:nanodat:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:nanodat:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:nanodat#0000EE:nodata");
	push(@tmp, "LINE2:nasecur#EE0000:Answer Secure");
	push(@tmp, "GPRINT:nasecur:LAST:Cur\\:%5.1lf");
	push(@tmp, "GPRINT:nasecur:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:nasecur:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:nasecur:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:nasecur#EE0000:Answer Secure");
	push(@tmp, "LINE2:nabogus#EEEE00:Answer Bogus");
	push(@tmp, "GPRINT:nabogus:LAST: Cur\\:%5.1lf");
	push(@tmp, "GPRINT:nabogus:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:nabogus:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:nabogus:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:nabogus#EEEE00:Answer Bogus");
	push(@tmp, "LINE2:narsbog#8A2908:RRset Bogus");
	push(@tmp, "GPRINT:narsbog:LAST:  Cur\\:%5.1lf");
	push(@tmp, "GPRINT:narsbog:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:narsbog:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:narsbog:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:narsbog#8A2908:RRset Bogus");
	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG7",
		"--title=$config->{graphs}->{_unbound7}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:nanoerr=$rrd:unbound_nanoerr:AVERAGE",
		"DEF:naforme=$rrd:unbound_naforme:AVERAGE",
		"DEF:naservf=$rrd:unbound_naservf:AVERAGE",
		"DEF:nanxdom=$rrd:unbound_nanxdom:AVERAGE",
		"DEF:nanotim=$rrd:unbound_nanotim:AVERAGE",
		"DEF:narefus=$rrd:unbound_narefus:AVERAGE",
		"DEF:nanodat=$rrd:unbound_nanodat:AVERAGE",
		"DEF:nasecur=$rrd:unbound_nasecur:AVERAGE",
		"DEF:nabogus=$rrd:unbound_nabogus:AVERAGE",
		"DEF:narsbog=$rrd:unbound_narsbog:AVERAGE",
		"CDEF:allvalues=nanoerr,naforme,naservf,nanxdom,nanotim,narefus,nanodat,nasecur,nabogus,narsbog,+,+,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG7: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG7z",
			"--title=$config->{graphs}->{_unbound7}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:nanoerr=$rrd:unbound_nanoerr:AVERAGE",
			"DEF:naforme=$rrd:unbound_naforme:AVERAGE",
			"DEF:naservf=$rrd:unbound_naservf:AVERAGE",
			"DEF:nanxdom=$rrd:unbound_nanxdom:AVERAGE",
			"DEF:nanotim=$rrd:unbound_nanotim:AVERAGE",
			"DEF:narefus=$rrd:unbound_narefus:AVERAGE",
			"DEF:nanodat=$rrd:unbound_nanodat:AVERAGE",
			"DEF:nasecur=$rrd:unbound_nasecur:AVERAGE",
			"DEF:nabogus=$rrd:unbound_nabogus:AVERAGE",
			"DEF:narsbog=$rrd:unbound_narsbog:AVERAGE",
			"CDEF:allvalues=nanoerr,naforme,naservf,nanxdom,nanotim,narefus,nanodat,nasecur,nabogus,narsbog,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG7z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /unbound7/)) {
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
	if($title) {
		push(@output, "    </td>\n");
	}

	@riglim = @{setup_riglim($rigid[7], $limit[7])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:qflagqr#FFA500:QR");
	push(@tmp, "GPRINT:qflagqr:LAST:       Cur\\:%5.1lf");
	push(@tmp, "GPRINT:qflagqr:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:qflagqr:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:qflagqr:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:qflagqr#FFA500:QR");
	push(@tmp, "LINE2:qflagaa#00EE00:AA");
	push(@tmp, "GPRINT:qflagaa:LAST:       Cur\\:%5.1lf");
	push(@tmp, "GPRINT:qflagaa:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:qflagaa:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:qflagaa:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:qflagaa#00EE00:AA");
	push(@tmp, "LINE2:qflagtc#448844:TC");
	push(@tmp, "GPRINT:qflagtc:LAST:       Cur\\:%5.1lf");
	push(@tmp, "GPRINT:qflagtc:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:qflagtc:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:qflagtc:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:qflagtc#448844:TC");
	push(@tmp, "LINE2:qflagrd#EE00EE:RD");
	push(@tmp, "GPRINT:qflagrd:LAST:       Cur\\:%5.1lf");
	push(@tmp, "GPRINT:qflagrd:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:qflagrd:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:qflagrd:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:qflagrd#EE00EE:RD");
	push(@tmp, "LINE2:qflagra#B4B444:RA");
	push(@tmp, "GPRINT:qflagra:LAST:       Cur\\:%5.1lf");
	push(@tmp, "GPRINT:qflagra:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:qflagra:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:qflagra:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:qflagra#B4B444:RA");
	push(@tmp, "LINE2:qflagz#00EEEE:Z");
	push(@tmp, "GPRINT:qflagz:LAST:        Cur\\:%5.1lf");
	push(@tmp, "GPRINT:qflagz:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:qflagz:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:qflagz:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:qflagz#00EEEE:Z");
	push(@tmp, "LINE2:qflagad#0000EE:AD");
	push(@tmp, "GPRINT:qflagad:LAST:       Cur\\:%5.1lf");
	push(@tmp, "GPRINT:qflagad:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:qflagad:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:qflagad:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:qflagad#0000EE:AD");
	push(@tmp, "LINE2:qflagcd#EE0000:CD");
	push(@tmp, "GPRINT:qflagcd:LAST:       Cur\\:%5.1lf");
	push(@tmp, "GPRINT:qflagcd:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:qflagcd:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:qflagcd:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:qflagcd#EE0000:CD");
	push(@tmp, "LINE2:qflagepr#EEEE00:EDNS Pres");
	push(@tmp, "GPRINT:qflagepr:LAST:Cur\\:%5.1lf");
	push(@tmp, "GPRINT:qflagepr:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:qflagepr:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:qflagepr:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:qflagepr#EEEE00:EDNS Pres");
	push(@tmp, "LINE2:qflagedo#8A2908:EDNS DO");
	push(@tmp, "GPRINT:qflagedo:LAST:  Cur\\:%5.1lf");
	push(@tmp, "GPRINT:qflagedo:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:qflagedo:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:qflagedo:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "LINE2:qflagedo#8A2908:EDNS DO");
	if($title) {
		push(@output, "    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG8",
		"--title=$config->{graphs}->{_unbound8}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:qflagqr=$rrd:unbound_qflagqr:AVERAGE",
		"DEF:qflagaa=$rrd:unbound_qflagaa:AVERAGE",
		"DEF:qflagtc=$rrd:unbound_qflagtc:AVERAGE",
		"DEF:qflagrd=$rrd:unbound_qflagrd:AVERAGE",
		"DEF:qflagra=$rrd:unbound_qflagra:AVERAGE",
		"DEF:qflagz=$rrd:unbound_qflagz:AVERAGE",
		"DEF:qflagad=$rrd:unbound_qflagad:AVERAGE",
		"DEF:qflagcd=$rrd:unbound_qflagcd:AVERAGE",
		"DEF:qflagepr=$rrd:unbound_qflagepr:AVERAGE",
		"DEF:qflagedo=$rrd:unbound_qflagedo:AVERAGE",
		"CDEF:allvalues=qflagqr,qflagaa,qflagtc,qflagrd,qflagra,qflagz,qflagad,qflagcd,qflagepr,qflagedo,+,+,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG8: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG8z",
			"--title=$config->{graphs}->{_unbound8}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:qflagqr=$rrd:unbound_qflagqr:AVERAGE",
			"DEF:qflagaa=$rrd:unbound_qflagaa:AVERAGE",
			"DEF:qflagtc=$rrd:unbound_qflagtc:AVERAGE",
			"DEF:qflagrd=$rrd:unbound_qflagrd:AVERAGE",
			"DEF:qflagra=$rrd:unbound_qflagra:AVERAGE",
			"DEF:qflagz=$rrd:unbound_qflagz:AVERAGE",
			"DEF:qflagad=$rrd:unbound_qflagad:AVERAGE",
			"DEF:qflagcd=$rrd:unbound_qflagcd:AVERAGE",
			"DEF:qflagepr=$rrd:unbound_qflagepr:AVERAGE",
			"DEF:qflagedo=$rrd:unbound_qflagedo:AVERAGE",
			"CDEF:allvalues=qflagqr,qflagaa,qflagtc,qflagrd,qflagra,qflagz,qflagad,qflagcd,qflagepr,qflagedo,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG8z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /unbound8/)) {
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
	if($title) {
		push(@output, "    </td>\n");
	}

	@riglim = @{setup_riglim($rigid[8], $limit[8])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:h0uto2m#FFA500:0μs - 2ms:STACK");
	push(@tmp, "GPRINT:h0uto2m:LAST:    Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h0uto2m:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h0uto2m:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h0uto2m:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h0uto2m#FFA500:0μs - 2ms:STACK");
	push(@tmp, "AREA:h2mto4m#00EE00:2ms - 4ms:STACK");
	push(@tmp, "GPRINT:h2mto4m:LAST:    Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h2mto4m:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h2mto4m:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h2mto4m:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h2mto4m#00EE00:2ms - 4ms:STACK");
	push(@tmp, "AREA:h4mto8m#448844:4ms - 8ms:STACK");
	push(@tmp, "GPRINT:h4mto8m:LAST:    Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h4mto8m:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h4mto8m:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h4mto8m:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h4mto8m#448844:4ms - 8ms:STACK");
	push(@tmp, "AREA:h8mto16m#EE00EE:8ms - 16ms:STACK");
	push(@tmp, "GPRINT:h8mto16m:LAST:   Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h8mto16m:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h8mto16m:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h8mto16m:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h8mto16m#EE00EE:8ms - 16ms:STACK");
	push(@tmp, "AREA:h16mto32m#B4B444:16ms - 32ms:STACK");
	push(@tmp, "GPRINT:h16mto32m:LAST:  Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h16mto32m:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h16mto32m:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h16mto32m:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h16mto32m#B4B444:16ms - 32ms:STACK");
	push(@tmp, "AREA:h32mto64m#00EEEE:32ms - 64ms:STACK");
	push(@tmp, "GPRINT:h32mto64m:LAST:  Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h32mto64m:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h32mto64m:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h32mto64m:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h32mto64m#00EEEE:32ms - 64ms:STACK");
	push(@tmp, "AREA:h64mto128m#0000EE:64ms - 128ms:STACK");
	push(@tmp, "GPRINT:h64mto128m:LAST: Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h64mto128m:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h64mto128m:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h64mto128m:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h64mto128m#0000EE:64ms - 128ms:STACK");
	push(@tmp, "AREA:h128mto256m#EE0000:128ms - 256ms:STACK");
	push(@tmp, "GPRINT:h128mto256m:LAST:Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h128mto256m:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h128mto256m:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h128mto256m:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h128mto256m#EE0000:128ms - 256ms:STACK");
	push(@tmp, "AREA:h256mto512m#EEEE00:256ms - 512ms:STACK");
	push(@tmp, "GPRINT:h256mto512m:LAST:Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h256mto512m:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h256mto512m:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h256mto512m:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h256mto512m#EEEE00:256ms - 512ms:STACK");
	push(@tmp, "AREA:h512mto1s#8A2908:512ms - 1s:STACK");
	push(@tmp, "GPRINT:h512mto1s:LAST:   Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h512mto1s:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h512mto1s:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h512mto1s:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h512mto1s#8A2908:512ms - 1s:STACK");
	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG9",
		"--title=$config->{graphs}->{_unbound9}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:h0uto2m=$rrd:unbound_h0uto2m:AVERAGE",
		"DEF:h2mto4m=$rrd:unbound_h2mto4m:AVERAGE",
		"DEF:h4mto8m=$rrd:unbound_h4mto8m:AVERAGE",
		"DEF:h8mto16m=$rrd:unbound_h8mto16m:AVERAGE",
		"DEF:h16mto32m=$rrd:unbound_h16mto32m:AVERAGE",
		"DEF:h32mto64m=$rrd:unbound_h32mto64m:AVERAGE",
		"DEF:h64mto128m=$rrd:unbound_h64mto128m:AVERAGE",
		"DEF:h128mto256m=$rrd:unbound_h128mto256m:AVERAGE",
		"DEF:h256mto512m=$rrd:unbound_h256mto512m:AVERAGE",
		"DEF:h512mto1s=$rrd:unbound_h512mto1s:AVERAGE",
		"CDEF:allvalues=h0uto2m,h2mto4m,h4mto8m,h8mto16m,h16mto32m,h32mto64m,h64mto128m,h128mto256m,h256mto512m,h512mto1s,+,+,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG9: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG9z",
			"--title=$config->{graphs}->{_unbound9}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:h0uto2m=$rrd:unbound_h0uto2m:AVERAGE",
			"DEF:h2mto4m=$rrd:unbound_h2mto4m:AVERAGE",
			"DEF:h4mto8m=$rrd:unbound_h4mto8m:AVERAGE",
			"DEF:h8mto16m=$rrd:unbound_h8mto16m:AVERAGE",
			"DEF:h16mto32m=$rrd:unbound_h16mto32m:AVERAGE",
			"DEF:h32mto64m=$rrd:unbound_h32mto64m:AVERAGE",
			"DEF:h64mto128m=$rrd:unbound_h64mto128m:AVERAGE",
			"DEF:h128mto256m=$rrd:unbound_h128mto256m:AVERAGE",
			"DEF:h256mto512m=$rrd:unbound_h256mto512m:AVERAGE",
			"DEF:h512mto1s=$rrd:unbound_h512mto1s:AVERAGE",
			"CDEF:allvalues=h0uto2m,h2mto4m,h4mto8m,h8mto16m,h16mto32m,h32mto64m,h64mto128m,h128mto256m,h256mto512m,h512mto1s,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG9z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /unbound9/)) {
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
	}

	@riglim = @{setup_riglim($rigid[9], $limit[9])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:h1sto2s#FFA500:1s - 2s:STACK");
	push(@tmp, "GPRINT:h1sto2s:LAST:    Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h1sto2s:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h1sto2s:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h1sto2s:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h1sto2s#FFA500:1s - 2s:STACK");
	push(@tmp, "AREA:h2sto4s#00EE00:2s - 4s:STACK");
	push(@tmp, "GPRINT:h2sto4s:LAST:    Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h2sto4s:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h2sto4s:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h2sto4s:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h2sto4s#00EE00:2s - 4s:STACK");
	push(@tmp, "AREA:h4sto8s#448844:4s - 8s:STACK");
	push(@tmp, "GPRINT:h4sto8s:LAST:    Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h4sto8s:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h4sto8s:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h4sto8s:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h4sto8s#448844:4s - 8s:STACK");
	push(@tmp, "AREA:h8sto16s#EE00EE:8s - 16s:STACK");
	push(@tmp, "GPRINT:h8sto16s:LAST:   Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h8sto16s:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h8sto16s:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h8sto16s:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h8sto16s#EE00EE:8s - 16s:STACK");
	push(@tmp, "AREA:h16sto32s#B4B444:16s - 32s:STACK");
	push(@tmp, "GPRINT:h16sto32s:LAST:  Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h16sto32s:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h16sto32s:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h16sto32s:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h16sto32s#B4B444:16s - 32s:STACK");
	push(@tmp, "AREA:h32sto64s#00EEEE:32s - 64s:STACK");
	push(@tmp, "GPRINT:h32sto64s:LAST:  Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h32sto64s:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h32sto64s:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h32sto64s:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h32sto64s#00EEEE:32s - 64s:STACK");
	push(@tmp, "AREA:h64sto128s#0000EE:64s - 128s:STACK");
	push(@tmp, "GPRINT:h64sto128s:LAST: Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h64sto128s:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h64sto128s:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h64sto128s:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h64sto128s#0000EE:64s - 128s:STACK");
	push(@tmp, "AREA:h128sto256s#EE0000:128s - 256s:STACK");
	push(@tmp, "GPRINT:h128sto256s:LAST:Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h128sto256s:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h128sto256s:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h128sto256s:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h128sto256s#EE0000:128s - 256s:STACK");
	push(@tmp, "AREA:h256sto512s#EEEE00:256s - 512s:STACK");
	push(@tmp, "GPRINT:h256sto512s:LAST:Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h256sto512s:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h256sto512s:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h256sto512s:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h256sto512s#EEEE00:256s - 512s:STACK");
	push(@tmp, "AREA:h512stomore#8A2908:512s - more:STACK");
	push(@tmp, "GPRINT:h512stomore:LAST:Cur\\:%5.1lf");
	push(@tmp, "GPRINT:h512stomore:AVERAGE: Avg\\:%5.1lf");
	push(@tmp, "GPRINT:h512stomore:MIN: Min\\:%5.1lf");
	push(@tmp, "GPRINT:h512stomore:MAX: Max\\:%5.1lf\\n");
	push(@tmpz, "AREA:h512stomore#8A2908:512ms - more:STACK");
	if($title) {
		push(@output, "    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium});
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG10",
		"--title=$config->{graphs}->{_unbound10}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:h1sto2s=$rrd:unbound_h1sto2s:AVERAGE",
		"DEF:h2sto4s=$rrd:unbound_h2sto4s:AVERAGE",
		"DEF:h4sto8s=$rrd:unbound_h4sto8s:AVERAGE",
		"DEF:h8sto16s=$rrd:unbound_h8sto16s:AVERAGE",
		"DEF:h16sto32s=$rrd:unbound_h16sto32s:AVERAGE",
		"DEF:h32sto64s=$rrd:unbound_h32sto64s:AVERAGE",
		"DEF:h64sto128s=$rrd:unbound_h64sto128s:AVERAGE",
		"DEF:h128sto256s=$rrd:unbound_h128sto256s:AVERAGE",
		"DEF:h256sto512s=$rrd:unbound_h256sto512s:AVERAGE",
		"DEF:h512stomore=$rrd:unbound_h512stomore:AVERAGE",
		"CDEF:allvalues=h1sto2s,h2sto4s,h4sto8s,h8sto16s,h16sto32s,h32sto64s,h64sto128s,h128sto256s,h256sto512s,h512stomore,+,+,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG10 $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG10z",
			"--title=$config->{graphs}->{_unbound10}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:h1sto2s=$rrd:unbound_h1sto2s:AVERAGE",
			"DEF:h2sto4s=$rrd:unbound_h2sto4s:AVERAGE",
			"DEF:h4sto8s=$rrd:unbound_h4sto8s:AVERAGE",
			"DEF:h8sto16s=$rrd:unbound_h8sto16s:AVERAGE",
			"DEF:h16sto32s=$rrd:unbound_h16sto32s:AVERAGE",
			"DEF:h32sto64s=$rrd:unbound_h32sto64s:AVERAGE",
			"DEF:h64sto128s=$rrd:unbound_h64sto128s:AVERAGE",
			"DEF:h128sto256s=$rrd:unbound_h128sto256s:AVERAGE",
			"DEF:h256sto512s=$rrd:unbound_h256sto512s:AVERAGE",
			"DEF:h512stomore=$rrd:unbound_h512stomore:AVERAGE",
			"CDEF:allvalues=h1sto2s,h2sto4s,h4sto8s,h8sto16s,h16sto32s,h32sto64s,h64sto128s,h128sto256s,h256sto512s,h512stomore,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG10z $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /unbound10/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG10z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG10 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG10z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG10 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG10 . "'>\n");
		}
	}

	if($title) {
		push(@output, "    </td>\n");
		push(@output, "    </tr>\n");
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;;
}

1;
