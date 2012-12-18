#!/usr/bin/env perl
#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2012 by Jordi Sanfeliu <jordi@fibranet.cat>
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

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
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
				"DS:mail_val01:COUNTER:120:0:U",
				"DS:mail_val02:COUNTER:120:0:U",
				"DS:mail_val03:COUNTER:120:0:U",
				"DS:mail_val04:COUNTER:120:0:U",
				"DS:mail_val05:COUNTER:120:0:U",
				"DS:mail_val06:GAUGE:120:0:U",
				"DS:mail_val07:GAUGE:120:0:U",
				"DS:mail_val08:GAUGE:120:0:U",
				"DS:mail_val09:GAUGE:120:0:U",
				"DS:mail_val10:GAUGE:120:0:U",
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

	$config->{mail_hist} = 0;
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
	my $gl_records;
	my $gl_greylisted;
	my $gl_whitelisted;
	my @mta_h = (0) x 15;
	my @mta = (0) x 15;
	my @gen = (0) x 10;

	my $n;
	my $mail_log_seekpos;
	my $mail_log_size;
	my $sa_log_seekpos;
	my $sa_log_size;
	my $clamav_log_seekpos;
	my $clamav_log_size = 0;
	my $rrdata = "N";

	# Read last MAIL data from historic
	($mail_log_seekpos, $sa_log_seekpos, $clamav_log_seekpos, @mta_h[0..15-1], @gen[0..10-1]) = split(';', $config->{mail_hist});
	$mail_log_seekpos = defined($mail_log_seekpos) ? int($mail_log_seekpos) : 0;
	$sa_log_seekpos = defined($sa_log_seekpos) ? int($sa_log_seekpos) : 0;
	$clamav_log_seekpos = defined($clamav_log_seekpos) ? int($clamav_log_seekpos) : 0;

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
				open(IN, "pflogsumm -d today -h 0 -u 0 --smtpd_stats --no_bounce_detail --no_deferral_detail --no_reject_detail --no_no_msg_size --no_smtpd_warnings $config->{mail_log} 2>/dev/null |");
			}
			if(-f "$path/pflogsumm.pl" && -x _) {
				open(IN, "pflogsumm.pl -d today -h 0 -u 0 --smtpd_stats --no_bounce_detail --no_deferral_detail --no_reject_detail --no_no_msg_size --no_smtpd_warnings $config->{mail_log} 2>/dev/null |");
			}
		}
		@data = <IN>;
		close(IN);
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
	}

	$gl_records = $gl_greylisted = $gl_whitelisted = 0;
	if(lc($mail->{greylist}) eq "milter-greylist") {
		if(-r $config->{milter_gl}) {
			open(IN, $config->{milter_gl});
			if(!seek(IN, -80, 2)) {
				logger("Couldn't seek to the end ($config->{milter_gl}): $!");
				return;
			}
			while(<IN>) {
				if(/^# Summary:\s+(\d+) records,\s+(\d+) greylisted,\s+(\d+) whitelisted$/) {
					$gl_records = $1;
					$gl_greylisted = $2;
					$gl_whitelisted = $3;
				}
			}
			close(IN);
		}
	}

	$spam = $virus = 0;
	if(-r $config->{mail_log}) {
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
			if(/MailScanner/ && /Spam Checks:/ && /Found/ && /spam messages/) {
				@line = split(' ', $_);
				$spam += int($line[8]);
			}
			if(/MailScanner/ && /Virus Scanning:/ && /Found/ && /viruses/) {
				@line = split(' ', $_);
				$virus += int($line[8]);
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
	$mta[0] /= 60;
	$mta_h[0] = int($in_conn);

	$mta[1] = int($out_conn) - ($mta_h[1] || 0);
	$mta[1] = 0 unless $mta[1] != int($out_conn);
	$mta[1] /= 60;
	$mta_h[1] = int($out_conn);

	$mta[2] = int($recvd) - ($mta_h[2] || 0);
	$mta[2] = 0 unless $mta[2] != int($recvd);
	$mta[2] /= 60;
	$mta_h[2] = int($recvd);

	$mta[3] = int($delvd) - ($mta_h[3] || 0);
	$mta[3] = 0 unless $mta[3] != int($delvd);
	$mta[3] /= 60;
	$mta_h[3] = int($delvd);

	$mta[4] = int($bytes_recvd) - ($mta_h[4] || 0);
	$mta[4] = 0 unless $mta[4] != int($bytes_recvd);
	$mta[4] /= 60;
	$mta_h[4] = int($bytes_recvd);

	$mta[5] = int($bytes_delvd) - ($mta_h[5] || 0);
	$mta[5] = 0 unless $mta[5] != int($bytes_delvd);
	$mta[5] /= 60;
	$mta_h[5] = int($bytes_delvd);

	$mta[6] = int($rejtd) - ($mta_h[6] || 0);
	$mta[6] = 0 unless $mta[6] != int($rejtd);
	$mta[6] /= 60;
	$mta_h[6] = int($rejtd);

	# avoid initial spike
	$mta[7] = int($spam) unless !$mta_h[7];
	$mta_h[7] = int($spam) unless $mta_h[7];
	$mta[7] /= 60;

	# avoid initial spike
	$mta[8] = int($virus) unless !$mta_h[8];
	$mta_h[8] = int($virus) unless $mta_h[8];
	$mta[8] /= 60;

	$mta[9] = int($bouncd) - ($mta_h[9] || 0);
	$mta[9] = 0 unless $mta[9] != int($bouncd);
	$mta[9] /= 60;
	$mta_h[9] = int($bouncd);

	$mta[10] = int($queued) || 0;
	$mta_h[10] = 0;

	$mta[11] = int($discrd) - ($mta_h[11] || 0);
	$mta[11] = 0 unless $mta[11] != int($discrd);
	$mta[11] /= 60;
	$mta_h[11] = int($discrd);

	$mta[12] = int($held) - ($mta_h[12] || 0);
	$mta[12] = 0 unless $mta[12] != int($held);
	$mta[12] /= 60;
	$mta_h[12] = int($held);

	$mta[13] = int($forwrd) - ($mta_h[13] || 0);
	$mta[13] = 0 unless $mta[13] != int($forwrd);
	$mta[13] /= 60;
	$mta_h[13] = int($forwrd);

	$mta[14] = int($queues) || 0;
	$mta_h[14] = 0;

	$gen[0] = 0;
	$gen[1] = 0;
	$gen[2] = 0;
	$gen[3] = 0;
	$gen[4] = 0;
	$gen[5] = int($gl_records) || 0;
	$gen[6] = 0;
	$gen[7] = int($gl_greylisted) || 0;
	$gen[8] = int($gl_whitelisted) || 0;
	$gen[9] = 0;

	$config->{mail_hist} = join(";", $mail_log_size, $sa_log_size, $clamav_log_size, @mta_h, @gen);
	for($n = 0; $n < 15; $n++) {
		$rrdata .= ":" . $mta[$n];
	}
	for($n = 0; $n < 10; $n++) {
		$rrdata .= ":" . $gen[$n];
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub mail_cgi {
	my ($package, $config, $cgi) = @_;

	my $mail = $config->{mail};
	my @rigid = split(',', $mail->{rigid});
	my @limit = split(',', $mail->{limit});
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};

	my $u = "";
	my $width;
	my $height;
	my @riglim;
	my $T = "B";
	my $vlabel = "bytes/s";
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $n;
	my $str;
	my $err;

	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	$title = !$silent ? $title : "";

	if(lc($config->{netstats_in_bps}) eq "y") {
		$T = "b";
		$vlabel = "bits/s";
	}


	# mode text
	#
	if(lc($config->{iface_mode}) eq "text") {
		if($title) {
			main::graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$colors->{title_bg_color}'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"AVERAGE",
			"-r $tf->{res}");
		$err = RRDs::error;
		print("ERROR: while fetching $rrd: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		print("Time  In.Conn Out.Conn  Receivd   Delivd  Bytes.R  Bytes.D  Rejectd  Bounced  Discard     Held  Forward     Spam    Virus   Queued  Queue.S\n");
		print("------------------------------------------------------------------------------------------------------------------------------------------- \n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			my ($in, $out, $recvd, $delvd, $bytes_recvd, $bytes_delvd, $rejtd, $spam, $virus, $bouncd, $queued, $discrd, $held, $forwrd, $queues) = @$line;
			@row = ($in, $out, $recvd, $delvd, $bytes_recvd, $bytes_delvd, $rejtd, $bouncd, $discrd, $held, $forwrd, $spam, $virus, $queued, $queues);
			printf(" %2d$tf->{tc}  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f  %7.2f\n", $time, @row);
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			main::graph_footer();
		}
		print("  <br>\n");
		return;
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

	my $PNG1 = $u . $package . "1." . $tf->{when} . ".png";
	my $PNG2 = $u . $package . "2." . $tf->{when} . ".png";
	my $PNG3 = $u . $package . "3." . $tf->{when} . ".png";
	my $PNG4 = $u . $package . "4." . $tf->{when} . ".png";
	my $PNG5 = $u . $package . "5." . $tf->{when} . ".png";
	my $PNG1z = $u . $package . "1z." . $tf->{when} . ".png";
	my $PNG2z = $u . $package . "2z." . $tf->{when} . ".png";
	my $PNG3z = $u . $package . "3z." . $tf->{when} . ".png";
	my $PNG4z = $u . $package . "4z." . $tf->{when} . ".png";
	my $PNG5z = $u . $package . "5z." . $tf->{when} . ".png";
	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3",
		"$PNG_DIR" . "$PNG4",
		"$PNG_DIR" . "$PNG5");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z",
			"$PNG_DIR" . "$PNG4z",
			"$PNG_DIR" . "$PNG5z");
	}

	if($title) {
		main::graph_header($title, 2);
	}
	if(trim($rigid[0]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[0]));
	} else {
		if(trim($rigid[0]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[0]));
			push(@riglim, "--rigid");
		}
	}
	if(lc($mail->{mta}) eq "sendmail") {
		push(@tmp, "AREA:in#44EE44:In Connections");
		push(@tmp, "GPRINT:in:LAST:    Cur\\: %5.2lf");
		push(@tmp, "GPRINT:in:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:in:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:in:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:rejtd#EE4444:Rejected");
		push(@tmp, "GPRINT:rejtd:LAST:          Cur\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:recvd#448844:Received");
		push(@tmp, "GPRINT:recvd:LAST:          Cur\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:spam#EEEE44:Spam");
		push(@tmp, "GPRINT:spam:LAST:              Cur\\: %5.2lf");
		push(@tmp, "GPRINT:spam:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:spam:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:spam:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:virus#EE44EE:Virus");
		push(@tmp, "GPRINT:virus:LAST:             Cur\\: %5.2lf");
		push(@tmp, "GPRINT:virus:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:virus:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:virus:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:n_delvd#4444EE:Delivered");
		push(@tmp, "GPRINT:delvd:LAST:         Cur\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:n_out#44EEEE:Out Connections");
		push(@tmp, "GPRINT:out:LAST:   Cur\\: %5.2lf");
		push(@tmp, "GPRINT:out:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:out:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:out:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "LINE1:in#00EE00");
		push(@tmp, "LINE1:rejtd#EE0000");
		push(@tmp, "LINE1:recvd#1F881F");
		push(@tmp, "LINE1:spam#EEEE00");
		push(@tmp, "LINE1:virus#EE00EE");
		push(@tmp, "LINE1:n_delvd#0000EE");
		push(@tmp, "LINE1:n_out#00EEEE");

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
		push(@tmp, "GPRINT:rejtd:LAST:          Cur\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:rejtd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:recvd#448844:Received");
		push(@tmp, "GPRINT:recvd:LAST:          Cur\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:recvd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:spam#EEEE44:Spam");
		push(@tmp, "GPRINT:spam:LAST:              Cur\\: %5.2lf");
		push(@tmp, "GPRINT:spam:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:spam:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:spam:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:virus#EE44EE:Virus");
		push(@tmp, "GPRINT:virus:LAST:             Cur\\: %5.2lf");
		push(@tmp, "GPRINT:virus:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:virus:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:virus:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:bouncd#FFA500:Bounced");
		push(@tmp, "GPRINT:bouncd:LAST:           Cur\\: %5.2lf");
		push(@tmp, "GPRINT:bouncd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:bouncd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:bouncd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:discrd#CCCCCC:Discarded");
		push(@tmp, "GPRINT:discrd:LAST:         Cur\\: %5.2lf");
		push(@tmp, "GPRINT:discrd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:discrd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:discrd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:held#44EE44:Held");
		push(@tmp, "GPRINT:held:LAST:              Cur\\: %5.2lf");
		push(@tmp, "GPRINT:held:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:held:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:held:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:n_forwrd#44EEEE:Forwarded");
		push(@tmp, "GPRINT:forwrd:LAST:         Cur\\: %5.2lf");
		push(@tmp, "GPRINT:forwrd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:forwrd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:forwrd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "AREA:n_delvd#4444EE:Delivered");
		push(@tmp, "GPRINT:delvd:LAST:         Cur\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:AVERAGE:    Avg\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:MIN:    Min\\: %5.2lf");
		push(@tmp, "GPRINT:delvd:MAX:    Max\\: %5.2lf\\n");
		push(@tmp, "LINE1:rejtd#EE0000");
		push(@tmp, "LINE1:recvd#1F881F");
		push(@tmp, "LINE1:spam#EEEE00");
		push(@tmp, "LINE1:virus#EE00EE");
		push(@tmp, "LINE1:bouncd#FFA500");
		push(@tmp, "LINE1:discrd#888888");
		push(@tmp, "LINE1:held#00EE00");
		push(@tmp, "LINE1:n_forwrd#00EEEE");
		push(@tmp, "LINE1:n_delvd#0000EE");

		push(@tmpz, "AREA:rejtd#EE4444:Rejected");
		push(@tmpz, "AREA:recvd#448844:Received");
		push(@tmpz, "AREA:spam#EEEE44:Spam");
		push(@tmpz, "AREA:virus#EE44EE:Virus");
		push(@tmpz, "AREA:bouncd#FFA500:Bounced");
		push(@tmpz, "AREA:discrd#888888:Discarded");
		push(@tmpz, "AREA:held#44EE44:Held");
		push(@tmpz, "AREA:n_forwrd#44EEEE:Forwarded");
		push(@tmpz, "AREA:n_delvd#4444EE:Delivered");
		push(@tmpz, "LINE1:rejtd#EE0000");
		push(@tmpz, "LINE1:recvd#1F881F");
		push(@tmpz, "LINE1:spam#EEEE00");
		push(@tmpz, "LINE1:virus#EE00EE");
		push(@tmpz, "LINE1:bouncd#FFA500");
		push(@tmpz, "LINE1:discrd#888888");
		push(@tmpz, "LINE1:held#00EE00");
		push(@tmpz, "LINE1:n_forwrd#00EEEE");
		push(@tmpz, "LINE1:n_delvd#0000EE");
	}

	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$colors->{title_bg_color}'>\n");
	}
	($width, $height) = split('x', $config->{graph_size}->{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$config->{graphs}->{_mail1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Messages/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:in=$rrd:mail_in:AVERAGE",
		"DEF:out=$rrd:mail_out:AVERAGE",
		"DEF:recvd=$rrd:mail_recvd:AVERAGE",
		"DEF:delvd=$rrd:mail_delvd:AVERAGE",
		"DEF:bytes_recvd=$rrd:mail_bytes_recvd:AVERAGE",
		"DEF:bytes_delvd=$rrd:mail_bytes_delvd:AVERAGE",
		"DEF:rejtd=$rrd:mail_rejtd:AVERAGE",
		"DEF:spam=$rrd:mail_spam:AVERAGE",
		"DEF:virus=$rrd:mail_virus:AVERAGE",
		"DEF:bouncd=$rrd:mail_bouncd:AVERAGE",
		"DEF:discrd=$rrd:mail_discrd:AVERAGE",
		"DEF:held=$rrd:mail_held:AVERAGE",
		"DEF:forwrd=$rrd:mail_forwrd:AVERAGE",
		"CDEF:n_forwrd=forwrd,-1,*",
		"CDEF:n_delvd=delvd,-1,*",
		"CDEF:n_out=out,-1,*",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$config->{graphs}->{_mail1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Messages/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:in=$rrd:mail_in:AVERAGE",
			"DEF:out=$rrd:mail_out:AVERAGE",
			"DEF:recvd=$rrd:mail_recvd:AVERAGE",
			"DEF:delvd=$rrd:mail_delvd:AVERAGE",
			"DEF:bytes_recvd=$rrd:mail_bytes_recvd:AVERAGE",
			"DEF:bytes_delvd=$rrd:mail_bytes_delvd:AVERAGE",
			"DEF:rejtd=$rrd:mail_rejtd:AVERAGE",
			"DEF:spam=$rrd:mail_spam:AVERAGE",
			"DEF:virus=$rrd:mail_virus:AVERAGE",
			"DEF:bouncd=$rrd:mail_bouncd:AVERAGE",
			"DEF:discrd=$rrd:mail_discrd:AVERAGE",
			"DEF:held=$rrd:mail_held:AVERAGE",
			"DEF:forwrd=$rrd:mail_forwrd:AVERAGE",
			"CDEF:n_forwrd=forwrd,-1,*",
			"CDEF:n_delvd=delvd,-1,*",
			"CDEF:n_out=out,-1,*",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNG1z . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNG1z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG1 . "'>\n");
		}
	}

	undef(@riglim);
	if(trim($rigid[1]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[1]));
	} else {
		if(trim($rigid[1]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[1]));
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
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
		push(@CDEF, "CDEF:B_out=out,8,*");
	} else {
		push(@CDEF, "CDEF:B_in=in");
		push(@CDEF, "CDEF:B_out=out");
	}
	($width, $height) = split('x', $config->{graph_size}->{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
	}

	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$config->{graphs}->{_mail2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:in=$rrd:mail_bytes_recvd:AVERAGE",
		"DEF:out=$rrd:mail_bytes_delvd:AVERAGE",
		@CDEF,
		"CDEF:K_in=B_in,1024,/",
		"CDEF:K_out=B_out,1024,/",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$config->{graphs}->{_mail2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:in=$rrd:mail_bytes_recvd:AVERAGE",
			"DEF:out=$rrd:mail_bytes_delvd:AVERAGE",
			@CDEF,
			"CDEF:K_in=B_in,1024,/",
			"CDEF:K_out=B_out,1024,/",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNG2z . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNG2z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG2 . "'>\n");
		}
	}
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}

	undef(@riglim);
	if(trim($rigid[2]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[2]));
	} else {
		if(trim($rigid[2]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[2]));
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:queued#EEEE44:Queued");
	push(@tmp, "LINE1:queued#EEEE00");
	push(@tmp, "GPRINT:queued:LAST:               Current\\: %5.0lf\\n");
	push(@tmpz, "AREA:queued#EEEE44:Queued");
	push(@tmpz, "LINE1:queued#EEEE00");
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$config->{graphs}->{_mail3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Messages",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:queued=$rrd:mail_queued:AVERAGE",
		"COMMENT: \\n",
		@tmp,
		"COMMENT: \\n",
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$config->{graphs}->{_mail3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Messages",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:queued=$rrd:mail_queued:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail3/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNG3z . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNG3z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG3 . "'>\n");
		}
	}

	undef(@riglim);
	if(trim($rigid[3]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[3]));
	} else {
		if(trim($rigid[3]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[3]));
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:queues#44AAEE:Size in KB");
	push(@tmp, "LINE1:queues#00AAEE");
	push(@tmp, "GPRINT:K_queues:LAST:           Current\\: %5.1lf\\n");
	push(@tmpz, "AREA:queues#44AAEE:Size");
	push(@tmpz, "LINE1:queues#00AAEE");
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG4",
		"--title=$config->{graphs}->{_mail4}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Bytes",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:queues=$rrd:mail_queues:AVERAGE",
		"CDEF:K_queues=queues,1024,/",
		"COMMENT: \\n",
		@tmp,
		"COMMENT: \\n",
		"COMMENT: \\n");
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG4: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG4z",
			"--title=$config->{graphs}->{_mail4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Bytes",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:queues=$rrd:mail_queues:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail4/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNG4z . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG4 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNG4z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG4 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG4 . "'>\n");
		}
	}

	undef(@riglim);
	if(trim($rigid[4]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[4]));
	} else {
		if(trim($rigid[4]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[4]));
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:greylisted#4444EE:Greylisted");
	push(@tmp, "GPRINT:greylisted:LAST:           Current\\: %5.0lf\\n");
	push(@tmp, "AREA:whitelisted#44EEEE:Whitelisted");
	push(@tmp, "GPRINT:whitelisted:LAST:          Current\\: %5.0lf\\n");
	push(@tmp, "LINE1:greylisted#0000EE");
	push(@tmp, "LINE1:whitelisted#00EEEE");
	push(@tmp, "LINE1:records#EE0000:Records");
	push(@tmp, "GPRINT:records:LAST:              Current\\: %5.0lf\\n");
	push(@tmpz, "AREA:greylisted#4444EE:Greylisted");
	push(@tmpz, "AREA:whitelisted#44EEEE:Whitelisted");
	push(@tmpz, "LINE2:greylisted#0000EE");
	push(@tmpz, "LINE2:whitelisted#00EEEE");
	push(@tmpz, "LINE2:records#EE0000:Records");
	if(lc($mail->{mta}) eq "postfix") {
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
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
	RRDs::graph("$PNG_DIR" . "$PNG5",
		"--title=$config->{graphs}->{_mail5}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Messages",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:records=$rrd:mail_val07:AVERAGE",
		"DEF:greylisted=$rrd:mail_val08:AVERAGE",
		"DEF:whitelisted=$rrd:mail_val09:AVERAGE",
		"COMMENT: \\n",
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG5: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG5z",
			"--title=$config->{graphs}->{_mail5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Messages",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:records=$rrd:mail_val07:AVERAGE",
			"DEF:greylisted=$rrd:mail_val08:AVERAGE",
			"DEF:whitelisted=$rrd:mail_val09:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /mail5/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNG5z . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG5 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNG5z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG5 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG5 . "'>\n");
		}
	}

	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		main::graph_footer();
	}
	print("  <br>\n");
	return;
}

1;
