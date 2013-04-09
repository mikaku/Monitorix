#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2013 by Jordi Sanfeliu <jordi@fibranet.cat>
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

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
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
				"RRA:AVERAGE:0.5:1440:365",
				"RRA:MIN:0.5:1:1440",
				"RRA:MIN:0.5:30:336",
				"RRA:MIN:0.5:60:744",
				"RRA:MIN:0.5:1440:365",
				"RRA:MAX:0.5:1:1440",
				"RRA:MAX:0.5:30:336",
				"RRA:MAX:0.5:60:744",
				"RRA:MAX:0.5:1440:365",
				"RRA:LAST:0.5:1:1440",
				"RRA:LAST:0.5:30:336",
				"RRA:LAST:0.5:60:744",
				"RRA:LAST:0.5:1440:365",
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

	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
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
							}
						}
					}
				}
				if($lmsens->{list}->{$str} eq "ati") {
					$gpu[$n] = get_ati_data($n);
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

	my $lmsens = $config->{lmsens};
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};

	my $u = "";
	my $width;
	my $height;
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

	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	$title = !$silent ? $title : "";

	if(lc($config->{temperature_scale}) eq "f") {
		$temp_scale = "Fahrenheit";
	}


	# text mode
	#
	if(lc($config->{iface_mode}) eq "text") {
		if($title) {
			main::graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$colors->{title_bg_color}'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"AVERAGE",
			"-r $tf->{res}");
		$err = RRDs::error;
		print("ERROR: while fetching $rrd: $err\n") if $err;
		my $line1;
		my $line2;
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
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
		print("Time $line1\n");
		print("-----$line2\n");
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
			printf("$line1 \n", $time, @row);
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			main::graph_footer();
		}
		print("  <br>\n");
		return;
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

	my $PNG1 = $u . $package . "1." . $tf->{when} . ".png";
	my $PNG2 = $u . $package . "2." . $tf->{when} . ".png";
	my $PNG3 = $u . $package . "3." . $tf->{when} . ".png";
	my $PNG4 = $u . $package . "4." . $tf->{when} . ".png";
	my $PNG5 = $u . $package . "5." . $tf->{when} . ".png";
	my $PNG1z = $u . $package . "1z." . $tf->{when} . ".png";
	my $PNG2z = $u . $package . "2z." . $tf->{when} . ".png";
	my $PNG3z = $u . $package . "3z." . $tf->{when} . ".png";
	my $PNG4z = $u . $package . "4z." . $tf->{when} . ".png";
	my $PNG5z = $u . $package . "5z." . $tf->{when} . ".png";
	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3",
		"$PNG_DIR" . "$PNG4",
		"$PNG_DIR" . "$PNG5");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z",
			"$PNG_DIR" . "$PNG4z",
			"$PNG_DIR" . "$PNG5z");
	}

	if($title) {
		main::graph_header($title, 2);
	}
	for($n = 0; $n < 4; $n++) {
		for($n2 = $n; $n2 < 16; $n2 += 4) {
			$str = "core_" . $n2;
			if($lmsens->{list}->{$str}) {
				$str = sprintf("Core %2d", $n2);
				push(@tmp, "LINE2:core_$n2" . $LC[$n2] . ":$str\\g");
				push(@tmp, "GPRINT:core_$n2:LAST:\\:%3.0lf      ");
			}
		}
		push(@tmp, "COMMENT: \\n") unless !@tmp;
	}
	for($n = 0; $n < 16; $n++) {
		$str = "core" . $n;
		if($lmsens->{list}->{$str}) {
			$str = sprintf("Core %d", $n);
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
		print("    <tr>\n");
		print("    <td valign='bottom' bgcolor='$colors->{title_bg_color}'>\n");
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
	($width, $height) = split('x', $config->{graph_size}->{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$config->{graphs}->{_lmsens1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=$temp_scale",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
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
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$config->{graphs}->{_lmsens1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
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
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG1 . "'>\n");
		}
	}

	undef(@tmp);
	undef(@tmpz);
	$lmsens->{list}->{'volt0'} =~ s/\\// if $lmsens->{list}->{'volt0'};
	$str = $lmsens->{list}->{'volt0'} ? sprintf("%8s", substr($lmsens->{list}->{'volt0'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt0#FFA500:$str\\g", "GPRINT:volt0:LAST:\\:%6.2lf   "));
	$lmsens->{list}->{'volt3'} =~ s/\\// if $lmsens->{list}->{'volt3'};
	$str = $lmsens->{list}->{'volt3'} ? sprintf("%8s", substr($lmsens->{list}->{'volt3'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt3#4444EE:$str\\g", "GPRINT:volt3:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt6'} =~ s/\\// if $lmsens->{list}->{'volt6'};;
	$str = $lmsens->{list}->{'volt6'} ? sprintf("%8s", substr($lmsens->{list}->{'volt6'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt6#EE44EE:$str\\g", "GPRINT:volt6:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt9'} =~ s/\\// if $lmsens->{list}->{'volt9'};;
	$str = $lmsens->{list}->{'volt9'} ? sprintf("%8s", substr($lmsens->{list}->{'volt9'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt9#94C36B:$str\\g", "GPRINT:volt9:LAST:\\:%6.2lf\\g")) unless !$str;
	push(@tmp, "COMMENT: \\n");
	$lmsens->{list}->{'volt1'} =~ s/\\// if $lmsens->{list}->{'volt1'};;
	$str = $lmsens->{list}->{'volt1'} ? sprintf("%8s", substr($lmsens->{list}->{'volt1'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt1#44EEEE:$str\\g", "GPRINT:volt1:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt4'} =~ s/\\// if $lmsens->{list}->{'volt4'};;
	$str = $lmsens->{list}->{'volt4'} ? sprintf("%8s", substr($lmsens->{list}->{'volt4'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt4#448844:$str\\g", "GPRINT:volt4:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt7'} =~ s/\\// if $lmsens->{list}->{'volt7'};;
	$str = $lmsens->{list}->{'volt7'} ? sprintf("%8s", substr($lmsens->{list}->{'volt7'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt7#EEEE44:$str\\g", "GPRINT:volt7:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt10'} =~ s/\\// if $lmsens->{list}->{'volt10'};;
	$str = $lmsens->{list}->{'volt10'} ? sprintf("%8s", substr($lmsens->{list}->{'volt10'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt10#3CB5B0:$str\\g", "GPRINT:volt10:LAST:\\:%6.2lf\\g")) unless !$str;
	push(@tmp, "COMMENT: \\n");
	$lmsens->{list}->{'volt2'} =~ s/\\// if $lmsens->{list}->{'volt2'};;
	$str = $lmsens->{list}->{'volt2'} ? sprintf("%8s", substr($lmsens->{list}->{'volt2'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt2#44EE44:$str\\g", "GPRINT:volt2:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt5'} =~ s/\\// if $lmsens->{list}->{'volt5'};;
	$str = $lmsens->{list}->{'volt5'} ? sprintf("%8s", substr($lmsens->{list}->{'volt5'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt5#EE4444:$str\\g", "GPRINT:volt5:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt8'} =~ s/\\// if $lmsens->{list}->{'volt8'};;
	$str = $lmsens->{list}->{'volt8'} ? sprintf("%8s", substr($lmsens->{list}->{'volt8'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt8#963C74:$str\\g", "GPRINT:volt8:LAST:\\:%6.2lf   ")) unless !$str;
	$lmsens->{list}->{'volt11'} =~ s/\\// if $lmsens->{list}->{'volt11'};;
	$str = $lmsens->{list}->{'volt11'} ? sprintf("%8s", substr($lmsens->{list}->{'volt11'}, 0, 8)) : "";
	push(@tmp, ("LINE2:volt11#597AB7:$str\\g", "GPRINT:volt11:LAST:\\:%6.2lf\\g")) unless !$str;
	push(@tmp, "COMMENT: \\n");
	$str = $lmsens->{list}->{'volt0'} ? substr($lmsens->{list}->{'volt0'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt0#FFA500:$str");
	$str = $lmsens->{list}->{'volt1'} ? substr($lmsens->{list}->{'volt1'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt1#44EEEE:$str")unless !$str;
	$str = $lmsens->{list}->{'volt2'} ? substr($lmsens->{list}->{'volt2'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt2#44EE44:$str")unless !$str;
	$str = $lmsens->{list}->{'volt3'} ? substr($lmsens->{list}->{'volt3'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt3#4444EE:$str")unless !$str;
	$str = $lmsens->{list}->{'volt4'} ? substr($lmsens->{list}->{'volt4'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt4#448844:$str")unless !$str;
	$str = $lmsens->{list}->{'volt5'} ? substr($lmsens->{list}->{'volt5'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt5#EE4444:$str")unless !$str;
	$str = $lmsens->{list}->{'volt6'} ? substr($lmsens->{list}->{'volt6'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt6#EE44EE:$str")unless !$str;
	$str = $lmsens->{list}->{'volt7'} ? substr($lmsens->{list}->{'volt7'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt7#EEEE44:$str")unless !$str;
	$str = $lmsens->{list}->{'volt8'} ? substr($lmsens->{list}->{'volt8'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt8#963C74:$str")unless !$str;
	$str = $lmsens->{list}->{'volt9'} ? substr($lmsens->{list}->{'volt9'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt9#94C36B:$str")unless !$str;
	$str = $lmsens->{list}->{'volt10'} ? substr($lmsens->{list}->{'volt10'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt10#3CB5B0:$str")unless !$str;
	$str = $lmsens->{list}->{'volt11'} ? substr($lmsens->{list}->{'volt11'}, 0, 8) : "";
	push(@tmpz, "LINE2:volt11#597AB7:$str") unless !$str;
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
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$config->{graphs}->{_lmsens2}  ($tf->{nwhen}$tf->{twhen})
		",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Volts",
		"--width=$width",
		"--height=$height",
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
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$config->{graphs}->{_lmsens2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Volts",
			"--width=$width",
			"--height=$height",
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
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG2 . "'>\n");
		}
	}

	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	undef(@CDEF);
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, ("LINE2:mb_0#FFA500:MB 0\\g", "GPRINT:mb_0:LAST:\\:%3.0lf   "));
	push(@tmp, ("LINE2:cpu_0#4444EE:CPU 0\\g", "GPRINT:cpu_0:LAST:\\:%3.0lf   ")) unless !$lmsens->{list}->{'cpu0'};
	push(@tmp, ("LINE2:cpu_2#EE44EE:CPU 2\\g", "GPRINT:cpu_2:LAST:\\:%3.0lf\\g")) unless !$lmsens->{list}->{'cpu2'};
	push(@tmp, "COMMENT: \\n");
	push(@tmp, ("LINE2:mb_1#44EEEE:MB 1\\g", "GPRINT:mb_1:LAST:\\:%3.0lf   ")) unless !$lmsens->{list}->{'mb1'};
	push(@tmp, ("LINE2:cpu_1#EEEE44:CPU 1\\g", "GPRINT:cpu_1:LAST:\\:%3.0lf   ")) unless !$lmsens->{list}->{'cpu1'};
	push(@tmp, ("LINE2:cpu_3#44EE44:CPU 3\\g", "GPRINT:cpu_3:LAST:\\:%3.0lf\\g")) unless !$lmsens->{list}->{'cpu3'};
	push(@tmp, "COMMENT: \\n");
	push(@tmpz, "LINE2:mb_0#FFA500:MB 0");
	push(@tmpz, "LINE2:mb_1#44EEEE:MB 1") unless !$lmsens->{list}->{'mb1'};
	push(@tmpz, "LINE2:cpu_0#4444EE:CPU 0") unless !$lmsens->{list}->{'cpu0'};
	push(@tmpz, "LINE2:cpu_1#EEEE44:CPU 1") unless !$lmsens->{list}->{'cpu1'};
	push(@tmpz, "LINE2:cpu_2#EE44EE:CPU 2") unless !$lmsens->{list}->{'cpu2'};
	push(@tmpz, "LINE2:cpu_3#44EE44:CPU 3") unless !$lmsens->{list}->{'cpu3'};
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
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$config->{graphs}->{_lmsens3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=$temp_scale",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:mb0=$rrd:lmsens_mb0:AVERAGE",
		"DEF:mb1=$rrd:lmsens_mb1:AVERAGE",
		"DEF:cpu0=$rrd:lmsens_cpu0:AVERAGE",
		"DEF:cpu1=$rrd:lmsens_cpu1:AVERAGE",
		"DEF:cpu2=$rrd:lmsens_cpu2:AVERAGE",
		"DEF:cpu3=$rrd:lmsens_cpu3:AVERAGE",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$config->{graphs}->{_lmsens3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:mb0=$rrd:lmsens_mb0:AVERAGE",
			"DEF:mb1=$rrd:lmsens_mb1:AVERAGE",
			"DEF:cpu0=$rrd:lmsens_cpu0:AVERAGE",
			"DEF:cpu1=$rrd:lmsens_cpu1:AVERAGE",
			"DEF:cpu2=$rrd:lmsens_cpu2:AVERAGE",
			"DEF:cpu3=$rrd:lmsens_cpu3:AVERAGE",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens3/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG3 . "'>\n");
		}
	}

	undef(@tmp);
	undef(@tmpz);
	push(@tmp, ("LINE2:fan0#FFA500:Fan 0\\g", "GPRINT:fan0:LAST:\\:%5.0lf"));
	push(@tmp, ("LINE2:fan3#4444EE:Fan 3\\g", "GPRINT:fan3:LAST:\\:%5.0lf")) unless !$lmsens->{list}->{'fan3'};
	push(@tmp, ("LINE2:fan6#EE44EE:Fan 6\\g", "GPRINT:fan6:LAST:\\:%5.0lf\\g")) unless !$lmsens->{list}->{'fan6'};
	push(@tmp, "COMMENT: \\n");
	push(@tmp, ("LINE2:fan1#44EEEE:Fan 1\\g", "GPRINT:fan1:LAST:\\:%5.0lf")) unless !$lmsens->{list}->{'fan1'};
	push(@tmp, ("LINE2:fan4#448844:Fan 4\\g", "GPRINT:fan4:LAST:\\:%5.0lf")) unless !$lmsens->{list}->{'fan4'};
	push(@tmp, ("LINE2:fan7#EEEE44:Fan 7\\g", "GPRINT:fan7:LAST:\\:%5.0lf\\g")) unless !$lmsens->{list}->{'fan7'};
	push(@tmp, "COMMENT: \\n");
	push(@tmp, ("LINE2:fan2#44EE44:Fan 2\\g", "GPRINT:fan2:LAST:\\:%5.0lf")) unless !$lmsens->{list}->{'fan2'};
	push(@tmp, ("LINE2:fan5#EE4444:Fan 5\\g", "GPRINT:fan5:LAST:\\:%5.0lf")) unless !$lmsens->{list}->{'fan5'};
	push(@tmp, ("LINE2:fan8#963C74:Fan 8\\g", "GPRINT:fan8:LAST:\\:%5.0lf\\g")) unless !$lmsens->{list}->{'fan8'};
	push(@tmp, "COMMENT: \\n");
	push(@tmpz, "LINE2:fan0#FFA500:Fan 0");
	push(@tmpz, "LINE2:fan1#44EEEE:Fan 1") unless !$lmsens->{list}->{'fan1'};
	push(@tmpz, "LINE2:fan2#44EE44:Fan 2") unless !$lmsens->{list}->{'fan2'};
	push(@tmpz, "LINE2:fan3#4444EE:Fan 3") unless !$lmsens->{list}->{'fan3'};
	push(@tmpz, "LINE2:fan4#448844:Fan 4") unless !$lmsens->{list}->{'fan4'};
	push(@tmpz, "LINE2:fan5#EE4444:Fan 5") unless !$lmsens->{list}->{'fan5'};
	push(@tmpz, "LINE2:fan6#EE44EE:Fan 6") unless !$lmsens->{list}->{'fan6'};
	push(@tmpz, "LINE2:fan7#EEEE44:Fan 7") unless !$lmsens->{list}->{'fan7'};
	push(@tmpz, "LINE2:fan8#963C74:Fan 8") unless !$lmsens->{list}->{'fan8'};
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG4",
		"--title=$config->{graphs}->{_lmsens4}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=RPM",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
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
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG4: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG4z",
			"--title=$config->{graphs}->{_lmsens4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=RPM",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
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
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG4z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens4/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG4z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG4 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG4z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG4 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG4 . "'>\n");
		}
	}

	undef(@CDEF);
	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "LINE2:gpu_0#FFA500:GPU 0\\g");
	push(@tmp, "GPRINT:gpu_0:LAST:\\:%3.0lf  ");
	push(@tmp, ("LINE2:gpu_3#4444EE:GPU 3\\g", "GPRINT:gpu_3:LAST:\\:%3.0lf  ")) unless !$lmsens->{list}->{'gpu3'};
	push(@tmp, ("LINE2:gpu_6#EE44EE:GPU 6\\g", "GPRINT:gpu_6:LAST:\\:%3.0lf\\g")) unless !$lmsens->{list}->{'gpu6'};
	push(@tmp, "COMMENT: \\n");
	push(@tmp, ("LINE2:gpu_1#44EEEE:GPU 1\\g", "GPRINT:gpu_1:LAST:\\:%3.0lf  ")) unless !$lmsens->{list}->{'gpu1'};
	push(@tmp, ("LINE2:gpu_4#448844:GPU 4\\g", "GPRINT:gpu_4:LAST:\\:%3.0lf  ")) unless !$lmsens->{list}->{'gpu4'};
	push(@tmp, ("LINE2:gpu_7#EEEE44:GPU 7\\g", "GPRINT:gpu_7:LAST:\\:%3.0lf\\g")) unless !$lmsens->{list}->{'gpu7'};
	push(@tmp, "COMMENT: \\n");
	push(@tmp, ("LINE2:gpu_2#44EE44:GPU 2\\g", "GPRINT:gpu_2:LAST:\\:%3.0lf  ")) unless !$lmsens->{list}->{'gpu2'};
	push(@tmp, ("LINE2:gpu_5#EE4444:GPU 5\\g", "GPRINT:gpu_5:LAST:\\:%3.0lf  ")) unless !$lmsens->{list}->{'gpu5'};
	push(@tmp, ("LINE2:gpu_8#963C74:GPU 8\\g", "GPRINT:gpu_8:LAST:\\:%3.0lf\\g")) unless !$lmsens->{list}->{'gpu8'};
	push(@tmp, "COMMENT: \\n");
	push(@tmpz, "LINE2:gpu_0#FFA500:GPU 0\\g");
	push(@tmpz, "LINE2:gpu_1#44EEEE:GPU 1\\g") unless !$lmsens->{list}->{'gpu1'};
	push(@tmpz, "LINE2:gpu_2#44EE44:GPU 2\\g") unless !$lmsens->{list}->{'gpu2'};
	push(@tmpz, "LINE2:gpu_3#4444EE:GPU 3\\g") unless !$lmsens->{list}->{'gpu3'};
	push(@tmpz, "LINE2:gpu_4#448844:GPU 4\\g") unless !$lmsens->{list}->{'gpu4'};
	push(@tmpz, "LINE2:gpu_5#EE4444:GPU 5\\g") unless !$lmsens->{list}->{'gpu5'};
	push(@tmpz, "LINE2:gpu_6#EE44EE:GPU 6\\g") unless !$lmsens->{list}->{'gpu6'};
	push(@tmpz, "LINE2:gpu_7#EEEE44:GPU 7\\g") unless !$lmsens->{list}->{'gpu7'};
	push(@tmpz, "LINE2:gpu_8#963C74:GPU 8\\g") unless !$lmsens->{list}->{'gpu8'};
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
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG5",
		"--title=$config->{graphs}->{_lmsens5}  ($tf->{nwhen}$tf->{twhen})
		",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=$temp_scale",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
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
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG5: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG5z",
			"--title=$config->{graphs}->{_lmsens5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$temp_scale",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
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
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG5z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /lmsens5/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNG5z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG5 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNG5z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG5 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG5 . "'>\n");
		}
	}


	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		main::graph_footer();
	}
	print("  <br>\n");
	return;
}

1;
