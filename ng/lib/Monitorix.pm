package Monitorix;

use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw(logger trim);

sub logger {
	my ($msg) = @_;

	$msg = localtime() . " - " . $msg;
	print("$msg\n");
}

sub trim {
	my $str = shift;

	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	return $str;
}

1;
