#!/usr/bin/env perl

use strict;
use warnings;

BEGIN
{
	$ENV{WEBWORK_ROOT} = "/home/john/webworkdev/webwork2";
	die "WEBWORK_ROOT not found in environment.\n"
		unless exists $ENV{WEBWORK_ROOT};
}

use lib "$ENV{WEBWORK_ROOT}/lib";
use WeBWorK::CourseEnvironment;

# bring up a minimal course environment
my $ce = WeBWorK::CourseEnvironment->new({
	webwork_dir => $ENV{WEBWORK_ROOT},
});

my $loginlistdir = $ce->{bridge}{vista_loginlist};
open FILE, $loginlistdir or die "Cannot open loginlist file! $!\n";

my @lines = <FILE>;
foreach (@lines)
{
	my @line = split(/\t/, $_);
	
	if (scalar @line != 5)
	{
		print "Warning, line with unexpected format, skipping '$_' \n";
		next;
	}

	my $userid = $line[0];
	my $lcid = $line[1];
	my $course = $line[2];

	my $cmd = $ENV{WEBWORK_ROOT} . "/lib/WebworkBridge/updateclass.pl $userid $lcid $course";
	my $ret = `$cmd\n`;
	if ($?)
	{
		die "Autoupdate failed.\n";
	}
	print "Autoupdate done!\n";
}

close FILE;
