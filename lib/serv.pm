#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2013 by Jordi Sanfeliu <jordi@fibranet.cat>
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

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
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
				"RRA:AVERAGE:0.5:288:365",
				"RRA:MIN:0.5:1:288",
				"RRA:MIN:0.5:6:336",
				"RRA:MIN:0.5:12:744",
				"RRA:MIN:0.5:288:365",
				"RRA:MAX:0.5:1:288",
				"RRA:MAX:0.5:6:336",
				"RRA:MAX:0.5:12:744",
				"RRA:MAX:0.5:288:365",
				"RRA:LAST:0.5:1:288",
				"RRA:LAST:0.5:6:336",
				"RRA:LAST:0.5:12:744",
				"RRA:LAST:0.5:288:365",
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

	my $date;
	my $rrdata = "N";

	# This graph is refreshed only every 5 minutes
	my (undef, $min) = localtime(time);
	return if($min % 5);

	if(-r $config->{secure_log}) {
		$date = strftime("%b %e", localtime);
		open(IN, "$config->{secure_log}");
		while(<IN>) {
			if(/^$date/) {
				if(/ sshd\[/ && /Accepted /) {
					$ssh++;
				}
				if($config->{os} eq "Linux") {
					if(/START: pop3/) {
						$pop3++;
					}
					if(/START: ftp/ ||
					  (/ proftpd\[/ && /Login successful./)) {
						$ftp++;
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
		}
		close(IN);
	}

	if(-r $config->{imap_log}) {
		$config->{imap_date_log_format} = $config->{imap_date_log_format} || "%b %d";
		my $date_dovecot = strftime($config->{imap_date_log_format}, localtime);
		my $date_uw = strftime("%b %e %T", localtime);
		open(IN, "$config->{imap_log}");
		while(<IN>) {
			# UW-IMAP log
			if(/$date_uw/) {
				if(/ imapd\[/ && / Login user=/) {
					$imap++;
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
			if(/^$date/ && / fail2ban/ && / WARNING / && / Ban /) {
				$f2b++;
			}
		}
		close(IN);
	}

	if(-r $config->{mail_log}) {
		$date = strftime("%b %e", localtime);
		open(IN, "$config->{mail_log}");
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
			}
		}
		close(IN);
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
		open(IN, $config->{spamassassin_log});
		while(<IN>) {
			if(/^$date/ && /spamd: identified spam/) {
				$spam++;
			}
		}
		close(IN);
	}

	if(-r $config->{clamav_log}) {
		$date = strftime("%a %b %e", localtime);
		open(IN, $config->{clamav_log});
		while(<IN>) {
			if(/^$date/ && / FOUND/) {
				$virus++;
			}
		}
		close(IN);
	}

	# I data (incremental)
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

	$l_ssh = $ssh - ($config->{serv_hist}->{'ssh'} || 0);
	$l_ssh = 0 unless $l_ssh != $ssh;
	$l_ssh /= 300;
	$config->{serv_hist}->{'ssh'} = $ssh;

	$l_ftp = $ftp - ($config->{serv_hist}->{'ftp'} || 0);
	$l_ftp = 0 unless $l_ftp != $ftp;
	$l_ftp /= 300;
	$config->{serv_hist}->{'ftp'} = $ftp;

	$l_telnet = $telnet - ($config->{serv_hist}->{'telnet'} || 0);
	$l_telnet = 0 unless $l_telnet != $telnet;
	$l_telnet /= 300;
	$config->{serv_hist}->{'telnet'} = $telnet;

	$l_imap = $imap - ($config->{serv_hist}->{'imap'} || 0);
	$l_imap = 0 unless $l_imap != $imap;
	$l_imap /= 300;
	$config->{serv_hist}->{'imap'} = $imap;

	$l_smb = $smb - ($config->{serv_hist}->{'smb'} || 0);
	$l_smb = 0 unless $l_smb != $smb;
	$l_smb /= 300;
	$config->{serv_hist}->{'smb'} = $smb;

	$l_fax = $fax - ($config->{serv_hist}->{'fax'} || 0);
	$l_fax = 0 unless $l_fax != $fax;
	$l_fax /= 300;
	$config->{serv_hist}->{'fax'} = $fax;

	$l_cups = $cups - ($config->{serv_hist}->{'cups'} || 0);
	$l_cups = 0 unless $l_cups != $cups;
	$l_cups /= 300;
	$config->{serv_hist}->{'cups'} = $cups;

	$l_pop3 = $pop3 - ($config->{serv_hist}->{'pop3'} || 0);
	$l_pop3 = 0 unless $l_pop3 != $pop3;
	$l_pop3 /= 300;
	$config->{serv_hist}->{'pop3'} = $pop3;

	$l_smtp = $smtp - ($config->{serv_hist}->{'smtp'} || 0);
	$l_smtp = 0 unless $l_smtp != $smtp;
	$l_smtp /= 300;
	$config->{serv_hist}->{'smtp'} = $smtp;

	$l_spam = $spam - ($config->{serv_hist}->{'spam'} || 0);
	$l_spam = 0 unless $l_spam != $spam;
	$l_spam /= 300;
	$config->{serv_hist}->{'spam'} = $spam;

	$l_virus = $virus - ($config->{serv_hist}->{'virus'} || 0);
	$l_virus = 0 unless $l_virus != $virus;
	$l_virus /= 300;
	$config->{serv_hist}->{'virus'} = $virus;

	$l_f2b = $f2b - ($config->{serv_hist}->{'f2b'} || 0);
	$l_f2b = 0 unless $l_f2b != $f2b;
	$l_f2b /= 300;
	$config->{serv_hist}->{'f2b'} = $f2b;

	$l_val02 = $val02 - ($config->{serv_hist}->{'val02'} || 0);
	$l_val02 = 0 unless $l_val02 != $val02;
	$l_val02 /= 300;
	$config->{serv_hist}->{'val02'} = $val02;

	$l_val03 = $val03 - ($config->{serv_hist}->{'val03'} || 0);
	$l_val03 = 0 unless $l_val03 != $val03;
	$l_val03 /= 300;
	$config->{serv_hist}->{'val03'} = $val03;

	$l_val04 = $val04 - ($config->{serv_hist}->{'val04'} || 0);
	$l_val04 = 0 unless $l_val04 != $val04;
	$l_val04 /= 300;
	$config->{serv_hist}->{'val04'} = $val04;

	$l_val05 = $val05 - ($config->{serv_hist}->{'val05'} || 0);
	$l_val05 = 0 unless $l_val05 != $val05;
	$l_val05 /= 300;
	$config->{serv_hist}->{'val05'} = $val05;

	$rrdata .= ":$l_ssh:$l_ftp:$l_telnet:$l_imap:$l_smb:$l_fax:$l_cups:$l_pop3:$l_smtp:$l_spam:$l_virus:$l_f2b:$l_val02:$l_val03:$l_val04:$l_val05";
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub serv_cgi {
	my ($package, $config, $cgi) = @_;

	my $serv = $config->{serv};
	my @rigid = split(',', $serv->{rigid});
	my @limit = split(',', $serv->{limit});
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};

	my $u = "";
	my $width;
	my $height;
	my @riglim;
	my $vlabel;
	my @tmp;
	my @tmpz;
	my $n;
	my $str;
	my $err;

	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	$title = !$silent ? $title : "";


	# text mode
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
		if(lc($serv->{mode}) eq "i") {
			print "Values expressed as incremental or cumulative hits.\n";
		}
		print("Time    SSH     FTP  Telnet   Samba     Fax    CUPS     F2B    IMAP    POP3    SMTP    Spam   Virus\n");
		print("--------------------------------------------------------------------------------------------------- \n");
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
				printf(" %2d$tf->{tc} %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d\n", $time, @row);
			} elsif(lc($serv->{mode}) eq "l") {
				printf(" %2d$tf->{tc} %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f\n", $time, @row);
			}
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
	my $PNG1z = $u . $package . "1z." . $tf->{when} . ".png";
	my $PNG2z = $u . $package . "2z." . $tf->{when} . ".png";
	my $PNG3z = $u . $package . "3z." . $tf->{when} . ".png";
	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
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
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$config->{graphs}->{_serv1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
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
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$config->{graphs}->{_serv1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
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
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /serv1/)) {
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

	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
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
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$config->{graphs}->{_serv2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:i_imap=$rrd:serv_i_imap:AVERAGE",
		"DEF:l_imap=$rrd:serv_l_imap:AVERAGE",
		"DEF:i_pop3=$rrd:serv_i_pop3:AVERAGE",
		"DEF:l_pop3=$rrd:serv_l_pop3:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$config->{graphs}->{_serv2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:i_imap=$rrd:serv_i_imap:AVERAGE",
			"DEF:l_imap=$rrd:serv_l_imap:AVERAGE",
			"DEF:i_pop3=$rrd:serv_i_pop3:AVERAGE",
			"DEF:l_pop3=$rrd:serv_l_pop3:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /serv2/)) {
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
		"--title=$config->{graphs}->{_serv3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:i_smtp=$rrd:serv_i_smtp:AVERAGE",
		"DEF:i_spam=$rrd:serv_i_spam:AVERAGE",
		"DEF:i_virus=$rrd:serv_i_virus:AVERAGE",
		"DEF:l_smtp=$rrd:serv_l_smtp:AVERAGE",
		"DEF:l_spam=$rrd:serv_l_spam:AVERAGE",
		"DEF:l_virus=$rrd:serv_l_virus:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		undef(@tmp);
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$config->{graphs}->{_serv3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:i_smtp=$rrd:serv_i_smtp:AVERAGE",
			"DEF:i_spam=$rrd:serv_i_spam:AVERAGE",
			"DEF:i_virus=$rrd:serv_i_virus:AVERAGE",
			"DEF:l_smtp=$rrd:serv_l_smtp:AVERAGE",
			"DEF:l_spam=$rrd:serv_l_spam:AVERAGE",
			"DEF:l_virus=$rrd:serv_l_virus:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /serv3/)) {
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

	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		main::graph_footer();
	}
	print("  <br>\n");
	return;
}

1;
