package WebworkBridge::Bridges::LTIBridge;
use base qw(WebworkBridge::Bridge);

##### Library Imports #####
use strict;
use warnings;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Debug;
use WeBWorK::Utils qw(runtime_use readFile cryptPassword);

use Net::OAuth;
use HTTP::Request::Common;
use LWP::UserAgent;

use WebworkBridge::Importer::Error;
use WebworkBridge::Bridges::LTIParser;

# Constructor
sub new 
{
	my ($class, $r) = @_;
	my $self = $class->SUPER::new($r);
	bless $self, $class;
	return $self;
}

sub accept
{
	my $self = shift;
	my $r = $self->{r};
	
	if ($r->param("lti_message_type"))
	{
		return 1;
	}

	return 0;
}

# In order to simplify, we use the Webwork root URL for all LTI actions,
# e.g.: http://137.82.12.77/webworkdev/
# Cases to handle:
# * The course does not yet exist
# ** If user is instructor, ask if want to create course
# ** If user is student, inform that course does not exist
# * The course exists
# ** SSO login

sub run
{
	my $self = shift;
	my $r = $self->{r};
	my $ce = $r->ce;

	if ($r->param("lti_message_type") &&
		$r->param("context_label"))
	{
		debug("LTI detected\n");
		# Check for course existence
		my $coursename = $self->sanitizeCourseName($r->param("context_label"));
		my $tmpce = WeBWorK::CourseEnvironment->new({
				%WeBWorK::SeedCE,
				courseName => $coursename
			});
		if (-e $tmpce->{courseDirs}->{root})
		{ # course exists
			debug("We're trying to authenticate to an existing course.");
			if ($ce->{"courseName"})
			{
				debug("CourseID found, trying authentication\n");
				$self->{useAuthenModule} = 1;
				$self->updateCourse();
			}
			else
			{
				debug("CourseID not found, trying workaround\n");
				# workaround is basically dump all our POST parameters into
				# GET and redirect to that url. This should work as long as
				# our url doesn't exceed 2000 characters.
				use URI::Escape;
				my @tmp;
				foreach my $key ($r->param) {
					my $val = $r->param($key);
					push(@tmp, "$key=" . uri_escape($val)); 	
				}
				my $args = join('&', @tmp);

				use CGI;
				my $q = CGI->new();
				my $redir = $r->uri . $r->param("context_label") . "/?". $args;
				debug($redir);
				print $q->redirect($redir);
			}
		}
		else
		{ # course does not exist
			debug("Course does not exist, try LTI import.");
			$self->{useDisplayModule} = 1;
			$self->createCourse();
		}
	}
	else
	{
		debug("LTI detected but unable to proceed, missing parameter 'context_label'.\n");
	}

}

sub getAuthenModule
{
	my $self = shift;
	my $r = $self->{r};
	return WeBWorK::Authen::class($r->ce, "lti");
}

sub getDisplayModule
{
	my $self = shift;
	return "WeBWorK::ContentGenerator::LTIImport";
}

sub createCourse
{
	my $self = shift;
	my $r = $self->{r};
	
	my $xml = $self->_getRoster();
	if ($xml == 0)
	{
		return error("Unable to get class roster.", "#e003");
	}

	my %course = ();
	my @students = ();

	my $parser = WebworkBridge::Bridges::LTIParser->new(\%course, \@students);
	my $ret = $parser->parse($xml);
	if ($ret)
	{
		return error("XML response received, but access denied.", "#e005");
	}
	$course{name} = $self->sanitizeCourseName($r->param("context_label"));
	$course{title} = $r->param("resource_link_title");
	$course{id} = $r->param("resource_link_id");

	$self->SUPER::createCourse(\%course, \@students);

	return 0;
}

sub updateCourse
{
	my $self = shift;
	my $r = $self->{r};
	
	my $xml = $self->_getRoster();
	if (!$xml)
	{
		return error("Unable to get class roster.", "#e003");
	}

	my %course = ();
	my @students = ();

	my $parser = WebworkBridge::Bridges::LTIParser->new(\%course, \@students);
	my $ret = $parser->parse($xml);
	if ($ret)
	{
		return error("XML response received, but access denied.", "#e005");
	}
	$course{name} = $self->sanitizeCourseName($r->param("context_label"));
	$course{title} = $r->param("resource_link_title");
	$course{id} = $r->param("resource_link_id");

	$self->SUPER::updateCourse(\%course, \@students);

	return 0;
}

sub _getRoster
{
	my $self = shift;
	my $r = $self->{r};

	my $ua = LWP::UserAgent->new;
	debug("##### LTI Secret: " . $r->ce->{bridge}{lti_secret});
	my $request = Net::OAuth->request("request token")->new(
		consumer_key => $r->param('oauth_consumer_key'),
		consumer_secret => $r->ce->{bridge}{lti_secret},
		protocol_version => Net::OAuth::PROTOCOL_VERSION_1_0A,
		request_url => $r->param('ext_ims_lis_memberships_url'),
		request_method => 'POST',
		signature_method => 'HMAC-SHA1',
		timestamp => time(),
		nonce => rand(),
		callback => 'about:blank',
		extra_params => {
			lti_version => 'LTI-1p0',
			lti_message_type => 'basic-lis-readmembershipsforcontext',
			id => $r->param('lis_result_sourcedid'),
		}
	);

	$request->sign;
	my $res = $ua->request(POST $request->to_url);
	my $xml;
	if ($res->is_success) 
	{
		$xml = $res->content;
		debug("LTI Get Roster Success! \n" . $xml . "\n");	
	}
	else
	{
		return 0;
	}

	return $xml;
}

1;
