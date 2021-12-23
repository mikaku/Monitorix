#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2021 by Jordi Sanfeliu <jordi@fibranet.cat>
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

package nvidiagpu;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Cwd 'abs_path';
use File::Basename;
use Exporter 'import';
our @EXPORT = qw(nvidiagpu_init nvidiagpu_update nvidiagpu_cgi);

my $max_number_of_gpus = 8; # Changing this number destroys history.
my $number_of_values_per_gpu_in_rrd = 14; # Changing this number destroys history.

sub nvidiagpu_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nvidiagpu = $config->{nvidiagpu};

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	# checks if 'nvidia-smi' does exists.
	if(!open(IN, "nvidia-smi |")) {
		logger("$myself: unable to execute 'nvidia-smi'. $!");
		return;
	}
	close(IN);

	if(-e $rrd) {
		my $rrd_n_gpu = 0;
		my $rrd_n_gpu_times_n_values = 0;
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'ds[') == 0) {
				if(index($key, '.type') != -1) {
					push(@ds, substr($key, 3, index($key, ']') - 3));
				}
				if(index($key, '_val0].index') != -1) {
					$rrd_n_gpu += 1;
				}
				if(index($key, '.index') != -1) {
					$rrd_n_gpu_times_n_values += 1;
				}
			}
			if(index($key, 'rra[') == 0) {
				if(index($key, '.rows') != -1) {
					push(@rra, substr($key, 4, index($key, ']') - 4));
				}
			}
		}
		if(scalar(@ds) / $rrd_n_gpu_times_n_values != keys(%{$nvidiagpu->{list}})) {
			logger("$myself: Detected size mismatch between <list>...</list> (" . keys(%{$nvidiagpu->{list}}) . ") and $rrd (" . scalar(@ds) / $rrd_n_gpu_times_n_values . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if($rrd_n_gpu < $max_number_of_gpus) {
			logger("$myself: Detected size mismatch between max_number_of_gpus (" . $max_number_of_gpus . ") and $rrd (" . $rrd_n_gpu . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if($rrd_n_gpu_times_n_values / $rrd_n_gpu < $number_of_values_per_gpu_in_rrd) {
			logger("$myself: Detected size mismatch between number_of_values_per_gpu_in_rrd (" . $number_of_values_per_gpu_in_rrd . ") and $rrd (" . ($rrd_n_gpu_times_n_values / $rrd_n_gpu) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < keys(%{$nvidiagpu->{list}}); $n++) {
			for(my $n_gpu = 0; $n_gpu < $max_number_of_gpus; $n_gpu++) {
				for(my $n_sensor = 0; $n_sensor < $number_of_values_per_gpu_in_rrd; $n_sensor++) {
					push(@tmp, "DS:nv" . $n . "_gpu" . $n_gpu . "_val" . $n_sensor . ":GAUGE:120:0:U");
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
	if(lc($nvidiagpu->{alerts}->{coretemp_enabled} || "") eq "y") {
		if(! -x $nvidiagpu->{alerts}->{coretemp_script}) {
			logger("$myself: ERROR: script '$nvidiagpu->{alerts}->{coretemp_script}' doesn't exist or don't has execution permissions.");
		}
	}
	if(lc($nvidiagpu->{alerts}->{memorytemp_enabled} || "") eq "y") {
		if(! -x $nvidiagpu->{alerts}->{memorytemp_script}) {
			logger("$myself: ERROR: script '$nvidiagpu->{alerts}->{memorytemp_script}' doesn't exist or don't has execution permissions.");
		}
	}

	$config->{nvidiagpu_hist_alert1} = ();
	$config->{nvidiagpu_hist_alert2} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub nvidiagpu_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nvidiagpu = $config->{nvidiagpu};
	my $use_nan_for_missing_data = lc($nvidiagpu->{use_nan_for_missing_data} || "") eq "y" ? 1 : 0;

	my @sensors;

	my $n;
	my $rrdata = "N";

	foreach my $k (sort keys %{$nvidiagpu->{list}}) {
		# values delimitted by ", " (comma + space)
		my @gpu_group = split(', ', $nvidiagpu->{list}->{$k});
		for($n = 0; $n < $max_number_of_gpus; $n++) {
			@sensors = ($use_nan_for_missing_data ? (0+"nan") : 0) x $number_of_values_per_gpu_in_rrd;

			if($n < scalar(@gpu_group)) {
				my $str = trim($gpu_group[$n]);

        open(IN, "nvidia-smi --format=csv,noheader,nounits -i $str --query-gpu=clocks.current.graphics,clocks.current.memory,utilization.gpu,utilization.memory,temperature.gpu,temperature.memory,fan.speed,pstate,power.draw,power.limit,memory.used,memory.total |");
				while(<IN>) {
					my @tmp = split(',', $_);
					if(scalar(@tmp) > 1) { # To catch missing devices
						for(my $n_sensor = 0; $n_sensor < scalar(@tmp); $n_sensor += 1) {
							my $val = trim($tmp[$n_sensor]);
							if($val ne "N/A") {
								if(substr($val, 0, 1) eq "P") {
									$val = substr($val, 1);
								}
								$val =~ tr/,//d;
								$sensors[$n_sensor] = trim($val);
								chomp($sensors[$n_sensor]);
							}
						}
						$sensors[10] = $sensors[10] / $sensors[11]
					}
				}
				close(IN);
			}

			foreach(@sensors) {
				$rrdata .= ":$_";
			}

			# nvidiagpu alert
			if(lc($nvidiagpu->{alerts}->{coretemp_enabled}) eq "y") {
				my $sensorIndex = 1;
				$config->{nvidiagpu_hist_alert1}->{$n} = 0 if(!$config->{nvidiagpu_hist_alert1}->{$n});
				if($sensors[$sensorIndex] >= $nvidiagpu->{alerts}->{coretemp_threshold} && $config->{nvidiagpu_hist_alert1}->{$n} < $sensors[$sensorIndex]) {
					if(-x $nvidiagpu->{alerts}->{coretemp_script}) {
						logger("$myself: ALERT: executing script '$nvidiagpu->{alerts}->{coretemp_script}'.");
						system($nvidiagpu->{alerts}->{coretemp_script} . " " .$nvidiagpu->{alerts}->{coretemp_timeintvl} . " " . $nvidiagpu->{alerts}->{coretemp_threshold} . " " . $sensors[$sensorIndex]);
					} else {
						logger("$myself: ERROR: script '$nvidiagpu->{alerts}->{coretemp_script}' doesn't exist or don't has execution permissions.");
					}
					$config->{nvidiagpu_hist_alert1}->{$n} = $sensors[$sensorIndex];
				}
			}
			if(lc($nvidiagpu->{alerts}->{memorytemp_enabled}) eq "y") {
				my $sensorIndex = 2;
				$config->{nvidiagpu_hist_alert2}->{$n} = 0 if(!$config->{nvidiagpu_hist_alert2}->{$n});
				if($sensors[$sensorIndex] >= $nvidiagpu->{alerts}->{memorytemp_threshold} && $config->{nvidiagpu_hist_alert2}->{$n} < $sensors[$sensorIndex]) {
					if(-x $nvidiagpu->{alerts}->{memorytemp_script}) {
						logger("$myself: ALERT: executing script '$nvidiagpu->{alerts}->{memorytemp_script}'.");
						system($nvidiagpu->{alerts}->{memorytemp_script} . " " .$nvidiagpu->{alerts}->{memorytemp_timeintvl} . " " . $nvidiagpu->{alerts}->{memorytemp_threshold} . " " . $sensors[$sensorIndex]);
					} else {
						logger("$myself: ERROR: script '$nvidiagpu->{alerts}->{memorytemp_script}' doesn't exist or don't has execution permissions.");
					}
					$config->{nvidiagpu_hist_alert2}->{$n} = $sensors[$sensorIndex];
				}
			}
		}
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub nvidiagpu_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $nvidiagpu = $config->{nvidiagpu};
	my @rigid = split(',', ($nvidiagpu->{rigid} || ""));
	my @limit = split(',', ($nvidiagpu->{limit} || ""));
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
	my $n;
	my $n2;
	my $e;
	my $e2;
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
	);

	my $number_of_sensor_values_in_use = 11;
	if($number_of_sensor_values_in_use > $number_of_values_per_gpu_in_rrd) {
		logger(@output, "ERROR: Number of sensor values (" . $number_of_sensor_values_in_use . ") has smaller or equal to number of sensor values in rrd (" . $number_of_values_per_gpu_in_rrd . ")!");
		return;
	}
	my $show_current_values = lc($nvidiagpu->{show_current_values} || "") eq "y" ? 1 : 0;

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
	my $gap_on_all_nan = lc($nvidiagpu->{gap_on_all_nan} || "") eq "y" ? 1 : 0;

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
		foreach my $k (sort keys %{$nvidiagpu->{list}}) {
			# values delimitted by ", " (comma + space)
			my @d = split(', ', $nvidiagpu->{list}->{$k});
			for($n = 0; $n < scalar(@d); $n++) {
				$str = sprintf(" NVIDIAgpu %d               ", $n + 1);
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
			foreach my $k (sort keys %{$nvidiagpu->{list}}) {
				# values delimitted by ", " (comma + space)
				my @d = split(', ', $nvidiagpu->{list}->{$k});
				for($n2 = 0; $n2 < scalar(@d); $n2++) {
					$from = ($e * $max_number_of_gpus * $number_of_values_per_gpu_in_rrd) + ($n2 * $number_of_values_per_gpu_in_rrd);
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
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "_";
	}
	if($silent eq "imagetagbig") {
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "";
	}

	for($n = 0; $n < keys(%{$nvidiagpu->{list}}); $n++) {
		for($n2 = 0; $n2 < $number_of_sensor_values_in_use; $n2++) {
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

	# Plot settings in order of the sensor array.

	my $temperature_unit = lc($config->{temperature_scale}) eq "f" ? "Fahrenheit" : "Celsius";
	my $temperature_scaling = lc($config->{temperature_scale}) eq "f" ? ",9,*,5,/,32,+" : "";

	my @y_axis_titles_per_plot = (
		"Percent (%)",
		$temperature_unit,
		$temperature_unit,
		"Percent (%)",,
		"Watt",
		"Percent (%)",
		"Percent (%)",
		"Hz",
		"Hz",
		"P"
	);
	my @value_transformations_per_sensor = (
		",1000000,*",
		",1000000,*",
		"",
		"",
		$temperature_scaling,
		$temperature_scaling,
		"",
		"",
		"",
		"",
		",100,*"
	);
	my @legend_labels_per_sensor = (
		"%4.2lf%s",
		"%4.2lf%s",
		"%3.0lf%%",
		"%3.0lf%%",
		"%3.1lf",
		"%3.1lf",
		"%3.1lf%%",
		"%1.0lf",
		"%5.0lf%s",
		"%5.0lf%s",
		"%3.1lf%%"
	);

	my @graphs_per_plot = (6, 4, 5, 10, [8, 9], 2, 3, 0, 1, 7); # To rearange the graphs
	my $main_sensor_plots = 4; # Number of sensor plots on the left side.
	my @main_plots_with_average = (1, 1, 1, 1); # Wether or not the main plots show average, min and max or only the last value in the legend.

	my $number_of_plots = scalar(@graphs_per_plot);

	if(scalar(@y_axis_titles_per_plot) != $number_of_plots) {
		push(@output, "ERROR: Size of y_axis_titles_per_plot (" . scalar(@y_axis_titles_per_plot) . ") has to be equal to number_of_plots (" . $number_of_plots . ")");
	}
	if(scalar(@value_transformations_per_sensor) != $number_of_sensor_values_in_use) {
		push(@output, "ERROR: Size of value_transformations_per_sensor (" . scalar(@value_transformations_per_sensor) . ") has to be equal to number_of_sensor_values_in_use (" . $number_of_sensor_values_in_use . ")");
	}
	if(scalar(@legend_labels_per_sensor) != $number_of_sensor_values_in_use) {
		push(@output, "ERROR: Size of legend_labels_per_sensor (" . scalar(@legend_labels_per_sensor) . ") has to be equal to number_of_sensor_values_in_use (" . $number_of_sensor_values_in_use . ")");
	}
	if(scalar(@graphs_per_plot) >= $number_of_sensor_values_in_use) {
		push(@output, "ERROR: Size of graphs_per_plot (" . scalar(@graphs_per_plot) . ") has to be smaller than number_of_sensor_values_in_use (" . $number_of_sensor_values_in_use . ")");
	}
	if(scalar(@main_plots_with_average) != $main_sensor_plots) {
		push(@output, "ERROR: Size of main_plots_with_average (" . scalar(@main_plots_with_average) . ") has to be equal to main_sensor_plots (" . $main_sensor_plots . ")");
	}

	$e = 0;
	foreach my $k (sort keys %{$nvidiagpu->{list}}) {
		# values delimitted by ", " (comma + space)
		my @d = split(', ', $nvidiagpu->{list}->{$k});
		if($e) {
			push(@output, "   <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		for(my $n_graph = 0, my $n_plot = 0; $n_graph < $number_of_sensor_values_in_use; $n_graph += 1, $n_plot += 1) {
			if($title && $n_plot == $main_sensor_plots) {
				push(@output, "    </td>\n");
				push(@output, "    <td class='td-valign-top'>\n");
			}

			if($n_graph > scalar(@graphs_per_plot)) {
				push(@output, "ERROR: n_graph (" . $n_graph . ") has to smaller than size of graphs_per_plot (" . scalar(@graphs_per_plot) . ")");
			}
			my $n_sensor;
			my $n_sensor2;
			if (ref($graphs_per_plot[$n_graph]) eq 'ARRAY') {
				$n_sensor = $graphs_per_plot[$n_plot]->[0];
				$n_sensor2 = $graphs_per_plot[$n_plot]->[1];
				$n_graph += 1
			} else {
				$n_sensor = $graphs_per_plot[$n_plot];
			}

			@riglim = @{setup_riglim($rigid[$n_plot], $limit[$n_plot])};
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			if($n_plot < $main_sensor_plots) {
				push(@tmp, "COMMENT: \\n");
			}
			for($n = 0; $n < $max_number_of_gpus; $n += 1) {
				if($n < scalar(@d)) {
					my $dstr = trim($d[$n]);
					my $base = "";
					$dstr =~ s/^\"//;
					$dstr =~ s/\"$//;

					# $dstr =~ s/^(.+?) .*$/$1/;
					if($base && defined($nvidiagpu->{map}->{$base})) {
						$dstr = $nvidiagpu->{map}->{$base};
					} else {
						if(defined($nvidiagpu->{map}->{$dstr})) {
							$dstr = $nvidiagpu->{map}->{$dstr};
						}
					}
					if($n_plot < $main_sensor_plots) {
						if($main_plots_with_average[$n_plot]) {
							$str = sprintf("%-20s", $dstr);
						} else {
							$str = sprintf("%-57s", $dstr);
						}
					} else {
						if($show_current_values) {
							$str = sprintf("%-13s", substr($dstr, 0, 13));
						} else {
							$str = sprintf("%-19s", substr($dstr, 0, 19));
						}
					}

					my $value_name = "gpu" . $n . "_val" . $n_sensor;
					my $value_name2;
					push(@tmp, "LINE2:trans_" . $value_name . $LC[$n] . ":$str" . ($n_plot < $main_sensor_plots ? "" : ( $show_current_values ? "\\: \\g" : (($n%2 || ($n+1 == scalar(@d))) ? "\\n" : ""))));
					push(@tmpz, "LINE2:trans_" . $value_name . $LC[$n] . ":$dstr");

					if ($n_sensor2) {
						$value_name2 = "gpu" . $n . "_val" . $n_sensor2;
						push(@tmp, "LINE2:trans_" . $value_name2 . $LC[$n] . "BB" . ":dashes=1,3:");
						push(@tmpz, "LINE2:trans_" . $value_name2 . $LC[$n] . "BB" . ":dashes=1,3:");
					}

					if($n_plot < $main_sensor_plots) {
						if($main_plots_with_average[$n_plot]) {
							push(@tmp, "GPRINT:trans_" . $value_name . ":LAST:  Current\\: " . $legend_labels_per_sensor[$n_sensor]);
							push(@tmp, "GPRINT:trans_" . $value_name . ":AVERAGE:  Average\\: " . $legend_labels_per_sensor[$n_sensor]);
							push(@tmp, "GPRINT:trans_" . $value_name . ":MIN:  Min\\: " . $legend_labels_per_sensor[$n_sensor]);
							push(@tmp, "GPRINT:trans_" . $value_name . ":MAX:  Max\\: " . $legend_labels_per_sensor[$n_sensor] . "\\n");
						} else {
							push(@tmp, "GPRINT:trans_" . $value_name . ":LAST: Current\\: " . $legend_labels_per_sensor[$n_sensor] . "\\n");
						}
					} else {
						if($show_current_values) {
						  if($n_sensor2 && $value_name2) {
								push(@tmp, "GPRINT:trans_" . $value_name . ":LAST:" . $legend_labels_per_sensor[$n_sensor] . "\\g");
								push(@tmp, "GPRINT:trans_" . $value_name2 . ":LAST: /" . $legend_labels_per_sensor[$n_sensor2] . " (actual/limit)\\n");
							} else {
								push(@tmp, "GPRINT:trans_" . $value_name . ":LAST:" . $legend_labels_per_sensor[$n_sensor] . (($n%2 || ($n+1 == scalar(@d))) ? "\\n" : ""));
							}
						}
					}
				}
			}

			if($n_plot < $main_sensor_plots) {
				push(@tmp, "COMMENT: \\n");
				if(scalar(@d) && (scalar(@d) % 2)) {
					push(@tmp, "COMMENT: \\n");
				}
			}

			for(my $n_gpu = 0; $n_gpu < $max_number_of_gpus; $n_gpu++) {
				my $value_name = "gpu" . $n_gpu . "_val" . $n_sensor;
				push(@CDEF, "CDEF:trans_" . $value_name . "=" . $value_name . $value_transformations_per_sensor[$n_sensor]);
				if ($n_sensor2) {
					my $value_name2 = "gpu" . $n_gpu . "_val" . $n_sensor2;
					push(@CDEF, "CDEF:trans_" . $value_name2 . "=" . $value_name2 . $value_transformations_per_sensor[$n_sensor2]);
				}
			}
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{($n_plot < $main_sensor_plots) ? 'main' : 'small'});
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
				@tmp = @tmpz;
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}
			if ($n_plot >= $main_sensor_plots) {
				$height *= 1.6
			}

			my @def_sensor_average;
			my $cdef_sensor_allvalues = "CDEF:allvalues=";
			for(my $n_gpu = 0; $n_gpu < $max_number_of_gpus; $n_gpu++) {
				my $value_name = "gpu" . $n_gpu . "_val" . $n_sensor;
				push(@def_sensor_average, "DEF:" . $value_name . "=$rrd:nv" . $e . "_" . $value_name . ":AVERAGE");
				if($n_sensor2) {
					my $value_name2 = "gpu" . $n_gpu . "_val" . $n_sensor2;
					push(@def_sensor_average, "DEF:" . $value_name2 . "=$rrd:nv" . $e . "_" . $value_name2 . ":AVERAGE");
				}

				if($n_gpu != 0) {
					$cdef_sensor_allvalues .= ",";
				}
				if ($gap_on_all_nan) {
					$cdef_sensor_allvalues .= $value_name . ",UN,0,1,IF";
				} else {
					$cdef_sensor_allvalues .= $value_name;
				}
			}
			$cdef_sensor_allvalues .= ",+" x ($max_number_of_gpus - 1);
			if ($gap_on_all_nan) {
				$cdef_sensor_allvalues .= ",0,GT,1,UNKN,IF";
			}
			my $plot_title = $config->{graphs}->{'_nvidiagpu' . ($n_plot + 1)};
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 3 + $n_plot]",
				"--title=$plot_title ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=" . $y_axis_titles_per_plot[$n_plot],
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				$n_plot < $main_sensor_plots ? () : @{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				@def_sensor_average,
				$cdef_sensor_allvalues,
				@CDEF,
				@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3 + $n_plot]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3 + $n_plot]",
					"--title=$plot_title  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=$imgfmt_uc",
					"--vertical-label=" . $y_axis_titles_per_plot[$n_plot],
					"--width=$width",
					"--height=$height",
					"--full-size-mode",
					@extra,
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					$n_plot < $main_sensor_plots ? () : @{$cgi->{version12_small}},
					@{$colors->{graph_colors}},
					@def_sensor_average,
					$cdef_sensor_allvalues,
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3 + $n_plot]: $err\n") if $err;
			}
			$e2 = $e + $n_plot + 1;
			if($title || ($silent =~ /imagetag/ && $graph =~ /nvidiagpu$e2/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      " . picz_a_element(config => $config, IMGz => $IMGz[$e * 3 + $n_plot], IMG => $IMG[$e * 3 + $n_plot]) . "\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      " . picz_js_a_element(width => $picz_width, height => $picz_height, config => $config, IMGz => $IMGz[$e * 3 + $n_plot], IMG => $IMG[$e * 3 + $n_plot]) . "\n");
					}
				} else {
					push(@output, "      " . img_element(config => $config, IMG => $IMG[$e * 3 + $n_plot]) . "\n");
				}
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");

			if($nvidiagpu->{desc}->{$k}) {
				push(@output, "    <tr>\n");
				push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
				push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
				push(@output, "       <font size='-1'>\n");
				push(@output, "        <b>&nbsp;&nbsp;$nvidiagpu->{desc}->{$k}<b>\n");
				push(@output, "       </font></font>\n");
				push(@output, "      </td>\n");
				push(@output, "    </tr>\n");
			}
			push(@output, main::graph_footer());
		}
		$e++;
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
