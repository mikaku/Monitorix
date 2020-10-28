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

package Monitorix;

use strict;
use warnings;
use Exporter 'import';
use POSIX qw(setuid setgid setsid getgid getuid);
use Socket;
our @EXPORT = qw(logger trim min max celsius_to uptime2str setup_riglim httpd_setup get_nvidia_data get_ati_data flush_accounting_rules);

sub logger {
	my ($msg) = @_;

	$msg = localtime() . " - " . $msg;
	print("$msg\n");
}

sub trim {
	my $str = shift;

	if($str) {
		$str =~ s/^\s+//;
		$str =~ s/\s+$//;
		return $str;
	}
}

sub min {
	my ($min, @args) = @_;
	foreach(@args) {
		$min = $_ if $_ < $min;
	}
	return $min;
}

sub max {
	my ($max, @args) = @_;
	foreach(@args) {
		$max = $_ if $_ > $max;
	}
	return $max;
}

sub celsius_to {
	my ($config, $celsius) = @_;

	$celsius = $celsius || 0;
	if(lc($config->{temperature_scale}) eq "f") {
		return ($celsius * (9 / 5)) + 32;
	}
	return $celsius;
}

sub uptime2str {
	my $uptime = shift || 0;
	my $str;

	my $d = int($uptime / (60 * 60 * 24));
	my $h = int($uptime / (60 * 60)) % 24;
	my $m = int($uptime / 60) % 60;

	my $d_string = $d ? sprintf("%d days,", $d) : "";
	my $h_string = $h ? sprintf("%d", $h) : "";
	my $m_string = $h ? sprintf("%sh %dm", $h, $m) : sprintf("%d min", $m);

	return "$d_string $m_string";
}

sub setup_riglim {
	my $myself = (caller(0))[3];
	my ($rigid, $limit) = @_;
	my @riglim;

	my ($upper, $lower) = split(':', trim($limit) || "0:0");
	if(trim($rigid || 0) eq 0) {
		push(@riglim, "--lower-limit=$lower") if defined($lower);
	} else {
		push(@riglim, "--upper-limit=" . ($upper || 0));
		push(@riglim, "--lower-limit=" . ($lower || 0));
		push(@riglim, "--rigid") if trim($rigid || 0) eq 2;
	}
	return \@riglim;
}

sub httpd_setup {
	my $myself = (caller(0))[3];
	my ($config, $reguser) = @_;
	my $pid;
	my ($uid, $gid);

	my $host = $config->{httpd_builtin}->{host};
	my $port = $config->{httpd_builtin}->{port};

	if($reguser) {
		(undef, undef, $uid, $gid ) = getpwuid($<);
	} else {
		(undef, undef, $uid) = getpwnam($config->{httpd_builtin}->{user});
		(undef, undef, $gid) = getgrnam($config->{httpd_builtin}->{group});
	}

	if(!defined($uid)) {
		logger("$myself: ERROR: invalid user defined.");
		return;
	}
	if(!defined($gid)) {
		logger("$myself: ERROR: invalid group defined.");
		return;
	}
	if(!defined($port)) {
		logger("$myself: ERROR: invalid port defined.");
		return;
	}

	if($pid = fork()) {
		$config->{httpd_pid} = $pid;
		return;	# parent returns
	}

	# create the HTTPd logfile
	if($config->{log_file}) {
		open(OUT, ">> " . $config->{httpd_builtin}->{log_file});
		close(OUT);
		chown($uid, $gid, $config->{httpd_builtin}->{log_file});
		chmod(0600, $config->{httpd_builtin}->{log_file});
	}

	setgid($gid);
	if(getgid() != $gid) {
		logger("WARNING: $myself: unable to setgid($gid).");
		exit(1);
	}
	setuid($uid);
	if(getuid() != $uid) {
		logger("WARNING: $myself: unable to setuid($uid).");
		exit(1);
	}
	setsid();
	$SIG{$_} = 'DEFAULT' for keys %SIG;		# reset all sighandlers
	$0 = "monitorix-httpd listening on $port";	# change process' name
	chdir($config->{base_dir});

	# check if 'htpasswd' file does exists and it's accessible
	if(lc($config->{httpd_builtin}->{auth}->{enabled}) eq "y") {
		if(! -r ($config->{httpd_builtin}->{auth}->{htpasswd} || "")) {
			logger("$myself: '$config->{httpd_builtin}->{auth}->{htpasswd}' $!");
		}
	} else {
		if(!grep {$_ eq $config->{httpd_builtin}->{host}} ("localhost", "127.0.0.1")) {
			logger("WARNING: the HTTP built-in server has authentication disabled.");
		}
	}

	my $server = HTTPServer->new();
	$server->host($host);
	$server->port($port);
	$server->run();
	exit(0);
}

sub get_nvidia_data {
	my $myself = (caller(0))[3];
	my ($gpu) = @_;
	my $total = 0;
	my $used = 0;
	my $mem = 0;
	my $cpu = 0;
	my $temp = 0;
	my $check_mem = 0;
	my $check_cpu = 0;
	my $check_temp = 0;
	my $l;

	my @data = ();
	if(open(IN, "nvidia-smi -q -i $gpu -d MEMORY,UTILIZATION,TEMPERATURE |")) {
		@data = <IN>;
		close(IN);
	} else {
		logger("$myself: ERROR: 'nvidia-smi' command is not installed.");
	}
	for($l = 0; $l < scalar(@data); $l++) {
		if($data[$l] =~ /Memory Usage/) {
			if($data[$l] !~ /BAR1 Memory Usage/) {
				$check_mem = 1;
				next;
			}
		}
		if($check_mem) {	
			if($data[$l] =~ /Total/) {
				my (undef, $tmp) = split(':', $data[$l]);
				if($tmp eq "\n") {
					$l++;
					$tmp = $data[$l];
				}
				my ($value, undef) = split(' ', $tmp);
				$value =~ s/[-]/./;
				$value =~ s/[^0-9.]//g;
				if(int($value) > 0) {
					$total = int($value);
				}
			}
			if($data[$l] =~ /Used/) {
				my (undef, $tmp) = split(':', $data[$l]);
				if($tmp eq "\n") {
					$l++;
					$tmp = $data[$l];
				}
				my ($value, undef) = split(' ', $tmp);
				$value =~ s/[-]/./;
				$value =~ s/[^0-9.]//g;
				if(int($value) > 0) {
					$used = int($value);
				}
				$check_mem = 0;
			}
		}

		if($data[$l] =~ /Utilization/) {
			$check_cpu = 1;
			next;
		}
		if($check_cpu) {	
			if($data[$l] =~ /Gpu/) {
				my (undef, $tmp) = split(':', $data[$l]);
				if($tmp eq "\n") {
					$l++;
					$tmp = $data[$l];
				}
				my ($value, undef) = split(' ', $tmp);
				$value =~ s/[-]/./;
				$value =~ s/[^0-9.]//g;
				$value ||= 0;	# zero if not numeric
				if(int($value) > 0) {
					$cpu = int($value);
				}
			}
			# not used
			if($data[$l] =~ /Memory/) {
				my (undef, $tmp) = split(':', $data[$l]);
				if($tmp eq "\n") {
					$l++;
					$tmp = $data[$l];
				}
				my ($value, undef) = split(' ', $tmp);
				$value =~ s/[-]/./;
				$value =~ s/[^0-9.]//g;
				$value ||= 0;	# zero if not numeric
				if(int($value) > 0) {
					$mem = int($value);
				}
			}
			$check_cpu = 0;
		}

		if($data[$l] =~ /Temperature/) {
			$check_temp = 1;
			next;
		}
		if($check_temp) {	
			if($data[$l] =~ /Gpu.*?(?:Current Temp)?/i) {
				my (undef, $tmp) = split(':', $data[$l]);
				if($tmp eq "\n") {
					$l++;
					$tmp = $data[$l];
				}
				my ($value, undef) = split(' ', $tmp);
				$value =~ s/[-]/./;
				$value =~ s/[^0-9.]//g;
				if(int($value) > 0) {
					$temp = int($value);
				}
			}
			$check_temp = 0;
		}
	}

	# NVIDIA driver v285.+ not supported (needs new output parsing).
	# This is to avoid a divide by zero message.
	if($total) {
		$mem = ($used * 100) / $total;
	} else {
		$mem = $used = $total = 0;
	}
	return join(" ", $mem, $cpu, $temp);
}

sub get_ati_data {
	my $myself = (caller(0))[3];
	my ($gpu) = @_;
	my $temp = 0;

	my @data = ();
	if(open(IN, "aticonfig --odgt --adapter=$gpu |")) {
		@data = <IN>;
		close(IN);
	} else {
		logger("$myself: ERROR: 'aticonfig' command is not installed.");
	}
	foreach(@data) {
		if(/Sensor \d: Temperature - (\d+\.\d+) C/) {
			$temp = $1;
		}
	}
	return $temp || 0;
}

# flushes out all Monitorix iptables/ipfw rules
sub flush_accounting_rules {
	my ($config, $debug) = @_;
	my $table = $config->{ip_default_table};

	if($config->{os} eq "Linux") {
		my $num = 0;
		my $num6 = 0;
		my $cmd = "iptables" . $config->{iptables_wait_lock};
		my $cmd6 = "ip6tables" . $config->{iptables_wait_lock};

		logger("Flushing out iptables rules.") if $debug;
		{
			my @names;

			# IPv4
			if(open(IN, "$cmd -t $table -nxvL INPUT --line-numbers |")) {
				my @rules;
				while(<IN>) {
					my ($rule, undef, undef, $name) = split(' ', $_);
					if(lc($config->{use_external_firewall} || "") eq "n") {
						if($name =~ /monitorix_IN/ || /monitorix_OUT/ || /monitorix_nginx_IN/) {
							push(@rules, $rule);
							push(@names, $name);
						}
					}
				}
				close(IN);
				@rules = reverse(@rules);
				foreach(@rules) {
					system("$cmd -t $table -D INPUT $_");
					$num++;
				}
			}
			if(open(IN, "$cmd -t $table -nxvL OUTPUT --line-numbers |")) {
				my @rules;
				while(<IN>) {
					my ($rule, undef, undef, $name) = split(' ', $_);
					if(lc($config->{use_external_firewall} || "") eq "n") {
						if($name =~ /monitorix_IN/ || /monitorix_OUT/ || /monitorix_nginx_IN/) {
							push(@rules, $rule);
						}
					}
				}
				close(IN);
				@rules = reverse(@rules);
				foreach(@rules) {
					system("$cmd -t $table -D OUTPUT $_");
					$num++;
				}
			}
			foreach(@names) {
				system("$cmd -t $table -X $_");
			}

			# IPv6
			if(lc($config->{ipv6_disabled} || "") ne "y") {
				undef(@names);
				if(open(IN, "$cmd6 -t $table -nxvL INPUT --line-numbers |")) {
					my @rules;
					while(<IN>) {
						my ($rule, undef, undef, $name) = split(' ', $_);
						if(lc($config->{use_external_firewall} || "") eq "n") {
							if($name =~ /monitorix_IN/ || /monitorix_OUT/ || /monitorix_nginx_IN/) {
								push(@rules, $rule);
								push(@names, $name);
							}
						}
					}
					close(IN);
					@rules = reverse(@rules);
					foreach(@rules) {
						system("$cmd6 -t $table -D INPUT $_");
						$num6++;
					}
				}
				if(open(IN, "$cmd6 -t $table -nxvL OUTPUT --line-numbers |")) {
					my @rules;
					while(<IN>) {
						my ($rule, undef, undef, $name) = split(' ', $_);
						if(lc($config->{use_external_firewall} || "") eq "n") {
							if($name =~ /monitorix_IN/ || /monitorix_OUT/ || /monitorix_nginx_IN/) {
								push(@rules, $rule);
							}
						}
					}
					close(IN);
					@rules = reverse(@rules);
					foreach(@rules) {
						system("$cmd6 -t $table -D OUTPUT $_");
						$num6++;
					}
				}
				foreach(@names) {
					system("$cmd6 -t $table -X $_");
				}
			}
		}
		if(open(IN, "$cmd -t $table -nxvL FORWARD --line-numbers |")) {
			my @rules;
			my @names;
			while(<IN>) {
				my ($rule, undef, undef, $name) = split(' ', $_);
				if($name =~ /monitorix_daily_/ || /monitorix_total_/) {
					push(@rules, $rule);
					push(@names, $name);
				}
			}
			close(IN);
			@rules = reverse(@rules);
			foreach(@rules) {
				system("$cmd -t $table -D FORWARD $_");
				$num++;
			}
			foreach(@names) {
				system("$cmd -t $table -F $_");
				system("$cmd -t $table -X $_");
			}
		}
		if(lc($config->{ipv6_disabled} || "") ne "y") {
			if(open(IN, "$cmd6 -t $table -nxvL FORWARD --line-numbers |")) {
				my @rules;
				my @names;
				while(<IN>) {
					my ($rule, undef, undef, $name) = split(' ', $_);
					if($name =~ /monitorix_daily_/ || /monitorix_total_/) {
						push(@rules, $rule);
						push(@names, $name);
					}
				}
				close(IN);
				@rules = reverse(@rules);
				foreach(@rules) {
					system("$cmd6 -t $table -D FORWARD $_");
					$num6++;
				}
				foreach(@names) {
					system("$cmd6 -t $table -F $_");
					system("$cmd6 -t $table -X $_");
				}
			}
		}
		logger("$num iptables rules have been flushed.") if $debug;
		if(lc($config->{ipv6_disabled} || "") ne "y") {
			logger("$num6 ip6tables rules have been flushed.") if $debug;
		}
	}
	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		logger("Flushing out ipfw rules.") if $debug;
		system("ipfw delete $config->{port}->{rule} 2>/dev/null");
		system("ipfw delete $config->{nginx}->{rule} 2>/dev/null");
	}
}

1;
