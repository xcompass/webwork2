package WebworkBridge::Bridges::LTIParser;
use base qw(WebworkBridge::Parser);

use strict;
use warnings;

use XML::Simple;
use WebworkBridge::Importer::Error;
use Data::Dumper;

##### Exported Functions #####
sub new
{
	my ($class, $r, $course_ref, $students_ref) = @_;
	my $self = $class->SUPER::new($r, $course_ref, $students_ref);
	bless $self, $class;
	return $self;
}

sub parse
{
	my ($self, $param) = @_;
	my $course = $self->{course};
	my $students = $self->{students};
	%{$course} = ();
	@{$students} = ();

	my $xml = new XML::Simple;

	my $data = $xml->XMLin($param);

	if ($data->{'statusinfo'}{'codemajor'} ne 'Success')
	{ # check status code
		return error("Failed to retrieve roster.", "#e001");
	}

	foreach(@{$data->{'memberships'}{'member'}})
	{ # process members
		if ($_->{'roles'} =~ /instructor/i)
		{ # make note of the instructor for later
			$course->{'profid'} = $_->{'user_id'};
		}
		my %tmp = parseStudent($_);
		push(@{$students}, \%tmp);
	}

	return 0;
}

##### Helper Functions #####

sub parseStudent
{
	my $tmp = shift;
	my %param = %{$tmp};
	my %student;
	$student{'firstname'} = $param{'person_name_given'};
	$student{'lastname'} = $param{'person_name_family'};
	$student{'studentid'} = $param{'user_id'};
	$student{'loginid'} = $param{'user_id'};
	$student{'email'} = $param{'person_contact_email_primary'};
	$student{'password'} = "";
	return %student;
}

# test code
#open FILE, "test.xml" or die "Cannot open XML file. $!";
#
#my $input = join("",<FILE>);
#
#my %course = ();
#my @students = ();
#
#parse($input, \%course, \@students);
#
#$Data::Dumper::Indent = 3;
#print "Course Info: \n";
#print Dumper(\%course);
#
#print "\n\nStudents List: \n";
#print Dumper(\@students);

1;

