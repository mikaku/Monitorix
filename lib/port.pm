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

package port;

use strict;
use warnings;
use Monitorix;
use RRDs;
use POSIX qw(strftime setlocale LC_ALL);
use Exporter 'import';
our @EXPORT = qw(port_init port_update port_cgi);

# Force a standard locale
$ENV{LANG} = "";
setlocale(LC_ALL, "C");

sub port_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $port = $config->{port};
	my $cmd;

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	my $table = $config->{ip_default_table};

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
		if(scalar(@ds) / 4 != $port->{max}) {
			logger("$myself: Detected size mismatch between 'max = $port->{max}' and $rrd (" . scalar(@ds) / 4 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < $port->{max}; $n++) {
			push(@tmp, "DS:port" . $n . "_i_in:GAUGE:120:0:U");
			push(@tmp, "DS:port" . $n . "_i_out:GAUGE:120:0:U");
			push(@tmp, "DS:port" . $n . "_o_in:GAUGE:120:0:U");
			push(@tmp, "DS:port" . $n . "_o_out:GAUGE:120:0:U");
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

	if(scalar(my @pls = split(',', $port->{list})) > $port->{max}) {
		logger("$myself: WARNING: 'max' option indicates less ports than really defined in 'list'.");
	}

	if(lc($config->{use_external_firewall} || "") eq "n") {
		if($config->{os} eq "Linux") {
			my $num;
			my @line;

			# set the iptables rules for each defined port
			my @pl = split(',', $port->{list});
			for($n = 0; $n < min($port->{max}, scalar(@pl)); $n++) {
				$pl[$n] = trim($pl[$n]);
				my ($np) = ($pl[$n] =~ m/^(\d+).*?/);

				if(!$port->{desc}->{$pl[$n]}) {
					logger("$myself: port number '$np' listed but not defined.");
					next;
				}
				# support for port range (i.e: 49152:65534)
				if(index($pl[$n], ":") != -1) {
					($np) = ($pl[$n] =~ m/^(\d+:\d+).*?/);
				}
				if($pl[$n] && $np) {
					my $p = trim(lc((split(',', $port->{desc}->{$pl[$n]}))[1])) || "";
					if(! grep {$_ eq $p} ("tcp", "udp", "tcp6", "udp6")) {
						logger("$myself: Invalid protocol name '$p' in port '$pl[$n]'.");
						next;
					}
					$cmd = "iptables" . $config->{iptables_wait_lock};
					if(grep {$_ eq $p} ("tcp6", "udp6")) {
						if(lc($config->{ipv6_disabled} || "") eq "y") {
							logger("$myself: IPv6 is explicitly disabled, you shouldn't want to monitor 'tcp6' or 'udp6' protocols.");
							next;
						}
						$cmd = "ip6tables" . $config->{iptables_wait_lock};
						$p =~ s/6//;
					}
					my $conn = trim(lc((split(',', $port->{desc}->{$pl[$n]}))[2]));
					if($conn eq "in" || $conn eq "in/out") {
						system("$cmd -t $table -N monitorix_IN_$n 2>/dev/null");
						system("$cmd -t $table -I INPUT -p $p --sport 1024:65535 --dport $np -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j monitorix_IN_$n -c 0 0");
						system("$cmd -t $table -I OUTPUT -p $p --sport $np --dport 1024:65535 -m conntrack --ctstate ESTABLISHED,RELATED -j monitorix_IN_$n -c 0 0");
					}
					if($conn eq "out" || $conn eq "in/out") {
						system("$cmd -t $table -N monitorix_OUT_$n 2>/dev/null");
						system("$cmd -t $table -I INPUT -p $p --sport $np --dport 1024:65535 -m conntrack --ctstate ESTABLISHED,RELATED -j monitorix_OUT_$n -c 0 0");
						system("$cmd -t $table -I OUTPUT -p $p --sport 1024:65535 --dport $np -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j monitorix_OUT_$n -c 0 0");
					}
					if($conn ne "in" && $conn ne "out" && $conn ne "in/out") {
						logger("$myself: Invalid connection type '$conn'; must be 'in', 'out' or 'in/out'.");
					}
				}
			}
		}
	}
	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		# set the ipfw rules for each defined port
		my @pl = split(',', $port->{list});
		for($n = 0; $n < min($port->{max}, scalar(@pl)); $n++) {
			$pl[$n] = trim($pl[$n]);
			my ($np) = ($pl[$n] =~ m/^(\d+).*?/);
			if($pl[$n] && $np) {
				my $p = lc((split(',', $port->{desc}->{$pl[$n]}))[1]) || "all";
				# in/out not supported yet  FIXME
				$p =~ s/6//;	# tcp6, udp6, ... not supported
				system("ipfw -q add $port->{rule} count $p from me $np to any");
				system("ipfw -q add $port->{rule} count $p from any to me $np");
			}
		}
	}

	$config->{port_hist_in} = ();
	$config->{port_hist_out} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub port_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $port = $config->{port};

	my @i_in;
	my @i_out;
	my @o_in;
	my @o_out;
	my $table = $config->{ip_default_table};

	my $n;
	my $rrdata = "N";

	if($config->{os} eq "Linux") {
		my @data;
		my $l;
		my $cmd;
		my $cmd6;

		$cmd = "iptables" . $config->{iptables_wait_lock};
		$cmd6 = "ip6tables" . $config->{iptables_wait_lock};
		open(IN, "$cmd -t $table -nxvL INPUT 2>/dev/null |");
		@data = <IN>;
		close(IN);
		if(lc($config->{ipv6_disabled} || "") ne "y") {
			open(IN, "$cmd6 -t $table -nxvL INPUT 2>/dev/null |");
			push(@data, <IN>);
			close(IN);
		}
		for($l = 0; $l < scalar(@data); $l++) {
			for($n = 0; $n < $port->{max}; $n++) {
				$i_in[$n] = 0 unless $i_in[$n];
				$o_in[$n] = 0 unless $o_in[$n];
				if($data[$l] =~ / monitorix_IN_$n /) {
					my (undef, $bytes) = split(' ', $data[$l]);
					chomp($bytes);
					$i_in[$n] = $bytes - ($config->{port_hist_i_in}[$n] || 0);
					$i_in[$n] = 0 unless $i_in[$n] != $bytes;
					$config->{port_hist_i_in}[$n] = $bytes;
					$i_in[$n] /= 60;
				}
				if($data[$l] =~ / monitorix_OUT_$n /) {
					my (undef, $bytes) = split(' ', $data[$l]);
					chomp($bytes);
					$o_in[$n] = $bytes - ($config->{port_hist_o_in}[$n] || 0);
					$o_in[$n] = 0 unless $o_in[$n] != $bytes;
					$config->{port_hist_o_in}[$n] = $bytes;
					$o_in[$n] /= 60;
				}
			}
		}
		open(IN, "$cmd -t $table -nxvL OUTPUT 2>/dev/null |");
		@data = <IN>;
		close(IN);
		if(lc($config->{ipv6_disabled} || "") ne "y") {
			open(IN, "$cmd6 -t $table -nxvL OUTPUT 2>/dev/null |");
			push(@data, <IN>);
			close(IN);
		}
		for($l = 0; $l < scalar(@data); $l++) {
			for($n = 0; $n < $port->{max}; $n++) {
				$o_out[$n] = 0 unless $o_out[$n];
				$i_out[$n] = 0 unless $i_out[$n];
				if($data[$l] =~ / monitorix_OUT_$n /) {
					my (undef, $bytes) = split(' ', $data[$l]);
					chomp($bytes);
					$o_out[$n] = $bytes - ($config->{port_hist_o_out}[$n] || 0);
					$o_out[$n] = 0 unless $o_out[$n] != $bytes;
					$config->{port_hist_o_out}[$n] = $bytes;
					$o_out[$n] /= 60;
				}
				if($data[$l] =~ / monitorix_IN_$n /) {
					my (undef, $bytes) = split(' ', $data[$l]);
					chomp($bytes);
					$i_out[$n] = $bytes - ($config->{port_hist_i_out}[$n] || 0);
					$i_out[$n] = 0 unless $i_out[$n] != $bytes;
					$config->{port_hist_i_out}[$n] = $bytes;
					$i_out[$n] /= 60;
				}
			}
		}
	}
	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		my @pl = split(',', $port->{list});
		open(IN, "ipfw show $port->{rule} 2>/dev/null |");
		while(<IN>) {
			for($n = 0; $n < $port->{max}; $n++) {
				$i_in[$n] = 0 unless $i_in[$n];
				$o_in[$n] = 0 unless $o_in[$n];
				$pl[$n] = trim($pl[$n]);
				my ($np) = ($pl[$n] =~ m/^(\d+).*?/);
				if(/ from any to me dst-port $np$/) {
					my (undef, undef, $bytes) = split(' ', $_);
					chomp($bytes);
					$i_in[$n] = $bytes - ($config->{port_hist_i_in}[$n] || 0);
					$i_in[$n] = 0 unless $i_in[$n] != $bytes;
					$config->{port_hist_i_in}[$n] = $bytes;
					$i_in[$n] /= 60;
				}
				$o_out[$n] = 0 unless $o_out[$n];
				$i_out[$n] = 0 unless $i_out[$n];
				if(/ from me $np to any$/) {
					my (undef, undef, $bytes) = split(' ', $_);
					chomp($bytes);
					$i_out[$n] = $bytes - ($config->{port_hist_i_out}[$n] || 0);
					$i_out[$n] = 0 unless $i_out[$n] != $bytes;
					$config->{port_hist_i_out}[$n] = $bytes;
					$i_out[$n] /= 60;
				}
			}
		}
		close(IN);
	}

	for($n = 0; $n < $port->{max}; $n++) {
		$rrdata .= ":$i_in[$n]:$i_out[$n]:$o_in[$n]:$o_out[$n]";
	}
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub port_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $port = $config->{port};
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
	my @warning;
	my @IMG;
	my @IMGz;
	my $name;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $T = "B";
	my $vlabel = "bytes/s";
	my $n;
	my $n2;
	my $n3;
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

	if(lc($config->{netstats_in_bps}) eq "y") {
		$T = "b";
		$vlabel = "bits/s";
	}


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
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		my $max = min($port->{max}, scalar(my @pl = split(',', $port->{list})));
		for($n = 0; $n < $max; $n++) {
			$pl[$n] = trim($pl[$n]);
			my $pn = trim((split(',', $port->{desc}->{$pl[$n]}))[0]);
			my $pc = trim((split(',', $port->{desc}->{$pl[$n]}))[2]);
			foreach(split('/', $pc)) {
				push(@output, sprintf("   %-5s %10s", $pl[$n], uc(trim($_)) . "-" . $pn));
				$line1 .= "    K$T/s_I   K$T/s_O";
				$line2 .= "-------------------";
			}
		}
		push(@output, "\n");
		push(@output, "Time$line1\n");
		push(@output, "----$line2 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			for($n2 = 0; $n2 < $max; $n2++) {
				$pl[$n2] = trim($pl[$n2]);
				my $pc = trim((split(',', $port->{desc}->{$pl[$n2]}))[2]);
				$from = $n2 * 4;
				$to = $from + 3;
				my ($i_in, $i_out, $o_in, $o_out) = @$line[$from..$to];
				my $k_i_in = ($i_in || 0) / 1024;
				my $k_i_out = ($i_out || 0) / 1024;
				my $k_o_in = ($o_in || 0) / 1024;
				my $k_o_out = ($o_out || 0) / 1024;

				if(lc($config->{netstats_in_bps}) eq "y") {
					$k_i_in *= 8;
					$k_i_out *= 8;
					$k_o_in *= 8;
					$k_o_out *= 8;
				}
				foreach(split('/', $pc)) {
					if(lc($_) eq "in") {
						@row = ($k_i_in, $k_i_out);
						push(@output, sprintf("   %6d   %6d ", @row));
					}
					if(lc($_) eq "out") {
						@row = ($k_o_in, $k_o_out);
						push(@output, sprintf("   %6d   %6d ", @row));
					}
				}
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

	my $max = min($port->{max}, scalar(my @pl = split(',', $port->{list})));
	for($n = 0; $n < $max; $n++) {
		$pl[$n] = trim($pl[$n]);
		next if !$port->{desc}->{$pl[$n]};

		my $pc = trim((split(',', $port->{desc}->{$pl[$n]}))[2]);
		foreach my $conn (split('/', $pc)) {
			$str = $u . $package . $n . substr($conn, 0 ,1) . "." . $tf->{when} . ".$imgfmt_lc";
			push(@IMG, $str);
			unlink("$IMG_DIR" . $str);
			if(lc($config->{enable_zoom}) eq "y") {
				$str = $u . $package . $n . substr($conn, 0 ,1) . "z." . $tf->{when} . ".$imgfmt_lc";
				push(@IMGz, $str);
				unlink("$IMG_DIR" . $str);
			}
		}
	}

	$n = $n3 = 0;
	$n2 = 1;
	while($n < $max) {
		next unless $pl[$n];

		# continue if port was listed but not defined
		if(!$port->{desc}->{$pl[$n]}) {
			$n++;
			next;
		}

		if($title) {
			if($n == 0) {
				push(@output, main::graph_header($title, $port->{graphs_per_row}));
			}
			if($n2 == 1) {
				push(@output, "    <tr>\n");
			}
		}

		my $pc = trim((split(',', $port->{desc}->{$pl[$n]}))[2]);
		foreach my $pcon (split('/', $pc)) {
			if($title) {
				push(@output, "    <td>\n");
			}
			my $pnum;
			$pl[$n] = trim($pl[$n]);
			my $num = ($pl[$n] =~ m/^(\d+).*?/)[0];	# strips any suffix from port number
			my $pn = trim((split(',', $port->{desc}->{$pl[$n]}))[0]);
			my $pp = trim((split(',', $port->{desc}->{$pl[$n]}))[1]);
			$pp =~ s/6//;
			my $prig = trim((split(',', $port->{desc}->{$pl[$n]}))[3]);
			my $plim = trim((split(',', $port->{desc}->{$pl[$n]}))[4]);
			my $plis = trim((split(',', $port->{desc}->{$pl[$n]}))[5]);
			@riglim = @{setup_riglim($prig, $plim)};

			# check if the network port is still listening
			undef(@warning);
			if(uc($plis || "") eq "L") {
				if($config->{os} eq "Linux") {
					my $cmd = $port->{cmd} || "";
					if(!$cmd || $cmd eq "ss") {
						open(IN, "ss -nl --$pp |");
						while(<IN>) {
							(undef, undef, undef, $pnum) = split(' ', $_);
							chomp($pnum);
							$pnum =~ s/.*://;
							if($pnum eq $num) {
								last;
							}
						}
						close(IN);
					}
					if($cmd eq "netstat") {
						open(IN, "netstat -nl --$pp |");
						while(<IN>) {
							(undef, undef, undef, $pnum) = split(' ', $_);
							chomp($pnum);
							$pnum =~ s/.*://;
							if($pnum eq $num) {
								last;
							}
						}
						close(IN);
					}
				}
				if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD")) {
					open(IN, "netstat -anl -p $pp |");
					while(<IN>) {
					 	my $stat;
						(undef, undef, undef, $pnum, undef, $stat) = split(' ', $_);
						chomp($stat);
						if($stat eq "LISTEN") {
							chomp($pnum);
							($pnum) = ($pnum =~ m/^.*?(\.\d+$)/);
							$pnum =~ s/\.//;
							if($pnum eq $num) {
								last;
							}
						}
					}
					close(IN);
				}
				if(lc($pcon) ne "out" && $pnum ne $num) {
					push(@warning, $colors->{warning_color});
				}
			}

			$name = substr(uc($pcon) . "-" . $pn, 0, 15);
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			if(lc($pcon) eq "in") {
				push(@tmp, "AREA:B_i_in#44EE44:Input");
				push(@tmp, "AREA:B_i_out#4444EE:Output");
				push(@tmp, "AREA:B_i_out#4444EE:");
				push(@tmp, "AREA:B_i_in#44EE44:");
				push(@tmp, "LINE1:B_i_out#0000EE");
				push(@tmp, "LINE1:B_i_in#00EE00");
				push(@tmpz, "AREA:B_i_in#44EE44:Input");
				push(@tmpz, "AREA:B_i_out#4444EE:Output");
				push(@tmpz, "AREA:B_i_out#4444EE:");
				push(@tmpz, "AREA:B_i_in#44EE44:");
				push(@tmpz, "LINE1:B_i_out#0000EE");
				push(@tmpz, "LINE1:B_i_in#00EE00");
				if(lc($config->{netstats_in_bps}) eq "y") {
					push(@CDEF, "CDEF:B_i_in=i_in,8,*");
					if(lc($config->{netstats_mode} || "") eq "separated") {
						push(@CDEF, "CDEF:B_i_out=i_out,8,*,-1,*");
					} else {
						push(@CDEF, "CDEF:B_i_out=i_out,8,*");
					}
				} else {
					push(@CDEF, "CDEF:B_i_in=i_in");
					if(lc($config->{netstats_mode} || "") eq "separated") {
						push(@CDEF, "CDEF:B_i_out=i_out,-1,*");
					} else {
						push(@CDEF, "CDEF:B_i_out=i_out");
					}
				}
			}
			if(lc($pcon) eq "out") {
				push(@tmp, "AREA:B_o_in#44EE44:Input");
				push(@tmp, "AREA:B_o_out#4444EE:Output");
				push(@tmp, "AREA:B_o_out#4444EE:");
				push(@tmp, "AREA:B_o_in#44EE44:");
				push(@tmp, "LINE1:B_o_out#0000EE");
				push(@tmp, "LINE1:B_o_in#00EE00");
				push(@tmpz, "AREA:B_o_in#44EE44:Input");
				push(@tmpz, "AREA:B_o_out#4444EE:Output");
				push(@tmpz, "AREA:B_o_out#4444EE:");
				push(@tmpz, "AREA:B_o_in#44EE44:");
				push(@tmpz, "LINE1:B_o_out#0000EE");
				push(@tmpz, "LINE1:B_o_in#00EE00");
				if(lc($config->{netstats_in_bps}) eq "y") {
					push(@CDEF, "CDEF:B_o_in=o_in,8,*");
					if(lc($config->{netstats_mode} || "") eq "separated") {
						push(@CDEF, "CDEF:B_o_out=o_out,8,*,-1,*");
					} else {
						push(@CDEF, "CDEF:B_o_out=o_out,8,*");
					}
				} else {
					push(@CDEF, "CDEF:B_o_in=o_in");
					if(lc($config->{netstats_mode} || "") eq "separated") {
						push(@CDEF, "CDEF:B_o_out=o_out,-1,*");
					} else {
						push(@CDEF, "CDEF:B_o_out=o_out");
					}
				}
			}
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			$port->{size} = "mini" if !defined($port->{size});
			($width, $height) = split('x', $config->{graph_size}->{$port->{size}});
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$n3]",
				"--title=$name traffic  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=$vlabel",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				@warning,
				"DEF:i_in=$rrd:port" . $n . "_i_in:AVERAGE",
				"DEF:i_out=$rrd:port" . $n . "_i_out:AVERAGE",
				"DEF:o_in=$rrd:port" . $n . "_o_in:AVERAGE",
				"DEF:o_out=$rrd:port" . $n . "_o_out:AVERAGE",
				"CDEF:allvalues=i_in,i_out,o_in,o_out,+,+,+",
				@CDEF,
				@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$n3]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$n3]",
					"--title=$name traffic  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=$vlabel",
					"--width=$width",
					"--height=$height",
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$cgi->{version12_small}},
					@{$colors->{graph_colors}},
					@warning,
					"DEF:i_in=$rrd:port" . $n . "_i_in:AVERAGE",
					"DEF:i_out=$rrd:port" . $n . "_i_out:AVERAGE",
					"DEF:o_in=$rrd:port" . $n . "_o_in:AVERAGE",
					"DEF:o_out=$rrd:port" . $n . "_o_out:AVERAGE",
					"CDEF:allvalues=i_in,i_out,o_in,o_out,+,+,+",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$n3]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /port$n3/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$n3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n3] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$n3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n3] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n3] . "'>\n");
				}
			}
			if($title) {
				push(@output, "    </td>\n");
			}

			if($n2 < $port->{graphs_per_row} && $n2 < $max) {
				$n2++;
			} else {
				if($title) {
					push(@output, "    </tr>\n");
				}
				$n2 = 1;
			}
			$n3++;
		}
		$n++;
	}
	if($title) {
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
