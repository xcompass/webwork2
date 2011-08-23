package WebworkBridge::Parser;

##### Library Imports #####
use strict;
use warnings;

use WebworkBridge::Importer::Error;

# Constructor
sub new
{
	my ($class, $r, $course_ref, $students_ref) = @_;

	my $self = {
		r => $r,
		course => $course_ref,
		students => $students_ref
	};

	bless $self, $class;
	return $self;
}

sub parse
{
	my ($self, $param) = @_;
	die "Not implemented";
}

sub parseStudent
{
	my ($self, $param) = @_;
	die "Not implemented";
}

sub parseCourse
{
	my ($self, $param) = @_;
	die "Not implemented";
}

sub sanitizeCourseName
{
	my $course = shift;
	$course =~ s/[^a-zA-Z0-9_-]//g;
	$course = substr($course,0,20); # needs to fit mysql table name limits
	return $course;
}

1;
