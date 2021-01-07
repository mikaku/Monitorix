#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2021 by Jordi Sanfeliu <jordi@fibranet.cat>
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

package pagespeed;

use strict;
use warnings;
use Monitorix;
use RRDs;
use LWP::UserAgent;
use XML::Simple;
use Exporter 'import';
our @EXPORT = qw(pagespeed_init pagespeed_update pagespeed_cgi);

sub pagespeed_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $pagespeed = $config->{pagespeed};

	my $info;
	my @ds;
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
		if(scalar(@ds) / 59 != scalar(my @bl = split(',', $pagespeed->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @bl = split(',', $pagespeed->{list})) . ") and $rrd (" . scalar(@ds) / 59 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @bl = split(',', $pagespeed->{list})); $n++) {
			push(@tmp, "DS:pagespeed" . $n . "_catim:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_cahit:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_camis:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_cabhit:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_cabmis:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_cafal:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_caexp:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_cains:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_cadel:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_caext:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_notca:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_fihit:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_fiins:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_fimis:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_lrhit:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_lrins:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_lrmis:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_mcahit:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_mcains:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_mcamis:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_mcbhit:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_mcbins:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_mcbmis:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_pcbchit:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_pcbcins:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_pcbcmis:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_pcdhit:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_pcdins:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_pcdmis:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_rcohit:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_rcomis:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_shchit:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_shcins:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_shcmis:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_cftob:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_cftbs:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_irtob:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_irtbs:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_jstob:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_jstbs:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_ccos:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_cccs:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_urltri:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_rurlrj:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_rwcdea:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_rfetca:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_numflu:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_numrwx:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_numrwd:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_val01:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_val02:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_val03:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_val04:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_val05:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_val06:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_val07:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_val08:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_val09:GAUGE:120:0:U");
			push(@tmp, "DS:pagespeed" . $n . "_val10:GAUGE:120:0:U");
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

	$config->{pagespeed_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub pagespeed_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $pagespeed = $config->{pagespeed};

	my $str;
	my $rrdata = "N";

	my $n = 0;
	foreach(my @pl = split(',', $pagespeed->{list})) {
		my $url = trim($_);
		my $ssl = "";

		$ssl = "ssl_opts => {verify_hostname => 0}"
			if lc($config->{accept_selfsigned_certs}) eq "y";

		my $ua = LWP::UserAgent->new(timeout => 30, $ssl);
		$ua->agent($config->{user_agent_id}) if $config->{user_agent_id} || "";
		my $response = $ua->request(HTTP::Request->new('GET', $url));

		if(!$response->is_success) {
			logger("$myself: ERROR: Unable to connect to '$url'.");
			logger("$myself: " . $response->status_line);
		}

		my $catim = 0;
		my $cahit = 0;
		my $camis = 0;
		my $cabhit = 0;
		my $cabmis = 0;
		my $cafal = 0;
		my $caexp = 0;
		my $cains = 0;
		my $cadel = 0;
		my $caext = 0;
		my $notca = 0;
		my $fihit = 0;
		my $fiins = 0;
		my $fimis = 0;
		my $lrhit = 0;
		my $lrins = 0;
		my $lrmis = 0;
		my $mcahit = 0;
		my $mcains = 0;
		my $mcamis = 0;
		my $mcbhit = 0;
		my $mcbins = 0;
		my $mcbmis = 0;
		my $pcbchit = 0;
		my $pcbcins = 0;
		my $pcbcmis = 0;
		my $pcdhit = 0;
		my $pcdins = 0;
		my $pcdmis = 0;
		my $rcohit = 0;
		my $rcomis = 0;
		my $shchit = 0;
		my $shcins = 0;
		my $shcmis = 0;
		my $cftob = 0;
		my $cftbs = 0;
		my $irtob = 0;
		my $irtbs = 0;
		my $jstob = 0;
		my $jstbs = 0;
		my $ccos = 0;
		my $cccs = 0;
		my $urltri = 0;
		my $rurlrj = 0;
		my $rwcdea = 0;
		my $rfetca = 0;
		my $numflu = 0;
		my $numrwx = 0;
		my $numrwd = 0;

		foreach(split('\n', $response->content)) {
			if(/^cache_time_us:\s+(\d+)$/) {
				$str = $n . "catim";
				$catim = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$catim = 0 unless $catim != $1;
				$catim /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^cache_hits:\s+(\d+)$/) {
				$str = $n . "cahit";
				$cahit = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$cahit = 0 unless $cahit != $1;
				$cahit /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^cache_misses:\s+(\d+)$/) {
				$str = $n . "camis";
				$camis = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$camis = 0 unless $camis != $1;
				$camis /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^cache_backend_hits:\s+(\d+)$/) {
				$str = $n . "cabhit";
				$cabhit = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$cabhit = 0 unless $cabhit != $1;
				$cabhit /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^cache_backend_misses:\s+(\d+)$/) {
				$str = $n . "cabmis";
				$cabmis = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$cabmis = 0 unless $cabmis != $1;
				$cabmis /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^cache_fallbacks:\s+(\d+)$/) {
				$str = $n . "cafal";
				$cafal = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$cafal = 0 unless $cafal != $1;
				$cafal /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^cache_expirations:\s+(\d+)$/) {
				$str = $n . "caexp";
				$caexp = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$caexp = 0 unless $caexp != $1;
				$caexp /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^cache_inserts:\s+(\d+)$/) {
				$str = $n . "cains";
				$cains = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$cains = 0 unless $cains != $1;
				$cains /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^cache_deletes:\s+(\d+)$/) {
				$str = $n . "cadel";
				$cadel = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$cadel = 0 unless $cadel != $1;
				$cadel /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^cache_extensions:\s+(\d+)$/) {
				$str = $n . "caext";
				$caext = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$caext = 0 unless $caext != $1;
				$caext /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^not_cacheable:\s+(\d+)$/) {
				$str = $n . "notca";
				$notca = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$notca = 0 unless $notca != $1;
				$notca /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^file_cache_hits:\s+(\d+)$/) {
				$str = $n . "fihit";
				$fihit = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$fihit = 0 unless $fihit != $1;
				$fihit /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^file_cache_inserts:\s+(\d+)$/) {
				$str = $n . "fiins";
				$fiins = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$fiins = 0 unless $fiins != $1;
				$fiins /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^file_cache_misses:\s+(\d+)$/) {
				$str = $n . "fimis";
				$fimis = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$fimis = 0 unless $fimis != $1;
				$fimis /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^lru_cache_hits:\s+(\d+)$/) {
				$str = $n . "lrhit";
				$lrhit = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$lrhit = 0 unless $lrhit != $1;
				$lrhit /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^lru_cache_inserts:\s+(\d+)$/) {
				$str = $n . "lrins";
				$lrins = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$lrins = 0 unless $lrins != $1;
				$lrins /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^lru_cache_misses:\s+(\d+)$/) {
				$str = $n . "lrmis";
				$lrmis = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$lrmis = 0 unless $lrmis != $1;
				$lrmis /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^memcached_async_hits:\s+(\d+)$/) {
				$str = $n . "mcahit";
				$mcahit = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$mcahit = 0 unless $mcahit != $1;
				$mcahit /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^memcached_async_inserts:\s+(\d+)$/) {
				$str = $n . "mcains";
				$mcains = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$mcains = 0 unless $mcains != $1;
				$mcains /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^memcached_async_misses:\s+(\d+)$/) {
				$str = $n . "mcamis";
				$mcamis = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$mcamis = 0 unless $mcamis != $1;
				$mcamis /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^memcached_blocking_hits:\s+(\d+)$/) {
				$str = $n . "mcbhit";
				$mcbhit = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$mcbhit = 0 unless $mcbhit != $1;
				$mcbhit /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^memcached_blocking_inserts:\s+(\d+)$/) {
				$str = $n . "mcbins";
				$mcbins = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$mcbins = 0 unless $mcbins != $1;
				$mcbins /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^memcached_blocking_misses:\s+(\d+)$/) {
				$str = $n . "mcbmis";
				$mcbmis = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$mcbmis = 0 unless $mcbmis != $1;
				$mcbmis /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^pcache-cohorts-beacon_cohort_hits:\s+(\d+)$/) {
				$str = $n . "pcbchit";
				$pcbchit = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$pcbchit = 0 unless $pcbchit != $1;
				$pcbchit /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^pcache-cohorts-beacon_cohort_inserts:\s+(\d+)$/) {
				$str = $n . "pcbcins";
				$pcbcins = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$pcbcins = 0 unless $pcbcins != $1;
				$pcbcins /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^pcache-cohorts-beacon_cohort_misses:\s+(\d+)$/) {
				$str = $n . "pcbcmis";
				$pcbcmis = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$pcbcmis = 0 unless $pcbcmis != $1;
				$pcbcmis /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^pcache-cohorts-dom_hits:\s+(\d+)$/) {
				$str = $n . "pcdhit";
				$pcdhit = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$pcdhit = 0 unless $pcdhit != $1;
				$pcdhit /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^pcache-cohorts-dom_inserts:\s+(\d+)$/) {
				$str = $n . "pcdins";
				$pcdins = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$pcdins = 0 unless $pcdins != $1;
				$pcdins /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^pcache-cohorts-dom_misses:\s+(\d+)$/) {
				$str = $n . "pcdmis";
				$pcdmis = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$pcdmis = 0 unless $pcdmis != $1;
				$pcdmis /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^rewrite_cached_output_hits:\s+(\d+)$/) {
				$str = $n . "rcohit";
				$rcohit = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$rcohit = 0 unless $rcohit != $1;
				$rcohit /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^rewrite_cached_output_misses:\s+(\d+)$/) {
				$str = $n . "rcomis";
				$rcomis = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$rcomis = 0 unless $rcomis != $1;
				$rcomis /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^shm_cache_hits:\s+(\d+)$/) {
				$str = $n . "shchit";
				$shchit = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$shchit = 0 unless $shchit != $1;
				$shchit /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^shm_cache_inserts:\s+(\d+)$/) {
				$str = $n . "shcins";
				$shcins = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$shcins = 0 unless $shcins != $1;
				$shcins /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^shm_cache_misses:\s+(\d+)$/) {
				$str = $n . "shcmis";
				$shcmis = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$shcmis = 0 unless $shcmis != $1;
				$shcmis /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^css_filter_total_original_bytes:\s+(\d+)$/) {
				$cftob = $1;
				chomp($cftob);
				next;
			}
			if(/^css_filter_total_bytes_saved:\s+(\d+)$/) {
				$cftbs = $1;
				chomp($cftbs);
				next;
			}
			if(/^image_rewrite_total_original_bytes:\s+(\d+)$/) {
				$irtob = $1;
				chomp($irtob);
				next;
			}
			if(/^image_rewrite_total_bytes_saved:\s+(\d+)$/) {
				$irtbs = $1;
				chomp($irtbs);
				next;
			}
			if(/^javascript_total_original_bytes:\s+(\d+)$/) {
				$jstob = $1;
				chomp($jstob);
				next;
			}
			if(/^javascript_total_bytes_saved:\s+(\d+)$/) {
				$jstbs = $1;
				chomp($jstbs);
				next;
			}
			if(/^compressed_cache_original_size:\s+(\d+)$/) {
				$ccos = $1;
				chomp($ccos);
				next;
			}
			if(/^compressed_cache_compressed_size:\s+(\d+)$/) {
				$cccs = $1;
				chomp($cccs);
				next;
			}
			if(/^url_trims:\s+(\d+)$/) {
				$str = $n . "urltri";
				$urltri = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$urltri = 0 unless $urltri != $1;
				$urltri /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^resource_url_domain_rejections:\s+(\d+)$/) {
				$str = $n . "rurlrj";
				$rurlrj = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$shcmis = 0 unless $rurlrj != $1;
				$rurlrj /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^rewrite_cached_output_missed_deadline:\s+(\d+)$/) {
				$str = $n . "rwcdea";
				$rwcdea = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$rwcdea = 0 unless $rwcdea != $1;
				$rwcdea /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^resource_fetches_cached:\s+(\d+)$/) {
				$str = $n . "rfetca";
				$rfetca = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$rfetca = 0 unless $rfetca != $1;
				$rfetca /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^num_flushes:\s+(\d+)$/) {
				$str = $n . "numflu";
				$numflu = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$numflu = 0 unless $numflu != $1;
				$numflu /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^num_rewrites_executed:\s+(\d+)$/) {
				$str = $n . "numrwx";
				$numrwx = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$numrwx = 0 unless $numrwx != $1;
				$numrwx /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
			if(/^num_rewrites_dropped:\s+(\d+)$/) {
				$str = $n . "numrwd";
				$numrwd = $1 - ($config->{pagespeed_hist}->{$str} || 0);
				$numrwd = 0 unless $numrwd != $1;
				$numrwd /= 60;
				$config->{pagespeed_hist}->{$str} = $1;
				next;
			}
		}
		$rrdata .= ":$catim:$cahit:$camis:$cabhit:$cabmis:$cafal:$caexp:$cains:$cadel:$caext:$notca:$fihit:$fiins:$fimis:$lrhit:$lrins:$lrmis:$mcahit:$mcains:$mcamis:$mcbhit:$mcbins:$mcbmis:$pcbchit:$pcbcins:$pcbcmis:$pcdhit:$pcdins:$pcdmis:$rcohit:$rcomis:$shchit:$shcins:$shcmis:$cftob:$cftbs:$irtob:$irtbs:$jstob:$jstbs:$ccos:$cccs:$urltri:$rurlrj:$rwcdea:$rfetca:$numflu:$numrwx:$numrwd:0:0:0:0:0:0:0:0:0:0";
		$n++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub pagespeed_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $pagespeed = $config->{pagespeed};
	my @rigid = split(',', ($pagespeed->{rigid} || ""));
	my @limit = split(',', ($pagespeed->{limit} || ""));
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
	my $e;
	my $e2;
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
		my $line0;
		my $line1;
		my $line2;
		my $line3;
		my $n2;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		$line0 = "                                                          Cache Overview           File cache             LRU cache       Memcached async    Memcached blocking Pcache cohorts beacon    Pcache cohorts dom Rewrite cached             SHM cache         CSS filter total      Image rewrite total         Javascript total       Compressed cache";
		for($n = 0; $n < scalar(my @pl = split(',', $pagespeed->{list})); $n++) {
			my $l = trim($pl[$n]);
			$line1 .= $line0;
			$line3 .= "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
			$line2 .= "    Hits Misses  B.Hits Misses Fallba Expira Insert Delete Extens Notcac   Hits Insert Misses    Hits Insert Misses    Hits Insert Misses    Hits Insert Misses    Hits Insert Misses    Hits Insert Misses    Hits Misses    Hits Insert Misses    Orig_bytes Save_Bytes    Orig_bytes Save_bytes    Orig_bytes Save_bytes    Orig_size Comp_size";

			my $i = length($line0);
			push(@output, sprintf(sprintf("%${i}s", sprintf("Pagespeed: %s", $l))));
		}
		push(@output, "\n");
		push(@output, "    $line1\n");
		push(@output, "Time$line2 \n");
		push(@output, "----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			$from = 1;
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			for($n2 = 0; $n2 < scalar(my @pl = split(',', $pagespeed->{list})); $n2++) {
				$from += $n2 * 59;
				$to = $from + 59;
				@row = @$line[$from..$to];
				push(@output, sprintf(" %6d %6d  %6d %6d %6d %6d %6d %6d %6d %6d %6d %6d %6d  %6d %6d %6d  %6d %6d %6d  %6d %6d %6d  %6d %6d %6d  %6d %6d %6d  %6d %6d  %6d %6d %6d    %10d %10d    %10d %10d    %10d %10d    %9d %9d", @row));
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

	for($n = 0; $n < scalar(my @pl = split(',', $pagespeed->{list})); $n++) {
		for($n2 = 1; $n2 <= 8; $n2++) {
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
	foreach (my @pl = split(',', $pagespeed->{list})) {
		my $l = trim($_);
		if($e) {
			push(@output, "   <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}
		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:cahit#5F04B4:Hits");
		push(@tmp, "GPRINT:cahit" . ":LAST:             Current\\:%6.2lf");
		push(@tmp, "GPRINT:cahit" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:cahit" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:cahit" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:camis#EE44EE:Misses");
		push(@tmp, "GPRINT:camis" . ":LAST:           Current\\:%6.2lf");
		push(@tmp, "GPRINT:camis" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:camis" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:camis" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:cabhit#4444EE:Backend hits");
		push(@tmp, "GPRINT:cabhit" . ":LAST:     Current\\:%6.2lf");
		push(@tmp, "GPRINT:cabhit" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:cabhit" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:cabhit" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:cabmis#44EEEE:Backend misses");
		push(@tmp, "GPRINT:cabmis" . ":LAST:   Current\\:%6.2lf");
		push(@tmp, "GPRINT:cabmis" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:cabmis" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:cabmis" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:cafal#EEEE44:Fallbacks");
		push(@tmp, "GPRINT:cafal" . ":LAST:        Current\\:%6.2lf");
		push(@tmp, "GPRINT:cafal" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:cafal" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:cafal" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:caexp#FFA500:Expirations");
		push(@tmp, "GPRINT:caexp" . ":LAST:      Current\\:%6.2lf");
		push(@tmp, "GPRINT:caexp" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:caexp" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:caexp" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:cains#44EE44:Inserts");
		push(@tmp, "GPRINT:cains" . ":LAST:          Current\\:%6.2lf");
		push(@tmp, "GPRINT:cains" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:cains" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:cains" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:cadel#EE4444:Deletes");
		push(@tmp, "GPRINT:cadel" . ":LAST:          Current\\:%6.2lf");
		push(@tmp, "GPRINT:cadel" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:cadel" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:cadel" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:caext#448844:Extensions");
		push(@tmp, "GPRINT:caext" . ":LAST:       Current\\:%6.2lf");
		push(@tmp, "GPRINT:caext" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:caext" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:caext" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:notca#888888:Not cacheable");
		push(@tmp, "GPRINT:notca" . ":LAST:    Current\\:%6.2lf");
		push(@tmp, "GPRINT:notca" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:notca" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:notca" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmpz, "LINE2:cahit#5F04B4:Hits");
		push(@tmpz, "LINE2:camis#EE44EE:Misses");
		push(@tmpz, "LINE2:cabhit#4444EE:Backend hits");
		push(@tmpz, "LINE2:cabmis#44EEEE:Backend misses");
		push(@tmpz, "LINE2:cafal#EEEE44:Fallbacks");
		push(@tmpz, "LINE2:caexp#FFA500:Expirations");
		push(@tmpz, "LINE2:cains#44EE44:Inserts");
		push(@tmpz, "LINE2:cadel#EE4444:Deletes");
		push(@tmpz, "LINE2:caext#448844:Extensions");
		push(@tmpz, "LINE2:notca#888888:Not cacheable");
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
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 8]",
			"--title=$config->{graphs}->{_pagespeed1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Values/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:cahit=$rrd:pagespeed" . $e . "_cahit:AVERAGE",
			"DEF:camis=$rrd:pagespeed" . $e . "_camis:AVERAGE",
			"DEF:cabhit=$rrd:pagespeed" . $e . "_cabhit:AVERAGE",
			"DEF:cabmis=$rrd:pagespeed" . $e . "_cabmis:AVERAGE",
			"DEF:cafal=$rrd:pagespeed" . $e . "_cafal:AVERAGE",
			"DEF:caexp=$rrd:pagespeed" . $e . "_caexp:AVERAGE",
			"DEF:cains=$rrd:pagespeed" . $e . "_cains:AVERAGE",
			"DEF:cadel=$rrd:pagespeed" . $e . "_cadel:AVERAGE",
			"DEF:caext=$rrd:pagespeed" . $e . "_caext:AVERAGE",
			"DEF:notca=$rrd:pagespeed" . $e . "_notca:AVERAGE",
			"CDEF:allvalues=cahit,camis,cabhit,cabmis,cafal,caexp,cains,cadel,caext,notca,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 8]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 8]",
				"--title=$config->{graphs}->{_pagespeed1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Values/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:cahit=$rrd:pagespeed" . $e . "_cahit:AVERAGE",
				"DEF:camis=$rrd:pagespeed" . $e . "_camis:AVERAGE",
				"DEF:cabhit=$rrd:pagespeed" . $e . "_cabhit:AVERAGE",
				"DEF:cabmis=$rrd:pagespeed" . $e . "_cabmis:AVERAGE",
				"DEF:cafal=$rrd:pagespeed" . $e . "_cafal:AVERAGE",
				"DEF:caexp=$rrd:pagespeed" . $e . "_caexp:AVERAGE",
				"DEF:cains=$rrd:pagespeed" . $e . "_cains:AVERAGE",
				"DEF:cadel=$rrd:pagespeed" . $e . "_cadel:AVERAGE",
				"DEF:caext=$rrd:pagespeed" . $e . "_caext:AVERAGE",
				"DEF:notca=$rrd:pagespeed" . $e . "_notca:AVERAGE",
				"CDEF:allvalues=cahit,camis,cabhit,cabmis,cafal,caexp,cains,cadel,caext,notca,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 8]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pagespeed$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:urltri#5F04B4:URL trims");
		push(@tmp, "GPRINT:urltri" . ":LAST:        Current\\:%6.2lf");
		push(@tmp, "GPRINT:urltri" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:urltri" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:urltri" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:rurlrj#EE44EE:Res.URL dom.rej.");
		push(@tmp, "GPRINT:rurlrj" . ":LAST: Current\\:%6.2lf");
		push(@tmp, "GPRINT:rurlrj" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:rurlrj" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:rurlrj" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:rwcdea#4444EE:Rew.mis.deadline");
		push(@tmp, "GPRINT:rwcdea" . ":LAST: Current\\:%6.2lf");
		push(@tmp, "GPRINT:rwcdea" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:rwcdea" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:rwcdea" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:rfetca#44EEEE:Res.fetch.cached");
		push(@tmp, "GPRINT:rfetca" . ":LAST: Current\\:%6.2lf");
		push(@tmp, "GPRINT:rfetca" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:rfetca" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:rfetca" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:numflu#EEEE44:Num. of flushes");
		push(@tmp, "GPRINT:numflu" . ":LAST:  Current\\:%6.2lf");
		push(@tmp, "GPRINT:numflu" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:numflu" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:numflu" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:numrwx#FFA500:Num.rew. executed");
		push(@tmp, "GPRINT:numrwx" . ":LAST:Current\\:%6.2lf");
		push(@tmp, "GPRINT:numrwx" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:numrwx" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:numrwx" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmp, "LINE2:numrwd#EE4444:Num.rew. dropped");
		push(@tmp, "GPRINT:numrwd" . ":LAST: Current\\:%6.2lf");
		push(@tmp, "GPRINT:numrwd" . ":AVERAGE:   Average\\:%6.2lf");
		push(@tmp, "GPRINT:numrwd" . ":MIN:   Min\\:%6.2lf");
		push(@tmp, "GPRINT:numrwd" . ":MAX:   Max\\:%6.2lf\\n");
		push(@tmpz, "LINE2:urltri#5F04B4:URL trims");
		push(@tmpz, "LINE2:rurlrj#EE44EE:Resource URL dom. rejections");
		push(@tmpz, "LINE2:rwcdea#4444EE:Rewrite cached mis. deadline");
		push(@tmpz, "LINE2:rfetca#44EEEE:Resource fetches cached");
		push(@tmpz, "LINE2:numflu#EEEE44:Number of flushes");
		push(@tmpz, "LINE2:numrwx#FFA500:Number of rewrites executed");
		push(@tmpz, "LINE2:numrwd#EE4444:Number of rewrites dropped");
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
		}
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 8 + 1]",
			"--title=$config->{graphs}->{_pagespeed2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Values/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:urltri=$rrd:pagespeed" . $e . "_urltri:AVERAGE",
			"DEF:rurlrj=$rrd:pagespeed" . $e . "_rurlrj:AVERAGE",
			"DEF:rwcdea=$rrd:pagespeed" . $e . "_rwcdea:AVERAGE",
			"DEF:rfetca=$rrd:pagespeed" . $e . "_rfetca:AVERAGE",
			"DEF:numflu=$rrd:pagespeed" . $e . "_numflu:AVERAGE",
			"DEF:numrwx=$rrd:pagespeed" . $e . "_numrwx:AVERAGE",
			"DEF:numrwd=$rrd:pagespeed" . $e . "_numrwd:AVERAGE",
			"CDEF:allvalues=urltri,rurlrj,rwcdea,rfetca,numflu,numrwx,numrwd,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 8 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 8 + 1]",
				"--title=$config->{graphs}->{_pagespeed2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Values/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:urltri=$rrd:pagespeed" . $e . "_urltri:AVERAGE",
				"DEF:rurlrj=$rrd:pagespeed" . $e . "_rurlrj:AVERAGE",
				"DEF:rwcdea=$rrd:pagespeed" . $e . "_rwcdea:AVERAGE",
				"DEF:rfetca=$rrd:pagespeed" . $e . "_rfetca:AVERAGE",
				"DEF:numflu=$rrd:pagespeed" . $e . "_numflu:AVERAGE",
				"DEF:numrwx=$rrd:pagespeed" . $e . "_numrwx:AVERAGE",
				"DEF:numrwd=$rrd:pagespeed" . $e . "_numrwd:AVERAGE",
				"CDEF:allvalues=urltri,rurlrj,rwcdea,rfetca,numflu,numrwx,numrwd,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 8 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pagespeed$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 1] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:cf#FFA500:CSS filter");
		push(@tmp, "GPRINT:cf" . ":LAST:       Current\\:%4.1lf%%");
		push(@tmp, "GPRINT:cf" . ":AVERAGE:   Average\\:%4.1lf%%");
		push(@tmp, "GPRINT:cf" . ":MIN:   Min\\:%4.1lf%%");
		push(@tmp, "GPRINT:cf" . ":MAX:   Max\\:%4.1lf%%\\n");
		push(@tmp, "LINE2:ir#44EEEE:Image rewrite");
		push(@tmp, "GPRINT:ir" . ":LAST:    Current\\:%4.1lf%%");
		push(@tmp, "GPRINT:ir" . ":AVERAGE:   Average\\:%4.1lf%%");
		push(@tmp, "GPRINT:ir" . ":MIN:   Min\\:%4.1lf%%");
		push(@tmp, "GPRINT:ir" . ":MAX:   Max\\:%4.1lf%%\\n");
		push(@tmp, "LINE2:js#44EE44:Javascript");
		push(@tmp, "GPRINT:js" . ":LAST:       Current\\:%4.1lf%%");
		push(@tmp, "GPRINT:js" . ":AVERAGE:   Average\\:%4.1lf%%");
		push(@tmp, "GPRINT:js" . ":MIN:   Min\\:%4.1lf%%");
		push(@tmp, "GPRINT:js" . ":MAX:   Max\\:%4.1lf%%\\n");
		push(@tmp, "LINE2:cc#4444EE:Compressed cache");
		push(@tmp, "GPRINT:cc" . ":LAST: Current\\:%4.1lf%%");
		push(@tmp, "GPRINT:cc" . ":AVERAGE:   Average\\:%4.1lf%%");
		push(@tmp, "GPRINT:cc" . ":MIN:   Min\\:%4.1lf%%");
		push(@tmp, "GPRINT:cc" . ":MAX:   Max\\:%4.1lf%%\\n");
		push(@tmpz, "LINE2:cf#FFA500:CSS filter");
		push(@tmpz, "LINE2:ir#44EEEE:Image rewrite");
		push(@tmpz, "LINE2:js#44EE44:Javascript");
		push(@tmpz, "LINE2:cc#4444EE:Compressed cache");
		push(@CDEF, "CDEF:cf=cftbs,100,*,cftob,/");
		push(@CDEF, "CDEF:ir=irtbs,100,*,irtob,/");
		push(@CDEF, "CDEF:js=jstbs,100,*,jstob,/");
		push(@CDEF, "CDEF:cc=cccs,100,*,ccos,/");
		push(@tmp, "COMMENT: \\n");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{main});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 8 + 2]",
			"--title=$config->{graphs}->{_pagespeed3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:cftob=$rrd:pagespeed" . $e . "_cftob:AVERAGE",
			"DEF:cftbs=$rrd:pagespeed" . $e . "_cftbs:AVERAGE",
			"DEF:irtob=$rrd:pagespeed" . $e . "_irtob:AVERAGE",
			"DEF:irtbs=$rrd:pagespeed" . $e . "_irtbs:AVERAGE",
			"DEF:jstob=$rrd:pagespeed" . $e . "_jstob:AVERAGE",
			"DEF:jstbs=$rrd:pagespeed" . $e . "_jstbs:AVERAGE",
			"DEF:ccos=$rrd:pagespeed" . $e . "_ccos:AVERAGE",
			"DEF:cccs=$rrd:pagespeed" . $e . "_cccs:AVERAGE",
			"CDEF:allvalues=cftob,cftbs,irtob,irtbs,jstob,jstbs,ccos,cccs,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 8 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 8 + 2]",
				"--title=$config->{graphs}->{_pagespeed3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Percent (%)",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:cftob=$rrd:pagespeed" . $e . "_cftob:AVERAGE",
				"DEF:cftbs=$rrd:pagespeed" . $e . "_cftbs:AVERAGE",
				"DEF:irtob=$rrd:pagespeed" . $e . "_irtob:AVERAGE",
				"DEF:irtbs=$rrd:pagespeed" . $e . "_irtbs:AVERAGE",
				"DEF:jstob=$rrd:pagespeed" . $e . "_jstob:AVERAGE",
				"DEF:jstbs=$rrd:pagespeed" . $e . "_jstbs:AVERAGE",
				"DEF:ccos=$rrd:pagespeed" . $e . "_ccos:AVERAGE",
				"DEF:cccs=$rrd:pagespeed" . $e . "_cccs:AVERAGE",
				"CDEF:allvalues=cftob,cftbs,irtob,irtbs,jstob,jstbs,ccos,cccs,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 8 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pagespeed$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 2] . "'>\n");
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
		push(@tmp, "LINE2:mcahit#44EEEE:Async hits");
		push(@tmp, "GPRINT:mcahit" . ":LAST:           Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:mcains#EEEE44:Async inserts");
		push(@tmp, "GPRINT:mcains" . ":LAST:        Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:mcamis#EE44EE:Async misses");
		push(@tmp, "GPRINT:mcamis" . ":LAST:         Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:mcbhit#009999:Blocking hits");
		push(@tmp, "GPRINT:mcbhit" . ":LAST:        Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:mcbins#FFA500:Blocking inserts");
		push(@tmp, "GPRINT:mcbins" . ":LAST:     Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:mcbmis#5F04B4:Blocking misses");
		push(@tmp, "GPRINT:mcbmis" . ":LAST:      Current\\:%5.1lf\\n");
		push(@tmpz, "LINE2:mcahit#44EEEE:Async hits");
		push(@tmpz, "LINE2:mcains#EEEE44:Async inserts");
		push(@tmpz, "LINE2:mcamis#EE44EE:Async misses");
		push(@tmpz, "LINE2:mcbhit#009999:Blocking hits");
		push(@tmpz, "LINE2:mcbins#FFA500:Blocking inserts");
		push(@tmpz, "LINE2:mcbmis#5F04B4:Blocking misses");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 8 + 3]",
			"--title=$config->{graphs}->{_pagespeed4}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:mcahit=$rrd:pagespeed" . $e . "_mcahit:AVERAGE",
			"DEF:mcains=$rrd:pagespeed" . $e . "_mcains:AVERAGE",
			"DEF:mcamis=$rrd:pagespeed" . $e . "_mcamis:AVERAGE",
			"DEF:mcbhit=$rrd:pagespeed" . $e . "_mcbhit:AVERAGE",
			"DEF:mcbins=$rrd:pagespeed" . $e . "_mcbins:AVERAGE",
			"DEF:mcbmis=$rrd:pagespeed" . $e . "_mcbmis:AVERAGE",
			"CDEF:allvalues=mcbhit,mcbins,mcbmis,mcahit,mcains,mcamis,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 8 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 8 + 3]",
				"--title=$config->{graphs}->{_pagespeed4}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:mcahit=$rrd:pagespeed" . $e . "_mcahit:AVERAGE",
				"DEF:mcains=$rrd:pagespeed" . $e . "_mcains:AVERAGE",
				"DEF:mcamis=$rrd:pagespeed" . $e . "_mcamis:AVERAGE",
				"DEF:mcbhit=$rrd:pagespeed" . $e . "_mcbhit:AVERAGE",
				"DEF:mcbins=$rrd:pagespeed" . $e . "_mcbins:AVERAGE",
				"DEF:mcbmis=$rrd:pagespeed" . $e . "_mcbmis:AVERAGE",
				"CDEF:allvalues=mcbhit,mcbins,mcbmis,mcahit,mcains,mcamis,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 8 + 3]: $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pagespeed$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 3] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[4], $limit[4])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:pcbchit#44EEEE:Beacon hits");
		push(@tmp, "GPRINT:pcbchit" . ":LAST:          Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:pcbcins#EEEE44:beacon inserts");
		push(@tmp, "GPRINT:pcbcins" . ":LAST:       Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:pcbcmis#EE44EE:beacon misses");
		push(@tmp, "GPRINT:pcbcmis" . ":LAST:        Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:pcdhit#009999:Dom hits");
		push(@tmp, "GPRINT:pcdhit" . ":LAST:             Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:pcdins#FFA500:Dom inserts");
		push(@tmp, "GPRINT:pcdins" . ":LAST:          Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:pcdmis#5F04B4:Dom misses");
		push(@tmp, "GPRINT:pcdmis" . ":LAST:           Current\\:%5.1lf\\n");
		push(@tmpz, "LINE2:pcdhit#44EEEE:Beacon hits");
		push(@tmpz, "LINE2:pcdins#EEEE44:Beacon inserts");
		push(@tmpz, "LINE2:pcdmis#EE44EE:Beacon misses");
		push(@tmpz, "LINE2:pcbchit#009999:Dom hits");
		push(@tmpz, "LINE2:pcbcins#FFA500:Dom inserts");
		push(@tmpz, "LINE2:pcbcmis#5F04B4:Dom misses");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 8 + 4]",
			"--title=$config->{graphs}->{_pagespeed5}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:pcbchit=$rrd:pagespeed" . $e . "_pcbchit:AVERAGE",
			"DEF:pcbcins=$rrd:pagespeed" . $e . "_pcbcins:AVERAGE",
			"DEF:pcbcmis=$rrd:pagespeed" . $e . "_pcbcmis:AVERAGE",
			"DEF:pcdhit=$rrd:pagespeed" . $e . "_pcdhit:AVERAGE",
			"DEF:pcdins=$rrd:pagespeed" . $e . "_pcdins:AVERAGE",
			"DEF:pcdmis=$rrd:pagespeed" . $e . "_pcdmis:AVERAGE",
			"CDEF:allvalues=pcbchit,pcbcins,pcbcmis,pcdhit,pcdins,pcdmis,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 8 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 8 + 4]",
				"--title=$config->{graphs}->{_pagespeed5}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:pcbchit=$rrd:pagespeed" . $e . "_pcbchit:AVERAGE",
				"DEF:pcbcins=$rrd:pagespeed" . $e . "_pcbcins:AVERAGE",
				"DEF:pcbcmis=$rrd:pagespeed" . $e . "_pcbcmis:AVERAGE",
				"DEF:pcdhit=$rrd:pagespeed" . $e . "_pcdhit:AVERAGE",
				"DEF:pcdins=$rrd:pagespeed" . $e . "_pcdins:AVERAGE",
				"DEF:pcdmis=$rrd:pagespeed" . $e . "_pcdmis:AVERAGE",
				"CDEF:allvalues=pcbchit,pcbcins,pcbcmis,pcdhit,pcdins,pcdmis,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 8 + 4]: $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pagespeed$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 4] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 4] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 4] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 4] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 4] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[5], $limit[5])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:rcohit#44EEEE:Rewrite c.o. hits");
		push(@tmp, "GPRINT:rcohit" . ":LAST:    Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:rcomis#EE44EE:Rewrite c.o. misses");
		push(@tmp, "GPRINT:rcomis" . ":LAST:  Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:shchit#009999:SHM cache hits");
		push(@tmp, "GPRINT:shchit" . ":LAST:       Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:shcins#FFA500:SHM cache inserts");
		push(@tmp, "GPRINT:shcins" . ":LAST:    Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:shcmis#5F04B4:SHM cache misses");
		push(@tmp, "GPRINT:shcmis" . ":LAST:     Current\\:%5.1lf\\n");
		push(@tmpz, "LINE2:rcohit#44EEEE:Rewrite c.o. hits");
		push(@tmpz, "LINE2:rcomis#EE44EE:Rewrite c.o. misses");
		push(@tmpz, "LINE2:shchit#009999:SHM cache hits");
		push(@tmpz, "LINE2:shcins#FFA500:SHM cache inserts");
		push(@tmpz, "LINE2:shcmis#5F04B4:SHM cache misses");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 8 + 5]",
			"--title=$config->{graphs}->{_pagespeed6}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:rcohit=$rrd:pagespeed" . $e . "_rcohit:AVERAGE",
			"DEF:rcomis=$rrd:pagespeed" . $e . "_rcomis:AVERAGE",
			"DEF:shchit=$rrd:pagespeed" . $e . "_shchit:AVERAGE",
			"DEF:shcins=$rrd:pagespeed" . $e . "_shcins:AVERAGE",
			"DEF:shcmis=$rrd:pagespeed" . $e . "_shcmis:AVERAGE",
			"CDEF:allvalues=rcohit,rcomis,shchit,shcins,shcmis,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 8 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 8 + 5]",
				"--title=$config->{graphs}->{_pagespeed6}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:rcohit=$rrd:pagespeed" . $e . "_rcohit:AVERAGE",
				"DEF:rcomis=$rrd:pagespeed" . $e . "_rcomis:AVERAGE",
				"DEF:shchit=$rrd:pagespeed" . $e . "_shchit:AVERAGE",
				"DEF:shcins=$rrd:pagespeed" . $e . "_shcins:AVERAGE",
				"DEF:shcmis=$rrd:pagespeed" . $e . "_shcmis:AVERAGE",
				"CDEF:allvalues=rcohit,rcomis,shchit,shcins,shcmis,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 8 + 5]: $err\n") if $err;
		}
		$e2 = $e + 6;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pagespeed$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 5] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 5] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 5] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 5] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 5] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[6], $limit[6])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:fihit#44EEEE:LRU cache hits");
		push(@tmp, "GPRINT:fihit" . ":LAST:       Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:fiins#EEEE44:LRU cache inserts");
		push(@tmp, "GPRINT:fiins" . ":LAST:    Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:fimis#EE44EE:LRU cache misses");
		push(@tmp, "GPRINT:fimis" . ":LAST:     Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:lrhit#009999:File cache hits");
		push(@tmp, "GPRINT:lrhit" . ":LAST:      Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:lrins#FFA500:File cache inserts");
		push(@tmp, "GPRINT:lrins" . ":LAST:   Current\\:%5.1lf\\n");
		push(@tmp, "LINE2:lrmis#5F04B4:File cache misses");
		push(@tmp, "GPRINT:lrmis" . ":LAST:    Current\\:%5.1lf\\n");
		push(@tmpz, "LINE2:fihit#44EEEE:LRU cache hits");
		push(@tmpz, "LINE2:fiins#EEEE44:LRU cache inserts");
		push(@tmpz, "LINE2:fimis#EE44EE:LRU cache misses");
		push(@tmpz, "LINE2:lrhit#009999:File cache hits");
		push(@tmpz, "LINE2:lrins#FFA500:File cache inserts");
		push(@tmpz, "LINE2:lrmis#5F04B4:File cache misses");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 8 + 6]",
			"--title=$config->{graphs}->{_pagespeed7}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:fihit=$rrd:pagespeed" . $e . "_fihit:AVERAGE",
			"DEF:fiins=$rrd:pagespeed" . $e . "_fiins:AVERAGE",
			"DEF:fimis=$rrd:pagespeed" . $e . "_fimis:AVERAGE",
			"DEF:lrhit=$rrd:pagespeed" . $e . "_lrhit:AVERAGE",
			"DEF:lrins=$rrd:pagespeed" . $e . "_lrins:AVERAGE",
			"DEF:lrmis=$rrd:pagespeed" . $e . "_lrmis:AVERAGE",
			"CDEF:allvalues=fihit,fiins,fimis,lrhit,lrins,lrmis,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 8 + 6]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 8 + 6]",
				"--title=$config->{graphs}->{_pagespeed7}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Value/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:fihit=$rrd:pagespeed" . $e . "_fihit:AVERAGE",
				"DEF:fiins=$rrd:pagespeed" . $e . "_fiins:AVERAGE",
				"DEF:fimis=$rrd:pagespeed" . $e . "_fimis:AVERAGE",
				"DEF:lrhit=$rrd:pagespeed" . $e . "_lrhit:AVERAGE",
				"DEF:lrins=$rrd:pagespeed" . $e . "_lrins:AVERAGE",
				"DEF:lrmis=$rrd:pagespeed" . $e . "_lrmis:AVERAGE",
				"CDEF:allvalues=fihit,fiins,fimis,lrhit,lrins,lrmis,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 8 + 6]: $err\n") if $err;
		}
		$e2 = $e + 7;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pagespeed$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 6] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 6] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 6] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 6] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 6] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[7], $limit[7])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:catim#44EEEE:Cache time");
		push(@tmp, "GPRINT:catim" . ":LAST:           Current\\:%6.0lf\\n");
		push(@tmpz, "LINE2:catim#44EEEE:Cache time");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 8 + 7]",
			"--title=$config->{graphs}->{_pagespeed8}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Microseconds/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:catim=$rrd:pagespeed" . $e . "_catim:AVERAGE",
			"CDEF:allvalues=catim",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 8 + 7]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 8 + 7]",
				"--title=$config->{graphs}->{_pagespeed8}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Microseconds/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:catim=$rrd:pagespeed" . $e . "_catim:AVERAGE",
				"CDEF:allvalues=catim",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 8 + 7]: $err\n") if $err;
		}
		$e2 = $e + 8;
		if($title || ($silent =~ /imagetag/ && $graph =~ /pagespeed$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 7] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 7] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 8 + 7] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 7] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 8 + 7] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");

			push(@output, "    <tr>\n");
			push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
			push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
			push(@output, "       <font size='-1'>\n");
			push(@output, "        <b>&nbsp;&nbsp;<a href='" . $l . "' style='color: $colors->{title_fg_color}'>$l</a><b>\n");
			push(@output, "       </font></font>\n");
			push(@output, "      </td>\n");
			push(@output, "    </tr>\n");
			push(@output, main::graph_footer());
		}
		$e++;
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
