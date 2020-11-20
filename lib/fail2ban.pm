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

package fail2ban;

use strict;
use warnings;
use Monitorix;
use RRDs;
use POSIX qw(strftime);
use Exporter 'import';
our @EXPORT = qw(fail2ban_init fail2ban_update fail2ban_cgi);

sub fail2ban_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $fail2ban = $config->{fail2ban};

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
		if(scalar(@ds) / 9 != scalar(my @fl = split(',', $fail2ban->{list}))) {
			logger("$myself: Detected size mismatch between 'list' (" . scalar(my @fl = split(',', $fail2ban->{list})) . ") and $rrd (" . scalar(@ds) / 9 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < scalar(my @fl = split(',', $fail2ban->{list})); $n++) {
			push(@tmp, "DS:fail2ban" . $n . "_j1:GAUGE:120:0:U");
			push(@tmp, "DS:fail2ban" . $n . "_j2:GAUGE:120:0:U");
			push(@tmp, "DS:fail2ban" . $n . "_j3:GAUGE:120:0:U");
			push(@tmp, "DS:fail2ban" . $n . "_j4:GAUGE:120:0:U");
			push(@tmp, "DS:fail2ban" . $n . "_j5:GAUGE:120:0:U");
			push(@tmp, "DS:fail2ban" . $n . "_j6:GAUGE:120:0:U");
			push(@tmp, "DS:fail2ban" . $n . "_j7:GAUGE:120:0:U");
			push(@tmp, "DS:fail2ban" . $n . "_j8:GAUGE:120:0:U");
			push(@tmp, "DS:fail2ban" . $n . "_j9:GAUGE:120:0:U");
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

	$config->{fail2ban_hist} = 0;
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub fail2ban_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $fail2ban = $config->{fail2ban};

	my $seek_pos;
	my $logsize;
	my @jails;

	my $n;
	my $str;
	my $rrdata = "N";

	if(lc($fail2ban->{graph_mode} || "") ne "rate") {
		my $e = 0;
		while($e < scalar(my @fl = split(',', $fail2ban->{list}))) {
			my $e2 = 0;
			foreach my $i (split(',', $fail2ban->{desc}->{$e})) {
				($str = trim($i)) =~ s/\[//;
				$str =~ s/\]//;
				$jails[$e][$e2] = 0 unless defined $jails[$e][$e2];
				if(open(IN, "fail2ban-client status $str |")) {
					while(<IN>) {
						if(/- Currently banned:\s+(\d+)$/) {
							$jails[$e][$e2] = $1;
						}
					}
					close(IN);
				}
				$e2++;
			}
			$e++;
		}
	} else {
		if(! -r $config->{fail2ban_log}) {
			logger("Couldn't find file '$config->{fail2ban_log}': $!");
			return;
		}

		$seek_pos = $config->{fail2ban_hist} || 0;
		$seek_pos = defined($seek_pos) ? int($seek_pos) : 0;
		open(IN, $config->{fail2ban_log});
		if(!seek(IN, 0, 2)) {
			logger("Couldn't seek to the end of '$config->{fail2ban_log}': $!");
			return;
		}
		$logsize = tell(IN);
		if($logsize < $seek_pos) {
			$seek_pos = 0;
		}
		if(!seek(IN, $seek_pos, 0)) {
			logger("Couldn't seek to $seek_pos in '$config->{fail2ban_log}': $!");
			return;
		}
		if($config->{fail2ban_hist} > 0) {	# avoids initial peak
			my $date = strftime("%Y-%m-%d", localtime);
			while(<IN>) {
				if(/^$date/) {
					my $e = 0;
					while($e < scalar(my @fl = split(',', $fail2ban->{list}))) {
						my $e2 = 0;
						foreach my $i (split(',', $fail2ban->{desc}->{$e})) {
							($str = trim($i)) =~ s/\[/\\[/;
							$str =~ s/\]/\\]/;
							$jails[$e][$e2] = 0 unless defined $jails[$e][$e2];
							if(/ $str Ban /) {
								$jails[$e][$e2]++;
							}
							$e2++;
						}
						$e++;
					}
				}
			}
		}
		close(IN);
	}

	my $e = 0;
	while($e < scalar(my @fl = split(',', $fail2ban->{list}))) {
		for($n = 0; $n < 9; $n++) {
			$jails[$e][$n] = 0 unless defined $jails[$e][$n];
			$rrdata .= ":" . $jails[$e][$n];
		}
		$e++;
	}

	$config->{fail2ban_hist} = $logsize;

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub fail2ban_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $fail2ban = $config->{fail2ban};
	my @rigid = split(',', ($fail2ban->{rigid} || ""));
	my @limit = split(',', ($fail2ban->{limit} || ""));
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
	my $vlabel = "Bans";
	my $n;
	my $n2;
	my $str;
	my $err;
	my @LC = (
		"#4444EE",
		"#EEEE44",
		"#44EEEE",
		"#EE44EE",
		"#888888",
		"#E29136",
		"#44EE44",
		"#448844",
		"#EE4444",
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
	if(lc($fail2ban->{graph_mode} || "") eq "rate") {
		$vlabel = "Bans/min";
	}

	$title = !$silent ? $title : "";


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
		push(@output, "    ");
		for($n = 0; $n < scalar(my @fl = split(',', $fail2ban->{list})); $n++) {
			$line1 = "";
			foreach my $i (split(',', $fail2ban->{desc}->{$n})) {
				$str = sprintf("%20s", substr(trim($i), 0, 20));
				$line1 .= "                     ";
				$line2 .= sprintf(" %20s", $str);
				$line3 .= "---------------------";
			}
			if($line1) {
				my $i = length($line1);
				push(@output, sprintf(sprintf("%${i}s", sprintf("%s", trim($fl[$n])))));
			}
		}
		push(@output, "\n");
		push(@output, "Time$line2\n");
		push(@output, "----$line3 \n");
		my $line;
		my @row;
		my $time;
		my $n2;
		my $n3;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc} ", $time));
			for($n2 = 0; $n2 < scalar(my @fl = split(',', $fail2ban->{list})); $n2++) {
				$n3 = 0;
				foreach my $i (split(',', $fail2ban->{desc}->{$n2})) {
					$from = $n2 * 9 + $n3++;
					$to = $from + 1;
					my ($j) = @$line[$from..$to];
					@row = ($j);
					push(@output, sprintf("%20d ", @row));
				}
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

	for($n = 0; $n < scalar(my @fl = split(',', $fail2ban->{list})); $n++) {
		$str = $u . $package . $n . "." . $tf->{when} . ".$imgfmt_lc";
		push(@IMG, $str);
		unlink("$IMG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . $package . $n . "z." . $tf->{when} . ".$imgfmt_lc";
			push(@IMGz, $str);
			unlink("$IMG_DIR" . $str);
		}
	}

	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	$n = 0;
	while($n < scalar(my @fl = split(',', $fail2ban->{list}))) {
		if($title) {
			if($n == 0) {
				push(@output, main::graph_header($title, $fail2ban->{graphs_per_row}));
			}
			push(@output, "    <tr>\n");
		}
		for($n2 = 0; $n2 < $fail2ban->{graphs_per_row}; $n2++) {
			last unless $n < scalar(my @fl = split(',', $fail2ban->{list}));
			if($title) {
				push(@output, "    <td>\n");
			}
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			my $e = 0;
			foreach my $i (split(',', $fail2ban->{desc}->{$n})) {
				$str = sprintf("%-25s", substr(trim($i), 0, 25));
				push(@tmp, "LINE2:j" . ($e + 1) . $LC[$e] . ":$str");
				push(@tmp, "GPRINT:j" . ($e + 1) . ":LAST:Cur\\:%4.0lf\\g");
				push(@tmp, "GPRINT:j" . ($e + 1) . ":AVERAGE:    Avg\\:%4.0lf\\g");
				push(@tmp, "GPRINT:j" . ($e + 1) . ":MAX:    Max\\:%4.0lf\\n");
				push(@tmpz, "LINE2:j" . ($e + 1) . $LC[$e] . ":$str");
				$e++;
			}
			while($e < 9) {
				push(@tmp, "COMMENT: \\n");
				$e++;
			}
			if(lc($config->{show_gaps}) eq "y") {
				push(@tmp, "AREA:wrongdata#$colors->{gap}:");
				push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
				push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
			}
			($width, $height) = split('x', $config->{graph_size}->{medium});
			$str = substr(trim($fl[$n]), 0, 25);
			$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$n]",
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
				"DEF:j1=$rrd:fail2ban" . $n . "_j1:AVERAGE",
				"DEF:j2=$rrd:fail2ban" . $n . "_j2:AVERAGE",
				"DEF:j3=$rrd:fail2ban" . $n . "_j3:AVERAGE",
				"DEF:j4=$rrd:fail2ban" . $n . "_j4:AVERAGE",
				"DEF:j5=$rrd:fail2ban" . $n . "_j5:AVERAGE",
				"DEF:j6=$rrd:fail2ban" . $n . "_j6:AVERAGE",
				"DEF:j7=$rrd:fail2ban" . $n . "_j7:AVERAGE",
				"DEF:j8=$rrd:fail2ban" . $n . "_j8:AVERAGE",
				"DEF:j9=$rrd:fail2ban" . $n . "_j9:AVERAGE",
				"CDEF:allvalues=j1,j2,j3,j4,j5,j6,j7,j8,j9,+,+,+,+,+,+,+,+",
				@CDEF,
				@tmp);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$n]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$n]",
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
					"DEF:j1=$rrd:fail2ban" . $n . "_j1:AVERAGE",
					"DEF:j2=$rrd:fail2ban" . $n . "_j2:AVERAGE",
					"DEF:j3=$rrd:fail2ban" . $n . "_j3:AVERAGE",
					"DEF:j4=$rrd:fail2ban" . $n . "_j4:AVERAGE",
					"DEF:j5=$rrd:fail2ban" . $n . "_j5:AVERAGE",
					"DEF:j6=$rrd:fail2ban" . $n . "_j6:AVERAGE",
					"DEF:j7=$rrd:fail2ban" . $n . "_j7:AVERAGE",
					"DEF:j8=$rrd:fail2ban" . $n . "_j8:AVERAGE",
					"DEF:j9=$rrd:fail2ban" . $n . "_j9:AVERAGE",
					"CDEF:allvalues=j1,j2,j3,j4,j5,j6,j7,j8,j9,+,+,+,+,+,+,+,+",
					@CDEF,
					@tmpz);
				$err = RRDs::error;
				push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$n]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /fail2ban$n/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$n] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$n] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n] . "' border='0'></a>\n");
					}
				} else {
					push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$n] . "'>\n");
				}
			}
			if($title) {
				push(@output, "    </td>\n");
			}
			$n++;
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
