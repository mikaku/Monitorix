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
use POSIX qw(strftime);
use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

sub logger {
	my $url = shift;

	print STDERR localtime() . " - [$ENV{REMOTE_ADDR}] The requested URL $url was not found on this server.\n";
}

sub handle_request {
	my ($self, $cgi) = @_;
	my $target;
	my @data;

	return if fork();	# parent returns

	my $url = $cgi->path_info();
	print STDERR "'$url'\n";

	# sanitizes the $target
	$target = $url;
	while() {
		my $cur = length($target);
		$target =~ s/\.\.\///;
		$target =~ s/^\///;
		last unless $cur ne length $target;
	}
	$target = "/$target";

	$target =~ s/^\///;	# removes the leading slash
	$target = "index.html" unless $target;
	if($target eq "monitorix.cgi") {
#		chdir("cgi");
		chdir("/home/jordi/github/Monitorix/");		# XXX
		open(P, "./$target |");
		@data = <P>;
		close(P);
	} else {
		if(open(IN, $target)) {
			@data = <IN>;
			close(IN);
		}
	}

	if(scalar(@data)) {
		print "HTTP/1.0 200 OK\r\n";
		print "Date: " . strftime("%a, %d %b %Y %H:%M:%S %z", localtime) . "\r\n";
		print "Server: Monitorix HTTP Server\r\n";
		print "Connection: close\r\n";
		print "Content-Type: text/html; charset=ISO-8859-1\r\n";
		print "\r\n";
		foreach(@data) {
			print $_;
		}
	} else {
		print "HTTP/1.0 404 Not found\r\n";
		print "Date: " . strftime("%a, %d %b %Y %H:%M:%S %z", localtime) . "\r\n";
		print "Server: Monitorix HTTP Server\r\n";
		print "Connection: close\r\n";
		print "Content-Type: text/html; charset=ISO-8859-1\r\n";
		print "\r\n";
		print "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\r\n";
		print "<html><head>\r\n";
		print "<title>404 Not Found</title>\r\n";
		print "</head><body>\r\n";
		print "<h1>Not Found</h1>\r\n";
		print "The requested URL $url was not found on this server.<p>\r\n";
		print "<hr>\r\n";
		print "<address>Monitorix HTTP Server listening on 8080</address>\r\n";
		print "</body></html>\r\n";
		logger($url);
	}

#	use Data::Dumper;
#	print "<pre>";
#	print Dumper(\@_);
#	print Dumper(\%ENV);

	exit(0);
}

1;
