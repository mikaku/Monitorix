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

package HTTPServer;

use strict;
use warnings;
use Monitorix qw(trim);
use POSIX qw(strftime);
use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);
use MIME::Base64 qw(decode_base64);
use Socket;

sub logger {
	my ($url, $type) = @_;

	if($main::config{httpd_builtin}->{log_file}) {
		if(open(OUT, ">> $main::config{httpd_builtin}->{log_file}")) {
			if($type eq "OK") {
				print OUT localtime() . " - $type - [$ENV{REMOTE_ADDR}] \"$ENV{REQUEST_METHOD} $url - " . ($ENV{HTTP_USER_AGENT} || "") . "\"\n";
			} elsif($type eq "NOTEXIST") {
				print OUT localtime() . " - $type - [$ENV{REMOTE_ADDR}] File does not exist: $url\n";
			} elsif($type eq "AUTHERR") {
				print OUT localtime() . " - $type - [$ENV{REMOTE_ADDR}] Authentication error: $url\n";
			} elsif($type eq "NOTALLOWED") {
				print OUT localtime() . " - $type - [$ENV{REMOTE_ADDR}] Access not allowed: $url\n";
			} else {
				print OUT localtime() . " - $type - [$ENV{REMOTE_ADDR}] $url\n";
			}
			close(OUT);
		} else {
			print STDERR localtime() . " - ERROR: unable to open logfile '$main::config{httpd_builtin}->{log_file}'.\n";
		}
	} else {
		my $msg;
		if($type eq "OK") {
			$msg = localtime() . " - $type - [$ENV{REMOTE_ADDR}] \"$ENV{REQUEST_METHOD} $url - " . ($ENV{HTTP_USER_AGENT} || "") . "\"\n";
		} elsif($type eq "NOTEXIST") {
			$msg = localtime() . " - $type - [$ENV{REMOTE_ADDR}] File does not exist: $url\n";
		} elsif($type eq "AUTHERR") {
			$msg = localtime() . " - $type - [$ENV{REMOTE_ADDR}] Authentication error: $url\n";
		} elsif($type eq "NOTALLOWED") {
			$msg = localtime() . " - $type - [$ENV{REMOTE_ADDR}] Access not allowed: $url\n";
		} else {
			$msg = localtime() . " - $type - [$ENV{REMOTE_ADDR}] $url\n";
		}
		print("$msg");
	}
}

sub check_passwd {
	my ($user, $pass) = @_;

	if(open(IN, $main::config{httpd_builtin}->{auth}->{htpasswd})) {
		while(<IN>) {
			my $line = trim($_);

			# append character ':' if not exist
			if(index($line, ":") < 0) {
				logger("Malformed line in " . $main::config{httpd_builtin}->{auth}->{htpasswd}, "ERROR");
				$line .= ":" if index($line, ":") < 0;
			}

			# discard that line if password is missing
			if(length($line) == index($line, ":") + 1) {
				logger("Malformed line in " . $main::config{httpd_builtin}->{auth}->{htpasswd}, "ERROR");
				next;
			}

			my %pair = split(':', $line);
			if($pair{$user || ""}) {
				chomp($pair{$user});
				if(crypt($pass, $pair{$user}) ne $pair{$user}) {
					next;
				}
				return 0;
			}
		}
		close(IN);
	} else {
		print STDERR localtime() . " - ERROR: can't open file '$main::config{httpd_builtin}->{auth}->{htpasswd}'.\n";
	}
	return 1;
}

sub ip_validity {
	my ($myip, $hosts) = @_;
	my $valid = 0;

	foreach my $address (split(',', $hosts)) {
		my $myip_bin = inet_aton($myip);

		$address = "0.0.0.0/0" if $address eq "all";
		my ($ip, $netmask) = split('/', trim($address) . "/");
		my $ip_bin = inet_aton($ip);

		$netmask = "255.255.255.255" if $netmask eq "";
		$netmask = unpack("%32b*", inet_aton($netmask)) if length($netmask) > 2;
		my $netmask_bin = ~pack("N", (2**(32-$netmask))-1);

		my $first_valid = unpack("N", $ip_bin & $netmask_bin) + ($netmask eq "32" ? 0 : 1);
		my $last_valid = unpack("N", $ip_bin | ~$netmask_bin) - ($netmask eq "32" ? 0 : 1);

		$myip_bin = unpack("N", $myip_bin);
		if($myip_bin >= $first_valid && $myip_bin <= $last_valid) {
			$valid++;
		}
	}
	return $valid;
}

sub http_header {
	my ($code, $mimetype) = @_;
	my $msg = $main::config{httpd_builtin}->{auth}->{msg} || "";
	my $hosts_deny = $main::config{httpd_builtin}->{auth}->{hosts_deny} || "";
	my $hosts_allow = $main::config{httpd_builtin}->{auth}->{hosts_allow} || "";

	if($code eq "200") {
		print "HTTP/1.0 200 OK\r\n";
	} elsif($code eq "401") {
		# check if the IP address is forced to auth
		my $denied;
		my $allowed = ip_validity($ENV{REMOTE_ADDR}, $hosts_allow);
		$denied = ip_validity($ENV{REMOTE_ADDR}, $hosts_deny) if !$allowed;
		if(!$allowed && $denied) {
			my (undef, $encoded_str) = split(' ', $ENV{HTTP_AUTHORIZATION} || "");
			my ($user, $pass) = split(':', decode_base64($encoded_str || ":"));

			if(check_passwd($user, $pass)) {
				print "HTTP/1.0 401 Access Denied\r\n";
				print "WWW-Authenticate: Basic realm=\"$msg\"\r\n";
				print "Content-Length: 0\r\n";
				print "\r\n";
				return 1;
			}
		}
		return 0;
	} elsif($code eq "404") {
		print "HTTP/1.0 404 Not found\r\n";
	} else {
		print "HTTP/1.0 403 Forbidden\r\n";
	}

	print "Date: " . strftime("%a, %d %b %Y %H:%M:%S %z", localtime) . "\r\n";
	print "Server: Monitorix HTTP Server\r\n";
	print "Connection: close\r\n";

	if($mimetype =~ m/(html|cgi)/) {
		print "Content-Type: text/html; charset=UTF-8\r\n";
	} elsif($mimetype eq "css") {
		print "Content-Type: text/css; charset=UTF-8\r\n";
	} elsif($mimetype eq "svg") {
		print "Content-Type: image/svg+xml; charset=UTF-8\r\n";
	} else {
		print "Content-Type: image/$mimetype;\r\n";
	}

	print "\r\n";
	return 0;
}

sub handle_request {
	my ($self, $cgi) = @_;
	my $base_url = $main::config{base_url};
	my $base_cgi = $main::config{base_cgi};
	my $host = $main::config{httpd_builtin}->{host} || "localhost";
	my $port = $main::config{httpd_builtin}->{port} || "8080";
	my $hosts_deny = $main::config{httpd_builtin}->{hosts_deny} || "";
	my $hosts_allow = $main::config{httpd_builtin}->{hosts_allow} || "";
	my $auth = lc($main::config{httpd_builtin}->{auth}->{enabled});
	my $mimetype;
	my $target;
	my $target_cgi;
	my @data;
	my $OK_CHARS='-a-zA-Z0-9_./';	# a restrictive list of valid chars

	return if fork();	# parent returns

	my $url = $cgi->path_info();
	my $url_disarmed = $url;

	# this should disarm all XSS and Cookie Injection attempts
	$url_disarmed =~ s/\&/&amp;/g;
	$url_disarmed =~ s/\</&lt;/g;
	$url_disarmed =~ s/\>/&gt;/g;
	$url_disarmed =~ s/\"/&quot;/g;
	$url_disarmed =~ s/\'/&#x27;/g;
	$url_disarmed =~ s/\(/&#x28;/g;
	$url_disarmed =~ s/\)/&#x29;/g;
	$url_disarmed =~ s/\//&#x2F;/g;

	$0 = "monitorix-httpd";	# change process' name

	# check if the IP address is allowed to connect
	my $denied;
	my $allowed = ip_validity($ENV{REMOTE_ADDR}, $hosts_allow);
	$denied = ip_validity($ENV{REMOTE_ADDR}, $hosts_deny) if !$allowed;
	if(!$allowed && $denied) {
		http_header("403", "html");
		print("<!DOCTYPE html '-//W3C//DTD HTML 4.01 Final//EN'>\r\n");
		print "<html><head>\r\n";
		print "<title>403 Forbidden</title>\r\n";
		print "</head><body>\r\n";
		print "<h1>Forbidden</h1>\r\n";
		print "<p>You don't have permission to access $url_disarmed\r\n";
		print "on this server.</p>\r\n";
		print "<hr>\r\n";
		print "<address>Monitorix HTTP Server listening at $host Port $port</address>\r\n";
		print "</body></html>\r\n";
		logger($url, "NOTALLOWED");
		exit(0);
	}

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
	($mimetype) = ($target =~ m/.*\.(html|cgi|css|png|svg)$/);

	$target =~ s/^\/*//;		# removes leading slashes
	$target_cgi =~ s/^\/*//;	# removes leading slashes

	$target =~ s/[^$OK_CHARS]/_/go;		# only $OK_CHARS are allowed
	$target_cgi =~ s/[^$OK_CHARS]/_/go;	# only $OK_CHARS are allowed

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

	if($auth eq "y") {
		if(http_header("401", $mimetype)) {
			print("<!DOCTYPE html '-//W3C//DTD HTML 4.01 Final//EN'>\r\n");
			print "<html><head>\r\n";
			print "<title>401 Authorization Required</title>\r\n";
			print "</head><body>\r\n";
			print "<h1>Authorization Required</h1>\r\n";
			print "<p>This server could not verify that you\r\n";
			print "are authorized to access the document\r\n";
			print "requested.  Either you supplied the wrong\r\n";
			print "credentials (e.g., bad password), or your\r\n";
			print "browser doesn't understand how to supply\r\n";
			print "the credentials required.</p>\r\n";
			print "</body></html>\r\n";
			logger($url, "AUTHERR");
			exit(0);
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
		print("<!DOCTYPE html '-//W3C//DTD HTML 4.01 Final//EN'>\r\n");
		print "<html><head>\r\n";
		print "<title>404 Not Found</title>\r\n";
		print "</head><body>\r\n";
		print "<h1>Not Found</h1>\r\n";
		print "The requested URL $url_disarmed was not found on this server.<p>\r\n";
		print "<hr>\r\n";
		print "<address>Monitorix HTTP Server listening at $host Port $port</address>\r\n";
		print "</body></html>\r\n";
		logger($url, "NOTEXIST");
	}

	exit(0);
}

1;
