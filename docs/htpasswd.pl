#!/usr/bin/env perl
#
# Usage: htpasswd.pl [encrypted_password]
#
# If no arguments are given then it will ask for a password and will show its
# encrypted form to be saved on a file.
#
# If the argument is an encrypted password it will ask the password and will
# verify if it's valid.
#

use strict;
use warnings;

my $word;

if(!$ARGV[0]) {
	my $salt = join('', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64]);
	print "Password to encrypt: ";
	chomp($word = <STDIN>);
	print crypt($word, $salt) . "\n";
} else {
	system("stty -echo");
	print "Password: ";
	chomp($word = <STDIN>);
	system("stty echo");
	print "\n";
	die "Sorry, do not match.\n" if crypt($word, $ARGV[0]) ne $ARGV[0];
	print "Ok!\n";
}

