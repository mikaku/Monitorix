#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2015 by Jordi Sanfeliu <jordi@fibranet.cat>
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
	my @riglim;
	my @PNG;
	my @PNGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
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
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	$title = !$silent ? $title : "";


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
		my $line3;
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		print("    ");
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
				printf(sprintf("%${i}s", sprintf("%s", trim($fl[$n]))));
			}
		}
		print("\n");
		print("Time$line2\n");
		print("----$line3 \n");
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
			printf(" %2d$tf->{tc} ", $time);
			for($n2 = 0; $n2 < scalar(my @fl = split(',', $fail2ban->{list})); $n2++) {
				$n3 = 0;
				foreach my $i (split(',', $fail2ban->{desc}->{$n2})) {
					$from = $n2 * 9 + $n3++;
					$to = $from + 1;
					my ($j) = @$line[$from..$to];
					@row = ($j);
					printf("%20d ", @row);
				}
			}
			print("\n");
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

	for($n = 0; $n < scalar(my @fl = split(',', $fail2ban->{list})); $n++) {
		$str = $u . $package . $n . "." . $tf->{when} . ".png";
		push(@PNG, $str);
		unlink("$PNG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . $package . $n . "z." . $tf->{when} . ".png";
			push(@PNGz, $str);
			unlink("$PNG_DIR" . $str);
		}
	}

	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	$n = 0;
	while($n < scalar(my @fl = split(',', $fail2ban->{list}))) {
		if($title) {
			if($n == 0) {
				main::graph_header($title, $fail2ban->{graphs_per_row});
			}
			print("    <tr>\n");
		}
		for($n2 = 0; $n2 < $fail2ban->{graphs_per_row}; $n2++) {
			last unless $n < scalar(my @fl = split(',', $fail2ban->{list}));
			if($title) {
				print("    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
			}
			undef(@tmp);
			undef(@tmpz);
			undef(@CDEF);
			my $e = 0;
			foreach my $i (split(',', $fail2ban->{desc}->{$n})) {
				$str = sprintf("%-25s", substr(trim($i), 0, 25));
				push(@tmp, "LINE1:j" . ($e + 1) . $LC[$e] . ":$str");
				push(@tmp, "GPRINT:j" . ($e + 1) . ":LAST: Cur\\:%2.0lf\\g");
				push(@tmp, "GPRINT:j" . ($e + 1) . ":AVERAGE:   Avg\\:%2.0lf\\g");
				push(@tmp, "GPRINT:j" . ($e + 1) . ":MIN:   Min\\:%2.0lf\\g");
				push(@tmp, "GPRINT:j" . ($e + 1) . ":MAX:   Max\\:%2.0lf\\n");
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
			$pic = $rrd{$version}->("$PNG_DIR" . "$PNG[$n]",
				"--title=$str  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=PNG",
				"--vertical-label=bans/s",
				"--width=$width",
				"--height=$height",
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
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
			print("ERROR: while graphing $PNG_DIR" . "$PNG[$n]: $err\n") if $err;
			if(lc($config->{enable_zoom}) eq "y") {
				($width, $height) = split('x', $config->{graph_size}->{zoom});
				$picz = $rrd{$version}->("$PNG_DIR" . "$PNGz[$n]",
					"--title=$str  ($tf->{nwhen}$tf->{twhen})",
					"--start=-$tf->{nwhen}$tf->{twhen}",
					"--imgformat=PNG",
					"--vertical-label=bans/s",
					"--width=$width",
					"--height=$height",
					@riglim,
					$zoom,
					@{$cgi->{version12}},
					@{$cgi->{version12_small}},
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
				print("ERROR: while graphing $PNG_DIR" . "$PNGz[$n]: $err\n") if $err;
			}
			if($title || ($silent =~ /imagetag/ && $graph =~ /fail2ban$n/)) {
				if(lc($config->{enable_zoom}) eq "y") {
					if(lc($config->{disable_javascript_void}) eq "y") {
						print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $PNGz[$n] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$n] . "' border='0'></a>\n");
					} else {
						if($version eq "new") {
							$picz_width = $picz->{image_width} * $config->{global_zoom};
							$picz_height = $picz->{image_height} * $config->{global_zoom};
						} else {
							$picz_width = $width + 115;
							$picz_height = $height + 100;
						}
						print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $PNGz[$n] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$n] . "' border='0'></a>\n");
					}
				} else {
					print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $PNG[$n] . "'>\n");
				}
			}
			if($title) {
				print("    </td>\n");
			}
			$n++;
		}
		if($title) {
			print("    </tr>\n");
		}
	}
	if($title) {
		main::graph_footer();
	}
	print("  <br>\n");
	return;
}

1;
