#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2016 by Jordi Sanfeliu <jordi@fibranet.cat>
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

package zfs;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(zfs_init zfs_update zfs_cgi);

sub zfs_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $zfs = $config->{zfs};

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
		if((scalar(@ds) - 22) / 10 != $zfs->{max_pools}) {
			logger("$myself: Detected size mismatch between 'max = $zfs->{max_pools}' and $rrd (" . (scalar(@ds) - 22) / 10 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < $zfs->{max_pools}; $n++) {
			push(@tmp, "DS:zfs" . $n . "_free:GAUGE:120:0:U");
			push(@tmp, "DS:zfs" . $n . "_udata:GAUGE:120:0:U");
			push(@tmp, "DS:zfs" . $n . "_usnap:GAUGE:120:0:U");
			push(@tmp, "DS:zfs" . $n . "_cap:GAUGE:120:0:100");
			push(@tmp, "DS:zfs" . $n . "_fra:GAUGE:120:0:100");
			push(@tmp, "DS:zfs" . $n . "_val1:GAUGE:120:0:U");
			push(@tmp, "DS:zfs" . $n . "_val2:GAUGE:120:0:U");
			push(@tmp, "DS:zfs" . $n . "_val3:GAUGE:120:0:U");
			push(@tmp, "DS:zfs" . $n . "_val4:GAUGE:120:0:U");
			push(@tmp, "DS:zfs" . $n . "_val5:GAUGE:120:0:U");
		}
		eval {
			RRDs::create($rrd,
				"--step=60",
				"DS:zfs_arcsize:GAUGE:120:0:U",
				"DS:zfs_cmax:GAUGE:120:0:U",
				"DS:zfs_cmin:GAUGE:120:0:U",
				"DS:zfs_arctgtsize:GAUGE:120:0:U",
				"DS:zfs_metalimit:GAUGE:120:0:U",
				"DS:zfs_metaused:GAUGE:120:0:U",
				"DS:zfs_metamax:GAUGE:120:0:U",
				"DS:zfs_arc_hits:GAUGE:120:0:U",
				"DS:zfs_arc_misses:GAUGE:120:0:U",
				"DS:zfs_arc_deleted:GAUGE:120:0:U",
				"DS:zfs_l2arc_hits:GAUGE:120:0:U",
				"DS:zfs_l2arc_misses:GAUGE:120:0:U",
				"DS:zfs_val01:GAUGE:120:0:U",
				"DS:zfs_val02:GAUGE:120:0:U",
				"DS:zfs_val03:GAUGE:120:0:U",
				"DS:zfs_val04:GAUGE:120:0:U",
				"DS:zfs_val05:GAUGE:120:0:U",
				"DS:zfs_val06:GAUGE:120:0:U",
				"DS:zfs_val07:GAUGE:120:0:U",
				"DS:zfs_val08:GAUGE:120:0:U",
				"DS:zfs_val09:GAUGE:120:0:U",
				"DS:zfs_val10:GAUGE:120:0:U",
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

	$config->{zfs_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub zfs_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $zfs = $config->{zfs};

	my $arcsize = 0;
	my $cmax = 0;
	my $cmin = 0;
	my $arctgtsize = 0;
	my $metalimit = 0;
	my $metaused = 0;
	my $metamax = 0;
	my $archits = 0;
	my $arcmisses = 0;
	my $arcdeleted = 0;
	my $l2arc_hits = 0;
	my $l2arc_misses = 0;
	my $val01 = 0;
	my $val02 = 0;
	my $val03 = 0;
	my $val04 = 0;
	my $val05 = 0;
	my $val06 = 0;
	my $val07 = 0;
	my $val08 = 0;
	my $val09 = 0;
	my $val10 = 0;

	my $n;
	my $rrdata = "N";

	if(open(IN, "/proc/spl/kstat/zfs/arcstats")) {
		while(<IN>) {
			if(/^size\s+\d+\s+(\d+)$/) {
				$arcsize = $1;
			}
			if(/^c_max\s+\d+\s+(\d+)$/) {
				$cmax = $1;
			}
			if(/^c_min\s+\d+\s+(\d+)$/) {
				$cmin = $1;
			}
			if(/^c\s+\d+\s+(\d+)$/) {
				$arctgtsize = $1;
			}
			if(/^arc_meta_limit\s+\d+\s+(\d+)$/) {
				$metalimit = $1;
			}
			if(/^arc_meta_used\s+\d+\s+(\d+)$/) {
				$metaused = $1;
			}
			if(/^arc_meta_max\s+\d+\s+(\d+)$/) {
				$metamax = $1;
			}
			if(/^hits\s+\d+\s+(\d+)$/) {
				$archits = $1 - ($config->{zfs_hist}->{archits} || 0);
				$archits = 0 unless $archits != $1;
				$archits /= 60;
				$config->{zfs_hist}->{archits} = $1;
			}
			if(/^misses\s+\d+\s+(\d+)$/) {
				$arcmisses = $1 - ($config->{zfs_hist}->{arcmisses} || 0);
				$arcmisses = 0 unless $arcmisses != $1;
				$arcmisses /= 60;
				$config->{zfs_hist}->{arcmisses} = $1;
			}
			if(/^deleted\s+\d+\s+(\d+)$/) {
				$arcdeleted = $1 - ($config->{zfs_hist}->{arcdeleted} || 0);
				$arcdeleted = 0 unless $arcdeleted != $1;
				$arcdeleted /= 60;
				$config->{zfs_hist}->{arcdeleted} = $1;
			}
			if(/^l2_hits\s+\d+\s+(\d+)$/) {
				$l2arc_hits = $1 - ($config->{zfs_hist}->{l2arc_hits} || 0);
				$l2arc_hits = 0 unless $l2arc_hits != $1;
				$l2arc_hits /= 60;
				$config->{zfs_hist}->{l2arc_hits} = $1;
			}
			if(/^l2_misses\s+\d+\s+(\d+)$/) {
				$l2arc_misses = $1 - ($config->{zfs_hist}->{l2arc_misses} || 0);
				$l2arc_misses = 0 unless $l2arc_misses != $1;
				$l2arc_misses /= 60;
				$config->{zfs_hist}->{l2arc_misses} = $1;
			}
		}
		close(IN);
	}

	$rrdata .= ":$arcsize:$cmax:$cmin:$arctgtsize:$metalimit:$metaused:$metamax:$archits:$arcmisses:$arcdeleted:$l2arc_hits:$l2arc_misses:0:0:0:0:0:0:0:0:0:0";

	for($n = 0; $n < $zfs->{max_pools}; $n++) {
		my $free = 0;
		my $udata = 0;
		my $usnap = 0;
		my $cap = 0;
		my $fra = 0;
		my $val1 = 0;
		my $val2 = 0;
		my $val3 = 0;
		my $val4 = 0;
		my $val5 = 0;

		my $pool = (split(',', $zfs->{list}))[$n] || "";
		if($pool) {
			my @zpool;

			$free = trim(`zfs get -rHp -o value available $pool`);
			$udata = trim(`zfs get -rHp -o value used $pool`);
			$usnap = trim(`zfs get -rHp -o value usedbysnapshots $pool`);
			@zpool = split(' ', `zpool list -H $pool` || "");

			if(scalar(@zpool) == 10) {	# ZFS version 0.6.4+
				$cap = trim($zpool[6]);
				$fra = trim($zpool[5]);
			} elsif(scalar(@zpool) == 8) {	# ZFS version 0.6.3- (?)
				$cap = trim($zpool[4]);
				$fra = 0;
			}
			$cap =~ s/%//;
			$fra =~ s/%//;
		}

		$rrdata .= ":$free:$udata:$usnap:$cap:$fra:0:0:0:0:0";
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub zfs_cgi {
	my ($package, $config, $cgi) = @_;

	my $zfs = $config->{zfs};
	my @rigid = split(',', ($zfs->{rigid} || ""));
	my @limit = split(',', ($zfs->{limit} || ""));
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
	my @IMG;
	my @IMGz;
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $e;
	my $n;
	my $str;
	my $err;

	$version = "old" if $RRDs::VERSION < 1.3;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $IMG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};
	my $imgfmt_uc = uc($config->{image_format});
	my $imgfmt_lc = lc($config->{image_format});

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
		my $line0;
		my $line1;
		my $n2;
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		print("    ");
		$line0 = "     ARC size       C-Max       C-Min  Targt size  Meta limit   Meta used    Meta max    ARC hits  ARC misses  ARC delete  L2ARC hits  L2ARC miss";
		$line1 = "-------------------------------------------------------------------------------------------------------------------------------------------------";
		for($n = 0; $n < scalar(my @zpl = split(',', $zfs->{list})); $n++) {
			my $p = trim($zpl[$n]);
			my $i = length($line0);
			$line0 .= "  Space free   Used Data   Used Snap  Cap  Fra";
			$line1 .= "----------------------------------------------";
			$i = length($line0) if(!$n);
			$i = length($line0) - $i if($n);
			printf(sprintf("%${i}s", sprintf("Pool: %s", $p)));
		}
		print("\n");
		print("Time$line0\n");
		print("----$line1 \n");
		my $line;
		my @row;
		my $time;
		my $from;
		my $to;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			$time = $time - (1 / $tf->{ts});
			@row = @$line[0..12];
			printf(" %2d$tf->{tc}   %10d  %10d  %10d  %10d  %10d  %10d  %10d  %10d  %10d  %10d  %10d  %10d", $time, @row);
			for($n2 = 0; $n2 < scalar(my @zpl = split(',', $zfs->{list})); $n2++) {
				$from = 22;
				$from += $n2 * 10;
				$to = $from + 5;
				@row = @$line[$from..$to];
				printf("  %10d  %10d  %10d %3d%% %3d%%", @row);
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

	my $IMG1 = $u . $package . "1." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2 = $u . $package . "2." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3 = $u . $package . "3." . $tf->{when} . ".$imgfmt_lc";
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
			"$IMG_DIR" . "$IMG2z",
			"$IMG_DIR" . "$IMG3z");
	}
	for($n = 0; $n < scalar(my @pl = split(',', $zfs->{list})); $n++) {
		$str = $u . $package . ($n + 4) . "1." . $tf->{when} . ".$imgfmt_lc";
		push(@IMG, $str);
		unlink("$IMG_DIR" . $str);
		$str = $u . $package . ($n + 4) . "2." . $tf->{when} . ".$imgfmt_lc";
		push(@IMG, $str);
		unlink("$IMG_DIR" . $str);
		if(lc($config->{enable_zoom}) eq "y") {
			$str = $u . $package . ($n + 4) . "1z." . $tf->{when} . ".$imgfmt_lc";
			push(@IMGz, $str);
			unlink("$IMG_DIR" . $str);
			$str = $u . $package . ($n + 4) . "2z." . $tf->{when} . ".$imgfmt_lc";
			push(@IMGz, $str);
			unlink("$IMG_DIR" . $str);
		}
	}

	if($title) {
		main::graph_header($title, 2);
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$colors->{title_bg_color}'>\n");
	}
	push(@tmp, "LINE2:arcsize#44EE44:ARC size");
	push(@tmp, "GPRINT:arcsize:LAST:          Cur\\: %5.1lf%s");
	push(@tmp, "GPRINT:arcsize:AVERAGE:   Avg\\: %5.1lf%s");
	push(@tmp, "GPRINT:arcsize:MIN:   Min\\: %5.1lf%s");
	push(@tmp, "GPRINT:arcsize:MAX:   Max\\: %5.1lf%s\\n");
	push(@tmpz, "LINE2:arcsize#44EE44:ARC size");
	push(@tmp, "LINE2:cmax#EE4444:Maximum ARC size");
	push(@tmp, "GPRINT:cmax:LAST:  Cur\\: %5.1lf%s");
	push(@tmp, "GPRINT:cmax:AVERAGE:   Avg\\: %5.1lf%s");
	push(@tmp, "GPRINT:cmax:MIN:   Min\\: %5.1lf%s");
	push(@tmp, "GPRINT:cmax:MAX:   Max\\: %5.1lf%s\\n");
	push(@tmpz, "LINE2:cmax#EE4444:Maximum ARC size");
	push(@tmp, "LINE2:cmin#EE4444:Minimum ARC size");
	push(@tmp, "GPRINT:cmin:LAST:  Cur\\: %5.1lf%s");
	push(@tmp, "GPRINT:cmin:AVERAGE:   Avg\\: %5.1lf%s");
	push(@tmp, "GPRINT:cmin:MIN:   Min\\: %5.1lf%s");
	push(@tmp, "GPRINT:cmin:MAX:   Max\\: %5.1lf%s\\n");
	push(@tmpz, "LINE2:cmin#EE4444:Minimum ARC size");
	push(@tmp, "LINE2:c#EEEE44:ARC target size");
	push(@tmp, "GPRINT:c:LAST:   Cur\\: %5.1lf%s");
	push(@tmp, "GPRINT:c:AVERAGE:   Avg\\: %5.1lf%s");
	push(@tmp, "GPRINT:c:MIN:   Min\\: %5.1lf%s");
	push(@tmp, "GPRINT:c:MAX:   Max\\: %5.1lf%s\\n");
	push(@tmpz, "LINE2:c#EEEE44:ARC target size");
	push(@tmp, "LINE2:limit#EE44EE:ARC meta limit");
	push(@tmp, "GPRINT:limit:LAST:    Cur\\: %5.1lf%s");
	push(@tmp, "GPRINT:limit:AVERAGE:   Avg\\: %5.1lf%s");
	push(@tmp, "GPRINT:limit:MIN:   Min\\: %5.1lf%s");
	push(@tmp, "GPRINT:limit:MAX:   Max\\: %5.1lf%s\\n");
	push(@tmpz, "LINE2:limit#EE44EE:ARC meta limit");
	push(@tmp, "LINE2:max#4444EE:ARC meta max");
	push(@tmp, "GPRINT:max:LAST:      Cur\\: %5.1lf%s");
	push(@tmp, "GPRINT:max:AVERAGE:   Avg\\: %5.1lf%s");
	push(@tmp, "GPRINT:max:MIN:   Min\\: %5.1lf%s");
	push(@tmp, "GPRINT:max:MAX:   Max\\: %5.1lf%s\\n");
	push(@tmpz, "LINE2:max#4444EE:ARC meta max");
	push(@tmp, "LINE2:used#44EEEE:ARC meta used");
	push(@tmp, "GPRINT:used:LAST:     Cur\\: %5.1lf%s");
	push(@tmp, "GPRINT:used:AVERAGE:   Avg\\: %5.1lf%s");
	push(@tmp, "GPRINT:used:MIN:   Min\\: %5.1lf%s");
	push(@tmp, "GPRINT:used:MAX:   Max\\: %5.1lf%s\\n");
	push(@tmpz, "LINE2:used#44EEEE:ARC meta used");
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
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG1",
		"--title=$config->{graphs}->{_zfs1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=bytes",
		"--width=$width",
		"--height=$height",
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:arcsize=$rrd:zfs_arcsize:AVERAGE",
		"DEF:cmax=$rrd:zfs_cmax:AVERAGE",
		"DEF:cmin=$rrd:zfs_cmin:AVERAGE",
		"DEF:c=$rrd:zfs_arctgtsize:AVERAGE",
		"DEF:limit=$rrd:zfs_metalimit:AVERAGE",
		"DEF:max=$rrd:zfs_metamax:AVERAGE",
		"DEF:used=$rrd:zfs_metaused:AVERAGE",
		"CDEF:allvalues=arcsize,cmax,cmin,c,limit,max,used,+,+,+,+,+,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_zfs1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=bytes",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:arcsize=$rrd:zfs_arcsize:AVERAGE",
			"DEF:cmax=$rrd:zfs_cmax:AVERAGE",
			"DEF:cmin=$rrd:zfs_cmin:AVERAGE",
			"DEF:c=$rrd:zfs_arctgtsize:AVERAGE",
			"DEF:limit=$rrd:zfs_metalimit:AVERAGE",
			"DEF:max=$rrd:zfs_metamax:AVERAGE",
			"DEF:used=$rrd:zfs_metaused:AVERAGE",
			"CDEF:allvalues=arcsize,cmax,cmin,c,limit,max,used,+,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /zfs1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "'>\n");
		}
	}

	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	@riglim = @{setup_riglim($rigid[1], $limit[1])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:hits#44EEEE:Hits");
	push(@tmp, "GPRINT:hits:LAST:                 Current\\: %4.0lf\\n");
	push(@tmp, "LINE2:miss#EE44EE:Misses");
	push(@tmp, "GPRINT:miss:LAST:               Current\\: %4.0lf\\n");
	push(@tmp, "LINE2:dele#EEEE44:Deleted");
	push(@tmp, "GPRINT:dele:LAST:              Current\\: %4.0lf\\n");
	push(@tmpz, "LINE2:hits#44EEEE:Hits");
	push(@tmpz, "LINE2:miss#EE44EE:Misses");
	push(@tmpz, "LINE2:dele#EEEE44:Deleted");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_zfs2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Reads/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:hits=$rrd:zfs_arc_hits:AVERAGE",
		"DEF:miss=$rrd:zfs_arc_misses:AVERAGE",
		"DEF:dele=$rrd:zfs_arc_deleted:AVERAGE",
		"CDEF:allvalues=hits,miss,dele,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_zfs2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Reads/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:hits=$rrd:zfs_arc_hits:AVERAGE",
			"DEF:miss=$rrd:zfs_arc_misses:AVERAGE",
			"DEF:dele=$rrd:zfs_arc_deleted:AVERAGE",
			"CDEF:allvalues=hits,miss,dele,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /zfs2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "'>\n");
		}
	}

	@riglim = @{setup_riglim($rigid[2], $limit[2])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:hits#44EEEE:Hits");
	push(@tmp, "GPRINT:hits:LAST:                 Current\\: %4.0lf\\n");
	push(@tmp, "LINE2:miss#EE44EE:Misses");
	push(@tmp, "GPRINT:miss:LAST:               Current\\: %4.0lf\\n");
	push(@tmpz, "LINE2:hits#44EEEE:Hits");
	push(@tmpz, "LINE2:miss#EE44EE:Misses");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG3",
		"--title=$config->{graphs}->{_zfs3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Reads/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:hits=$rrd:zfs_l2arc_hits:AVERAGE",
		"DEF:miss=$rrd:zfs_l2arc_misses:AVERAGE",
		"CDEF:allvalues=hits,miss,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_zfs3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Reads/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:hits=$rrd:zfs_l2arc_hits:AVERAGE",
			"DEF:miss=$rrd:zfs_l2arc_misses:AVERAGE",
			"CDEF:allvalues=hits,miss,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /zfs3/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "'>\n");
		}
	}

	if($title) {
		print("  </table>\n");
		print("  <table cellspacing='5' cellpadding='0' width='1' bgcolor='$colors->{graph_bg_color}' border='1'>\n");
	}

	$e = 0;
	for($n = 0; $n < scalar(my @pl = split(',', $zfs->{list})); $n++) {
		$str = trim($pl[$n]);

	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	@riglim = @{setup_riglim($rigid[$e + 3], $limit[$e + 3])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:udata#44EEEE:Used by data");
	push(@tmp, "GPRINT:udata:LAST:                 Current\\: %5.1lf%S\\n");
	push(@tmp, "LINE2:usnap#EE44EE:Used by snapshots");
	push(@tmp, "GPRINT:usnap:LAST:            Current\\: %5.1lf%S\\n");
	push(@tmpz, "LINE2:udata#44EEEE:Used by data");
	push(@tmpz, "LINE2:usnap#EE44EE:Used by snapshots");
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium2});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e]",
		"--title=$config->{graphs}->{_zfs4}: $str  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=bytes",
		"--width=$width",
		"--height=$height",
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:free=$rrd:zfs" . $n . "_free:AVERAGE",
		"DEF:udata=$rrd:zfs" . $n . "_udata:AVERAGE",
		"DEF:usnap=$rrd:zfs" . $n . "_usnap:AVERAGE",
		"CDEF:allvalues=free,udata,usnap,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $IMG_DIR" . "$IMG[$e]: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e]",
			"--title=$config->{graphs}->{_zfs4}: $str  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=bytes",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:free=$rrd:zfs" . $n . "_free:AVERAGE",
			"DEF:udata=$rrd:zfs" . $n . "_udata:AVERAGE",
			"DEF:usnap=$rrd:zfs" . $n . "_usnap:AVERAGE",
			"CDEF:allvalues=free,udata,usnap,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $IMG_DIR" . "$IMGz[$e]: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /zfs2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e] . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e] . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e] . "'>\n");
		}
	}
	$e++;

	if($title) {
		print("    </td>\n");
		print("    <td bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	@riglim = @{setup_riglim($rigid[$e + 3], $limit[$e + 3])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "LINE2:cap#44EEEE:Capacity");
	push(@tmp, "GPRINT:cap:LAST:                     Current\\: %4.1lf%%\\n");
	push(@tmp, "LINE2:fra#EE44EE:Fragmentation");
	push(@tmp, "GPRINT:fra:LAST:                Current\\: %4.1lf%%\\n");
	push(@tmpz, "LINE2:cap#44EEEE:Capacity");
	push(@tmpz, "LINE2:fra#EE44EE:Fragmentation");
	if(lc($config->{show_gaps}) eq "y") {
		push(@tmp, "AREA:wrongdata#$colors->{gap}:");
		push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{medium2});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e]",
		"--title=$config->{graphs}->{_zfs5}: $str  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Percent (%)",
		"--width=$width",
		"--height=$height",
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:cap=$rrd:zfs" . $n . "_cap:AVERAGE",
		"DEF:fra=$rrd:zfs" . $n . "_fra:AVERAGE",
		"CDEF:allvalues=cap,fra,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $IMG_DIR" . "$IMG[$e]: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e]",
			"--title=$config->{graphs}->{_zfs5}: $str  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:cap=$rrd:zfs" . $n . "_cap:AVERAGE",
			"DEF:fra=$rrd:zfs" . $n . "_fra:AVERAGE",
			"CDEF:allvalues=cap,fra,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $IMG_DIR" . "$IMGz[$e]: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /zfs3/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e] . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e] . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e] . "'>\n");
		}
	}
	$e++;

	if($title) {
		print("    </td>\n");
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
