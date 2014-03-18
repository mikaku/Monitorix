#!/usr/bin/env perl
#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2014 by Jordi Sanfeliu <jordi@fibranet.cat>
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
use FindBin qw($Bin);
use lib $Bin . "/lib", "/usr/lib/monitorix";

use Monitorix;
use CGI qw(:standard);
use Config::General;
use POSIX;
use RRDs;

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
					push(@url, (split(',', $multihost->{remotehost_desc}->{$n2}))[0] . (split(',', $multihost->{remotehost_desc}->{$n2}))[2]);
					push(@foot_url, (split(',', $multihost->{remotehost_desc}->{$n2}))[0] . (split(',', $multihost->{remotehost_desc}->{$n2}))[1]);
				}
			}
		}
	} else {
		my @remotehost_list = split(',', $multihost->{remotehost_list});
		for($n = 0; $n < scalar(@remotehost_list); $n++) {
			push(@host, trim($remotehost_list[$n]));
			push(@url, (split(',', $multihost->{remotehost_desc}->{$n}))[0] . (split(',', $multihost->{remotehost_desc}->{$n}))[2]);
			push(@foot_url, (split(',', $multihost->{remotehost_desc}->{$n}))[0] . (split(',', $multihost->{remotehost_desc}->{$n}))[1]);
		}
	}

	$multihost->{graphs_per_row} = 1 unless $multihost->{graphs_per_row} > 1;
	my $graph = ($cgi->{graph} eq "all" || $cgi->{graph} =~ m/group\[0-9]*/) ? "_system1" : $cgi->{graph};

	if($cgi->{val} eq "all" || $cgi->{val} =~ m/group[0-9]*/) {
		for($n = 0; $n < scalar(@host); $n += $multihost->{graphs_per_row}) {
			print "<table cellspacing='5' cellpadding='0' width='1' bgcolor='$colors->{graph_bg_color}' border='1'>\n";
			print " <tr>\n";
			for($n2 = 0; $n2 < $multihost->{graphs_per_row}; $n2++) {
				if($n < scalar(@host)) {
					print "  <td bgcolor='$colors->{title_bg_color}'>\n";
					print "   <font face='Verdana, sans-serif' color='$colors->{fg_color}'>\n";
					print "   <b>&nbsp;&nbsp;" . $host[$n] . "</b>\n";
					print "   </font>\n";
					print "  </td>\n";
				}
				$n++;
			}
			print " </tr>\n";
			print " <tr>\n";
			for($n2 = 0, $n = $n - $multihost->{graphs_per_row}; $n2 < $multihost->{graphs_per_row}; $n2++) {
				if($n < scalar(@host)) {
					print "  <td bgcolor='$colors->{title_bg_color}' style='vertical-align: top; height: 10%; width: 10%;'>\n";
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
					print "  <td bgcolor='$colors->{title_bg_color}'>\n";
					print "   <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n";
					print "   <font size='-1'>\n";
					print "    <b>&nbsp;&nbsp;<a href='" . $foot_url[$n] . "' style='{color: " . $colors->{title_fg_color} . "}'>$foot_url[$n]</a></b>\n";
					print "   </font></font>\n";
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
	} else {
		print "  <table cellspacing='5' cellpadding='0' width='1' bgcolor='$colors->{graph_bg_color}' border='1'>\n";
		print "   <tr>\n";
		print "    <td bgcolor='$colors->{title_bg_color}'>\n";
		print "    <font face='Verdana, sans-serif' color='$colors->{fg_color}'>\n";
		print "    <b>&nbsp;&nbsp;" . $host[$cgi->{val}] . "</b>\n";
		print "    </font>\n";
		print "    </td>\n";
		print "   </tr>\n";
		print "   <tr>\n";
		print "    <td bgcolor='$colors->{title_bg_color}' style='vertical-align: top; height: 10%; width: 10%;'>\n";
		print "     <iframe src='" . (split(',', $multihost->{remotehost_desc}->{$cgi->{val}}))[0] . (split(',', $multihost->{remotehost_desc}->{$cgi->{val}}))[2] . "/monitorix.cgi?mode=localhost&when=$cgi->{when}&graph=$graph&color=$cgi->{color}&silent=imagetagbig' height=249 width=545 frameborder=0 marginwidth=0 marginheight=0 scrolling=no></iframe>\n";
		print "    </td>\n";
		print "   </tr>\n";
		print "   <tr>\n";
		if(lc($multihost->{footer_url}) eq "y") {
			print "   <td bgcolor='$colors->{title_bg_color}'>\n";
			print "    <font face='Verdana, sans-serif' color='$colors->{title_fg_color}'>\n";
			print "    <font size='-1'>\n";
			print "    <b>&nbsp;&nbsp;<a href='" . $foot_url[$cgi->{val}] . "' style='{color: " . $colors->{title_fg_color} . "}'>$foot_url[$cgi->{val}]</a></b>\n";
			print "    </font></font>\n";
			print "   </td>\n";
		}
		print "   </tr>\n";
		print "  </table>\n";
		print "  <br>\n";
	}
}

sub graph_header {
	my ($title, $colspan) = @_;
	print("\n");
	print("<!-- graph table begins -->\n");
	print("  <table cellspacing='5' cellpadding='0' width='1' bgcolor='$colors{graph_bg_color}' border='1'>\n");
	print("    <tr>\n");
	print("      <td bgcolor='$colors{title_bg_color}' colspan='$colspan'>\n");
	print("        <font face='Verdana, sans-serif' color='$colors{title_fg_color}'>\n");
	print("          <b>&nbsp;&nbsp;$title</b>\n");
	print("        </font>\n");
	print("      </td>\n");
	print("    </tr>\n");
}

sub graph_footer {
	print("  </table>\n");
	print("<!-- graph table ends -->\n");
}


# MAIN
# ----------------------------------------------------------------------------
open(IN, "< monitorix.conf.path");
my $config_path = <IN>;
chomp($config_path);
close(IN);

if(! -f $config_path) {
	print(<< "EOF");
Content-Type: text/plain

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
	close(DIR);
	foreach my $c (sort @files) {
		next unless -f $config{include_dir} . "/$c";
		next unless $c =~ m/\.conf$/;
		my $conf_inc = new Config::General(
			-ConfigFile => $config{include_dir} . "/$c",
		);
		my %config_inc = $conf_inc->getall;
		my $g = $config_inc{graph_name};
		if(!$g) {
			next;
		}
		if(grep {trim($_) eq $g} (split(',', $config{graph_name}))) {
			next;
		}
		if(!$config_inc{graph_enable}->{$g}) {
			next;
		}
		if(!$config_inc{graph_title}->{$g}) {
			next;
		}
		if(!$config_inc{$g}) {
			next;
		}
		$config{graph_enable}->{$g} = $config_inc{graph_enable}->{$g};
		$config{$g} = $config_inc{$g};
		$config{graph_title}->{$g} = $config_inc{graph_title}->{$g};
		$config{graph_name} .= ", $g";
		foreach my $k (sort keys %{$config_inc{graphs}}) {
			$config{graphs}->{$k} = $config_inc{graphs}->{$k};
		}
		delete $config_inc{graph_name};
		delete $config_inc{graph_enable};
		delete $config_inc{$g};
		delete $config_inc{graph_title};
		delete $config_inc{graphs};
		@config{keys %config_inc} = values %config_inc;
	}
}

$config{url} = ($ENV{HTTPS} || ($config{httpd_builtin}->{https_url} || "n") eq "y") ? "https://" . $ENV{HTTP_HOST} : "http://" . $ENV{HTTP_HOST};
$config{hostname} = $config{hostname} || $ENV{SERVER_NAME};
if(!($config{hostname})) {	# called from the command line
	$config{hostname} = "127.0.0.1";
	$config{url} = "http://127.0.0.1";
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


if(lc($config{httpd_builtin}->{enabled} ne "y")) {
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


($tf{twhen}) = ($when =~ m/(hour|day|week|month|year)$/);
($tf{nwhen} = $when) =~ s/$tf{twhen}// unless !$tf{twhen};
$tf{nwhen} = 1 unless $tf{nwhen};
$tf{twhen} = "day" unless $tf{twhen};
$tf{when} = $tf{nwhen} . $tf{twhen};

# toggle this to 1 if you want to maintain old (2.3-) Monitorix with Multihost
if($config{backwards_compat_old_multihost}) {
	$tf{when} = $tf{twhen};
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

	print("<!DOCTYPE HTML PUBLIC '-//W3C//DTD HTML 3.2 Final//EN'>\n");
	print("<html>\n");
	print("  <head>\n");
	print("    <title>$config{title}</title>\n");
	print("    <link rel='shortcut icon' href='" . $config{url} . "/" . $config{favicon} . "'>\n");
	if($config{refresh_rate}) {
		print("    <meta http-equiv='Refresh' content='" . $config{refresh_rate} . "'>\n");
	}
	print("  </head>\n");
	print("  <body bgcolor='" . $colors{bg_color} . "' vlink='#888888' link='#888888'>\n");
	print("  <center>\n");
	print("  <table cellspacing='5' cellpadding='0' bgcolor='" . $colors{graph_bg_color} . "' border='1'>\n");
	print("  <tr>\n");

	if(($val ne "all" || $val ne "group") && $mode ne "multihost") {
		print("  <td bgcolor='" . $colors{title_bg_color} . "'>\n");
		print("  <font face='Verdana, sans-serif' color='" . $colors{title_fg_color} . "'>\n");
		print("    <font size='5'><b>&nbsp;&nbsp;Host:&nbsp;</b></font>\n");
		print("  </font>\n");
		print("  </td>\n");
	}

	if($val =~ m/group(\d+)/) {
		my $gnum = $1;
		my $gname = (split(',', $config{multihost}->{remotegroup_list}))[$gnum];
		$gname = trim($gname);
		print("  <td bgcolor='" . $colors{title_bg_color} . "'>\n");
		print("  <font face='Verdana, sans-serif' color='" . $colors{title_fg_color} . "'>\n");
		print("    <font size='5'><b>&nbsp;&nbsp;$gname&nbsp;</b></font>\n");
		print("  </font>\n");
		print("  </td>\n");
	}

	print("  <td bgcolor='" . $colors{bg_color} . "'>\n");
	print("  <font face='Verdana, sans-serif' color='" . $colors{fg_color} . "'>\n");
	if($mode eq "localhost" || $mode eq "traffacct") {
		$title = $config{hostname};
	} elsif($mode eq "multihost") {
		$graph = $graph eq "all" ? "_system1" : $graph;
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
	}
	$title =~ s/ /&nbsp;/g;
	print("    <font size='5'><b>&nbsp;&nbsp;$title&nbsp;&nbsp;</b></font>\n");
	print("  </font>\n");
	print("  </td>\n");
		print("  <td bgcolor='" . $colors{title_bg_color} . "'>\n");
		print("  <font face='Verdana, sans-serif' color='" . $colors{title_fg_color} . "'>\n");
		print("    <font size='5'><b>&nbsp;&nbsp;last&nbsp;$tf{twhen}&nbsp;&nbsp;</b></font>\n");
		print("  </font>\n");
		print("  </td>\n");
	print("  </tr>\n");
	print("  </table>\n");
	print("  <font face='Verdana, sans-serif' color='" . $colors{fg_color} . "'>\n");
	print("    <h4><font color='#888888'>" . strftime("%a %b %e %H:%M:%S %Z %Y", localtime) . "</font></h4>\n");
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
	foreach (split(',', $config{graph_name})) {
		my $g = trim($_);
		if(lc($config{graph_enable}->{$g}) eq "y") {
			my $cgi = $g . "_cgi";

			eval "use $g qw(" . $cgi . ")";
			if($@) {
				print(STDERR "WARNING: unable to find module '$g'\n");
				next;
			}

			if($graph eq "all" || $graph =~ m/^_$g\d+/) {
				no strict "refs";
				&$cgi($g, \%config, \%cgi);
			}
		}
	}
} elsif($mode eq "multihost") {
	multihost(\%config, \%colors, \%cgi);
} elsif($mode eq "traffacct") {
	eval "use $mode qw(traffacct_cgi)";
	if($@) {
		print(STDERR "WARNING: unable to find module '$mode'\n");
		exit;
	}
	traffacct_cgi($mode, \%config, \%cgi);
}

if(!$silent) {
	print("\n");
	print("  </font>\n");
	print("  </center>\n");
	print("<!-- footer begins -->\n");
	print("  <p>\n");
	print("  <a href='http://www.monitorix.org'><img src='" . $config{url} . "/" . $config{logo_bottom} . "' border='0'></a>\n");
	print("  <br>\n");
	print("  <font face='Verdana, sans-serif' color='" . $colors{fg_color} . "' size='-2'>\n");
	print("Copyright &copy; 2005-2014 Jordi Sanfeliu\n");
	print("  </font>\n");
	print("  </body>\n");
	print("</html>\n");
	print("<!-- footer ends -->\n");
}

0;
