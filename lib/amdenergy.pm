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

package amdenergy;

use strict;
use warnings;
use Monitorix;
use RRDs;
use POSIX;
use Time::HiRes;
use Cwd 'abs_path';
use File::Basename;
use Exporter 'import';
our @EXPORT = qw(amdenergy_init amdenergy_update amdenergy_cgi);

my $core_identifier = "Ecore";
my $socket_identifier = "Esocket";
my $epoc_identifier = "last_epoc";
my $cpu_list_delimiter = ",";
my $number_of_additional_values = 6; # Changing this value will destroy history.
my $number_of_additional_values_in_use = 1;
my $socket_offset = 0;

sub round {
	my ($float) = @_;
  return int($float + $float/abs($float*2 || 1));
}

sub hue_to_rgb {
	my ($p, $q, $t) = @_;
	if($t < 0) {
		$t += 1;
	}
	if($t > 1) {
		$t -= 1;
	}
	if($t < 1/6) {
		return $p + ($q - $p) * 6 * $t;
	}
	if($t < 1/2) {
		return $q;
	}
	if($t < 2/3) {
		return $p + ($q - $p) * (2/3 - $t) * 6;
	}
	return $p;
}

sub hsl_to_rgb {
	my ($H, $S, $L) = @_;
	my $h = $H/360;
	my $s = $S/100;
	my $l = $L/100;
	my ($r, $g, $b);
	if($s == 0) {
		$r = $g = $b = $l;
	} else {
		my $q = $l < 0.5 ? $l * (1 + $s) : $l + $s - $l * $s;
		my $p = 2 * $l - $q;
		$r = hue_to_rgb($p, $q, $h + 1/3);
		$g = hue_to_rgb($p, $q, $h);
		$b = hue_to_rgb($p, $q, $h - 1/3);
	}
	return (round($r * 255), round($g * 255), round($b * 255));
}

sub line_color {
	my ($n, @LC) = @_;
	if ($n < scalar(@LC)) {
		return $LC[$n];
	}
	my $h_step = 31;
	my $h_min = ($n-1) * $h_step;
	my $h_max = $h_min + $h_step;
	my ($r,$g,$b) = hsl_to_rgb($n*($h_max-$h_min)+$h_min, 100, 50);
	return sprintf("#%02x%02x%02x",$r,$g,$b);
}

sub measure {

	my ($myself, $config, $amdenergy) = @_;
	my $use_nan_for_missing_data = lc($amdenergy->{use_nan_for_missing_data} || "") eq "y" ? 1 : 0;

	my @sensors_all;
	my $rrdata = "N";

	foreach my $k (sort keys %{$amdenergy->{list}}) {
		my @cpu_group = split($cpu_list_delimiter, $amdenergy->{list}->{$k});
		for(my $n = 0; $n < scalar(@cpu_group); $n++) {
			my $str = trim($cpu_group[$n]);
			my $number_of_cores = $amdenergy->{number_of_cores}->{$str};
			if (!defined($number_of_cores)) {
				logger("$myself: ERROR: unable to find number_of_cores for key: '" . $str. "'. Please add this key to the config file.");
				return $rrdata;
			}
			my @sensors = ($use_nan_for_missing_data ? (0+"nan") : 0) x ($number_of_cores + $number_of_additional_values);
			my @data;
			if(open(IN, $amdenergy->{cmd} . " " . $str . " |")) {
				@data = <IN>;
				close(IN);
			} else {
				logger("$myself: WARNING: unable to execute '" . $amdenergy->{cmd} . "' command.");
			}

			my $last_epoc = ($config->{amdenergy_hist}->{$k}->{$str}->{$epoc_identifier} || 0);
			my $epoc = Time::HiRes::time();
			$config->{amdenergy_hist}->{$k}->{$str}->{$epoc_identifier} = $epoc;

			my $socket_index;
			my $i_core = 0;
			for(my $l = 0; $l < scalar(@data); $l++) {
				if (index($data[$l], $core_identifier) != -1) {
					my (undef, $tmp) = split(':', $data[$l+1]);
					chomp($tmp);
					$tmp = trim($tmp);
					my $last_core_energy = ($config->{amdenergy_hist}->{$k}->{$str}->{$core_identifier . $i_core} || 0);
					my $core_energy = $tmp;
					$config->{amdenergy_hist}->{$k}->{$str}->{$core_identifier . $i_core} = $core_energy;
					if ($last_epoc ne 0 && $core_energy >= $last_core_energy) {
						$sensors[$i_core] = ($core_energy - $last_core_energy) / ($epoc - $last_epoc); # Conversion from Joule to Watt during the time interval.
					}
					$i_core++;
					$l++;
				}
				if (index($data[$l], $socket_identifier) != -1) {
					my (undef, $tmp) = split(':', $data[$l+1]);
					chomp($tmp);
					$tmp = trim($tmp);
					my $last_socket_energy = ($config->{amdenergy_hist}->{$k}->{$str}->{$socket_identifier . ($number_of_cores + $socket_offset)} || 0);
					my $socket_energy = $tmp;
					$config->{amdenergy_hist}->{$k}->{$str}->{$socket_identifier . $i_core} = $socket_energy;
					if ($last_epoc ne 0 && $socket_energy >= $last_socket_energy) {
						$sensors[($number_of_cores + $socket_offset)] = ($socket_energy - $last_socket_energy) / ($epoc - $last_epoc); # Conversion from Joule to Watt during the time interval.
						$socket_index = ($number_of_cores + $socket_offset);
					}
					$l++;
				}
			}

			push(@sensors_all, @sensors);

			if(defined($socket_index) && defined($amdenergy->{alerts}) && lc($amdenergy->{alerts}->{socketpower_enabled}) eq "y") {
				my $sensorIndex = $socket_index;
				$config->{amdenergy_hist_alert1}->{$n} = 0 if(!$config->{amdenergy_hist_alert1}->{$n});
				if($sensors[$sensorIndex] >= $amdenergy->{alerts}->{socketpower_threshold} && $config->{amdenergy_hist_alert1}->{$n} < $sensors[$sensorIndex]) {
					if(-x $amdenergy->{alerts}->{socketpower_script}) {
						logger("$myself: ALERT: executing script '$amdenergy->{alerts}->{socketpower_script}'.");
						system($amdenergy->{alerts}->{socketpower_script} . " " .$amdenergy->{alerts}->{socketpower_timeintvl} . " " . $amdenergy->{alerts}->{socketpower_threshold} . " " . $sensors[$sensorIndex]);
					} else {
						logger("$myself: ERROR: script '$amdenergy->{alerts}->{socketpower_script}' doesn't exist or don't has execution permissions.");
					}
					$config->{amdenergy_hist_alert1}->{$n} = $sensors[$sensorIndex];
				}
			}
		}
	}

	foreach(@sensors_all) {
		$rrdata .= ":$_";
	}

	return $rrdata;
}

sub amdenergy_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $amdenergy = $config->{amdenergy};

	my $info;
	my @ds;
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

	if(!defined($config->{amdenergy}->{cmd})) {
		$config->{amdenergy}->{cmd} = "sensors -u";
	}

	# checks if binary does exists.
	if(!open(IN, $amdenergy->{cmd} . " |")) {
		logger("$myself: unable to execute '" . $amdenergy->{cmd} . "'. $!");
		return;
	}
	close(IN);

	if(-e $rrd) {
		my $rrd_n_cpu = 0;
		my $rrd_n_cpu_times_n_values = 0;
		my $rrd_n_cpu_times_n_additional_values = 0;
		my $rrd_n_list_item = 0;
		my $rrd_n_cores = 0;
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'ds[') == 0) {
				if(index($key, '.type') != -1) {
					push(@ds, substr($key, 3, index($key, ']') - 3));
				}
				if(index($key, '_val0].index') != -1) {
					$rrd_n_cpu += 1;
					if(index($key, 'cpu0_val0].index') != -1) {
						$rrd_n_list_item += 1;
					}
				}
				if(index($key, '.index') != -1) {
					$rrd_n_cpu_times_n_values += 1;
				}
				if(index($key, 'add].index') != -1) {
					$rrd_n_cpu_times_n_additional_values += 1;
				}
			}
			if(index($key, 'rra[') == 0) {
				if(index($key, '.rows') != -1) {
					push(@rra, substr($key, 4, index($key, ']') - 4));
				}
			}
		}

		my $total_number_of_cpus = 0;
		my $total_number_of_cores = 0;
		foreach my $k (sort keys %{$amdenergy->{list}}) {
			my @cpu_group = split($cpu_list_delimiter, $amdenergy->{list}->{$k});
			$total_number_of_cpus += scalar(@cpu_group);
			for(my $n = 0; $n < scalar(@cpu_group); $n++) {
				my $str = trim($cpu_group[$n]);
				my $number_of_cores = $amdenergy->{number_of_cores}->{$str};
				if (!defined($number_of_cores)) {
					logger("$myself: ERROR: unable to find number_of_cores for key: '" . $str. "'. Please add this key to the config file.");
					return;
				}
				$total_number_of_cores += $number_of_cores;
			}
		}

		if($rrd_n_list_item != keys(%{$amdenergy->{list}})) {
			logger("$myself: Detected size mismatch between <list>...</list> (" . keys(%{$amdenergy->{list}}) . ") and $rrd (" . $rrd_n_list_item . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if(($rrd_n_cpu_times_n_additional_values / $rrd_n_cpu) != $number_of_additional_values) {
			logger("$myself: Detected mismatch between number_of_additional_values (" . $number_of_additional_values . ") and $rrd (" . ($rrd_n_cpu_times_n_additional_values / $rrd_n_cpu) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if($rrd_n_cpu != $total_number_of_cpus) {
			logger("$myself: Detected size mismatch between total number of CPUs (" . $total_number_of_cpus . ") and $rrd (" . $rrd_n_cpu . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if(($rrd_n_cpu_times_n_values -$rrd_n_cpu_times_n_additional_values) != $total_number_of_cores) {
			logger("$myself: Detected mismatch between total number of cores (" . $total_number_of_cores . ") and $rrd (" . ($rrd_n_cpu_times_n_values -$rrd_n_cpu_times_n_additional_values) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for(my $k = 0; $k < keys(%{$amdenergy->{list}}); $k++) {
			my @cpu_group = split($cpu_list_delimiter, $amdenergy->{list}->{$k});
			for($n = 0; $n < scalar(@cpu_group); $n++) {
				my $str = trim($cpu_group[$n]);
				my $number_of_cores = $amdenergy->{number_of_cores}->{$str};
				for(my $n_sensor = 0; $n_sensor < $number_of_cores; $n_sensor++) {
					push(@tmp, "DS:en" . $k . "_cpu" . $n . "_val" . $n_sensor . ":GAUGE:120:0:U");
				}
				for(my $n_sensor = 0; $n_sensor < $number_of_additional_values; $n_sensor++) {
					push(@tmp, "DS:en" . $k . "_cpu" . $n . "_" . $n_sensor . "add" . ":GAUGE:120:0:U");
				}
			}
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

	# check dependencies
	if(defined($amdenergy->{alerts}) && lc($amdenergy->{alerts}->{socketpower_enabled} || "") eq "y") {
		if(! -x $amdenergy->{alerts}->{socketpower_script}) {
			logger("$myself: ERROR: script '$amdenergy->{alerts}->{socketpower_script}' doesn't exist or don't has execution permissions.");
		}
	}

	$config->{amdenergy_hist_alert1} = ();
	$config->{amdenergy_hist} = ();
	push(@{$config->{func_update}}, $package);

	measure($myself, $config, $amdenergy);

	logger("$myself: Ok") if $debug;
}

sub amdenergy_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $amdenergy = $config->{amdenergy};

	my $rrdata = measure($myself, $config, $amdenergy);

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub amdenergy_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $amdenergy = $config->{amdenergy};
	my @rigid = split(',', ($amdenergy->{rigid} || ""));
	my @limit = split(',', ($amdenergy->{limit} || ""));
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
	my @IMG;
	my @IMGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $n;
	my $n2;
	my $e;
	my $e2;
	my $str;
	my $err;
	my @LC = (
		"#44EE44",
		"#44EEEE",
		"#a600ff",
		"#4444EE",
	);

	my @LC2 = (
		"#ff9100",
		"#448844",
		"#EE4444",
		"#EE44EE",
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
	my $gap_on_all_nan = lc($amdenergy->{gap_on_all_nan} || "") eq "y" ? 1 : 0;

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
		my $line3;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		foreach my $k (sort keys %{$amdenergy->{list}}) {
			my @cpu_group = split($cpu_list_delimiter, $amdenergy->{list}->{$k});
			for($n = 0; $n < scalar(@cpu_group); $n++) {
				$str = sprintf(" AMD energy cpu %d               ", $n + 1);
				$line1 .= $str;
				$str = sprintf(" Sensor values ");
				$line2 .= $str;
				$line3 .=      "----------------------";
			}
		}
		push(@output, "     $line1\n");
		push(@output, "Time $line2\n");
		push(@output, "-----$line3\n");
		my $line;
		my @row;
		my $time;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			$e = 0;
			foreach my $k (sort keys %{$amdenergy->{list}}) {
				my @cpu_group = split($cpu_list_delimiter, $amdenergy->{list}->{$k});

				for($n2 = 0; $n2 < scalar(@cpu_group); $n2++) {
					my $str = trim($cpu_group[$n2]);
					my $number_of_cores = $amdenergy->{number_of_cores}->{$str};
					my $number_of_values_per_cpu_in_rrd = $number_of_cores + $number_of_additional_values_in_use;
					$from = ($e * scalar(@cpu_group) * $number_of_values_per_cpu_in_rrd) + ($n2 * $number_of_values_per_cpu_in_rrd);
					$to = $from + 1;
					my @sensor_values = @$line[$from..$to];
					@row = (celsius_to($config, $sensor_values[0]), @sensor_values[1, -1]);
					my $format_string = "%7.0f" x scalar(@row);
					push(@output, sprintf(" " . $format_string. " ", @row));
				}
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

	my $plots_per_list_item = 1;
	foreach my $k (sort keys %{$amdenergy->{list}}) {
		for($n = 0; $n < $plots_per_list_item; $n++) {
			$str = $u . $package . $k . "_" . $n . "." . $tf->{when} . ".$imgfmt_lc";
			push(@IMG, $str);
			unlink("$IMG_DIR" . $str);
			if(lc($config->{enable_zoom}) eq "y") {
				$str = $u . $package . $k . "_" . $n . "z." . $tf->{when} . ".$imgfmt_lc";
				push(@IMGz, $str);
				unlink("$IMG_DIR" . $str);
			}
		}
	}

	$e = 0;
	foreach my $k (sort keys %{$amdenergy->{list}}) {
		my @cpu_group = split($cpu_list_delimiter, $amdenergy->{list}->{$k});
		if($title && $e == 0) {
			push(@output, main::graph_header($title, 1));
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}

		my $n_plot = 0;
		@riglim = @{setup_riglim($rigid[$n_plot], $limit[$n_plot])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < scalar(@cpu_group); $n += 1) {
			my $dstr = trim($cpu_group[$n]);
			my $core_string = $dstr;
			my $base = "";
			$dstr =~ s/^\"//;
			$dstr =~ s/\"$//;

			if($base && defined($amdenergy->{map}->{$base})) {
				$dstr = $amdenergy->{map}->{$base};
			} else {
				if(defined($amdenergy->{map}->{$dstr})) {
					$dstr = $amdenergy->{map}->{$dstr};
				}
			}
			$str = $dstr;

			my $legend_label_format = "%7.2lf";
			my $value_transformation = "";

			my $cpu_label_size = 53;
			my $cpu_label = sprintf("%-" . $cpu_label_size . "s", $str);
			my $cpu_label_empty = sprintf("%-" . $cpu_label_size . "s", "");

			my $number_of_cores = $amdenergy->{number_of_cores}->{$core_string};

			my $socket_name = "cpu" . $n . "_" . $socket_offset . "add";

			my $core_sum_name = "core_sum". $n;
			my $cdef_core_sum = "CDEF:" . $core_sum_name . "=";

			for(my $i_core = 0; $i_core < $number_of_cores; $i_core++) {
				my $value_name = "cpu" . $n . "_val" . $i_core;
				my $hex_transparancy = "E6";
				my ($r,$g,$b);
				if ($n == 0) {
					($r,$g,$b) = (46, $i_core/$number_of_cores*255, 255);
				} else {
					my $h_step = 61;
					my $h_min = ($n-1) * $h_step;
					my $h_max = $h_min + $h_step;
					($r,$g,$b) = hsl_to_rgb($i_core/$number_of_cores*($h_max-$h_min)+$h_min, 100, 50);
				}
				my $hex_color = sprintf("#%02x%02x%02x",$r,$g,$b) . $hex_transparancy;

				if ($i_core != 0) {
					$cdef_core_sum .= ",";
				}
				$cdef_core_sum .= $value_name;
				push(@CDEF, "CDEF:trans_" . $value_name . "=" . $value_name . $value_transformation);

				my $legend_label = "";
				if ($i_core == 0) {
					$legend_label = "-\\g";
				} elsif ($i_core + 1 == $number_of_cores) {
					$legend_label = "Cores 0-".$i_core;
				}

				if ($i_core == 0) {
				  push(@tmp, "COMMENT:" . $cpu_label);
				}
				push(@tmp, "AREA:trans_" . $value_name . $hex_color . ":" . $legend_label . (($i_core == 0) ? "" : ":STACK"));
				push(@tmpz, "AREA:trans_" . $value_name . $hex_color . ":" . $legend_label . (($i_core == 0) ? "" : ":STACK"));
			}

			$cdef_core_sum .= ",+" x ($number_of_cores-1);
			push(@CDEF, $cdef_core_sum);
			push(@CDEF, "CDEF:trans_" . $core_sum_name . "=" . $core_sum_name . $value_transformation);

			push(@tmp, "GPRINT:trans_" . $core_sum_name . ":LAST:    Sum\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $core_sum_name . ":AVERAGE:Average\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $core_sum_name . ":MIN:Min\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $core_sum_name . ":MAX:Max\\:" . $legend_label_format . "\\n");

			my $socket_overhead_name = "socket_overhead". $n;
			my $cdef_socket_overhead = "CDEF:" . $socket_overhead_name . "=" . $socket_name . "," . $core_sum_name . ",-";
			push(@CDEF, $cdef_socket_overhead);

			my $hex_color = line_color($n, @LC2);

			my $number_of_cores_digits = length($number_of_cores-1);
			my $legend_size = 10 + $number_of_cores_digits;

			my $socket_overhead_label = sprintf("%-" . $legend_size . "s", "Non-Core");

			push(@CDEF, "CDEF:trans_" . $socket_overhead_name . "=" . $socket_overhead_name . $value_transformation);

			push(@tmp, "COMMENT:". $cpu_label_empty);

			push(@tmp, "LINE1:trans_" . $socket_overhead_name . $hex_color . ":" . $socket_overhead_label);
			push(@tmpz, "LINE1:trans_" . $socket_overhead_name . $hex_color . ":" . $socket_overhead_label);

			push(@tmp, "GPRINT:trans_" . $socket_overhead_name . ":LAST: Current\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $socket_overhead_name . ":AVERAGE:Average\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $socket_overhead_name . ":MIN:Min\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $socket_overhead_name . ":MAX:Max\\:" . $legend_label_format . "\\n");

			my $socket_label = sprintf("%-" . $legend_size . "s", "Socket");

			push(@CDEF, "CDEF:trans_" . $socket_name . "=" . $socket_name . $value_transformation);

			push(@tmp, "COMMENT:". $cpu_label_empty);
			push(@tmp, "LINE1:trans_" . $socket_name . line_color($n, @LC) . ":" . $socket_label);
			push(@tmpz, "LINE1:trans_" . $socket_name . line_color($n, @LC) . ":" . $socket_label);

			push(@tmp, "GPRINT:trans_" . $socket_name . ":LAST: Current\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $socket_name . ":AVERAGE:Average\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $socket_name . ":MIN:Min\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $socket_name . ":MAX:Max\\:" . $legend_label_format . "\\n");
		}

		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		my $graph_size_name = "large";
		($width, $height) = split('x', $config->{graph_size}->{$graph_size_name});
		if($silent =~ /imagetag/) {
			($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
			($width, $height) = split('x', $config->{graph_size}->{$graph_size_name}) if $silent eq "imagetagbig";
			@tmp = @tmpz;
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}

		my @def_sensor_average;
		my $cdef_sensor_allvalues = "CDEF:allvalues=";
		my $sum_of_values = 0;
		for(my $n_cpu = 0; $n_cpu < scalar(@cpu_group); $n_cpu++) {
			my $dstr = trim($cpu_group[$n_cpu]);
			my $number_of_cores = $amdenergy->{number_of_cores}->{$dstr};
			$sum_of_values += $number_of_cores + $number_of_additional_values_in_use;
			for(my $i_core = 0; $i_core < $number_of_cores; $i_core++) {
				my $value_name = "cpu" . $n_cpu . "_val" . $i_core;
				push(@def_sensor_average, "DEF:" . $value_name . "=$rrd:en" . $e . "_" . $value_name . ":AVERAGE");
				if($n_cpu != 0 || $i_core != 0) {
					$cdef_sensor_allvalues .= ",";
				}
				$cdef_sensor_allvalues .= $value_name . ($gap_on_all_nan ? ",UN,0,1,IF" : "");
			}
			for(my $i_add = 0; $i_add < $number_of_additional_values_in_use; $i_add++) {
				my $value_name = "cpu" . $n_cpu . "_" . $i_add . "add";
				push(@def_sensor_average, "DEF:" . $value_name . "=$rrd:en" . $e . "_" . $value_name . ":AVERAGE");
				$cdef_sensor_allvalues .= ",";
				$cdef_sensor_allvalues .= $value_name . ($gap_on_all_nan ? ",UN,0,1,IF" : "");
			}
		}
		$cdef_sensor_allvalues .= ",+" x ($sum_of_values-1);
		if ($gap_on_all_nan) {
			$cdef_sensor_allvalues .= ",0,GT,1,UNKN,IF";
		}
		my $y_axis_title = "Watt";
		my $large_plot = 1;
		my $plot_title = $config->{graphs}->{'_amdenergy1'};
		if(defined($amdenergy->{desc}) && defined($amdenergy->{desc}->{$k})) {
			$plot_title = $amdenergy->{desc}->{$k};
		}
		$pic = $rrd{$version}->("$IMG_DIR" . $IMG[$e * $plots_per_list_item + $n_plot],
			"--title=$plot_title ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=" . $y_axis_title,
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			$large_plot ? () : @{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			@def_sensor_average,
			$cdef_sensor_allvalues,
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . $IMG[$e * $plots_per_list_item + $n_plot] . ": $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . $IMGz[$e * $plots_per_list_item + $n_plot],
				"--title=$plot_title  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=" . $y_axis_title,
				"--width=$width",
				"--height=$height",
				@full_size_mode,
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				$large_plot ? () : @{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				@def_sensor_average,
				$cdef_sensor_allvalues,
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . $IMGz[$e * $plots_per_list_item + $n_plot] . ": $err\n") if $err;
		}
		$e2 = $e + $n_plot + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /amdenergy$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * $plots_per_list_item + $n_plot], IMG => $IMG[$e * $plots_per_list_item + $n_plot]) . "\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      " . picz_js_a_element(width => $picz_width, height => $picz_height, config => $config, IMGz => $IMGz[$e * $plots_per_list_item + $n_plot], IMG => $IMG[$e * $plots_per_list_item + $n_plot]) . "\n");
				}
			} else {
				 push(@output, "      " . img_element(config => $config, IMG => $IMG[$e * $plots_per_list_item + $n_plot]) . "\n");
			}
		}
		$e++;
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
