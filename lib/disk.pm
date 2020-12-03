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

package disk;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Cwd 'abs_path';
use File::Basename;
use Exporter 'import';
our @EXPORT = qw(disk_init disk_update disk_cgi);

sub disk_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $disk = $config->{disk};

	my $info;
	my @ds;
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	foreach my $k (sort keys %{$disk->{list}}) {
		# values delimitted by ", " (comma + space)
		my @dsk = split(', ', $disk->{list}->{$k});
		for(my $n = 0; $n < 8; $n++) {
			if($dsk[$n]) {
				my $d = trim($dsk[$n]);
				$d =~ s/^\"//;
				$d =~ s/\"$//;
				$d =~ s/^(.+?) .*$/$1/;
	  			next if -e $d;
				logger("$myself: ERROR: invalid or inexistent device name '$d'.");
				if(lc($disk->{accept_invalid_disk} || "") ne "y") {
					logger("$myself: 'accept_invalid_disk' option is not set.");
					logger("$myself: WARNING: initialization aborted.");
					return;
				}
			}
		}
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
		if(scalar(@ds) / 24 != keys(%{$disk->{list}})) {
			logger("$myself: Detected size mismatch between <list>...</list> (" . keys(%{$disk->{list}}) . ") and $rrd (" . scalar(@ds) / 24 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < keys(%{$disk->{list}}); $n++) {
			push(@tmp, "DS:disk" . $n . "_hd0_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd0_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd0_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd1_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd1_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd1_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd2_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd2_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd2_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd3_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd3_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd3_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd4_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd4_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd4_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd5_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd5_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd5_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd6_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd6_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd6_smart2:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd7_temp:GAUGE:120:0:100");
			push(@tmp, "DS:disk" . $n . "_hd7_smart1:GAUGE:120:0:U");
			push(@tmp, "DS:disk" . $n . "_hd7_smart2:GAUGE:120:0:U");
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
	if(lc($disk->{alerts}->{realloc_enabled} || "") eq "y") {
		if(! -x $disk->{alerts}->{realloc_script}) {
			logger("$myself: ERROR: script '$disk->{alerts}->{realloc_script}' doesn't exist or don't has execution permissions.");
		}
	}
	if(lc($disk->{alerts}->{pendsect_enabled} || "") eq "y") {
		if(! -x $disk->{alerts}->{pendsect_script}) {
			logger("$myself: ERROR: script '$disk->{alerts}->{pendsect_script}' doesn't exist or don't has execution permissions.");
		}
	}

	$config->{disk_hist_alert1} = ();
	$config->{disk_hist_alert2} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub disk_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $disk = $config->{disk};

	my $temp;
	my $smart1;
	my $smart2;

	my $n;
	my $rrdata = "N";

	foreach my $k (sort keys %{$disk->{list}}) {
		# values delimitted by ", " (comma + space)
		my @dsk = split(', ', $disk->{list}->{$k});
		for($n = 0; $n < 8; $n++) {
			$temp = 0;
			$smart1 = 0;
			$smart2 = 0;
			if($dsk[$n]) {
				my $d = trim($dsk[$n]);
				$d =~ s/^\"//;
				$d =~ s/\"$//;

				# check if device name is a symbolic link
				# e.g. /dev/disk/by-path/pci-0000:07:07.0-scsi-0:0:0:0
				if(-l $d) {
					$d = abs_path(dirname($d) . "/" . readlink($d));
					chomp($d);
				}

	  			open(IN, "smartctl -A $d |");
				while(<IN>) {
					if(/^  5/ && /Reallocated_Sector_Ct/) {
						my @tmp = split(' ', $_);
						$smart1 = $tmp[9];
						chomp($smart1);
					}
					if(/^194/ && /Temperature_Celsius/) {
						my @tmp = split(' ', $_);
						$temp = $tmp[9];
						chomp($temp);
					}
					if(/^190/ && /Airflow_Temperature_Cel/) {
						my @tmp = split(' ', $_);
						$temp = $tmp[9] unless $temp;
						chomp($temp);
					}
					if(/^197/ && /Current_Pending_Sector/) {
						my @tmp = split(' ', $_);
						$smart2 = $tmp[9];
						chomp($smart2);
					}
					if(/^Current Drive Temperature: /) {
						my @tmp = split(' ', $_);
						$temp = $tmp[3] unless $temp;
						chomp($temp);
					}
					if(/^Temperature: /) {
                                                my @tmp = split(' ', $_);
                                                $temp = $tmp[1] unless $temp;
                                                chomp($temp);
                                        }
				}
				close(IN);
				if(!$temp) {
	  				if(open(IN, "hddtemp -wqn $d |")) {
						$temp = <IN>;
						close(IN);
					} else {
						logger("$myself: 'smartctl' failed to get data from '$d' and 'hddtemp' seems doesn't exist.");
					}
				}
				chomp($temp);
			}
			$rrdata .= ":$temp";
			$rrdata .= ":$smart1";
			$rrdata .= ":$smart2";

			# DISK alert
			if(lc($disk->{alerts}->{realloc_enabled}) eq "y") {
				$config->{disk_hist_alert1}->{$n} = 0
					if(!$config->{disk_hist_alert1}->{$n});
				if($smart1 >= $disk->{alerts}->{realloc_threshold} && $config->{disk_hist_alert1}->{$n} < $smart1) {
					if(-x $disk->{alerts}->{realloc_script}) {
						logger("$myself: ALERT: executing script '$disk->{alerts}->{realloc_script}'.");
						system($disk->{alerts}->{realloc_script} . " " .$disk->{alerts}->{realloc_timeintvl} . " " . $disk->{alerts}->{realloc_threshold} . " " . $smart1);
					} else {
						logger("$myself: ERROR: script '$disk->{alerts}->{realloc_script}' doesn't exist or don't has execution permissions.");
					}
					$config->{disk_hist_alert1}->{$n} = $smart1;
				}
			}
			if(lc($disk->{alerts}->{pendsect_enabled}) eq "y") {
				$config->{disk_hist_alert2}->{$n} = 0
					if(!$config->{disk_hist_alert2}->{$n});
				if($smart2 >= $disk->{alerts}->{pendsect_threshold} && $config->{disk_hist_alert2}->{$n} < $smart2) {
					if(-x $disk->{alerts}->{pendsect_script}) {
						logger("$myself: ALERT: executing script '$disk->{alerts}->{pendsect_script}'.");
						system($disk->{alerts}->{pendsect_script} . " " .$disk->{alerts}->{pendsect_timeintvl} . " " . $disk->{alerts}->{pendsect_threshold} . " " . $smart2);
					} else {
						logger("$myself: ERROR: script '$disk->{alerts}->{pendsect_script}' doesn't exist or don't has execution permissions.");
					}
					$config->{disk_hist_alert2}->{$n} = $smart2;
				}
			}
		}
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub disk_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $disk = $config->{disk};
	my @rigid = split(',', ($disk->{rigid} || ""));
	my @limit = split(',', ($disk->{limit} || ""));
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
		foreach my $k (sort keys %{$disk->{list}}) {
			# values delimitted by ", " (comma + space)
			my @d = split(', ', $disk->{list}->{$k});
			for($n = 0; $n < scalar(@d); $n++) {
				$str = sprintf(" DISK %d               ", $n + 1);
				$line1 .= $str;
				$str = sprintf(" Temp Realloc Pending ");
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
			foreach my $k (sort keys %{$disk->{list}}) {
				# values delimitted by ", " (comma + space)
				my @d = split(', ', $disk->{list}->{$k});
				for($n2 = 0; $n2 < scalar(@d); $n2++) {
					$from = ($e * 8 * 3) + ($n2 * 3);
					$to = $from + 3;
					my ($temp, $realloc, $pending) = @$line[$from..$to];
					@row = (celsius_to($config, $temp), $realloc, $pending);
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

	for($n = 0; $n < keys(%{$disk->{list}}); $n++) {
		for($n2 = 1; $n2 <= 8; $n2++) {
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
	foreach my $k (sort keys %{$disk->{list}}) {
		# values delimitted by ", " (comma + space)
		my @d = split(', ', $disk->{list}->{$k});

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
		for($n = 0; $n < 8; $n++) {
			if($d[$n]) {
				my $dstr = trim($d[$n]);
				my $base = "";
				$dstr =~ s/^\"//;
				$dstr =~ s/\"$//;

				# check if device name is a symbolic link
				# e.g. /dev/disk/by-path/pci-0000:07:07.0-scsi-0:0:0:0
				if(-l $dstr) {
					$base = basename($dstr);
					$dstr = abs_path(dirname($dstr) . "/" . readlink($dstr));
					chomp($dstr);
				}

				$dstr =~ s/^(.+?) .*$/$1/;
				if($base && defined($disk->{map}->{$base})) {
					$dstr = $disk->{map}->{$base};
				} else {
					if(defined($disk->{map}->{$dstr})) {
						$dstr = $disk->{map}->{$dstr};
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
		push(@tmp, "COMMENT: \\n");
		if(scalar(@d) && (scalar(@d) % 2)) {
			push(@tmp, "COMMENT: \\n");
		}
		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		if(lc($config->{temperature_scale}) eq "f") {
			push(@CDEF, "CDEF:temp_0=9,5,/,temp0,*,32,+");
			push(@CDEF, "CDEF:temp_1=9,5,/,temp1,*,32,+");
			push(@CDEF, "CDEF:temp_2=9,5,/,temp2,*,32,+");
			push(@CDEF, "CDEF:temp_3=9,5,/,temp3,*,32,+");
			push(@CDEF, "CDEF:temp_4=9,5,/,temp4,*,32,+");
			push(@CDEF, "CDEF:temp_5=9,5,/,temp5,*,32,+");
			push(@CDEF, "CDEF:temp_6=9,5,/,temp6,*,32,+");
			push(@CDEF, "CDEF:temp_7=9,5,/,temp7,*,32,+");
		} else {
			push(@CDEF, "CDEF:temp_0=temp0");
			push(@CDEF, "CDEF:temp_1=temp1");
			push(@CDEF, "CDEF:temp_2=temp2");
			push(@CDEF, "CDEF:temp_3=temp3");
			push(@CDEF, "CDEF:temp_4=temp4");
			push(@CDEF, "CDEF:temp_5=temp5");
			push(@CDEF, "CDEF:temp_6=temp6");
			push(@CDEF, "CDEF:temp_7=temp7");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 3]",
			"--title=$config->{graphs}->{_disk1}  ($tf->{nwhen}$tf->{twhen})",
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
			"DEF:temp0=$rrd:disk" . $e ."_hd0_temp:AVERAGE",
			"DEF:temp1=$rrd:disk" . $e ."_hd1_temp:AVERAGE",
			"DEF:temp2=$rrd:disk" . $e ."_hd2_temp:AVERAGE",
			"DEF:temp3=$rrd:disk" . $e ."_hd3_temp:AVERAGE",
			"DEF:temp4=$rrd:disk" . $e ."_hd4_temp:AVERAGE",
			"DEF:temp5=$rrd:disk" . $e ."_hd5_temp:AVERAGE",
			"DEF:temp6=$rrd:disk" . $e ."_hd6_temp:AVERAGE",
			"DEF:temp7=$rrd:disk" . $e ."_hd7_temp:AVERAGE",
			"CDEF:allvalues=temp0,temp1,temp2,temp3,temp4,temp5,temp6,temp7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3]",
				"--title=$config->{graphs}->{_disk1}  ($tf->{nwhen}$tf->{twhen})",
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
				"DEF:temp0=$rrd:disk" . $e ."_hd0_temp:AVERAGE",
				"DEF:temp1=$rrd:disk" . $e ."_hd1_temp:AVERAGE",
				"DEF:temp2=$rrd:disk" . $e ."_hd2_temp:AVERAGE",
				"DEF:temp3=$rrd:disk" . $e ."_hd3_temp:AVERAGE",
				"DEF:temp4=$rrd:disk" . $e ."_hd4_temp:AVERAGE",
				"DEF:temp5=$rrd:disk" . $e ."_hd5_temp:AVERAGE",
				"DEF:temp6=$rrd:disk" . $e ."_hd6_temp:AVERAGE",
				"DEF:temp7=$rrd:disk" . $e ."_hd7_temp:AVERAGE",
				"CDEF:allvalues=temp0,temp1,temp2,temp3,temp4,temp5,temp6,temp7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /disk$e2/)) {
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

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}
		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < 8; $n += 2) {
			if($d[$n]) {
				my $dstr = trim($d[$n]);
				$dstr =~ s/^\"//;
				$dstr =~ s/\"$//;

				# check if device name is a symbolic link
				# e.g. /dev/disk/by-path/pci-0000:07:07.0-scsi-0:0:0:0
				if(-l $dstr) {
					$dstr = abs_path(dirname($dstr) . "/" . readlink($dstr));
					chomp($dstr);
				}

				$dstr =~ s/^(.+?) .*$/$1/;
				$str = sprintf("%-17s", substr($dstr, 0, 17));
				push(@tmp, "LINE2:rsc" . $n . $LC[$n] . ":$str");
				push(@tmpz, "LINE2:rsc" . $n . $LC[$n] . ":$dstr\\g");
			}
			if($d[$n + 1]) {
				my $dstr = trim($d[$n + 1]);
				$dstr =~ s/^\"//;
				$dstr =~ s/\"$//;

				# check if device name is a symbolic link
				# e.g. /dev/disk/by-path/pci-0000:07:07.0-scsi-0:0:0:0
				if(-l $dstr) {
					$dstr = abs_path(dirname($dstr) . "/" . readlink($dstr));
					chomp($dstr);
				}

				$dstr =~ s/^(.+?) .*$/$1/;
				$str = sprintf("%-17s", substr($dstr, 0, 17));
				push(@tmp, "LINE2:rsc" . ($n + 1) . $LC[$n + 1] . ":$str\\n");
				push(@tmpz, "LINE2:rsc" . ($n + 1) . $LC[$n + 1] . ":$dstr\\g");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 3 + 1]",
			"--title=$config->{graphs}->{_disk2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Sectors",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:rsc0=$rrd:disk" . $e . "_hd0_smart1:AVERAGE",
			"DEF:rsc1=$rrd:disk" . $e . "_hd1_smart1:AVERAGE",
			"DEF:rsc2=$rrd:disk" . $e . "_hd2_smart1:AVERAGE",
			"DEF:rsc3=$rrd:disk" . $e . "_hd3_smart1:AVERAGE",
			"DEF:rsc4=$rrd:disk" . $e . "_hd4_smart1:AVERAGE",
			"DEF:rsc5=$rrd:disk" . $e . "_hd5_smart1:AVERAGE",
			"DEF:rsc6=$rrd:disk" . $e . "_hd6_smart1:AVERAGE",
			"DEF:rsc7=$rrd:disk" . $e . "_hd7_smart1:AVERAGE",
			"CDEF:allvalues=rsc0,rsc1,rsc2,rsc3,rsc4,rsc5,rsc6,rsc7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3 + 1]",
				"--title=$config->{graphs}->{_disk2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Sectors",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:rsc0=$rrd:disk" . $e . "_hd0_smart1:AVERAGE",
				"DEF:rsc1=$rrd:disk" . $e . "_hd1_smart1:AVERAGE",
				"DEF:rsc2=$rrd:disk" . $e . "_hd2_smart1:AVERAGE",
				"DEF:rsc3=$rrd:disk" . $e . "_hd3_smart1:AVERAGE",
				"DEF:rsc4=$rrd:disk" . $e . "_hd4_smart1:AVERAGE",
				"DEF:rsc5=$rrd:disk" . $e . "_hd5_smart1:AVERAGE",
				"DEF:rsc6=$rrd:disk" . $e . "_hd6_smart1:AVERAGE",
				"DEF:rsc7=$rrd:disk" . $e . "_hd7_smart1:AVERAGE",
				"CDEF:allvalues=rsc0,rsc1,rsc2,rsc3,rsc4,rsc5,rsc6,rsc7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /disk$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 1] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < 8; $n += 2) {
			if($d[$n]) {
				my $dstr = trim($d[$n]);
				$dstr =~ s/^\"//;
				$dstr =~ s/\"$//;

				# check if device name is a symbolic link
				# e.g. /dev/disk/by-path/pci-0000:07:07.0-scsi-0:0:0:0
				if(-l $dstr) {
					$dstr = abs_path(dirname($dstr) . "/" . readlink($dstr));
					chomp($dstr);
				}

				$dstr =~ s/^(.+?) .*$/$1/;
				$str = sprintf("%-17s", substr($dstr, 0, 17));
				push(@tmp, "LINE2:cps" . $n . $LC[$n] . ":$str");
				push(@tmpz, "LINE2:cps" . $n . $LC[$n] . ":$dstr\\g");
			}
			if($d[$n + 1]) {
				my $dstr = trim($d[$n + 1]);
				$dstr =~ s/^\"//;
				$dstr =~ s/\"$//;

				# check if device name is a symbolic link
				# e.g. /dev/disk/by-path/pci-0000:07:07.0-scsi-0:0:0:0
				if(-l $dstr) {
					$dstr = abs_path(dirname($dstr) . "/" . readlink($dstr));
					chomp($dstr);
				}

				$dstr =~ s/^(.+?) .*$/$1/;
				$str = sprintf("%-17s", substr($dstr, 0, 17));
				push(@tmp, "LINE2:cps" . ($n + 1) . $LC[$n + 1] . ":$str\\n");
				push(@tmpz, "LINE2:cps" . ($n + 1) . $LC[$n + 1] . ":$dstr\\g");
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
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 3 + 2]",
			"--title=$config->{graphs}->{_disk3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Sectors",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:cps0=$rrd:disk" . $e . "_hd0_smart2:AVERAGE",
			"DEF:cps1=$rrd:disk" . $e . "_hd1_smart2:AVERAGE",
			"DEF:cps2=$rrd:disk" . $e . "_hd2_smart2:AVERAGE",
			"DEF:cps3=$rrd:disk" . $e . "_hd3_smart2:AVERAGE",
			"DEF:cps4=$rrd:disk" . $e . "_hd4_smart2:AVERAGE",
			"DEF:cps5=$rrd:disk" . $e . "_hd5_smart2:AVERAGE",
			"DEF:cps6=$rrd:disk" . $e . "_hd6_smart2:AVERAGE",
			"DEF:cps7=$rrd:disk" . $e . "_hd7_smart2:AVERAGE",
			"CDEF:allvalues=cps0,cps1,cps2,cps3,cps4,cps5,cps6,cps7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 3 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 3 + 2]",
				"--title=$config->{graphs}->{_disk3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Sectors",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:cps0=$rrd:disk" . $e . "_hd0_smart2:AVERAGE",
				"DEF:cps1=$rrd:disk" . $e . "_hd1_smart2:AVERAGE",
				"DEF:cps2=$rrd:disk" . $e . "_hd2_smart2:AVERAGE",
				"DEF:cps3=$rrd:disk" . $e . "_hd3_smart2:AVERAGE",
				"DEF:cps4=$rrd:disk" . $e . "_hd4_smart2:AVERAGE",
				"DEF:cps5=$rrd:disk" . $e . "_hd5_smart2:AVERAGE",
				"DEF:cps6=$rrd:disk" . $e . "_hd6_smart2:AVERAGE",
				"DEF:cps7=$rrd:disk" . $e . "_hd7_smart2:AVERAGE",
				"CDEF:allvalues=cps0,cps1,cps2,cps3,cps4,cps5,cps6,cps7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 3 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /disk$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 3 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 3 + 2] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");

			if($disk->{desc}->{$k}) {
				push(@output, "    <tr>\n");
				push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
				push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
				push(@output, "       <font size='-1'>\n");
				push(@output, "        <b>&nbsp;&nbsp;$disk->{desc}->{$k}<b>\n");
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
