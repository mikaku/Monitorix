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

package bind;

use strict;
use warnings;
use Monitorix;
use RRDs;
use LWP::UserAgent;
use XML::LibXML;
use Exporter 'import';
our @EXPORT = qw(bind_init bind_update bind_cgi);

sub bind_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $bind = $config->{bind};

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
		if(scalar(@ds) / 135 != scalar(my @bl = split(',', $bind->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @bl = split(',', $bind->{list})) . ") and $rrd (" . scalar(@ds) / 135 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @bl = split(',', $bind->{list})); $n++) {
			push(@tmp, "DS:bind" . $n . "_totalinq:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq01:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq02:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq03:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq04:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq05:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq06:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq07:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq08:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq09:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq10:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq11:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq12:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq13:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq14:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq15:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq16:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq17:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq18:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq19:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_inq20:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq01:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq02:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq03:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq04:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq05:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq06:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq07:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq08:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq09:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq10:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq11:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq12:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq13:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq14:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq15:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq16:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq17:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq18:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq19:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ouq20:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss01:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss02:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss03:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss04:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss05:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss06:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss07:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss08:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss09:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss10:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss11:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss12:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss13:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss14:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss15:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss16:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss17:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss18:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss19:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_ss20:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs01:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs02:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs03:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs04:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs05:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs06:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs07:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs08:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs09:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs10:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs11:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs12:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs13:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs14:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs15:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs16:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs17:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs18:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs19:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_rs20:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr01:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr02:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr03:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr04:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr05:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr06:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr07:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr08:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr09:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr10:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr11:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr12:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr13:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr14:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr15:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr16:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr17:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr18:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr19:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_crr20:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio01:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio02:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio03:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio04:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio05:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio06:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio07:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio08:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio09:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio10:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio11:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio12:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio13:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio14:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio15:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio16:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio17:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio18:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio19:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_sio20:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_mem_totaluse:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_mem_inuse:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_mem_blksize:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_mem_ctxtsize:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_mem_lost:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_mem_val01:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_mem_val02:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_mem_val03:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_tsk_workthrds:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_tsk_defquantm:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_tsk_tasksrun:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_tsk_val01:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_tsk_val02:GAUGE:120:0:U");
			push(@tmp, "DS:bind" . $n . "_tsk_val03:GAUGE:120:0:U");
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

	# this fixes the lack of minimum definition in some data sources
	for($n = 0; $n < scalar(my @bl = split(',', $bind->{list})); $n++) {
		RRDs::tune($rrd,
			"--minimum=bind" . $n . "_totalinq:0",
			"--minimum=bind" . $n . "_inq01:0",
			"--minimum=bind" . $n . "_inq02:0",
			"--minimum=bind" . $n . "_inq03:0",
			"--minimum=bind" . $n . "_inq04:0",
			"--minimum=bind" . $n . "_inq05:0",
			"--minimum=bind" . $n . "_ouq01:0",
			"--minimum=bind" . $n . "_ouq02:0",
			"--minimum=bind" . $n . "_ouq03:0",
			"--minimum=bind" . $n . "_ouq04:0",
			"--minimum=bind" . $n . "_ouq05:0",
			"--minimum=bind" . $n . "_crr01:0",
			"--minimum=bind" . $n . "_crr02:0",
			"--minimum=bind" . $n . "_crr03:0",
			"--minimum=bind" . $n . "_crr04:0",
			"--minimum=bind" . $n . "_crr05:0",
		);
	}

	$config->{bind_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub bind_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $bind = $config->{bind};

	my $totalinq;
	my %inq = ();
	my %ouq = ();
	my %ss = ();
	my %rs = ();
	my %crr = ();
	my %sio = ();
	my $str;
	my $n;
	my $n2;
	my $rrdata = "N";

	for($n = 0; $n < scalar(my @bl = split(',', $bind->{list})); $n++) {
		my $l = trim($bl[$n]);
		my $ssl = "";

		$ssl = "ssl_opts => {verify_hostname => 0}"
			if lc($config->{accept_selfsigned_certs}) eq "y";

		my $ua = LWP::UserAgent->new(timeout => 30, $ssl);
		$ua->agent($config->{user_agent_id}) if $config->{user_agent_id} || "";
		my $response = $ua->request(HTTP::Request->new('GET', $l));
		my $data = XML::LibXML->new->load_xml(string => $response->content);
		my $value;

		# BIND v9.9+ has different statistics layout than BIND v9.5+.
		# we attempt first to get stats from a BIND v9.5+
		if(!($value = $data->findnodes('/isc/bind/statistics/@version'))) {
			# otherwise attempt it on a BIND v9.9+
			$value = $data->findnodes('/statistics/@version');
		}
		my ($major, $minor) = split('\.', $value);
		$minor =~ m/^(\d+)/;
		if(!grep {$_ eq $major} ("2", "3")) {
			my $version = $major . "." . $minor;
			logger("$myself: BIND stats version '$version' unsupported.");
		}

		if($major eq "2") {
			foreach my $counters ($data->findnodes('/isc/bind/statistics/server/requests/opcode')) {
				foreach my $c ($counters) {
					my $name = $c->findvalue('name');
					my $counter = $c->findvalue('counter');
					$value = $counter if $name eq "QUERY";
				}
			}
		}
		if($major eq "3") {
			$value = $data->findvalue('/statistics/server/counters/counter[@name="QUERY"]');
		}
		$str = $n . "totalinq";
		$value = $value || 0;
		$totalinq = $value - ($config->{bind_hist}->{$str} || 0);
		$totalinq = 0 unless $totalinq != $value;
		$totalinq /= 60;
		$config->{bind_hist}->{$str} = $value;

		if($major eq "2") {
			foreach my $counters ($data->findnodes('/isc/bind/statistics/server/queries-in/*')) {
				foreach my $c ($counters) {
					my $name = $c->findvalue('name');
					my $counter = $c->findvalue('counter');
					$str = $n . "inq_$name";
					$inq{$str} = $counter - ($config->{bind_hist}->{$str} || 0);
					$inq{$str} = 0 unless $inq{$str} != $counter;
					$inq{$str} /= 60;
					$config->{bind_hist}->{$str} = $counter;
				}
			}
		}
		if($major eq "3") {
			foreach my $counters ($data->findnodes('/statistics/server/counters[@type="qtype"]/*')) {
				foreach my $c ($counters) {
					my $name = $c->findvalue('@name');
					my $counter = $c->textContent();
					$str = $n . "inq_$name";
					$inq{$str} = $counter - ($config->{bind_hist}->{$str} || 0);
					$inq{$str} = 0 unless $inq{$str} != $counter;
					$inq{$str} /= 60;
					$config->{bind_hist}->{$str} = $counter;
				}
			}
		}

		if($major eq "2") {
			foreach my $counters ($data->findnodes('/isc/bind/statistics/views/view/rdtype')) {
				foreach my $c ($counters) {
					my $name = $c->findvalue('name');
					my $counter = $c->findvalue('counter');
					$str = $n . "ouq_$name";
					$ouq{$str} = $counter - ($config->{bind_hist}->{$str} || 0);
					$ouq{$str} = 0 unless $ouq{$str} != $counter;
					$ouq{$str} /= 60;
					$config->{bind_hist}->{$str} = $counter;
				}
			}
		}
		if($major eq "3") {
			foreach my $counters ($data->findnodes('/statistics/views/view[@name="_default"]/counters[@type="resqtype"]/*')) {
				foreach my $c ($counters) {
					my $name = $c->findvalue('@name');
					my $counter = $c->textContent();
					$str = $n . "ouq_$name";
					$ouq{$str} = $counter - ($config->{bind_hist}->{$str} || 0);
					$ouq{$str} = 0 unless $ouq{$str} != $counter;
					$ouq{$str} /= 60;
					$config->{bind_hist}->{$str} = $counter;
				}
			}
		}

		if($major eq "2") {
			foreach my $counters ($data->findnodes('/isc/bind/statistics/server/nsstat')) {
				foreach my $c ($counters) {
					my $name = $c->findvalue('name');
					my $counter = $c->findvalue('counter');
					$str = $n . "ss_$name";
					$ss{$str} = $counter - ($config->{bind_hist}->{$str} || 0);
					$ss{$str} = 0 unless $ss{$str} != $counter;
					$ss{$str} /= 60;
					$config->{bind_hist}->{$str} = $counter;
				}
			}
		}
		if($major eq "3") {
			foreach my $counters ($data->findnodes('/statistics/server/counters[@type="nsstat"]/*')) {
				foreach my $c ($counters) {
					my $name = $c->findvalue('@name');
					my $counter = $c->textContent();
					$str = $n . "ss_$name";
					$ss{$str} = $counter - ($config->{bind_hist}->{$str} || 0);
					$ss{$str} = 0 unless $ss{$str} != $counter;
					$ss{$str} /= 60;
					$config->{bind_hist}->{$str} = $counter;
				}
			}
		}

		if($major eq "2") {
			LOOP:
			foreach my $counters ($data->findnodes('/isc/bind/statistics/views/view/resstat')) {
				foreach my $c ($counters) {
					my $name = $c->findvalue('name');
					my $counter = $c->findvalue('counter');
					last LOOP if $name eq "Queryv4" && defined($rs{$str});
					$str = $n . "rs_$name";
					$rs{$str} = $counter - ($config->{bind_hist}->{$str} || 0);
					$rs{$str} = 0 unless $rs{$str} != $counter;
					$rs{$str} /= 60;
					$config->{bind_hist}->{$str} = $counter;
				}
			}
		}
		if($major eq "3") {
			foreach my $counters ($data->findnodes('/statistics/views/view[@name="_default"]/counters[@type="resstats"]/*')) {
				foreach my $c ($counters) {
					my $name = $c->findvalue('@name');
					my $counter = $c->textContent();
					$str = $n . "rs_$name";
					$rs{$str} = $counter - ($config->{bind_hist}->{$str} || 0);
					$rs{$str} = 0 unless $rs{$str} != $counter;
					$rs{$str} /= 60;
					$config->{bind_hist}->{$str} = $counter;
				}
			}
		}

		if($major eq "2") {
			foreach my $counters ($data->findnodes('/isc/bind/statistics/views/view/cache[@name="_default"]/rrset')) {
				foreach my $c ($counters) {
					my $name = $c->findvalue('name');
					my $counter = $c->findvalue('counter');
					$str = $n . "crr_$name";
					$crr{$str} = $counter;
				}
			}
		}
		if($major eq "3") {
			foreach my $counters ($data->findnodes('/statistics/views/view[@name="_default"]/cache[@name="_default"]/*')) {
				foreach my $c ($counters) {
					my $name = $c->findvalue('name');
					my $counter = $c->findvalue('counter');
					$str = $n . "crr_$name";
					$crr{$str} = $counter;
				}
			}
		}

		$rrdata .= ":$totalinq";
		my @i;
		@i = split(',', $bind->{in_queries_list}->{$l});
		for($n2 = 0; $n2 < 20; $n2++) {
			my $j = trim($i[$n2] || 0);
			$str = $n . "inq_$j";
			$rrdata .= ":";
			$rrdata .= defined($inq{$str}) ? $inq{$str} : 0;
		}
		@i = split(',', $bind->{out_queries_list}->{$l});
		for($n2 = 0; $n2 < 20; $n2++) {
			my $j = trim($i[$n2] || 0);
			$str = $n . "ouq_$j";
			$rrdata .= ":";
			$rrdata .= defined($ouq{$str}) ? $ouq{$str} : 0;
		}
		@i = split(',', $bind->{server_stats_list}->{$l});
		for($n2 = 0; $n2 < 20; $n2++) {
			my $j = trim($i[$n2] || 0);
			$str = $n . "ss_$j";
			$rrdata .= ":";
			$rrdata .= defined($ss{$str}) ? $ss{$str} : 0;
		}
		@i = split(',', $bind->{resolver_stats_list}->{$l});
		for($n2 = 0; $n2 < 20; $n2++) {
			my $j = trim($i[$n2] || 0);
			$str = $n . "rs_$j";
			$rrdata .= ":";
			$rrdata .= defined($rs{$str}) ? $rs{$str} : 0;
		}
		@i = split(',', $bind->{cache_rrsets_list}->{$l});
		for($n2 = 0; $n2 < 20; $n2++) {
			my $j = trim($i[$n2] || 0);
			$str = $n . "crr_$j";
			$rrdata .= ":";
			$rrdata .= defined($crr{$str}) ? $crr{$str} : 0;
		}
#		@i = split(',', $bind->{sio_stats_list}->{$l});                                
		for($n2 = 0; $n2 < 20; $n2++) {                                                
			my $j = "";     #trim($i[$n2] || 0);
			$str = $n . "sio_$j";                                                  
			$rrdata .= ":";                                                        
			$rrdata .= defined($sio{$str}) ? $sio{$str} : 0;                       
		}                                                                        

		if($major eq "2") {
			foreach my $counters ($data->findnodes('/isc/bind/statistics/memory/summary')) {
				$rrdata .= ":" . $counters->findvalue('./TotalUse');
				$rrdata .= ":" . $counters->findvalue('./InUse');
				$rrdata .= ":" . $counters->findvalue('./BlockSize');
				$rrdata .= ":" . $counters->findvalue('./ContextSize');
				$rrdata .= ":" . $counters->findvalue('./Lost');
			}
			$rrdata .= ":0:0:0";
		}
		if($major eq "3") {
			foreach my $counters ($data->findnodes('/statistics/memory/summary')) {
				$rrdata .= ":" . $counters->findvalue('./TotalUse');
				$rrdata .= ":" . $counters->findvalue('./InUse');
				$rrdata .= ":" . $counters->findvalue('./BlockSize');
				$rrdata .= ":" . $counters->findvalue('./ContextSize');
				$rrdata .= ":" . $counters->findvalue('./Lost');
			}
			$rrdata .= ":0:0:0";
		}

		if($major eq "2") {
			foreach my $counters ($data->findnodes('/isc/bind/statistics/taskmgr/thread-model')) {
				$rrdata .= ":" . $counters->findvalue('./worker-threads');
				$rrdata .= ":" . $counters->findvalue('./default-quantum');
				$rrdata .= ":" . $counters->findvalue('./tasks-running');
			}
			$rrdata .= ":0:0:0";
		}
		if($major eq "3") {
			foreach my $counters ($data->findnodes('/statistics/taskmgr/thread-model')) {
				$rrdata .= ":" . $counters->findvalue('./worker-threads');
				$rrdata .= ":" . $counters->findvalue('./default-quantum');
				$rrdata .= ":" . $counters->findvalue('./tasks-running');
			}
			$rrdata .= ":0:0:0";
		}
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub bind_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $bind = $config->{bind};
	my @rigid = split(',', ($bind->{rigid} || ""));
	my @limit = split(',', ($bind->{limit} || ""));
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
	my $n;
	my $n2;
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
		$line0 = "                                                                                                                                                $config->{graphs}->{_bind1}                                                                                                                                     $config->{graphs}->{_bind2}                                                                                                                                                                                                                                                                                                          $config->{graphs}->{_bind3}                                                                                                                                                                                                                                                                                                  $config->{graphs}->{_bind4}                                                                                                                                      $config->{graphs}->{_bind5}                                           $config->{graphs}->{_bind6}                     $config->{graphs}->{_bind7}";
		for($n = 0; $n < scalar(my @bl = split(',', $bind->{list})); $n++) {
			my $l = trim($bl[$n]);
			$line1 .= $line0;
			$line3 .= "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
			$n2 = 0;
			foreach (split(',', $bind->{in_queries_list}->{$l})) {
				$str = sprintf("%7s", substr(trim($_), 0, 7));
				$line2 .= sprintf(" %7s", $str);
				$n2++;
			}
			for(; $n2 < 20; $n2++) {
				$str = sprintf("%7s", substr(trim($_), 0, 7));
				$line2 .= sprintf(" %7s", $str);
			}

			$n2 = 0;
			foreach (split(',', $bind->{out_queries_list}->{$l})) {
				$str = sprintf("%7s", substr(trim($_), 0, 7));
				$line2 .= sprintf(" %7s", $str);
				$n2++;
			}
			for(; $n2 < 20; $n2++) {
				$str = sprintf("%7s", substr(trim($_), 0, 7));
				$line2 .= sprintf(" %7s", $str);
			}

			$n2 = 0;
			foreach (split(',', $bind->{server_stats_list}->{$l})) {
				$str = sprintf("%15s", substr(trim($_), 0, 15));
				$line2 .= sprintf(" %15s", $str);
				$n2++;
			}
			for(; $n2 < 20; $n2++) {
				$str = sprintf("%15s", substr(trim($_), 0, 15));
				$line2 .= sprintf(" %15s", $str);
			}

			$n2 = 0;
			foreach (split(',', $bind->{resolver_stats_list}->{$l})) {
				$str = sprintf("%15s", substr(trim($_), 0, 15));
				$line2 .= sprintf(" %15s", $str);
				$n2++;
			}
			for(; $n2 < 20; $n2++) {
				$str = sprintf("%15s", substr(trim($_), 0, 15));
				$line2 .= sprintf(" %15s", $str);
			}

			$n2 = 0;
			foreach (split(',', $bind->{cache_rrsets_list}->{$l})) {
				$str = sprintf("%7s", substr(trim($_), 0, 7));
				$line2 .= sprintf(" %7s", $str);
				$n2++;
			}
			for(; $n2 < 20; $n2++) {
				$str = sprintf("%7s", substr(trim($_), 0, 7));
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

			my $i = length($line0);
			push(@output, sprintf(sprintf("%${i}s", sprintf("BIND server: %s", $l))));
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
			for($n2 = 0; $n2 < scalar(my @bl = split(',', $bind->{list})); $n2++) {
				# inq
				$from += $n2 * 95;
				$to = $from + 20;
				@row = @$line[$from..$to];
				push(@output, sprintf("%7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row));
				# ouq
				$from = $to;
				$to = $from + 20;
				@row = @$line[$from..$to];
				push(@output, sprintf("%7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row));
				# ss
				$from = $to;
				$to = $from + 20;
				@row = @$line[$from..$to];
				push(@output, sprintf("%15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d ", @row));
				# rs
				$from = $to;
				$to = $from + 20;
				@row = @$line[$from..$to];
				push(@output, sprintf("%15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d %15d ", @row));
				# crr
				$from = $to;
				$to = $from + 20;
				@row = @$line[$from..$to];
				push(@output, sprintf("%7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d ", @row));
				# mem
				$from = $to;
				$to = $from + 8;
				@row = @$line[$from..$to];
				push(@output, sprintf("%10d %10d %10d %10d %10d ", @row));
				# tsk
				$from = $to;
				$to = $from + 6;
				@row = @$line[$from..$to];
				push(@output, sprintf("%10d %10d %10d ", @row));
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

	for($n = 0; $n < scalar(my @bl = split(',', $bind->{list})); $n++) {
		for($n2 = 1; $n2 <= 7; $n2++) {
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
	foreach (my @bl = split(',', $bind->{list})) {
		my $l = trim($_);
		if($e) {
			push(@output, print("   <br>\n"));
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}
		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		my @i;
		@i = split(',', $bind->{in_queries_list}->{$l});
		for($n = 0; $n < scalar(@i); $n += 2) {
			$str = sprintf("%-8s", substr(trim($i[$n]), 0, 8));
			push(@tmp, "LINE1:inq" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:inq" . $n . ":LAST: Current\\:%5.1lf       ");
			push(@tmpz, "LINE2:inq" . $n . $LC[$n] . ":$str");
			$str = sprintf("%-8s", substr(trim($i[$n + 1]), 0, 8));
			push(@tmp, "LINE1:inq" . ($n + 1) . $LC[$n + 1] . ":$str");
			push(@tmp, "GPRINT:inq" . ($n + 1) . ":LAST: Current\\:%5.1lf\\n");
			push(@tmpz, "LINE2:inq" . ($n + 1) . $LC[$n + 1] . ":$str");
		}
		for(; $n < 20; $n += 2) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7]",
			"--title=$config->{graphs}->{_bind1}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:inq0=$rrd:bind" . $e . "_inq01:AVERAGE",
			"DEF:inq1=$rrd:bind" . $e . "_inq02:AVERAGE",
			"DEF:inq2=$rrd:bind" . $e . "_inq03:AVERAGE",
			"DEF:inq3=$rrd:bind" . $e . "_inq04:AVERAGE",
			"DEF:inq4=$rrd:bind" . $e . "_inq05:AVERAGE",
			"DEF:inq5=$rrd:bind" . $e . "_inq06:AVERAGE",
			"DEF:inq6=$rrd:bind" . $e . "_inq07:AVERAGE",
			"DEF:inq7=$rrd:bind" . $e . "_inq08:AVERAGE",
			"DEF:inq8=$rrd:bind" . $e . "_inq09:AVERAGE",
			"DEF:inq9=$rrd:bind" . $e . "_inq10:AVERAGE",
			"DEF:inq10=$rrd:bind" . $e . "_inq11:AVERAGE",
			"DEF:inq11=$rrd:bind" . $e . "_inq12:AVERAGE",
			"DEF:inq12=$rrd:bind" . $e . "_inq13:AVERAGE",
			"DEF:inq13=$rrd:bind" . $e . "_inq14:AVERAGE",
			"DEF:inq14=$rrd:bind" . $e . "_inq15:AVERAGE",
			"DEF:inq15=$rrd:bind" . $e . "_inq16:AVERAGE",
			"DEF:inq16=$rrd:bind" . $e . "_inq17:AVERAGE",
			"DEF:inq17=$rrd:bind" . $e . "_inq18:AVERAGE",
			"DEF:inq18=$rrd:bind" . $e . "_inq19:AVERAGE",
			"DEF:inq19=$rrd:bind" . $e . "_inq20:AVERAGE",
			"CDEF:allvalues=inq0,inq1,inq2,inq3,inq4,inq5,inq6,inq7,inq8,inq9,inq10,inq11,inq12,inq13,inq14,inq15,inq16,inq17,inq18,inq19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7]",
				"--title=$config->{graphs}->{_bind1}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:inq0=$rrd:bind" . $e . "_inq01:AVERAGE",
				"DEF:inq1=$rrd:bind" . $e . "_inq02:AVERAGE",
				"DEF:inq2=$rrd:bind" . $e . "_inq03:AVERAGE",
				"DEF:inq3=$rrd:bind" . $e . "_inq04:AVERAGE",
				"DEF:inq4=$rrd:bind" . $e . "_inq05:AVERAGE",
				"DEF:inq5=$rrd:bind" . $e . "_inq06:AVERAGE",
				"DEF:inq6=$rrd:bind" . $e . "_inq07:AVERAGE",
				"DEF:inq7=$rrd:bind" . $e . "_inq08:AVERAGE",
				"DEF:inq8=$rrd:bind" . $e . "_inq09:AVERAGE",
				"DEF:inq9=$rrd:bind" . $e . "_inq10:AVERAGE",
				"DEF:inq10=$rrd:bind" . $e . "_inq11:AVERAGE",
				"DEF:inq11=$rrd:bind" . $e . "_inq12:AVERAGE",
				"DEF:inq12=$rrd:bind" . $e . "_inq13:AVERAGE",
				"DEF:inq13=$rrd:bind" . $e . "_inq14:AVERAGE",
				"DEF:inq14=$rrd:bind" . $e . "_inq15:AVERAGE",
				"DEF:inq15=$rrd:bind" . $e . "_inq16:AVERAGE",
				"DEF:inq16=$rrd:bind" . $e . "_inq17:AVERAGE",
				"DEF:inq17=$rrd:bind" . $e . "_inq18:AVERAGE",
				"DEF:inq18=$rrd:bind" . $e . "_inq19:AVERAGE",
				"DEF:inq19=$rrd:bind" . $e . "_inq20:AVERAGE",
				"CDEF:allvalues=inq0,inq1,inq2,inq3,inq4,inq5,inq6,inq7,inq8,inq9,inq10,inq11,inq12,inq13,inq14,inq15,inq16,inq17,inq18,inq19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind1/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7] . "'>\n");
			}
		}
		if($title) {
			push(@output, "    </td>\n");
		}

		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		@i = split(',', $bind->{out_queries_list}->{$l});
		for($n = 0; $n < scalar(@i); $n += 2) {
			$str = sprintf("%-8s", substr(trim($i[$n]), 0, 8));
			push(@tmp, "LINE1:ouq" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:ouq" . $n . ":LAST: Current\\:%5.1lf       ");
			push(@tmpz, "LINE2:ouq" . $n . $LC[$n] . ":$str");
			$str = sprintf("%-8s", substr(trim($i[$n + 1]), 0, 8));
			push(@tmp, "LINE1:ouq" . ($n + 1) . $LC[$n + 1] . ":$str");
			push(@tmp, "GPRINT:ouq" . ($n + 1) . ":LAST: Current\\:%5.1lf\\n");
			push(@tmpz, "LINE2:ouq" . ($n + 1) . $LC[$n + 1] . ":$str");
		}
		for(; $n < 20; $n += 2) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			push(@output, "    <td>\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 1]",
			"--title=$config->{graphs}->{_bind2}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:ouq0=$rrd:bind" . $e . "_ouq01:AVERAGE",
			"DEF:ouq1=$rrd:bind" . $e . "_ouq02:AVERAGE",
			"DEF:ouq2=$rrd:bind" . $e . "_ouq03:AVERAGE",
			"DEF:ouq3=$rrd:bind" . $e . "_ouq04:AVERAGE",
			"DEF:ouq4=$rrd:bind" . $e . "_ouq05:AVERAGE",
			"DEF:ouq5=$rrd:bind" . $e . "_ouq06:AVERAGE",
			"DEF:ouq6=$rrd:bind" . $e . "_ouq07:AVERAGE",
			"DEF:ouq7=$rrd:bind" . $e . "_ouq08:AVERAGE",
			"DEF:ouq8=$rrd:bind" . $e . "_ouq09:AVERAGE",
			"DEF:ouq9=$rrd:bind" . $e . "_ouq10:AVERAGE",
			"DEF:ouq10=$rrd:bind" . $e . "_ouq11:AVERAGE",
			"DEF:ouq11=$rrd:bind" . $e . "_ouq12:AVERAGE",
			"DEF:ouq12=$rrd:bind" . $e . "_ouq13:AVERAGE",
			"DEF:ouq13=$rrd:bind" . $e . "_ouq14:AVERAGE",
			"DEF:ouq14=$rrd:bind" . $e . "_ouq15:AVERAGE",
			"DEF:ouq15=$rrd:bind" . $e . "_ouq16:AVERAGE",
			"DEF:ouq16=$rrd:bind" . $e . "_ouq17:AVERAGE",
			"DEF:ouq17=$rrd:bind" . $e . "_ouq18:AVERAGE",
			"DEF:ouq18=$rrd:bind" . $e . "_ouq19:AVERAGE",
			"DEF:ouq19=$rrd:bind" . $e . "_ouq20:AVERAGE",
			"CDEF:allvalues=ouq0,ouq1,ouq2,ouq3,ouq4,ouq5,ouq6,ouq7,ouq8,ouq9,ouq10,ouq11,ouq12,ouq13,ouq14,ouq15,ouq16,ouq17,ouq18,ouq19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 1]",
				"--title=$config->{graphs}->{_bind2}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:ouq0=$rrd:bind" . $e . "_ouq01:AVERAGE",
				"DEF:ouq1=$rrd:bind" . $e . "_ouq02:AVERAGE",
				"DEF:ouq2=$rrd:bind" . $e . "_ouq03:AVERAGE",
				"DEF:ouq3=$rrd:bind" . $e . "_ouq04:AVERAGE",
				"DEF:ouq4=$rrd:bind" . $e . "_ouq05:AVERAGE",
				"DEF:ouq5=$rrd:bind" . $e . "_ouq06:AVERAGE",
				"DEF:ouq6=$rrd:bind" . $e . "_ouq07:AVERAGE",
				"DEF:ouq7=$rrd:bind" . $e . "_ouq08:AVERAGE",
				"DEF:ouq8=$rrd:bind" . $e . "_ouq09:AVERAGE",
				"DEF:ouq9=$rrd:bind" . $e . "_ouq10:AVERAGE",
				"DEF:ouq10=$rrd:bind" . $e . "_ouq11:AVERAGE",
				"DEF:ouq11=$rrd:bind" . $e . "_ouq12:AVERAGE",
				"DEF:ouq12=$rrd:bind" . $e . "_ouq13:AVERAGE",
				"DEF:ouq13=$rrd:bind" . $e . "_ouq14:AVERAGE",
				"DEF:ouq14=$rrd:bind" . $e . "_ouq15:AVERAGE",
				"DEF:ouq15=$rrd:bind" . $e . "_ouq16:AVERAGE",
				"DEF:ouq16=$rrd:bind" . $e . "_ouq17:AVERAGE",
				"DEF:ouq17=$rrd:bind" . $e . "_ouq18:AVERAGE",
				"DEF:ouq18=$rrd:bind" . $e . "_ouq19:AVERAGE",
				"DEF:ouq19=$rrd:bind" . $e . "_ouq20:AVERAGE",
				"CDEF:allvalues=ouq0,ouq1,ouq2,ouq3,ouq4,ouq5,ouq6,ouq7,ouq8,ouq9,ouq10,ouq11,ouq12,ouq13,ouq14,ouq15,ouq16,ouq17,ouq18,ouq19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 1]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 1] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		@i = split(',', $bind->{server_stats_list}->{$l});
		for($n = 0; $n < scalar(@i); $n += 2) {
			$str = sprintf("%-14s", substr(trim($i[$n]), 0, 14));
			push(@tmp, "LINE1:ss" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:ss" . $n . ":LAST:Cur\\:%5.1lf     ");
			push(@tmpz, "LINE2:ss" . $n . $LC[$n] . ":$str");
			$str = sprintf("%-14s", substr(trim($i[$n + 1]), 0, 14));
			push(@tmp, "LINE1:ss" . ($n + 1) . $LC[$n + 1] . ":$str");
			push(@tmp, "GPRINT:ss" . ($n + 1) . ":LAST:Cur\\:%5.1lf\\n");
			push(@tmpz, "LINE2:ss" . ($n + 1) . $LC[$n + 1] . ":$str");
		}
		for(; $n < 20; $n += 2) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 2]",
			"--title=$config->{graphs}->{_bind3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:ss0=$rrd:bind" . $e . "_ss01:AVERAGE",
			"DEF:ss1=$rrd:bind" . $e . "_ss02:AVERAGE",
			"DEF:ss2=$rrd:bind" . $e . "_ss03:AVERAGE",
			"DEF:ss3=$rrd:bind" . $e . "_ss04:AVERAGE",
			"DEF:ss4=$rrd:bind" . $e . "_ss05:AVERAGE",
			"DEF:ss5=$rrd:bind" . $e . "_ss06:AVERAGE",
			"DEF:ss6=$rrd:bind" . $e . "_ss07:AVERAGE",
			"DEF:ss7=$rrd:bind" . $e . "_ss08:AVERAGE",
			"DEF:ss8=$rrd:bind" . $e . "_ss09:AVERAGE",
			"DEF:ss9=$rrd:bind" . $e . "_ss10:AVERAGE",
			"DEF:ss10=$rrd:bind" . $e . "_ss11:AVERAGE",
			"DEF:ss11=$rrd:bind" . $e . "_ss12:AVERAGE",
			"DEF:ss12=$rrd:bind" . $e . "_ss13:AVERAGE",
			"DEF:ss13=$rrd:bind" . $e . "_ss14:AVERAGE",
			"DEF:ss14=$rrd:bind" . $e . "_ss15:AVERAGE",
			"DEF:ss15=$rrd:bind" . $e . "_ss16:AVERAGE",
			"DEF:ss16=$rrd:bind" . $e . "_ss17:AVERAGE",
			"DEF:ss17=$rrd:bind" . $e . "_ss18:AVERAGE",
			"DEF:ss18=$rrd:bind" . $e . "_ss19:AVERAGE",
			"DEF:ss19=$rrd:bind" . $e . "_ss20:AVERAGE",
			"CDEF:allvalues=ss0,ss1,ss2,ss3,ss4,ss5,ss6,ss7,ss8,ss9,ss10,ss11,ss12,ss13,ss14,ss15,ss16,ss17,ss18,ss19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 2]",
				"--title=$config->{graphs}->{_bind3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Requests/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:ss0=$rrd:bind" . $e . "_ss01:AVERAGE",
				"DEF:ss1=$rrd:bind" . $e . "_ss02:AVERAGE",
				"DEF:ss2=$rrd:bind" . $e . "_ss03:AVERAGE",
				"DEF:ss3=$rrd:bind" . $e . "_ss04:AVERAGE",
				"DEF:ss4=$rrd:bind" . $e . "_ss05:AVERAGE",
				"DEF:ss5=$rrd:bind" . $e . "_ss06:AVERAGE",
				"DEF:ss6=$rrd:bind" . $e . "_ss07:AVERAGE",
				"DEF:ss7=$rrd:bind" . $e . "_ss08:AVERAGE",
				"DEF:ss8=$rrd:bind" . $e . "_ss09:AVERAGE",
				"DEF:ss9=$rrd:bind" . $e . "_ss10:AVERAGE",
				"DEF:ss10=$rrd:bind" . $e . "_ss11:AVERAGE",
				"DEF:ss11=$rrd:bind" . $e . "_ss12:AVERAGE",
				"DEF:ss12=$rrd:bind" . $e . "_ss13:AVERAGE",
				"DEF:ss13=$rrd:bind" . $e . "_ss14:AVERAGE",
				"DEF:ss14=$rrd:bind" . $e . "_ss15:AVERAGE",
				"DEF:ss15=$rrd:bind" . $e . "_ss16:AVERAGE",
				"DEF:ss16=$rrd:bind" . $e . "_ss17:AVERAGE",
				"DEF:ss17=$rrd:bind" . $e . "_ss18:AVERAGE",
				"DEF:ss18=$rrd:bind" . $e . "_ss19:AVERAGE",
				"DEF:ss19=$rrd:bind" . $e . "_ss20:AVERAGE",
				"CDEF:allvalues=ss0,ss1,ss2,ss3,ss4,ss5,ss6,ss7,ss8,ss9,ss10,ss11,ss12,ss13,ss14,ss15,ss16,ss17,ss18,ss19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 2]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind3/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 2] . "'>\n");
			}
		}
		if($title) {
			push(@output, "    </td>\n");
		}

		@riglim = @{setup_riglim($rigid[3], $limit[3])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		@i = split(',', $bind->{resolver_stats_list}->{$l});
		for($n = 0; $n < scalar(@i); $n += 2) {
			$str = sprintf("%-14s", substr(trim($i[$n]), 0, 14));
			push(@tmp, "LINE1:rs" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:rs" . $n . ":LAST:Cur\\:%5.1lf     ");
			push(@tmpz, "LINE2:rs" . $n . $LC[$n] . ":$str");
			$str = sprintf("%-14s", substr(trim($i[$n + 1]), 0, 14));
			push(@tmp, "LINE1:rs" . ($n + 1) . $LC[$n + 1] . ":$str");
			push(@tmp, "GPRINT:rs" . ($n + 1) . ":LAST:Cur\\:%5.1lf\\n");
			push(@tmpz, "LINE2:rs" . ($n + 1) . $LC[$n + 1] . ":$str");
		}
		for(; $n < 20; $n += 2) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			push(@output, "    <td>\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 3]",
			"--title=$config->{graphs}->{_bind4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:rs0=$rrd:bind" . $e . "_rs01:AVERAGE",
			"DEF:rs1=$rrd:bind" . $e . "_rs02:AVERAGE",
			"DEF:rs2=$rrd:bind" . $e . "_rs03:AVERAGE",
			"DEF:rs3=$rrd:bind" . $e . "_rs04:AVERAGE",
			"DEF:rs4=$rrd:bind" . $e . "_rs05:AVERAGE",
			"DEF:rs5=$rrd:bind" . $e . "_rs06:AVERAGE",
			"DEF:rs6=$rrd:bind" . $e . "_rs07:AVERAGE",
			"DEF:rs7=$rrd:bind" . $e . "_rs08:AVERAGE",
			"DEF:rs8=$rrd:bind" . $e . "_rs09:AVERAGE",
			"DEF:rs9=$rrd:bind" . $e . "_rs10:AVERAGE",
			"DEF:rs10=$rrd:bind" . $e . "_rs11:AVERAGE",
			"DEF:rs11=$rrd:bind" . $e . "_rs12:AVERAGE",
			"DEF:rs12=$rrd:bind" . $e . "_rs13:AVERAGE",
			"DEF:rs13=$rrd:bind" . $e . "_rs14:AVERAGE",
			"DEF:rs14=$rrd:bind" . $e . "_rs15:AVERAGE",
			"DEF:rs15=$rrd:bind" . $e . "_rs16:AVERAGE",
			"DEF:rs16=$rrd:bind" . $e . "_rs17:AVERAGE",
			"DEF:rs17=$rrd:bind" . $e . "_rs18:AVERAGE",
			"DEF:rs18=$rrd:bind" . $e . "_rs19:AVERAGE",
			"DEF:rs19=$rrd:bind" . $e . "_rs20:AVERAGE",
			"CDEF:allvalues=rs0,rs1,rs2,rs3,rs4,rs5,rs6,rs7,rs8,rs9,rs10,rs11,rs12,rs13,rs14,rs15,rs16,rs17,rs18,rs19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 3]",
				"--title=$config->{graphs}->{_bind4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Requests/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:rs0=$rrd:bind" . $e . "_rs01:AVERAGE",
				"DEF:rs1=$rrd:bind" . $e . "_rs02:AVERAGE",
				"DEF:rs2=$rrd:bind" . $e . "_rs03:AVERAGE",
				"DEF:rs3=$rrd:bind" . $e . "_rs04:AVERAGE",
				"DEF:rs4=$rrd:bind" . $e . "_rs05:AVERAGE",
				"DEF:rs5=$rrd:bind" . $e . "_rs06:AVERAGE",
				"DEF:rs6=$rrd:bind" . $e . "_rs07:AVERAGE",
				"DEF:rs7=$rrd:bind" . $e . "_rs08:AVERAGE",
				"DEF:rs8=$rrd:bind" . $e . "_rs09:AVERAGE",
				"DEF:rs9=$rrd:bind" . $e . "_rs10:AVERAGE",
				"DEF:rs10=$rrd:bind" . $e . "_rs11:AVERAGE",
				"DEF:rs11=$rrd:bind" . $e . "_rs12:AVERAGE",
				"DEF:rs12=$rrd:bind" . $e . "_rs13:AVERAGE",
				"DEF:rs13=$rrd:bind" . $e . "_rs14:AVERAGE",
				"DEF:rs14=$rrd:bind" . $e . "_rs15:AVERAGE",
				"DEF:rs15=$rrd:bind" . $e . "_rs16:AVERAGE",
				"DEF:rs16=$rrd:bind" . $e . "_rs17:AVERAGE",
				"DEF:rs17=$rrd:bind" . $e . "_rs18:AVERAGE",
				"DEF:rs18=$rrd:bind" . $e . "_rs19:AVERAGE",
				"DEF:rs19=$rrd:bind" . $e . "_rs20:AVERAGE",
				"CDEF:allvalues=rs0,rs1,rs2,rs3,rs4,rs5,rs6,rs7,rs8,rs9,rs10,rs11,rs12,rs13,rs14,rs15,rs16,rs17,rs18,rs19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 3]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind4/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 3] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[4], $limit[4])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		@i = split(',', $bind->{cache_rrsets_list}->{$l});
		for($n = 0; $n < scalar(@i); $n += 2) {
			$str = sprintf("%-8s", substr(trim($i[$n]), 0, 8));
			push(@tmp, "LINE1:crr" . $n . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:crr" . $n . ":LAST:  Cur\\:%8.1lf       ");
			push(@tmpz, "LINE2:crr" . $n . $LC[$n] . ":$str");
			$str = sprintf("%-8s", substr(trim($i[$n + 1]), 0, 8));
			push(@tmp, "LINE1:crr" . ($n + 1) . $LC[$n + 1] . ":$str");
			push(@tmp, "GPRINT:crr" . ($n + 1) . ":LAST: Cur\\:%8.1lf\\n");
			push(@tmpz, "LINE2:crr" . ($n + 1) . $LC[$n + 1] . ":$str");
		}
		for(; $n < 20; $n += 2) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 4]",
			"--title=$config->{graphs}->{_bind5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=RRsets",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:crr0=$rrd:bind" . $e . "_crr01:AVERAGE",
			"DEF:crr1=$rrd:bind" . $e . "_crr02:AVERAGE",
			"DEF:crr2=$rrd:bind" . $e . "_crr03:AVERAGE",
			"DEF:crr3=$rrd:bind" . $e . "_crr04:AVERAGE",
			"DEF:crr4=$rrd:bind" . $e . "_crr05:AVERAGE",
			"DEF:crr5=$rrd:bind" . $e . "_crr06:AVERAGE",
			"DEF:crr6=$rrd:bind" . $e . "_crr07:AVERAGE",
			"DEF:crr7=$rrd:bind" . $e . "_crr08:AVERAGE",
			"DEF:crr8=$rrd:bind" . $e . "_crr09:AVERAGE",
			"DEF:crr9=$rrd:bind" . $e . "_crr10:AVERAGE",
			"DEF:crr10=$rrd:bind" . $e . "_crr11:AVERAGE",
			"DEF:crr11=$rrd:bind" . $e . "_crr12:AVERAGE",
			"DEF:crr12=$rrd:bind" . $e . "_crr13:AVERAGE",
			"DEF:crr13=$rrd:bind" . $e . "_crr14:AVERAGE",
			"DEF:crr14=$rrd:bind" . $e . "_crr15:AVERAGE",
			"DEF:crr15=$rrd:bind" . $e . "_crr16:AVERAGE",
			"DEF:crr16=$rrd:bind" . $e . "_crr17:AVERAGE",
			"DEF:crr17=$rrd:bind" . $e . "_crr18:AVERAGE",
			"DEF:crr18=$rrd:bind" . $e . "_crr19:AVERAGE",
			"DEF:crr19=$rrd:bind" . $e . "_crr20:AVERAGE",
			"CDEF:allvalues=crr0,crr1,crr2,crr3,crr4,crr5,crr6,crr7,crr8,crr9,crr10,crr11,crr12,crr13,crr14,crr15,crr16,crr17,crr18,crr19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 4]",
				"--title=$config->{graphs}->{_bind5}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=RRsets",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:crr0=$rrd:bind" . $e . "_crr01:AVERAGE",
				"DEF:crr1=$rrd:bind" . $e . "_crr02:AVERAGE",
				"DEF:crr2=$rrd:bind" . $e . "_crr03:AVERAGE",
				"DEF:crr3=$rrd:bind" . $e . "_crr04:AVERAGE",
				"DEF:crr4=$rrd:bind" . $e . "_crr05:AVERAGE",
				"DEF:crr5=$rrd:bind" . $e . "_crr06:AVERAGE",
				"DEF:crr6=$rrd:bind" . $e . "_crr07:AVERAGE",
				"DEF:crr7=$rrd:bind" . $e . "_crr08:AVERAGE",
				"DEF:crr8=$rrd:bind" . $e . "_crr09:AVERAGE",
				"DEF:crr9=$rrd:bind" . $e . "_crr10:AVERAGE",
				"DEF:crr10=$rrd:bind" . $e . "_crr11:AVERAGE",
				"DEF:crr11=$rrd:bind" . $e . "_crr12:AVERAGE",
				"DEF:crr12=$rrd:bind" . $e . "_crr13:AVERAGE",
				"DEF:crr13=$rrd:bind" . $e . "_crr14:AVERAGE",
				"DEF:crr14=$rrd:bind" . $e . "_crr15:AVERAGE",
				"DEF:crr15=$rrd:bind" . $e . "_crr16:AVERAGE",
				"DEF:crr16=$rrd:bind" . $e . "_crr17:AVERAGE",
				"DEF:crr17=$rrd:bind" . $e . "_crr18:AVERAGE",
				"DEF:crr18=$rrd:bind" . $e . "_crr19:AVERAGE",
				"DEF:crr19=$rrd:bind" . $e . "_crr20:AVERAGE",
				"CDEF:allvalues=crr0,crr1,crr2,crr3,crr4,crr5,crr6,crr7,crr8,crr9,crr10,crr11,crr12,crr13,crr14,crr15,crr16,crr17,crr18,crr19,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 4]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind5/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 4] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 4] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 4] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 4] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 4] . "'>\n");
			}
		}
		if($title) {
			push(@output, "    </td>\n");
		}

		@riglim = @{setup_riglim($rigid[5], $limit[5])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
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
			push(@output, "    <td>\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium2});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 5]",
			"--title=$config->{graphs}->{_bind6}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:mem_tu=$rrd:bind" . $e . "_mem_totaluse:AVERAGE",
			"DEF:mem_iu=$rrd:bind" . $e . "_mem_inuse:AVERAGE",
			"DEF:mem_bs=$rrd:bind" . $e . "_mem_blksize:AVERAGE",
			"DEF:mem_cs=$rrd:bind" . $e . "_mem_ctxtsize:AVERAGE",
			"DEF:mem_l=$rrd:bind" . $e . "_mem_lost:AVERAGE",
			"CDEF:mem_tu_mb=mem_tu,1024,/,1024,/",
			"CDEF:mem_iu_mb=mem_iu,1024,/,1024,/",
			"CDEF:mem_bs_mb=mem_bs,1024,/,1024,/",
			"CDEF:mem_cs_mb=mem_cs,1024,/,1024,/",
			"CDEF:mem_l_mb=mem_l,1024,/,1024,/",
			"CDEF:allvalues=mem_tu,mem_iu,mem_bs,mem_cs,mem_l,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 5]",
				"--title=$config->{graphs}->{_bind6}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:mem_tu=$rrd:bind" . $e . "_mem_totaluse:AVERAGE",
				"DEF:mem_iu=$rrd:bind" . $e . "_mem_inuse:AVERAGE",
				"DEF:mem_bs=$rrd:bind" . $e . "_mem_blksize:AVERAGE",
				"DEF:mem_cs=$rrd:bind" . $e . "_mem_ctxtsize:AVERAGE",
				"DEF:mem_l=$rrd:bind" . $e . "_mem_lost:AVERAGE",
				"CDEF:allvalues=mem_tu,mem_iu,mem_bs,mem_cs,mem_l,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 5]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind6/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 5] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 5] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 5] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 5] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 5] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[6], $limit[6])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE1:tsk_dq#EEEE44:Default Quantum");
		push(@tmp, "GPRINT:tsk_dq" . ":LAST:        Current\\:%4.0lf\\n");
		push(@tmpz, "LINE2:tsk_dq#EEEE44:Default Quantum");
		push(@tmp, "LINE1:tsk_wt#4444EE:Worker Threads");
		push(@tmp, "GPRINT:tsk_wt" . ":LAST:         Current\\:%4.0lf\\n");
		push(@tmpz, "LINE2:tsk_wt#4444EE:Worker Threads");
		push(@tmp, "LINE1:tsk_tr#44EEEE:Tasks Running");
		push(@tmp, "GPRINT:tsk_tr" . ":LAST:          Current\\:%4.0lf\\n");
		push(@tmpz, "LINE2:tsk_tr#44EEEE:Tasks Running");
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{medium2});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 7 + 6]",
			"--title=$config->{graphs}->{_bind7}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Tasks",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:tsk_wt=$rrd:bind" . $e . "_tsk_workthrds:AVERAGE",
			"DEF:tsk_dq=$rrd:bind" . $e . "_tsk_defquantm:AVERAGE",
			"DEF:tsk_tr=$rrd:bind" . $e . "_tsk_tasksrun:AVERAGE",
			"CDEF:allvalues=tsk_wt,tsk_dq,tsk_tr,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 7 + 6]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 7 + 6]",
				"--title=$config->{graphs}->{_bind7}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Tasks",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:tsk_wt=$rrd:bind" . $e . "_tsk_workthrds:AVERAGE",
				"DEF:tsk_dq=$rrd:bind" . $e . "_tsk_defquantm:AVERAGE",
				"DEF:tsk_tr=$rrd:bind" . $e . "_tsk_tasksrun:AVERAGE",
				"CDEF:allvalues=tsk_wt,tsk_dq,tsk_tr,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 7 + 6]: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /bind7/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 6] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 6] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 7 + 6] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 6] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 7 + 6] . "'>\n");
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
	return @output;;
}

1;
