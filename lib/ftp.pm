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

package ftp;

use strict;
use warnings;
use Monitorix;
use RRDs;
use POSIX qw(strftime);
use Exporter 'import';
our @EXPORT = qw(ftp_init ftp_update ftp_cgi);

sub ftp_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

	my $info;
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
			if(index($key, 'rra[') == 0) {
				if(index($key, '.rows') != -1) {
					push(@rra, substr($key, 4, index($key, ']') - 4));
				}
			}
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
		eval {
			RRDs::create($rrd,
				"--step=60",
				"DS:ftp_retr:GAUGE:120:0:U",
				"DS:ftp_stor:GAUGE:120:0:U",
				"DS:ftp_mkd:GAUGE:120:0:U",
				"DS:ftp_rmd:GAUGE:120:0:U",
				"DS:ftp_dele:GAUGE:120:0:U",
				"DS:ftp_mlsd:GAUGE:120:0:U",
				"DS:ftp_val01:GAUGE:120:0:U",
				"DS:ftp_val02:GAUGE:120:0:U",
				"DS:ftp_val03:GAUGE:120:0:U",
				"DS:ftp_logins:GAUGE:120:0:U",
				"DS:ftp_good_logins:GAUGE:120:0:U",
				"DS:ftp_bad_logins:GAUGE:120:0:U",
				"DS:ftp_anon_logins:GAUGE:120:0:U",
				"DS:ftp_bytes_dn:GAUGE:120:0:U",
				"DS:ftp_bytes_up:GAUGE:120:0:U",
				"DS:ftp_val04:GAUGE:120:0:U",
				"DS:ftp_val05:GAUGE:120:0:U",
				"DS:ftp_val06:GAUGE:120:0:U",
				"DS:ftp_val07:GAUGE:120:0:U",
				"DS:ftp_val08:GAUGE:120:0:U",
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

	$config->{ftp_hist} = 0;
	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub ftp_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $ftp = $config->{ftp};

	my $seek_pos;
	my $logsize;

	my $retr = 0;
	my $stor = 0;
	my $mkd = 0;
	my $rmd = 0;
	my $dele = 0;
	my $mlsd = 0;
	my $logins = 0;
	my $good_logins = 0;
	my $bad_logins = 0;
	my $anon_logins = 0;
	my $bytes_down = 0;
	my $bytes_up = 0;

	my $rrdata = "N";

	if(! -r $config->{ftp_log}) {
		logger("$myself: Couldn't find file '$config->{ftp_log}': $!");
		return;
	}

	$seek_pos = $config->{ftp_hist} || 0;
	$seek_pos = defined($seek_pos) ? int($seek_pos) : 0;
	open(IN, $config->{ftp_log});
	if(!seek(IN, 0, 2)) {
		logger("Couldn't seek to the end of '$config->{ftp_log}': $!");
		return;
	}
	$logsize = tell(IN);
	if($logsize < $seek_pos) {
		$seek_pos = 0;
	}
	if(!seek(IN, $seek_pos, 0)) {
		logger("Couldn't seek to $seek_pos in '$config->{ftp_log}': $!");
		return;
	}
	if($config->{ftp_hist} > 0) {	# avoids initial peak
		while(<IN>) {
			if(lc($ftp->{server}) eq "proftpd") {
				my $date = strftime("%d/%b/%Y", localtime);
				if(/^\S+ \S+ \S+ \[$date.*\] \"(\S+.*)\" (\d\d\d) (\d+|\-)$/) {
					my $cmd = $1;
					my $user = "";
					my $code = $2;
					my $bytes = $3;
					$cmd =~ m/(\S+)\s(\S*)/;
					$cmd = $1;
					$user = trim($2);
					if($cmd eq "RETR") {
						if($code =~ /^2../) {
							$retr++;
							$bytes_down += int($bytes);
						}
					}
					if($cmd =~ /(STOR|STOU)/) {
						if($code =~ /^2../) {
							$stor++;
							$bytes_up += int($bytes);
						}
					}
					if($cmd =~ /(MKD|XMKD)/) {
						$mkd++ if($code =~ /^2../);
					}
					if($cmd =~ /(RMD|XRMD)/) {
						$rmd++ if($code =~ /^2../);
					}
					if($cmd eq "DELE") {
						$dele++ if($code =~ /^2../);
					}
					if($cmd =~ /(MLSD|MLST)/) {
						$mlsd++ if($code =~ /^2../);
					}
					if($cmd eq "USER") {
						if(grep {trim($_) eq $user} (split(',', $ftp->{anon_user}))) {
							$anon_logins++ if($code =~ /^3../);
						}
					}
					if($cmd eq "PASS") {
						$good_logins++ if($code =~ /^2../);
						$bad_logins++ if($code =~ /^5../);
						$logins++;
					}
				}
			}
			if(lc($ftp->{server}) eq "vsftpd") {
				my $date = strftime("%a %b %e", localtime);
				if(/^$date /) {
					if(/ OK DOWNLOAD: .*?, (\d+) bytes, /) {
						$retr++;
						$bytes_down += int($1);
					}
					if(/ OK UPLOAD: .*?, (\d+) bytes, /) {
						$stor++;
						$bytes_up += int($1);
					}
					if(/ OK MKDIR: /) {
						$mkd++;
					}
					if(/ OK RMDIR: /) {
						$rmd++;
					}
					if(/ OK DELETE: /) {
						$dele++;
					}
					if(/ OK LOGIN: /) {
						if(/ anon password /) {
							$anon_logins++;
							$logins++;
						} else {
							$good_logins++;
							$logins++;
						}
					}
					if(/ FAIL LOGIN: /) {
						$bad_logins++;
					}
				}
			}
			if(lc($ftp->{server}) eq "pure-ftpd") {
				my $date = strftime("%b %e", localtime);
				if(/^$date /) {
					if(/ \[NOTICE\] .*? downloaded  \((\d+) bytes,.*?/) {
						$retr++;
						$bytes_down += int($1);
					}
					if(/ \[NOTICE\] .*? uploaded  \((\d+) bytes,.*?/) {
						$stor++;
						$bytes_up += int($1);
					}
					if(/ \[DEBUG\] Command \[mkd\] /) {
						$mkd++;
					}
					if(/ \[DEBUG\] Command \[rmd\] /) {
						$rmd++;
					}
					if(/ \[DEBUG\] Command \[dele\] /) {
						$dele++;
					}
					if(/ \[DEBUG\] Command (\[mlsd\]|\[list\]) /) {
						$mlsd++;
					}
					if(/ \[INFO\] .*? is now logged in/) {
						if(/ anon password /) {	# XXX
							$anon_logins++;	# XXX
							$logins++;	# XXX
						} else {
							$good_logins++;
							$logins++;
						}
					}
					if(/ \[WARNING\] Authentication failed for user /) {
						$bad_logins++;
					}
				}
			}
		}
		close(IN);
	}

	$config->{ftp_hist} = $logsize;

	$rrdata .= ":$retr:$stor:$mkd:$rmd:$dele:$mlsd:0:0:0:$logins:$good_logins:$bad_logins:$anon_logins:$bytes_down:$bytes_up:0:0:0:0:0";
	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub ftp_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $ftp = $config->{ftp};
	my @rigid = split(',', ($ftp->{rigid} || ""));
	my @limit = split(',', ($ftp->{limit} || ""));
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
	my @tmp;
	my @tmpz;
	my @CDEF;
	my $n;
	my $err;

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
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "Time    Dnloads Uploads  Mkdirs  Rmdirs Deletes Listing  Logins GLogins BLogins ALogins BytesDn BytesUp\n");
		push(@output, "------------------------------------------------------------------------------------------------------- \n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			my ($retr, $stor, $mkd, $rmd, $dele, $mlsd, undef, undef, undef, $logins, $good_logins, $bad_logins, $anon_logins, $bytes_down, $bytes_up) = @$line;
			@row = ($retr || 0,
				$stor || 0,
				$mkd || 0,
				$rmd || 0,
				$dele || 0,
				$mlsd || 0,
				$logins || 0,
				$good_logins || 0,
				$bad_logins || 0,
				$anon_logins || 0,
				$bytes_down || 0,
				$bytes_up || 0);
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc}    %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d\n", $time, @row));
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

	if($title) {
		push(@output, main::graph_header($title, 2));
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td>\n");
	}
	push(@tmp, "LINE2:retr#44EE44:Files downloaded (RETR)");
	push(@tmp, "GPRINT:retr:LAST: Current\\: %3.0lf");
	push(@tmp, "GPRINT:retr:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:retr:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:retr:MAX:   Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:stor#4444EE:Files uploaded (STOR)");
	push(@tmp, "GPRINT:stor:LAST:   Current\\: %3.0lf");
	push(@tmp, "GPRINT:stor:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:stor:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:stor:MAX:   Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:mkd#EEEE44:Dirs created (MKD)");
	push(@tmp, "GPRINT:mkd:LAST:      Current\\: %3.0lf");
	push(@tmp, "GPRINT:mkd:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:mkd:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:mkd:MAX:   Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:rmd#EE4444:Dirs deleted (RMD)");
	push(@tmp, "GPRINT:rmd:LAST:      Current\\: %3.0lf");
	push(@tmp, "GPRINT:rmd:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:rmd:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:rmd:MAX:   Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:dele#EE44EE:Files deleted (DELE)");
	push(@tmp, "GPRINT:dele:LAST:    Current\\: %3.0lf");
	push(@tmp, "GPRINT:dele:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:dele:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:dele:MAX:   Max\\: %3.0lf\\n");
	push(@tmp, "LINE2:mlsd#44EEEE:Dir listings (MLSD)");
	push(@tmp, "GPRINT:mlsd:LAST:     Current\\: %3.0lf");
	push(@tmp, "GPRINT:mlsd:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:mlsd:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:mlsd:MAX:   Max\\: %3.0lf\\n");
	push(@tmpz, "LINE2:retr#44EE44:Files downloaded (RETR)");
	push(@tmpz, "LINE2:stor#4444EE:Files uploaded (STOR)");
	push(@tmpz, "LINE2:mkd#EEEE44:Dirs created (MKD)");
	push(@tmpz, "LINE2:rmd#EE4444:Dirs deleted (RMD)");
	push(@tmpz, "LINE2:dele#EE44EE:Files deleted (DELE)");
	push(@tmpz, "LINE2:mlsd#44EEEE:Dir listings (MLSD)");
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
		"--title=$config->{graphs}->{_ftp1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Commands/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:retr=$rrd:ftp_retr:AVERAGE",
		"DEF:stor=$rrd:ftp_stor:AVERAGE",
		"DEF:mkd=$rrd:ftp_mkd:AVERAGE",
		"DEF:rmd=$rrd:ftp_rmd:AVERAGE",
		"DEF:dele=$rrd:ftp_dele:AVERAGE",
		"DEF:mlsd=$rrd:ftp_mlsd:AVERAGE",
		"CDEF:allvalues=retr,stor,mkd,rmd,dele,mlsd,+,+,+,+,+",
		@CDEF,
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_ftp1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Commands/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:retr=$rrd:ftp_retr:AVERAGE",
			"DEF:stor=$rrd:ftp_stor:AVERAGE",
			"DEF:mkd=$rrd:ftp_mkd:AVERAGE",
			"DEF:rmd=$rrd:ftp_rmd:AVERAGE",
			"DEF:dele=$rrd:ftp_dele:AVERAGE",
			"DEF:mlsd=$rrd:ftp_mlsd:AVERAGE",
			"CDEF:allvalues=retr,stor,mkd,rmd,dele,mlsd,+,+,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /ftp1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "'>\n");
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
	push(@tmp, "AREA:good_logins#44EEEE:Successful logins");
	push(@tmp, "GPRINT:good_logins:LAST:     Current\\: %3.0lf\\n");
	push(@tmp, "AREA:bad_logins#EE4444:Bad logins");
	push(@tmp, "GPRINT:bad_logins:LAST:            Current\\: %3.0lf\\n");
	push(@tmp, "AREA:anon_logins#EEEE44:Anonymous logins");
	push(@tmp, "GPRINT:anon_logins:LAST:      Current\\: %3.0lf\\n");
	push(@tmp, "LINE1:good_logins#44EEEE");
	push(@tmp, "LINE1:bad_logins#EE4444");
	push(@tmp, "LINE1:anon_logins#EEEE44");
	push(@tmpz, "AREA:good_logins#44EEEE:Successful logins");
	push(@tmpz, "AREA:bad_logins#EE4444:Bad logins");
	push(@tmpz, "AREA:anon_logins#EEEE44:Anonymous logins");
	push(@tmpz, "LINE2:good_logins#44EEEE");
	push(@tmpz, "LINE2:bad_logins#EE4444");
	push(@tmpz, "LINE2:anon_logins#EEEE44");
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
		"--title=$config->{graphs}->{_ftp2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Logins/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:logins=$rrd:ftp_logins:AVERAGE",
		"DEF:good_logins=$rrd:ftp_good_logins:AVERAGE",
		"DEF:bad_logins=$rrd:ftp_bad_logins:AVERAGE",
		"DEF:anon_logins=$rrd:ftp_anon_logins:AVERAGE",
		"CDEF:allvalues=logins,good_logins,bad_logins,anon_logins,+,+,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_ftp2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Logins/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:logins=$rrd:ftp_logins:AVERAGE",
			"DEF:good_logins=$rrd:ftp_good_logins:AVERAGE",
			"DEF:bad_logins=$rrd:ftp_bad_logins:AVERAGE",
			"DEF:anon_logins=$rrd:ftp_anon_logins:AVERAGE",
			"CDEF:allvalues=logins,good_logins,bad_logins,anon_logins,+,+,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /ftp2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "'>\n");
		}
	}

	@riglim = @{setup_riglim($rigid[2], $limit[2])};
	undef(@tmp);
	undef(@tmpz);
	undef(@CDEF);
	push(@tmp, "AREA:B_up#44EE44:Upload");
	push(@tmp, "AREA:B_dn#4444EE:Download");
	push(@tmp, "AREA:B_dn#4444EE:");
	push(@tmp, "AREA:B_up#44EE44:");
	push(@tmp, "LINE1:B_dn#0000EE");
	push(@tmp, "LINE1:B_up#00EE00");
	push(@tmpz, "AREA:B_up#44EE44:Upload");
	push(@tmpz, "AREA:B_dn#4444EE:Download");
	push(@tmpz, "AREA:B_dn#4444EE:");
	push(@tmpz, "AREA:B_up#44EE44:");
	push(@tmpz, "LINE1:B_dn#0000EE");
	push(@tmpz, "LINE1:B_up#00EE00");
	push(@CDEF, "CDEF:B_up=up");
	if(lc($config->{netstats_mode} || "") eq "separated") {
		push(@CDEF, "CDEF:B_dn=dn,-1,*");
	} else {
		push(@CDEF, "CDEF:B_dn=dn");
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
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG3",
		"--title=$config->{graphs}->{_ftp3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=bytes/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:dn=$rrd:ftp_bytes_dn:AVERAGE",
		"DEF:up=$rrd:ftp_bytes_up:AVERAGE",
		"CDEF:allvalues=dn,up,+",
		@CDEF,
		@tmp);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
			"--title=$config->{graphs}->{_ftp3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=bytes/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:dn=$rrd:ftp_bytes_dn:AVERAGE",
			"DEF:up=$rrd:ftp_bytes_up:AVERAGE",
			"CDEF:allvalues=dn,up,+",
			@CDEF,
			@tmpz);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /ftp3/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "'>\n");
		}
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
