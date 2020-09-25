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

package traffacct;

use strict;
use warnings;
use Monitorix;
use RRDs;
use MIME::Lite;
use LWP::UserAgent;
use Socket;
use Exporter 'import';
our @EXPORT = qw(traffacct_init traffacct_update traffacct_cgi traffacct_getcounters traffacct_sendreports);

sub traffacct_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $traffacct = $config->{traffacct};

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

	if(!grep {$_ eq $config->{os}} ("Linux")) {
		logger("$myself is not supported yet by your operating system ($config->{os}.");
		return;
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
		if(scalar(@ds) / 2 != $traffacct->{max}) {
			logger("$myself: Detected size mismatch between 'max = $traffacct->{max}' and $rrd (" . scalar(@ds) / 2 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < $traffacct->{max}; $n++) {
			push(@tmp, "DS:traffacct" . $n . "_in:GAUGE:120:0:U");
			push(@tmp, "DS:traffacct" . $n . "_out:GAUGE:120:0:U");
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

	if($config->{os} eq "Linux") {
		if(!$config->{net}->{gateway}) {
			logger("$myself: ERROR: You must assign a valid ethernet interface in 'net->gateway'");
			return;
		}
		# set the iptables rules for each defined host/network
		my @tal = split(',', $traffacct->{list});
		for($n = 0; $n < $traffacct->{max}; $n++) {
			my $name = trim($tal[$n]);
			if($name) {
				my $ip;
				if($traffacct->{desc}->{$n}) {
					$ip = trim((split(',', $traffacct->{desc}->{$n}))[0]);
				}
				if(!$ip) {
					if(!gethostbyname($name)) {
						logger("WARNING: Unable to resolve '" . $name . "'. Check your DNS.");
					}
					$ip = inet_ntoa((gethostbyname($name))[4]);
					$ip = $ip . "/32";
				}
				open(IN, "iptables -t $table -nxvL monitorix_daily_$name 2>/dev/null |");
				my @data = <IN>;
				close(IN);
				if(!scalar(@data)) {
					system("iptables -t $table -N monitorix_daily_$name");
					system("iptables -t $table -I FORWARD -j monitorix_daily_$name");
					system("iptables -t $table -A monitorix_daily_$name -s $ip -d 0/0 -o $config->{net}->{gateway}");
					system("iptables -t $table -A monitorix_daily_$name -s 0/0 -d $ip -i $config->{net}->{gateway}");
				}
			}
		}
	}

	# Since 3.0.0 PC_LAN values were renamed to TRAFFACCT.
	for($n = 0; $n < $traffacct->{max}; $n++) {
		RRDs::tune($rrd,
			"--data-source-rename=pc" . $n . "_in:traffacct" . $n . "_in",
			"--data-source-rename=pc" . $n . "_out:traffacct" . $n . "_out",
		);
	}

	$config->{traffacct_hist_in} = ();
	$config->{traffacct_hist_out} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub traffacct_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $traffacct = $config->{traffacct};

	my $table = $config->{ip_default_table};
	my @in;
	my @out;

	my $n;
	my $rrdata = "N";

	my @tal = split(',', $traffacct->{list});
	for($n = 0; $n < $traffacct->{max}; $n++) {
		my $name = trim($tal[$n]);
		if($name) {
			my $ip;
			if($traffacct->{desc}->{$n}) {
				$ip = trim((split(',', $traffacct->{desc}->{$n}))[0]);
			}
			if(!$ip) {
				if(!gethostbyname($name)) {
					logger("WARNING: Unable to resolve '" . $name . "'. Check your DNS.");
				}
				$ip = inet_ntoa((gethostbyname($name))[4]);
			}
			$ip =~ s/\/\d+//;
			open(IN, "iptables -t $table -nxvL monitorix_daily_$name |");
			$in[$n] = 0 unless $in[$n];
			$out[$n] = 0 unless $out[$n];
			while(<IN>) {
				my (undef, $bytes, undef, undef, undef, undef, $source) = split(' ', $_);
				if($source) {
					if($source =~ /0.0.0.0/) {
						$in[$n] = $bytes - ($config->{traffacct_hist_in}[$n] || 0);
						$in[$n] = 0 unless $in[$n] != $bytes;
						$config->{traffacct_hist_in}[$n] = $bytes;
						$in[$n] /= 60;
					}
					if($source eq $ip) {
						$out[$n] = $bytes - ($config->{traffacct_hist_out}[$n] || 0);
						$out[$n] = 0 unless $out[$n] != $bytes;
						$config->{traffacct_hist_out}[$n] = $bytes;
						$out[$n] /= 60;
					}
				}
			}
			close(IN);
		}
	}

	for($n = 0; $n < $traffacct->{max}; $n++) {
		my $i = $in[$n] || 0;
		my $o = $out[$n] || 0;
		$rrdata .= ":$i:$o";
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub traffacct_getcounters {
	my $myself = (caller(0))[3];
	my ($config, $debug) = @_;
	my $traffacct = $config->{traffacct};

	my $in;
	my $out;

	my $n;
	my $day = (localtime(time - 60))[3];

	my @tal = split(',', $traffacct->{list});
	for($n = 0; $n < $traffacct->{max}; $n++) {
		my $name = trim($tal[$n]);
		if($name) {
			my $ip;
			if($traffacct->{desc}->{$n}) {
				$ip = trim((split(',', $traffacct->{desc}->{$n}))[0]);
			}
			if(!$ip) {
				if(!gethostbyname($name)) {
					logger("WARNING: Unable to resolve '" . $name . "'. Check your DNS.");
				}
				$ip = inet_ntoa((gethostbyname($name))[4]);
			}
			$ip =~ s/\/\d+//;
			open(IN, "iptables -nxvL monitorix_daily_$name |");
			while(<IN>) {
				my (undef, $bytes, undef, undef, undef, undef, $source) = split(' ', $_);
				if($source) {
					if($source eq $ip) {
						$out = $bytes;
					}
					if($source =~ /0.0.0.0/) {
						$in = $bytes;
					}
				}
			}
			close(IN);
			my $usage_dir = $config->{base_lib} . $config->{usage_dir};
			if(! -w $usage_dir) {
				logger("WARNING: directory '" . $usage_dir ."' doesn't exists or is not writable.");
				last;
			} else {
				open(OUT, ">> " . $usage_dir . $name);
				print(OUT "$day $in $out\n");
				close(OUT);
				logger("Saved daily traffic counter for '$name'.") if $debug;
			}
			system("iptables -Z monitorix_daily_$name >/dev/null 2>/dev/null");
		}
	}

}

sub adjust {
	my $bytes = (shift);
	my $adjust = 0;
	my $b = "  ";

	if($bytes > 0  &&  $bytes < 1048576) {
		$adjust = $bytes/1024;
		$b = "KB";
	}
	if($bytes > 1048576  &&  $bytes < 1073741824) {
		$adjust = $bytes/1024/1024;
		$b = "MB";
	}
	if($bytes > 1073741824  &&  $bytes < 1000000000000) {
		$adjust = $bytes/1024/1024/1024;
		$b = "GB";
	}
	return sprintf("%3u%s", $adjust, $b);
}

sub traffacct_sendreports {
	my $myself = (caller(0))[3];
	my ($config, $debug) = @_;
	my $traffacct = $config->{traffacct};
	my $imgfmt_lc = lc($config->{image_format});

	my (undef, undef, undef, undef, $prev_month, $prev_year) = localtime(time - 3600);
	my $n;
	my $mime;

	my $usage_dir = $config->{base_lib} . $config->{usage_dir};
	my $report_dir = $config->{base_lib} . $config->{report_dir};
	my $base_url = $config->{base_url};
	my $base_cgi = $config->{base_cgi};
	my $imgs_dir = $config->{imgs_dir};

	$mime = "image/png";
	$mime = "image/svg+xml" if uc($config->{image_format}) eq "SVG";

	logger("Sending monthly network traffic reports.");

	my @tal = split(',', $traffacct->{list});
	for($n = 0; $n < $traffacct->{max}; $n++) {
		my $name = trim($tal[$n]);
		next if(!$name);

		my @traffic = ();
		my $tot_in = 0;
		my $tot_out = 0;
		my $tot = 0;
		if(open(IN, $usage_dir . $name)) {
			push(@traffic, "DAY              INPUT             OUTPUT                 TOTAL\n");
			push(@traffic, "---------------------------------------------------------------\n");
			while(<IN>) {
				my ($day, $in, $out) = split(' ', $_);
				chomp($day);
				chomp($in);
				chomp($day);
				$tot_in += $in;
				$tot_out += $out;
				$tot = $in + $out;
				push(@traffic, sprintf("%3u %12u %s %12u %s %15u %s\n", $day, $in, adjust($in), $out, adjust($out), $tot, adjust($tot)));
			}
			close(IN);
		} else {
			next;
		}
		push(@traffic, "---------------------------------------------------------------\n");
		$tot = $tot_in + $tot_out;
		push(@traffic, sprintf("%16u %s %12u %s %15u %s\n", $tot_in, adjust($tot_in), $tot_out, adjust($tot_out), $tot, adjust($tot)));

		my $to = trim((split(',', $traffacct->{desc}->{$n}))[1]);
		$to = $traffacct->{reports}->{default_mail} unless $to;

		# get the monthly graph
		my $url = $traffacct->{reports}->{url_prefix} . $base_cgi . "/monitorix.cgi?mode=traffacct.$n&graph=all&when=1month&color=&silent=imagetagbig";
		my $ssl = "";

		$ssl = "ssl_opts => {verify_hostname => 0}"
			if lc($config->{accept_selfsigned_certs}) eq "y";

		my $ua = LWP::UserAgent->new(timeout => 30, $ssl);
		$ua->agent($config->{user_agent_id}) if $config->{user_agent_id} || "";
		$ua->request(HTTP::Request->new('GET', $url));

		$url = $traffacct->{reports}->{url_prefix} . $base_url . "/" . $imgs_dir . "traffacct" . $n . ".1month.$imgfmt_lc";
		my $response = $ua->request(HTTP::Request->new('GET', $url));
		if(!$response->is_success) {
			logger("$myself: ERROR: Unable to connect to '$url'.");
			logger("$myself: " . $response->status_line);
		}

		# create the multipart container and add attachments
		my $msg = new MIME::Lite(
			From		=> $traffacct->{reports}->{from_address},
			To		=> $to,
			Subject		=> "Monitorix: monthly traffic report - $name",
			Type		=> "multipart/related",
			Organization	=> "Monitorix",
		);

		$msg->attach(
			Type		=> 'text/html',
			Path		=> $report_dir . $traffacct->{reports}->{language} . '.html',
		);
		$msg->attach(
			Type		=> 'image/png',
			Id		=> 'image_01',
			Path		=> $config->{base_dir} . $config->{logo_bottom},
		);
		$msg->attach(
			Type		=> $mime,
			Id		=> 'image_02',
			Data		=> $response->content,
		);
		$msg->attach(
			Type		=> 'text/plain',
			Id		=> 'text_01',
			Data		=> join("", @traffic),
		);
		$msg->send('smtp', $traffacct->{reports}->{smtp_hostname}, Timeout => 60);

		# rename the processed file to avoid reusing it
		my $new = sprintf("%s.%02u-%u", $usage_dir . $name, $prev_month + 1, $prev_year + 1900);
		rename($usage_dir . $name, $new);
		logger("$myself: $name -> $to [$traffacct->{reports}->{language}]");
	}
}

sub traffacct_cgi {
	my ($package, $config, $cgi) = @_;

	my $traffacct = $config->{traffacct};
	my @rigid = split(',', ($traffacct->{rigid} || ""));
	my @limit = split(',', ($traffacct->{limit} || ""));
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
	my $T = "B";
	my $vlabel = "bytes/s";
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

	if(lc($config->{netstats_in_bps}) eq "y") {
		$T = "b";
		$vlabel = "bits/s";
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

	for($n = 0; $n < $traffacct->{max}; $n++) {
		$str = $u . "traffacct" . $n . ".$tf->{when}" . ".$imgfmt_lc";
		push(@IMG, $str);
		unlink("$IMG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . "traffacct" . $n . "z.$tf->{when}" . ".$imgfmt_lc";
			push(@IMGz, $str);
			unlink("$IMG_DIR" . $str);
		}
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};

	$traffacct->{graphs_per_row} = 1 unless $traffacct->{graphs_per_row} > 1;
	my @tal = split(',', $traffacct->{list});

	if($cgi->{val} eq "all") {
		print("  <table cellspacing='5' cellpadding='0' width='1' bgcolor='$colors->{graph_bg_color}' border='1'>\n");
		print("  <tr>\n");
		print("  <td bgcolor='$colors->{title_bg_color}' colspan='" . $traffacct->{graphs_per_row}  . "'>\n");
		print("  <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
		print("    <b>&nbsp;&nbsp;Network traffic<b>\n");
		print("  </font>\n");
		print("  </td>\n");
		print("  </tr>\n");
		$n = 0;
		while($n < $traffacct->{max}) {
			my $name = trim($tal[$n]);
			last unless $name;
			print("  <tr>\n");
			for($n2 = 0; $n2 < $traffacct->{graphs_per_row}; $n2++) {
				$name = trim($tal[$n]);
				last unless ($n < $traffacct->{max} && $n < scalar(@tal));
				print("  <td bgcolor='$colors->{title_bg_color}'>\n");
				undef(@tmp);
				undef(@tmpz);
				undef(@CDEF);
				push(@tmp, "AREA:B_in#44EE44:Input");
				push(@tmp, "AREA:B_out#4444EE:Output");
				push(@tmp, "AREA:B_out#4444EE:");
				push(@tmp, "AREA:B_in#44EE44:");
				push(@tmp, "LINE1:B_out#0000EE");
				push(@tmp, "LINE1:B_in#00EE00");
				push(@tmpz, "AREA:B_in#44EE44:Input");
				push(@tmpz, "AREA:B_out#4444EE:Output");
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
				if(lc($config->{show_gaps}) eq "y") {
					push(@tmp, "AREA:wrongdata#$colors->{gap}:");
					push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
					push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
				}
				($width, $height) = split('x', $config->{graph_size}->{remote});
				$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$n]",
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
					"DEF:in=$rrd:traffacct" . $n . "_in:AVERAGE",
					"DEF:out=$rrd:traffacct" . $n . "_out:AVERAGE",
					"CDEF:allvalues=in,out,+",
					@CDEF,
					@tmp);
				$err = RRDs::error;
				print("ERROR: while graphing $IMG_DIR" . "$IMG[$n]: $err\n") if $err;
				if(lc($config->{enable_zoom}) eq "y") {
					($width, $height) = split('x', $config->{graph_size}->{zoom});
					$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$n]",
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
						"DEF:in=$rrd:traffacct" . $n . "_in:AVERAGE",
						"DEF:out=$rrd:traffacct" . $n . "_out:AVERAGE",
						"CDEF:allvalues=in,out,+",
						@CDEF,
						@tmpz);
					$err = RRDs::error;
					print("ERROR: while graphing $IMG_DIR" . "$IMGz[$n]: $err\n") if $err;
				}
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$n] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$n] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n] . "' border='0'></a>\n");
					}
				} else {
					print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n] . "'>\n");
				}
				print("  </td>\n");
				$n++;
			}
			print("  </tr>\n");
		}
		print "  </table>\n";
	} else {
		return unless $tal[$cgi->{val}];
		if(!$silent) {
			print("  <table cellspacing='5' cellpadding='0' width='1' bgcolor='$colors->{graph_bg_color}' border='1'>\n");
			print("  <tr>\n");
			print("  <td bgcolor='$colors->{title_bg_color}' colspan='1'>\n");
			print("  <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
			print("    <b>&nbsp;&nbsp;Network traffic<b>\n");
			print("  </font>\n");
			print("  </td>\n");
			print("  </tr>\n");
			print("  <tr>\n");
			print("  <td bgcolor='$colors->{title_bg_color}'>\n");
		}
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		push(@tmp, "AREA:B_in#44EE44:K$T/s Input");
		push(@tmp, "GPRINT:K_in:LAST:     Current\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:AVERAGE: Average\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:MIN:    Min\\: %5.0lf");
		push(@tmp, "GPRINT:K_in:MAX:    Max\\: %5.0lf\\n");
		push(@tmp, "AREA:B_out#4444EE:K$T/s Output");
		push(@tmp, "GPRINT:K_out:LAST:    Current\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:AVERAGE: Average\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:MIN:    Min\\: %5.0lf");
		push(@tmp, "GPRINT:K_out:MAX:    Max\\: %5.0lf\\n");
		push(@tmp, "AREA:B_out#4444EE:");
		push(@tmp, "AREA:B_in#44EE44:");
		push(@tmp, "LINE1:B_out#0000EE");
		push(@tmp, "LINE1:B_in#00EE00");
		push(@tmpz, "AREA:B_in#44EE44:Input");
		push(@tmpz, "AREA:B_out#4444EE:Output");
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
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{main});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$cgi->{val}]",
			"--title=$tal[$cgi->{val}] traffic  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:in=$rrd:traffacct" . $cgi->{val} . "_in:AVERAGE",
			"DEF:out=$rrd:traffacct" . $cgi->{val} . "_out:AVERAGE",
			"CDEF:allvalues=in,out,+",
			@CDEF,
			"CDEF:K_in=B_in,1024,/",
			"CDEF:K_out=B_out,1024,/",
			@tmp);
		$err = RRDs::error;
		print("ERROR: while graphing $IMG_DIR" . "$IMG[$cgi->{val}]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$cgi->{val}]",
				"--title=$tal[$cgi->{val}] traffic  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:in=$rrd:traffacct" . $cgi->{val} . "_in:AVERAGE",
				"DEF:out=$rrd:traffacct" . $cgi->{val} . "_out:AVERAGE",
				"CDEF:allvalues=in,out,+",
				@CDEF,
				"CDEF:K_in=B_in,1024,/",
				"CDEF:K_out=B_out,1024,/",
				@tmpz);
			$err = RRDs::error;
			print("ERROR: while graphing $IMG_DIR" . "$IMGz[$cgi->{val}]: $err\n") if $err;
		}
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$cgi->{val}] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$cgi->{val}] . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$cgi->{val}] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$cgi->{val}] . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$cgi->{val}] . "'>\n");
		}
		if(!$silent) {
			print("  </td>\n");
			print "  </td>\n";
			print "  </tr>\n";
			print "  </table>\n";
		}
	}
}

1;
