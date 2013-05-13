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
use Authen::Simple::Passwd;
use HTTP::Server::Simple::CGI;
use HTTP::Server::Simple::Authen;
use base qw( HTTP::Server::Simple::Authen HTTP::Server::Simple::CGI );



sub authen_handler {
    Authen::Simple::Passwd->new(passwd => $main::config{base_dir}.'/htpasswd');
}

sub logger {
	my ($url, $type) = @_;

	if(open(OUT, ">> $main::config{httpd_builtin}->{log_file}")) {
		if($type eq "OK") {
			print OUT localtime() . " - $type - [$ENV{REMOTE_ADDR}] \"$ENV{REQUEST_METHOD} $url - $ENV{HTTP_USER_AGENT}\"\n";
		} else {
			print OUT localtime() . " - $type - [$ENV{REMOTE_ADDR}] File does not exist: $url\n";
		}
		close(OUT);
	} else {
		print STDERR localtime() . " - ERROR: unable to open logfile '$main::config{httpd_builtin}->{log_file}'.\n";
	}
}

sub http_header {
	my ($code, $mimetype) = @_;

	if($code eq "200") {
		print "HTTP/1.0 200 OK\r\n";
	} else {
		print "HTTP/1.0 404 Not found\r\n";
	}

	print "Date: " . strftime("%a, %d %b %Y %H:%M:%S %z", localtime) . "\r\n";
	print "Server: Monitorix HTTP Server\r\n";
	print "Connection: close\r\n";

	if($mimetype =~ m/(html|cgi)/) {
		print "Content-Type: text/html; charset=UTF-8\r\n";
	} else {
		print "Content-Type: image/$mimetype;\r\n";
	}

	print "\r\n";
}

sub handle_request {
	my ($self, $cgi) = @_;
	
	if(lc($main::config{httpd_builtin}->{auth} eq "y")) {
		my $user = $self->authenticate();
    	return unless defined $user;
	}

	my $base_url = $main::config{base_url};
	my $base_cgi = $main::config{base_cgi};
	my $port = $main::config{httpd_builtin}->{port};
	my $mimetype;
	my $target;
	my $target_cgi;
	my @data;

	return if fork();	# parent returns

	my $url = $cgi->path_info();
	$0 = "monitorix-httpd";	# change process' name

	# sanitizes the $target
	$target = $url;
	while() {
		my $cur = length($target);
		$target =~ s/\.\.\///;
		$target =~ s/^\///;
		$target =~ s/\/$//;
		last unless $cur ne length($target);
	}
	$target = $target_cgi = "/$target";

	$target =~ s/^$base_url//;	# removes the 'base_url' part
	$target_cgi =~ s/^$base_cgi//;	# removes the 'base_cgi' part
	if(!$target || $target eq $base_url) {
		$target = "index.html" unless $target;
	}
	($mimetype) = ($target =~ m/.*\.(html|cgi|png)$/);

	$target =~ s/^\///;		# removes leading slash
	$target_cgi =~ s/^\///;		# removes leading slash
	if($target_cgi eq "monitorix.cgi") {
		chdir("cgi");
		open(EXEC, "./$target_cgi |");
		@data = <EXEC>;
		close(EXEC);
	} elsif($target) {
		if(open(IN, $target)) {
			@data = <IN>;
			close(IN);
		}
	}

	if(scalar(@data)) {
		http_header("200", $mimetype);
		foreach(@data) {
			print $_;
		}
		logger($url, "OK");
	} else {
		http_header("404", "html");
		print "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\r\n";
		print "<html><head>\r\n";
		print "<title>404 Not Found</title>\r\n";
		print "</head><body>\r\n";
		print "<h1>Not Found</h1>\r\n";
		print "The requested URL $url was not found on this server.<p>\r\n";
		print "<hr>\r\n";
		print "<address>Monitorix HTTP Server listening on $port</address>\r\n";
		print "</body></html>\r\n";
		logger($url, "ERROR");
	}

	exit(0);
}

1;
