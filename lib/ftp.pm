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

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
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

	my @data;
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
	if($config->{ftp_hist} > 0) {	# avoids initial spike
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

	my $ftp = $config->{ftp};
	my @rigid = split(',', $ftp->{rigid});
	my @limit = split(',', $ftp->{limit});
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};

	my $u = "";
	my $width;
	my $height;
	my @riglim;
	my @tmp;
	my @tmpz;
	my $n;
	my $err;

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
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		print("Time    Dnloads Uploads  Mkdirs  Rmdirs Deletes Listing  Logins GLogins BLogins ALogins BytesDn BytesUp\n");
		print("------------------------------------------------------------------------------------------------------- \n");
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
			printf(" %2d$tf->{tc}    %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d %7d\n", $time, @row);
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
	my $PNG1z = $u . $package . "1z." . $tf->{when} . ".png";
	my $PNG2z = $u . $package . "2z." . $tf->{when} . ".png";
	my $PNG3z = $u . $package . "3z." . $tf->{when} . ".png";
	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	if($title) {
		main::graph_header($title, 2);
	}
	if(trim($rigid[0]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[0]));
	} else {
		if(trim($rigid[0]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[0]));
			push(@riglim, "--rigid");
		}
	}
	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$colors->{title_bg_color}'>\n");
	}
	push(@tmp, "LINE1:retr#FFA500:Files downloaded (RETR)");
	push(@tmp, "GPRINT:retr:LAST: Current\\: %3.0lf");
	push(@tmp, "GPRINT:retr:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:retr:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:retr:MAX:   Max\\: %3.0lf\\n");
	push(@tmp, "LINE1:stor#EEEE44:Files uploaded (STOR)");
	push(@tmp, "GPRINT:stor:LAST:   Current\\: %3.0lf");
	push(@tmp, "GPRINT:stor:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:stor:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:stor:MAX:   Max\\: %3.0lf\\n");
	push(@tmp, "LINE1:mkd#EE4444:Dirs created (MKD)");
	push(@tmp, "GPRINT:mkd:LAST:      Current\\: %3.0lf");
	push(@tmp, "GPRINT:mkd:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:mkd:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:mkd:MAX:   Max\\: %3.0lf\\n");
	push(@tmp, "LINE1:rmd#44EE44:Dirs deleted (RMD)");
	push(@tmp, "GPRINT:rmd:LAST:      Current\\: %3.0lf");
	push(@tmp, "GPRINT:rmd:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:rmd:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:rmd:MAX:   Max\\: %3.0lf\\n");
	push(@tmp, "LINE1:dele#EE44EE:Files deleted (DELE)");
	push(@tmp, "GPRINT:dele:LAST:    Current\\: %3.0lf");
	push(@tmp, "GPRINT:dele:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:dele:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:dele:MAX:   Max\\: %3.0lf\\n");
	push(@tmp, "LINE1:mlsd#44EEEE:Dir listings (MLSD)");
	push(@tmp, "GPRINT:mlsd:LAST:     Current\\: %3.0lf");
	push(@tmp, "GPRINT:mlsd:AVERAGE:   Average\\: %3.0lf");
	push(@tmp, "GPRINT:mlsd:MIN:   Min\\: %3.0lf");
	push(@tmp, "GPRINT:mlsd:MAX:   Max\\: %3.0lf\\n");
	push(@tmpz, "LINE1:retr#FFA500:Files downloaded (RETR)");
	push(@tmpz, "LINE1:stor#EEEE44:Files uploaded (STOR)");
	push(@tmpz, "LINE1:mkd#EE4444:Dirs created (MKD)");
	push(@tmpz, "LINE1:rmd#44EE44:Dirs deleted (RMD)");
	push(@tmpz, "LINE1:dele#EE44EE:Files deleted (DELE)");
	push(@tmpz, "LINE1:mlsd#44EEEE:Dir listings (MLSD)");
	($width, $height) = split('x', $config->{graph_size}->{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$config->{graphs}->{_ftp1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Commands/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:retr=$rrd:ftp_retr:AVERAGE",
		"DEF:stor=$rrd:ftp_stor:AVERAGE",
		"DEF:mkd=$rrd:ftp_mkd:AVERAGE",
		"DEF:rmd=$rrd:ftp_rmd:AVERAGE",
		"DEF:dele=$rrd:ftp_dele:AVERAGE",
		"DEF:mlsd=$rrd:ftp_mlsd:AVERAGE",
		"COMMENT: \\n",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$config->{graphs}->{_ftp1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Commands/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:retr=$rrd:ftp_retr:AVERAGE",
			"DEF:stor=$rrd:ftp_stor:AVERAGE",
			"DEF:mkd=$rrd:ftp_mkd:AVERAGE",
			"DEF:rmd=$rrd:ftp_rmd:AVERAGE",
			"DEF:dele=$rrd:ftp_dele:AVERAGE",
			"DEF:mlsd=$rrd:ftp_mlsd:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /ftp1/)) {
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

	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}
	undef(@riglim);
	if(trim($rigid[1]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[1]));
	} else {
		if(trim($rigid[1]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[1]));
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
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
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$config->{graphs}->{_ftp2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Logins/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:logins=$rrd:ftp_logins:AVERAGE",
		"DEF:good_logins=$rrd:ftp_good_logins:AVERAGE",
		"DEF:bad_logins=$rrd:ftp_bad_logins:AVERAGE",
		"DEF:anon_logins=$rrd:ftp_anon_logins:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$config->{graphs}->{_ftp2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Logins/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:logins=$rrd:ftp_logins:AVERAGE",
			"DEF:good_logins=$rrd:ftp_good_logins:AVERAGE",
			"DEF:bad_logins=$rrd:ftp_bad_logins:AVERAGE",
			"DEF:anon_logins=$rrd:ftp_anon_logins:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /ftp2/)) {
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

	undef(@riglim);
	if(trim($rigid[2]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[2]));
	} else {
		if(trim($rigid[2]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[2]));
			push(@riglim, "--rigid");
		}
	}
	undef(@tmp);
	undef(@tmpz);
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
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$config->{graphs}->{_ftp3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=bytes/s",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:B_dn=$rrd:ftp_bytes_dn:AVERAGE",
		"DEF:B_up=$rrd:ftp_bytes_up:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$config->{graphs}->{_ftp3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=bytes/s",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:B_dn=$rrd:ftp_bytes_dn:AVERAGE",
			"DEF:B_up=$rrd:ftp_bytes_up:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /ftp3/)) {
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

	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		main::graph_footer();
	}
	print("  <br>\n");
	return;
}

1;
