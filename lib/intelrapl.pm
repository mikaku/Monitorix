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

package intelrapl;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Time::HiRes;
use Cwd 'abs_path';
use File::Basename;
use Exporter 'import';
our @EXPORT = qw(intelrapl_init intelrapl_update intelrapl_cgi);

my $epoc_identifier = "last_epoc";
my $val_identifier = "last_val";
my $list_delimiter = ",";

sub get_max_number_of_values_per_group {
	my ($intelrapl) = @_;
	my $default_max_number_of_values_per_group = 10; # Can be overwritten via config file but changes will break history.
	if(defined($intelrapl->{max_number_of_values_per_group})) {
		return $intelrapl->{max_number_of_values_per_group};
	}
	return $default_max_number_of_values_per_group;
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
	my ($n) = @_;
	my @LC = (
		"#44EEEE",
		"#EE44EE",
		"#44EE44",
		"#4444EE",
		"#ff9100",
		"#a600ff",
		"#EEEE00",
		"#448844",
		"#EE4444",
		"#EE44EE",
	);
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
	my ($myself, $config, $intelrapl) = @_;
	my $use_nan_for_missing_data = lc($intelrapl->{use_nan_for_missing_data} || "") eq "y" ? 1 : 0;

	my @sensors_all;
	my $rrdata = "N";

	my $max_number_of_values_per_group = get_max_number_of_values_per_group($intelrapl);

	foreach my $k (sort keys %{$intelrapl->{list}}) {
		my $package_sensor;
		if(defined($intelrapl->{package_sensors}) && defined($intelrapl->{package_sensors}->{$k})) {
			$package_sensor = trim($intelrapl->{package_sensors}->{$k});
		}
		my $package_index;
		my @sensor_group = split($list_delimiter, $intelrapl->{list}->{$k});
		my @sensors = ($use_nan_for_missing_data ? (0+"nan") : 0) x $max_number_of_values_per_group;
		for(my $n = 0; $n < min(scalar(@sensor_group), $max_number_of_values_per_group); $n++) {
			my $str = trim($sensor_group[$n] || "");
			my $sensor_path = trim($intelrapl->{sensors}->{$str} || "");
			chomp($sensor_path);

			my $last_epoc = ($config->{intelrapl_hist}->{$k}->{$n}->{$epoc_identifier} || 0);
			my $epoc = Time::HiRes::time();
			$config->{intelrapl_hist}->{$k}->{$n}->{$epoc_identifier} = $epoc;

			if ($sensor_path ne "") {
				my $sensor_file = $sensor_path;
				if(open(IN, $sensor_file)) {
					my $val = <IN>;
					close(IN);
					$val = trim($val);
					chomp($val);

					my $last_sensor_val = ($config->{intelrapl_hist}->{$k}->{$n}->{$val_identifier} || 0);
					my $sensor_val = $val;
					$config->{intelrapl_hist}->{$k}->{$n}->{$val_identifier} = $sensor_val;
					if ($last_epoc ne 0 && $sensor_val >= $last_sensor_val) {
						$sensors[$n] = ($sensor_val - $last_sensor_val) / ($epoc - $last_epoc); # Conversion from muJoule to muWatt during the time interval.
						if (defined($package_sensor) && $str eq $package_sensor) {
							$package_index = $n;
						}
					}
				} else {
					logger("$myself: ERROR: unable to open '$sensor_file'.");
				}
			}
		}
		push(@sensors_all, @sensors);
		# intelrapl alert
		if(defined($intelrapl->{alerts}) && lc($intelrapl->{alerts}->{packagepower_enabled}) eq "y") {
			my $sensor_index = $package_index;
			if (defined($sensor_index)) {
				$config->{intelrapl_hist_alert1}->{$k} = 0 if(!$config->{intelrapl_hist_alert1}->{$k});
				if($sensors[$sensor_index] >= $intelrapl->{alerts}->{packagepower_threshold} && $config->{intelrapl_hist_alert1}->{$k} < $sensors[$sensor_index]) {
					if(-x $intelrapl->{alerts}->{packagepower_script}) {
						logger("$myself: ALERT: executing script '$intelrapl->{alerts}->{packagepower_script}'.");
						system($intelrapl->{alerts}->{packagepower_script} . " " .$intelrapl->{alerts}->{packagepower_timeintvl} . " " . $intelrapl->{alerts}->{packagepower_threshold} . " " . $sensors[$sensor_index]);
					} else {
						logger("$myself: ERROR: script '$intelrapl->{alerts}->{packagepower_script}' doesn't exist or don't has execution permissions.");
					}
					$config->{intelrapl_hist_alert1}->{$k} = $sensors[$sensor_index];
				}
			} else {
				logger("$myself: ERROR: could not find $package_sensor in sensors. Alarms will not work!");
			}
		}
	}

	foreach(@sensors_all) {
		$rrdata .= ":$_";
	}

	return $rrdata;
}

sub intelrapl_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $intelrapl = $config->{intelrapl};

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	my $max_number_of_values_per_group = get_max_number_of_values_per_group($intelrapl);

	foreach my $k (sort keys %{$intelrapl->{list}}) {
		my @sensor_group = split($list_delimiter, $intelrapl->{list}->{$k});
		for(my $n = 0; $n < min(scalar(@sensor_group), $max_number_of_values_per_group); $n++) {
			my $str = trim($sensor_group[$n] || "");
			my $sensor_path = trim($intelrapl->{sensors}->{$str} || "");
			chomp($sensor_path);
			if ($sensor_path ne "") {
				my $sensor_file = $sensor_path;
				unless(-e $sensor_file) {
					logger("$myself: ERROR: invalid or inexistent device name '$sensor_file'.");
					if(lc($intelrapl->{accept_invalid} || "") ne "y") {
						logger("$myself: 'accept_invalid' option is not set.");
						logger("$myself: WARNING: initialization aborted.");
						return;
					}
				}
			}
		}
	}

	if(-e $rrd) {
		my $rrd_n_groups = 0;
		my $rrd_n_groups_times_n_values = 0;
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'ds[') == 0) {
				if(index($key, '.type') != -1) {
					push(@ds, substr($key, 3, index($key, ']') - 3));
				}
				if(index($key, '_val0].index') != -1) {
					$rrd_n_groups += 1;
				}
				if(index($key, '.index') != -1) {
					$rrd_n_groups_times_n_values += 1;
				}
			}
			if(index($key, 'rra[') == 0) {
				if(index($key, '.rows') != -1) {
					push(@rra, substr($key, 4, index($key, ']') - 4));
				}
			}
		}

		my $total_number_of_groups = 0;
		foreach my $k (sort keys %{$intelrapl->{list}}) {
			my @sensor_group = split($list_delimiter, $intelrapl->{list}->{$k});
			$total_number_of_groups += scalar(@sensor_group);
		}

		if(scalar(@ds) / ($rrd_n_groups_times_n_values / $rrd_n_groups) != keys(%{$intelrapl->{list}})) {
			logger("$myself: Detected size mismatch between <list>...</list> (" . keys(%{$intelrapl->{list}}) . ") and $rrd (" . scalar(@ds) / ($rrd_n_groups_times_n_values / $rrd_n_groups) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if($rrd_n_groups_times_n_values / $rrd_n_groups < $max_number_of_values_per_group) {
			logger("$myself: Detected size mismatch between max_number_of_values_per_group (" . $max_number_of_values_per_group . ") and $rrd (" . ($rrd_n_groups_times_n_values / $rrd_n_groups) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for(my $k = 0; $k < keys(%{$intelrapl->{list}}); $k++) {
			for($n = 0; $n < $max_number_of_values_per_group; $n++) {
				push(@tmp, "DS:rapl" . $k . "_val" . $n . ":GAUGE:120:0:U");
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
	if(defined($intelrapl->{alerts}) && lc($intelrapl->{alerts}->{packagepower_enabled} || "") eq "y") {
		if(! -x $intelrapl->{alerts}->{packagepower_script}) {
			logger("$myself: ERROR: script '$intelrapl->{alerts}->{packagepower_script}' doesn't exist or don't has execution permissions.");
		}
	}

	$config->{intelrapl_hist_alert1} = ();
	$config->{intelrapl_hist} = ();
	push(@{$config->{func_update}}, $package);

	measure($myself, $config, $intelrapl);

	logger("$myself: Ok") if $debug;
}

sub intelrapl_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $intelrapl = $config->{intelrapl};

	my $rrdata = measure($myself, $config, $intelrapl);

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub round {
	my ($float) = @_;
	return int($float + $float/abs($float*2 || 1));
}

sub intelrapl_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $intelrapl = $config->{intelrapl};
	my @rigid = split(',', ($intelrapl->{rigid} || ""));
	my @limit = split(',', ($intelrapl->{limit} || ""));
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};
	my $zoom = $config->{global_zoom};
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
	my $gap_on_all_nan = lc($intelrapl->{gap_on_all_nan} || "") eq "y" ? 1 : 0;

	my $max_number_of_values_per_group = get_max_number_of_values_per_group($intelrapl);

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
		foreach my $k (sort keys %{$intelrapl->{list}}) {
			my @sensor_group = split($list_delimiter, $intelrapl->{list}->{$k});
			for($n = 0; $n < min(scalar(@sensor_group), $max_number_of_values_per_group); $n++) {
				$str = sprintf(" RAPL power %d               ", $n + 1);
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
			foreach my $k (sort keys %{$intelrapl->{list}}) {
			  my @sensor_group = split($list_delimiter, $intelrapl->{list}->{$k});

				for($n2 = 0; $n2 < min(scalar(@sensor_group), $max_number_of_values_per_group); $n2++) {
					my $str = trim($sensor_group[$n] || "");
					$from = ($e * scalar(@sensor_group) + $n2);
					$to = $from + 3;
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
		$zoom = 1;	# force 'global_zoom' to 1 in Multihost viewer
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "_";
	}
	if($silent eq "imagetagbig") {
		$zoom = 1;	# force 'global_zoom' to 1 in Multihost viewer
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "";
	}
	my $global_zoom = "--zoom=" . $zoom;

	my $plots_per_list_item = 1;
	for($n = 0; $n < keys(%{$intelrapl->{list}}); $n++) {
		my @sensor_group = split($list_delimiter, $intelrapl->{list}->{$n});
		for($n2 = 0; $n2 < $plots_per_list_item; $n2++) {
			$str = $u . $package . $n . $n2 . "." . $tf->{when} . ".$imgfmt_lc";
			push(@IMG, $str);
			unlink("$IMG_DIR" . $str);
			if(lc($config->{enable_zoom}) eq "y") {
				$str = $u . $package . $n . $n2 . "z." . $tf->{when} . ".$imgfmt_lc";
				push(@IMGz, $str);
				unlink("$IMG_DIR" . $str);
			}
		}
	}


	$e = 0;
	foreach my $k (sort keys %{$intelrapl->{list}}) {
		my @sensor_group = split($list_delimiter, $intelrapl->{list}->{$k});
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

		my $dstr = $k;
		if(defined($intelrapl->{list_item_names}->{$k})) {
			$dstr = $intelrapl->{list_item_names}->{$k};
		}
		my $core_string = $dstr;
		$str = $dstr;

		my $legend_label_format = "%7.2lf";
		my $value_transformation = ",1e-6,*"; # muWatt to Watts

		my $legend_size = 16;
		my $cpu_label_size = 50;
		my $cpu_label = sprintf("%-" . $cpu_label_size . "s", $str);
		my $cpu_label_empty = sprintf("%-" . $cpu_label_size . "s", "");

		my $sum_name = "sum";
		my $cdef_sum = "CDEF:" . $sum_name . "=";

		my @sum_group = ();
		if(defined($intelrapl->{sum}) && defined($intelrapl->{sum}->{$k})) {
			@sum_group = split($list_delimiter, $intelrapl->{sum}->{$k});
		}

		my $package_sensor = "package";
		my $package_index;
		if(defined($intelrapl->{package_sensors}) && defined($intelrapl->{package_sensors}->{$k})) {
			$package_sensor = trim($intelrapl->{package_sensors}->{$k});
		}
		my $noncore_name = "noncore";
		my $cdef_noncore = "CDEF:" . $noncore_name . "=";
		my @package_content_group = ();
		if(defined($intelrapl->{package_content}) && defined($intelrapl->{package_content}->{$k})) {
			@package_content_group = split($list_delimiter, $intelrapl->{package_content}->{$k});
		}

		my $sum_counter = 0;
		my $package_content_counter = 0;
		for($n = 0; $n < min(scalar(@sensor_group), $max_number_of_values_per_group); $n += 1) {
			my $value_name = "val" . $n;
			my $sensor_name = trim($sensor_group[$n]);
			my $value_label = $sensor_name;
			if(defined($intelrapl->{sensor_names}->{$value_label})) {
				$value_label = $intelrapl->{sensor_names}->{$value_label};
			}
			$value_label = sprintf("%-".$legend_size."s", $value_label);

			push(@CDEF, "CDEF:trans_" . $value_name . "=" . $value_name . $value_transformation);

			if(scalar(@sum_group) != 0) {
				if(grep {$_ eq $sensor_name} @sum_group) {
					if ($sum_counter != 0) {
						$cdef_sum .= ",";
					}
					$cdef_sum .= $value_name;
					$sum_counter += 1;
				}
			}

			if(scalar(@package_content_group) != 0) {
				if(grep {$_ eq $sensor_name} @package_content_group) {
					if ($package_content_counter != 0) {
						$cdef_noncore .= ",";
					}
					$cdef_noncore .= $value_name;
					$package_content_counter += 1;
				}
			}

			if ($package_sensor eq $sensor_name) {
				$package_index = $n;
			}

			my $legend_label = $value_label;

			if (defined($package_index) && scalar(@package_content_group) != 0 && $sensor_name eq $package_sensor) {
				my $noncore_label_full = "Non-Core";
				if(defined($intelrapl->{noncore_names}) && defined($intelrapl->{noncore_names}->{$k})) {
					$noncore_label_full = trim($intelrapl->{noncore_names}->{$k});
				}

				my $noncore_label = sprintf("%-".$legend_size."s", $noncore_label_full);
				my $noncore_color = line_color(scalar(@sensor_group));

				my $package_sensor_name = $package_sensor;
				if(defined($intelrapl->{sensor_names}->{$package_sensor})) {
					$package_sensor_name = $intelrapl->{sensor_names}->{$package_sensor};
				}

				my $package_info = "(".$noncore_label_full . " = " . $package_sensor_name;
				for(my $i = 0; $i < scalar(@package_content_group); $i += 1) {
					my $package_item = trim($package_content_group[$i]);
					my $package_item_name = $package_item;
					if(defined($intelrapl->{sensor_names}->{$package_item})) {
						$package_item_name = $intelrapl->{sensor_names}->{$package_item};
					}
					$package_info .= " - ";
					$package_info .= $package_item_name;
				}
				$package_info .= ")";
				$package_info = sprintf("%-" . ($cpu_label_size) . "s" , substr($package_info, 0, ($cpu_label_size)));
				if(defined($intelrapl->{show_noncore_info}) && lc(trim($intelrapl->{show_noncore_info})) eq "y") {
					push(@tmp, "COMMENT:" . $package_info);
				} else {
					push(@tmp, "COMMENT:" . $cpu_label_empty);
				}


				push(@tmp, "LINE1:trans_" . $noncore_name . $noncore_color . ":" . $noncore_label);
				push(@tmpz, "LINE1:trans_" . $noncore_name . $noncore_color . ":" . $noncore_label);

				push(@tmp, "GPRINT:trans_" . $noncore_name . ":LAST:Current\\:" . $legend_label_format);
				push(@tmp, "GPRINT:trans_" . $noncore_name . ":AVERAGE:Average\\:" . $legend_label_format);
				push(@tmp, "GPRINT:trans_" . $noncore_name . ":MIN:Min\\:" . $legend_label_format);
				push(@tmp, "GPRINT:trans_" . $noncore_name . ":MAX:Max\\:" . $legend_label_format . "\\n");
			}

			if ($n == 0) {
				push(@tmp, "COMMENT:" . $cpu_label);
			} else {
				push(@tmp, "COMMENT:" . $cpu_label_empty);
			}

			my $hex_color_n = line_color($n);
			if ($sensor_name eq "core") {
				my $hex_transparency = "E6";
				push(@tmp, "AREA:trans_" . $value_name . $hex_color_n .$hex_transparency. ":" . $legend_label);
				push(@tmpz, "AREA:trans_" . $value_name . $hex_color_n .$hex_transparency. ":" . $legend_label);
			} else {
				push(@tmp, "LINE1:trans_" . $value_name . $hex_color_n . ":" . $legend_label);
				push(@tmpz, "LINE1:trans_" . $value_name . $hex_color_n . ":" . $legend_label);
			}

			push(@tmp, "GPRINT:trans_" . $value_name . ":LAST:Current\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $value_name . ":AVERAGE:Average\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $value_name . ":MIN:Min\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $value_name . ":MAX:Max\\:" . $legend_label_format . "\\n");
		}

		if ($sum_counter != 0) {
			$cdef_sum .= ",+" x ($sum_counter-1);
			push(@CDEF, $cdef_sum);
			push(@CDEF, "CDEF:trans_" . $sum_name . "=" . $sum_name . $value_transformation);
			my $sum_label = "Sum";
			if(defined($intelrapl->{sum_names}->{$k})) {
				$sum_label = $intelrapl->{sum_names}->{$k};
			}

			$sum_label = sprintf("%-".$legend_size."s", $sum_label);
			my $socket_color = line_color(scalar(@sensor_group)+1);
			push(@tmp, "COMMENT:". $cpu_label_empty);

			push(@tmp, "LINE1:trans_" . $sum_name . $socket_color . ":" . $sum_label);
			push(@tmpz, "LINE1:trans_" . $sum_name . $socket_color . ":" . $sum_label);

			push(@tmp, "GPRINT:trans_" . $sum_name . ":LAST:Current\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $sum_name . ":AVERAGE:Average\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $sum_name . ":MIN:Min\\:" . $legend_label_format);
			push(@tmp, "GPRINT:trans_" . $sum_name . ":MAX:Max\\:" . $legend_label_format . "\\n");
		}

		if (defined($package_index) && $package_content_counter != 0) {
			$cdef_noncore .=  ",+" x ($package_content_counter-1);
			$cdef_noncore .=  ",val" . $package_index . ",-,-1,*";
			push(@CDEF, $cdef_noncore);
			push(@CDEF, "CDEF:trans_" . $noncore_name . "=" . $noncore_name . $value_transformation);
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
		my $sum_of_cores = 0;
		for(my $n_group = 0; $n_group < min(scalar(@sensor_group), $max_number_of_values_per_group); $n_group++) {
			my $dstr = trim($sensor_group[$n_group]);
			$sum_of_cores += 1;
			my $value_name = "val" . $n_group;
			push(@def_sensor_average, "DEF:" . $value_name . "=$rrd:rapl" . $e . "_" . $value_name . ":AVERAGE");
			if($n_group != 0) {
				$cdef_sensor_allvalues .= ",";
			}
			if ($gap_on_all_nan) {
				$cdef_sensor_allvalues .= $value_name . ",UN,0,1,IF";
			} else {
				$cdef_sensor_allvalues .= $value_name;
			}
		}
		$cdef_sensor_allvalues .= ",+" x ($sum_of_cores-1);
		if ($gap_on_all_nan) {
			$cdef_sensor_allvalues .= ",0,GT,1,UNKN,IF";
		}
		my $y_axis_title = "Watt";
		my $large_plot = 1;
		my $plot_title = $config->{graphs}->{'_intelrapl1'};
		if(defined($intelrapl->{desc}) && defined($intelrapl->{desc}->{$k})) {
			$plot_title = $intelrapl->{desc}->{$k};
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
			$global_zoom,
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
				$global_zoom,
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
		if($title || ($silent =~ /imagetag/ && $graph =~ /intelrapl$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * $plots_per_list_item + $n_plot] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * $plots_per_list_item + $n_plot] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $zoom;
						$picz_height = $picz->{image_height} * $zoom;
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
