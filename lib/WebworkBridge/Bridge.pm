package WebworkBridge::Bridge;

##### Library Imports #####
use strict;
use warnings;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Debug;
use WeBWorK::Utils qw(runtime_use readFile cryptPassword);

use WebworkBridge::Importer::Error;
use WebworkBridge::Importer::CourseCreator;
use WebworkBridge::Importer::CourseUpdater;

# Constructor
sub new 
{
	my ($class, $r) = @_;
	my $self = {
		r => $r,
		useAuthenModule => 0,
		useDisplayModule => 0
	};
	bless $self, $class;
	return $self;
}

sub accept
{
	my $self = shift;
	return 0;
}

sub run
{
	my $self = shift;
	die "Not implemented";
}

# Returns whether this module requires the use of a custom display module
sub useDisplayModule
{
	my $self = shift;
	return $self->{useDisplayModule};
}

# Returns whether this module requires the use of a custom authen module
sub useAuthenModule
{
	my $self = shift;
	return $self->{useAuthenModule};
}

sub getDisplayModule
{
	my $self = shift;
	return "WeBWorK::ContentGenerator::WebworkBridgeStatus";
}

sub getAuthenModule
{
	my $self = shift;
	die "Not implemented";
}

sub sanitizeCourseName
{
	my ($self, $course) = @_;
	$course =~ s/\W//g;
	$course = substr($course,0,20); # needs to fit mysql table name limits
	return $course;
}

sub createCourse
{
	my ($self, $course, $students) = @_;

	my $creator = WebworkBridge::Importer::CourseCreator->new($self->{r}, $course, $students);
	my $ret = $creator->createCourse();
	if ($ret)
	{
		return error("Failed to create course: $ret", "#e004");
	}
}

sub updateCourse
{
	my ($self, $course, $students) = @_;

	my $creator = WebworkBridge::Importer::CourseUpdater->new($self->{r}, $course, $students);
	my $ret = $creator->updateCourse();
	if ($ret)
	{
		return error("Failed to update course: $ret", "#e004");
	}
}

1;
