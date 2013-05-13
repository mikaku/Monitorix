#!/usr/bin/perl
use v5.14;
use Config::General;
my $conf = new Config::General("monitorix.conf");
my %config = $conf->getall;
say "[create htpasswd]";
print "username:>";
my $username = <STDIN>;
chomp $username;
system("echo -n $username: > $config{base_dir}/htpasswd");
print "password:>";
my $password = <STDIN>;
chomp $password;
system ("openssl passwd -crypt -salt $username $password >> $config{base_dir}/htpasswd");
say "[htpasswd created]";
