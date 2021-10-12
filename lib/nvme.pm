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
my $number_of_smart_values_in_rrd = 8;	# Changing this number destroys history.
my $number_of_smart_values_in_use = 5;	# Changing this number does not require rrd recreation as long as number_of_smart_values_in_rrd is not changed. Has to be <= number_of_smart_values_in_rrd

sub nvme_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $nvme = $config->{nvme};

	if($number_of_smart_values_in_use > $number_of_smart_values_in_rrd) {
		logger("$myself: ERROR: Number of smart values (" . $number_of_smart_values_in_use . ") has smaller or equal to number of smart values in rrd (" . $number_of_smart_values_in_rrd . ")!");
		return;
	}

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
				if(index($key, '_temp].index') != -1) {
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
		if($rrd_n_hd_times_n_values / $rrd_n_hd < ($number_of_smart_values_in_rrd + 1)) {
			logger("$myself: Detected size mismatch between number_of_smart_values_in_rrd (" . $number_of_smart_values_in_rrd . ") and $rrd (" . (($rrd_n_hd_times_n_values / $rrd_n_hd) - 1) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
				push(@tmp, "DS:nvme" . $n . "_hd" . $n_hd . "_temp:GAUGE:120:0:100");
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

	my $temp;
	my @smart;

	my $n;
	my $rrdata = "N";

	foreach my $k (sort keys %{$nvme->{list}}) {
		# values delimitted by ", " (comma + space)
		my @dsk = split(', ', $nvme->{list}->{$k});
		for($n = 0; $n < $max_number_of_hds; $n++) {
			$temp = $use_nan_for_missing_data ? (0+"nan") : 0;
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
					if(/\"available_spare\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						$smart[0] = trim($tmp[1]);
						chomp($smart[0]);
					}
					if(/\"percentage_used\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						$smart[1] = trim($tmp[1]);
						chomp($smart[1]);
					}
					if(/\"data_units_written\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						$smart[2] = trim($tmp[1]);
						chomp($smart[2]);
					}
					if(/\"media_errors\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						$smart[3] = trim($tmp[1]);
						chomp($smart[3]);
					}
					if(/\"unsafe_shutdowns\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						$smart[4] = trim($tmp[1]);
						chomp($smart[4]);
					}
					if(/\"temperature\"/) {
						my @tmp = split(':', $_);
						$tmp[1] =~ tr/,//d;
						if (index($tmp[1], "{") == -1) {
							$temp = trim($tmp[1]);
							chomp($temp);
						}
					}
				}
				close(IN);
			}
			$rrdata .= ":$temp";
			foreach(@smart) {
				$rrdata .= ":$_";
			}

			# nvme alert
			if(lc($nvme->{alerts}->{availspare_enabled}) eq "y") {
				$config->{nvme_hist_alert1}->{$n} = 0
				if(!$config->{nvme_hist_alert1}->{$n});
				if($smart[0] <= $nvme->{alerts}->{availspare_threshold} && $config->{nvme_hist_alert1}->{$n} < $smart[0]) {
					if(-x $nvme->{alerts}->{availspare_script}) {
						logger("$myself: ALERT: executing script '$nvme->{alerts}->{availspare_script}'.");
						system($nvme->{alerts}->{availspare_script} . " " .$nvme->{alerts}->{availspare_timeintvl} . " " . $nvme->{alerts}->{availspare_threshold} . " " . $smart[0]);
					} else {
						logger("$myself: ERROR: script '$nvme->{alerts}->{availspare_script}' doesn't exist or don't has execution permissions.");
					}
					$config->{nvme_hist_alert1}->{$n} = $smart[0];
				}
			}
			if(lc($nvme->{alerts}->{percentused_enabled}) eq "y") {
				$config->{nvme_hist_alert2}->{$n} = 0
				if(!$config->{nvme_hist_alert2}->{$n});
				if($smart[1] >= $nvme->{alerts}->{percentused_threshold} && $config->{nvme_hist_alert2}->{$n} < $smart[1]) {
					if(-x $nvme->{alerts}->{percentused_script}) {
						logger("$myself: ALERT: executing script '$nvme->{alerts}->{percentused_script}'.");
						system($nvme->{alerts}->{percentused_script} . " " .$nvme->{alerts}->{percentused_timeintvl} . " " . $nvme->{alerts}->{percentused_threshold} . " " . $smart[1]);
					} else {
						logger("$myself: ERROR: script '$nvme->{alerts}->{percentused_script}' doesn't exist or don't has execution permissions.");
					}
					$config->{nvme_hist_alert2}->{$n} = $smart[1];
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
	my $temp_scale = "Celsius";
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
				$str = sprintf(" NVME %d               ", $n + 1);
				$line1 .= $str;
				$str = sprintf(" Temp Availspare Percentused ");
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
					$from = ($e * $max_number_of_hds * 3) + ($n2 * 3);
					$to = $from + 3;
					my ($temp, $availspare, $percentused) = @$line[$from..$to];
					@row = (celsius_to($config, $temp), $availspare, $percentused);
					push(@output, sprintf(" %4.0f %7.0f %7.0f ", @row));
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
		for($n2 = 1; $n2 <= $number_of_smart_values_in_use+1; $n2++) {
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
	foreach my $k (sort keys %{$nvme->{list}}) {
		# values delimitted by ", " (comma + space)
		my @d = split(', ', $nvme->{list}->{$k});

		if($e) {
			push(@output, "   <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}

		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		undef(@CDEF);
		undef(@tmp);
		undef(@tmpz);
		push(@tmp, "COMMENT: \\n");
		for($n = 0; $n < $max_number_of_hds; $n++) {
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
				$str = sprintf("%-20s", $dstr);
				push(@tmp, "LINE2:temp_" . $n . $LC[$n] . ":$str");
				push(@tmpz, "LINE2:temp_" . $n . $LC[$n] . ":$dstr");
				push(@tmp, "GPRINT:temp_" . $n . ":LAST:   Current\\: %2.0lf");
				push(@tmp, "GPRINT:temp_" . $n . ":AVERAGE:   Average\\: %2.0lf");
				push(@tmp, "GPRINT:temp_" . $n . ":MIN:   Min\\: %2.0lf");
				push(@tmp, "GPRINT:temp_" . $n . ":MAX:   Max\\: %2.0lf\\n");
			}
		}
		push(@tmp, "COMMENT: \\n");
		if(scalar(@d) && (scalar(@d) % 2)) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		if(lc($config->{temperature_scale}) eq "f") {
			for(my $n_hd = 0; $n_hd < $max_number_of_hds; $n_hd++) {
				push(@CDEF, "CDEF:temp_" . $n_hd . "=9,5,/,temp" . $n_hd . ",*,32,+");
			}
		} else {
			for(my $n_hd = 0; $n_hd < $max_number_of_hds; $n_hd++) {
				push(@CDEF, "CDEF:temp_" . $n_hd . "=temp" . $n_hd);
			}
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
			push(@tmp, "COMMENT: \\n");
			push(@tmp, "COMMENT: \\n");
		}

		my @def_temp_average;
		my $cdef_temp_allvalues = "CDEF:allvalues=";
		for(my $n_hd = 0; $n_hd < $max_number_of_hds; $n_hd++) {
			push(@def_temp_average, "DEF:temp" . $n_hd . "=$rrd:nvme" . $e ."_hd" . $n_hd . "_temp:AVERAGE");
			if($n_hd != 0) {
				$cdef_temp_allvalues .= ",";
			}
			if ($gap_on_all_nan) {
				$cdef_temp_allvalues .= "temp" . $n_hd . ",UN,0,1,IF";
			} else {
				$cdef_temp_allvalues .= "temp" . $n_hd;
			}
		}
		$cdef_temp_allvalues .= ",+" x ($max_number_of_hds - 1);
		if ($gap_on_all_nan) {
			$cdef_temp_allvalues .= ",0,GT,1,UNKN,IF";
		}

		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 3]",
		"--title=$config->{graphs}->{_nvme1}  ($tf->{nwhen}$tf->{twhen})",
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
		@def_temp_average,
		$cdef_temp_allvalues,
		@CDEF,
		@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3]",
			"--title=$config->{graphs}->{_nvme1}  ($tf->{nwhen}$tf->{twhen})",
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
			@def_temp_average,
			$cdef_temp_allvalues,
			@CDEF,
			@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /nvme$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3] . "'>\n");
			}
		}

		if($title && $number_of_smart_values_in_use == 0) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}

		my @y_axis_titles = ("Percent (%)", "Percent (%)", "bytes", "Errors", "Counts");
		my @y_axis_factors = (1, 1, 512000, 1, 1);
		my @legend_labels = ("%3.0lf%%", "%3.0lf%%", "%7.3lf%s", " %3.0lf%s", " %3.0lf%s");
		my @smart_order = (2, 0, 1, 3, 4); # To rearange the plots
		my $main_smart_plots = 1; # Number of smart plots on the left side.

		for(my $n_plot = 0; $n_plot < $number_of_smart_values_in_use; $n_plot += 1) {
			if($title && $n_plot == $main_smart_plots) {
				push(@output, "    </td>\n");
				push(@output, "    <td class='td-valign-top'>\n");
			}
			my $n_smart = $smart_order[$n_plot];
			@riglim = @{setup_riglim($rigid[$n_smart+1], $limit[$n_smart+1])};
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
						$str = sprintf("%-57s", $dstr);
					} else {
						$str = sprintf("%-14s", substr($dstr, 0, 14));
					}
					my $value_name = "hd" . $n . "_smv" . $n_smart;
					push(@tmp, "LINE2:mult_" . $value_name . $LC[$n] . ":$str" . ($n_plot < $main_smart_plots ? "" :"\\: \\g"));
					push(@tmpz, "LINE2:mult_" . $value_name . $LC[$n] . ":$dstr\\g");
					if($n_plot < $main_smart_plots) {
						push(@tmp, "GPRINT:mult_" . $value_name . ":LAST: Current\\: " . $legend_labels[$n_smart] . "\\n");
					} else {
						push(@tmp, "GPRINT:mult_" . $value_name . ":LAST:" . $legend_labels[$n_smart] . (($n%2 || !$d[$n+1]) ? "\\n" : ""));
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
				push(@CDEF, "CDEF:mult_" . $value_name . "=" . $value_name . "," . $y_axis_factors[$n_smart] . ",*");
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
			my $plot_title = $config->{graphs}->{'_nvme' . ($n_smart + 2)};
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 3 + $n_smart + 1]",
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
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3 + $n_smart + 1]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3 + $n_smart + 1]",
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
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3 + $n_smart + 1]: $err\n") if $err;
			}
			$e2 = $e + $n_smart + 2;
			if($title || ($silent =~ /imagetag/ && $graph =~ /nvme$e2/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + $n_smart + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + $n_smart + 1] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + $n_smart + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + $n_smart + 1] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + $n_smart + 1] . "'>\n");
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
