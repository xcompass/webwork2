################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen/LDAP.pm,v 1.3 2006/11/13 16:48:39 sh002i Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::Authen::VistaLogin2;
use base qw/WeBWorK::Authen/;

use strict;
use warnings;
use WeBWorK::Debug;

sub get_credentials {
	my ($self) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	
	# don't allow guest login from Vista
	if ($r->param("login_practice_user")) {
		$self->{log_error} = "no guest logins are available";
		$self->{error} = "No guest logins are available. Please try again in a few minutes.";
		return 0;
	}

	my $vista_login_enable = $ce->{authen}{vista_login_options}{"enable_param"};
	my $vista_login_course = $ce->{authen}{vista_login_options}{"course_param"};
	my $vista_login_section = $ce->{authen}{vista_login_options}{"section_param"};
	my $vista_login_user = $ce->{authen}{vista_login_options}{"user_param"};
	my $vista_login_time = $ce->{authen}{vista_login_options}{"time_param"};
	my $vista_login_mac = $ce->{authen}{vista_login_options}{"mac_param"};
	my $vista_login_secret = $ce->{authen}{vista_login_options}{"secret"};
	my $vista_login_time_tolerance = $ce->{authen}{vista_login_options}{"valid_time_diff"};

	# construct the mac message for authentication, the mac is basically concatenating all the http params together with the secret and then MD5 hash the whole string
	my $mac_msg;
	# note that params are alphabetically sorted by key before concatenating them together for the mac, we put the params into a hash table for easy sorting
	my %macparams;

	$macparams{$vista_login_enable} = $r->param($vista_login_enable);
	$macparams{$vista_login_course} = $r->param($vista_login_course);
	$macparams{$vista_login_section} = $r->param($vista_login_section);
	$macparams{$vista_login_user} = $r->param($vista_login_user);
	$macparams{$vista_login_time} = $r->param($vista_login_time);

	# this is the mac our calculated mac should match
	$vista_login_mac = $r->param($vista_login_mac);

	foreach my $key (sort keys %macparams) 
	{
		$mac_msg .= $macparams{$key};	
	}
	$mac_msg .= $vista_login_secret;
	debug("Vista login: MAC message: $mac_msg\n");

# validate timestamp, if the timestamps are too far apart, fail login
	my $curtime = time();
	my $diff = abs($curtime - $macparams{$vista_login_time});
	debug("Vista login: WeBWorK time: $curtime Vista time: $macparams{$vista_login_time}\n");
	
	if ($diff > $vista_login_time_tolerance)
	{
		$self->{log_error} = "timestamp validation failed";
		$self->{error} = "The Vista server's time does not match WeBWorK's server time.";
		return 0;
	}
	
	# at least the user ID is available in request parameters
	if (defined $vista_login_user) {
		$self->{user_id} = $macparams{$vista_login_user};
		$self->{mac_msg} = $mac_msg;
		$self->{mac} = $vista_login_mac;
#		$self->{session_key} = $r->param("key");
#		$self->{password} = $r->param("passwd");
		$self->{login_type} = "normal";
		$self->{credential_source} = "params";
		debug("params user '", $self->{user_id}, "' password '", $self->{password}, "' key '", $self->{session_key}, "'");
		return 1;
	}
	
	# disable cookie login for Vista
#	my ($cookieUser, $cookieKey) = $self->fetchCookie;
#	if (defined $cookieUser) {
#		$self->{user_id} = $cookieUser;
#		$self->{session_key} = $cookieKey;
#		$self->{login_type} = "normal";
#		$self->{credential_source} = "cookie";
#		debug("cookie user '", $self->{user_id}, "' key '", $self->{session_key}, "'");
#		return 1;
#	}
	return 0;
}

#  1 == authentication succeeded
#  0 == required data was present, but authentication failed
# -1 == required data was not present (i.e. password missing)
sub authenticate {
	my $self = shift;
	my $r = $self->{r};
	
	my $user_id = $self->{user_id};
	my $password = $self->{password};

	my $mac_msg = $self->{mac_msg};
	my $mac = $self->{mac};

	use Digest::MD5 qw(md5_hex);
	my $digest = md5_hex($mac_msg);
	debug("MAC Received: $mac\n");
	debug("MAC Calculated: $digest\n");

	if ($digest eq $mac)
	{
		return 1;
	}
	else
	{
		return 0;
	}

#	if (defined $password) {
#		return $self->checkPassword($user_id, $password);
#	} else {
#		return -1;
#	}
}


1;
