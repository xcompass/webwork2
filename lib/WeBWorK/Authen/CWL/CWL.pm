package CWL;
use strict;

use Carp;
use MIME::Base64;
use XMLRPC::Lite;
use WeBWorK::Debug;
use WeBWorK::Authen::CWL::Session;

# Revision history:
#
#  - Corrected max retries from 1 to 5
#  - Only retry on communication failure
#

=head1 NAME

CWL - Campus Wide Login Auth v2 Client

=head1 SYNOPSIS

  # Get the login name of the user presenting a ticket
  
  use CWL;
  
  my $cwl = new CWL(service => 'webworks_psa',
                    password => '3ducat3m3',
                    url => 'https://www.auth.verf2.cwl.ubc.ca/auth/login',
            );
  
  my $session = $cwl->create_session($ticket);
  
  my $login_name = $session->get_login_name();

=head1 DESCRIPTION

This module provides a connection to the CWL Auth 2 service.
Most of the CWL authtentication service API can be accessed
through the CWL::Session object that is returned by the
L<create_session($ticket)|$cwl-E<gt>create_session($ticket)>
and
L<validate_session($ticket)|$cwl-E<gt>validate_session($ticket)>
methods.

=head2 Methods

The following methods are provided:

=over




=item B<CWL-E<gt>new(%properties)>

Create a CWL connection.

The following keys are required in the properties hash:

=over

=item service

The service account name.

=item password

The service account password.

=item url

The URL of the CWL authentication service.

=back

=cut

sub new {
	my $class = shift;
	my $self = bless { @_ };
	
	foreach my $property qw( service password url ) {
		if (not defined $self->{$property}) {
			croak qq[Required property '$property' not defined];
		}
	}
	
	$self->{max_age} = 10;
	$self->initialize_proxy();
	return $self;
}




=item B<$cwl-E<gt>create_session($ticket)>

Create a CWL::Session object from a session key without performing any checks.

=item B<$cwl-E<gt>create_session($username, $password)>

Create a CWL::Session object directly from a CWL username and
password.  Note: This is only to be used in special circumstances.
Most applications must obtain a session key through the login page.

=cut

sub create_session {
	my ($self, @credentials) = @_;
	my $session;
	debug(@credentials);	
	if (scalar @credentials == 1) {
		my ($ticket) = @credentials;
		$session = fromTicket Session($self, $ticket);
	} else {
		my ($username, $password) = @credentials;
		$session = fromLogin Session($self, $username, $password);
	}
	return $session;
}




=item B<$cwl-E<gt>create_service_session( )>

Create a CWL::Session object for the current application's service user.
This method is intended to support service to service authentication.
It returns a newly created session with the current service as its user.
This session can then be transferred to another service such as the
management API.

=cut

sub create_service_session {
	my ($self) = @_;
	my $ticket = $self->invoke('service.createServiceSession');
	return $self->create_session($ticket);
}




=item B<$cwl-E<gt>validate_session($ticket)>

Create a CWL::Session object from a session key, checking its age.
See also
L<set_max_ticket_age($seconds)|/$cwl-E<gt>set_max_ticket_age($seconds)>.

=cut

sub validate_session {
    my ($self, $ticket) = @_;
	my $session = $self->create_session($ticket);
	
	my $max_age = $self->{max_age};
	my $age = $session->get_session_age();
	if ($age > $max_age) {
		croak "StaleTicket: This session is older than $max_age seconds";
	}
	
	return $session;
}




=item B<$cwl-E<gt>set_max_ticket_age($seconds)>

Set the maximum age, in seconds, of ticket that this module is willing
to accept.  The default is 10 seconds.

=cut

sub set_max_ticket_age {
	my ($self, $seconds) = @_;
	
	my $set_seconds = ($seconds || 0) + 0;
	if ($set_seconds > 0) {
		$self->{max_age} = $set_seconds;
	} else {
		croak qq[Invalid (non-numerical or zero) max age specified: $seconds];
	}
}




=back

=head2 Private Methods

The following methods are used internally by this module and L<CWL::Session>.
You should not invoke these methods directly; rather, use one of the other
methods as described in the CWL API.

=over




=item B<$cwl-E<gt>invoke($method_name, @args)>

B<(PRIVATE METHOD)>
Calls the RPC method and returns the result.

=cut

# private
sub invoke {
	my ($self, $method_name, @args) = @_;
	my $tries_left = 5;
	CALL_ATTEMPT: while ($tries_left--) {
		my $som;
		debug($self->{proxy});	
		eval { $som = $self->{proxy}->call($method_name, @args) };
		
		if (ref $som and !$som->fault) {
			return $som->result;
		}
		
		if ($tries_left and not (defined $som and ref $som)) {
			# Retry only for communication errors
			sleep 1;
			$self->initialize_proxy();
			next CALL_ATTEMPT;
		}
		
		croak $@ if $@;
		croak $som->faultstring if ref $som and $som->faultstring;
		croak 'Unknown XMLRPC fault';
	}
}




=item B<$cwl-E<gt>initialize_proxy( )>

B<(PRIVATE METHOD)>
Prepares the RPC connection.

=cut

# private
sub initialize_proxy {
	my ($self) = @_;
	
	my $proxy = XMLRPC::Lite->proxy($self->{url}, timeout => 60);
	
	# Authorization must be added manually because the httpd does not
	# return a 401 result code with "WWW-Authenticate: Basic" header
	# as required by RFC 1945.
	my $auth = encode_base64($self->{service} . ':' . $self->{password});
	$proxy->transport->default_header('Authorization', "Basic $auth");
	
	$self->{proxy} = $proxy;
}




=back

=head1 REQUIRED MODULES

L<Carp>, L<MIME::Base64>, L<XMLRPC::Lite>, L<CWL::Session>

=head1 SEE ALSO

I<Technical Guide for Intergrating with the CWL Authentication Service>,
L<CWL::Session>

=head1 COPYRIGHT

Copyright (c) 2007 The University of British Columbia

=cut


1;
# vim:sw=4:ts=4
