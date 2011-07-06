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

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

	# TODO wtf does this thing do?
	my $ltiimport_error = MP2 ? $r->notes->get("ltiimport_error") : $r->notes("ltiimport_error");

	print CGI::h2("LTI Course Import");
	print CGI::p("Do you wish to import this course into WeBWorKs? If so, click 'Import' to start.");

	print CGI::startform({-method=>"POST", -action=>$r->uri});

	print CGI::input({-type=>"text", -name=>"", -value=>""});
	print CGI::input({-type=>"text", -name=>"", -value=>""});
	print CGI::input({-type=>"submit", -value=>"Import"});
	
	print CGI::endform();

	return "";
}

1;
