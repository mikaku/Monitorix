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

package serv;

use strict;
use warnings;
use Monitorix;
use RRDs;
use POSIX qw(strftime);
use Exporter 'import';
our @EXPORT = qw(serv_init serv_update serv_cgi);

sub serv_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

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
		eval {
			RRDs::create($rrd,
				"--step=300",
				"DS:serv_i_ssh:GAUGE:600:0:U",
				"DS:serv_i_ftp:GAUGE:600:0:U",
				"DS:serv_i_telnet:GAUGE:600:0:U",
				"DS:serv_i_imap:GAUGE:600:0:U",
				"DS:serv_i_smb:GAUGE:600:0:U",
				"DS:serv_i_fax:GAUGE:600:0:U",
				"DS:serv_i_cups:GAUGE:600:0:U",
				"DS:serv_i_pop3:GAUGE:600:0:U",
				"DS:serv_i_smtp:GAUGE:600:0:U",
				"DS:serv_i_spam:GAUGE:600:0:U",
				"DS:serv_i_virus:GAUGE:600:0:U",
				"DS:serv_i_f2b:GAUGE:600:0:U",
				"DS:serv_i_val02:GAUGE:600:0:U",
				"DS:serv_i_val03:GAUGE:600:0:U",
				"DS:serv_i_val04:GAUGE:600:0:U",
				"DS:serv_i_val05:GAUGE:600:0:U",
				"DS:serv_l_ssh:GAUGE:600:0:U",
				"DS:serv_l_ftp:GAUGE:600:0:U",
				"DS:serv_l_telnet:GAUGE:600:0:U",
				"DS:serv_l_imap:GAUGE:600:0:U",
				"DS:serv_l_smb:GAUGE:600:0:U",
				"DS:serv_l_fax:GAUGE:600:0:U",
				"DS:serv_l_cups:GAUGE:600:0:U",
				"DS:serv_l_pop3:GAUGE:600:0:U",
				"DS:serv_l_smtp:GAUGE:600:0:U",
				"DS:serv_l_spam:GAUGE:600:0:U",
				"DS:serv_l_virus:GAUGE:600:0:U",
				"DS:serv_l_f2b:GAUGE:600:0:U",
				"DS:serv_l_val02:GAUGE:600:0:U",
				"DS:serv_l_val03:GAUGE:600:0:U",
				"DS:serv_l_val04:GAUGE:600:0:U",
				"DS:serv_l_val05:GAUGE:600:0:U",
				"RRA:AVERAGE:0.5:1:288",
				"RRA:AVERAGE:0.5:6:336",
				"RRA:AVERAGE:0.5:12:744",
				@average,
				"RRA:MIN:0.5:1:288",
				"RRA:MIN:0.5:6:336",
				"RRA:MIN:0.5:12:744",
				@min,
				"RRA:MAX:0.5:1:288",
				"RRA:MAX:0.5:6:336",
				"RRA:MAX:0.5:12:744",
				@max,
				"RRA:LAST:0.5:1:288",
				"RRA:LAST:0.5:6:336",
				"RRA:LAST:0.5:12:744",
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

	$config->{serv_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub serv_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

	my $ssh = 0;
	my $ftp = 0;
	my $telnet = 0;
	my $imap = 0;
	my $smb = 0;
	my $fax = 0;
	my $cups = 0;
	my $pop3 = 0;
	my $smtp = 0;
	my $spam = 0;
	my $virus = 0;
	my $f2b = 0;
	my $val02 = 0;
	my $val03 = 0;
	my $val04 = 0;
	my $val05 = 0;

	my $secure_seek_pos;
	my $imap_seek_pos;
	my $mail_seek_pos;
	my $sa_seek_pos;
	my $clamav_seek_pos;
	my $logsize;

	my $date;
	my $hour;
	my $rrdata = "N";

	# this graph is refreshed only every 5 minutes
	my (undef, $min) = localtime(time);
	return if($min % 5);

	$ssh = $config->{serv_hist}->{'i_ssh'} || 0;
	$ftp = $config->{serv_hist}->{'i_ftp'} || 0;
	$telnet = $config->{serv_hist}->{'i_telnet'} || 0;
	$imap = $config->{serv_hist}->{'i_imap'} || 0;
	$pop3 = $config->{serv_hist}->{'i_pop3'} || 0;
	$smtp = $config->{serv_hist}->{'i_smtp'} || 0;
	$spam = $config->{serv_hist}->{'i_spam'} || 0;
	$virus = $config->{serv_hist}->{'i_virus'} || 0;

	# zero all values on every new day
	$hour = int(strftime("%H", localtime));
	if(!defined($config->{serv_hist}->{'hour'})) {
		$config->{serv_hist}->{'hour'} = $hour;
	} else {
		if($hour < $config->{serv_hist}->{'hour'}) {
			$ssh = 0;
			$ftp = 0;
			$telnet = 0;
			$imap = 0;
			$smb = 0;
			$fax = 0;
			$cups = 0;
			$pop3 = 0;
			$smtp = 0;
			$spam = 0;
			$virus = 0;
			$f2b = 0;
			$val02 = 0;
			$val03 = 0;
			$val04 = 0;
			$val05 = 0;
		}
		$config->{serv_hist}->{'hour'} = $hour;
	}

	if(-r $config->{secure_log}) {
		$date = strftime("%b %e", localtime);
		$config->{secure_log_date_format} = $config->{secure_log_date_format} || "%b %e";
		my $date2 = strftime($config->{secure_log_date_format}, localtime);

		$secure_seek_pos = $config->{serv_hist}->{'secure_seek_pos'} || 0;
		$secure_seek_pos = defined($secure_seek_pos) ? int($secure_seek_pos) : 0;

		open(IN, "$config->{secure_log}");
		if(!seek(IN, 0, 2)) {
			logger("Couldn't seek to the end of '$config->{secure_log}': $!");
			close(IN);
			return;
		}
		$logsize = tell(IN);
		if($logsize < $secure_seek_pos) {
			$secure_seek_pos = 0;
		}
		if(!seek(IN, $secure_seek_pos, 0)) {
			logger("Couldn't seek to $secure_seek_pos in '$config->{secure_log}': $!");
			close(IN);
			return;
		}

		while(<IN>) {
			if(/^$date/) {
				if(/ sshd\[/ && /Accepted /) {
					$ssh++;
				}
				if($config->{os} eq "Linux") {
					if(/START: pop3/) {
						$pop3++;
					}
					if(/START: telnet/) {
						$telnet++;
					}
				} elsif($config->{os} eq "FreeBSD") {

					if(/login:/ && /login from /) {
						$telnet++;
					}
				}
			}
			if(/$date2/) {
				# ProFTPD log
				if(/START: ftp/ || (/ proftpd\[/ && /Login successful./) || /\"PASS .*\" 230/) {
					$ftp++;
					next;
				}
				# vsftpd log
				if(/OK LOGIN:/) {
					$ftp++;
					next;
				}
				# Pure-FTPd log
				if(/ \[INFO\] .*? is now logged in/) {
					$ftp++;
					next;
				}
			}
		}
		close(IN);
		$config->{serv_hist}->{'secure_seek_pos'} = $logsize;
	}

	if(-r $config->{imap_log}) {
		$config->{imap_log_date_format} = $config->{imap_log_date_format} || "%b %d";
		my $date_dovecot = strftime($config->{imap_log_date_format}, localtime);
		my $date_uw = strftime("%b %e", localtime);

		$imap_seek_pos = $config->{serv_hist}->{'imap_seek_pos'} || 0;
		$imap_seek_pos = defined($imap_seek_pos) ? int($imap_seek_pos) : 0;
		open(IN, "$config->{imap_log}");
		if(!seek(IN, 0, 2)) {
			logger("Couldn't seek to the end of '$config->{imap_log}': $!");
			close(IN);
			return;
		}
		$logsize = tell(IN);
		if($logsize < $imap_seek_pos) {
			$imap_seek_pos = 0;
		}
		if(!seek(IN, $imap_seek_pos, 0)) {
			logger("Couldn't seek to $imap_seek_pos in '$config->{imap_log}': $!");
			close(IN);
			return;
		}

		while(<IN>) {
			# UW-IMAP log
			if(/$date_uw/) {
				if(/ imapd\[/ && / Login user=/) {
					$imap++;
				}
				if(/ ipop3d\[/ && / Login user=/) {
					$pop3++;
				}
			}
			# Dovecot log
			if(/$date_dovecot /) {
				if(/ imap-login: / && / Login: /) {
					$imap++;
				}
				if(/ pop3-login: / && / Login: /) {
					$pop3++;
				}
			}
		}
		close(IN);
		$config->{serv_hist}->{'imap_seek_pos'} = $logsize;
	}

	my $smb_L = 0;
	open(IN, "smbstatus -L 2>/dev/null |");
	while(<IN>) {
		if(/^----------/) {
			$smb_L++;
			next;
		}
		if($smb_L) {
			$smb_L++ unless !$_;
		}
	}
	close(IN);
	$smb_L--;
	my $smb_S = 0;
	open(IN, "smbstatus -S 2>/dev/null |");
	while(<IN>) {
		if(/^----------/) {
			$smb_S++;
			next;
		}
		if($smb_S) {
			$smb_S++ unless !$_;
		}
	}
	close(IN);
	$smb_S--;
	$smb = $smb_L + $smb_S;

	if(-r $config->{hylafax_log}) {
		$date = strftime("%m/%d/%y", localtime);
		open(IN, "$config->{hylafax_log}");
		while(<IN>) {
			if(/^$date/ && /SEND/) {
				$fax++;
			}
		}
		close(IN);
	}

	if(-r $config->{cups_log}) {
		$date = strftime("%d/%b/%Y", localtime);
		open(IN, "$config->{cups_log}");
		while(<IN>) {
			if(/\[$date:/) {
				$cups++;
			}
		}
		close(IN);
	}

	if(-r $config->{fail2ban_log}) {
		$date = strftime("%Y-%m-%d", localtime);
		open(IN, $config->{fail2ban_log});
		while(<IN>) {
			if(/^$date/ && / fail2ban.actions/ && / Ban /) {
				$f2b++;
			}
		}
		close(IN);
	}

	if(-r $config->{mail_log}) {
		$date = strftime("%b %e", localtime);

		$mail_seek_pos = $config->{serv_hist}->{'mail_seek_pos'} || 0;
		$mail_seek_pos = defined($mail_seek_pos) ? int($mail_seek_pos) :0;
		open(IN, "$config->{mail_log}");
		if(!seek(IN, 0, 2)) {
			logger("Couldn't seek to the end of '$config->{mail_log}': $!");
			close(IN);
			return;
		}
		$logsize = tell(IN);
		if($logsize < $mail_seek_pos) {
			$mail_seek_pos = 0;
		}
		if(!seek(IN, $mail_seek_pos, 0)) {
			logger("Couldn't seek to $mail_seek_pos in '$config->{mail_log}': $!");
			close(IN);
			return;
		}

		while(<IN>) {
			if(/^$date/) {
				if(/to=/ && /stat(us)?=sent/i) {
					$smtp++;	
				}
				if(/MailScanner/ && /Spam Checks:/ && /Found/ && /spam messages/) {
					$spam++;
				}
				if(/MailScanner/ && /Virus Scanning:/ && /Found/ && /viruses/) {
					$virus++;
				}
				if(/amavis\[.* SPAM/) {
					$spam++;
				}
				if(/amavis\[.* INFECTED|amavis\[.* BANNED/) {
					$virus++;
				}
			}
		}
		close(IN);
		$config->{serv_hist}->{'mail_seek_pos'} = $logsize;
	}

	$date = strftime("%Y-%m-%d", localtime);
	if(-r "$config->{cg_logdir}/$date.log") {
		open(IN, "$config->{cg_logdir}/$date.log");
		while(<IN>) {
			if(/DEQUEUER \[\d+\] (LOCAL\(.+\) delivered|SMTP.+ relayed)\:/) {
				$smtp++;
			}
			if(/IMAP/ && / connected from /) {
				$imap++;
			}
			if(/POP/ && / connected from /) {
				$pop3++;
			}
		}
		close(IN);
	}

	if(-r $config->{spamassassin_log}) {
		$date = strftime("%b %e", localtime);

		$sa_seek_pos = $config->{serv_hist}->{'sa_seek_pos'} || 0;
		$sa_seek_pos = defined($sa_seek_pos) ? int($sa_seek_pos) :0;
		open(IN, "$config->{spamassassin_log}");
		if(!seek(IN, 0, 2)) {
			logger("Couldn't seek to the end of '$config->{spamassassin_log}': $!");
			close(IN);
			return;
		}
		$logsize = tell(IN);
		if($logsize < $sa_seek_pos) {
			$sa_seek_pos = 0;
		}
		if(!seek(IN, $sa_seek_pos, 0)) {
			logger("Couldn't seek to $sa_seek_pos in '$config->{spamassassin_log}': $!");
			close(IN);
			return;
		}

		while(<IN>) {
			if(/^$date/ && /spamd: identified spam/) {
				$spam++;
			}
		}
		close(IN);
		$config->{serv_hist}->{'sa_seek_pos'} = $logsize;
	}

	if(-r $config->{clamav_log}) {
		$date = strftime("%a %b %e", localtime);

		$clamav_seek_pos = $config->{serv_hist}->{'clamav_seek_pos'} || 0;
		$clamav_seek_pos = defined($clamav_seek_pos) ? int($clamav_seek_pos) :0;
		open(IN, "$config->{clamav_log}");
		if(!seek(IN, 0, 2)) {
			logger("Couldn't seek to the end of '$config->{clamav_log}': $!");
			close(IN);
			return;
		}
		$logsize = tell(IN);
		if($logsize < $clamav_seek_pos) {
			$clamav_seek_pos = 0;
		}
		if(!seek(IN, $clamav_seek_pos, 0)) {
			logger("Couldn't seek to $clamav_seek_pos in '$config->{clamav_log}': $!");
			close(IN);
			return;
		}

		while(<IN>) {
			if(/^$date/ && / FOUND/) {
				$virus++;
			}
		}
		close(IN);
		$config->{serv_hist}->{'clamav_seek_pos'} = $logsize;
	}

	# I data (incremental)
	$config->{serv_hist}->{'i_ssh'} = $ssh;
	$config->{serv_hist}->{'i_ftp'} = $ftp;
	$config->{serv_hist}->{'i_telnet'} = $telnet;
	$config->{serv_hist}->{'i_imap'} = $imap;
	$config->{serv_hist}->{'i_smb'} = $smb;
	$config->{serv_hist}->{'i_fax'} = $fax;
	$config->{serv_hist}->{'i_cups'} = $cups;
	$config->{serv_hist}->{'i_pop3'} = $pop3;
	$config->{serv_hist}->{'i_smtp'} = $smtp;
	$config->{serv_hist}->{'i_spam'} = $spam;
	$config->{serv_hist}->{'i_virus'} = $virus;
	$config->{serv_hist}->{'i_f2b'} = $f2b;
	$config->{serv_hist}->{'i_val02'} = $val02;
	$config->{serv_hist}->{'i_val03'} = $val03;
	$config->{serv_hist}->{'i_val04'} = $val04;
	$config->{serv_hist}->{'i_val05'} = $val05;
	$rrdata .= ":$ssh:$ftp:$telnet:$imap:$smb:$fax:$cups:$pop3:$smtp:$spam:$virus:$f2b:$val02:$val03:$val04:$val05";

	# L data (load)
	my $l_ssh = 0;
	my $l_ftp = 0;
	my $l_telnet = 0;
	my $l_imap = 0;
	my $l_smb = 0;
	my $l_fax = 0;
	my $l_cups = 0;
	my $l_pop3 = 0;
	my $l_smtp = 0;
	my $l_spam = 0;
	my $l_virus = 0;
	my $l_f2b = 0;
	my $l_val02 = 0;
	my $l_val03 = 0;
	my $l_val04 = 0;
	my $l_val05 = 0;

	$l_ssh = $ssh - ($config->{serv_hist}->{'l_ssh'} || 0);
	$l_ssh = 0 unless $l_ssh != $ssh;
	$l_ssh /= 300;
	$config->{serv_hist}->{'l_ssh'} = $ssh;

	$l_ftp = $ftp - ($config->{serv_hist}->{'l_ftp'} || 0);
	$l_ftp = 0 unless $l_ftp != $ftp;
	$l_ftp /= 300;
	$config->{serv_hist}->{'l_ftp'} = $ftp;

	$l_telnet = $telnet - ($config->{serv_hist}->{'l_telnet'} || 0);
	$l_telnet = 0 unless $l_telnet != $telnet;
	$l_telnet /= 300;
	$config->{serv_hist}->{'l_telnet'} = $telnet;

	$l_imap = $imap - ($config->{serv_hist}->{'l_imap'} || 0);
	$l_imap = 0 unless $l_imap != $imap;
	$l_imap /= 300;
	$config->{serv_hist}->{'l_imap'} = $imap;

	$l_smb = $smb - ($config->{serv_hist}->{'l_smb'} || 0);
	$l_smb = 0 unless $l_smb != $smb;
	$l_smb /= 300;
	$config->{serv_hist}->{'l_smb'} = $smb;

	$l_fax = $fax - ($config->{serv_hist}->{'l_fax'} || 0);
	$l_fax = 0 unless $l_fax != $fax;
	$l_fax /= 300;
	$config->{serv_hist}->{'l_fax'} = $fax;

	$l_cups = $cups - ($config->{serv_hist}->{'l_cups'} || 0);
	$l_cups = 0 unless $l_cups != $cups;
	$l_cups /= 300;
	$config->{serv_hist}->{'l_cups'} = $cups;

	$l_pop3 = $pop3 - ($config->{serv_hist}->{'l_pop3'} || 0);
	$l_pop3 = 0 unless $l_pop3 != $pop3;
	$l_pop3 /= 300;
	$config->{serv_hist}->{'l_pop3'} = $pop3;

	$l_smtp = $smtp - ($config->{serv_hist}->{'l_smtp'} || 0);
	$l_smtp = 0 unless $l_smtp != $smtp;
	$l_smtp /= 300;
	$config->{serv_hist}->{'l_smtp'} = $smtp;

	$l_spam = $spam - ($config->{serv_hist}->{'l_spam'} || 0);
	$l_spam = 0 unless $l_spam != $spam;
	$l_spam /= 300;
	$config->{serv_hist}->{'l_spam'} = $spam;

	$l_virus = $virus - ($config->{serv_hist}->{'l_virus'} || 0);
	$l_virus = 0 unless $l_virus != $virus;
	$l_virus /= 300;
	$config->{serv_hist}->{'l_virus'} = $virus;

	$l_f2b = $f2b - ($config->{serv_hist}->{'l_f2b'} || 0);
	$l_f2b = 0 unless $l_f2b != $f2b;
	$l_f2b /= 300;
	$config->{serv_hist}->{'l_f2b'} = $f2b;

	$l_val02 = $val02 - ($config->{serv_hist}->{'l_val02'} || 0);
	$l_val02 = 0 unless $l_val02 != $val02;
	$l_val02 /= 300;
	$config->{serv_hist}->{'l_val02'} = $val02;

	$l_val03 = $val03 - ($config->{serv_hist}->{'l_val03'} || 0);
	$l_val03 = 0 unless $l_val03 != $val03;
	$l_val03 /= 300;
	$config->{serv_hist}->{'l_val03'} = $val03;

	$l_val04 = $val04 - ($config->{serv_hist}->{'l_val04'} || 0);
	$l_val04 = 0 unless $l_val04 != $val04;
	$l_val04 /= 300;
	$config->{serv_hist}->{'l_val04'} = $val04;

	$l_val05 = $val05 - ($config->{serv_hist}->{'l_val05'} || 0);
	$l_val05 = 0 unless $l_val05 != $val05;
	$l_val05 /= 300;
	$config->{serv_hist}->{'l_val05'} = $val05;

	$rrdata .= ":$l_ssh:$l_ftp:$l_telnet:$l_imap:$l_smb:$l_fax:$l_cups:$l_pop3:$l_smtp:$l_spam:$l_virus:$l_f2b:$l_val02:$l_val03:$l_val04:$l_val05";
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub serv_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $serv = $config->{serv};
	my @rigid = split(',', ($serv->{rigid} || ""));
	my @limit = split(',', ($serv->{limit} || ""));
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
	my $vlabel;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $n;
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
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		if(lc($serv->{mode}) eq "i") {
			push(@output, "Values expressed as incremental or cumulative hits.\n");
		}
		push(@output, "Time    SSH     FTP  Telnet   Samba     Fax    CUPS     F2B    IMAP    POP3    SMTP    Spam   Virus\n");
		push(@output, "--------------------------------------------------------------------------------------------------- \n");
		my $line;
		my @row;
		my $time;
		my $from = 0;
		my $to;
		if(lc($serv->{mode}) eq "l") {
			$from = 15;
		}
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			$to = $from + 10;
			my ($ssh, $ftp, $telnet, $imap, $smb, $fax, $cups, $pop3, $smtp, $spam, $virus, $f2b) = @$line[$from..$to];
			@row = ($ssh, $ftp, $telnet, $imap, $smb, $fax, $cups, $f2b, $pop3, $smtp, $spam, $virus);
			if(lc($serv->{mode}) eq "i") {
				push(@output, sprintf(" %2d$tf->{tc} %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d\n", $time, @row));
			} elsif(lc($serv->{mode}) eq "l") {
				push(@output, sprintf(" %2d$tf->{tc} %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f\n", $time, @row));
			}
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
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
			"$IMG_DIR" . "$IMG2z",
			"$IMG_DIR" . "$IMG3z");
	}

	if($title) {
		push(@output, main::graph_header($title, 2));
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	if(lc($serv->{mode}) eq "l") {
		$vlabel = "Accesses/s";
		push(@tmp, "AREA:l_ssh#4444EE:SSH");
		push(@tmp, "GPRINT:l_ssh:LAST:        Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_ssh:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_ssh:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_ssh:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_ftp#44EE44:FTP");
		push(@tmp, "GPRINT:l_ftp:LAST:        Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_ftp:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_ftp:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_ftp:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_telnet#EE44EE:Telnet");
		push(@tmp, "GPRINT:l_telnet:LAST:     Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_telnet:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_telnet:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_telnet:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_smb#EEEE44:Samba");
		push(@tmp, "GPRINT:l_smb:LAST:      Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_smb:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_smb:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_smb:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_fax#FFA500:Fax");
		push(@tmp, "GPRINT:l_fax:LAST:        Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_fax:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_fax:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_fax:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_cups#444444:CUPS");
		push(@tmp, "GPRINT:l_cups:LAST:       Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_cups:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_cups:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_cups:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "AREA:l_f2b#EE4444:Fail2ban");
		push(@tmp, "GPRINT:l_f2b:LAST:   Current\\: %3.2lf");
		push(@tmp, "GPRINT:l_f2b:AVERAGE:   Average\\: %3.2lf");
		push(@tmp, "GPRINT:l_f2b:MIN:   Min\\: %3.2lf");
		push(@tmp, "GPRINT:l_f2b:MAX:   Max\\: %3.2lf\\n");
		push(@tmp, "LINE2:l_ssh#4444EE");
		push(@tmp, "LINE2:l_ftp#44EE44");
		push(@tmp, "LINE2:l_telnet#EE44EE");
		push(@tmp, "LINE2:l_smb#EEEE44");
		push(@tmp, "LINE2:l_fax#FFA500");
		push(@tmp, "LINE2:l_cups#444444");
		push(@tmp, "LINE2:l_f2b#EE4444");
		push(@tmp, "COMMENT: \\n");

		push(@tmpz, "AREA:l_ssh#4444EE:SSH");
		push(@tmpz, "AREA:l_ftp#44EE44:FTP");
		push(@tmpz, "AREA:l_telnet#EE44EE:Telnet");
		push(@tmpz, "AREA:l_smb#EEEE44:Samba");
		push(@tmpz, "AREA:l_fax#FFA500:Fax");
		push(@tmpz, "AREA:l_cups#444444:CUPS");
		push(@tmpz, "AREA:l_f2b#EE4444:Fail2ban");
		push(@tmpz, "LINE2:l_ssh#4444EE");
		push(@tmpz, "LINE2:l_ftp#44EE44");
		push(@tmpz, "LINE2:l_telnet#EE44EE");
		push(@tmpz, "LINE2:l_smb#EEEE44");
		push(@tmpz, "LINE2:l_fax#FFA500");
		push(@tmpz, "LINE2:l_cups#444444");
		push(@tmpz, "LINE2:l_f2b#EE4444");
	} else {
		$vlabel = "Incremental hits";
		push(@tmp, "AREA:i_ssh#4444EE:SSH");
		push(@tmp, "GPRINT:i_ssh:LAST:        Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_ssh:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_ssh:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_ssh:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_ftp#44EE44:FTP");
		push(@tmp, "GPRINT:i_ftp:LAST:        Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_ftp:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_ftp:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_ftp:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_telnet#EE44EE:Telnet");
		push(@tmp, "GPRINT:i_telnet:LAST:     Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_telnet:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_telnet:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_telnet:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_smb#EEEE44:Samba");
		push(@tmp, "GPRINT:i_smb:LAST:      Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_smb:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_smb:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_smb:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_fax#FFA500:Fax");
		push(@tmp, "GPRINT:i_fax:LAST:        Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_fax:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_fax:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_fax:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_cups#444444:CUPS");
		push(@tmp, "GPRINT:i_cups:LAST:       Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_cups:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_cups:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_cups:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "AREA:i_f2b#EE4444:Fail2ban");
		push(@tmp, "GPRINT:i_f2b:LAST:   Current\\: %5.0lf");
		push(@tmp, "GPRINT:i_f2b:AVERAGE:   Average\\: %5.0lf");
		push(@tmp, "GPRINT:i_f2b:MIN:   Min\\: %5.0lf");
		push(@tmp, "GPRINT:i_f2b:MAX:   Max\\: %5.0lf\\n");
		push(@tmp, "LINE2:i_ssh#4444EE");
		push(@tmp, "LINE2:i_ftp#44EE44");
		push(@tmp, "LINE2:i_telnet#EE44EE");
		push(@tmp, "LINE2:i_smb#EEEE44");
		push(@tmp, "LINE2:i_fax#FFA500");
		push(@tmp, "LINE2:i_cups#444444");
		push(@tmp, "LINE2:i_f2b#EE4444");
		push(@tmp, "COMMENT: \\n");

		push(@tmpz, "AREA:i_ssh#4444EE:SSH");
		push(@tmpz, "AREA:i_ftp#44EE44:FTP");
		push(@tmpz, "AREA:i_telnet#EE44EE:Telnet");
		push(@tmpz, "AREA:i_smb#EEEE44:Samba");
		push(@tmpz, "AREA:i_fax#FFA500:Fax");
		push(@tmpz, "AREA:i_cups#444444:CUPS");
		push(@tmpz, "AREA:i_f2b#EE4444:Fail2ban");
		push(@tmpz, "LINE2:i_ssh#4444EE");
		push(@tmpz, "LINE2:i_ftp#44EE44");
		push(@tmpz, "LINE2:i_telnet#EE44EE");
		push(@tmpz, "LINE2:i_smb#EEEE44");
		push(@tmpz, "LINE2:i_fax#FFA500");
		push(@tmpz, "LINE2:i_cups#444444");
		push(@tmpz, "LINE2:i_f2b#EE4444");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}

	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td>\n");
	}
	($width, $height) = split('x', $config->{graph_size}->{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG1",
		"--title=$config->{graphs}->{_serv1}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:i_ssh=$rrd:serv_i_ssh:AVERAGE",
		"DEF:i_ftp=$rrd:serv_i_ftp:AVERAGE",
		"DEF:i_telnet=$rrd:serv_i_telnet:AVERAGE",
		"DEF:i_imap=$rrd:serv_i_imap:AVERAGE",
		"DEF:i_smb=$rrd:serv_i_smb:AVERAGE",
		"DEF:i_fax=$rrd:serv_i_fax:AVERAGE",
		"DEF:i_cups=$rrd:serv_i_cups:AVERAGE",
		"DEF:i_f2b=$rrd:serv_i_f2b:AVERAGE",
		"DEF:l_ssh=$rrd:serv_l_ssh:AVERAGE",
		"DEF:l_ftp=$rrd:serv_l_ftp:AVERAGE",
		"DEF:l_telnet=$rrd:serv_l_telnet:AVERAGE",
		"DEF:l_imap=$rrd:serv_l_imap:AVERAGE",
		"DEF:l_smb=$rrd:serv_l_smb:AVERAGE",
		"DEF:l_fax=$rrd:serv_l_fax:AVERAGE",
		"DEF:l_cups=$rrd:serv_l_cups:AVERAGE",
		"DEF:l_f2b=$rrd:serv_l_f2b:AVERAGE",
		"CDEF:allvalues=i_ssh,i_ftp,i_telnet,i_imap,i_smb,i_fax,i_cups,i_f2b,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_serv1}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:i_ssh=$rrd:serv_i_ssh:AVERAGE",
			"DEF:i_ftp=$rrd:serv_i_ftp:AVERAGE",
			"DEF:i_telnet=$rrd:serv_i_telnet:AVERAGE",
			"DEF:i_imap=$rrd:serv_i_imap:AVERAGE",
			"DEF:i_smb=$rrd:serv_i_smb:AVERAGE",
			"DEF:i_fax=$rrd:serv_i_fax:AVERAGE",
			"DEF:i_cups=$rrd:serv_i_cups:AVERAGE",
			"DEF:i_f2b=$rrd:serv_i_f2b:AVERAGE",
			"DEF:l_ssh=$rrd:serv_l_ssh:AVERAGE",
			"DEF:l_ftp=$rrd:serv_l_ftp:AVERAGE",
			"DEF:l_telnet=$rrd:serv_l_telnet:AVERAGE",
			"DEF:l_imap=$rrd:serv_l_imap:AVERAGE",
			"DEF:l_smb=$rrd:serv_l_smb:AVERAGE",
			"DEF:l_fax=$rrd:serv_l_fax:AVERAGE",
			"DEF:l_cups=$rrd:serv_l_cups:AVERAGE",
			"DEF:l_f2b=$rrd:serv_l_f2b:AVERAGE",
			"CDEF:allvalues=i_ssh,i_ftp,i_telnet,i_imap,i_smb,i_fax,i_cups,i_f2b,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /serv1/)) {
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
		push(@output, "    <td class='td-valign-top'>\n");
	}
	@riglim = @{setup_riglim($rigid[1], $limit[1])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	if(lc($serv->{mode}) eq "l") {
		$vlabel = "Accesses/s";
		push(@tmp, "AREA:l_imap#4444EE:IMAP");
		push(@tmp, "GPRINT:l_imap:LAST:                 Current\\: %4.2lf\\n");
		push(@tmp, "AREA:l_pop3#44EE44:POP3");
		push(@tmp, "GPRINT:l_pop3:LAST:                 Current\\: %4.2lf\\n");
		push(@tmp, "LINE1:l_imap#4444EE:");
		push(@tmp, "LINE1:l_pop3#44EE44:");
		push(@tmpz, "AREA:l_imap#4444EE:IMAP");
		push(@tmpz, "AREA:l_pop3#44EE44:POP3");
		push(@tmpz, "LINE2:l_imap#4444EE:");
		push(@tmpz, "LINE2:l_pop3#44EE44:");
	} else {
		$vlabel = "Incremental hits";
		push(@tmp, "AREA:i_imap#4444EE:IMAP");
		push(@tmp, "GPRINT:i_imap:LAST:                 Current\\: %5.0lf\\n");
		push(@tmp, "AREA:i_pop3#44EE44:POP3");
		push(@tmp, "GPRINT:i_pop3:LAST:                 Current\\: %5.0lf\\n");
		push(@tmp, "LINE1:i_imap#4444EE:");
		push(@tmp, "LINE1:i_pop3#44EE44:");
		push(@tmpz, "AREA:i_imap#4444EE:IMAP");
		push(@tmpz, "AREA:i_pop3#44EE44:POP3");
		push(@tmpz, "LINE2:i_imap#4444EE:");
		push(@tmpz, "LINE2:i_pop3#44EE44:");
	}
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_serv2}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:i_imap=$rrd:serv_i_imap:AVERAGE",
		"DEF:l_imap=$rrd:serv_l_imap:AVERAGE",
		"DEF:i_pop3=$rrd:serv_i_pop3:AVERAGE",
		"DEF:l_pop3=$rrd:serv_l_pop3:AVERAGE",
		"CDEF:allvalues=i_imap,i_pop3,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_serv2}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:i_imap=$rrd:serv_i_imap:AVERAGE",
			"DEF:l_imap=$rrd:serv_l_imap:AVERAGE",
			"DEF:i_pop3=$rrd:serv_i_pop3:AVERAGE",
			"DEF:l_pop3=$rrd:serv_l_pop3:AVERAGE",
			"CDEF:allvalues=i_imap,i_pop3,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /serv2/)) {
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

	@riglim = @{setup_riglim($rigid[2], $limit[2])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	if(lc($serv->{mode}) eq "l") {
		$vlabel = "Accesses/s";
		push(@tmp, "AREA:l_smtp#44EEEE:SMTP");
		push(@tmp, "GPRINT:l_smtp:LAST:                 Current\\: %4.2lf\\n");
		push(@tmp, "AREA:l_spam#EEEE44:Spam");
		push(@tmp, "GPRINT:l_spam:LAST:                 Current\\: %4.2lf\\n");
		push(@tmp, "AREA:l_virus#EE4444:Virus");
		push(@tmp, "GPRINT:l_virus:LAST:                Current\\: %4.2lf\\n");
		push(@tmp, "LINE2:l_smtp#44EEEE");
		push(@tmp, "LINE2:l_spam#EEEE44");
		push(@tmp, "LINE2:l_virus#EE4444");

		push(@tmpz, "AREA:l_smtp#44EEEE:SMTP");
		push(@tmpz, "AREA:l_spam#EEEE44:Spam");
		push(@tmpz, "AREA:l_virus#EE4444:Virus");
		push(@tmpz, "LINE2:l_smtp#44EEEE");
		push(@tmpz, "LINE2:l_spam#EEEE44");
		push(@tmpz, "LINE2:l_virus#EE4444");
	} else {
		$vlabel = "Incremental hits";
		push(@tmp, "AREA:i_smtp#44EEEE:SMTP");
		push(@tmp, "GPRINT:i_smtp:LAST:                 Current\\: %5.0lf\\n");
		push(@tmp, "AREA:i_spam#EEEE44:Spam");
		push(@tmp, "GPRINT:i_spam:LAST:                 Current\\: %5.0lf\\n");
		push(@tmp, "AREA:i_virus#EE4444:Virus");
		push(@tmp, "GPRINT:i_virus:LAST:                Current\\: %5.0lf\\n");
		push(@tmp, "LINE2:i_smtp#44EEEE");
		push(@tmp, "LINE2:i_spam#EEEE44");
		push(@tmp, "LINE2:i_virus#EE4444");

		push(@tmpz, "AREA:i_smtp#44EEEE:SMTP");
		push(@tmpz, "AREA:i_spam#EEEE44:Spam");
		push(@tmpz, "AREA:i_virus#EE4444:Virus");
		push(@tmpz, "LINE2:i_smtp#44EEEE");
		push(@tmpz, "LINE2:i_spam#EEEE44");
		push(@tmpz, "LINE2:i_virus#EE4444");
	}
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG3",
		"--title=$config->{graphs}->{_serv3}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:i_smtp=$rrd:serv_i_smtp:AVERAGE",
		"DEF:i_spam=$rrd:serv_i_spam:AVERAGE",
		"DEF:i_virus=$rrd:serv_i_virus:AVERAGE",
		"DEF:l_smtp=$rrd:serv_l_smtp:AVERAGE",
		"DEF:l_spam=$rrd:serv_l_spam:AVERAGE",
		"DEF:l_virus=$rrd:serv_l_virus:AVERAGE",
		"CDEF:allvalues=i_smtp,i_spam,i_virus,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		undef(@tmp);
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_serv3}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:i_smtp=$rrd:serv_i_smtp:AVERAGE",
			"DEF:i_spam=$rrd:serv_i_spam:AVERAGE",
			"DEF:i_virus=$rrd:serv_i_virus:AVERAGE",
			"DEF:l_smtp=$rrd:serv_l_smtp:AVERAGE",
			"DEF:l_spam=$rrd:serv_l_spam:AVERAGE",
			"DEF:l_virus=$rrd:serv_l_virus:AVERAGE",
			"CDEF:allvalues=i_smtp,i_spam,i_virus,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /serv3/)) {
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
		push(@output, "    </tr>\n");
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
