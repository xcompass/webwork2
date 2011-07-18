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

package WeBWorK::ContentGenerator::WebworkBridgeStatus;
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

	# check for error messages to display
	my $import_error = MP2 ? $r->notes->get("import_error") : $r->notes("import_error");

	print CGI::h2("Course Import");
	print CGI::p("This course does not yet exist in Webworks, so we tried to import it.");

	if ($import_error)
	{
		print CGI::h4("Course Import Failed");
		print CGI::p("Unfortunately, import failed. This might be a temporary condition. If it persists, please mail an error report with the time that the error occured and the exact error message below:");
		print CGI::div({class=>"ResultsWithError"}, CGI::pre("$import_error") );
	}
	else
	{
		print CGI::h2("Course Import Successful");
		print CGI::p("The course was successfully imported into Webwork. Please refresh to login to your course.");
	}

	return "";
}

1;
