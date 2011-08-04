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

package WeBWorK::ContentGenerator::Home;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Home - display a list of courses.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Utils qw(readFile readDirectory);
use WeBWorK::Utils::CourseManagement qw/listCourses/;
use WeBWorK::Localize;
sub info {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

	my $result;
	
	# This section should be kept in sync with the Login.pm version
	my $site_info = $ce->{webworkFiles}->{site_info};
	if (defined $site_info and $site_info) {
		# deal with previewing a temporary file
		# FIXME: DANGER: this code allows viewing of any file
		# FIXME: this code is disabled because PGProblemEditor no longer uses editFileSuffix
		#if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile"
		#		and defined $r->param("editFileSuffix")) {
		#	$site_info .= $r->param("editFileSuffix");
		#}
		
		if (-f $site_info) {
			my $text = eval { readFile($site_info) };
			if ($@) {
				$result = CGI::div({class=>"ResultsWithError"}, $@);
			} elsif ($text =~ /\S/) {
				$result = $text;
			}
		}
	}
	
	if (defined $result and $result ne "") {
		return CGI::div({class=>"info-box", id=>"InfoPanel"},
			CGI::h2("Site Information"), $result);
	} else {
		return "";
	}
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	
	my $coursesDir = $r->ce->{webworkDirs}->{courses};
	my $coursesURL = $r->ce->{webworkURLs}->{root};
	
	my @courseIDs = listCourses($r->ce);
	#filter underscores here!
	
	my $haveAdminCourse = 0;
	foreach my $courseID (@courseIDs) {
		if ($courseID eq "admin") {
			$haveAdminCourse = 1;
			last;
		}
	}
	
	print CGI::p("Welcome to WeBWorK! <p>WeBWorK is an on-line homework system for delivering individualized homework problems over the web. It gives students instant feedback as to whether or not their answers are correct. Please click on a course below to login with your CWL account. You will only be able to login to the course you enrolled. If you have any question, please contact <a href=mailto:webwork.support\@ubc.ca>webwork.support\@ubc.ca</a>.</p>

<!--<p color=red>NOTE: There is a scheduled server maintenance on 10AM~11AM Nov. 13th. The webwork service will not be available during that time. If you have any question, please contact us at webwork.support\@ubc.ca. Sorry for the inconvenience.</p>-->

<p>NOTE: If you have trouble to login to the system, please send an email with the following information to webwork.support\@ubc.ca to activate your account.</p>
<ul>
<li>Your full name</li>
<li>Your email</li>
<li>Your student ID</li>
<li>Your CWL username</li>
<li>Course and section you registered</li>
</ul>
");
	
#	print CGI::p("<p style='color: red'>NOTICE: Due to IT service maintenance on Oct. 24, 2009 from 7:00am to 10:00am, there will be a service interruption during that time. You will not be able to login to WeBWorK. If you are planning to do the assignment on Oct. 24, please prepare it ahead of time. Sorry for the inconvenience. </p>");
	if ($haveAdminCourse and !(-f "$coursesDir/admin/hide_directory")) {
		my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => "admin");
		print CGI::p(CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, "Course Administration"));
	}
	
	print CGI::h2($r->maketext("Courses"));
	
	# changed by Compass
#	print CGI::start_ul();
	print q(<ul id="course-list">);
	
	foreach my $courseID (sort {lc($a) cmp lc($b) } @courseIDs) {
		next if $courseID eq "admin"; # done already above
		next if -f "$coursesDir/$courseID/hide_directory";
		my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => $courseID);
		# changed by Compass
		print CGI::li(CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, '<img src="https://www.auth.cwl.ubc.ca/CWL_login_button.gif" width="76" height="25" alt="CWL Login" border="0">&nbsp;'.$courseID));
	}###place to use underscore sub
	
	print CGI::end_ul();
	
	return "";
}

1;
