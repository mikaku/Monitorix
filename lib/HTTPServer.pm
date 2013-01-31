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

package HTTPServer;

use strict;
use warnings;
use Monitorix;
use POSIX qw(strftime getpid);
use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

my %dispatch = (
	'/' 			=> \&do_req,
	'/logo_top.png' 	=> \&do_req,
	'/logo_bot.png' 	=> \&do_req,
	'/monitorixico.png' 	=> \&do_req,
	'/monitorix.cgi' 	=> \&do_req,
);

sub handle_request {
	my ($self, $cgi) = @_;
	my $method = $ENV{REQUEST_METHOD};

	return if fork();	# parent returns

	my $url = $cgi->path_info();
	print STDERR getpid() . " = '$url'\n";

	my $handler = $dispatch{$url};

	# sanitizes the $url
	while() {
		my $cur = length($url);
		$url =~ s/\.\.\///;
		$url =~ s/^\///;
		last unless $cur ne length $url;
	}
	$url = "/$url";


	# XXX
	print "HTTP/1.0 200 OK\r\n";
	do_req($url, $cgi);
	exit;


	if(ref($handler) eq "CODE") {
		print "HTTP/1.0 200 OK\r\n";
		$handler->($url, $cgi);
	} else {
		print "HTTP/1.0 404 Not found\r\n";
		print   $cgi->header,
			$cgi->start_html('404 Not Found'),
			$cgi->h1('Not Found'),
			$cgi->end_html;
		print "The requested URL $url was not found on this server.<p>";
		print "<hr>";
		print "<i>Monitorix HTTP Server listening on 8080</i>";
		print "<p>";
	}

	if (lc($method) eq 'post') {
		print "Received POST request";
	} else {
		print "Received request of type $method";
	}

#	use Data::Dumper;
#	print "<pre>";
#	print Dumper(\@_);
	exit(0);
}

sub do_req {
	my ($url, $cgi) = @_;
	return if !ref $cgi;

	print STDERR "\t$url\n";

#	my $who = $cgi->param('name');
#	print $cgi->header,
#		$cgi->start_html("Hello"),
#		$cgi->h1("Hello $who!"),
#		$cgi->end_html;

	print "Date: " . strftime("%a, %d %b %Y %H:%M:%S %z", localtime) . "\r\n";
	print "Server: Monitorix HTTP Server\r\n";
	print "Connection: close\r\n";
	print $cgi->header;

	$url =~ s/^\///;	# removes the leading slash
	$url = "index.html" unless $url;
	if($url eq "monitorix.cgi") {
#		chdir("cgi");
		chdir("/home/jordi/github/Monitorix/");		# XXX
		open(P, "./$url |");
		foreach(<P>) {
			print $_;
		}
		close(P);
	} else {
		if(open(IN, $url)) {
			while(<IN>) {
				print $_;
			}
			close(IN);
		} else {
			print "ERROR: '$url' not found!<br>";
		}
	}
}


#sub handle_request {
#	my ($self, $cgi) = @_;
#	my $method = $ENV{REQUEST_METHOD};
#	if (lc($method) == 'post') {
#		my $file = $cgi->param('POSTDATA');
#		open OUT, '>file.xml' or warn $!;
#		print OUT $file;
#		close OUT;
#		print 'Received data.';
#	} else {
#		print 'Please POST a file.';
#	}
#}

1;
