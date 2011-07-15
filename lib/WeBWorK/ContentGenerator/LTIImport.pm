################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Home.pm,v 1.19 2006/07/12 01:23:54 gage Exp $
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

package WeBWorK::ContentGenerator::LTIImport;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::LTIImport - create course from LTI import.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Utils qw(readFile readDirectory);
use WeBWorK::Utils::CourseManagement qw/listCourses/;
use WeBWorK::ContentGenerator::Home;
use WeBWorK::Debug;

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

	# TODO wtf does this thing do?
	my $ltiimport_error = MP2 ? $r->notes->get("ltiimport_error") : $r->notes("ltiimport_error");

	debug("LTI Role: " . $r->param('roles'));

	if ($r->param('roles') =~ /instructor/i)
	{
		print CGI::p("This course does not yet exist in Webworks, importing...");
		print CGI::p("Reticulating splines...");
	}
	else
	{
		print CGI::p("This course does not yet exist in Webworks, please wait for your instructor to create it.");
	}

	use Net::OAuth;
	use HTTP::Request::Common;
	use LWP::UserAgent;
	
	my $ua = LWP::UserAgent->new;
	my $request = Net::OAuth->request("request token")->new(
		consumer_key => 'secret',
		consumer_secret => 'secret',
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
	if ($res->is_success) 
	{
		debug("LTI Get Roster Success! \n" . $res->content . "\n");	
		print CGI::p("Get Roster Success!");
	}
	else
	{
		debug("LTI Get Roster Failed... :'( \n");
		print CGI::p("Get Roster Failed :'(");
	}

	return "";
}

1;
