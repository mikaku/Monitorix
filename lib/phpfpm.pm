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

package phpfpm;

use strict;
use warnings;
use Monitorix;
use RRDs;
use LWP::UserAgent;
use Exporter 'import';
our @EXPORT = qw(phpfpm_init phpfpm_update phpfpm_cgi);

sub phpfpm_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $phpfpm = $config->{phpfpm};

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
		if(scalar(@ds) / 144 != keys(%{$phpfpm->{list}})) {
			logger("$myself: Detected size mismatch between <list>...</list> (" . keys(%{$phpfpm->{list}}) . ") and $rrd (" . scalar(@ds) / 144 . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
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
		for($n = 0; $n < keys(%{$phpfpm->{list}}); $n++) {
			my $n2;
			for($n2 = 0; $n2 < 8; $n2++) {
				push(@tmp, "DS:phpfpm" . $n . "_uptim" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_aconn" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_lqueu" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_mlque" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_iproc" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_aproc" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_mapro" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_mchil" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_slreq" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_val1" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_val2" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_val3" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_val4" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_val5" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_val6" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_val7" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_val8" . $n2 . ":GAUGE:120:0:U");
				push(@tmp, "DS:phpfpm" . $n . "_val9" . $n2 . ":GAUGE:120:0:U");
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

	$config->{phpfpm_hist} = ();
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub phpfpm_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $phpfpm = $config->{phpfpm};

	my @sens;

	my $n;
	my $str;
	my $rrdata = "N";

	foreach my $pfg (sort keys %{$phpfpm->{group}}) {
		my @pfl = split(',', $phpfpm->{list}->{$pfg});
		for($n = 0; $n < 8 && $n < scalar(@pfl); $n++) {
			my $uptim = 0;
			my $aconn = 0;
			my $lqueu = 0;
			my $mlque = 0;
			my $iproc = 0;
			my $aproc = 0;
			my $mapro = 0;
			my $mchil = 0;
			my $slreq = 0;
			my $ssl = "";

			my $pool = trim($pfl[$n] || "");
			my $url = $phpfpm->{desc}->{$pool} || "";
			if(!$url) {
				logger("$myself: ERROR: the pool '$pool' don't has an associated URL.");
				$rrdata .= ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0";
				next;
			}

			$ssl = "ssl_opts => {verify_hostname => 0}",
			$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0
				if lc($config->{accept_selfsigned_certs}) eq "y";
			my $ua = LWP::UserAgent->new(timeout => 30, $ssl);
			$ua->agent($config->{user_agent_id}) if $config->{user_agent_id} || "";
			my $response = $ua->request(HTTP::Request->new('GET', $url));
			if(!$response->is_success) {
				logger("$myself: ERROR: in pool '$pool', unable to connect to '$url'.");
				logger("$myself: " . $response->status_line);
			} else {
				foreach(split('\n', $response->content)) {
					if(/^start since:\s+(\d+)$/) {
						$uptim = $1;
					}
					if(/^accepted conn:\s+(\d+)$/) {
						$str = $pfg . $n . "aconn";
						$aconn = $1 - ($config->{phpfpm_hist}->{$str} || 0);
						$aconn = 0 unless $aconn != $1;
						$aconn /= 60;
						$config->{phpfpm_hist}->{$str} = $1;
					}
					if(/^listen queue:\s+(\d+)$/) {
						$lqueu = $1;
					}
					if(/^max listen queue:\s+(\d+)$/) {
						$mlque = $1;
					}
					if(/^idle processes:\s+(\d+)$/) {
						$iproc = $1;
					}
					if(/^active processes:\s+(\d+)$/) {
						$aproc = $1;
					}
					if(/^max active processes:\s+(\d+)$/) {
						$mapro = $1;
					}
					if(/^max children reached:\s+(\d+)$/) {
						$mchil = $1;
					}
					if(/^slow requests:\s+(\d+)$/) {
						$slreq = $1;
					}
				}
			}
			$rrdata .= ":$uptim:$aconn:$lqueu:$mlque:$iproc:$aproc:$mapro:$mchil:$slreq:0:0:0:0:0:0:0:0:0";
		}
		for(; $n < 8; $n++) {
			$rrdata .= ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0";
		}
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub phpfpm_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $phpfpm = $config->{phpfpm};
	my @rigid = split(',', ($phpfpm->{rigid} || ""));
	my @limit = split(',', ($phpfpm->{limit} || ""));
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
	my $e;
	my $e2;
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
		my $line4;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "    ");
		foreach my $pfg (sort keys %{$phpfpm->{group}}) {
			if(!scalar(my @pfl = split(',', $phpfpm->{list}->{$pfg}))) {
				next;
			}
			$line1 = " ";
			$line2 .= " ";
			$line3 .= " ";
			$line4 .= "-";
			for($n = 0; $n < scalar(my @pfl = split(',', $phpfpm->{list}->{$pfg})); $n++) {
				my $dl = trim($pfl[$n]);
				$str = $phpfpm->{map}->{$dl} || $dl;
				$line1 .= "                                                               ";
				$line2 .= sprintf(" %62s", $str);
				$line3 .= "  aconn  lqueue  mlqueu  idproc  acproc  macpro  mchild  slwreq";
				$line4 .= "---------------------------------------------------------------";
			}
			my $i = length($line1);
			push(@output, sprintf("%${i}s", sprintf("%s", trim($phpfpm->{group}->{$pfg}))));
		}
		push(@output, "\n");
		push(@output, "    $line2\n");
		push(@output, "Time$line3\n");
		push(@output, "----$line4 \n");
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
			$n3 = 0;
			foreach my $pfg (sort keys %{$phpfpm->{group}}) {
				if(!scalar(my @pfl = split(',', $phpfpm->{list}->{$pfg}))) {
					next;
				}
				for($n2 = 0; $n2 < scalar(my @pfl = split(',', $phpfpm->{list}->{$pfg})); $n2++) {
					$from = $n2 * 18 + ($n3 * 144);
					$to = $from + 18;
					my (undef, $aconn, $lqueue, $mlqueu, $idproc, $acproc, $macpro, $mchild, $slwreq) = @$line[$from..$to];
					@row = ($aconn, $lqueue, $mlqueu, $idproc, $acproc, $macpro, $mchild, $slwreq);
					push(@output, sprintf(" %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d", @row));
				}
				push(@output, sprintf(" "));
				$n3++;
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

	$n = 0;
	foreach my $pfg (sort keys %{$phpfpm->{group}}) {
		for($n2 = 1; $n2 <= 6; $n2++) {
			$str = $u . $package . $n . $n2 . "." . $tf->{when} . ".$imgfmt_lc";
			push(@IMG, $str);
			unlink("$IMG_DIR" . $str);
			if(lc($config->{enable_zoom}) eq "y") {
				$str = $u . $package . $n . $n2 . "z." . $tf->{when} . ".$imgfmt_lc";
				push(@IMGz, $str);
				unlink("$IMG_DIR" . $str);
			}
		}
		$n++;
	}

	my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
		"--resolution=60",
		"--start=-1min",
		"AVERAGE");
	$err = RRDs::error;
	push(@output, "ERROR: while fetching $rrd: $err\n") if $err;
	my $line = @$data[0];
	my ($uptime) = @$line[0];	# all pools have the same uptime
	my $uptimeline;
	if($RRDs::VERSION > 1.2) {
		$uptimeline = "COMMENT:uptime\\: " . uptime2str($uptime) . "\\c";
	} else {
		$uptimeline = "COMMENT:uptime: " . uptime2str($uptime) . "\\c";
	}

	$e = $n2 = 0;
	foreach my $pfg (sort keys %{$phpfpm->{group}}) {
		# skip empty lists
		if(!scalar(my @pfl = split(',', $phpfpm->{list}->{$pfg}))) {
			$n2++;
			next;
		}

		if($e) {
			push(@output, "   <br>\n");
		}
		if($title) {
			push(@output, main::graph_header($title, 2));
		}

		@riglim = @{setup_riglim($rigid[0], $limit[0])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		my @pfl;
		for($n = 0; $n < scalar(@pfl = split(',', $phpfpm->{list}->{$pfg})); $n++) {
			$str = trim($pfl[$n]);
			$str = $phpfpm->{map}->{$str} ? $phpfpm->{map}->{$str} : $str;
			my $dstr = sprintf("%-25s", substr($str, 0, 25));
			push(@tmp, "LINE2:acon" . $n2 . "_$n" . $LC[$n] . ":$dstr");
			push(@tmpz, "LINE2:acon" . $n2 . "_$n" . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:acon" . $n2 . "_$n" . ":LAST: Cur\\:%5.2lf");
			push(@tmp, "GPRINT:acon" . $n2 . "_$n" . ":AVERAGE:  Avg\\:%5.2lf");
			push(@tmp, "GPRINT:acon" . $n2 . "_$n" . ":MIN:  Min\\:%5.2lf");
			push(@tmp, "GPRINT:acon" . $n2 . "_$n" . ":MAX:  Max\\:%5.2lf\\n");
		}

		if($title) {
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		push(@tmp, "COMMENT: \\n");
		($width, $height) = split('x', $config->{graph_size}->{main});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6]",
			"--title=$config->{graphs}->{_phpfpm1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Connections/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:acon" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_aconn0:AVERAGE",
			"DEF:acon" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_aconn1:AVERAGE",
			"DEF:acon" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_aconn2:AVERAGE",
			"DEF:acon" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_aconn3:AVERAGE",
			"DEF:acon" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_aconn4:AVERAGE",
			"DEF:acon" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_aconn5:AVERAGE",
			"DEF:acon" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_aconn6:AVERAGE",
			"DEF:acon" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_aconn7:AVERAGE",
			"CDEF:allvalues=acon" . $n2 . "_0,acon" . $n2 . "_1,acon" . $n2 . "_2,acon" . $n2 . "_3,acon" . $n2 . "_4,acon" . $n2 . "_5,acon" . $n2 . "_6,acon" . $n2 . "_7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp,
			$uptimeline);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6]",
				"--title=$config->{graphs}->{_phpfpm1}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Connections/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:acon" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_aconn0:AVERAGE",
				"DEF:acon" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_aconn1:AVERAGE",
				"DEF:acon" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_aconn2:AVERAGE",
				"DEF:acon" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_aconn3:AVERAGE",
				"DEF:acon" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_aconn4:AVERAGE",
				"DEF:acon" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_aconn5:AVERAGE",
				"DEF:acon" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_aconn6:AVERAGE",
				"DEF:acon" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_aconn7:AVERAGE",
				"CDEF:allvalues=acon" . $n2 . "_0,acon" . $n2 . "_1,acon" . $n2 . "_2,acon" . $n2 . "_3,acon" . $n2 . "_4,acon" . $n2 . "_5,acon" . $n2 . "_6,acon" . $n2 . "_7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6]: $err\n") if $err;
		}
		$e2 = $e + 1;
		if($title || ($silent =~ /imagetag/ && $graph =~ /phpfpm$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[1], $limit[1])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < scalar(@pfl = split(',', $phpfpm->{list}->{$pfg})); $n++) {
			$str = trim($pfl[$n]);
			$str = $phpfpm->{map}->{$str} ? $phpfpm->{map}->{$str} : $str;
			my $dstr = sprintf("%-25s", substr($str, 0, 25));
			push(@tmp, "LINE2:aproc" . $n2 . "_$n" . $LC[$n] . ":$dstr");
			push(@tmpz, "LINE2:aproc" . $n2 . "_$n" . $LC[$n] . ":$str");
			push(@tmp, "GPRINT:aproc" . $n2 . "_$n" . ":LAST: Cur\\:%5.2lf");
			push(@tmp, "GPRINT:aproc" . $n2 . "_$n" . ":AVERAGE:  Avg\\:%5.2lf");
			push(@tmp, "GPRINT:aproc" . $n2 . "_$n" . ":MIN:  Min\\:%5.2lf");
			push(@tmp, "GPRINT:aproc" . $n2 . "_$n" . ":MAX:  Max\\:%5.2lf\\n");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		push(@tmp, "COMMENT: \\n");
		($width, $height) = split('x', $config->{graph_size}->{main});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 1]",
			"--title=$config->{graphs}->{_phpfpm2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Processes",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:aproc" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_aproc0:AVERAGE",
			"DEF:aproc" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_aproc1:AVERAGE",
			"DEF:aproc" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_aproc2:AVERAGE",
			"DEF:aproc" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_aproc3:AVERAGE",
			"DEF:aproc" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_aproc4:AVERAGE",
			"DEF:aproc" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_aproc5:AVERAGE",
			"DEF:aproc" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_aproc6:AVERAGE",
			"DEF:aproc" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_aproc7:AVERAGE",
			"CDEF:allvalues=aproc" . $n2 . "_0,aproc" . $n2 . "_1,aproc" . $n2 . "_2,aproc" . $n2 . "_3,aproc" . $n2 . "_4,aproc" . $n2 . "_5,aproc" . $n2 . "_6,aproc" . $n2 . "_7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 1]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 1]",
				"--title=$config->{graphs}->{_phpfpm2}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Processes",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$colors->{graph_colors}},
				"DEF:aproc" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_aproc0:AVERAGE",
				"DEF:aproc" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_aproc1:AVERAGE",
				"DEF:aproc" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_aproc2:AVERAGE",
				"DEF:aproc" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_aproc3:AVERAGE",
				"DEF:aproc" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_aproc4:AVERAGE",
				"DEF:aproc" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_aproc5:AVERAGE",
				"DEF:aproc" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_aproc6:AVERAGE",
				"DEF:aproc" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_aproc7:AVERAGE",
				"CDEF:allvalues=aproc" . $n2 . "_0,aproc" . $n2 . "_1,aproc" . $n2 . "_2,aproc" . $n2 . "_3,aproc" . $n2 . "_4,aproc" . $n2 . "_5,aproc" . $n2 . "_6,aproc" . $n2 . "_7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 1]: $err\n") if $err;
		}
		$e2 = $e + 2;
		if($title || ($silent =~ /imagetag/ && $graph =~ /phpfpm$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 1] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 1] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 1] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    <td class='td-valign-top'>\n");
		}

		@riglim = @{setup_riglim($rigid[2], $limit[2])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < scalar(my @pfl = split(',', $phpfpm->{list}->{$pfg})); $n++) {
			$str = trim($pfl[$n]);
			$str = $phpfpm->{map}->{$str} ? $phpfpm->{map}->{$str} : $str;
			my $dstr = substr($str, 0, 25);
			push(@tmp, "LINE2:lqueue" . $n2 . "_$n" . $LC[$n] . ":$dstr");
			push(@tmpz, "LINE2:lqueue" . $n2 . "_$n" . $LC[$n] . ":$str\\g");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 2]",
			"--title=$config->{graphs}->{_phpfpm3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Listening",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:lqueue" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_lqueu0:AVERAGE",
			"DEF:lqueue" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_lqueu1:AVERAGE",
			"DEF:lqueue" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_lqueu2:AVERAGE",
			"DEF:lqueue" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_lqueu3:AVERAGE",
			"DEF:lqueue" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_lqueu4:AVERAGE",
			"DEF:lqueue" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_lqueu5:AVERAGE",
			"DEF:lqueue" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_lqueu6:AVERAGE",
			"DEF:lqueue" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_lqueu7:AVERAGE",
			"CDEF:allvalues=lqueue" . $n2 . "_0,lqueue" . $n2 . "_1,lqueue" . $n2 . "_2,lqueue" . $n2 . "_3,lqueue" . $n2 . "_4,lqueue" . $n2 . "_5,lqueue" . $n2 . "_6,lqueue" . $n2 . "_7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 2]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 2]",
				"--title=$config->{graphs}->{_phpfpm3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Listening",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:lqueue" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_lqueu0:AVERAGE",
				"DEF:lqueue" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_lqueu1:AVERAGE",
				"DEF:lqueue" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_lqueu2:AVERAGE",
				"DEF:lqueue" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_lqueu3:AVERAGE",
				"DEF:lqueue" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_lqueu4:AVERAGE",
				"DEF:lqueue" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_lqueu5:AVERAGE",
				"DEF:lqueue" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_lqueu6:AVERAGE",
				"DEF:lqueue" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_lqueu7:AVERAGE",
				"CDEF:allvalues=lqueue" . $n2 . "_0,lqueue" . $n2 . "_1,lqueue" . $n2 . "_2,lqueue" . $n2 . "_3,lqueue" . $n2 . "_4,lqueue" . $n2 . "_5,lqueue" . $n2 . "_6,lqueue" . $n2 . "_7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 2]: $err\n") if $err;
		}
		$e2 = $e + 3;
		if($title || ($silent =~ /imagetag/ && $graph =~ /phpfpm$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 2] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 2] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 2] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[3], $limit[3])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < scalar(my @pfl = split(',', $phpfpm->{list}->{$pfg})); $n++) {
			$str = trim($pfl[$n]);
			$str = $phpfpm->{map}->{$str} ? $phpfpm->{map}->{$str} : $str;
			my $dstr = substr($str, 0, 25);
			push(@tmp, "LINE2:tproc" . $n . $LC[$n] . ":$dstr");
			push(@tmpz, "LINE2:tproc" . $n . $LC[$n] . ":$str\\g");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 3]",
			"--title=$config->{graphs}->{_phpfpm4}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Processes",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:iproc" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_iproc0:AVERAGE",
			"DEF:iproc" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_iproc1:AVERAGE",
			"DEF:iproc" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_iproc2:AVERAGE",
			"DEF:iproc" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_iproc3:AVERAGE",
			"DEF:iproc" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_iproc4:AVERAGE",
			"DEF:iproc" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_iproc5:AVERAGE",
			"DEF:iproc" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_iproc6:AVERAGE",
			"DEF:iproc" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_iproc7:AVERAGE",
			"DEF:aproc" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_aproc0:AVERAGE",
			"DEF:aproc" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_aproc1:AVERAGE",
			"DEF:aproc" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_aproc2:AVERAGE",
			"DEF:aproc" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_aproc3:AVERAGE",
			"DEF:aproc" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_aproc4:AVERAGE",
			"DEF:aproc" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_aproc5:AVERAGE",
			"DEF:aproc" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_aproc6:AVERAGE",
			"DEF:aproc" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_aproc7:AVERAGE",
			"CDEF:tproc0=iproc" . $n2 . "_0,aproc" . $n2 . "_0,+",
			"CDEF:tproc1=iproc" . $n2 . "_1,aproc" . $n2 . "_1,+",
			"CDEF:tproc2=iproc" . $n2 . "_2,aproc" . $n2 . "_2,+",
			"CDEF:tproc3=iproc" . $n2 . "_3,aproc" . $n2 . "_3,+",
			"CDEF:tproc4=iproc" . $n2 . "_4,aproc" . $n2 . "_4,+",
			"CDEF:tproc5=iproc" . $n2 . "_5,aproc" . $n2 . "_5,+",
			"CDEF:tproc6=iproc" . $n2 . "_6,aproc" . $n2 . "_6,+",
			"CDEF:tproc7=iproc" . $n2 . "_7,aproc" . $n2 . "_6,+",
			"CDEF:allvalues=tproc0,tproc1,tproc2,tproc3,tproc4,tproc5,tproc6,tproc7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 3]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 3]",
				"--title=$config->{graphs}->{_phpfpm4}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Processes",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:iproc" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_iproc0:AVERAGE",
				"DEF:iproc" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_iproc1:AVERAGE",
				"DEF:iproc" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_iproc2:AVERAGE",
				"DEF:iproc" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_iproc3:AVERAGE",
				"DEF:iproc" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_iproc4:AVERAGE",
				"DEF:iproc" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_iproc5:AVERAGE",
				"DEF:iproc" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_iproc6:AVERAGE",
				"DEF:iproc" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_iproc7:AVERAGE",
				"DEF:aproc" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_aproc0:AVERAGE",
				"DEF:aproc" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_aproc1:AVERAGE",
				"DEF:aproc" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_aproc2:AVERAGE",
				"DEF:aproc" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_aproc3:AVERAGE",
				"DEF:aproc" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_aproc4:AVERAGE",
				"DEF:aproc" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_aproc5:AVERAGE",
				"DEF:aproc" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_aproc6:AVERAGE",
				"DEF:aproc" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_aproc7:AVERAGE",
				"CDEF:tproc0=iproc" . $n2 . "_0,aproc" . $n2 . "_0,+",
				"CDEF:tproc1=iproc" . $n2 . "_1,aproc" . $n2 . "_1,+",
				"CDEF:tproc2=iproc" . $n2 . "_2,aproc" . $n2 . "_2,+",
				"CDEF:tproc3=iproc" . $n2 . "_3,aproc" . $n2 . "_3,+",
				"CDEF:tproc4=iproc" . $n2 . "_4,aproc" . $n2 . "_4,+",
				"CDEF:tproc5=iproc" . $n2 . "_5,aproc" . $n2 . "_5,+",
				"CDEF:tproc6=iproc" . $n2 . "_6,aproc" . $n2 . "_6,+",
				"CDEF:tproc7=iproc" . $n2 . "_7,aproc" . $n2 . "_6,+",
				"CDEF:allvalues=tproc0,tproc1,tproc2,tproc3,tproc4,tproc5,tproc6,tproc7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 3]: $err\n") if $err;
		}
		$e2 = $e + 4;
		if($title || ($silent =~ /imagetag/ && $graph =~ /phpfpm$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 3] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 3] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 3] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[4], $limit[4])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < scalar(my @pfl = split(',', $phpfpm->{list}->{$pfg})); $n++) {
			$str = trim($pfl[$n]);
			$str = $phpfpm->{map}->{$str} ? $phpfpm->{map}->{$str} : $str;
			my $dstr = substr($str, 0, 25);
			push(@tmp, "LINE2:mchild" . $n2 . "_$n" . $LC[$n] . ":$dstr");
			push(@tmpz, "LINE2:mchild" . $n2 . "_$n" . $LC[$n] . ":$str\\g");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 4]",
			"--title=$config->{graphs}->{_phpfpm5}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Children",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:mchild" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_mchil0:AVERAGE",
			"DEF:mchild" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_mchil1:AVERAGE",
			"DEF:mchild" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_mchil2:AVERAGE",
			"DEF:mchild" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_mchil3:AVERAGE",
			"DEF:mchild" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_mchil4:AVERAGE",
			"DEF:mchild" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_mchil5:AVERAGE",
			"DEF:mchild" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_mchil6:AVERAGE",
			"DEF:mchild" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_mchil7:AVERAGE",
			"CDEF:allvalues=mchild" . $n2 . "_0,mchild" . $n2 . "_1,mchild" . $n2 . "_2,mchild" . $n2 . "_3,mchild" . $n2 . "_4,mchild" . $n2 . "_5,mchild" . $n2 . "_6,mchild" . $n2 . "_7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 4]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 4]",
				"--title=$config->{graphs}->{_phpfpm5}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Children",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:mchild" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_mchil0:AVERAGE",
				"DEF:mchild" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_mchil1:AVERAGE",
				"DEF:mchild" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_mchil2:AVERAGE",
				"DEF:mchild" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_mchil3:AVERAGE",
				"DEF:mchild" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_mchil4:AVERAGE",
				"DEF:mchild" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_mchil5:AVERAGE",
				"DEF:mchild" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_mchil6:AVERAGE",
				"DEF:mchild" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_mchil7:AVERAGE",
				"CDEF:allvalues=mchild" . $n2 . "_0,mchild" . $n2 . "_1,mchild" . $n2 . "_2,mchild" . $n2 . "_3,mchild" . $n2 . "_4,mchild" . $n2 . "_5,mchild" . $n2 . "_6,mchild" . $n2 . "_7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 4]: $err\n") if $err;
		}
		$e2 = $e + 5;
		if($title || ($silent =~ /imagetag/ && $graph =~ /phpfpm$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 4] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 4] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 4] . "'>\n");
			}
		}

		@riglim = @{setup_riglim($rigid[5], $limit[5])};
		undef(@tmp);
		undef(@tmpz);
		undef(@CDEF);
		for($n = 0; $n < scalar(my @pfl = split(',', $phpfpm->{list}->{$pfg})); $n++) {
			$str = trim($pfl[$n]);
			$str = $phpfpm->{map}->{$str} ? $phpfpm->{map}->{$str} : $str;
			my $dstr = substr($str, 0, 25);
			push(@tmp, "LINE2:slwreq" . $n2 . "_$n" . $LC[$n] . ":$dstr");
			push(@tmpz, "LINE2:slwreq" . $n2 . "_$n" . $LC[$n] . ":$str\\g");
		}
		if(lc($config->{show_gaps}) eq "y") {
			push(@tmp, "AREA:wrongdata#$colors->{gap}:");
			push(@tmpz, "AREA:wrongdata#$colors->{gap}:");
			push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
		}
		($width, $height) = split('x', $config->{graph_size}->{small});
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG[$e * 6 + 5]",
			"--title=$config->{graphs}->{_phpfpm6}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Requests",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:slwreq" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_slreq0:AVERAGE",
			"DEF:slwreq" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_slreq1:AVERAGE",
			"DEF:slwreq" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_slreq2:AVERAGE",
			"DEF:slwreq" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_slreq3:AVERAGE",
			"DEF:slwreq" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_slreq4:AVERAGE",
			"DEF:slwreq" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_slreq5:AVERAGE",
			"DEF:slwreq" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_slreq6:AVERAGE",
			"DEF:slwreq" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_slreq7:AVERAGE",
			"CDEF:allvalues=slwreq" . $n2 . "_0,slwreq" . $n2 . "_1,slwreq" . $n2 . "_2,slwreq" . $n2 . "_3,slwreq" . $n2 . "_4,slwreq" . $n2 . "_5,slwreq" . $n2 . "_6,slwreq" . $n2 . "_7,+,+,+,+,+,+,+",
			@CDEF,
			@tmp);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG[$e * 6 + 5]: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMGz[$e * 6 + 5]",
				"--title=$config->{graphs}->{_phpfpm6}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Requests",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				"DEF:slwreq" . $n2 . "_0=$rrd:phpfpm" . $n2 . "_slreq0:AVERAGE",
				"DEF:slwreq" . $n2 . "_1=$rrd:phpfpm" . $n2 . "_slreq1:AVERAGE",
				"DEF:slwreq" . $n2 . "_2=$rrd:phpfpm" . $n2 . "_slreq2:AVERAGE",
				"DEF:slwreq" . $n2 . "_3=$rrd:phpfpm" . $n2 . "_slreq3:AVERAGE",
				"DEF:slwreq" . $n2 . "_4=$rrd:phpfpm" . $n2 . "_slreq4:AVERAGE",
				"DEF:slwreq" . $n2 . "_5=$rrd:phpfpm" . $n2 . "_slreq5:AVERAGE",
				"DEF:slwreq" . $n2 . "_6=$rrd:phpfpm" . $n2 . "_slreq6:AVERAGE",
				"DEF:slwreq" . $n2 . "_7=$rrd:phpfpm" . $n2 . "_slreq7:AVERAGE",
				"CDEF:allvalues=slwreq" . $n2 . "_0,slwreq" . $n2 . "_1,slwreq" . $n2 . "_2,slwreq" . $n2 . "_3,slwreq" . $n2 . "_4,slwreq" . $n2 . "_5,slwreq" . $n2 . "_6,slwreq" . $n2 . "_7,+,+,+,+,+,+,+",
				@CDEF,
				@tmpz);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMGz[$e * 6 + 5]: $err\n") if $err;
		}
		$e2 = $e + 6;
		if($title || ($silent =~ /imagetag/ && $graph =~ /phpfpm$e2/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 5] . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMGz[$e * 6 + 5] . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG[$e * 6 + 5] . "'>\n");
			}
		}

		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");

			push(@output, "    <tr>\n");
			push(@output, "      <td bgcolor='$colors->{title_bg_color}' colspan='2'>\n");
			push(@output, "       <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n");
			push(@output, "       <font size='-1'>\n");
			push(@output, "        <b>&nbsp;&nbsp;$phpfpm->{group}->{$pfg}<b>\n");
			push(@output, "       </font></font>\n");
			push(@output, "      </td>\n");
			push(@output, "    </tr>\n");
			push(@output, main::graph_footer());
		}
		$e++;
		$n2++;
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
