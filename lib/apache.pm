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

package apache;

use strict;
use warnings;
use Monitorix;
use RRDs;
use LWP::UserAgent;
use Exporter 'import';
our @EXPORT = qw(apache_init apache_update apache_cgi);

#
# Some ideas of this upgrading function have been taken from a script written
# by Joost Cassee and found in the RRDtool Contrib Area:
# <https://oss.oetiker.ch/rrdtool/pub/contrib/>
#
sub upgrade_to_380 {
	my $myself = (caller(0))[3];
	my $rrd = shift;

	my $ds = 0;
	my $cdp = 0;
	my $in_idle = 0;
	my $str = "";

	logger("$myself: Adding 16 extra DS values to '$rrd'.");
	logger("$myself: $!") if !(open(IN, "rrdtool dump $rrd |"));
	logger("$myself: $!") if !(open(OUT, "| rrdtool restore - $rrd.new"));

	while(<IN>) {
		$ds = 1 if /<!-- Round Robin Database Dump -->/;
		$ds = 0 if /<!-- Round Robin Archives -->/;
		$cdp = 1 if /<cdp_prep>/;
		$cdp = 0 if /<\/cdp_prep>/;
		if($ds) {
			if(/<name> apache(\d+)_idle <\/name>/) {
				$str = "apache$1" . "_wcon";
				$in_idle = 1;
			}
			if($in_idle) {
				if(/<\/ds>/) {
					print OUT $_;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> Nan </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_wcon/_star/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_star/_rreq/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_rreq/_srep/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_srep/_keep/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_keep/_dnsl/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_dnsl/_ccon/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_ccon/_logg/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_logg/_gfin/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_gfin/_idlc/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_idlc/_slot/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_slot/_val1/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_val1/_val2/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_val2/_val3/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_val3/_val4/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$str =~ s/_val4/_val5/;
					print OUT "\n";
					print OUT <<EOF;
	<ds>
		<name> $str </name>
		<type> GAUGE </type>
		<minimal_heartbeat> 120 </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>
EOF
					$in_idle = 0;
					next;
				}
			}
		}
		if($cdp) {
			if(/<\/ds>/) {
				if(!($cdp % 5)) {
					print OUT $_;
					print OUT <<EOF;
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
			<ds>
			<primary_value> 0.0000000000e+00 </primary_value>
			<secondary_value> NaN </secondary_value>
			<value> NaN </value>
			<unknown_datapoints> 0 </unknown_datapoints>
			</ds>
EOF
					$cdp++;
					next;
				}
				$cdp++;
			}
		}

		if(/<\/row>/) {
			my $str = $_;
			my $n = 0;
			$str =~ s/(\s*<\/v>)/++$n % 5 == 0 ? " $1<v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v><v> NaN <\/v>" : $1/eg;
			print OUT $str;
			next;
		}

		print OUT $_;
	}
	close(IN);
	close(OUT);

	if(-f "$rrd.new") {
		rename($rrd, "$rrd.old");
		rename("$rrd.new", $rrd);
	} else {
		logger("$myself: WARNING: something went wrong upgrading $rrd. You have an unsupported old version.");
	}
}

sub apache_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $apache = $config->{apache};

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	if(!scalar(my @al = split(',', $apache->{list}))) {
		logger("$myself: ERROR: missing or not defined 'list' option.");
		return 0;
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

		# convert from 3.7.0- to 3.8.0 (adding 16 extra DS)
		upgrade_to_380($rrd) if scalar(@ds) == 5;
		# recalculate the number of DS
		undef(@ds);
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'ds[') == 0) {
				if(index($key, '.type') != -1) {
					push(@ds, substr($key, 3, index($key, ']') - 3));
				}
			}
		}

		if(scalar(@ds) / 21 != scalar(my @al = split(',', $apache->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @al = split(',', $apache->{list})) . ") and $rrd (" . scalar(@ds) / 21 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @al = split(',', $apache->{list})); $n++) {
			push(@tmp, "DS:apache" . $n . "_acc:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_kb:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_cpu:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_busy:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_idle:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_wcon:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_star:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_rreq:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_srep:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_keep:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_dnsl:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_ccon:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_logg:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_gfin:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_idlc:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_slot:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_val1:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_val2:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_val3:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_val4:GAUGE:120:0:U");
			push(@tmp, "DS:apache" . $n . "_val5:GAUGE:120:0:U");
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

	$config->{apache_hist} = ();
	$config->{apache_hist_alerts} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub apache_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $apache = $config->{apache};

	my $str;
	my $rrdata = "N";

	my $n = 0;
	foreach(my @al = split(',', $apache->{list})) {
		my $url = trim($_);
		my $ssl = "";

		my $acc = 0;
		my $kb = 0;
		my $cpu = 0;
		my $busy = 0;
		my $idle = 0;
		my $wcon = 0;
		my $star = 0;
		my $rreq = 0;
		my $srep = 0;
		my $keep = 0;
		my $dnsl = 0;
		my $ccon = 0;
		my $logg = 0;
		my $gfin = 0;
		my $idlc = 0;
		my $slot = 0;

		$ssl = "ssl_opts => {verify_hostname => 0}"
			if lc($config->{accept_selfsigned_certs}) eq "y";

		my $ua = LWP::UserAgent->new(timeout => 30, $ssl);
		$ua->agent($config->{user_agent_id}) if $config->{user_agent_id} || "";
		my $response = $ua->request(HTTP::Request->new('GET', $url));

		if(!$response->is_success) {
			logger("$myself: ERROR: Unable to connect to '$url'.");
			logger("$myself: " . $response->status_line);
		} else {
			foreach(split('\n', $response->content)) {
				if(/^Total Accesses:\s+(\d+)$/) {
					$str = $n . "acc";
					$acc = $1 - ($config->{apache_hist}->{$str} || 0);
					$acc = 0 unless $acc != $1;
					$acc /= 60;
					$config->{apache_hist}->{$str} = $1;
					next;
				}
				if(/^Total kBytes:\s+(\d+)$/) {
					$str = $n . "kb";
					$kb = $1 - ($config->{apache_hist}->{$str} || 0);
					$kb = 0 unless $kb != $1;
					$config->{apache_hist}->{$str} = $1;
					next;
				}
				if(/^CPULoad:\s+(\d*\.\d+)$/) {
					$cpu = abs($1) || 0;
					next;
				}
				if(/^BusyWorkers:\s+(\d+)/ || /^BusyServers:\s+(\d+)/) {
					$busy = int($1) || 0;
					next;
				}
				if(/^IdleWorkers:\s+(\d+)/ || /^IdleServers:\s+(\d+)/) {
					$idle = int($1) || 0;
					next;
				}
				if(/^Scoreboard:\s+(\S+)$/) {
					my $scoreboard = $1;
					$wcon = ($scoreboard =~ tr/_//);
					$star = ($scoreboard =~ tr/S//);
					$rreq = ($scoreboard =~ tr/R//);
					$srep = ($scoreboard =~ tr/W//);
					$keep = ($scoreboard =~ tr/K//);
					$dnsl = ($scoreboard =~ tr/D//);
					$ccon = ($scoreboard =~ tr/C//);
					$logg = ($scoreboard =~ tr/L//);
					$gfin = ($scoreboard =~ tr/G//);
					$idlc = ($scoreboard =~ tr/I//);
					$slot = ($scoreboard =~ tr/\.//);
					last;
				}
			}

			# check alerts for each Apache
			my @al = split(',', $apache->{alerts}->{$url} || "");
			if(scalar(@al)) {
				my $timeintvl = trim($al[0]);
				my $threshold = trim($al[1]);
				my $script = trim($al[2]);
	
				if(!$threshold || $slot >= $threshold) {
					$config->{apache_hist_alerts}->{$url} = 0;
				} else {
					if(!$config->{apache_hist_alerts}->{$url}) {
						$config->{apache_hist_alerts}->{$url} = time;
					}
					if($config->{apache_hist_alerts}->{$url} > 0 && (time - $config->{apache_hist_alerts}->{$url}) >= $timeintvl) {
						if(-x $script) {
							logger("$myself: alert on Apache ($url): executing script '$script'.");
							system($script . " " . $timeintvl . " " . $threshold . " " . $slot);
						} else {
							logger("$myself: ERROR: script '$script' doesn't exist or don't has execution permissions.");
						}
						$config->{apache_hist_alerts}->{$url} = time;
					}
				}
	
			}

			if(!$acc && !$kb && !$busy && !$idle) {
				logger("$myself: WARNING: collected values are zero. Check the URL defined.");
			}
		}

		$rrdata .= ":$acc:$kb:$cpu:$busy:$idle:$wcon:$star:$rreq:$srep:$keep:$dnsl:$ccon:$logg:$gfin:$idlc:$slot:0:0:0:0:0";
		$n++;
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub apache_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $apache = $config->{apache};
	my @rigid = split(',', ($apache->{rigid} || ""));
	my @limit = split(',', ($apache->{limit} || ""));
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
		my $line1;
		my $line2;
		my $line3;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		for($n = 0; $n < scalar(my @al = split(',', $apache->{list})); $n++) {
			$line1 = "                                          ";
			$line2 .= "   Acceses     kbytes      CPU  Busy  Idle";
			$line3 .= "------------------------------------------";
			if($line1) {
				my $i = length($line1);
				push(@output, sprintf(sprintf("%${i}s", sprintf("%s", trim($al[$n])))));
			}
		}
		push(@output, "\n");
		push(@output, "Time$line2\n");
		push(@output, "----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc}", $time));
			for($n2 = 0; $n2 < scalar(my @al = split(',', $apache->{list})); $n2++) {
				undef(@row);
				$from = $n2 * 21;
				$to = $from + 21;
				push(@row, @$line[$from..$to]);
				push(@output, sprintf("   %7d  %9d    %4.2f%%   %3d   %3d", @row));
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

	for($n = 0; $n < scalar(my @al = split(',', $apache->{list})); $n++) {
		for($n2 = 1; $n2 <= 6; $n2++) {
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
	foreach my $url (my @al = split(',', $apache->{list})) {
		$url = trim($url);
		if($e) {
			push(@output, "  <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}
		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:apache" . $e . "_idle#4444EE:Idle");
		push(@tmp, "GPRINT:apache" . $e . "_idle:LAST:              Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_idle:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_idle:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_idle:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "AREA:apache" . $e . "_busy#44EEEE:Busy");
		push(@tmp, "GPRINT:apache" . $e . "_busy:LAST:              Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_busy:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_busy:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_busy:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "LINE1.5:apache" . $e . "_idle#0000EE");
		push(@tmp, "LINE1.5:apache" . $e . "_busy#00EEEE");
		push(@tmp, "LINE1.5:apache" . $e . "_tot#EEEE44:Total");
		push(@tmpz, "AREA:apache" . $e . "_idle#4444EE:Idle");
		push(@tmpz, "AREA:apache" . $e . "_busy#44EEEE:Busy");
		push(@tmpz, "LINE2:apache" . $e . "_idle#0000EE");
		push(@tmpz, "LINE2:apache" . $e . "_busy#00EEEE");
		push(@tmpz, "LINE2:apache" . $e . "_tot#EEEE00:Total");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6]",
			"--title=$config->{graphs}->{_apache1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Workers",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:apache" . $e . "_busy=$rrd:apache" . $e . "_busy:AVERAGE",
			"DEF:apache" . $e . "_idle=$rrd:apache" . $e . "_idle:AVERAGE",
			"CDEF:apache" . $e . "_tot=apache" . $e . "_busy,apache" . $e . "_idle,+",
			"CDEF:allvalues=apache" . $e . "_busy,apache" . $e . "_idle,apache" . $e . "_tot,+,+",
			@CDEF,
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n",
			"COMMENT: \\n");
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6]",
				"--title=$config->{graphs}->{_apache1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Workers",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:apache" . $e . "_busy=$rrd:apache" . $e . "_busy:AVERAGE",
				"DEF:apache" . $e . "_idle=$rrd:apache" . $e . "_idle:AVERAGE",
				"CDEF:apache" . $e . "_tot=apache" . $e . "_busy,apache" . $e . "_idle,+",
				"CDEF:allvalues=apache" . $e . "_busy,apache" . $e . "_idle,apache" . $e . "_tot,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:apache" . $e . "_star#FFA500:Starting up");
		push(@tmp, "GPRINT:apache" . $e . "_star:LAST:       Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_star:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_star:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_star:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "AREA:apache" . $e . "_rreq#44EEEE:Reading request");
		push(@tmp, "GPRINT:apache" . $e . "_rreq:LAST:   Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_rreq:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_rreq:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_rreq:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "AREA:apache" . $e . "_srep#4444EE:Sending reply");
		push(@tmp, "GPRINT:apache" . $e . "_srep:LAST:     Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_srep:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_srep:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_srep:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "AREA:apache" . $e . "_dnsl#44EE44:DNS lookup");
		push(@tmp, "GPRINT:apache" . $e . "_dnsl:LAST:        Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_dnsl:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_dnsl:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_dnsl:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "AREA:apache" . $e . "_ccon#EE44EE:Closing conn");
		push(@tmp, "GPRINT:apache" . $e . "_ccon:LAST:      Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_ccon:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_ccon:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_ccon:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "AREA:apache" . $e . "_logg#EEEE44:Logging");
		push(@tmp, "GPRINT:apache" . $e . "_logg:LAST:           Current\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_logg:AVERAGE:   Average\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_logg:MIN:   Min\\: %3.0lf");
		push(@tmp, "GPRINT:apache" . $e . "_logg:MAX:   Max\\: %3.0lf\\n");
		push(@tmp, "LINE1.5:apache" . $e . "_logg#EEEE00");
		push(@tmp, "LINE1.5:apache" . $e . "_ccon#EE00EE");
		push(@tmp, "LINE1.5:apache" . $e . "_dnsl#00EE00");
		push(@tmp, "LINE1.5:apache" . $e . "_srep#0000EE");
		push(@tmp, "LINE1.5:apache" . $e . "_rreq#00EEEE");
		push(@tmp, "LINE1.5:apache" . $e . "_star#FFA500");
		push(@tmpz, "AREA:apache" . $e . "_star#FFA500:Starting up");
		push(@tmpz, "AREA:apache" . $e . "_rreq#44EEEE:Reading request");
		push(@tmpz, "AREA:apache" . $e . "_srep#4444EE:Sending reply");
		push(@tmpz, "AREA:apache" . $e . "_dnsl#44EE44:DNS lookup");
		push(@tmpz, "AREA:apache" . $e . "_ccon#EE44EE:Closing conn");
		push(@tmpz, "AREA:apache" . $e . "_logg#EEEE44:Logging");
		push(@tmpz, "LINE2:apache" . $e . "_logg#EEEE00");
		push(@tmpz, "LINE2:apache" . $e . "_ccon#EE00EE");
		push(@tmpz, "LINE2:apache" . $e . "_dnsl#00EE00");
		push(@tmpz, "LINE2:apache" . $e . "_srep#0000EE");
		push(@tmpz, "LINE2:apache" . $e . "_rreq#00EEEE");
		push(@tmpz, "LINE2:apache" . $e . "_star#FFA500");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 1]",
			"--title=$config->{graphs}->{_apache2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Workers",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:apache" . $e . "_star=$rrd:apache" . $e . "_star:AVERAGE",
			"DEF:apache" . $e . "_rreq=$rrd:apache" . $e . "_rreq:AVERAGE",
			"DEF:apache" . $e . "_srep=$rrd:apache" . $e . "_srep:AVERAGE",
			"DEF:apache" . $e . "_dnsl=$rrd:apache" . $e . "_dnsl:AVERAGE",
			"DEF:apache" . $e . "_ccon=$rrd:apache" . $e . "_ccon:AVERAGE",
			"DEF:apache" . $e . "_logg=$rrd:apache" . $e . "_logg:AVERAGE",
			"CDEF:allvalues=apache" . $e . "_star,apache" . $e . "_rreq,apache" . $e . "_srep,apache" . $e . "_dnsl,apache" . $e . "_ccon,apache" . $e . "_logg,+,+,+,+,+",
			@CDEF,
			"COMMENT: \\n",
			@tmp,
			"COMMENT: \\n");
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 1]",
				"--title=$config->{graphs}->{_apache2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Workers",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:apache" . $e . "_star=$rrd:apache" . $e . "_star:AVERAGE",
				"DEF:apache" . $e . "_rreq=$rrd:apache" . $e . "_rreq:AVERAGE",
				"DEF:apache" . $e . "_srep=$rrd:apache" . $e . "_srep:AVERAGE",
				"DEF:apache" . $e . "_dnsl=$rrd:apache" . $e . "_dnsl:AVERAGE",
				"DEF:apache" . $e . "_ccon=$rrd:apache" . $e . "_ccon:AVERAGE",
				"DEF:apache" . $e . "_logg=$rrd:apache" . $e . "_logg:AVERAGE",
				"CDEF:allvalues=apache" . $e . "_star,apache" . $e . "_rreq,apache" . $e . "_srep,apache" . $e . "_dnsl,apache" . $e . "_ccon,apache" . $e . "_logg,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}
		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:apache" . $e . "_cpu#44AAEE:CPU");
		push(@tmp, "GPRINT:apache" . $e . "_cpu:LAST:                  Current\\: %5.2lf%%\\n");
		push(@tmp, "LINE1:apache" . $e . "_cpu#00EEEE");
		push(@tmpz, "AREA:apache" . $e . "_cpu#44AAEE:CPU");
		push(@tmpz, "LINE1:apache" . $e . "_cpu#00EEEE");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 2]",
			"--title=$config->{graphs}->{_apache3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:apache" . $e . "_cpu=$rrd:apache" . $e . "_cpu:AVERAGE",
			"CDEF:allvalues=apache" . $e . "_cpu",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 2]",
				"--title=$config->{graphs}->{_apache3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Percent",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:apache" . $e . "_cpu=$rrd:apache" . $e . "_cpu:AVERAGE",
				"CDEF:allvalues=apache" . $e . "_cpu",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[3], $limit[3])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:apache" . $e . "_acc#44EE44:Requests");
		push(@tmp, "GPRINT:apache" . $e . "_acc:LAST:             Current\\: %5.2lf\\n");
		push(@tmp, "LINE1:apache" . $e . "_acc#00EE00");
		push(@tmpz, "AREA:apache" . $e . "_acc#44EE44:Requests");
		push(@tmpz, "LINE1:apache" . $e . "_acc#00EE00");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 3]",
			"--title=$config->{graphs}->{_apache4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Requests/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:apache" . $e . "_acc=$rrd:apache" . $e . "_acc:AVERAGE",
			"CDEF:allvalues=apache" . $e . "_acc",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 3]",
				"--title=$config->{graphs}->{_apache4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Requests/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:apache" . $e . "_acc=$rrd:apache" . $e . "_acc:AVERAGE",
				"CDEF:allvalues=apache" . $e . "_acc",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 3]: $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[4], $limit[4])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "LINE2:apache" . $e . "_wcon#FFA500:Waiting for conn");
		push(@tmp, "GPRINT:apache" . $e . "_wcon:LAST:     Current\\: %3.0lf\\n");
		push(@tmp, "LINE2:apache" . $e . "_keep#44EEEE:Keepalive");
		push(@tmp, "GPRINT:apache" . $e . "_keep:LAST:            Current\\: %3.0lf\\n");
		push(@tmp, "LINE2:apache" . $e . "_idlc#44EE44:Idle cleanup");
		push(@tmp, "GPRINT:apache" . $e . "_idlc:LAST:         Current\\: %3.0lf\\n");
		push(@tmp, "LINE2:apache" . $e . "_gfin#4444EE:Gracefully fin");
		push(@tmp, "GPRINT:apache" . $e . "_gfin:LAST:       Current\\: %3.0lf\\n");
		push(@tmpz, "LINE2:apache" . $e . "_wcon#FFA500:Waiting for conn");
		push(@tmpz, "LINE2:apache" . $e . "_keep#44EEEE:Keepalive");
		push(@tmpz, "LINE2:apache" . $e . "_idlc#44EE44:Idle cleanup");
		push(@tmpz, "LINE2:apache" . $e . "_gfin#4444EE:Gracefully fin");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 4]",
			"--title=$config->{graphs}->{_apache5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Workers",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:apache" . $e . "_wcon=$rrd:apache" . $e . "_wcon:AVERAGE",
			"DEF:apache" . $e . "_keep=$rrd:apache" . $e . "_keep:AVERAGE",
			"DEF:apache" . $e . "_idlc=$rrd:apache" . $e . "_idlc:AVERAGE",
			"DEF:apache" . $e . "_gfin=$rrd:apache" . $e . "_gfin:AVERAGE",
			"CDEF:allvalues=apache" . $e . "_wcon,apache" . $e . "_keep,apache" . $e . "_idlc,apache" . $e . "_gfin,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 4]",
				"--title=$config->{graphs}->{_apache5}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Workers",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:apache" . $e . "_wcon=$rrd:apache" . $e . "_wcon:AVERAGE",
				"DEF:apache" . $e . "_keep=$rrd:apache" . $e . "_keep:AVERAGE",
				"DEF:apache" . $e . "_idlc=$rrd:apache" . $e . "_idlc:AVERAGE",
				"DEF:apache" . $e . "_gfin=$rrd:apache" . $e . "_gfin:AVERAGE",
				"CDEF:allvalues=apache" . $e . "_wcon,apache" . $e . "_keep,apache" . $e . "_idlc,apache" . $e . "_gfin,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 4]: $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 4] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 4] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[5], $limit[5])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:apache" . $e . "_slot#EE44EE:Open slots");
		push(@tmp, "GPRINT:apache" . $e . "_slot:LAST:           Current\\: %4.0lf\\n");
		push(@tmp, "LINE1:apache" . $e . "_slot#963C74");
		push(@tmpz, "AREA:apache" . $e . "_slot#EE44EE:Open slots");
		push(@tmpz, "LINE1:apache" . $e . "_slot#963C74");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 5]",
			"--title=$config->{graphs}->{_apache6}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Slots",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:apache" . $e . "_slot=$rrd:apache" . $e . "_slot:AVERAGE",
			"CDEF:allvalues=apache" . $e . "_slot",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 5]",
				"--title=$config->{graphs}->{_apache6}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Slots",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:apache" . $e . "_slot=$rrd:apache" . $e . "_slot:AVERAGE",
				"CDEF:allvalues=apache" . $e . "_slot",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 5]: $err\n") if $err;
		}
		$e2 = $e + 6;
		if($title || ($silent =~ /imagetag/ && $graph =~ /apache$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 5] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 5] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");

			push(@output, "    <tr>\n");
			push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
			push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
			push(@output, "       <font size='-1'>\n");
			push(@output, "        <b>&nbsp;&nbsp;<a href='" . $url ."' style='color: " . $colors->{title_fg_color} . "'>$url</a></b>\n");
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
