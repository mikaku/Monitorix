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

package mail;

use strict;
use warnings;
use Monitorix;
use RRDs;
use POSIX qw(strftime);
use Exporter 'import';
our @EXPORT = qw(mail_init mail_update mail_cgi);


sub mail_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $mail = $config->{mail};

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
				"--step=60",
				"DS:mail_in:GAUGE:120:0:U",
				"DS:mail_out:GAUGE:120:0:U",
				"DS:mail_recvd:GAUGE:120:0:U",
				"DS:mail_delvd:GAUGE:120:0:U",
				"DS:mail_bytes_recvd:GAUGE:120:0:U",
				"DS:mail_bytes_delvd:GAUGE:120:0:U",
				"DS:mail_rejtd:GAUGE:120:0:U",
				"DS:mail_spam:GAUGE:120:0:U",
				"DS:mail_virus:GAUGE:120:0:U",
				"DS:mail_bouncd:GAUGE:120:0:U",
				"DS:mail_queued:GAUGE:120:0:U",
				"DS:mail_discrd:GAUGE:120:0:U",
				"DS:mail_held:GAUGE:120:0:U",
				"DS:mail_forwrd:GAUGE:120:0:U",
				"DS:mail_queues:GAUGE:120:0:U",
				"DS:mail_val01:GAUGE:120:0:U",
				"DS:mail_val02:GAUGE:120:0:U",
				"DS:mail_val03:GAUGE:120:0:U",
				"DS:mail_val04:GAUGE:120:0:U",
				"DS:mail_val05:GAUGE:120:0:U",
				"DS:mail_val06:GAUGE:120:0:U",
				"DS:mail_val07:GAUGE:120:0:U",
				"DS:mail_val08:GAUGE:120:0:U",
				"DS:mail_val09:GAUGE:120:0:U",
				"DS:mail_val10:GAUGE:120:0:U",
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

	# check dependencies
	if(lc($mail->{alerts}->{delvd_enabled}) eq "y") {
		if(! -x $mail->{alerts}->{delvd_script}) {
			logger("$myself: ERROR: script '$mail->{alerts}->{delvd_script}' doesn't exist or don't has execution permissions.");
		}
	}
	if(lc($mail->{alerts}->{mqueued_enabled}) eq "y") {
		if(! -x $mail->{alerts}->{mqueued_script}) {
			logger("$myself: ERROR: script '$mail->{alerts}->{mqueued_script}' doesn't exist or don't has execution permissions.");
		}
	}
	if(!$mail->{stats_rate}) {
		$mail->{stats_rate} = "per_second";
	}

	# Since 3.6.0 all DS changed from COUNTER to GAUGE
	RRDs::tune($rrd,
		"--data-source-type=mail_val01:GAUGE",
		"--data-source-type=mail_val02:GAUGE",
		"--data-source-type=mail_val03:GAUGE",
		"--data-source-type=mail_val04:GAUGE",
		"--data-source-type=mail_val05:GAUGE",
	);

	$config->{mail_hist} = 0;
	$config->{mail_hist_alert1} = 0;
	$config->{mail_hist_alert2} = 0;
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub mail_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $mail = $config->{mail};

	my $in_conn;
	my $out_conn;
	my $recvd;
	my $delvd;
	my $bytes_recvd;
	my $bytes_delvd;
	my $rejtd;
	my $spam;
	my $virus;
	my $bouncd;
	my $queued;
	my $discrd;
	my $held;
	my $forwrd;
	my $queues;
	my $spf_none;
	my $spf_pass;
	my $spf_softfail;
	my $spf_fail;
	my $rbl;
	my $gl_records;		# means 'passed' in Postgrey
	my $gl_greylisted;
	my $gl_whitelisted;
	my $gl_delayed;		# specific for Postgrey
	my @mta = (0) x 15;
	my @gen = (0) x 10;
	my @mta_h = (0) x 15;
	my @gen_h = (0) x 10;

	my $n;
	my $first_read;
	my $mail_log_seekpos;
	my $mail_log_size = 0;
	my $sa_log_seekpos;
	my $sa_log_size = 0;
	my $clamav_log_seekpos;
	my $clamav_log_size = 0;
	my $rrdata = "N";

	# Read last MAIL data from historic
	($mail_log_seekpos, $sa_log_seekpos, $clamav_log_seekpos, @mta_h[0..15-1], @gen_h[0..10-1]) = split(';', $config->{mail_hist});
	$mail_log_seekpos = defined($mail_log_seekpos) ? int($mail_log_seekpos) : 0;
	$sa_log_seekpos = defined($sa_log_seekpos) ? int($sa_log_seekpos) : 0;
	$clamav_log_seekpos = defined($clamav_log_seekpos) ? int($clamav_log_seekpos) : 0;
	$first_read = $mail_log_seekpos ? 0 : 1;

	$recvd = $delvd = $bytes_recvd = $bytes_delvd = 0;
	$in_conn = $out_conn = $rejtd = 0;
	$bouncd = $discrd = $held = $forwrd = 0;
	$queued = $queues = 0;
	if(lc($mail->{mta}) eq "sendmail") {
		if(open(IN, "mailstats -P |")) {
			while(<IN>) {
				if(/^ T\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
					$recvd = $1;
					$bytes_recvd = $2;
					$delvd = $3;
					$bytes_delvd = $4;
				}
				if(/^ C\s+(\d+)\s+(\d+)\s+(\d+)/) {
					$in_conn = $1;
					$out_conn = $2;
					$rejtd = $3;
				}
			}
			close(IN);
			$bytes_recvd *= 1024;
			$bytes_delvd *= 1024;
		}
		if(open(IN, "mailq |")) {
			while(<IN>) {
				my ($tmp) = ($_ =~ m/^\w{14}[ *X-]\s*(\d{1,8}) /);
				$queues += $tmp if $tmp;
				if(/^\s+Total requests: (\d+)$/) {
					$queued = $1;
				}
			}
			close(IN);
		}
	} elsif(lc($mail->{mta}) eq "postfix") {
		my @data;

		for my $path (split /:/, $ENV{PATH}) {
			if(-f "$path/pflogsumm" && -x _) {
				if(open(IN, "pflogsumm -d today -h 0 -u 0 --smtpd_stats --bounce_detail=0 --deferral_detail=0 --reject_detail=0 --no_no_msg_size --smtpd_warning_detail=0 $config->{mail_log} 2>/dev/null |")) {
					@data = <IN>;
					close(IN);
					last;
				}
			}
			if(-f "$path/pflogsumm.pl" && -x _) {
				if(open(IN, "pflogsumm.pl -d today -h 0 -u 0 --smtpd_stats --bounce_detail=0 --deferral_detail=0 --reject_detail=0 --no_no_msg_size --smtpd_warning_detail=0 $config->{mail_log} 2>/dev/null |")) {
					@data = <IN>;
					close(IN);
					last;
				}
			}
		}

		logger("$myself: 'pflogsumm' returned empty data. Is it really installed?")
			if !@data;

		foreach(@data) {
			if(/^\s*(\d{1,7})([ km])\s*received$/) {
				$recvd = $1;
				$recvd = $1 * 1024 if $2 eq "k";
				$recvd = $1 * 1024 * 1024 if $2 eq "m";
			}
			if(/^\s*(\d{1,7})([ km])\s*delivered$/) {
				$delvd = $1;
				$delvd = $1 * 1024 if $2 eq "k";
				$delvd = $1 * 1024 * 1024 if $2 eq "m";
			}
			if(/^\s*(\d{1,7})([ km])\s*forwarded$/) {
				$forwrd = $1;
				$forwrd = $1 * 1024 if $2 eq "k";
				$forwrd = $1 * 1024 * 1024 if $2 eq "m";
			}
			if(/^\s*(\d{1,7})([ km])\s*bounced$/) {
				$bouncd = $1;
				$bouncd = $1 * 1024 if $2 eq "k";
				$bouncd = $1 * 1024 * 1024 if $2 eq "m";
			}
			if(/^\s*(\d{1,7})([ km])\s*rejected \(/) {
				$rejtd = $1;
				$rejtd = $1 * 1024 if $2 eq "k";
				$rejtd = $1 * 1024 * 1024 if $2 eq "m";
			}
			if(/^\s*(\d{1,7})([ km])\s*held/) {
				$held = $1;
				$held = $1 * 1024 if $2 eq "k";
				$held = $1 * 1024 * 1024 if $2 eq "m";
			}
			if(/^\s*(\d{1,7})([ km])\s*discarded \(/) {
				$discrd = $1;
				$discrd = $1 * 1024 if $2 eq "k";
				$discrd = $1 * 1024 * 1024 if $2 eq "m";
			}
			if(/^\s*(\d{1,7})([ km])\s*bytes received$/) {
				$bytes_recvd = $1;
				$bytes_recvd = $1 * 1024 if $2 eq "k";
				$bytes_recvd = $1 * 1024 * 1024 if $2 eq "m";
			}
			if(/^\s*(\d{1,7})([ km])\s*bytes delivered$/) {
				$bytes_delvd = $1;
				$bytes_delvd = $1 * 1024 if $2 eq "k";
				$bytes_delvd = $1 * 1024 * 1024 if $2 eq "m";
			}
		}
		if(open(IN, "mailq |")) {
			while(<IN>) {
				if(/^-- (\d+) Kbytes in (\d+) Request/) {
					$queues = $1;
					$queued = $2;
				}  
			}
			close(IN);
		}
	} elsif(lc($mail->{mta}) eq "exim") {
		if(open(IN, "eximstats -h0 -ne -nr -t0 $config->{mail_log} |")) {
			while(<IN>) {
				if(/^  Received\s+(\d+)(\S\S)\s+(\d+).*?$/) {
					$bytes_recvd = $1;
					$bytes_recvd = $1 * 1024 if $2 eq "KB";
					$bytes_recvd = $1 * 1024 * 1024 if $2 eq "MB";
					$recvd = $3;
				}
				if(/^  Delivered\s+(\d+)(\S\S)\s+(\d+).*?$/) {
					$bytes_delvd = $1;
					$bytes_delvd = $1 * 1024 if $2 eq "KB";
					$bytes_delvd = $1 * 1024 * 1024 if $2 eq "MB";
					$delvd = $3;
				}
				if(/^  Rejects\s+(\d+).*?$/) {
					$rejtd = $1;
				}
				if(/^  remote_smtp\s+\d+\S*\s+(\d+)$/) {
					$out_conn = $1;
				}
			}
			close(IN);
			$in_conn = $recvd - $rejtd;
			$delvd -= $out_conn;
		}
		if(open(IN, "exim -bp |")) {
			while(<IN>) {
				# discard blank lines and lines with recipients
				if(!/^$/ && !/^\s{10}\S+$/) {
					my ($size, undef, $unit) = ($_ =~ m/^\s*\d+.\s+(\d(.\d)?)(\S*)\s.*?$/);
					$queues += int($size) if !$unit;
					$queues += int($size * 1024) if $unit eq "K";
					$queues += int($size * 1024 * 1024) if $unit eq "M";
					$queued++;
				}  
			}
			close(IN);
		}
	}

	$gl_records = $gl_greylisted = $gl_whitelisted = $gl_delayed = 0;
	if(lc($mail->{greylist}) eq "milter-greylist") {
		if(-r $config->{milter_gl}) {
			open(IN, $config->{milter_gl});
			if(!seek(IN, -80, 2)) {
				logger("Couldn't seek to the end ($config->{milter_gl}): $!");
				return;
			}
			while(<IN>) {
				if(/^# Summary:\s+(\d+) records,\s+(\d+) greylisted,\s+(\d+) whitelisted/) {
					$gl_records = $1;
					$gl_greylisted = $2;
					$gl_whitelisted = $3;
				}
			}
			close(IN);
		}
	}

	$spam = $virus = 0;
	$spf_none = $spf_pass = $spf_softfail = $spf_fail = 0;
	$rbl = 0;
	if(-r $config->{mail_log}) {
		my $date = strftime("%b %e", localtime);
		open(IN, $config->{mail_log});
		if(!seek(IN, 0, 2)) {
			logger("Couldn't seek to the end ($config->{mail_log}): $!");
			return;
		}
		$mail_log_size = tell(IN);
		if($mail_log_size < $mail_log_seekpos) {
			$mail_log_seekpos = 0;
		}
		if(!seek(IN, $mail_log_seekpos, 0)) {
			logger("Couldn't seek to $mail_log_seekpos ($config->{mail_log}): $!");
			return;
		}
		while(<IN>) {
			my @line;
			if(/^$date/) {
				if(/MailScanner/ && /Spam Checks:/ && /Found/ && /spam messages/) {
					@line = split(' ', $_);
					$spam += int($line[8]);
				}
				if(/MailScanner/ && /Virus Scanning:/ && /Found/ && /viruses/) {
					@line = split(' ', $_);
					$virus += int($line[8]);
				}
				if(/amavis\[.* SPAM/) {
					$spam++;
				}
				if(/amavis\[.* INFECTED|amavis\[.* BANNED/) {
					$virus++;
				}
				# postfix-policyd-spf-perl 
				if (/policy-spf/) {
					if(/: pass/) {
						$spf_pass++;
					} elsif(/: none/) {
						$spf_none++;
					} elsif(/ action=550 /) {
						$spf_fail++;
					} else {
						# There one line per spf check, so it gets here, we'll consider it is a softfail
						$spf_softfail++;
					}
				# for other SPF handlers (smf-spf)
				} else {
					if(/ SPF none/) {
						$spf_none++;
					} elsif(/ SPF pass/) {
						$spf_pass++;
					} elsif(/ SPF softfail/) {
						$spf_softfail++;
					} elsif(/ SPF fail/) {
						$spf_fail++;
					}
				}
				# postfix RBL
				if(/ postfix\/smtpd\[\d+\]: NOQUEUE: reject: RCPT from /) {
					# postgrey
					if(lc($mail->{greylist}) eq "postgrey") {
						if(/ Recipient address rejected: Greylisted, /) {
							next;	# ignored
						}
					}
					$rbl++;
				}
				# postgrey
				if(lc($mail->{greylist}) eq "postgrey") {
					if(/ action=greylist, reason=new, /) {
						$gl_greylisted++;
					}
					if(/ action=greylist, reason=early-retry /) {
						$gl_delayed++;
					}
					if(/ action=pass, reason=triplet found, /) {
						$gl_records++;
					}
					if(/ action=pass, reason=client (whitelist|AWL), /) {
						$gl_whitelisted++;
					}
				}
			}
		}
		close(IN);
	}

	if(-r $config->{spamassassin_log}) {
		my $date = strftime("%b %e", localtime);
		open(IN, $config->{spamassassin_log});
		if(!seek(IN, 0, 2)) {
			logger("Couldn't seek to the end ($config->{spamassassin_log}): $!");
			return;
		}
		$sa_log_size = tell(IN);
		if($sa_log_size < $sa_log_seekpos) {
			$sa_log_seekpos = 0;
		}
		if(!seek(IN, $sa_log_seekpos, 0)) {
			logger("Couldn't seek to $sa_log_seekpos ($config->{spamassassin_log}): $!");
			return;
		}
		while(<IN>) {
			if(/^$date/ && /spamd: identified spam/) {
				$spam++;
			}
		}
		close(IN);
	}

	if(-r $config->{clamav_log}) {
		my $date = strftime("%a %b %e", localtime);
		open(IN, $config->{clamav_log});
		if(!seek(IN, 0, 2)) {
			logger("Couldn't seek to the end ($config->{clamav_log}): $!");
			return;
		}
		$clamav_log_size = tell(IN);
		if($clamav_log_size < $clamav_log_seekpos) {
			$clamav_log_seekpos = 0;
		}
		if(!seek(IN, $clamav_log_seekpos, 0)) {
			logger("Couldn't seek to $clamav_log_seekpos ($config->{clamav_log}): $!");
			return;
		}
		while(<IN>) {
			if(/^$date/ && / FOUND/) {
				$virus++;
			}
		}
		close(IN);
	}

	$mta[0] = int($in_conn) - ($mta_h[0] || 0);
	$mta[0] = 0 unless $mta[0] != int($in_conn);
	$mta[0] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	$mta_h[0] = int($in_conn);

	$mta[1] = int($out_conn) - ($mta_h[1] || 0);
	$mta[1] = 0 unless $mta[1] != int($out_conn);
	$mta[1] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	$mta_h[1] = int($out_conn);

	$mta[2] = int($recvd) - ($mta_h[2] || 0);
	$mta[2] = 0 unless $mta[2] != int($recvd);
	$mta[2] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	$mta_h[2] = int($recvd);

	$mta[3] = int($delvd) - ($mta_h[3] || 0);
	$mta[3] = 0 unless $mta[3] != int($delvd);
	$mta[3] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	$mta_h[3] = int($delvd);

	$mta[4] = int($bytes_recvd) - ($mta_h[4] || 0);
	$mta[4] = 0 unless $mta[4] != int($bytes_recvd);
	$mta[4] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	$mta_h[4] = int($bytes_recvd);

	$mta[5] = int($bytes_delvd) - ($mta_h[5] || 0);
	$mta[5] = 0 unless $mta[5] != int($bytes_delvd);
	$mta[5] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	$mta_h[5] = int($bytes_delvd);

	$mta[6] = int($rejtd) - ($mta_h[6] || 0);
	$mta[6] = 0 unless $mta[6] != int($rejtd);
	$mta[6] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	$mta_h[6] = int($rejtd);

	# avoid initial peak
	$mta_h[7] = 0;
	if(!$first_read) {
		$mta[7] = int($spam);
		$mta[7] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	}
	# avoid initial peak
	$mta_h[8] = 0;
	if(!$first_read) {
		$mta[8] = int($virus);
		$mta[8] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	}

	$mta[9] = int($bouncd) - ($mta_h[9] || 0);
	$mta[9] = 0 unless $mta[9] != int($bouncd);
	$mta[9] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	$mta_h[9] = int($bouncd);

	$mta[10] = int($queued) || 0;
	$mta_h[10] = 0;

	$mta[11] = int($discrd) - ($mta_h[11] || 0);
	$mta[11] = 0 unless $mta[11] != int($discrd);
	$mta[11] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	$mta_h[11] = int($discrd);

	$mta[12] = int($held) - ($mta_h[12] || 0);
	$mta[12] = 0 unless $mta[12] != int($held);
	$mta[12] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	$mta_h[12] = int($held);

	$mta[13] = int($forwrd) - ($mta_h[13] || 0);
	$mta[13] = 0 unless $mta[13] != int($forwrd);
	$mta[13] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	$mta_h[13] = int($forwrd);

	$mta[14] = int($queues) || 0;
	$mta_h[14] = 0;

	# avoid initial peak
	$gen_h[0] = 0;
	if(!$first_read) {
		$gen[0] = int($spf_none);
	}
	# avoid initial peak
	$gen_h[1] = 0;
	if(!$first_read) {
		$gen[1] = int($spf_pass);
	}
	# avoid initial peak
	$gen_h[2] = 0;
	if(!$first_read) {
		$gen[2] = int($spf_softfail);
	}
	# avoid initial peak
	$gen_h[3] = 0;
	if(!$first_read) {
		$gen[3] = int($spf_fail);
	}
	# avoid initial peak
	$gen_h[4] = 0;
	if(!$first_read) {
		$gen[4] = int($rbl);
		$gen[4] /= 60 if lc($mail->{stats_rate}) eq "per_second";
	}

	if(lc($mail->{greylist}) eq "milter-greylist") {
		$gen_h[5] = $gen[5] = 0;
		$gen_h[6] = $gen[6] = int($gl_records) || 0;
		$gen_h[7] = $gen[7] = int($gl_greylisted) || 0;
		$gen_h[8] = $gen[8] = int($gl_whitelisted) || 0;
		$gen_h[9] = $gen[9] = int($gl_delayed) || 0;
	}
	if(lc($mail->{greylist}) eq "postgrey") {
		$gen_h[5] = $gen[5] = 0;
		$gen_h[6] = $gen[6] = 0;
		$gen_h[7] = $gen[7] = 0;
		$gen_h[8] = $gen[8] = 0;
		$gen_h[9] = $gen[9] = 0;
		# avoid initial peak
		if(!$first_read) {
			$gen[6] = int($gl_records);
			$gen[6] /= 60 if lc($mail->{stats_rate}) eq "per_second";
		}
		# avoid initial peak
		if(!$first_read) {
			$gen[7] = int($gl_greylisted);
			$gen[7] /= 60 if lc($mail->{stats_rate}) eq "per_second";
		}
		# avoid initial peak
		if(!$first_read) {
			$gen[8] = int($gl_whitelisted);
			$gen[8] /= 60 if lc($mail->{stats_rate}) eq "per_second";
		}
		# avoid initial peak
		if(!$first_read) {
			$gen[9] = int($gl_delayed);
			$gen[9] /= 60 if lc($mail->{stats_rate}) eq "per_second";
		}
	}

	$config->{mail_hist} = join(";", $mail_log_size, $sa_log_size, $clamav_log_size, @mta_h, @gen_h);
	for($n = 0; $n < 15; $n++) {
		$rrdata .= ":" . $mta[$n];
	}
	for($n = 0; $n < 10; $n++) {
		$rrdata .= ":" . $gen[$n];
	}

	# MAIL alert
	if(lc($mail->{alerts}->{delvd_enabled}) eq "y") {
		my $val = int($mta[3]);
		$val *= 60 + 0.5 if lc($mail->{stats_rate}) eq "per_second";
		if(!$mail->{alerts}->{delvd_threshold} || $val < $mail->{alerts}->{delvd_threshold}) {
			$config->{mail_hist_alert1} = 0;
		} else {
			if(!$config->{mail_hist_alert1}) {
				$config->{mail_hist_alert1} = time;
			}
			if($config->{mail_hist_alert1} > 0 && (time - $config->{mail_hist_alert1}) >= $mail->{alerts}->{delvd_timeintvl}) {
				if(-x $mail->{alerts}->{delvd_script}) {
					logger("$myself: ALERT: executing script '$mail->{alerts}->{delvd_script}'.");
					system($mail->{alerts}->{delvd_script} . " " .$mail->{alerts}->{delvd_timeintvl} . " " . $mail->{alerts}->{delvd_threshold} . " " . $val);
				} else {
					logger("$myself: ERROR: script '$mail->{alerts}->{delvd_script}' doesn't exist or don't has execution permissions.");
				}
				$config->{mail_hist_alert1} = time;
			}
		}
	}
	if(lc($mail->{alerts}->{mqueued_enabled}) eq "y") {
		my $val = $mta[10];
		if(!$mail->{alerts}->{mqueued_threshold} || $val < $mail->{alerts}->{mqueued_threshold}) {
			$config->{mail_hist_alert2} = 0;
		} else {
			if(!$config->{mail_hist_alert2}) {
				$config->{mail_hist_alert2} = time;
			}
			if($config->{mail_hist_alert2} > 0 && (time - $config->{mail_hist_alert2}) >= $mail->{alerts}->{mqueued_timeintvl}) {
				if(-x $mail->{alerts}->{mqueued_script}) {
					logger("$myself: ALERT: executing script '$mail->{alerts}->{mqueued_script}'.");
					system($mail->{alerts}->{mqueued_script} . " " .$mail->{alerts}->{mqueued_timeintvl} . " " . $mail->{alerts}->{mqueued_threshold} . " " . $val);
				} else {
					logger("$myself: ERROR: script '$mail->{alerts}->{mqueued_script}' doesn't exist or don't has execution permissions.");
				}
				$config->{mail_hist_alert2} = time;
			}
		}
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub mail_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $mail = $config->{mail};
	my @rigid = split(',', ($mail->{rigid} || ""));
	my @limit = split(',', ($mail->{limit} || ""));
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
	my $T = "B";
	my $vlabel = "bytes/s";
	my $rate_label = "Messages";
	my $valform = "%5.0lf";
	my $gl_valform = "%5.0lf";
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

	if(lc($config->{netstats_in_bps}) eq "y") {
		$T = "b";
		$vlabel = "bits/s";
	}
	if(!$mail->{stats_rate}) {
		$mail->{stats_rate} = "per_second";
	}
	if(lc($mail->{stats_rate}) eq "per_second") {
		$rate_label = "Messages/s";
		$valform = "%5.2lf";
		$gl_valform = "%5.1lf";
	}


	# mode text
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
		push(@output, "Time  In.Conn Out.Conn  Receivd   Delivd  Bytes.R  Bytes.D  Rejectd  Bounced  Discard     Held  Forward     Spam    Virus   Queued  Queue.S\n");
		push(@output, "------------------------------------------------------------------------------------------------------------------------------------------- \n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			my ($in, $out, $recvd, $delvd, $bytes_recvd, $bytes_delvd, $rejtd, $spam, $virus, $bouncd, $queued, $discrd, $held, $forwrd, $queues) = @$line;
			@row = ($in, $out, $recvd, $delvd, $bytes_recvd, $bytes_delvd, $rejtd, $bouncd, $discrd, $held, $forwrd, $spam, $virus, $queued, $queues);
			push(@output, sprintf(" %2d$tf->{tc}  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f\n", $time, @row));
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
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG4z = $u . $package . "4z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG5z = $u . $package . "5z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG6z = $u . $package . "6z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3",
		"$IMG_DIR" . "$IMG4",
		"$IMG_DIR" . "$IMG5",
		"$IMG_DIR" . "$IMG6");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
			"$IMG_DIR" . "$IMG2z",
			"$IMG_DIR" . "$IMG3z",
			"$IMG_DIR" . "$IMG4z",
			"$IMG_DIR" . "$IMG5z",
			"$IMG_DIR" . "$IMG6z");
	}

	if($title) {
		push(@output, main::graph_header($title, 2));
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	if(lc($mail->{mta}) eq "sendmail") {
		push(@tmp, "AREA:in#44EE44:In Connections");
		push(@tmp, "GPRINT:in:LAST:    Cur\\: $valform");
		push(@tmp, "GPRINT:in:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:in:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:in:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:rejtd#EE4444:Rejected");
		push(@tmp, "GPRINT:rejtd:LAST:          Cur\\: $valform");
		push(@tmp, "GPRINT:rejtd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:rejtd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:rejtd:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:recvd#448844:Received");
		push(@tmp, "GPRINT:recvd:LAST:          Cur\\: $valform");
		push(@tmp, "GPRINT:recvd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:recvd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:recvd:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:spam#EEEE44:Spam");
		push(@tmp, "GPRINT:spam:LAST:              Cur\\: $valform");
		push(@tmp, "GPRINT:spam:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:spam:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:spam:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:virus#EE44EE:Virus");
		push(@tmp, "GPRINT:virus:LAST:             Cur\\: $valform");
		push(@tmp, "GPRINT:virus:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:virus:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:virus:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:n_delvd#4444EE:Delivered");
		push(@tmp, "GPRINT:delvd:LAST:         Cur\\: $valform");
		push(@tmp, "GPRINT:delvd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:delvd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:delvd:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:n_out#44EEEE:Out Connections");
		push(@tmp, "GPRINT:out:LAST:   Cur\\: $valform");
		push(@tmp, "GPRINT:out:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:out:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:out:MAX:    Max\\: $valform\\n");
		push(@tmp, "LINE1:in#00EE00");
		push(@tmp, "LINE1:rejtd#EE0000");
		push(@tmp, "LINE1:recvd#1F881F");
		push(@tmp, "LINE1:spam#EEEE00");
		push(@tmp, "LINE1:virus#EE00EE");
		push(@tmp, "LINE1:n_delvd#0000EE");
		push(@tmp, "LINE1:n_out#00EEEE");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");

		push(@tmpz, "AREA:in#44EE44:In Connections");
		push(@tmpz, "AREA:rejtd#EE4444:Rejected");
		push(@tmpz, "AREA:recvd#448844:Received");
		push(@tmpz, "AREA:spam#EEEE44:Spam");
		push(@tmpz, "AREA:virus#EE44EE:Virus");
		push(@tmpz, "AREA:n_delvd#4444EE:Delivered");
		push(@tmpz, "AREA:n_out#44EEEE:Out Connections");
		push(@tmpz, "LINE1:in#00EE00");
		push(@tmpz, "LINE1:rejtd#EE0000");
		push(@tmpz, "LINE1:recvd#1F881F");
		push(@tmpz, "LINE1:spam#EEEE00");
		push(@tmpz, "LINE1:virus#EE00EE");
		push(@tmpz, "LINE1:n_delvd#0000EE");
		push(@tmpz, "LINE1:n_out#00EEEE");
	} elsif(lc($mail->{mta}) eq "postfix") {
		push(@tmp, "AREA:rejtd#EE4444:Rejected");
		push(@tmp, "GPRINT:rejtd:LAST:          Cur\\: $valform");
		push(@tmp, "GPRINT:rejtd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:rejtd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:rejtd:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:rbl#963C74:Rejected (RBL)");
		push(@tmp, "GPRINT:rbl:LAST:    Cur\\: $valform");
		push(@tmp, "GPRINT:rbl:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:rbl:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:rbl:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:recvd#448844:Received");
		push(@tmp, "GPRINT:recvd:LAST:          Cur\\: $valform");
		push(@tmp, "GPRINT:recvd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:recvd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:recvd:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:spam#EEEE44:Spam");
		push(@tmp, "GPRINT:spam:LAST:              Cur\\: $valform");
		push(@tmp, "GPRINT:spam:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:spam:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:spam:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:virus#EE44EE:Virus");
		push(@tmp, "GPRINT:virus:LAST:             Cur\\: $valform");
		push(@tmp, "GPRINT:virus:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:virus:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:virus:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:bouncd#FFA500:Bounced");
		push(@tmp, "GPRINT:bouncd:LAST:           Cur\\: $valform");
		push(@tmp, "GPRINT:bouncd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:bouncd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:bouncd:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:discrd#CCCCCC:Discarded");
		push(@tmp, "GPRINT:discrd:LAST:         Cur\\: $valform");
		push(@tmp, "GPRINT:discrd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:discrd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:discrd:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:held#44EE44:Held");
		push(@tmp, "GPRINT:held:LAST:              Cur\\: $valform");
		push(@tmp, "GPRINT:held:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:held:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:held:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:n_forwrd#44EEEE:Forwarded");
		push(@tmp, "GPRINT:forwrd:LAST:         Cur\\: $valform");
		push(@tmp, "GPRINT:forwrd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:forwrd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:forwrd:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:n_delvd#4444EE:Delivered");
		push(@tmp, "GPRINT:delvd:LAST:         Cur\\: $valform");
		push(@tmp, "GPRINT:delvd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:delvd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:delvd:MAX:    Max\\: $valform\\n");
		push(@tmp, "LINE1:rejtd#EE0000");
		push(@tmp, "LINE1:rbl#963C74");
		push(@tmp, "LINE1:recvd#1F881F");
		push(@tmp, "LINE1:spam#EEEE00");
		push(@tmp, "LINE1:virus#EE00EE");
		push(@tmp, "LINE1:bouncd#FFA500");
		push(@tmp, "LINE1:discrd#888888");
		push(@tmp, "LINE1:held#00EE00");
		push(@tmp, "LINE1:n_forwrd#00EEEE");
		push(@tmp, "LINE1:n_delvd#0000EE");

		push(@tmpz, "AREA:rejtd#EE4444:Rejected");
		push(@tmpz, "AREA:rbl#963C74:Rejected (RBL)");
		push(@tmpz, "AREA:recvd#448844:Received");
		push(@tmpz, "AREA:spam#EEEE44:Spam");
		push(@tmpz, "AREA:virus#EE44EE:Virus");
		push(@tmpz, "AREA:bouncd#FFA500:Bounced");
		push(@tmpz, "AREA:discrd#888888:Discarded");
		push(@tmpz, "AREA:held#44EE44:Held");
		push(@tmpz, "AREA:n_forwrd#44EEEE:Forwarded");
		push(@tmpz, "AREA:n_delvd#4444EE:Delivered");
		push(@tmpz, "LINE1:rejtd#EE0000");
		push(@tmpz, "LINE1:rbl#963C74");
		push(@tmpz, "LINE1:recvd#1F881F");
		push(@tmpz, "LINE1:spam#EEEE00");
		push(@tmpz, "LINE1:virus#EE00EE");
		push(@tmpz, "LINE1:bouncd#FFA500");
		push(@tmpz, "LINE1:discrd#888888");
		push(@tmpz, "LINE1:held#00EE00");
		push(@tmpz, "LINE1:n_forwrd#00EEEE");
		push(@tmpz, "LINE1:n_delvd#0000EE");
	} elsif(lc($mail->{mta}) eq "exim") {
		push(@tmp, "AREA:in#44EE44:In Connections");
		push(@tmp, "GPRINT:in:LAST:    Cur\\: $valform");
		push(@tmp, "GPRINT:in:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:in:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:in:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:rejtd#EE4444:Rejected");
		push(@tmp, "GPRINT:rejtd:LAST:          Cur\\: $valform");
		push(@tmp, "GPRINT:rejtd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:rejtd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:rejtd:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:recvd#448844:Received");
		push(@tmp, "GPRINT:recvd:LAST:          Cur\\: $valform");
		push(@tmp, "GPRINT:recvd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:recvd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:recvd:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:spam#EEEE44:Spam");
		push(@tmp, "GPRINT:spam:LAST:              Cur\\: $valform");
		push(@tmp, "GPRINT:spam:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:spam:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:spam:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:virus#EE44EE:Virus");
		push(@tmp, "GPRINT:virus:LAST:             Cur\\: $valform");
		push(@tmp, "GPRINT:virus:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:virus:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:virus:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:n_delvd#4444EE:Delivered");
		push(@tmp, "GPRINT:delvd:LAST:         Cur\\: $valform");
		push(@tmp, "GPRINT:delvd:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:delvd:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:delvd:MAX:    Max\\: $valform\\n");
		push(@tmp, "AREA:n_out#44EEEE:Out Connections");
		push(@tmp, "GPRINT:out:LAST:   Cur\\: $valform");
		push(@tmp, "GPRINT:out:AVERAGE:    Avg\\: $valform");
		push(@tmp, "GPRINT:out:MIN:    Min\\: $valform");
		push(@tmp, "GPRINT:out:MAX:    Max\\: $valform\\n");
		push(@tmp, "LINE1:in#00EE00");
		push(@tmp, "LINE1:rejtd#EE0000");
		push(@tmp, "LINE1:recvd#1F881F");
		push(@tmp, "LINE1:spam#EEEE00");
		push(@tmp, "LINE1:virus#EE00EE");
		push(@tmp, "LINE1:n_delvd#0000EE");
		push(@tmp, "LINE1:n_out#00EEEE");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");

		push(@tmpz, "AREA:in#44EE44:In Connections");
		push(@tmpz, "AREA:rejtd#EE4444:Rejected");
		push(@tmpz, "AREA:recvd#448844:Received");
		push(@tmpz, "AREA:spam#EEEE44:Spam");
		push(@tmpz, "AREA:virus#EE44EE:Virus");
		push(@tmpz, "AREA:n_delvd#4444EE:Delivered");
		push(@tmpz, "AREA:n_out#44EEEE:Out Connections");
		push(@tmpz, "LINE1:in#00EE00");
		push(@tmpz, "LINE1:rejtd#EE0000");
		push(@tmpz, "LINE1:recvd#1F881F");
		push(@tmpz, "LINE1:spam#EEEE00");
		push(@tmpz, "LINE1:virus#EE00EE");
		push(@tmpz, "LINE1:n_delvd#0000EE");
		push(@tmpz, "LINE1:n_out#00EEEE");
	}
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata_p#$colors->{gap}:");
		push(@tmp, "AREA:wrongdata_m#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata_p#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata_m#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata_p=allvalues_p,UN,INF,UNKN,IF");
		push(@CDEF, "CDEF:wrongdata_m=allvalues_m,0,LT,INF,-1,*,UNKN,IF");
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
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG1",
		"--title=$config->{graphs}->{_mail1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=$rate_label",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:in=$rrd:mail_in:AVERAGE",
		"DEF:out=$rrd:mail_out:AVERAGE",
		"DEF:recvd=$rrd:mail_recvd:AVERAGE",
		"DEF:delvd=$rrd:mail_delvd:AVERAGE",
		"DEF:rejtd=$rrd:mail_rejtd:AVERAGE",
		"DEF:spam=$rrd:mail_spam:AVERAGE",
		"DEF:virus=$rrd:mail_virus:AVERAGE",
		"DEF:bouncd=$rrd:mail_bouncd:AVERAGE",
		"DEF:discrd=$rrd:mail_discrd:AVERAGE",
		"DEF:held=$rrd:mail_held:AVERAGE",
		"DEF:forwrd=$rrd:mail_forwrd:AVERAGE",
		"DEF:rbl=$rrd:mail_val05:AVERAGE",
		"CDEF:allvalues_p=in,out,recvd,delvd,rejtd,spam,virus,bouncd,discrd,held,forwrd,rbl,+,+,+,+,+,+,+,+,+,+,+",
		"CDEF:allvalues_m=allvalues_p,UN,-1,UNKN,IF",
		@CDEF,
		"CDEF:n_forwrd=forwrd,-1,*",
		"CDEF:n_delvd=delvd,-1,*",
		"CDEF:n_out=out,-1,*",
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_mail1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=$rate_label",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:in=$rrd:mail_in:AVERAGE",
			"DEF:out=$rrd:mail_out:AVERAGE",
			"DEF:recvd=$rrd:mail_recvd:AVERAGE",
			"DEF:delvd=$rrd:mail_delvd:AVERAGE",
			"DEF:rejtd=$rrd:mail_rejtd:AVERAGE",
			"DEF:spam=$rrd:mail_spam:AVERAGE",
			"DEF:virus=$rrd:mail_virus:AVERAGE",
			"DEF:bouncd=$rrd:mail_bouncd:AVERAGE",
			"DEF:discrd=$rrd:mail_discrd:AVERAGE",
			"DEF:held=$rrd:mail_held:AVERAGE",
			"DEF:forwrd=$rrd:mail_forwrd:AVERAGE",
			"DEF:rbl=$rrd:mail_val05:AVERAGE",
			"CDEF:allvalues_p=in,out,recvd,delvd,rejtd,spam,virus,bouncd,discrd,held,forwrd,rbl,+,+,+,+,+,+,+,+,+,+,+",
			"CDEF:allvalues_m=allvalues_p,UN,-1,UNKN,IF",
			@CDEF,
			"CDEF:n_forwrd=forwrd,-1,*",
			"CDEF:n_delvd=delvd,-1,*",
			"CDEF:n_out=out,-1,*",
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail1/)) {
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

	@riglim = @{setup_riglim($rigid[1], $limit[1])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:B_in#44EE44:K$T/s Received");
	push(@tmp, "GPRINT:K_in:LAST:      Cur\\: %5.0lf");
	push(@tmp, "GPRINT:K_in:AVERAGE:    Avg\\: %5.0lf");
	push(@tmp, "GPRINT:K_in:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:K_in:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "AREA:B_out#4444EE:K$T/s Delivered");
	push(@tmp, "GPRINT:K_out:LAST:     Cur\\: %5.0lf");
	push(@tmp, "GPRINT:K_out:AVERAGE:    Avg\\: %5.0lf");
	push(@tmp, "GPRINT:K_out:MIN:    Min\\: %5.0lf");
	push(@tmp, "GPRINT:K_out:MAX:    Max\\: %5.0lf\\n");
	push(@tmp, "AREA:B_out#4444EE:");
	push(@tmp, "AREA:B_in#44EE44:");
	push(@tmp, "LINE1:B_out#0000EE");
	push(@tmp, "LINE1:B_in#00EE00");
	push(@tmpz, "AREA:B_in#44EE44:Received");
	push(@tmpz, "AREA:B_out#4444EE:Delivered");
	push(@tmpz, "AREA:B_out#4444EE:");
	push(@tmpz, "AREA:B_in#44EE44:");
	push(@tmpz, "LINE1:B_out#0000EE");
	push(@tmpz, "LINE1:B_in#00EE00");
	if(lc($config->{netstats_in_bps}) eq "y") {
		push(@CDEF, "CDEF:B_in=in,8,*");
		if(lc($config->{netstats_mode} || "") eq "separated") {
			push(@CDEF, "CDEF:B_out=out,8,*,-1,*");
		} else {
			push(@CDEF, "CDEF:B_out=out,8,*");
		}
	} else {
		push(@CDEF, "CDEF:B_in=in");
		if(lc($config->{netstats_mode} || "") eq "separated") {
			push(@CDEF, "CDEF:B_out=out,-1,*");
		} else {
			push(@CDEF, "CDEF:B_out=out");
		}
	}
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
		push(@tmp, "COMMENT: \\n");
	}

	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_mail2}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:in=$rrd:mail_bytes_recvd:AVERAGE",
		"DEF:out=$rrd:mail_bytes_delvd:AVERAGE",
		"CDEF:allvalues=in,out,+",
		@CDEF,
		"CDEF:K_in=B_in,1024,/",
		"CDEF:K_out=B_out,1024,/",
		"COMMENT: \\n",
		@tmp,
		"COMMENT: \\n");
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_mail2}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:in=$rrd:mail_bytes_recvd:AVERAGE",
			"DEF:out=$rrd:mail_bytes_delvd:AVERAGE",
			"CDEF:allvalues=in,out,+",
			@CDEF,
			"CDEF:K_in=B_in,1024,/",
			"CDEF:K_out=B_out,1024,/",
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail2/)) {
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
		push(@output, "    <td class='td-valign-top'>\n");
	}
	@riglim = @{setup_riglim($rigid[2], $limit[2])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:queued#EEEE44:Queued");
	push(@tmp, "LINE1:queued#EEEE00");
	push(@tmp, "GPRINT:queued:LAST:               Current\\: %5.0lf\\n");
	push(@tmpz, "AREA:queued#EEEE44:Queued");
	push(@tmpz, "LINE1:queued#EEEE00");
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
		"--title=$config->{graphs}->{_mail3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Messages",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:queued=$rrd:mail_queued:AVERAGE",
		"CDEF:allvalues=queued",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_mail3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Messages",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:queued=$rrd:mail_queued:AVERAGE",
			"CDEF:allvalues=queued",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail3/)) {
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

	@riglim = @{setup_riglim($rigid[3], $limit[3])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:queues#44AAEE:Size in KB");
	push(@tmp, "LINE1:queues#00AAEE");
	push(@tmp, "GPRINT:K_queues:LAST:           Current\\: %5.1lf\\n");
	push(@tmpz, "AREA:queues#44AAEE:Size");
	push(@tmpz, "LINE1:queues#00AAEE");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG4",
		"--title=$config->{graphs}->{_mail4}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:queues=$rrd:mail_queues:AVERAGE",
		"CDEF:allvalues=queues",
		@CDEF,
		"CDEF:K_queues=queues,1024,/",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG4z",
			"--title=$config->{graphs}->{_mail4}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:queues=$rrd:mail_queues:AVERAGE",
			"CDEF:allvalues=queues",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail4/)) {
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

	@riglim = @{setup_riglim($rigid[4], $limit[4])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:none#4444EE:None");
	push(@tmp, "GPRINT:none:LAST:                 Current\\: %5.0lf\\n");
	push(@tmp, "LINE2:pass#44EE44:Pass");
	push(@tmp, "GPRINT:pass:LAST:                 Current\\: %5.0lf\\n");
	push(@tmp, "LINE2:softfail#EEEE44:SoftFail");
	push(@tmp, "GPRINT:softfail:LAST:             Current\\: %5.0lf\\n");
	push(@tmp, "LINE2:fail#EE4444:Fail");
	push(@tmp, "GPRINT:fail:LAST:                 Current\\: %5.0lf\\n");
	push(@tmpz, "LINE2:none#4444EE:None");
	push(@tmpz, "LINE2:pass#44EE44:Pass");
	push(@tmpz, "LINE2:softfail#EEEE44:SoftFail");
	push(@tmpz, "LINE2:fail#EE4444:Fail");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG5",
		"--title=$config->{graphs}->{_mail5}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Messages",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:none=$rrd:mail_val01:AVERAGE",
		"DEF:pass=$rrd:mail_val02:AVERAGE",
		"DEF:softfail=$rrd:mail_val03:AVERAGE",
		"DEF:fail=$rrd:mail_val04:AVERAGE",
		"CDEF:allvalues=none,pass,softfail,fail,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG5z",
			"--title=$config->{graphs}->{_mail5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Messages",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:none=$rrd:mail_val01:AVERAGE",
			"DEF:pass=$rrd:mail_val02:AVERAGE",
			"DEF:softfail=$rrd:mail_val03:AVERAGE",
			"DEF:fail=$rrd:mail_val04:AVERAGE",
			"CDEF:allvalues=none,pass,softfail,fail,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail5/)) {
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

	@riglim = @{setup_riglim($rigid[5], $limit[5])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	if(lc($mail->{greylist}) eq "milter-greylist") {
		push(@tmp, "AREA:greylisted#4444EE:Greylisted");
		push(@tmp, "GPRINT:greylisted:LAST:           Current\\: %5.0lf\\n");
		push(@tmp, "AREA:whitelisted#44EEEE:Whitelisted");
		push(@tmp, "GPRINT:whitelisted:LAST:          Current\\: %5.0lf\\n");
		push(@tmp, "LINE2:greylisted#0000EE");
		push(@tmp, "LINE2:whitelisted#00EEEE");
		push(@tmp, "LINE2:records#EE0000:Records");
		push(@tmp, "GPRINT:records:LAST:              Current\\: %5.0lf\\n");
		push(@tmpz, "AREA:greylisted#4444EE:Greylisted");
		push(@tmpz, "AREA:whitelisted#44EEEE:Whitelisted");
		push(@tmpz, "LINE2:greylisted#0000EE");
		push(@tmpz, "LINE2:whitelisted#00EEEE");
		push(@tmpz, "LINE2:records#EE0000:Records");
	}
	if(lc($mail->{greylist}) eq "postgrey") {
		push(@tmp, "LINE2:greylisted#0000EE:Greylisted");
		push(@tmp, "GPRINT:greylisted:LAST:           Current\\: $gl_valform\\n");
		push(@tmp, "LINE2:delayed#EEEE00:Delayed");
		push(@tmp, "GPRINT:delayed:LAST:              Current\\: $gl_valform\\n");
		push(@tmp, "LINE2:whitelisted#00EEEE:Whitelisted");
		push(@tmp, "GPRINT:whitelisted:LAST:          Current\\: $gl_valform\\n");
		push(@tmp, "LINE2:records#EE00EE:Passed");
		push(@tmp, "GPRINT:records:LAST:               Current\\: $gl_valform\\n");
		push(@tmpz, "LINE2:greylisted#0000EE:Greylisted");
		push(@tmpz, "LINE2:delayed#EEEE00:Delayed");
		push(@tmpz, "LINE2:whitelisted#00EEEE:Whitelisted");
		push(@tmpz, "LINE2:records#EE00EE:Passed");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG6",
		"--title=$config->{graphs}->{_mail6}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=$rate_label",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:records=$rrd:mail_val07:AVERAGE",
		"DEF:greylisted=$rrd:mail_val08:AVERAGE",
		"DEF:whitelisted=$rrd:mail_val09:AVERAGE",
		"DEF:delayed=$rrd:mail_val10:AVERAGE",
		"CDEF:allvalues=records,greylisted,whitelisted,delayed,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG6: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG6z",
			"--title=$config->{graphs}->{_mail6}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=$rate_label",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:records=$rrd:mail_val07:AVERAGE",
			"DEF:greylisted=$rrd:mail_val08:AVERAGE",
			"DEF:whitelisted=$rrd:mail_val09:AVERAGE",
			"DEF:delayed=$rrd:mail_val10:AVERAGE",
			"CDEF:allvalues=records,greylisted,whitelisted,delayed,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG6z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail6/)) {
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
		push(@output, "    </tr>\n");
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
