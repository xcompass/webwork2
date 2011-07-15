package WebworkBridge::Importer::CourseUpdater;

##### Library Imports #####
use strict;
use warnings;

use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Debug;
use WeBWorK::Utils qw(runtime_use readFile cryptPassword);

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

# it should be safe to require that we have the correctly init course
# environment with the necessary course context
sub updateCourse
{
	my $self = shift;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = new WeBWorK::DB($ce->{dbLayout});

	debug(("-" x 80) . "\n");
	debug("Starting Student Update");
	# Perform Setup
	my $courseid = $self->{course}->{name}; # the course we're updating

	my @students = @{$self->{students}}; # deref pointer

	$db = new WeBWorK::DB($ce->{dbLayout});
	
	# Get already existing users in the database
	my @userIDs;
	eval { @userIDs = $db->listUsers(); };
	if ($@)
	{
		return "Unable to list existing users for course: $courseid\n"
	}
	my %users = map { ("$_" => 1) } @userIDs;


	# Update has 3 components 
	#	1. Check existing users to see if we have anyone who dropped the course
	#		but decided to re-register.
	#	2. Add newly enrolled users
	#	3. Mark dropped students as "dropped"

	# Update components 1,2: Check existing users 
	debug("Checking for new students...\n");
	foreach (@students)
	{
		my $id = $_->{'loginid'};
		if (exists($users{$id}))
		{ # existing student, only mess with them if they've been dropped 
			delete($users{$id}); # this student is now safe from deletion
			my $person = $db->getUser($id);
			if ($person->status() eq "D")
			{ # Update Component 1: this person dropped the course 
				# but re-registered
				$person->status("C");
				$db->putUser($person);
			}
		}
		else
		{ # Update component 2: newly enrolled student, have to add
			my $ret = $self->addStudent($_, $db);
			if ($ret)
			{
				return $ret;
			}
		}
	}

	debug("Checking for dropped students...\n");
	# Update component 3: Mark dropped students as dropped
	while (my ($key, $val) = each(%users))
	{ # any students left in %users has been dropped
		my $person = $db->getUser($key);
		if ($person->status() eq "C" && $key ne "admin")
		{ # only delete missing students
			$person->status("D");
			$db->putUser($person);
			#$db->deleteUser($key); # doesn't seem to throw an exception
		}
	}
	debug("Student Update From Vista Finished!\n");
	debug(("-" x 80) . "\n");
	return 0;
}

##### Helper Functions #####
sub addStudent
{
	my ($self, $new_student_info, $db) = @_;
	my $ce = $self->{r}->ce;
	my $id = $new_student_info->{'loginid'};
	
	# student record
	my $new_student = $db->{user}->{record}->new();
	$new_student->user_id($id);
	$new_student->first_name($new_student_info->{'firstname'});
	$new_student->last_name($new_student_info->{'lastname'});
	$new_student->email_address($new_student_info->{'email'});
	$new_student->status("C");
	$new_student->student_id($new_student_info->{'studentid'});
	
	# password record
	my $cryptedpassword;
	if ($new_student_info->{'password'})
	{
		$cryptedpassword = cryptPassword($new_student_info->{'password'});
	}
	else
	{
		$cryptedpassword = cryptPassword($new_student->student_id());
	}
	my $password = $db->newPassword(user_id => $id);
	$password->password($cryptedpassword);
	
	# permission record
	my $permission = $db->newPermissionLevel(user_id => $id, 
		permission => $ce->{userRoles}{student});

	# commit changes to db
	eval{ $db->addUser($new_student); };
	if ($@)
	{
		return "Add user for $id failed!\n";
	}
	eval { $db->addPassword($password); };
	if ($@)
	{
		return "Add password for $id failed!\n";
	}
	eval { $db->addPermissionLevel($permission); };
	if ($@)
	{
		return "Add permission for $id failed!\n";
	}
	return 0;
}

1;
