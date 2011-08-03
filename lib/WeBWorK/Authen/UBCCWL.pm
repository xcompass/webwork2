package WeBWorK::Authen::UBCCWL;
use base qw/WeBWorK::Authen/;

=head1 NAME

WeBWorK::Authen::CWL - Authentication plug in for CWL

to use: include in global.conf or course.conf
  $authen{user_module} = "WeBWorK::Authen::CWL";
and add /webwork2 or /webwork2/courseName as a CWL Protected Location

if $r->ce->{cosignoff} is set for a course, authentication reverts
to standard WeBWorK authentication.

=cut

use strict;
use warnings;
use CGI qw/:standard/;
use WeBWorK::Debug;
use WeBWorK::Authen::CWL::CWL;

my $CWL_SERVER="https://www.auth.cwl.ubc.ca/auth/login";
my $serviceURL="https://www.auth.cwl.ubc.ca/auth/rpc";
my $serviceName = "webworks_psa";
my $servicePassword = "m4th3mat1c5";

sub get_credentials {
	debug("get_credentials");
	
	my ($self) = @_;
    my $r = $self->{r};
    my $ce = $r->ce;
    my $db = $r->db;
	# if we come in with a user_id, we're in the loop where we
    #    use WeBWorK's authentication, and so just continue
    #    with the superclass get_credentials method.
	# if bypassCWL is submitted, using build-in authentication method.
	$self->{external_auth} = 1;
	if ( $r->param("bypassCWL") || ( $r->param("user") && ! $r->param("force_passwd_authen") ) ){
#		 debug(" user=".$r->param("user")." force_passwd_authen=".$r->param("force_passwd_authen")."bypassCWL=" . $r->param("bypassCWL"));
		if($r->param("bypassCWL")){
			$self->{external_auth} = 0;
		}
        return $self->SUPER::get_credentials( @_ );
    } else {
        my $ticket =  $r->param('ticket') || 0;
        if ( $ticket ) {
            my ($error, $user_id) = $self->check_cwl($ticket);
            if ( $error ) {
                $self->{error} = $error;
                return 0;
            } else {
                $self->{'user_id'} = $user_id;
                $self->{r}->param("user", $user_id);
                # set external auth parameter so that Login.pm
                #    knows not to rely on internal logins if
                #    there's a check_user failure.
                $self->{session_key}   = undef;
                $self->{password}      = "youWouldNeverPickThisPassword";
                $self->{login_type}    = "normal";
                $self->{credential_source} = "params";
				
				return 1;
            }
        } else {
            # if there's no ticket, redirect to get one
            #
            my $this_script = "https://"  . $ENV{'SERVER_NAME'} ;
			if( $ENV{"SERVER_PORT"} != 80 || $ENV{"SERVER_PORT"} != 443 ) 
			{
				$this_script = $this_script . ":" . $ENV{"SERVER_PORT"};
			}
			$this_script .=  $ENV{'REQUEST_URI'};
			my $go_to = "$CWL_SERVER?serviceName=$serviceName&serviceURL=$this_script";
			$self->{redirect} = $go_to;
			debug($go_to);

			my $q = new CGI;
			print $q->redirect($go_to);

            return 0;
        }
	}
}


sub site_checkPassword {
    my ( $self, $userID, $clearTextPassword ) = @_;
    # if we got here, we know we've already successfully authenticated against the CWL 
    return 1;
}

sub check_cwl {
	my ($self, $ticket) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	debug($ticket);
	my $cwl = CWL->new(service => $serviceName,
		password => $servicePassword,
		url => $serviceURL,
	);

	my $session = $cwl->create_session($ticket);
	
	# check if session is too old, login failded
	if($session->get_session_age() > 5) {
		return q(Access Denied. Your session has expired.);
	}

	my $cwl_login_name = $session->get_login_name();
	# get all ids, e.g. student id, employee id.
	my $ids = $session->get_identities();

	# get all users from database for this course
	my @usernames = $db->listUsers;
	my @users = $db->getUsers(@usernames);

	my @found;
	my $login_name = undef;
	
	# search for all matches.
	foreach(@users) {
		debug("user_id: $_->student_id");
		while( my($key, $value) = each (%$ids) ){
			debug("identities: " . $value);
			if( $value eq $_->student_id ) {
				push(@found, $_);
			}
		}
	}

	# if nothing found, no access. 
	# One found, use user_id from db. 
	# More than one found, try to match cwl login name with user_id in db. If no match, use the first one in db as default.
	if(0 == scalar @found) {
		$self->{external_auth} = 1;
		return q(Access Denied. You have successfully logged in using your CWL account, but you do not have access to this course.
			If you are experiencing any issues regarding access to WeBWorK, please contact the CTLT Support Team at 
			<a href="mailto:webwork.support@ubc.ca">webwork.support@ubc.ca</a>.<br /><br />
			<strong>You may logged in to the wrong course/section. Please make sure you clicked on the correct course and section link to login.</strong>);
			#<p>To log in, please click on the CWL Login button below.<br /><br /><a href=").qq($CWL_SERVER?serviceName=$serviceName&serviceURL=).url(-path_info=>1).'?'.$ENV{'QUERY_STRING'}.q(">
			#<img src="https://www.auth.cwl.ubc.ca/CWL_login_button.gif" width="76" height="25" alt="CWL Login" border="0"></a></p>);
	}elsif( scalar @found > 1) {
		foreach(@found){
			if( $_->user_id eq $cwl_login_name ) {
				$login_name = $_->user_id;
				last;
			}
		}
		if(!defined $login_name){
			$login_name = $found[0]->user_id;
		}
	}else{
		$login_name = $found[0]->user_id;
	}
	return (0, $login_name);
}

# override verify_normal_user method to customize time out handling.
sub verify_normal_user {
	my $self = shift;
	my $r = $self->{r};

	my $user_id = $self->{user_id};
	my $session_key = $self->{session_key};
	
	my ($sessionExists, $keyMatches, $timestampValid) = $self->check_session($user_id, $session_key, 1);
	debug("sessionExists='", $sessionExists, "' keyMatches='", $keyMatches, "' timestampValid='", $timestampValid, "'");
	debug(url(-path_info=>1).$ENV{'QUERY_STRING'});	
	if ($keyMatches and $timestampValid) {
		return 1;
	} else {
		my $auth_result = $self->authenticate;
		
		if ($auth_result > 0) {
			$self->{session_key} = $self->create_session($user_id);
			$self->{initial_login} = 1;
			return 1;
		} elsif ($auth_result == 0) {
			$self->{log_error} = "authentication failed";
			$self->{error} = $self->{GENERIC_ERROR_MESSAGE};
			return 0;
		} else { # ($auth_result < 0) => required data was not present
			if ($keyMatches and not $timestampValid) {
				$self->{error} = qq(Your session has timed out due to inactivity. Please log in again.);
			}
			return 0;
		}
	}
}

sub killCookie {
	my ($self, @args) = @_;
	return $self->SUPER::killCookie( @_ );
}

1;
