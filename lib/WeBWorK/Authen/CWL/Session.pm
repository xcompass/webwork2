package Session;
use strict;

use WeBWorK::Authen::CWL::CWL;
use Carp;
use WeBWorK::Debug;
use XMLRPC::Lite;

# Revision history:
#
#  - Initial revision completed
#

=head1 NAME

CWL::Session - Campus Wide Login Auth v2 Client Session

=head1 SYNOPSIS

  # Get the login name of the user presenting a ticket
  
  use CWL;
  
  my $cwl = new CWL(service => 'ubc_widget_service',
                    password => 'sprockets',
                    url => 'https://www.auth.verf2.cwl.ubc.ca/auth/login',
            );
  
  my $session = $cwl->create_session($ticket);
  
  my $login_name = $session->get_login_name();

=head1 DESCRIPTION

This module provides access to the CWL Auth 2 service API.
You should not create CWL::Session objects directly; rather,
use CWL to create CWL::Session objects.

=head2 Methods

The following methods are provided:

=over




=item B<$session-E<gt>add_identity($type, $value)>

Adds an identity key to the user.

Prior authorization is needed before a service can use this API.

=cut

sub add_identity {
	my ($self, $type, $value) = @_;
	$self->{cwl}->invoke('session.addIdentity',
	                     XMLRPC::Data->type(string => $self->{ticket}),
	                     XMLRPC::Data->type(string => $type),
	                     XMLRPC::Data->type(string => $value));
}




=item B<$session-E<gt>get_identities( )>

Returns all of the identity keys for the user.  This returns
a hashref, the keys of which are strings representing the
identity type.

=cut

sub get_identities {
	my ($self) = @_;
	
	$self->{cwl}->invoke('session.getIdentities',
	                     XMLRPC::Data->type(string => $self->{ticket}));
}




=item B<$session-E<gt>get_login_key( )>

Returns the login key of the user.

=cut

sub get_login_key {
	my ($self) = @_;
	
	$self->{cwl}->invoke('session.getLoginKey',
	                     XMLRPC::Data->type(string => $self->{ticket}));
}




=item B<$session-E<gt>get_login_name( )>

Returns the login name of the user.

=cut

sub get_login_name {
	my ($self) = @_;
	debug($self->{cwl});
	
	$self->{cwl}->invoke('session.getLoginName',
	                     XMLRPC::Data->type(string => $self->{ticket}));
}




=item B<$session-E<gt>get_preferred_name( )>

Returns the preferred full name of the user.

If no full name is available, this will return the login name instead.

=cut

sub get_preferred_name {
	my ($self) = @_;
	
	$self->{cwl}->invoke('session.getPreferredName',
	                     XMLRPC::Data->type(string => $self->{ticket}));
}




=item B<$session-E<gt>get_roles( )>

Returns the list of all of the user's roles.  This returns an arrayref.

=cut

sub get_roles {
	my ($self) = @_;
	
	$self->{cwl}->invoke('session.getRoles',
	                     XMLRPC::Data->type(string => $self->{ticket}));
}




=item B<$session-E<gt>get_session_age( )>

Returns the time, in seconds, since the session was created.

=cut

sub get_session_age {
	my ($self) = @_;
	
	$self->{cwl}->invoke('session.getSessionAge',
	                     XMLRPC::Data->type(string => $self->{ticket}));
}




=item B<$session-E<gt>get_session_key( )>

Returns the session key for this session.

=cut

sub get_session_key {
	my ($self) = @_;
	
	$self->{cwl}->invoke('session.getSessionKey',
	                     XMLRPC::Data->type(string => $self->{ticket}));
}




=item B<$session-E<gt>get_trust_path( )>

Get the list of services the user has traversed to arrive at this session.
This returns an arrayref.

=cut

sub get_trust_path {
	my ($self) = @_;
	
	$self->{cwl}->invoke('session.getTrustPath',
	                     XMLRPC::Data->type(string => $self->{ticket}));
}




=item B<$session-E<gt>has_role($role)>

Check to see if the user has a certain role.

Returns a true value if the user has that role, a false value otherwise.

=cut

sub has_role {
	my ($self, $role) = @_;
	
	$self->{cwl}->invoke('session.hasRole',
	                     XMLRPC::Data->type(string => $self->{ticket}),
	                     XMLRPC::Data->type(string => $role));
}




=item B<$session-E<gt>transfer_session($service)>

Create a ticket to transfer the session to another application.

This will request a new session key from the CWL Authentication Service that
can be used by the specified application, without requiring the user to log in
a second time.

Because tickets have relatively short lifetimes, it is important to only
request this ticket immediately before passing it to the next application.

This returns the new ticket.

=cut

sub transfer_session {
	my ($self, $service) = @_;
	
	$self->{cwl}->invoke('session.transferSession',
	                     XMLRPC::Data->type(string => $self->{ticket}),
	                     XMLRPC::Data->type(string => $service));
}




=back

=head2 Private Methods

The following methods are used internally by this module.  You should not
invoke these methods directly; rather, use one of the other methods as
described in the CWL API.

=over




=item B<CWL::Session-E<gt>fromTicket($cwl, $ticket)>

B<(PRIVATE METHOD)>
Creates a CWL::Session object from a ticket.

=cut

# private
sub fromTicket {
	my ($self, $cwl, $ticket) = @_;
	my $self = bless { };
	
	$self->{cwl} = $cwl;
	$self->{ticket} = $ticket;
	return $self;
}




=item B<CWL::Session-E<gt>fromLogin($cwl, $username, $password)>

B<(PRIVATE METHOD)>
Creates a CWL::Session object from a username and password.

=cut

# private
sub fromLogin {
	my ($class, $cwl, $username, $password) = @_;
	
	my $ticket = $cwl->invoke('service.createSession',
	                          XMLRPC::Data->type(string => $username),
	                          XMLRPC::Data->type(string => $password));
	
	return $class->fromTicket($cwl, $ticket);
}



=back

=head1 REQUIRED MODULES

L<Carp>, L<XMLRPC::Lite>, L<CWL>

=head1 SEE ALSO

I<Technical Guide for Intergrating with the CWL Authentication Service>,
L<CWL>

=head1 COPYRIGHT

Copyright (c) 2007 The University of British Columbia

=cut


1;
# vim:sw=4:ts=4
