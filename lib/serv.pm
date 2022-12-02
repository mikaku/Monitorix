#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2022 by Jordi Sanfeliu <jordi@fibranet.cat>
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
	my $serv = $config->{serv};

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
		if(scalar(@ds) / 32 != keys(%{$serv->{list}})) {
			logger("$myself: Detected size mismatch between <list>...</list> (" . keys(%{$serv->{list}}) . ") and $rrd (" . scalar(@ds) / 32 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < keys(%{$serv->{list}}); $n++) {
			push(@tmp, "DS:serv". $n . "_i_01:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_02:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_03:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_04:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_05:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_06:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_07:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_08:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_09:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_10:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_11:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_12:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_13:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_14:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_15:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_i_16:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_01:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_02:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_03:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_04:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_05:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_06:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_07:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_08:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_09:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_10:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_11:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_12:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_13:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_14:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_15:GAUGE:600:0:U");
			push(@tmp, "DS:serv". $n . "_l_16:GAUGE:600:0:U");
		}
		eval {
			RRDs::create($rrd,
				"--step=300",
				@tmp,
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

	# Since 3.15.0 all values have been renamed
	RRDs::tune($rrd,
		"--data-source-rename=serv_i_ssh:serv0_i_01",
		"--data-source-rename=serv_i_ftp:serv0_i_02",
		"--data-source-rename=serv_i_telnet:serv0_i_03",
		"--data-source-rename=serv_i_imap:serv0_i_04",
		"--data-source-rename=serv_i_smb:serv0_i_05",
		"--data-source-rename=serv_i_fax:serv0_i_06",
		"--data-source-rename=serv_i_cups:serv0_i_07",
		"--data-source-rename=serv_i_pop3:serv0_i_08",
		"--data-source-rename=serv_i_smtp:serv0_i_09",
		"--data-source-rename=serv_i_spam:serv0_i_10",
		"--data-source-rename=serv_i_virus:serv0_i_11",
		"--data-source-rename=serv_i_f2b:serv0_i_12",
		"--data-source-rename=serv_i_val02:serv0_i_13",
		"--data-source-rename=serv_i_val03:serv0_i_14",
		"--data-source-rename=serv_i_val04:serv0_i_15",
		"--data-source-rename=serv_i_val05:serv0_i_16",

		"--data-source-rename=serv_l_ssh:serv0_l_01",
		"--data-source-rename=serv_l_ftp:serv0_l_02",
		"--data-source-rename=serv_l_telnet:serv0_l_03",
		"--data-source-rename=serv_l_imap:serv0_l_04",
		"--data-source-rename=serv_l_smb:serv0_l_05",
		"--data-source-rename=serv_l_fax:serv0_l_06",
		"--data-source-rename=serv_l_cups:serv0_l_07",
		"--data-source-rename=serv_l_pop3:serv0_l_08",
		"--data-source-rename=serv_l_smtp:serv0_l_09",
		"--data-source-rename=serv_l_spam:serv0_l_10",
		"--data-source-rename=serv_l_virus:serv0_l_11",
		"--data-source-rename=serv_l_f2b:serv0_l_12",
		"--data-source-rename=serv_l_val02:serv0_l_13",
		"--data-source-rename=serv_l_val03:serv0_l_14",
		"--data-source-rename=serv_l_val04:serv0_l_15",
		"--data-source-rename=serv_l_val05:serv0_l_16",
	);

	$config->{serv_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub serv_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $serv = $config->{serv};
	my $use_nan_for_missing_data = lc($serv->{use_nan_for_missing_data} || "") eq "y" ? 1 : 0;

	# this graph is refreshed every 5 minutes only
	my (undef, $min) = localtime(time);
	return if($min % 5);

	my $n;
	my $rrdata = "N";
	my $e = 0;
	my $reset = 0;

	# zero all values on every new day
	my $hour = int(strftime("%H", localtime));
	if(!defined($config->{serv_hist}->{'hour'})) {
		$config->{serv_hist}->{'hour'} = $hour;
	} else {
		if($hour < $config->{serv_hist}->{'hour'}) {
			$reset = 1;
		}
		$config->{serv_hist}->{'hour'} = $hour;
	}

	foreach my $sg (sort keys %{$serv->{list}}) {
		my @sl = split(',', $serv->{list}->{$sg});
		my @val = ($use_nan_for_missing_data ? (0+"nan") : 0) x 16;
		my @l_val = ($use_nan_for_missing_data ? (0+"nan") : 0) x 16;

		# loads saved data
		for($n = 0; $n < 16; $n++) {
			my $str = "i_${e}_${n}";
			$val[$n] = $config->{serv_hist}->{$str} if $config->{serv_hist}->{$str};
		}

		if($reset) {
			@val = ($use_nan_for_missing_data ? (0+"nan") : 0) x 16;
		}

		for($n = 0; $n < 16; $n++) {
			my $seek_str = "${e}_${n}";
			my $s = trim($sl[$n] || "");
			my $logsize;

			if(defined($serv->{desc}->{$s})) {
				my @sa;
				my @sc;

				# any service can be defined multiple times and so
				# it will be combined into a single total.
				if(ref $serv->{desc}->{$s} ne "ARRAY") {
					@sa = $serv->{desc}->{$s};	# convert to array
				} else {
					@sa = @{$serv->{desc}->{$s}};
				}
				foreach my $se (@sa) {
					@sc = split(',', $se);
					my $valtype = trim(uc($sc[0]));
					$val[$n] = 0 unless $valtype eq "C";	# zero it if is not a counter
					my $logfile = trim($sc[1]);
					$sc[2] = trim($sc[2]);
					$sc[2] =~ s/^\"//; $sc[2] =~ s/\"$//; # remove leading and trailing quotes
					my $date = strftime($sc[2], localtime);
					$date = qr($date) unless !$date;
					$sc[3] = trim($sc[3]);
					$sc[3] = "\".\"" unless $sc[3] ne "\"\"";	# set "." as a minimal regex
					my @regex = split('\+', $sc[3]);
					my $IN;
					my $seek_pos = $config->{serv_hist}->{$seek_str} || 0;
					if($logfile =~ m/^file:.+/) {
						$logfile =~ s/^file://;
						if(-r $logfile) {
							$seek_pos = defined($seek_pos) ? int($seek_pos) : 0;

							open($IN, "$logfile");
							if(!seek($IN, 0, 2)) {
								logger("Couldn't seek to the end of '$logfile': $!");
							}
							$logsize = tell($IN) || 0;
							$seek_pos = 0 if $logsize < $seek_pos;
							if(!seek($IN, $seek_pos, 0)) {
								logger("Couldn't seek to $seek_pos in '$logfile': $!");
							}
						} else {
							logger("Logfile '$logfile' in service '$s' does not exist: $!");
							undef($logfile);
						}
					} elsif($logfile =~ m/^exec:.+/) {
						$logfile =~ s/^exec://;
						if(!open($IN, "$logfile |")) {
							logger("Unable to execute '$logfile' in service '$s': $!");
							undef($logfile);
						}
					} else {
						logger("Malformed logfile parameter '$logfile' in service '$s': $!");
						undef($logfile);
					}
					$date = "." if !$date;
					if(defined($logfile)) {
						while(<$IN>) {
							if(/$date/) {
								# multiple regex separated by a plus sign are accepted
								foreach my $r (@regex) {
									my $re = $r;
									$re = trim($re);
									$re =~ s/^\"//; $re =~ s/\"$//; # remove leading and trailing quotes
									# those prefixed with i: mean 'insensitive case'
									if($re =~ m/^i:.+/) {
										$re =~ s/^i://;
										$re =~ s/^\"//;	# remove leading quotes
										$val[$n]++ if /$re/i;
									} else {
										$val[$n]++ if /$re/;
									}
								}
							}
						}
						close($IN);
					}
				}
				$config->{serv_hist}->{$seek_str} = $logsize;
			}
		}

		# saves 'I data' (incremental)
		for($n = 0; $n < 16; $n++) {
			my $str = "i_${e}_${n}";
			$config->{serv_hist}->{$str} = $val[$n];
			$rrdata .= ":$val[$n]";
		}

		# saves 'L data' (load)
		for($n = 0; $n < 16; $n++) {
			my $str = "l_${e}_${n}";
			$l_val[$n] = $val[$n] - ($config->{serv_hist}->{$str} || 0);
			$l_val[$n] = 0 unless $l_val[$n] != $val[$n];
			$l_val[$n] /= 300;
			$config->{serv_hist}->{$str} = $val[$n];
			$rrdata .= ":$l_val[$n]";
		}

		$e++;
	}

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
	my @full_size_mode;
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
	my @IMG;
	my @IMGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $n;
	my $n2;
	my $e;
	my $str;
	my $err;
	my @LC = (
		"#FFA500",
		"#44EEEE",
		"#44EE44",
		"#4444EE",
		"#448844",
		"#5F04B4",
		"#EE44EE",
		"#EEEE44",
		"#888888",
		"#DDAE8C",
		"#963C74",
		"#CCCCCC",
		"#AEB404",
		"#037C8C",
		"#9048D4",
		"#8C7000",
	);

	$version = "old" if $RRDs::VERSION < 1.3;
	push(@full_size_mode, "--full-size-mode") if $RRDs::VERSION > 1.3;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $IMG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};
	my $imgfmt_uc = uc($config->{image_format});
	my $imgfmt_lc = lc($config->{image_format});
	foreach my $i (split(',', $config->{rrdtool_extra_options} || "")) {
		push(@extra, trim($i)) if trim($i);
	}

	$title = !$silent ? $title : "";
	my $gap_on_all_nan = lc($serv->{gap_on_all_nan} || "") eq "y" ? 1 : 0;


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
		my $line1;
		my $line2;
		my $line3;

		foreach my $sg (sort keys %{$serv->{list}}) {
			my @sl = split(',', $serv->{list}->{$sg});
			my $len;
			for($n = 0; $n < scalar(@sl); $n++) {
				my $s = trim($sl[$n]);
				if(defined($serv->{desc}->{$s})) {
					if($len) {
						$len++;
						$line3 .= sprintf("-");
					}
					$line2 .= sprintf("%10s ", substr($s, 0, 10));
					$len += 10;
					$line3 .= sprintf("----------");
				}
			}
			$len++;
			$line1 .= sprintf("%${len}s", $sg);
		}
		push(@output, "    $line1\n");
		push(@output, "Time $line2\n");
		push(@output, "-----$line3\n");
		my $line;
		my @row;
		my $time;
		my $from = 0;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			$e = 0;
			foreach my $sg (sort keys %{$serv->{list}}) {
				my @sl = split(',', $serv->{list}->{$sg});
				$from = ($e * 16);
				$to = $from + scalar(@sl);
				@row = @$line[$from..$to];
				my $str = "";
				for($n2 = 0; $n2 < scalar(@sl); $n2++) {
					$str .= "%10d ";
				}
				push(@output, sprintf($str, @row));
				$e++;
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

	for($n = 0; $n < scalar(keys %{$serv->{list}}); $n++) {
		$str = $u . $package . $n . "." . $tf->{when} . ".$imgfmt_lc";
		push(@IMG, $str);
		unlink("$IMG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . $package . $n . "z." . $tf->{when} . ".$imgfmt_lc";
			push(@IMGz, $str);
			unlink("$IMG_DIR" . $str);
		}
	}

	my $graphs_per_row = $serv->{graphs_per_row} || 2;
	my @sgl = (sort keys %{$serv->{list}});
	my @linpad = (0) x scalar(@sgl);
	if($graphs_per_row > 1) {
		for(my $n = 0; $n < scalar(@sgl); $n++) {
			my $sg = trim($sgl[$n]);
			my @sl = split(',', $serv->{list}->{$sg});
			$linpad[$n] = scalar(@sl);
		}
		for(my $n = 0; $n < scalar(@linpad); $n++) {
			if($n % $graphs_per_row == 0) {
				my $max_number_of_lines = 0;
				for(my $sub_n = $n; $sub_n < min($n + $graphs_per_row, scalar(@linpad)); $sub_n++) {
					$max_number_of_lines = max($max_number_of_lines, $linpad[$sub_n]);
				}
				for(my $sub_n = $n; $sub_n < min($n + $graphs_per_row, scalar(@linpad)); $sub_n++) {
					$linpad[$sub_n] = $max_number_of_lines;
				}
			}
		}
	}

	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	$e = 0;
	while($e < scalar(@sgl)) {
		if($title) {
			if($e == 0) {
				push(@output, main::graph_header($title, $graphs_per_row));
			}
			push(@output, "    <tr>\n");
		}
		for($n = 0; $n < $graphs_per_row; $n++) {
			my @DEF0;
			my @CDEF0;

			last unless defined($sgl[$e]);
			if($title) {
				push(@output, "    <td>\n");
			}
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);

			if(lc($serv->{mode}) eq "i") {
				$vlabel = "Incremental hits";
				push(@DEF0, "DEF:s1=$rrd:serv" . $e . "_i_01:AVERAGE");
				push(@DEF0, "DEF:s2=$rrd:serv" . $e . "_i_02:AVERAGE");
				push(@DEF0, "DEF:s3=$rrd:serv" . $e . "_i_03:AVERAGE");
				push(@DEF0, "DEF:s4=$rrd:serv" . $e . "_i_04:AVERAGE");
				push(@DEF0, "DEF:s5=$rrd:serv" . $e . "_i_05:AVERAGE");
				push(@DEF0, "DEF:s6=$rrd:serv" . $e . "_i_06:AVERAGE");
				push(@DEF0, "DEF:s7=$rrd:serv" . $e . "_i_07:AVERAGE");
				push(@DEF0, "DEF:s8=$rrd:serv" . $e . "_i_08:AVERAGE");
				push(@DEF0, "DEF:s9=$rrd:serv" . $e . "_i_09:AVERAGE");
				push(@DEF0, "DEF:s10=$rrd:serv" . $e . "_i_10:AVERAGE");
				push(@DEF0, "DEF:s11=$rrd:serv" . $e . "_i_11:AVERAGE");
				push(@DEF0, "DEF:s12=$rrd:serv" . $e . "_i_12:AVERAGE");
				push(@DEF0, "DEF:s13=$rrd:serv" . $e . "_i_13:AVERAGE");
				push(@DEF0, "DEF:s14=$rrd:serv" . $e . "_i_14:AVERAGE");
				push(@DEF0, "DEF:s15=$rrd:serv" . $e . "_i_15:AVERAGE");
				push(@DEF0, "DEF:s16=$rrd:serv" . $e . "_i_16:AVERAGE");
				push(@CDEF0, ($gap_on_all_nan ? "CDEF:allvalues=s1,UN,0,1,IF,s2,UN,0,1,IF,s3,UN,0,1,IF,s4,UN,0,1,IF,s5,UN,0,1,IF,s6,UN,0,1,IF,s7,UN,0,1,IF,s8,UN,0,1,IF,s9,UN,0,1,IF,s10,UN,0,1,IF,s11,UN,0,1,IF,s12,UN,0,1,IF,s13,UN,0,1,IF,s14,UN,0,1,IF,s15,UN,0,1,IF,s16,UN,0,1,IF,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+0,GT,1,UNKN,IF" : "CDEF:allvalues=s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+"));
			} else {
				$vlabel = "Accesses/s";
				push(@DEF0, "DEF:s1=$rrd:serv" . $e . "_l_01:AVERAGE");
				push(@DEF0, "DEF:s2=$rrd:serv" . $e . "_l_02:AVERAGE");
				push(@DEF0, "DEF:s3=$rrd:serv" . $e . "_l_03:AVERAGE");
				push(@DEF0, "DEF:s4=$rrd:serv" . $e . "_l_04:AVERAGE");
				push(@DEF0, "DEF:s5=$rrd:serv" . $e . "_l_05:AVERAGE");
				push(@DEF0, "DEF:s6=$rrd:serv" . $e . "_l_06:AVERAGE");
				push(@DEF0, "DEF:s7=$rrd:serv" . $e . "_l_07:AVERAGE");
				push(@DEF0, "DEF:s8=$rrd:serv" . $e . "_l_08:AVERAGE");
				push(@DEF0, "DEF:s9=$rrd:serv" . $e . "_l_09:AVERAGE");
				push(@DEF0, "DEF:s10=$rrd:serv" . $e . "_l_10:AVERAGE");
				push(@DEF0, "DEF:s11=$rrd:serv" . $e . "_l_11:AVERAGE");
				push(@DEF0, "DEF:s12=$rrd:serv" . $e . "_l_12:AVERAGE");
				push(@DEF0, "DEF:s13=$rrd:serv" . $e . "_l_13:AVERAGE");
				push(@DEF0, "DEF:s14=$rrd:serv" . $e . "_l_14:AVERAGE");
				push(@DEF0, "DEF:s15=$rrd:serv" . $e . "_l_15:AVERAGE");
				push(@DEF0, "DEF:s16=$rrd:serv" . $e . "_l_16:AVERAGE");
				push(@CDEF0, ($gap_on_all_nan ? "CDEF:allvalues=s1,UN,0,1,IF,s2,UN,0,1,IF,s3,UN,0,1,IF,s4,UN,0,1,IF,s5,UN,0,1,IF,s6,UN,0,1,IF,s7,UN,0,1,IF,s8,UN,0,1,IF,s9,UN,0,1,IF,s10,UN,0,1,IF,s11,UN,0,1,IF,s12,UN,0,1,IF,s13,UN,0,1,IF,s14,UN,0,1,IF,s15,UN,0,1,IF,s16,UN,0,1,IF,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+0,GT,1,UNKN,IF" : "CDEF:allvalues=s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+"));
			}

			my $sg = trim($sgl[$e]);
			my @sl = split(',', $serv->{list}->{$sg});
			for($n2 = 0; $n2 < scalar(@sl); $n2++) {
				my $s = trim($sl[$n2]);
				$str = sprintf("%-25s", substr($s, 0, 25));
				push(@tmp, "LINE2:s" . ($n2 + 1) . $LC[$n2] . ":$str");
				if(lc($serv->{mode}) eq "i") {
					push(@tmp, "GPRINT:s" . ($n2 + 1) . ":LAST:Cur\\: %3.0lf%s");
					push(@tmp, "GPRINT:s" . ($n2 + 1) . ":MIN: Min\\: %3.0lf%s");
					push(@tmp, "GPRINT:s" . ($n2 + 1) . ":MAX: Max\\: %3.0lf%s\\n");
				} else {
					push(@tmp, "GPRINT:s" . ($n2 + 1) . ":LAST: Current\\:%7.1lf%s\\n");
				}
				push(@tmpz, "LINE2:s" . ($n2 + 1) . $LC[$n2] . ":$str");
			}
			while($n2 < $linpad[$e]) {
				push(@tmp, "COMMENT: \\n");
				$n2++;
			}
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{medium});
			$str = substr(trim($sg), 0, 25);
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e]",
				"--title=$str  ($tf->{nwhen}$tf->{twhen})",
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
				@DEF0,
				@CDEF0,
				@CDEF,
				@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e]",
					"--title=$str  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=$vlabel",
					"--width=$width",
					"--height=$height",
					@full_size_mode,
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$colors->{graph_colors}},
					@DEF0,
					@CDEF0,
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /du$e/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e], IMG => $IMG[$e]) . "\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      " . picz_js_a_element(width => $picz_width, height => $picz_height, config => $config, IMGz => $IMGz[$e], IMG => $IMG[$e]) . "\n");
					}
				} else {
					push(@output, "      " . img_element(config => $config, IMG => $IMG[$e]) . "\n");
				}
			}
			if($title) {
				push(@output, "    </td>\n");
			}
			$e++;
		}
		if($title) {
			push(@output, "    </tr>\n");
		}
	}
	if($title) {
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
