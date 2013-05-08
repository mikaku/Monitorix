#!/usr/bin/perl
use v5.14;
say "[create htpasswd]";
print "username:>";
my $username = <STDIN>;
chomp $username;
system("echo -n $username: > /usr/share/monitorix/htpasswd");
print "password:>";
my $password = <STDIN>;
chomp $password;
system ("openssl passwd -crypt -salt $username $password >> /usr/share/monitorix/htpasswd");
say "[htpasswd created]";
