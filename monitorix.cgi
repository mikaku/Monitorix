#!/usr/bin/env perl
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

use strict;
use warnings;
use File::Basename;
use FindBin qw($Bin);
use lib $Bin . "/lib", "/usr/lib/monitorix";

use Monitorix;
use CGI qw(:standard);
use Config::General;
use POSIX;
use RRDs;
use Encode;

my %config;
my %cgi;
my %colors;
my %tf;
my @version12;
my @version12_small;


sub multihost {
	my ($config, $colors, $cgi) = @_;

	my $n;
	my $n2;
	my @host;
	my @url;
	my @foot_url;
	my $multihost = $config->{multihost};

	if($cgi->{val} =~ m/group(\d*)/) {
		my @remotegroup_desc;

		# all groups
		if($cgi->{val} eq "group") {
			my @remotegroup_list = split(',', $multihost->{remotegroup_list});
			for($n = 0; $n < scalar(@remotegroup_list); $n++) {
				scalar(my @tmp = split(',', $multihost->{remotegroup_desc}->{$n}));
				for($n2 = 0; $n2 < scalar(@tmp); $n2++) {
					push(@remotegroup_desc, trim($tmp[$n2]));
				}
			}
		}

		# specific group
		if($cgi->{val} =~ m/group(\d+)/) {
			my $gnum = int($1);
			@remotegroup_desc = split(',', $multihost->{remotegroup_desc}->{$gnum});
		}

		my @remotehost_list = split(',', $multihost->{remotehost_list});
		for($n = 0; $n < scalar(@remotegroup_desc); $n++) {
			my $h = trim($remotegroup_desc[$n]);
			for($n2 = 0; $n2 < scalar(@remotehost_list); $n2++) {
				my $h2 = trim($remotehost_list[$n2]);
				if($h eq $h2) {
					push(@host, $h);
					push(@url, trim((split(',', $multihost->{remotehost_desc}->{$n2}))[0]) . trim((split(',', $multihost->{remotehost_desc}->{$n2}))[2]));
					push(@foot_url, trim((split(',', $multihost->{remotehost_desc}->{$n2}))[0]) . trim((split(',', $multihost->{remotehost_desc}->{$n2}))[1]));
				}
			}
		}
	} else {
		my @remotehost_list = split(',', $multihost->{remotehost_list});
		for($n = 0; $n < scalar(@remotehost_list); $n++) {
			push(@host, trim($remotehost_list[$n]));
			push(@url, trim((split(',', $multihost->{remotehost_desc}->{$n}))[0]) . trim((split(',', $multihost->{remotehost_desc}->{$n}))[2]));
			push(@foot_url, trim((split(',', $multihost->{remotehost_desc}->{$n}))[0]) . trim((split(',', $multihost->{remotehost_desc}->{$n}))[1]));
		}
	}

	$multihost->{graphs_per_row} = 1 unless $multihost->{graphs_per_row} > 1;
	my $graph = ($cgi->{graph} eq "all" || $cgi->{graph} =~ m/group\[0-9]*/) ? "_system1" : $cgi->{graph};

	if($cgi->{val} eq "all" || $cgi->{val} =~ m/group[0-9]*/) {
		if($cgi->{graph} eq "all") {
			print "<table class='table-module' width='1' >\n";
			my $g = 0;
			foreach (split(',', $config{graph_name})) {
				my $gn = trim($_);
				if(lc($config{graph_enable}->{$gn}) eq "y") {
					if(!$g) {
						print " <tr>\n";
						for($n = 0; $n < scalar(@host); $n++) {
							print "  <td class='text-title-multihost'>\n";
							print "   <b>&nbsp;&nbsp;" . $host[$n] . "</b>\n";
							print "  </td>\n";
						}
						print " </tr>\n";
					}
					for(my $sg = 1; $config{graphs}->{"_$gn$sg"}; $sg++) {
						my $sgd = $sg;
						if($gn eq "fs" || $gn eq "net") {
							$sgd = sprintf("%02d", $sg);
						}
						print " <tr>\n";
						for($n = 0; $n < scalar(@host); $n++) {
							print "  <td  style='vertical-align: top; height: 10%; width: 10%;'>\n";
							print "   <iframe src='" . $url[$n] . "/monitorix.cgi?mode=localhost&when=$cgi->{when}&graph=_${gn}$sgd&color=$cgi->{color}&silent=imagetag' height=201 width=397 frameborder=0 marginwidth=0 marginheight=0 scrolling=no></iframe>\n";
							print "  </td>\n";
						}
						print " </tr>\n";
					}
				}
				$g++;
			}
			print "</table>\n";
			print "<br>\n";
		} else {
			for($n = 0; $n < scalar(@host); $n += $multihost->{graphs_per_row}) {
				print "<table class='table-module' width='1' >\n";
				print " <tr>\n";
				for($n2 = 0; $n2 < $multihost->{graphs_per_row}; $n2++) {
					if($n < scalar(@host)) {
						print "  <td class='text-title-multihost'>\n";
						print "   <b>&nbsp;&nbsp;" . $host[$n] . "</b>\n";
						print "  </td>\n";
					}
					$n++;
				}
				print " </tr>\n";
				print " <tr>\n";
				for($n2 = 0, $n = $n - $multihost->{graphs_per_row}; $n2 < $multihost->{graphs_per_row}; $n2++) {
					if($n < scalar(@host)) {
						print "  <td  style='vertical-align: top; height: 10%; width: 10%;'>\n";
						print "   <iframe src='" . $url[$n] . "/monitorix.cgi?mode=localhost&when=$cgi->{when}&graph=$graph&color=$cgi->{color}&silent=imagetag' height=201 width=397 frameborder=0 marginwidth=0 marginheight=0 scrolling=no></iframe>\n";
						print "  </td>\n";
	
					}
					$n++;
				}
				print " </tr>\n";
				print " <tr>\n";
				for($n2 = 0, $n = $n - $multihost->{graphs_per_row}; $n2 < $multihost->{graphs_per_row}; $n2++) {
					if($n < scalar(@host)) {
					if(lc($multihost->{footer_url}) eq "y") {
						print "  <td class='text-title'>\n";
						print "   <font size='-1'>\n";
						print "    <b>&nbsp;&nbsp;<a href='" . $foot_url[$n] . "' style='color: " . $colors->{title_fg_color} . ";'>$foot_url[$n]</a></b>\n";
						print "  </td>\n";
					}
					}
					$n++;
				}
				$n = $n - $multihost->{graphs_per_row};
				print " </tr>\n";
				print "</table>\n";
				print "<br>\n";
			}
		}
	} else {
		if($cgi->{graph} eq "all") {
			print "     <iframe src='" . trim((split(',', $multihost->{remotehost_desc}->{$cgi->{val}}))[0]) . trim((split(',', $multihost->{remotehost_desc}->{$cgi->{val}}))[2]) . "/monitorix.cgi?mode=localhost&when=$cgi->{when}&graph=all&color=$cgi->{color}' height=100% width=100% frameborder=0 marginwidth=0 marginheight=0 scrolling=yes></iframe>\n";
		} else {
			print "  <table class='table-module' width='1' >\n";
			print "   <tr>\n";
			print "    <td class='text-title-multihost-one'>\n";
			print "    <b>&nbsp;&nbsp;" . $host[$cgi->{val}] . "</b>\n";
			print "    </td>\n";
			print "   </tr>\n";
			print "   <tr>\n";
			print "    <td class='text-title-multihost-one td-valign-top' height: 10%; width: 10%;'>\n";
			print "     <iframe src='" . trim((split(',', $multihost->{remotehost_desc}->{$cgi->{val}}))[0]) . trim((split(',', $multihost->{remotehost_desc}->{$cgi->{val}}))[2]) . "/monitorix.cgi?mode=localhost&when=$cgi->{when}&graph=$graph&color=$cgi->{color}&silent=imagetagbig' height=249 width=545 frameborder=0 marginwidth=0 marginheight=0 scrolling=no></iframe>\n";
			print "    </td>\n";
			print "   </tr>\n";
			print "   <tr>\n";
			if(lc($multihost->{footer_url}) eq "y") {
				print "   <td class='text-title'>\n";
				print "    <font size='-1'>\n";
				print "    <b>&nbsp;&nbsp;<a href='" . $foot_url[$cgi->{val}] . "' style='color: " . $colors->{title_fg_color} . ";'>$foot_url[$cgi->{val}]</a></b>\n";
				print "   </td>\n";
			}
			print "   </tr>\n";
			print "  </table>\n";
			print "  <br>\n";
		}
	}
}

sub graph_header {
	my ($title, $colspan) = @_;
	my @output;

	push(@output, "\n");
	push(@output, "<!-- graph table begins -->\n");
	push(@output, "  <table class='table-module' width='1' >\n");
	push(@output, "    <tr>\n");
	push(@output, "      <td class='td-title' colspan='$colspan'>\n");
	push(@output, "          <b>&nbsp;&nbsp;$title</b>\n");
	push(@output, "      </td>\n");
	push(@output, "    </tr>\n");
	return @output;
}

sub graph_footer {
	my @output;

	push(@output, "  </table>\n");
	push(@output, "<!-- graph table ends -->\n");
	return @output;
}


# MAIN
# ----------------------------------------------------------------------------
open(IN, dirname(__FILE__)."/monitorix.conf.path");
my $config_path = <IN>;
chomp($config_path);
close(IN);

if(! -f $config_path) {
	print(<< "EOF");
Content-Type: text/plain
<pre>
FATAL: Monitorix is unable to continue!
=======================================

File 'monitorix.conf.path' was not found.

Please make sure that 'base_dir' option is correctly configured and this
CGI (monitorix.cgi) is located in the 'base_dir'/cgi/ directory.

And don't forget to restart Monitorix for the changes to take effect!
EOF
	die "FATAL: File 'monitorix.conf.path' was not found!";
}

# load main configuration file
my $conf = new Config::General(
	-ConfigFile => $config_path,
);
%config = $conf->getall;

# load additional configuration files
if($config{include_dir} && opendir(DIR, $config{include_dir})) {
	my @files = grep { !/^[.]/ } readdir(DIR);
	closedir(DIR);
	foreach my $c (sort @files) {
		next unless -f $config{include_dir} . "/$c";
		next unless $c =~ m/\.conf$/;
		my $conf_inc = new Config::General(
			-ConfigFile => $config{include_dir} . "/$c",
		);
		my %config_inc = $conf_inc->getall;
		while(my ($key, $val) = each(%config_inc)) {
			if(ref($val) eq "HASH") {
				# two level options (a subsection)
				while(my ($key2, $val2) = each(%{$val})) {
					# delete first this whole subsection
					delete($config{$key}->{$key2});
					if(ref($val2) eq "HASH") {
						# three level options (a subsubsection)
						while(my ($key3, $val3) = each(%{$val2})) {
							$config{$key}->{$key2}->{$key3} = $val3;
							delete $config_inc{$key}->{$key2}->{$key3};
						}
						next;
					}
					$config{$key}->{$key2} = $val2;
					delete $config_inc{$key}->{$key2};
				}
				next;
			}
			# graph_name option is special
			if($key eq "graph_name") {
				$config{graph_name} .= ", $val";
				delete $config_inc{graph_name};
				next;
			}
			# one level options
			$config{$key} = $val;
			delete $config_inc{$key};
		}
	}
}

$config{url} = ($config{url_prefix_proxy} || "");
if(!$config{url}) {
	$config{url} = ($ENV{HTTPS} || ($config{httpd_builtin}->{https_url} || "n") eq "y") ? "https://" . $ENV{HTTP_HOST} : "http://" . $ENV{HTTP_HOST};
	$config{hostname} = $config{hostname} || $ENV{SERVER_NAME};
	if(!($config{hostname})) {	# called from the command line
		$config{hostname} = "127.0.0.1";
		$config{url} = "http://127.0.0.1";
	}
}
$config{url} .= $config{base_url};

our $mode = defined(param('mode')) ? param('mode') : '';
our $graph = param('graph');
our $when = param('when');
our $color = param('color');
our $val = defined(param('val')) ? param('val') : '';
our $silent = defined(param('silent')) ? param('silent') : '';
if($mode ne "localhost") {
	($mode, $val)  = split(/\./, $mode);
}

# this should disarm all XSS and Cookie Injection attempts
my $OK_CHARS='-a-zA-Z0-9_';	# a restrictive list of valid chars
$graph =~ s/[^$OK_CHARS]/_/go;	# only $OK_CHARS are allowed
$mode =~ s/[^$OK_CHARS]/_/go;	# only $OK_CHARS are allowed
$when =~ s/[^$OK_CHARS]/_/go;	# only $OK_CHARS are allowed
$color =~ s/[^$OK_CHARS]/_/go;	# only $OK_CHARS are allowed
$val =~ s/[^$OK_CHARS]/_/go;	# only $OK_CHARS are allowed
$silent =~ s/[^$OK_CHARS]/_/go;	# only $OK_CHARS are allowed

#$graph =~ s/\&/&amp;/g;
#$graph =~ s/\</&lt;/g;
#$graph =~ s/\>/&gt;/g;
#$graph =~ s/\"/&quot;/g;
#$graph =~ s/\'/&#x27;/g;
#$graph =~ s/\(/&#x28;/g;
#$graph =~ s/\)/&#x29;/g;
#$graph =~ s/\//&#x2F;/g;

if(lc($config{httpd_builtin}->{enabled}) ne "y") {
	print("Content-Type: text/html\n");
	print("\n");
}

# get the current OS and kernel version
my $release;
($config{os}, undef, $release) = uname();
if(!($release =~ m/^(\d+)\.(\d+)/)) {
	die "FATAL: unable to get the kernel version.";
}
$config{kernel} = "$1.$2";

$colors{graph_colors} = ();
$colors{warning_color} = "--color=CANVAS#880000";

# keep backwards compatibility for v3.2.1 and less
if(ref($config{theme}) ne "HASH") {
	delete($config{theme});
}

if(!$config{theme}->{$color}) {
	$color = "white";

	$config{theme}->{$color}->{main_bg} = "FFFFFF";
	$config{theme}->{$color}->{main_fg} = "000000";
	$config{theme}->{$color}->{title_bg} = "777777";
	$config{theme}->{$color}->{title_fg} = "CCCC00";
	$config{theme}->{$color}->{graph_bg} = "CCCCCC";
	$config{theme}->{$color}->{gap} = "000000";
}

if($color eq "black") {
	push(@{$colors{graph_colors}}, "--color=CANVAS#" . $config{theme}->{$color}->{canvas});
	push(@{$colors{graph_colors}}, "--color=BACK#" . $config{theme}->{$color}->{back});
	push(@{$colors{graph_colors}}, "--color=FONT#" . $config{theme}->{$color}->{font});
	push(@{$colors{graph_colors}}, "--color=MGRID#" . $config{theme}->{$color}->{mgrid});
	push(@{$colors{graph_colors}}, "--color=GRID#" . $config{theme}->{$color}->{grid});
	push(@{$colors{graph_colors}}, "--color=FRAME#" . $config{theme}->{$color}->{frame});
	push(@{$colors{graph_colors}}, "--color=ARROW#" . $config{theme}->{$color}->{arrow});
	push(@{$colors{graph_colors}}, "--color=SHADEA#" . $config{theme}->{$color}->{shadea});
	push(@{$colors{graph_colors}}, "--color=SHADEB#" . $config{theme}->{$color}->{shadeb});
	push(@{$colors{graph_colors}}, "--color=AXIS#" . $config{theme}->{$color}->{axis})
		if defined($config{theme}->{$color}->{axis});
}
$colors{bg_color} = $config{theme}->{$color}->{main_bg};
$colors{fg_color} = $config{theme}->{$color}->{main_fg};
$colors{title_bg_color} = $config{theme}->{$color}->{title_bg};
$colors{title_fg_color} = $config{theme}->{$color}->{title_fg};
$colors{graph_bg_color} = $config{theme}->{$color}->{graph_bg};
$colors{gap} = $config{theme}->{$color}->{gap};


($tf{twhen}) = ($when =~ m/^\d+(hour|day|week|month|year)$/);
($tf{nwhen} = $when) =~ s/$tf{twhen}// unless !$tf{twhen};
$tf{nwhen} = 1 unless $tf{nwhen};
$tf{twhen} = "day" unless $tf{twhen};
$tf{when} = $tf{nwhen} . $tf{twhen};

# toggle this to 1 if you want to maintain old (2.3-) Monitorix with Multihost
if($config{backwards_compat_old_multihost}) {
	$tf{when} = $tf{twhen};
}

# make sure that some options are correctly defined
if(!$config{global_zoom}) {
	$config{global_zoom} = 1;
}
if(!$config{image_format}) {
	$config{image_format} = "PNG";
}

our ($res, $tc, $tb, $ts);
if($tf{twhen} eq "day") {
	($tf{res}, $tf{tc}, $tf{tb}, $tf{ts}) = (3600, 'h', 24, 1);
}
if($tf{twhen} eq "week") {
	($tf{res}, $tf{tc}, $tf{tb}, $tf{ts}) = (108000, 'd', 7, 1);
}
if($tf{twhen} eq "month") {
	($tf{res}, $tf{tc}, $tf{tb}, $tf{ts}) = (216000, 'd', 30, 1);
}
if($tf{twhen} eq "year") {
	($tf{res}, $tf{tc}, $tf{tb}, $tf{ts}) = (5184000, 'd', 365, 1);
}


if($RRDs::VERSION > 1.2) {
	push(@version12, "--slope-mode");
	push(@version12, "--font=LEGEND:7:");
	push(@version12, "--font=TITLE:9:");
	push(@version12, "--font=UNIT:8:");
	if($RRDs::VERSION >= 1.3) {
		push(@version12, "--font=DEFAULT:0:Mono");
	}
	if($tf{twhen} eq "day") {
		push(@version12, "--x-grid=HOUR:1:HOUR:6:HOUR:6:0:%R");
	}
	push(@version12_small, "--font=TITLE:8:");
	push(@version12_small, "--font=UNIT:7:");
	if($RRDs::VERSION >= 1.3) {
		push(@version12_small, "--font=DEFAULT:0:Mono");
	}
}


if(!$silent) {
	my $title;
	my $str;
	my @output;

	my $piwik_code = "";
	my ($piwik_url, $piwik_sid, $piwik_img);

	# Piwik tracking code
	if(lc($config{piwik_tracking}->{enabled}) eq "y") {
		$piwik_url = $config{piwik_tracking}->{url} || "";
	        $piwik_sid = $config{piwik_tracking}->{sid} || "";
		$piwik_img = $config{piwik_tracking}->{img} || "";
		$piwik_code = <<"EOF";

<!-- Piwik -->
  <script type="text/javascript">
     var _paq = _paq || [];
     _paq.push(['trackPageView']);
     _paq.push(['enableLinkTracking']);
     (function() {
       var u=(("https:" == document.location.protocol) ? "https" : "http") + "$piwik_url";
       _paq.push(['setTrackerUrl', u+'piwik.php']);
       _paq.push(['setSiteId', $piwik_sid]);
       var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0]; g.type='text/javascript';
       g.defer=true; g.async=true; g.src=u+'piwik.js';
       s.parentNode.insertBefore(g,s);
     })();
  </script>
  <noscript>
    <p><img src="$piwik_img" style="border:0;" alt=""/></p>
  </noscript>
<!-- End Piwik Code -->
EOF
	}

	print("<!DOCTYPE html '-//W3C//DTD HTML 4.01 Final//EN'>\n");
	print("<html>\n");
	print("  <head>\n");
	print("    <title>$config{title}</title>\n");
	print("    <link rel='shortcut icon' href='" . $config{url} . "/" . $config{favicon} . "'>\n");
	print("    <link href='" . $config{url} . "/css/" . $color . ".css' rel='stylesheet'>\n");
	if($config{refresh_rate}) {
		print("    <meta http-equiv='Refresh' content='" . $config{refresh_rate} . "'>\n");
	}
	print("  </head>\n");
	print("  <body>\n");
	print("  $piwik_code\n");
	print("  <center>\n");
	push(@output, "  <table class='cgi-header-table' >\n");
	push(@output, "  <tr>\n");

	if(lc($config{enable_back_button} || "") eq "y") {
		push(@output, "  <span style='color:#888888;position:fixed;left:1em;font-size:32px;letter-spacing:-1px;'><a href='javascript:history.back()' style='text-decoration:none;'>&#9664;</a>\n");
	}

	if(($val ne "all" || $val ne "group") && $mode ne "multihost") {
		push(@output, "  <th class='td-title'><b>&nbsp;&nbsp;Host:&nbsp;</b></th>\n");
	}

	if($val =~ m/group(\d+)/) {
		my $gnum = $1;
		my $gname = (split(',', $config{multihost}->{remotegroup_list}))[$gnum];
		$gname = trim($gname);
		push(@output, "  <th class='td-title-host' ><b>&nbsp;&nbsp;$gname&nbsp;</b></td>\n");
	}

	push(@output, "  <td class='td-title-host' >\n");
	if($mode eq "localhost" || $mode eq "traffacct") {
		$title = $config{hostname};
	} elsif($mode eq "multihost") {
		if($graph ne "all") {
			my ($g1, $g2) = ($graph =~ /(_\D+).*?(\d)$/);
			if($g1 eq "_port") {
				$title = $config{graphs}->{$g1};
				$g2 = trim((split(',', $config{port}->{list}))[$g2]);
				$title .= " " . $g2;
				$g2 = (split(',', $config{port}->{desc}->{$g2}))[0];
				$title .= " (" . trim($g2) . ")";
			} else {
				$g2 = "" if $g1 eq "_proc";	# '_procn' must be converted to '_proc'
				$title = $config{graphs}->{$g1 . $g2};
			}
		} else {
			$title = $graph eq "all" ? "all graphs" : $graph;
		}
	}
	$title =~ s/ /&nbsp;/g;
	my $twhen = $tf{nwhen} > 1 ? "$tf{nwhen} $tf{twhen}" : $tf{twhen};
	$twhen .= "s" if $tf{nwhen} > 1;

	if($mode ne "multihost" || $graph ne "all" || $val eq "all") {
		print @output;
		print("    <b>&nbsp;&nbsp;$title&nbsp;&nbsp;</b>\n");
		print("  </td>\n");
		print("  <td class='td-title' ><b>&nbsp;&nbsp;last&nbsp;$twhen&nbsp;&nbsp;</b></td>\n");
		print("  </tr>\n");
		print("  </table>\n");
		print encode('utf-8', "    <h4 class='text-title-date'>" . strftime("%a %b %e %H:%M:%S %Z %Y", localtime) . "</h4>\n");
	}
}


$cgi{colors} = \%colors;
$cgi{tf} = \%tf;
$cgi{version12} = \@version12;
$cgi{version12_small} = \@version12_small;
$cgi{graph} = $graph;
$cgi{when} = $when;
$cgi{color} = $color;
$cgi{val} = $val;
$cgi{silent} = $silent;

if($mode eq "localhost") {
	my %outputs;	# a hash of arrays
	my @readers;	# array of file descriptors
	my @writers;	# array of file descriptors
	my $children = 0;

	foreach (split(',', $config{graph_name})) {
		my $gn = trim($_);
		my $g = "";
		if($graph ne "all") {
			($g) = ($graph =~ m/^_*($gn)\d*$/);
			next unless $g;
		}
		if(lc($config{graph_enable}->{$gn}) eq "y") {
			my $cgi = $gn . "_cgi";

			eval "use $gn qw(" . $cgi . ")";
			if($@) {
				print(STDERR "WARNING: unable to load module '$gn. $@'\n");
				next;
			}

			if($graph eq "all" || $gn eq $g) {
				no strict "refs";

				if(lc($config{enable_parallelizing} || "") eq "y") {
					pipe($readers[$children], $writers[$children]);
					$writers[$children]->autoflush(1);

					if(!fork()) {
						my $child;

						close($readers[$children]);

						pipe(CHILD_RDR, PARENT_WTR);
						PARENT_WTR->autoflush(1);

						if(!($child = fork())) {
							# child
							my @output;
							close(CHILD_RDR);
							@output = &$cgi($gn, \%config, \%cgi);
							print(PARENT_WTR @output);
							close(PARENT_WTR);
							exit(0);
						}

						# parent
						my @output;
						close(PARENT_WTR);
						@output = <CHILD_RDR>;
						close(CHILD_RDR);
						waitpid($child, 0);
						my $fd = $writers[$children];
						print($fd @output);
						close($writers[$children]);
						exit(0);
					}
					close($writers[$children]);
					$children++;

				} else {
					my @output = &$cgi($gn, \%config, \%cgi);
					print @output;
				}
			}
		}
	}
	if(lc($config{enable_parallelizing} || "") eq "y") {
		my $n;
		my @output;

		for($n = 0; $n < $children; $n++) {
			my $fd = $readers[$n];
			@output = <$fd>;
			close($readers[$n]);
			@{$outputs{$n}} = @output;
			waitpid(-1, 0);	# wait for each child
			print @{$outputs{$n}} if $outputs{$n};
		}
	}

} elsif($mode eq "multihost") {
	multihost(\%config, \%colors, \%cgi);

} elsif($mode eq "traffacct") {
	eval "use $mode qw(traffacct_cgi)";
	if($@) {
		print(STDERR "WARNING: unable to load module '$mode'. $@\n");
		exit;
	}
	traffacct_cgi($mode, \%config, \%cgi);
}

if(!$silent) {
	if($mode ne "multihost" || $graph ne "all" || $val eq "all") {
		print("\n");
		print("  </center>\n");
		print("<!-- footer begins -->\n");
		print("  <p class='text-copyright'>\n");
		print("  <a href='https://www.monitorix.org'><img src='" . $config{url} . "/" . $config{logo_bottom} . "' border='0'></a>\n");
		print("  <br>\n");
		print("Copyright &copy; 2005-2021 Jordi Sanfeliu\n");
	}
	print("  </body>\n");
	print("</html>\n");
	print("<!-- footer ends -->\n");
}

0;
