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

package nvme;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Cwd 'abs_path';
use File::Basename;
use Exporter 'import';
our @EXPORT = qw(nvme_init nvme_update nvme_cgi);

my $max_number_of_hds = 8;							# Changing this number destroys history.
my $number_of_smart_values_in_rrd = 9;	# Changing this number destroys history.

sub nvme_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nvme = $config->{nvme};

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	foreach my $k (sort keys %{$nvme->{list}}) {
		# values delimitted by ", " (comma + space)
		my @dsk = split(', ', $nvme->{list}->{$k});
		for(my $n = 0; $n < $max_number_of_hds; $n++) {
			if($dsk[$n]) {
				my $d = trim($dsk[$n]);
				$d =~ s/^\"//;
				$d =~ s/\"$//;
				$d =~ s/^(.+?) .*$/$1/;
				next if -e $d;
				logger("$myself: ERROR: invalid or inexistent device name '$d'.");
				if(lc($nvme->{accept_invalid_nvme} || "") ne "y") {
					logger("$myself: 'accept_invalid_nvme' option is not set.");
					logger("$myself: WARNING: initialization aborted.");
					return;
				}
			}
		}
	}

	if(-e $rrd) {
		my $rrd_n_hd = 0;
		my $rrd_n_hd_times_n_values = 0;
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'ds[') == 0) {
				if(index($key, '.type') != -1) {
					push(@ds, substr($key, 3, index($key, ']') - 3));
				}
				if(index($key, '_smv0].index') != -1) {
					$rrd_n_hd += 1;
				}
				if(index($key, '.index') != -1) {
					$rrd_n_hd_times_n_values += 1;
				}
			}
			if(index($key, 'rra[') == 0) {
				if(index($key, '.rows') != -1) {
					push(@rra, substr($key, 4, index($key, ']') - 4));
				}
			}
		}
		if(scalar(@ds) / $rrd_n_hd_times_n_values != keys(%{$nvme->{list}})) {
			logger("$myself: Detected size mismatch between <list>...</list> (" . keys(%{$nvme->{list}}) . ") and $rrd (" . scalar(@ds) / $rrd_n_hd_times_n_values . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if($rrd_n_hd < $max_number_of_hds) {
			logger("$myself: Detected size mismatch between max_number_of_hds (" . $max_number_of_hds . ") and $rrd (" . $rrd_n_hd . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
		if($rrd_n_hd_times_n_values / $rrd_n_hd < $number_of_smart_values_in_rrd) {
			logger("$myself: Detected size mismatch between number_of_smart_values_in_rrd (" . $number_of_smart_values_in_rrd . ") and $rrd (" . ($rrd_n_hd_times_n_values / $rrd_n_hd) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < keys(%{$nvme->{list}}); $n++) {
			for(my $n_hd = 0; $n_hd < $max_number_of_hds; $n_hd++) {
				for(my $n_smart = 0; $n_smart < $number_of_smart_values_in_rrd; $n_smart++) {
					push(@tmp, "DS:nvme" . $n . "_hd" . $n_hd . "_smv" . $n_smart . ":GAUGE:120:0:U");
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
	if(lc($nvme->{alerts}->{availspare_enabled} || "") eq "y") {
		if(! -x $nvme->{alerts}->{availspare_script}) {
			logger("$myself: ERROR: script '$nvme->{alerts}->{availspare_script}' doesn't exist or don't has execution permissions.");
		}
	}
	if(lc($nvme->{alerts}->{percentused_enabled} || "") eq "y") {
		if(! -x $nvme->{alerts}->{percentused_script}) {
			logger("$myself: ERROR: script '$nvme->{alerts}->{percentused_script}' doesn't exist or don't has execution permissions.");
		}
	}

	$config->{nvme_hist_alert1} = ();
	$config->{nvme_hist_alert2} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub nvme_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nvme = $config->{nvme};
	my $use_nan_for_missing_data = lc($nvme->{use_nan_for_missing_data} || "") eq "y" ? 1 : 0;

	my @smart;

	my $n;
	my $rrdata = "N";

	foreach my $k (sort keys %{$nvme->{list}}) {
		# values delimitted by ", " (comma + space)
		my @dsk = split(', ', $nvme->{list}->{$k});
		for($n = 0; $n < $max_number_of_hds; $n++) {
			@smart = ($use_nan_for_missing_data ? (0+"nan") : 0) x $number_of_smart_values_in_rrd;

			if($dsk[$n]) {
				my $d = trim($dsk[$n]);
				$d =~ s/^\"//;
				$d =~ s/\"$//;

				# check if device name is a symbolic link
				# e.g. /dev/nvme/by-path/pci-0000:07:07.0-scsi-0:0:0:0
				if(-l $d) {
					$d = abs_path(dirname($d) . "/" . readlink($d));
					chomp($d);
				}

				open(IN, "smartctl -A $d --json |");
				while(<IN>) {
					if(/\"temperature\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						if (index($tmp[1], "{") == -1) {
							my $smartIndex = 0;
							$smart[$smartIndex] = trim($tmp[1]);
							chomp($smart[$smartIndex]);
						}
					}
					if(/\"available_spare\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						my $smartIndex = 1;
						$smart[$smartIndex] = trim($tmp[1]);
						chomp($smart[$smartIndex]);
					}
					if(/\"percentage_used\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						my $smartIndex = 2;
						$smart[$smartIndex] = trim($tmp[1]);
						chomp($smart[$smartIndex]);
					}
					if(/\"data_units_written\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						my $smartIndex = 3;
						$smart[$smartIndex] = trim($tmp[1]);
						chomp($smart[$smartIndex]);
					}
					if(/\"media_errors\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						my $smartIndex = 4;
						$smart[$smartIndex] = trim($tmp[1]);
						chomp($smart[$smartIndex]);
					}
					if(/\"unsafe_shutdowns\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						my $smartIndex = 5;
						$smart[$smartIndex] = trim($tmp[1]);
						chomp($smart[$smartIndex]);
					}
				}
				close(IN);
			}
			foreach(@smart) {
				$rrdata .= ":$_";
			}

			# nvme alert
			if(lc($nvme->{alerts}->{availspare_enabled}) eq "y") {
				my $smartIndex = 1;
				$config->{nvme_hist_alert1}->{$n} = 0
				if(!$config->{nvme_hist_alert1}->{$n});
				if($smart[$smartIndex] <= $nvme->{alerts}->{availspare_threshold} && $config->{nvme_hist_alert1}->{$n} < $smart[$smartIndex]) {
					if(-x $nvme->{alerts}->{availspare_script}) {
						logger("$myself: ALERT: executing script '$nvme->{alerts}->{availspare_script}'.");
						system($nvme->{alerts}->{availspare_script} . " " .$nvme->{alerts}->{availspare_timeintvl} . " " . $nvme->{alerts}->{availspare_threshold} . " " . $smart[$smartIndex]);
					} else {
						logger("$myself: ERROR: script '$nvme->{alerts}->{availspare_script}' doesn't exist or don't has execution permissions.");
					}
					$config->{nvme_hist_alert1}->{$n} = $smart[$smartIndex];
				}
			}
			if(lc($nvme->{alerts}->{percentused_enabled}) eq "y") {
				my $smartIndex = 2;
				$config->{nvme_hist_alert2}->{$n} = 0
				if(!$config->{nvme_hist_alert2}->{$n});
				if($smart[$smartIndex] >= $nvme->{alerts}->{percentused_threshold} && $config->{nvme_hist_alert2}->{$n} < $smart[$smartIndex]) {
					if(-x $nvme->{alerts}->{percentused_script}) {
						logger("$myself: ALERT: executing script '$nvme->{alerts}->{percentused_script}'.");
						system($nvme->{alerts}->{percentused_script} . " " .$nvme->{alerts}->{percentused_timeintvl} . " " . $nvme->{alerts}->{percentused_threshold} . " " . $smart[$smartIndex]);
					} else {
						logger("$myself: ERROR: script '$nvme->{alerts}->{percentused_script}' doesn't exist or don't has execution permissions.");
					}
					$config->{nvme_hist_alert2}->{$n} = $smart[$smartIndex];
				}
			}
		}
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub nvme_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $nvme = $config->{nvme};
	my @rigid = split(',', ($nvme->{rigid} || ""));
	my @limit = split(',', ($nvme->{limit} || ""));
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

	my $show_extended_plots = lc($nvme->{show_extended_plots} || "") eq "y" ? 1 : 0;
	my $number_of_smart_values_in_use = $show_extended_plots ? 6 : 3;
	if($number_of_smart_values_in_use > $number_of_smart_values_in_rrd) {
		logger(@output, "ERROR: Number of smart values (" . $number_of_smart_values_in_use . ") has smaller or equal to number of smart values in rrd (" . $number_of_smart_values_in_rrd . ")!");
		return;
	}
	my $show_current_values = lc($nvme->{show_current_values} || "") eq "y" ? 1 : 0;

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
	my $gap_on_all_nan = lc($nvme->{gap_on_all_nan} || "") eq "y" ? 1 : 0;

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
		foreach my $k (sort keys %{$nvme->{list}}) {
			# values delimitted by ", " (comma + space)
			my @d = split(', ', $nvme->{list}->{$k});
			for($n = 0; $n < scalar(@d); $n++) {
				$str = sprintf(" NVMe %d               ", $n + 1);
				$line1 .= $str;
				$str = sprintf(" Smart values ");
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
			foreach my $k (sort keys %{$nvme->{list}}) {
				# values delimitted by ", " (comma + space)
				my @d = split(', ', $nvme->{list}->{$k});
				for($n2 = 0; $n2 < scalar(@d); $n2++) {
					$from = ($e * $max_number_of_hds * $number_of_smart_values_in_rrd) + ($n2 * $number_of_smart_values_in_rrd);
					$to = $from + 3;
					my @smart_values = @$line[$from..$to];
					@row = (celsius_to($config, $smart_values[0]), @smart_values[1, -1]);
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

	for($n = 0; $n < keys(%{$nvme->{list}}); $n++) {
		for($n2 = 0; $n2 < $number_of_smart_values_in_use; $n2++) {
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

	# Plot settings in order of the smart array.
	my @y_axis_titles = ((lc($config->{temperature_scale}) eq "f" ? "Fahrenheit" : "Celsius"), "Percent (%)", "Percent (%)", "bytes", "Errors", "Counts");
	my @value_transformations = ((lc($config->{temperature_scale}) eq "f" ? ",9,*,5,/,32,+" : ""), "", "", ",512000,*", "", "");
	my @legend_labels = ("%2.0lf", "%4.0lf%%", "%4.0lf%%", "%7.3lf%s", "%4.0lf%s", "%4.0lf%s");

	my @plot_order = $show_extended_plots ? (0, 3, 1, 2, 4, 5) : (0, 1, 2); # To rearange the plots
	my $main_smart_plots = $show_extended_plots ? 2 : 1; # Number of smart plots on the left side.
	my @main_plot_with_average = $show_extended_plots ? (1, 0) : (1); # Wether or not the main plots show average, min and max or only the last value in the legend.

	if(!$show_extended_plots) {
		for(my $index = 0; $index < scalar(@plot_order); $index++) {
			$y_axis_titles[$index] = $y_axis_titles[$plot_order[$index]];
			$value_transformations[$index] = $value_transformations[$plot_order[$index]];
			$legend_labels[$index] = $legend_labels[$plot_order[$index]];
		}
		$#y_axis_titles = scalar(@plot_order)-1;
		$#value_transformations = scalar(@plot_order)-1;
		$#legend_labels = scalar(@plot_order)-1;
	}

	if(scalar(@y_axis_titles) != $number_of_smart_values_in_use) {
		push(@output, "ERROR: Size of y_axis_titles (" . scalar(@y_axis_titles) . ") has to be equal to number_of_smart_values_in_use (" . $number_of_smart_values_in_use . ")");
	}
	if(scalar(@value_transformations) != $number_of_smart_values_in_use) {
		push(@output, "ERROR: Size of value_transformations (" . scalar(@value_transformations) . ") has to be equal to number_of_smart_values_in_use (" . $number_of_smart_values_in_use . ")");
	}
	if(scalar(@legend_labels) != $number_of_smart_values_in_use) {
		push(@output, "ERROR: Size of legend_labels (" . scalar(@legend_labels) . ") has to be equal to number_of_smart_values_in_use (" . $number_of_smart_values_in_use . ")");
	}
	if(scalar(@plot_order) != $number_of_smart_values_in_use) {
		push(@output, "ERROR: Size of plot_order (" . scalar(@plot_order) . ") has to be equal to number_of_smart_values_in_use (" . $number_of_smart_values_in_use . ")");
	}
	if(scalar(@main_plot_with_average) != $main_smart_plots) {
		push(@output, "ERROR: Size of main_plot_with_average (" . scalar(@main_plot_with_average) . ") has to be equal to main_smart_plots (" . $main_smart_plots . ")");
	}

	$e = 0;
	foreach my $k (sort keys %{$nvme->{list}}) {
		# values delimitted by ", " (comma + space)
		my @d = split(', ', $nvme->{list}->{$k});
		if($e) {
			push(@output, "   <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		for(my $n_plot = 0; $n_plot < $number_of_smart_values_in_use; $n_plot += 1) {
			if($title && $n_plot == $main_smart_plots) {
				push(@output, "    </td>\n");
				push(@output, "    <td class='td-valign-top'>\n");
			}
			my $n_smart = $plot_order[$n_plot];
			@riglim = @{setup_riglim($rigid[$n_smart], $limit[$n_smart])};
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			if($n_plot < $main_smart_plots) {
				push(@tmp, "COMMENT: \\n");
			}
			for($n = 0; $n < $max_number_of_hds; $n += 1) {
				if($d[$n]) {
					my $dstr = trim($d[$n]);
					my $base = "";
					$dstr =~ s/^\"//;
					$dstr =~ s/\"$//;

					# check if device name is a symbolic link
					# e.g. /dev/nvme/by-path/pci-0000:07:07.0-scsi-0:0:0:0
					if(-l $dstr) {
						$base = basename($dstr);
						$dstr = abs_path(dirname($dstr) . "/" . readlink($dstr));
						chomp($dstr);
					}

					#				$dstr =~ s/^(.+?) .*$/$1/;
					if($base && defined($nvme->{map}->{$base})) {
						$dstr = $nvme->{map}->{$base};
					} else {
						if(defined($nvme->{map}->{$dstr})) {
							$dstr = $nvme->{map}->{$dstr};
						}
					}
					if($n_plot < $main_smart_plots) {
						if($main_plot_with_average[$n_plot]) {
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
					my $value_name = "hd" . $n . "_smv" . $n_smart;
					push(@tmp, "LINE2:trans_" . $value_name . $LC[$n] . ":$str" . ($n_plot < $main_smart_plots ? "" : ( $show_current_values ? "\\: \\g" : (($n%2 || !$d[$n+1]) ? "\\n" : ""))));
					push(@tmpz, "LINE2:trans_" . $value_name . $LC[$n] . ":$dstr");
					if($n_plot < $main_smart_plots) {
						if($main_plot_with_average[$n_plot]) {
							push(@tmp, "GPRINT:trans_" . $value_name . ":LAST:   Current\\: " . $legend_labels[$n_smart]);
							push(@tmp, "GPRINT:trans_" . $value_name . ":AVERAGE:   Average\\: " . $legend_labels[$n_smart]);
							push(@tmp, "GPRINT:trans_" . $value_name . ":MIN:   Min\\: " . $legend_labels[$n_smart]);
							push(@tmp, "GPRINT:trans_" . $value_name . ":MAX:   Max\\: " . $legend_labels[$n_smart] . "\\n");
						} else {
						  push(@tmp, "GPRINT:trans_" . $value_name . ":LAST: Current\\: " . $legend_labels[$n_smart] . "\\n");
						}
					} else {
						if($show_current_values) {
						  push(@tmp, "GPRINT:trans_" . $value_name . ":LAST:" . $legend_labels[$n_smart] . (($n%2 || !$d[$n+1]) ? "\\n" : ""));
						}
					}
				}
			}

			if($n_plot < $main_smart_plots) {
				push(@tmp, "COMMENT: \\n");
				if(scalar(@d) && (scalar(@d) % 2)) {
					push(@tmp, "COMMENT: \\n");
				}
			}

			for(my $n_hd = 0; $n_hd < $max_number_of_hds; $n_hd++) {
				my $value_name = "hd" . $n_hd . "_smv" . $n_smart;
				push(@CDEF, "CDEF:trans_" . $value_name . "=" . $value_name . $value_transformations[$n_smart]);
			}
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{($n_plot < $main_smart_plots) ? 'main' : 'small'});
			if($silent =~ /imagetag/) {
				($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
				($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
				@tmp = @tmpz;
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
				push(@tmp, "COMMENT: \\n");
			}

			my @def_smart_average;
			my $cdef_smart_allvalues = "CDEF:allvalues=";
			for(my $n_hd = 0; $n_hd < $max_number_of_hds; $n_hd++) {
				my $value_name = "hd" . $n_hd . "_smv" . $n_smart;
				push(@def_smart_average, "DEF:" . $value_name . "=$rrd:nvme" . $e . "_" . $value_name . ":AVERAGE");
				if($n_hd != 0) {
					$cdef_smart_allvalues .= ",";
				}
				if ($gap_on_all_nan) {
					$cdef_smart_allvalues .= $value_name . ",UN,0,1,IF";
				} else {
					$cdef_smart_allvalues .= $value_name;
				}
			}
			$cdef_smart_allvalues .= ",+" x ($max_number_of_hds - 1);
			if ($gap_on_all_nan) {
				$cdef_smart_allvalues .= ",0,GT,1,UNKN,IF";
			}
			my $plot_title = $config->{graphs}->{'_nvme' . ($n_smart + 1)};
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 3 + $n_smart]",
			"--title=$plot_title ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=" . $y_axis_titles[$n_smart],
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			$n_plot < $main_smart_plots ? () : @{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			@def_smart_average,
			$cdef_smart_allvalues,
			@CDEF,
			@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3 + $n_smart]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3 + $n_smart]",
				"--title=$plot_title  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=" . $y_axis_titles[$n_smart],
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				$n_plot < $main_smart_plots ? () : @{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				@def_smart_average,
				$cdef_smart_allvalues,
				@CDEF,
				@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3 + $n_smart]: $err\n") if $err;
			}
			$e2 = $e + $n_smart + 1;
			if($title || ($silent =~ /imagetag/ && $graph =~ /nvme$e2/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + $n_smart] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + $n_smart] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + $n_smart] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + $n_smart] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + $n_smart] . "'>\n");
				}
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");

			if($nvme->{desc}->{$k}) {
				push(@output, "    <tr>\n");
				push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
				push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
				push(@output, "       <font size='-1'>\n");
				push(@output, "        <b>&nbsp;&nbsp;$nvme->{desc}->{$k}<b>\n");
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
