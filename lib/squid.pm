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

package squid;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(squid_init squid_update squid_cgi);

sub squid_init {
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
				"--step=60",
				"DS:squid_g1_1:GAUGE:120:0:U",
				"DS:squid_g1_2:GAUGE:120:0:U",
				"DS:squid_g1_3:GAUGE:120:0:U",
				"DS:squid_g1_4:GAUGE:120:0:U",
				"DS:squid_g1_5:GAUGE:120:0:U",
				"DS:squid_g1_6:GAUGE:120:0:U",
				"DS:squid_g1_7:GAUGE:120:0:U",
				"DS:squid_g1_8:GAUGE:120:0:U",
				"DS:squid_g1_9:GAUGE:120:0:U",
				"DS:squid_g2_1:GAUGE:120:0:U",
				"DS:squid_g2_2:GAUGE:120:0:U",
				"DS:squid_g2_3:GAUGE:120:0:U",
				"DS:squid_g2_4:GAUGE:120:0:U",
				"DS:squid_g2_5:GAUGE:120:0:U",
				"DS:squid_g2_6:GAUGE:120:0:U",
				"DS:squid_g2_7:GAUGE:120:0:U",
				"DS:squid_g2_8:GAUGE:120:0:U",
				"DS:squid_g2_9:GAUGE:120:0:U",
				"DS:squid_rq_1:GAUGE:120:0:U",
				"DS:squid_rq_2:GAUGE:120:0:U",
				"DS:squid_rq_3:GAUGE:120:0:U",
				"DS:squid_rq_4:GAUGE:120:0:U",
				"DS:squid_rq_5:GAUGE:120:0:U",
				"DS:squid_rq_6:GAUGE:120:0:U",
				"DS:squid_rq_7:GAUGE:120:0:U",
				"DS:squid_rq_8:GAUGE:120:0:U",
				"DS:squid_rq_9:GAUGE:120:0:U",
				"DS:squid_m_1:GAUGE:120:0:U",
				"DS:squid_m_2:GAUGE:120:0:U",
				"DS:squid_m_3:GAUGE:120:0:U",
				"DS:squid_m_4:GAUGE:120:0:U",
				"DS:squid_m_5:GAUGE:120:0:U",
				"DS:squid_ic_1:GAUGE:120:0:U",
				"DS:squid_ic_2:GAUGE:120:0:U",
				"DS:squid_ic_3:GAUGE:120:0:U",
				"DS:squid_ic_4:GAUGE:120:0:U",
				"DS:squid_ic_5:GAUGE:120:0:U",
				"DS:squid_io_1:GAUGE:120:0:U",
				"DS:squid_io_2:GAUGE:120:0:U",
				"DS:squid_io_3:GAUGE:120:0:U",
				"DS:squid_io_4:GAUGE:120:0:U",
				"DS:squid_io_5:GAUGE:120:0:U",
				"DS:squid_s_1:GAUGE:120:0:U",
				"DS:squid_s_2:GAUGE:120:0:U",
				"DS:squid_s_3:GAUGE:120:0:U",
				"DS:squid_s_4:GAUGE:120:0:U",
				"DS:squid_s_5:GAUGE:120:0:U",
				"DS:squid_tc_1:GAUGE:120:0:U",
				"DS:squid_tc_2:GAUGE:120:0:U",
				"DS:squid_tc_3:GAUGE:120:0:U",
				"DS:squid_ts_1:GAUGE:120:0:U",
				"DS:squid_ts_2:GAUGE:120:0:U",
				"DS:squid_ts_3:GAUGE:120:0:U",
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

	$config->{squid_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub squid_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $squid = $config->{squid};

	my %g12 = ();
	my $seek_pos;
	my $logsize;
	my @data;
	my $all;
	my $value;
	my $g_result;
	my $g_status;

	my $rq_client_http_req = 0;
	my $rq_client_http_hit = 0;
	my $rq_server_http_req = 0;
	my $rq_server_ftp_req = 0;
	my $rq_server_other_req = 0;
	my $rq_aborted_req = 0;
	my $rq_swap_files_cleaned = 0;
	my $rq_unlink_requests = 0;

	my $tc_client_http_in = 0;
	my $tc_client_http_out = 0;
	my $ts_server_all_in = 0;
	my $ts_server_all_out = 0;

	my $m_alloc = 0;
	my $m_inuse = 0;

	my $ic_requests = 0;
	my $ic_hits = 0;
	my $ic_misses = 0;

	my $io_http = 0;
	my $io_ftp = 0;
	my $io_gopher = 0;
	my $io_wais = 0;

	my $s_entries = 0;
	my $s_maximum = 0;
	my $s_current = 0;

	my $n;
	my $rrdata = "N";

	$seek_pos = $config->{squid_hist}->{'seek_pos'} || 0;
	open(IN, $config->{squid_log});
	if(!seek(IN, 0, 2)) {
		logger("Couldn't seek to the end ($config->{squid_log}): $!");
		return;
	}
	$logsize = tell(IN);
	if($logsize < $seek_pos) {
		$seek_pos = 0;
	}
	if(!seek(IN, $seek_pos, 0)) {
		logger("Couldn't seek to $seek_pos ($config->{squid_log}): $!");
		return;
	}
	if(defined($config->{squid_hist}->{'seek_pos'})) {	# avoid initial peak
		while(<IN>) {
			(undef, undef, undef, $value) = split(' ', $_);
			($g_result, $g_status) = split('/', $value);
			$g12{$g_result}++;
			$g12{$g_status}++;
		}
	}
	close(IN);
	my @sl = split(',', $squid->{graph_0});
	if(scalar(@sl) > 9) {
		logger("$myself: WARNING: a maximum of 9 values is allowed in 'graph_0' option.");
	}
	for($n = 0; $n < 9 && $sl[$n]; $n++) {
		my $code = trim($sl[$n]);
		$rrdata .= ":";
		$rrdata .= defined($g12{$code}) ? int($g12{$code}) : 0;
	}
	for(; $n < 9; $n++) {
		$rrdata .= ":0";
	}
	@sl = split(',', $squid->{graph_0});
	if(scalar(@sl) > 9) {
		logger("$myself: WARNING: a maximum of 9 values is allowed in 'graph_1' option.");
	}
	for($n = 0; $n < 9 && $sl[$n]; $n++) {
		my $code = trim($sl[$n]);
		$rrdata .= ":";
		$rrdata .= defined($g12{$code}) ? int($g12{$code}) : 0;
	}
	for(; $n < 9; $n++) {
		$rrdata .= ":0";
	}
	$config->{squid_hist}->{'seek_pos'} = $logsize;

	open(IN, "$squid->{cmd} mgr:counters |");
	while(<IN>) {
		if(/^client_http\.requests = (\d+)$/) {
			$rq_client_http_req = $1 - ($config->{squid_hist}->{'rq_client_http_req'} || 0);
			$rq_client_http_req = 0 unless $rq_client_http_req != $1;
			$rq_client_http_req /= 60;
			$config->{squid_hist}->{'rq_client_http_req'} = $1;
			next;
		}
		if(/^client_http\.hits = (\d+)$/) {
			$rq_client_http_hit = $1 - ($config->{squid_hist}->{'rq_client_http_hit'} || 0);
			$rq_client_http_hit = 0 unless $rq_client_http_hit != $1;
			$rq_client_http_hit /= 60;
			$config->{squid_hist}->{'rq_client_http_hit'} = $1;
			next;
		}
		if(/^client_http\.kbytes_in = (\d+)$/) {
			$tc_client_http_in = $1 - ($config->{squid_hist}->{'tc_client_http_in'} || 0);
			$tc_client_http_in = 0 unless $tc_client_http_in != $1;
			$tc_client_http_in *= 1024;
			$tc_client_http_in /= 60;
			$config->{squid_hist}->{'tc_client_http_in'} = $1;
			next;
		}
		if(/^client_http\.kbytes_out = (\d+)$/) {
			$tc_client_http_out = $1 - ($config->{squid_hist}->{'tc_client_http_out'} || 0);
			$tc_client_http_out = 0 unless $tc_client_http_out != $1;
			$tc_client_http_out *= 1024;
			$tc_client_http_out /= 60;
			$config->{squid_hist}->{'tc_client_http_out'} = $1;
			next;
		}
		if(/^server\.all\.kbytes_in = (\d+)$/) {
			$ts_server_all_in = $1 - ($config->{squid_hist}->{'ts_server_all_in'} || 0);
			$ts_server_all_in = 0 unless $ts_server_all_in != $1;
			$ts_server_all_in *= 1024;
			$ts_server_all_in /= 60;
			$config->{squid_hist}->{'ts_server_all_in'} = $1;
			next;
		}
		if(/^server\.all\.kbytes_out = (\d+)$/) {
			$ts_server_all_out = $1 - ($config->{squid_hist}->{'ts_server_all_out'} || 0);
			$ts_server_all_out = 0 unless $ts_server_all_out != $1;
			$ts_server_all_out *= 1024;
			$ts_server_all_out /= 60;
			$config->{squid_hist}->{'ts_server_all_out'} = $1;
			next;
		}
		if(/^server\.http\.requests = (\d+)$/) {
			$rq_server_http_req = $1 - ($config->{squid_hist}->{'rq_server_http_req'} || 0);
			$rq_server_http_req = 0 unless $rq_server_http_req != $1;
			$rq_server_http_req /= 60;
			$config->{squid_hist}->{'rq_server_http_req'} = $1;
			next;
		}
		if(/^server\.ftp\.requests = (\d+)$/) {
			$rq_server_ftp_req = $1 - ($config->{squid_hist}->{'rq_server_ftp_req'} || 0);
			$rq_server_ftp_req = 0 unless $rq_server_ftp_req != $1;
			$rq_server_ftp_req /= 60;
			$config->{squid_hist}->{'rq_server_ftp_req'} = $1;
			next;
		}
		if(/^server\.other\.requests = (\d+)$/) {
			$rq_server_other_req = $1 - ($config->{squid_hist}->{'rq_server_other_req'} || 0);
			$rq_server_other_req = 0 unless $rq_server_other_req != $1;
			$rq_server_other_req /= 60;
			$config->{squid_hist}->{'rq_server_other_req'} = $1;
			next;
		}
		if(/^unlink\.requests = (\d+)$/) {
			$rq_unlink_requests = $1 - ($config->{squid_hist}->{'rq_unlink_requests'} || 0);
			$rq_unlink_requests = 0 unless $rq_unlink_requests != $1;
			$rq_unlink_requests /= 60;
			$config->{squid_hist}->{'rq_unlink_requests'} = $1;
			next;
		}
		if(/^swap\.files_cleaned = (\d+)$/) {
			$rq_swap_files_cleaned = $1 - ($config->{squid_hist}->{'rq_swap_files_cleaned'} || 0);
			$rq_swap_files_cleaned = 0 unless $rq_swap_files_cleaned != $1;
			$rq_swap_files_cleaned /= 60;
			$config->{squid_hist}->{'rq_swap_files_cleaned'} = $1;
			next;
		}
		if(/^aborted_requests = (\d+)$/) {
			$rq_aborted_req = $1 - ($config->{squid_hist}->{'rq_aborted_req'} || 0);
			$rq_aborted_req = 0 unless $rq_aborted_req != $1;
			$rq_aborted_req /= 60;
			$config->{squid_hist}->{'rq_aborted_req'} = $1;
			last;
		}
	}
	close(IN);
	$rrdata .= ":$rq_client_http_req:$rq_client_http_hit:$rq_server_http_req:$rq_server_ftp_req:$rq_server_other_req:$rq_aborted_req:$rq_swap_files_cleaned:$rq_unlink_requests:0";

	open(IN, "$squid->{cmd} mgr:info |");
	my $memory_section = 0;
	while(<IN>) {
		if(/^Memory usage for squid via mallinfo/) {
			$memory_section = 1;
			next;
		}
		if($memory_section) {
			if(/^\tTotal in use:\s+(\d+) KB/) {
				$m_inuse = $1;
				chomp($m_inuse);
				next;
			}
			if(/^\tTotal size:\s+(\d+) KB/) {
				$m_alloc = $1;
				chomp($m_alloc);
				$memory_section = 0;
				last;
			}
		}
	}
	close(IN);
	$rrdata .= ":$m_alloc:$m_inuse:0:0:0";

	open(IN, "$squid->{cmd} mgr:ipcache |");
	while(<IN>) {
		if(/^IPcache Requests:\s+(\d+)$/) {
			$ic_requests = $1 - ($config->{squid_hist}->{'ic_requests'} || 0);
			$ic_requests = 0 unless $ic_requests != $1;
			$ic_requests /= 60;
			$config->{squid_hist}->{'ic_requests'} = $1;
			next;
		}
		if(/^IPcache Hits:\s+(\d+)$/) {
			$ic_hits = $1 - ($config->{squid_hist}->{'ic_hits'} || 0);
			$ic_hits = 0 unless $ic_hits != $1;
			$ic_hits /= 60;
			$config->{squid_hist}->{'ic_hits'} = $1;
			next;
		}
		if(/^IPcache Misses:\s+(\d+)$/) {
			$ic_misses = $1 - ($config->{squid_hist}->{'ic_misses'} || 0);
			$ic_misses = 0 unless $ic_misses != $1;
			$ic_misses /= 60;
			$config->{squid_hist}->{'ic_misses'} = $1;
			last;
		}
	}
	close(IN);
	$rrdata .= ":$ic_requests:$ic_hits:$ic_misses:0:0";

	open(IN, "$squid->{cmd} mgr:io |");
	@data = <IN>;
	close(IN);
	$all = join('', @data);
	$all =~ s/\n/ /g;
	($value) = ($all =~ m/ HTTP I\/O number of reads.*?(\d+)/g)[0] || 0;
	chomp($value);
	$io_http = $value - ($config->{squid_hist}->{'io_http'} || 0);
	$io_http = 0 unless $io_http != $value;
	$io_http /= 60;
	$config->{squid_hist}->{'io_http'} = $value;
	($value) = ($all =~ m/ FTP I\/O number of reads.*?(\d+)/g)[0] || 0;
	chomp($value);
	$io_ftp = $value - ($config->{squid_hist}->{'io_ftp'} || 0);
	$io_ftp = 0 unless $io_ftp != $value;
	$io_ftp /= 60;
	$config->{squid_hist}->{'io_ftp'} = $value;
	($value) = ($all =~ m/ Gopher I\/O number of reads.*?(\d+)/g)[0] || 0;
	chomp($value);
	$io_gopher = $value - ($config->{squid_hist}->{'io_gopher'} || 0);
	$io_gopher = 0 unless $io_gopher != $value;
	$io_gopher /= 60;
	$config->{squid_hist}->{'io_gopher'} = $value;
	($value) = ($all =~ m/ WAIS I\/O number of reads.*?(\d+)/g)[0] || 0;
	$value = 0 unless defined($value);
	chomp($value);
	$io_wais = $value - ($config->{squid_hist}->{'io_wais'} || 0);
	$io_wais = 0 unless $io_wais != $value;
	$io_wais /= 60;
	$config->{squid_hist}->{'io_wais'} = $value;
	$rrdata .= ":$io_http:$io_ftp:$io_gopher:$io_wais:0";

	open(IN, "$squid->{cmd} mgr:storedir |");
	while(<IN>) {
		if(/^Store Entries\s+:\s+(\d+)$/) {
			$s_entries = $1;
			next;
		}
		if(/^Maximum Swap Size\s+:\s+(\d+)/) {
			$s_maximum = $1;
			next;
		}
		if(/^Current Store Swap Size\s*:\s+(\d+)/) {
			$s_current = $1;
			last;
		}
	}
	close(IN);
	$rrdata .= ":$s_entries:$s_maximum:$s_current:0:0";
	$rrdata .= ":$tc_client_http_in:$tc_client_http_out:0";
	$rrdata .= ":$ts_server_all_in:$ts_server_all_out:0";
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub squid_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $squid = $config->{squid};
	my @rigid = split(',', ($squid->{rigid} || ""));
	my @limit = split(',', ($squid->{limit} || ""));
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
	my $i;
	my @DEF;
	my @CDEF;
	my @allvalues;
	my @allsigns;
	my $T = "B";
	my $vlabel = "bytes/s";
	my $n;
	my $str;
	my $err;
	my @AC = (
		"#FFA500",
		"#44EEEE",
		"#44EE44",
		"#4444EE",
		"#448844",
		"#EE4444",
		"#EE44EE",
		"#EEEE44",
		"#963C74",
		"#CCCCCC",
	);
	my @LC = (
		"#FFA500",
		"#00EEEE",
		"#00EE00",
		"#0000EE",
		"#448844",
		"#EE0000",
		"#EE00EE",
		"#EEEE00",
		"#B4B444",
		"#888888",
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
		my $str;
		my $line1;
		my $line2;
		my $line3;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		for($n = 0; $n < scalar(my @sl = split(',', $squid->{graph_0})); $n++) {
			$line2 .= sprintf("%6d", $n + 1);
			$str .= "------";
		}
		$line3 .= $str;
		$i = length($str);
		$line1 .= sprintf(" %${i}s", "Statistics graph 1");
		undef($str);
		$line2 .= " ";
		$line3 .= "-";
		for($n = 0; $n < scalar(my @sl = split(',', $squid->{graph_1})); $n++) {
			$line2 .= sprintf("%6d", $n + 1);
			$str .= "------";
		}
		$line3 .= $str;
		$i = length($str);
		$line1 .= sprintf(" %${i}s", "Statistics graph 2");
		$line1 .= "                                              Overall I/O";
		$line2 .= "  cHTTPr cHTTPh sHTTPr  sFTPr sOther Abortr SwpFcl Unlnkr";
		$line3 .= "---------------------------------------------------------";
		$line1 .= "     Memory usage (MB)";
		$line2 .= "   Alloct   InUse  %  ";
		$line3 .= "----------------------";
		$line1 .= "      Storage usage (MB)";
		$line2 .= "    Alloct    InUse  %  ";
		$line3 .= "------------------------";
		$line1 .= "        IP Cache";
		$line2 .= "  Reqs Hits Miss";
		$line3 .= "----------------";
		$line1 .= "    Network Protocols";
		$line2 .= "  HTTP  FTP Goph WAIS";
		$line3 .= "---------------------";
		$line1 .= "  Client Traffic";
		$line2 .= "    Input Output";
		$line3 .= "----------------";
		$line1 .= "  Server Traffic";
		$line2 .= "    Input Output";
		$line3 .= "----------------";
		push(@output, "    $line1\n");
		push(@output, "Time $line2\n");
		push(@output, "-----$line3 \n");
		my $line;
		my @row;
		my $time;
		my @g1;
		my @g2;
		my $n2;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			undef($line1);
			undef(@row);
			(@g1) = @$line[0..scalar(my @sg0 = split(',', $squid->{graph_0})) - 1];
			for($n2 = 0; $n2 < scalar(@sg0); $n2++) {
				push(@row, $g1[$n2] || 0);
				$line1 .= "%5d ";
			}
			(@g2) = @$line[9..9 + scalar(my @sg1 = split(',', $squid->{graph_1})) - 1];
			$line1 .= " ";
			for($n2 = 0; $n2 < scalar(@sg1); $n2++) {
				push(@row, $g2[$n2] || 0);
				$line1 .= "%5d ";
			}
			$line1 .= " ";
			foreach(@$line[18..25]) {
				push(@row, $_ || 0);
			}
			$line1 .= "%6d %6d %6d %6d %6d %6d %6d %6d ";
			$line1 .= " ";
			foreach(@$line[27..28]) {
				push(@row, $_ || 0);
			}
			@$line[28] = @$line[28] || 0;
			push(@row, (@$line[28] * 100) / (@$line[27] || 1));
			$line1 .= "%7d %7d %4.1f ";
			$line1 .= " ";
			foreach(@$line[43..44]) {
				push(@row, $_ || 0);
			}
			@$line[44] = @$line[44] || 0;
			push(@row, (@$line[44] * 100) / (@$line[43] || 1));
			$line1 .= "%8d %8d %4.1f ";
			$line1 .= " ";
			foreach(@$line[32..34]) {
				push(@row, $_ || 0);
			}
			$line1 .= "%4d %4d %4d ";
			$line1 .= " ";
			foreach(@$line[37..40]) {
				push(@row, $_ || 0);
			}
			$line1 .= "%4d %4d %4d %4d ";
			$line1 .= " ";
			foreach(@$line[47..48]) {
				my $value = $_ || 0;
				if(lc($config->{netstats_in_bps}) eq "y") {
					$value *= 8;
				}
				push(@row, $value);
			}
			$line1 .= " %6d %6d ";
			$line1 .= " ";
			foreach(@$line[50..51]) {
				my $value = $_ || 0;
				if(lc($config->{netstats_in_bps}) eq "y") {
					$value *= 8;
				}
				push(@row, $value);
			}
			$line1 .= " %6d %6d ";
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc}  $line1\n", $time, @row));
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
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG4z = $u . $package . "4z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG5z = $u . $package . "5z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG6z = $u . $package . "6z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG7z = $u . $package . "7z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG8z = $u . $package . "8z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG9z = $u . $package . "9z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3",
		"$IMG_DIR" . "$IMG4",
		"$IMG_DIR" . "$IMG5",
		"$IMG_DIR" . "$IMG6",
		"$IMG_DIR" . "$IMG7",
		"$IMG_DIR" . "$IMG8",
		"$IMG_DIR" . "$IMG9");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
			"$IMG_DIR" . "$IMG2z",
			"$IMG_DIR" . "$IMG3z",
			"$IMG_DIR" . "$IMG4z",
			"$IMG_DIR" . "$IMG5z",
			"$IMG_DIR" . "$IMG6z",
			"$IMG_DIR" . "$IMG7z",
			"$IMG_DIR" . "$IMG8z",
			"$IMG_DIR" . "$IMG9z");
	}
	if($title) {
		push(@output, main::graph_header($title, 2));
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td class='td-valign-top'>\n");
	}
	my @sg0 = split(',', $squid->{graph_0});
	for($n = 0, $i = 1; $n < 9; $n++, $i++) {
		if(trim($sg0[$n])) {
			$str = sprintf("%-34s", trim($sg0[$n]));
			$str = substr($str, 0, 23);
			push(@DEF, "DEF:squid_g1_$i=$rrd:squid_g1_$i:AVERAGE");
			push(@tmp, "LINE2:squid_g1_$i$AC[$n]:$str");
			push(@tmp, "GPRINT:squid_g1_$i:LAST:Cur\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g1_$i:AVERAGE:  Avg\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g1_$i:MIN:  Min\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g1_$i:MAX:  Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:squid_g1_$i$AC[$n]:" . trim($sg0[$n]));
			push(@allvalues, "squid_g1_$i");
			push(@allsigns, "+");
		} else {
			push(@tmp, "COMMENT: \\n");
		}
	}
	pop(@allsigns);
	push(@CDEF, "CDEF:allvalues=" . join(',', @allvalues, @allsigns));
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
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG1",
		"--title=$config->{graphs}->{_squid1}  ($tf->{nwhen}$tf->{twhen})",
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
		@DEF,
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_squid1}  ($tf->{nwhen}$tf->{twhen})",
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
			@DEF,
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid1/)) {
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
	undef(@DEF);
	undef(@CDEF);
	undef(@allvalues);
	undef(@allsigns);
	my @sg1 = split(',', $squid->{graph_1});
	for($n = 0, $i = 1; $n < 9; $n++, $i++) {
		if(trim($sg1[$n])) {
			$str = sprintf("%-34s", trim($sg1[$n]));
			$str = substr($str, 0, 23);
			push(@DEF, "DEF:squid_g2_$i=$rrd:squid_g2_$i:AVERAGE");
			push(@tmp, "LINE2:squid_g2_$i$AC[$n]:$str");
			push(@tmp, "GPRINT:squid_g2_$i:LAST:Cur\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g2_$i:AVERAGE:  Avg\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g2_$i:MIN:  Min\\: %6.1lf");
			push(@tmp, "GPRINT:squid_g2_$i:MAX:  Max\\: %6.1lf\\n");
			push(@tmpz, "LINE2:squid_g2_$i$AC[$n]:" . trim($sg1[$n]));
			push(@allvalues, "squid_g2_$i");
			push(@allsigns, "+");
		} else {
			push(@tmp, "COMMENT: \\n");
		}
	}
	pop(@allsigns);
	push(@CDEF, "CDEF:allvalues=" . join(',', @allvalues, @allsigns));
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
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_squid2}  ($tf->{nwhen}$tf->{twhen})",
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
		@DEF,
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_squid2}  ($tf->{nwhen}$tf->{twhen})",
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
			@DEF,
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid2/)) {
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
	push(@tmp, "LINE2:squid_rq_1$AC[0]:Client HTTP requests");
	push(@tmp, "GPRINT:squid_rq_1:LAST:  Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_1:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_1:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_1:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE2:squid_rq_2$AC[1]:Client HTTP hits");
	push(@tmp, "GPRINT:squid_rq_2:LAST:      Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_2:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_2:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_2:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE2:squid_rq_3$AC[2]:Server HTTP requests");
	push(@tmp, "GPRINT:squid_rq_3:LAST:  Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_3:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_3:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_3:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE2:squid_rq_4$AC[3]:Server FTP requests");
	push(@tmp, "GPRINT:squid_rq_4:LAST:   Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_4:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_4:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_4:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE2:squid_rq_5$AC[4]:Server Other requests");
	push(@tmp, "GPRINT:squid_rq_5:LAST: Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_5:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_5:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_5:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE2:squid_rq_6$AC[5]:Aborted requests");
	push(@tmp, "GPRINT:squid_rq_6:LAST:      Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_6:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_6:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_6:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE2:squid_rq_7$AC[6]:Swap files cleaned");
	push(@tmp, "GPRINT:squid_rq_7:LAST:    Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_7:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_7:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_7:MAX:  Max\\: %6.1lf\\n");
	push(@tmp, "LINE2:squid_rq_8$AC[7]:Unlink requests");
	push(@tmp, "GPRINT:squid_rq_8:LAST:       Cur\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_8:AVERAGE:  Avg\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_8:MIN:  Min\\: %6.1lf");
	push(@tmp, "GPRINT:squid_rq_8:MAX:  Max\\: %6.1lf\\n");
	push(@tmpz, "LINE2:squid_rq_1$AC[0]:Client HTTP requests");
	push(@tmpz, "LINE2:squid_rq_2$AC[1]:Client HTTP hits");
	push(@tmpz, "LINE2:squid_rq_3$AC[2]:Server HTTP requests");
	push(@tmpz, "LINE2:squid_rq_4$AC[3]:Server FTP requests");
	push(@tmpz, "LINE2:squid_rq_5$AC[4]:Server Other requests");
	push(@tmpz, "LINE2:squid_rq_6$AC[5]:Aborted requests");
	push(@tmpz, "LINE2:squid_rq_7$AC[6]:Swap files cleaned");
	push(@tmpz, "LINE2:squid_rq_8$AC[7]:Unlink requests");
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
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG3",
		"--title=$config->{graphs}->{_squid3}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:squid_rq_1=$rrd:squid_rq_1:AVERAGE",
		"DEF:squid_rq_2=$rrd:squid_rq_2:AVERAGE",
		"DEF:squid_rq_3=$rrd:squid_rq_3:AVERAGE",
		"DEF:squid_rq_4=$rrd:squid_rq_4:AVERAGE",
		"DEF:squid_rq_5=$rrd:squid_rq_5:AVERAGE",
		"DEF:squid_rq_6=$rrd:squid_rq_6:AVERAGE",
		"DEF:squid_rq_7=$rrd:squid_rq_7:AVERAGE",
		"DEF:squid_rq_8=$rrd:squid_rq_8:AVERAGE",
		"DEF:squid_rq_9=$rrd:squid_rq_9:AVERAGE",
		"CDEF:allvalues=squid_rq_1,squid_rq_2,squid_rq_3,squid_rq_4,squid_rq_5,squid_rq_6,squid_rq_7,squid_rq_8,squid_rq_9,+,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_squid3}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:squid_rq_1=$rrd:squid_rq_1:AVERAGE",
			"DEF:squid_rq_2=$rrd:squid_rq_2:AVERAGE",
			"DEF:squid_rq_3=$rrd:squid_rq_3:AVERAGE",
			"DEF:squid_rq_4=$rrd:squid_rq_4:AVERAGE",
			"DEF:squid_rq_5=$rrd:squid_rq_5:AVERAGE",
			"DEF:squid_rq_6=$rrd:squid_rq_6:AVERAGE",
			"DEF:squid_rq_7=$rrd:squid_rq_7:AVERAGE",
			"DEF:squid_rq_8=$rrd:squid_rq_8:AVERAGE",
			"DEF:squid_rq_9=$rrd:squid_rq_9:AVERAGE",
			"CDEF:allvalues=squid_rq_1,squid_rq_2,squid_rq_3,squid_rq_4,squid_rq_5,squid_rq_6,squid_rq_7,squid_rq_8,squid_rq_9,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid3/)) {
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
		push(@output, "    <td class='td-valign-top'>\n");
	}
	@riglim = @{setup_riglim($rigid[3], $limit[3])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:m_alloc#EEEE44:Allocated");
	push(@tmp, "GPRINT:m_alloc:LAST:            Current\\: %6.1lf%s\\n");
	push(@tmp, "AREA:m_inuse#44AAEE:In use");
	push(@tmp, "LINE2:m_inuse#00AAEE:");
	push(@tmp, "GPRINT:m_inuse:LAST:               Current\\: %6.1lf%s\\n");
	push(@tmp, "GPRINT:m_perc:LAST:                          In use\\:   %4.1lf%%\\n");
	push(@tmpz, "LINE2:m_alloc#EEEE44:Allocated");
	push(@tmpz, "AREA:m_inuse#44AAEE:In use");
	push(@tmpz, "LINE2:m_inuse#00AAEE:");
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
		"--title=$config->{graphs}->{_squid4}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:squid_m_1=$rrd:squid_m_1:AVERAGE",
		"DEF:squid_m_2=$rrd:squid_m_2:AVERAGE",
		"CDEF:m_alloc=squid_m_1,1024,*",
		"CDEF:m_inuse=squid_m_2,1024,*",
		"CDEF:m_perc=squid_m_2,100,*,squid_m_1,/",
		"CDEF:allvalues=squid_m_1,squid_m_2,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG4z",
			"--title=$config->{graphs}->{_squid4}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:squid_m_1=$rrd:squid_m_1:AVERAGE",
			"DEF:squid_m_2=$rrd:squid_m_2:AVERAGE",
			"CDEF:m_alloc=squid_m_1,1024,*",
			"CDEF:m_inuse=squid_m_2,1024,*",
			"CDEF:m_perc=squid_m_2,100,*,squid_m_1,/",
			"CDEF:allvalues=squid_m_1,squid_m_2,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid4/)) {
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
	push(@tmp, "LINE2:s_alloc#EEEE44:Allocated");
	push(@tmp, "GPRINT:s_alloc:LAST:            Current\\: %6.1lf%s\\n");
	push(@tmp, "AREA:s_inuse#44AAEE:In use");
	push(@tmp, "GPRINT:s_inuse:LAST:               Current\\: %6.1lf%s\\n");
	push(@tmp, "LINE2:s_inuse#00AAEE:");
	push(@tmp, "GPRINT:s_perc:LAST:                          In use\\:   %4.1lf%%\\n");
	push(@tmpz, "LINE2:s_alloc#EEEE44:Allocated");
	push(@tmpz, "AREA:s_inuse#44AAEE:In use");
	push(@tmpz, "LINE2:s_inuse#00AAEE:");
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
		"--title=$config->{graphs}->{_squid5}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:squid_s_2=$rrd:squid_s_2:AVERAGE",
		"DEF:squid_s_3=$rrd:squid_s_3:AVERAGE",
		"CDEF:s_alloc=squid_s_2,1024,*",
		"CDEF:s_inuse=squid_s_3,1024,*",
		"CDEF:s_perc=squid_s_3,100,*,squid_s_2,/",
		"CDEF:allvalues=squid_s_2,squid_s_3,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG5z",
			"--title=$config->{graphs}->{_squid5}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:squid_s_2=$rrd:squid_s_2:AVERAGE",
			"DEF:squid_s_3=$rrd:squid_s_3:AVERAGE",
			"CDEF:s_alloc=squid_s_2,1024,*",
			"CDEF:s_inuse=squid_s_3,1024,*",
			"CDEF:s_perc=squid_s_3,100,*,squid_s_2,/",
			"CDEF:allvalues=squid_s_2,squid_s_3,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid5/)) {
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
	push(@tmp, "AREA:ic_requests#44EEEE:Requests");
	push(@tmp, "GPRINT:ic_requests:LAST:             Current\\: %7.1lf\\n");
	push(@tmp, "AREA:ic_hits#4444EE:Hits");
	push(@tmp, "GPRINT:ic_hits:LAST:                 Current\\: %7.1lf\\n");
	push(@tmp, "AREA:ic_misses#EE44EE:Misses");
	push(@tmp, "GPRINT:ic_misses:LAST:               Current\\: %7.1lf\\n");
	push(@tmp, "LINE2:ic_requests#00EEEE");
	push(@tmp, "LINE2:ic_hits#0000EE");
	push(@tmp, "LINE2:ic_misses#EE00EE");
	push(@tmpz, "AREA:ic_requests#44EEEE:Requests");
	push(@tmpz, "AREA:ic_hits#4444EE:Hits");
	push(@tmpz, "AREA:ic_misses#EE44EE:Misses");
	push(@tmpz, "LINE2:ic_requests#00EEEE");
	push(@tmpz, "LINE2:ic_hits#0000EE");
	push(@tmpz, "LINE2:ic_misses#EE00EE");
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
		"--title=$config->{graphs}->{_squid6}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:ic_requests=$rrd:squid_ic_1:AVERAGE",
		"DEF:ic_hits=$rrd:squid_ic_2:AVERAGE",
		"DEF:ic_misses=$rrd:squid_ic_3:AVERAGE",
		"CDEF:allvalues=ic_requests,ic_hits,ic_misses,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG6: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG6z",
			"--title=$config->{graphs}->{_squid6}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:ic_requests=$rrd:squid_ic_1:AVERAGE",
			"DEF:ic_hits=$rrd:squid_ic_2:AVERAGE",
			"DEF:ic_misses=$rrd:squid_ic_3:AVERAGE",
			"CDEF:allvalues=ic_requests,ic_hits,ic_misses,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG6z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid6/)) {
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

	@riglim = @{setup_riglim($rigid[6], $limit[6])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:io_http#44EEEE:HTTP");
	push(@tmp, "GPRINT:io_http:LAST:                 Current\\: %7.1lf\\n");
	push(@tmp, "AREA:io_ftp#4444EE:FTP");
	push(@tmp, "GPRINT:io_ftp:LAST:                  Current\\: %7.1lf\\n");
	push(@tmp, "AREA:io_gopher#EE44EE:Gopher");
	push(@tmp, "GPRINT:io_gopher:LAST:               Current\\: %7.1lf\\n");
	push(@tmp, "AREA:io_wais#EEEE44:WAIS");
	push(@tmp, "GPRINT:io_wais:LAST:                 Current\\: %7.1lf\\n");
	push(@tmp, "LINE2:io_http#00EEEE");
	push(@tmp, "LINE2:io_ftp#0000EE");
	push(@tmp, "LINE2:io_gopher#EE00EE");
	push(@tmp, "LINE2:io_wais#EEEE00");
	push(@tmpz, "AREA:io_http#44EEEE:HTTP");
	push(@tmpz, "AREA:io_ftp#4444EE:FTP");
	push(@tmpz, "AREA:io_gopher#EE44EE:Gopher");
	push(@tmpz, "AREA:io_wais#EEEE44:WAIS");
	push(@tmpz, "LINE2:io_http#44EEEE");
	push(@tmpz, "LINE2:io_ftp#4444EE");
	push(@tmpz, "LINE2:io_gopher#EE44EE");
	push(@tmpz, "LINE2:io_wais#EEEE44");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG7",
		"--title=$config->{graphs}->{_squid7}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Reads/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:io_http=$rrd:squid_io_1:AVERAGE",
		"DEF:io_ftp=$rrd:squid_io_2:AVERAGE",
		"DEF:io_gopher=$rrd:squid_io_3:AVERAGE",
		"DEF:io_wais=$rrd:squid_io_4:AVERAGE",
		"CDEF:allvalues=io_http,io_ftp,io_gopher,io_wais,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG7: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG7z",
			"--title=$config->{graphs}->{_squid7}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Reads/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:io_http=$rrd:squid_io_1:AVERAGE",
			"DEF:io_ftp=$rrd:squid_io_2:AVERAGE",
			"DEF:io_gopher=$rrd:squid_io_3:AVERAGE",
			"DEF:io_wais=$rrd:squid_io_4:AVERAGE",
			"CDEF:allvalues=io_http,io_ftp,io_gopher,io_wais,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG7z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid7/)) {
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

	@riglim = @{setup_riglim($rigid[7], $limit[7])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:B_in#44EE44:Input");
	push(@tmp, "AREA:B_out#4444EE:Output");
	push(@tmp, "AREA:B_out#4444EE:");
	push(@tmp, "AREA:B_in#44EE44:");
	push(@tmp, "LINE2:B_out#0000EE");
	push(@tmp, "LINE2:B_in#00EE00");
	push(@tmpz, "AREA:B_in#44EE44:Input");
	push(@tmpz, "AREA:B_out#4444EE:Output");
	push(@tmpz, "AREA:B_out#4444EE:");
	push(@tmpz, "AREA:B_in#44EE44:");
	push(@tmpz, "LINE2:B_out#0000EE");
	push(@tmpz, "LINE2:B_in#00EE00");
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
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG8",
		"--title=$config->{graphs}->{_squid8}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:in=$rrd:squid_tc_1:AVERAGE",
		"DEF:out=$rrd:squid_tc_2:AVERAGE",
		"CDEF:allvalues=in,out,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG8: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG8z",
			"--title=$config->{graphs}->{_squid8}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:in=$rrd:squid_tc_1:AVERAGE",
			"DEF:out=$rrd:squid_tc_2:AVERAGE",
			"CDEF:allvalues=in,out,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG8z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid8/)) {
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

	@riglim = @{setup_riglim($rigid[8], $limit[8])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:B_in#44EE44:Input");
	push(@tmp, "AREA:B_out#4444EE:Output");
	push(@tmp, "AREA:B_out#4444EE:");
	push(@tmp, "AREA:B_in#44EE44:");
	push(@tmp, "LINE2:B_out#0000EE");
	push(@tmp, "LINE2:B_in#00EE00");
	push(@tmpz, "AREA:B_in#44EE44:Input");
	push(@tmpz, "AREA:B_out#4444EE:Output");
	push(@tmpz, "AREA:B_out#4444EE:");
	push(@tmpz, "AREA:B_in#44EE44:");
	push(@tmpz, "LINE2:B_out#0000EE");
	push(@tmpz, "LINE2:B_in#00EE00");
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
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG9",
		"--title=$config->{graphs}->{_squid9}  ($tf->{nwhen}$tf->{twhen})",
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
		"DEF:in=$rrd:squid_ts_1:AVERAGE",
		"DEF:out=$rrd:squid_ts_2:AVERAGE",
		"CDEF:allvalues=in,out,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG9: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG9z",
			"--title=$config->{graphs}->{_squid9}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:in=$rrd:squid_ts_1:AVERAGE",
			"DEF:out=$rrd:squid_ts_2:AVERAGE",
			"CDEF:allvalues=in,out,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG9z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /squid9/)) {
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
		push(@output, "    </tr>\n");
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
