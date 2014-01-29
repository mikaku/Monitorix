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

package emailreports;

use strict;
use warnings;
use Monitorix;
use MIME::Lite;
use LWP::UserAgent;
use Exporter 'import';
our @EXPORT = qw(emailreports_send);

sub emailreports_send {
	my $myself = (caller(0))[3];
	my ($config, $report, $when, $debug) = @_;
	my $emailreports = $config->{emailreports};

	my $n;
	my $base_cgi = $config->{base_cgi};
	my $imgs_dir = $config->{imgs_dir};
	my $images;
	
	my $self_signed_certs = $config->{use_self_signed_certificates};

	logger("$myself: sending $report reports.");

	my $uri = URI->new($emailreports->{url_prefix});
	my $hostname = $uri->host;

	my $html = <<"EOF";
<html>
  <body bgcolor='FFFFFF' vlink='#888888' link='#888888'>
  <table cellspacing='5' cellpadding='0' bgcolor='CCCCCC' border='1'>
  <tr>
  <td bgcolor='777777'>
  <font face='Verdana, sans-serif' color='CCCC00'>
    <font size='5'><b>&nbsp;&nbsp;Host:&nbsp;<b></font>
  </font>
  </td>
  <td bgcolor='FFFFFF'>
  <font face='Verdana, sans-serif' color='000000'>
    <font size='5'><b>&nbsp;&nbsp;$hostname&nbsp;&nbsp;</b></font>
  </font>
  </td>
  <td bgcolor='777777'>
  <font face='Verdana, sans-serif' color='CCCC00'>
    <font size='5'><b>&nbsp;&nbsp;$report&nbsp;&nbsp;<b></font>
  </font>
  </td>
  </tr>
  </table>
  <br>
EOF
	my $html_footer = <<EOF;
  <p>
  <a href='http://www.monitorix.org'><img src='cid:image_logo' border='0'></a>
  <br>
  <font face='Verdana, sans-serif' color='000000' size='-2'>
Copyright &copy; 2005-2013 Jordi Sanfeliu
  </font>
  </body>
</html>
EOF

	foreach (split(',', $emailreports->{$report}->{graphs})) {
		my $g = trim($_);

		# generate the graphs and get the html source
		my $url = $emailreports->{url_prefix} . $base_cgi . "/monitorix.cgi?mode=localhost&graph=_$g&when=$when&color=white";
		my $ua = LWP::UserAgent->new(timeout => 30);
		if ($self_signed_certs == 1) {
			$ua->ssl_opts(verify_hostname => 0);
		}
		my $response = $ua->request(HTTP::Request->new('GET', $url));

		my $data = $response->content;
		$data =~ s/\n/@@@/g;
		(my $graph) = $data =~ m/<!-- graph table begins -->@@@(.*?)<!-- graph table ends -->/;

		if(!$graph) {
			logger("$myself: unable to retrieve graphs from '$g'. It's enabled?");
			next;
		}

		$graph =~ s/@@@/\n/g;

		$graph =~ s/<a href=.*?>//g;
		$graph =~ s/><\/a>/>/g;

		# get the images
		my @tmp = ();
		$n = 1;
		foreach (split('\n', $graph)) {
			if(/<img src=/) {
				push(@tmp, "<img src='cid:image_$g$n' border='0'>");
				$images->{"image_$g$n"} = "";

				($url) = $_ =~ m/<img src='(.*?)' /;
				$response = $ua->request(HTTP::Request->new('GET', $url));
				$images->{"image_$g$n"} = $response->content;
				$n++;
			} else {
				push(@tmp, $_);
			}
		}

		$html .= join("\n", @tmp);
		$html .= "<br>";
	}

	$html .= $html_footer;

	# create the multipart container and add attachments
	foreach (split(',', $emailreports->{$report}->{to})) {
		my $to = trim($_);

		my $msg = new MIME::Lite(
			From		=> $emailreports->{from_address},
			To		=> $to,
			Subject		=> "Monitorix: '$report' Report",
			Type		=> "multipart/related",
			Organization	=> "Monitorix",
		);

		$msg->attach(
			Type		=> 'text/html',
			Data		=> $html,
		);
		$msg->attach(
			Type		=> 'image/png',
			Id		=> 'image_logo',
			Path		=> $config->{base_dir} . $config->{logo_bottom},
		);
		while (my ($key, $val) = each(%{$images})) {
			$msg->attach(
				Type		=> 'image/png',
				Id		=> $key,
				Data		=> $val,
			);
		}

		$msg->send('smtp', $emailreports->{smtp_hostname}, Timeout => 60);
		logger("\t$myself: to: $to") if $debug;
	}
}

1;
