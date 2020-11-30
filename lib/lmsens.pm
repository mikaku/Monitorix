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

package lmsens;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(lmsens_init lmsens_update lmsens_cgi);

sub lmsens_init {
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

	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		logger("$myself is not supported yet by your operating system ($config->{os}).");
		return;
	}

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
				"DS:lmsens_mb0:GAUGE:120:0:100",
				"DS:lmsens_mb1:GAUGE:120:0:100",
				"DS:lmsens_cpu0:GAUGE:120:0:100",
				"DS:lmsens_cpu1:GAUGE:120:0:100",
				"DS:lmsens_cpu2:GAUGE:120:0:100",
				"DS:lmsens_cpu3:GAUGE:120:0:100",
				"DS:lmsens_fan0:GAUGE:120:0:U",
				"DS:lmsens_fan1:GAUGE:120:0:U",
				"DS:lmsens_fan2:GAUGE:120:0:U",
				"DS:lmsens_fan3:GAUGE:120:0:U",
				"DS:lmsens_fan4:GAUGE:120:0:U",
				"DS:lmsens_fan5:GAUGE:120:0:U",
				"DS:lmsens_fan6:GAUGE:120:0:U",
				"DS:lmsens_fan7:GAUGE:120:0:U",
				"DS:lmsens_fan8:GAUGE:120:0:U",
				"DS:lmsens_core0:GAUGE:120:0:100",
				"DS:lmsens_core1:GAUGE:120:0:100",
				"DS:lmsens_core2:GAUGE:120:0:100",
				"DS:lmsens_core3:GAUGE:120:0:100",
				"DS:lmsens_core4:GAUGE:120:0:100",
				"DS:lmsens_core5:GAUGE:120:0:100",
				"DS:lmsens_core6:GAUGE:120:0:100",
				"DS:lmsens_core7:GAUGE:120:0:100",
				"DS:lmsens_core8:GAUGE:120:0:100",
				"DS:lmsens_core9:GAUGE:120:0:100",
				"DS:lmsens_core10:GAUGE:120:0:100",
				"DS:lmsens_core11:GAUGE:120:0:100",
				"DS:lmsens_core12:GAUGE:120:0:100",
				"DS:lmsens_core13:GAUGE:120:0:100",
				"DS:lmsens_core14:GAUGE:120:0:100",
				"DS:lmsens_core15:GAUGE:120:0:100",
				"DS:lmsens_volt0:GAUGE:120:U:U",
				"DS:lmsens_volt1:GAUGE:120:U:U",
				"DS:lmsens_volt2:GAUGE:120:U:U",
				"DS:lmsens_volt3:GAUGE:120:U:U",
				"DS:lmsens_volt4:GAUGE:120:U:U",
				"DS:lmsens_volt5:GAUGE:120:U:U",
				"DS:lmsens_volt6:GAUGE:120:U:U",
				"DS:lmsens_volt7:GAUGE:120:U:U",
				"DS:lmsens_volt8:GAUGE:120:U:U",
				"DS:lmsens_volt9:GAUGE:120:U:U",
				"DS:lmsens_volt10:GAUGE:120:U:U",
				"DS:lmsens_volt11:GAUGE:120:U:U",
				"DS:lmsens_gpu0:GAUGE:120:0:100",
				"DS:lmsens_gpu1:GAUGE:120:0:100",
				"DS:lmsens_gpu2:GAUGE:120:0:100",
				"DS:lmsens_gpu3:GAUGE:120:0:100",
				"DS:lmsens_gpu4:GAUGE:120:0:100",
				"DS:lmsens_gpu5:GAUGE:120:0:100",
				"DS:lmsens_gpu6:GAUGE:120:0:100",
				"DS:lmsens_gpu7:GAUGE:120:0:100",
				"DS:lmsens_gpu8:GAUGE:120:0:100",
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

	$config->{lmsens_hist_alerts} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub lmsens_alerts {
	my $myself = (caller(0))[3];
	my $config = (shift);
	my $sensor = (shift);
	my $val = (shift);

	my $lmsens = $config->{lmsens};
	my @al = split(',', $lmsens->{alerts}->{$sensor} || "");

	if(scalar(@al)) {
		my $timeintvl = trim($al[0]);
		my $threshold = trim($al[1]);
		my $script = trim($al[2]);
	
		if(!$threshold || $val < $threshold) {
			$config->{lmsens_hist_alerts}->{$sensor} = 0;
		} else {
			if(!$config->{lmsens_hist_alerts}->{$sensor}) {
				$config->{lmsens_hist_alerts}->{$sensor} = time;
			}
			if($config->{lmsens_hist_alerts}->{$sensor} > 0 && (time - $config->{lmsens_hist_alerts}->{$sensor}) >= $timeintvl) {
				if(-x $script) {
					logger("$myself: alert on LM-Sensor ($sensor): executing script '$script'.");
					system($script . " " . $timeintvl . " " . $threshold . " " . $val);
				} else {
					logger("$myself: ERROR: script '$script' doesn't exist or don't has execution permissions.");
				}
				$config->{lmsens_hist_alerts}->{$sensor} = time;
			}
		}
	}
}

sub lmsens_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $lmsens = $config->{lmsens};

	my @mb = (0) x 2;
	my @cpu = (0) x 4;
	my @fan = (0) x 9;
	my @core = (0) x 16;
	my @volt = (0) x 12;
	my @gpu = (0) x 9;

	my $l;
	my $n;
	my $rrdata = "N";

	if($config->{os} eq "Linux") {
		if($lmsens->{list}) {
			my @data;
	  		if(open(IN, "sensors |")) {
				@data = <IN>;
				close(IN);
			} else {
				logger("$myself: WARNING: unable to execute 'sensors' command.");
			}
			my $str;
			for($l = 0; $l < scalar(@data); $l++) {
				for($n = 0; $n < 2; $n++) {
					$str = "mb" . $n;
					$mb[$n] = 0 unless $mb[$n];
					next if !$lmsens->{list}->{$str};
					if($data[$l] =~ /^$lmsens->{list}->{$str}:/ && $data[$l] !~ /RPM/) {
						my (undef, $tmp) = split(':', $data[$l]);
						if($tmp eq "\n") {
							$l++;
							$tmp = $data[$l];
						}
						my ($value, undef) = split(' ', $tmp);
						if($value =~ m/^\+?(\d{1,3}\.?\d*)/) {
							$value = $1;
						}
						$mb[$n] = int($value);
						# check alerts for each sensor defined
						lmsens_alerts($config, $str, $value);
					}
				}
				for($n = 0; $n < 4; $n++) {
					$str = "cpu" . $n;
					$cpu[$n] = 0 unless $cpu[$n];
					next if !$lmsens->{list}->{$str};
					if($data[$l] =~ /^$lmsens->{list}->{$str}:/ && $data[$l] !~ /RPM/) {
						my (undef, $tmp) = split(':', $data[$l]);
						if($tmp eq "\n") {
							$l++;
							$tmp = $data[$l];
						}
						my ($value, undef) = split(' ', $tmp);
						if($value =~ m/^\+?(\d{1,3}\.?\d*)/) {
							$value = $1;
						}
						$cpu[$n] = int($value);
						# check alerts for each sensor defined
						lmsens_alerts($config, $str, $value);
					}
				}
				for($n = 0; $n < 9; $n++) {
					$str = "fan" . $n;
					$fan[$n] = 0 unless $fan[$n];
					next if !$lmsens->{list}->{$str};
					if($data[$l] =~ /^$lmsens->{list}->{$str}:/ && $data[$l] =~ /RPM/) {
						my (undef, $tmp) = split(':', $data[$l]);
						if($tmp eq "\n") {
							$l++;
							$tmp = $data[$l];
						}
						my ($value, undef) = split(' ', $tmp);
						$fan[$n] = int($value);
						# check alerts for each sensor defined
						lmsens_alerts($config, $str, $value);
					}
				}
				for($n = 0; $n < 16; $n++) {
					$str = "core" . $n;
					$core[$n] = 0 unless $core[$n];
					next if !$lmsens->{list}->{$str};
					if($data[$l] =~ /^$lmsens->{list}->{$str}:/ && $data[$l] !~ /RPM/) {
						my (undef, $tmp) = split(':', $data[$l]);
						if($tmp eq "\n") {
							$l++;
							$tmp = $data[$l];
						}
						my ($value, undef) = split(' ', $tmp);
						if($value =~ m/^\+?(\d{1,3}\.?\d*)/) {
							$value = $1;
						}
						$core[$n] = int($value);
						# check alerts for each sensor defined
						lmsens_alerts($config, $str, $value);
					}
				}
				for($n = 0; $n < 12; $n++) {
					$str = "volt" . $n;
					$volt[$n] = 0 unless $volt[$n];
					next if !$lmsens->{list}->{$str};
					if($data[$l] =~ /^$lmsens->{list}->{$str}:/ && $data[$l] !~ /RPM/) {
						my (undef, $tmp) = split(':', $data[$l]);
						if($tmp eq "\n") {
							$l++;
							$tmp = $data[$l];
						}
						my ($value, undef) = split(' ', $tmp);
						$volt[$n] = $value;
						# check alerts for each sensor defined
						lmsens_alerts($config, $str, $value);
					}
				}
			}
			for($n = 0; $n < 9; $n++) {
				$str = "gpu" . $n;
				$gpu[$n] = 0 unless $gpu[$n];
				next if !$lmsens->{list}->{$str};
				if($lmsens->{list}->{$str} eq "nvidia") {
					(undef, undef, $gpu[$n]) = split(' ', get_nvidia_data($n));
					if(!$gpu[$n]) {
						# attempt to get data using the old driver version
						my @data = ();
	  					if(open(IN, "nvidia-smi -g $n |")) {
							@data = <IN>;
							close(IN);
						} else {
							logger("$myself: ERROR: 'nvidia-smi' command is not installed.");
						}
						for($l = 0; $l < scalar(@data); $l++) {
							if($data[$l] =~ /Temperature/) {
								my (undef, $tmp) = split(':', $data[$l]);
								if($tmp eq "\n") {
									$l++;
									$tmp = $data[$l];
								}
								my ($value, undef) = split(' ', $tmp);
								$value =~ s/[-]/./;
								$value =~ s/[^0-9.]//g;
								if(int($value) > 0) {
									$gpu[$n] = int($value);
								}
								# check alerts for each sensor defined
								lmsens_alerts($config, $str, $value);
							}
						}
					}
				}
				if($lmsens->{list}->{$str} eq "ati") {
					$gpu[$n] = get_ati_data($n);
					# check alerts for each sensor defined
					lmsens_alerts($config, $str, $gpu[$n]);
				}
			}
		}
		for($n = 0; $n < scalar(@mb); $n++) {
			$rrdata .= ":$mb[$n]";
		}
		for($n = 0; $n < scalar(@cpu); $n++) {
			$rrdata .= ":$cpu[$n]";
		}
		for($n = 0; $n < scalar(@fan); $n++) {
			$rrdata .= ":$fan[$n]";
		}
		for($n = 0; $n < scalar(@core); $n++) {
			$rrdata .= ":$core[$n]";
		}
		for($n = 0; $n < scalar(@volt); $n++) {
			$rrdata .= ":$volt[$n]";
		}
		for($n = 0; $n < scalar(@gpu); $n++) {
			$rrdata .= ":$gpu[$n]";
		}
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub lmsens_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $lmsens = $config->{lmsens};
	my @rigid = split(',', ($lmsens->{rigid} || ""));
	my @limit = split(',', ($lmsens->{limit} || ""));
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
	my $temp_scale = "Celsius";
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $n;
	my $n2;
	my $str;
	my $err;
	my @LC = (
		"#FFA500",
		"#44EEEE",
		"#44EE44",
		"#4444EE",
		"#448844",
		"#EE4444",
		"#EE44EE",
		"#EEEE44",
		"#444444",
		"#BB44EE",
		"#CCCCCC",
		"#B4B444",
		"#D3D701",
		"#E29136",
		"#DDAE8C",
		"#F29967",
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

	if(lc($config->{temperature_scale}) eq "f") {
		$temp_scale = "Fahrenheit";
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
		for($n = 0; $n < 2; $n++) {
			$str = "mb" . $n;
			if($lmsens->{list}->{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($lmsens->{list}->{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		for($n = 0; $n < 4; $n++) {
			$str = "cpu" . $n;
			if($lmsens->{list}->{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($lmsens->{list}->{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		for($n = 0; $n < 9; $n++) {
			$str = "fan" . $n;
			if($lmsens->{list}->{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($lmsens->{list}->{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		for($n = 0; $n < 16; $n++) {
			$str = "core" . $n;
			if($lmsens->{list}->{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($lmsens->{list}->{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		for($n = 0; $n < 12; $n++) {
			$str = "volt" . $n;
			if($lmsens->{list}->{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($lmsens->{list}->{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		for($n = 0; $n < 9; $n++) {
			$str = "gpu" . $n;
			if($lmsens->{list}->{$str}) {
				$line1 .= "  ";
				$line1 .= sprintf("%15s", substr($lmsens->{list}->{$str}, 0, 15));
				$line2 .= "-----------------";
			}
		}
		push(@output, "Time $line1\n");
		push(@output, "-----$line2\n");
		my $l;
		my $line;
		my @row;
		my $time;
		my @mb;
		my @cpu;
		my @fan;
		my @core;
		my @volt;
		my @gpu;
		for($l = 0, $time = $tf->{tb}; $l < ($tf->{tb} * $tf->{ts}); $l++) {
			$line1 = " %2d$tf->{tc} ";
			undef(@row);
			$line = @$data[$l];
			(@mb[0..2-1], @cpu[0..4-1], @fan[0..10-1], @core[0..16-1], @volt[0..10-1], @gpu[0..8-1]) = @$line;
			for($n = 0; $n < 2; $n++) {
				$str = "mb" . $n;
				if($lmsens->{list}->{$str}) {
					push(@row, celsius_to($config, $mb[$n]));
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			for($n = 0; $n < 4; $n++) {
				$str = "cpu" . $n;
				if($lmsens->{list}->{$str}) {
					push(@row, celsius_to($config, $cpu[$n]));
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			for($n = 0; $n < 9; $n++) {
				$str = "fan" . $n;
				if($lmsens->{list}->{$str}) {
					push(@row, $fan[$n]);
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			for($n = 0; $n < 16; $n++) {
				$str = "core" . $n;
				if($lmsens->{list}->{$str}) {
					push(@row, celsius_to($config, $core[$n]));
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			for($n = 0; $n < 12; $n++) {
				$str = "volt" . $n;
				if($lmsens->{list}->{$str}) {
					push(@row, $volt[$n]);
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			for($n = 0; $n < 9; $n++) {
				$str = "gpu" . $n;
				if($lmsens->{list}->{$str}) {
					push(@row, celsius_to($config, $gpu[$n]));
					$line1 .= "  ";
					$line1 .= "%15.1f";
				}
			}
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf("$line1 \n", $time, @row));
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
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG4z = $u . $package . "4z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG5z = $u . $package . "5z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3",
		"$IMG_DIR" . "$IMG4",
		"$IMG_DIR" . "$IMG5");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
			"$IMG_DIR" . "$IMG2z",
			"$IMG_DIR" . "$IMG3z",
			"$IMG_DIR" . "$IMG4z",
			"$IMG_DIR" . "$IMG5z");
	}

	if($title) {
		push(@output, main::graph_header($title, 2));
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	for($n = 0; $n < 4; $n++) {
		for($n2 = $n; $n2 < 16; $n2 += 4) {
			$str = "core" . $n2;
			if($lmsens->{list}->{$str}) {
				$str = $lmsens->{desc}->{$str} ? sprintf("%7s", substr($lmsens->{desc}->{$str}, 0, 7)) : sprintf("Core %2d", $n2);
				push(@tmp, "LINE2:core_$n2" . $LC[$n2] . ":$str\\g");
				push(@tmp, "GPRINT:core_$n2:LAST:\\:%3.0lf      ");
			}
		}
		push(@tmp, "COMMENT: \\n") unless !@tmp;
	}
	for($n = 0; $n < 16; $n++) {
		$str = "core" . $n;
		if($lmsens->{list}->{$str}) {
			$str = $lmsens->{desc}->{$str} ? substr($lmsens->{desc}->{$str}, 0, 7) : sprintf("Core %2d", $n);
			push(@tmpz, "LINE2:core_$n" . $LC[$n] . ":$str");
		}
	}
	# if no COREs are defined then create a blank graph
	if(!@tmp) {
		push(@tmp, "GPRINT:core_0:LAST:%0.0lf");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmpz, "GPRINT:core_0:LAST:%0.0lf");
	}
	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td class='td-valign-top'>\n");
	}
	if(lc($config->{temperature_scale}) eq "f") {
		push(@CDEF, "CDEF:core_0=9,5,/,core0,*,32,+");
		push(@CDEF, "CDEF:core_1=9,5,/,core1,*,32,+");
		push(@CDEF, "CDEF:core_2=9,5,/,core2,*,32,+");
		push(@CDEF, "CDEF:core_3=9,5,/,core3,*,32,+");
		push(@CDEF, "CDEF:core_4=9,5,/,core4,*,32,+");
		push(@CDEF, "CDEF:core_5=9,5,/,core5,*,32,+");
		push(@CDEF, "CDEF:core_6=9,5,/,core6,*,32,+");
		push(@CDEF, "CDEF:core_7=9,5,/,core7,*,32,+");
		push(@CDEF, "CDEF:core_8=9,5,/,core8,*,32,+");
		push(@CDEF, "CDEF:core_9=9,5,/,core9,*,32,+");
		push(@CDEF, "CDEF:core_10=9,5,/,core10,*,32,+");
		push(@CDEF, "CDEF:core_11=9,5,/,core11,*,32,+");
		push(@CDEF, "CDEF:core_12=9,5,/,core12,*,32,+");
		push(@CDEF, "CDEF:core_13=9,5,/,core13,*,32,+");
		push(@CDEF, "CDEF:core_14=9,5,/,core14,*,32,+");
		push(@CDEF, "CDEF:core_15=9,5,/,core15,*,32,+");
	} else {
		push(@CDEF, "CDEF:core_0=core0");
		push(@CDEF, "CDEF:core_1=core1");
		push(@CDEF, "CDEF:core_2=core2");
		push(@CDEF, "CDEF:core_3=core3");
		push(@CDEF, "CDEF:core_4=core4");
		push(@CDEF, "CDEF:core_5=core5");
		push(@CDEF, "CDEF:core_6=core6");
		push(@CDEF, "CDEF:core_7=core7");
		push(@CDEF, "CDEF:core_8=core8");
		push(@CDEF, "CDEF:core_9=core9");
		push(@CDEF, "CDEF:core_10=core10");
		push(@CDEF, "CDEF:core_11=core11");
		push(@CDEF, "CDEF:core_12=core12");
		push(@CDEF, "CDEF:core_13=core13");
		push(@CDEF, "CDEF:core_14=core14");
		push(@CDEF, "CDEF:core_15=core15");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG1",
		"--title=$config->{graphs}->{_lmsens1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=$temp_scale",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:core0=$rrd:lmsens_core0:AVERAGE",
		"DEF:core1=$rrd:lmsens_core1:AVERAGE",
		"DEF:core2=$rrd:lmsens_core2:AVERAGE",
		"DEF:core3=$rrd:lmsens_core3:AVERAGE",
		"DEF:core4=$rrd:lmsens_core4:AVERAGE",
		"DEF:core5=$rrd:lmsens_core5:AVERAGE",
		"DEF:core6=$rrd:lmsens_core6:AVERAGE",
		"DEF:core7=$rrd:lmsens_core7:AVERAGE",
		"DEF:core8=$rrd:lmsens_core8:AVERAGE",
		"DEF:core9=$rrd:lmsens_core9:AVERAGE",
		"DEF:core10=$rrd:lmsens_core10:AVERAGE",
		"DEF:core11=$rrd:lmsens_core11:AVERAGE",
		"DEF:core12=$rrd:lmsens_core12:AVERAGE",
		"DEF:core13=$rrd:lmsens_core13:AVERAGE",
		"DEF:core14=$rrd:lmsens_core14:AVERAGE",
		"DEF:core15=$rrd:lmsens_core15:AVERAGE",
		"CDEF:allvalues=core0,core1,core2,core3,core4,core5,core6,core7,core8,core9,core10,core11,core12,core13,core14,core15,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_lmsens1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:core0=$rrd:lmsens_core0:AVERAGE",
			"DEF:core1=$rrd:lmsens_core1:AVERAGE",
			"DEF:core2=$rrd:lmsens_core2:AVERAGE",
			"DEF:core3=$rrd:lmsens_core3:AVERAGE",
			"DEF:core4=$rrd:lmsens_core4:AVERAGE",
			"DEF:core5=$rrd:lmsens_core5:AVERAGE",
			"DEF:core6=$rrd:lmsens_core6:AVERAGE",
			"DEF:core7=$rrd:lmsens_core7:AVERAGE",
			"DEF:core8=$rrd:lmsens_core8:AVERAGE",
			"DEF:core9=$rrd:lmsens_core9:AVERAGE",
			"DEF:core10=$rrd:lmsens_core10:AVERAGE",
			"DEF:core11=$rrd:lmsens_core11:AVERAGE",
			"DEF:core12=$rrd:lmsens_core12:AVERAGE",
			"DEF:core13=$rrd:lmsens_core13:AVERAGE",
			"DEF:core14=$rrd:lmsens_core14:AVERAGE",
			"DEF:core15=$rrd:lmsens_core15:AVERAGE",
			"CDEF:allvalues=core0,core1,core2,core3,core4,core5,core6,core7,core8,core9,core10,core11,core12,core13,core14,core15,+,+,+,+,+,+,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens1/)) {
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
	$lmsens->{list}->{'volt0'} =~ s/\\// if $lmsens->{list}->{'volt0'};
	$str = $lmsens->{list}->{'volt0'} ? sprintf("%8s", substr($lmsens->{list}->{'volt0'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt0'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt0'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt0#FFA500:$str\\g", "GPRINT:volt0:LAST:\\:%6.2lf   "));
	$lmsens->{list}->{'volt3'} =~ s/\\// if $lmsens->{list}->{'volt3'};
	$str = $lmsens->{list}->{'volt3'} ? sprintf("%8s", substr($lmsens->{list}->{'volt3'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt3'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt3'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt3#4444EE:$str\\g", "GPRINT:volt3:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt6'} =~ s/\\// if $lmsens->{list}->{'volt6'};;
	$str = $lmsens->{list}->{'volt6'} ? sprintf("%8s", substr($lmsens->{list}->{'volt6'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt6'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt6'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt6#EE44EE:$str\\g", "GPRINT:volt6:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt9'} =~ s/\\// if $lmsens->{list}->{'volt9'};;
	$str = $lmsens->{list}->{'volt9'} ? sprintf("%8s", substr($lmsens->{list}->{'volt9'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt9'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt9'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt9#94C36B:$str\\g", "GPRINT:volt9:LAST:\\:%6.2lf\\g")) unless !$str;
	push(@tmp, "COMMENT: \\n");
	$lmsens->{list}->{'volt1'} =~ s/\\// if $lmsens->{list}->{'volt1'};;
	$str = $lmsens->{list}->{'volt1'} ? sprintf("%8s", substr($lmsens->{list}->{'volt1'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt1'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt1'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt1#44EEEE:$str\\g", "GPRINT:volt1:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt4'} =~ s/\\// if $lmsens->{list}->{'volt4'};;
	$str = $lmsens->{list}->{'volt4'} ? sprintf("%8s", substr($lmsens->{list}->{'volt4'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt4'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt4'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt4#448844:$str\\g", "GPRINT:volt4:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt7'} =~ s/\\// if $lmsens->{list}->{'volt7'};;
	$str = $lmsens->{list}->{'volt7'} ? sprintf("%8s", substr($lmsens->{list}->{'volt7'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt7'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt7'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt7#EEEE44:$str\\g", "GPRINT:volt7:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt10'} =~ s/\\// if $lmsens->{list}->{'volt10'};;
	$str = $lmsens->{list}->{'volt10'} ? sprintf("%8s", substr($lmsens->{list}->{'volt10'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt10'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt10'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt10#3CB5B0:$str\\g", "GPRINT:volt10:LAST:\\:%6.2lf\\g")) unless !$str;
	push(@tmp, "COMMENT: \\n");
	$lmsens->{list}->{'volt2'} =~ s/\\// if $lmsens->{list}->{'volt2'};;
	$str = $lmsens->{list}->{'volt2'} ? sprintf("%8s", substr($lmsens->{list}->{'volt2'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt2'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt2'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt2#44EE44:$str\\g", "GPRINT:volt2:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt5'} =~ s/\\// if $lmsens->{list}->{'volt5'};;
	$str = $lmsens->{list}->{'volt5'} ? sprintf("%8s", substr($lmsens->{list}->{'volt5'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt5'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt5'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt5#EE4444:$str\\g", "GPRINT:volt5:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt8'} =~ s/\\// if $lmsens->{list}->{'volt8'};;
	$str = $lmsens->{list}->{'volt8'} ? sprintf("%8s", substr($lmsens->{list}->{'volt8'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt8'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt8'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt8#963C74:$str\\g", "GPRINT:volt8:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt11'} =~ s/\\// if $lmsens->{list}->{'volt11'};;
	$str = $lmsens->{list}->{'volt11'} ? sprintf("%8s", substr($lmsens->{list}->{'volt11'}, 0, 8)) : "";
	$str = $lmsens->{desc}->{'volt11'} ? sprintf("%8s", substr($lmsens->{desc}->{'volt11'}, 0, 8)) : $str;
	push(@tmp, ("LINE2:volt11#597AB7:$str\\g", "GPRINT:volt11:LAST:\\:%6.2lf\\g")) unless !$str;
	push(@tmp, "COMMENT: \\n");
	$str = $lmsens->{list}->{'volt0'} ? substr($lmsens->{list}->{'volt0'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt0'} ? substr($lmsens->{desc}->{'volt0'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt0#FFA500:$str");
	$str = $lmsens->{list}->{'volt1'} ? substr($lmsens->{list}->{'volt1'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt1'} ? substr($lmsens->{desc}->{'volt1'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt1#44EEEE:$str")unless !$str;
	$str = $lmsens->{list}->{'volt2'} ? substr($lmsens->{list}->{'volt2'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt2'} ? substr($lmsens->{desc}->{'volt2'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt2#44EE44:$str")unless !$str;
	$str = $lmsens->{list}->{'volt3'} ? substr($lmsens->{list}->{'volt3'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt3'} ? substr($lmsens->{desc}->{'volt3'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt3#4444EE:$str")unless !$str;
	$str = $lmsens->{list}->{'volt4'} ? substr($lmsens->{list}->{'volt4'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt4'} ? substr($lmsens->{desc}->{'volt4'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt4#448844:$str")unless !$str;
	$str = $lmsens->{list}->{'volt5'} ? substr($lmsens->{list}->{'volt5'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt5'} ? substr($lmsens->{desc}->{'volt5'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt5#EE4444:$str")unless !$str;
	$str = $lmsens->{list}->{'volt6'} ? substr($lmsens->{list}->{'volt6'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt6'} ? substr($lmsens->{desc}->{'volt6'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt6#EE44EE:$str")unless !$str;
	$str = $lmsens->{list}->{'volt7'} ? substr($lmsens->{list}->{'volt7'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt7'} ? substr($lmsens->{desc}->{'volt7'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt7#EEEE44:$str")unless !$str;
	$str = $lmsens->{list}->{'volt8'} ? substr($lmsens->{list}->{'volt8'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt8'} ? substr($lmsens->{desc}->{'volt8'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt8#963C74:$str")unless !$str;
	$str = $lmsens->{list}->{'volt9'} ? substr($lmsens->{list}->{'volt9'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt9'} ? substr($lmsens->{desc}->{'volt9'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt9#94C36B:$str")unless !$str;
	$str = $lmsens->{list}->{'volt10'} ? substr($lmsens->{list}->{'volt10'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt10'} ? substr($lmsens->{desc}->{'volt10'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt10#3CB5B0:$str")unless !$str;
	$str = $lmsens->{list}->{'volt11'} ? substr($lmsens->{list}->{'volt11'}, 0, 8) : "";
	$str = $lmsens->{desc}->{'volt11'} ? substr($lmsens->{desc}->{'volt11'}, 0, 8) : $str;
	push(@tmpz, "LINE2:volt11#597AB7:$str") unless !$str;
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) 
		if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if
		 $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_lmsens2}  ($tf->{nwhen}$tf->{twhen})
		",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Volts",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:volt0=$rrd:lmsens_volt0:AVERAGE",
		"DEF:volt1=$rrd:lmsens_volt1:AVERAGE",
		"DEF:volt2=$rrd:lmsens_volt2:AVERAGE",
		"DEF:volt3=$rrd:lmsens_volt3:AVERAGE",
		"DEF:volt4=$rrd:lmsens_volt4:AVERAGE",
		"DEF:volt5=$rrd:lmsens_volt5:AVERAGE",
		"DEF:volt6=$rrd:lmsens_volt6:AVERAGE",
		"DEF:volt7=$rrd:lmsens_volt7:AVERAGE",
		"DEF:volt8=$rrd:lmsens_volt8:AVERAGE",
		"DEF:volt9=$rrd:lmsens_volt9:AVERAGE",
		"DEF:volt10=$rrd:lmsens_volt10:AVERAGE",
		"DEF:volt11=$rrd:lmsens_volt11:AVERAGE",
		"CDEF:allvalues=volt0,volt1,volt2,volt3,volt4,volt5,volt6,volt7,volt8,volt9,volt10,volt11,+,+,+,+,+,+,+,+,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_lmsens2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Volts",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:volt0=$rrd:lmsens_volt0:AVERAGE",
			"DEF:volt1=$rrd:lmsens_volt1:AVERAGE",
			"DEF:volt2=$rrd:lmsens_volt2:AVERAGE",
			"DEF:volt3=$rrd:lmsens_volt3:AVERAGE",
			"DEF:volt4=$rrd:lmsens_volt4:AVERAGE",
			"DEF:volt5=$rrd:lmsens_volt5:AVERAGE",
			"DEF:volt6=$rrd:lmsens_volt6:AVERAGE",
			"DEF:volt7=$rrd:lmsens_volt7:AVERAGE",
			"DEF:volt8=$rrd:lmsens_volt8:AVERAGE",
			"DEF:volt9=$rrd:lmsens_volt9:AVERAGE",
			"DEF:volt10=$rrd:lmsens_volt10:AVERAGE",
			"DEF:volt11=$rrd:lmsens_volt11:AVERAGE",
			"CDEF:allvalues=volt0,volt1,volt2,volt3,volt4,volt5,volt6,volt7,volt8,volt9,volt10,volt11,+,+,+,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens2/)) {
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
	$str = $lmsens->{desc}->{'mb0'} ? sprintf("%5s", substr($lmsens->{desc}->{'mb0'}, 0, 5)) : "MB  0";
	push(@tmp, ("LINE2:mb_0#FFA500:$str\\g", "GPRINT:mb_0:LAST:\\:%3.0lf   "));
	$str = $lmsens->{desc}->{'cpu0'} ? sprintf("%5s", substr($lmsens->{desc}->{'cpu0'}, 0, 5)) : "CPU 0";
	push(@tmp, ("LINE2:cpu_0#4444EE:$str\\g", "GPRINT:cpu_0:LAST:\\:%3.0lf   ")) unless !$lmsens->{list}->{'cpu0'};
	$str = $lmsens->{desc}->{'cpu2'} ? sprintf("%5s", substr($lmsens->{desc}->{'cpu2'}, 0, 5)) : "CPU 2";
	push(@tmp, ("LINE2:cpu_2#EE44EE:$str\\g", "GPRINT:cpu_2:LAST:\\:%3.0lf\\g")) unless !$lmsens->{list}->{'cpu2'};
	push(@tmp, "COMMENT: \\n");
	$str = $lmsens->{desc}->{'mb1'} ? sprintf("%5s", substr($lmsens->{desc}->{'mb1'}, 0, 5)) : "MB  1";
	push(@tmp, ("LINE2:mb_1#44EEEE:$str\\g", "GPRINT:mb_1:LAST:\\:%3.0lf   ")) unless !$lmsens->{list}->{'mb1'};
	$str = $lmsens->{desc}->{'cpu1'} ? sprintf("%5s", substr($lmsens->{desc}->{'cpu1'}, 0, 5)) : "CPU 1";
	push(@tmp, ("LINE2:cpu_1#EEEE44:$str\\g", "GPRINT:cpu_1:LAST:\\:%3.0lf   ")) unless !$lmsens->{list}->{'cpu1'};
	$str = $lmsens->{desc}->{'cpu3'} ? sprintf("%5s", substr($lmsens->{desc}->{'cpu3'}, 0, 5)) : "CPU 3";
	push(@tmp, ("LINE2:cpu_3#44EE44:$str\\g", "GPRINT:cpu_3:LAST:\\:%3.0lf\\g")) unless !$lmsens->{list}->{'cpu3'};
	push(@tmp, "COMMENT: \\n");

	$str = $lmsens->{desc}->{'mb0'} ? substr($lmsens->{desc}->{'mb0'}, 0, 8) : "MB 0";
	push(@tmpz, "LINE2:mb_0#FFA500:$str");
	$str = $lmsens->{desc}->{'mb1'} ? substr($lmsens->{desc}->{'mb1'}, 0, 8) : "MB 1";
	push(@tmpz, "LINE2:mb_1#44EEEE:$str") unless !$lmsens->{list}->{'mb1'};
	$str = $lmsens->{desc}->{'cpu0'} ? substr($lmsens->{desc}->{'cpu0'}, 0, 8) : "CPU 0";
	push(@tmpz, "LINE2:cpu_0#4444EE:$str") unless !$lmsens->{list}->{'cpu0'};
	$str = $lmsens->{desc}->{'cpu1'} ? substr($lmsens->{desc}->{'cpu1'}, 0, 8) : "CPU 1";
	push(@tmpz, "LINE2:cpu_1#EEEE44:$str") unless !$lmsens->{list}->{'cpu1'};
	$str = $lmsens->{desc}->{'cpu2'} ? substr($lmsens->{desc}->{'cpu2'}, 0, 8) : "CPU 2";
	push(@tmpz, "LINE2:cpu_2#EE44EE:$str") unless !$lmsens->{list}->{'cpu2'};
	$str = $lmsens->{desc}->{'cpu3'} ? substr($lmsens->{desc}->{'cpu3'}, 0, 8) : "CPU 3";
	push(@tmpz, "LINE2:cpu_3#44EE44:$str") unless !$lmsens->{list}->{'cpu3'};
	if(lc($config->{temperature_scale}) eq "f") {
		push(@CDEF, "CDEF:mb_0=9,5,/,mb0,*,32,+");
		push(@CDEF, "CDEF:mb_1=9,5,/,mb1,*,32,+");
		push(@CDEF, "CDEF:cpu_0=9,5,/,cpu0,*,32,+");
		push(@CDEF, "CDEF:cpu_1=9,5,/,cpu1,*,32,+");
		push(@CDEF, "CDEF:cpu_2=9,5,/,cpu2,*,32,+");
		push(@CDEF, "CDEF:cpu_3=9,5,/,cpu3,*,32,+");
	} else {
		push(@CDEF, "CDEF:mb_0=mb0");
		push(@CDEF, "CDEF:mb_1=mb1");
		push(@CDEF, "CDEF:cpu_0=cpu0");
		push(@CDEF, "CDEF:cpu_1=cpu1");
		push(@CDEF, "CDEF:cpu_2=cpu2");
		push(@CDEF, "CDEF:cpu_3=cpu3");
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
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG3",
		"--title=$config->{graphs}->{_lmsens3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=$temp_scale",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:mb0=$rrd:lmsens_mb0:AVERAGE",
		"DEF:mb1=$rrd:lmsens_mb1:AVERAGE",
		"DEF:cpu0=$rrd:lmsens_cpu0:AVERAGE",
		"DEF:cpu1=$rrd:lmsens_cpu1:AVERAGE",
		"DEF:cpu2=$rrd:lmsens_cpu2:AVERAGE",
		"DEF:cpu3=$rrd:lmsens_cpu3:AVERAGE",
		"CDEF:allvalues=mb0,mb1,cpu0,cpu1,cpu2,cpu3,+,+,+,+,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_lmsens3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:mb0=$rrd:lmsens_mb0:AVERAGE",
			"DEF:mb1=$rrd:lmsens_mb1:AVERAGE",
			"DEF:cpu0=$rrd:lmsens_cpu0:AVERAGE",
			"DEF:cpu1=$rrd:lmsens_cpu1:AVERAGE",
			"DEF:cpu2=$rrd:lmsens_cpu2:AVERAGE",
			"DEF:cpu3=$rrd:lmsens_cpu3:AVERAGE",
			"CDEF:allvalues=mb0,mb1,cpu0,cpu1,cpu2,cpu3,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens3/)) {
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
	$str = $lmsens->{desc}->{'fan0'} ? sprintf("%5s", substr($lmsens->{desc}->{'fan0'}, 0, 5)) : "Fan 0";
	push(@tmp, ("LINE2:fan0#FFA500:$str\\g", "GPRINT:fan0:LAST:\\:%5.0lf"));
	$str = $lmsens->{desc}->{'fan3'} ? sprintf("%5s", substr($lmsens->{desc}->{'fan3'}, 0, 5)) : "Fan 3";
	push(@tmp, ("LINE2:fan3#4444EE:$str\\g", "GPRINT:fan3:LAST:\\:%5.0lf")) unless !$lmsens->{list}->{'fan3'};
	$str = $lmsens->{desc}->{'fan6'} ? sprintf("%5s", substr($lmsens->{desc}->{'fan6'}, 0, 5)) : "Fan 6";
	push(@tmp, ("LINE2:fan6#EE44EE:$str\\g", "GPRINT:fan6:LAST:\\:%5.0lf\\g")) unless !$lmsens->{list}->{'fan6'};
	push(@tmp, "COMMENT: \\n");
	$str = $lmsens->{desc}->{'fan1'} ? sprintf("%5s", substr($lmsens->{desc}->{'fan1'}, 0, 5)) : "Fan 1";
	push(@tmp, ("LINE2:fan1#44EEEE:$str\\g", "GPRINT:fan1:LAST:\\:%5.0lf")) unless !$lmsens->{list}->{'fan1'};
	$str = $lmsens->{desc}->{'fan4'} ? sprintf("%5s", substr($lmsens->{desc}->{'fan4'}, 0, 5)) : "Fan 4";
	push(@tmp, ("LINE2:fan4#448844:$str\\g", "GPRINT:fan4:LAST:\\:%5.0lf")) unless !$lmsens->{list}->{'fan4'};
	$str = $lmsens->{desc}->{'fan7'} ? sprintf("%5s", substr($lmsens->{desc}->{'fan7'}, 0, 5)) : "Fan 7";
	push(@tmp, ("LINE2:fan7#EEEE44:$str\\g", "GPRINT:fan7:LAST:\\:%5.0lf\\g")) unless !$lmsens->{list}->{'fan7'};
	push(@tmp, "COMMENT: \\n");
	$str = $lmsens->{desc}->{'fan2'} ? sprintf("%5s", substr($lmsens->{desc}->{'fan2'}, 0, 5)) : "Fan 2";
	push(@tmp, ("LINE2:fan2#44EE44:$str\\g", "GPRINT:fan2:LAST:\\:%5.0lf")) unless !$lmsens->{list}->{'fan2'};
	$str = $lmsens->{desc}->{'fan5'} ? sprintf("%5s", substr($lmsens->{desc}->{'fan5'}, 0, 5)) : "Fan 5";
	push(@tmp, ("LINE2:fan5#EE4444:$str\\g", "GPRINT:fan5:LAST:\\:%5.0lf")) unless !$lmsens->{list}->{'fan5'};
	$str = $lmsens->{desc}->{'fan8'} ? sprintf("%5s", substr($lmsens->{desc}->{'fan8'}, 0, 5)) : "Fan 8";
	push(@tmp, ("LINE2:fan8#963C74:$str\\g", "GPRINT:fan8:LAST:\\:%5.0lf\\g")) unless !$lmsens->{list}->{'fan8'};
	push(@tmp, "COMMENT: \\n");

	$str = $lmsens->{desc}->{'fan0'} ? substr($lmsens->{desc}->{'fan0'}, 0, 8) : "Fan 0";
	push(@tmpz, "LINE2:fan0#FFA500:$str");
	$str = $lmsens->{desc}->{'fan1'} ? substr($lmsens->{desc}->{'fan1'}, 0, 8) : "Fan 1";
	push(@tmpz, "LINE2:fan1#44EEEE:$str") unless !$lmsens->{list}->{'fan1'};
	$str = $lmsens->{desc}->{'fan2'} ? substr($lmsens->{desc}->{'fan2'}, 0, 8) : "Fan 2";
	push(@tmpz, "LINE2:fan2#44EE44:$str") unless !$lmsens->{list}->{'fan2'};
	$str = $lmsens->{desc}->{'fan3'} ? substr($lmsens->{desc}->{'fan3'}, 0, 8) : "Fan 3";
	push(@tmpz, "LINE2:fan3#4444EE:$str") unless !$lmsens->{list}->{'fan3'};
	$str = $lmsens->{desc}->{'fan4'} ? substr($lmsens->{desc}->{'fan4'}, 0, 8) : "Fan 4";
	push(@tmpz, "LINE2:fan4#448844:$str") unless !$lmsens->{list}->{'fan4'};
	$str = $lmsens->{desc}->{'fan5'} ? substr($lmsens->{desc}->{'fan5'}, 0, 8) : "Fan 5";
	push(@tmpz, "LINE2:fan5#EE4444:$str") unless !$lmsens->{list}->{'fan5'};
	$str = $lmsens->{desc}->{'fan6'} ? substr($lmsens->{desc}->{'fan6'}, 0, 8) : "Fan 6";
	push(@tmpz, "LINE2:fan6#EE44EE:$str") unless !$lmsens->{list}->{'fan6'};
	$str = $lmsens->{desc}->{'fan7'} ? substr($lmsens->{desc}->{'fan7'}, 0, 8) : "Fan 7";
	push(@tmpz, "LINE2:fan7#EEEE44:$str") unless !$lmsens->{list}->{'fan7'};
	$str = $lmsens->{desc}->{'fan8'} ? substr($lmsens->{desc}->{'fan8'}, 0, 8) : "Fan 8";
	push(@tmpz, "LINE2:fan8#963C74:$str") unless !$lmsens->{list}->{'fan8'};
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
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG4",
		"--title=$config->{graphs}->{_lmsens4}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=RPM",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:fan0=$rrd:lmsens_fan0:AVERAGE",
		"DEF:fan1=$rrd:lmsens_fan1:AVERAGE",
		"DEF:fan2=$rrd:lmsens_fan2:AVERAGE",
		"DEF:fan3=$rrd:lmsens_fan3:AVERAGE",
		"DEF:fan4=$rrd:lmsens_fan4:AVERAGE",
		"DEF:fan5=$rrd:lmsens_fan5:AVERAGE",
		"DEF:fan6=$rrd:lmsens_fan6:AVERAGE",
		"DEF:fan7=$rrd:lmsens_fan7:AVERAGE",
		"DEF:fan8=$rrd:lmsens_fan8:AVERAGE",
		"CDEF:allvalues=fan0,fan1,fan2,fan3,fan4,fan5,fan6,fan7,fan8,+,+,+,+,+,+,+,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG4z",
			"--title=$config->{graphs}->{_lmsens4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=RPM",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:fan0=$rrd:lmsens_fan0:AVERAGE",
			"DEF:fan1=$rrd:lmsens_fan1:AVERAGE",
			"DEF:fan2=$rrd:lmsens_fan2:AVERAGE",
			"DEF:fan3=$rrd:lmsens_fan3:AVERAGE",
			"DEF:fan4=$rrd:lmsens_fan4:AVERAGE",
			"DEF:fan5=$rrd:lmsens_fan5:AVERAGE",
			"DEF:fan6=$rrd:lmsens_fan6:AVERAGE",
			"DEF:fan7=$rrd:lmsens_fan7:AVERAGE",
			"DEF:fan8=$rrd:lmsens_fan8:AVERAGE",
			"CDEF:allvalues=fan0,fan1,fan2,fan3,fan4,fan5,fan6,fan7,fan8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens4/)) {
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
	$str = $lmsens->{desc}->{'gpu0'} ? sprintf("%5s", substr($lmsens->{desc}->{'gpu0'}, 0, 5)) : "GPU 0";
	push(@tmp, "LINE2:gpu_0#FFA500:$str\\g");
	push(@tmp, "GPRINT:gpu_0:LAST:\\:%3.0lf  ");
	$str = $lmsens->{desc}->{'gpu3'} ? sprintf("%5s", substr($lmsens->{desc}->{'gpu3'}, 0, 5)) : "GPU 3";
	push(@tmp, ("LINE2:gpu_3#4444EE:$str\\g", "GPRINT:gpu_3:LAST:\\:%3.0lf  ")) unless !$lmsens->{list}->{'gpu3'};
	$str = $lmsens->{desc}->{'gpu6'} ? sprintf("%5s", substr($lmsens->{desc}->{'gpu6'}, 0, 5)) : "GPU 6";
	push(@tmp, ("LINE2:gpu_6#EE44EE:$str\\g", "GPRINT:gpu_6:LAST:\\:%3.0lf\\g")) unless !$lmsens->{list}->{'gpu6'};
	push(@tmp, "COMMENT: \\n");
	$str = $lmsens->{desc}->{'gpu1'} ? sprintf("%5s", substr($lmsens->{desc}->{'gpu1'}, 0, 5)) : "GPU 1";
	push(@tmp, ("LINE2:gpu_1#44EEEE:$str\\g", "GPRINT:gpu_1:LAST:\\:%3.0lf  ")) unless !$lmsens->{list}->{'gpu1'};
	$str = $lmsens->{desc}->{'gpu4'} ? sprintf("%5s", substr($lmsens->{desc}->{'gpu4'}, 0, 5)) : "GPU 4";
	push(@tmp, ("LINE2:gpu_4#448844:$str\\g", "GPRINT:gpu_4:LAST:\\:%3.0lf  ")) unless !$lmsens->{list}->{'gpu4'};
	$str = $lmsens->{desc}->{'gpu7'} ? sprintf("%5s", substr($lmsens->{desc}->{'gpu7'}, 0, 5)) : "GPU 7";
	push(@tmp, ("LINE2:gpu_7#EEEE44:$str\\g", "GPRINT:gpu_7:LAST:\\:%3.0lf\\g")) unless !$lmsens->{list}->{'gpu7'};
	push(@tmp, "COMMENT: \\n");
	$str = $lmsens->{desc}->{'gpu2'} ? sprintf("%5s", substr($lmsens->{desc}->{'gpu2'}, 0, 5)) : "GPU 2";
	push(@tmp, ("LINE2:gpu_2#44EE44:$str\\g", "GPRINT:gpu_2:LAST:\\:%3.0lf  ")) unless !$lmsens->{list}->{'gpu2'};
	$str = $lmsens->{desc}->{'gpu5'} ? sprintf("%5s", substr($lmsens->{desc}->{'gpu5'}, 0, 5)) : "GPU 5";
	push(@tmp, ("LINE2:gpu_5#EE4444:$str\\g", "GPRINT:gpu_5:LAST:\\:%3.0lf  ")) unless !$lmsens->{list}->{'gpu5'};
	$str = $lmsens->{desc}->{'gpu8'} ? sprintf("%5s", substr($lmsens->{desc}->{'gpu8'}, 0, 5)) : "GPU 8";
	push(@tmp, ("LINE2:gpu_8#963C74:$str\\g", "GPRINT:gpu_8:LAST:\\:%3.0lf\\g")) unless !$lmsens->{list}->{'gpu8'};
	push(@tmp, "COMMENT: \\n");

	$str = $lmsens->{desc}->{'gpu0'} ? substr($lmsens->{desc}->{'gpu0'}, 0, 8) : "GPU 0";
	push(@tmpz, "LINE2:gpu_0#FFA500:$str\\g");
	$str = $lmsens->{desc}->{'gpu1'} ? substr($lmsens->{desc}->{'gpu1'}, 0, 8) : "GPU 1";
	push(@tmpz, "LINE2:gpu_1#44EEEE:$str\\g") unless !$lmsens->{list}->{'gpu1'};
	$str = $lmsens->{desc}->{'gpu2'} ? substr($lmsens->{desc}->{'gpu2'}, 0, 8) : "GPU 2";
	push(@tmpz, "LINE2:gpu_2#44EE44:$str\\g") unless !$lmsens->{list}->{'gpu2'};
	$str = $lmsens->{desc}->{'gpu3'} ? substr($lmsens->{desc}->{'gpu3'}, 0, 8) : "GPU 3";
	push(@tmpz, "LINE2:gpu_3#4444EE:$str\\g") unless !$lmsens->{list}->{'gpu3'};
	$str = $lmsens->{desc}->{'gpu4'} ? substr($lmsens->{desc}->{'gpu4'}, 0, 8) : "GPU 4";
	push(@tmpz, "LINE2:gpu_4#448844:$str\\g") unless !$lmsens->{list}->{'gpu4'};
	$str = $lmsens->{desc}->{'gpu5'} ? substr($lmsens->{desc}->{'gpu5'}, 0, 8) : "GPU 5";
	push(@tmpz, "LINE2:gpu_5#EE4444:$str\\g") unless !$lmsens->{list}->{'gpu5'};
	$str = $lmsens->{desc}->{'gpu6'} ? substr($lmsens->{desc}->{'gpu6'}, 0, 8) : "GPU 6";
	push(@tmpz, "LINE2:gpu_6#EE44EE:$str\\g") unless !$lmsens->{list}->{'gpu6'};
	$str = $lmsens->{desc}->{'gpu7'} ? substr($lmsens->{desc}->{'gpu7'}, 0, 8) : "GPU 7";
	push(@tmpz, "LINE2:gpu_7#EEEE44:$str\\g") unless !$lmsens->{list}->{'gpu7'};
	$str = $lmsens->{desc}->{'gpu8'} ? substr($lmsens->{desc}->{'gpu8'}, 0, 8) : "GPU 8";
	push(@tmpz, "LINE2:gpu_8#963C74:$str\\g") unless !$lmsens->{list}->{'gpu8'};
	if(lc($config->{temperature_scale}) eq "f") {
		push(@CDEF, "CDEF:gpu_0=9,5,/,gpu0,*,32,+");
		push(@CDEF, "CDEF:gpu_1=9,5,/,gpu1,*,32,+");
		push(@CDEF, "CDEF:gpu_2=9,5,/,gpu2,*,32,+");
		push(@CDEF, "CDEF:gpu_3=9,5,/,gpu3,*,32,+");
		push(@CDEF, "CDEF:gpu_4=9,5,/,gpu4,*,32,+");
		push(@CDEF, "CDEF:gpu_5=9,5,/,gpu5,*,32,+");
		push(@CDEF, "CDEF:gpu_6=9,5,/,gpu6,*,32,+");
		push(@CDEF, "CDEF:gpu_7=9,5,/,gpu7,*,32,+");
		push(@CDEF, "CDEF:gpu_8=9,5,/,gpu8,*,32,+");
	} else {
		push(@CDEF, "CDEF:gpu_0=gpu0");
		push(@CDEF, "CDEF:gpu_1=gpu1");
		push(@CDEF, "CDEF:gpu_2=gpu2");
		push(@CDEF, "CDEF:gpu_3=gpu3");
		push(@CDEF, "CDEF:gpu_4=gpu4");
		push(@CDEF, "CDEF:gpu_5=gpu5");
		push(@CDEF, "CDEF:gpu_6=gpu6");
		push(@CDEF, "CDEF:gpu_7=gpu7");
		push(@CDEF, "CDEF:gpu_8=gpu8");
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
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG5",
		"--title=$config->{graphs}->{_lmsens5}  ($tf->{nwhen}$tf->{twhen})
		",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=$temp_scale",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:gpu0=$rrd:lmsens_gpu0:AVERAGE",
		"DEF:gpu1=$rrd:lmsens_gpu1:AVERAGE",
		"DEF:gpu2=$rrd:lmsens_gpu2:AVERAGE",
		"DEF:gpu3=$rrd:lmsens_gpu3:AVERAGE",
		"DEF:gpu4=$rrd:lmsens_gpu4:AVERAGE",
		"DEF:gpu5=$rrd:lmsens_gpu5:AVERAGE",
		"DEF:gpu6=$rrd:lmsens_gpu6:AVERAGE",
		"DEF:gpu7=$rrd:lmsens_gpu7:AVERAGE",
		"DEF:gpu8=$rrd:lmsens_gpu8:AVERAGE",
		"CDEF:allvalues=gpu0,gpu1,gpu2,gpu3,gpu4,gpu5,gpu6,gpu7,gpu8,+,+,+,+,+,+,+,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG5z",
			"--title=$config->{graphs}->{_lmsens5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:gpu0=$rrd:lmsens_gpu0:AVERAGE",
			"DEF:gpu1=$rrd:lmsens_gpu1:AVERAGE",
			"DEF:gpu2=$rrd:lmsens_gpu2:AVERAGE",
			"DEF:gpu3=$rrd:lmsens_gpu3:AVERAGE",
			"DEF:gpu4=$rrd:lmsens_gpu4:AVERAGE",
			"DEF:gpu5=$rrd:lmsens_gpu5:AVERAGE",
			"DEF:gpu6=$rrd:lmsens_gpu6:AVERAGE",
			"DEF:gpu7=$rrd:lmsens_gpu7:AVERAGE",
			"DEF:gpu8=$rrd:lmsens_gpu8:AVERAGE",
			"CDEF:allvalues=gpu0,gpu1,gpu2,gpu3,gpu4,gpu5,gpu6,gpu7,gpu8,+,+,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens5/)) {
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


	if($title) {
		push(@output, "    </td>\n");
		push(@output, "    </tr>\n");
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
