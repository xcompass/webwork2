package WeBWorK::ContentGenerator::Instructor::ShowAnswers;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetList - Entry point for Problem and Set editing

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(formatDateTime);

sub initialize {
	my $self = shift;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $courseName = $ce->{courseName};
	my $user = $r->param('user');
	
	unless ($authz->hasPermissions($user, "create_and_delete_problem_sets")) {
		$self->{submitError} = "You aren't authorized to create or delete problems";
		return;
	}
	

}

sub path {
	my ($self, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home"          => "$root",
		$courseName     => "$root/$courseName",
		'instructor'    => "$root/$courseName/instructor",
		'showAnswers'   => ''
	);
}

sub title {
	my $self = shift;
	return "Instructor Tools - Show answers submitted by students in".$self->{ce}->{courseName};
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $user = $r->param('user');
	my $key  = $r->param('key');
	my $studentUser = $r->param('studentUser');
	my $setName = $r->param('setName');
	my $problemNumber = $r->param('problemNumber');
	
	return CGI::em("You are not authorized to access the instructor tools") unless $authz->hasPermissions($user, "access_instructor_tools");
	
	$studentUser = $r->param('studentUser') if ( defined($r->param('studentUser')) );
	my ($safeUser,$safeCourse) = (showHTML($studentUser),showHTML($courseName));
	my ($safeSet,$safeProb) = (showHTML($setName),showHTML($problemNumber));
	
	
	#####################################################################
	# print form
	#####################################################################
	
	print "<p>\n\n<HR>\n";
	print '<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0"><TR><TD>';
	print CGI::start_form("POST", $self->{r}->uri,-target=>'information'),
	  CGI::submit(-name => 'action',  -value=>'Past Answers for'), "\n",
	  " &nbsp; \n",
	  $self->hidden_authen_fields,
	  qq{<INPUT TYPE="TEXT" NAME="studentUser" VALUE="$safeUser" SIZE="15">},
	  " &nbsp; &nbsp;\n",
	  qq{Set: <INPUT TYPE="TEXT" NAME="setName" VALUE="$safeSet" SIZE="10">},
	  " &nbsp; &nbsp;\n",
	  qq{Problem: <INPUT TYPE="TEXT" NAME="problemNumber" VALUE="$safeProb" SIZE="5">},
	  CGI::end_form(),"\n\n";
	print "</TABLE>";
	
	if (defined($setName) and defined($problemNumber) )  {
		#####################################################################
		# print result table of answers
		#####################################################################
		my $answer_log    = $self->{ce}->{courseFiles}->{logs}->{'answer_log'};
	
		$studentUser = $r->param('studentUser') if ( defined($r->param('studentUser')) );
		my ($safeUser,$safeCourse) = (showHTML($studentUser),showHTML($courseName));
		my ($safeSet,$safeProb) = (showHTML($setName),showHTML($problemNumber));
	
		
		print CGI::h3( "Past Answers for $safeUser, set $safeSet, problem$safeProb)" );
	
		$studentUser = "[^|]*"    if ($studentUser eq ""    or $studentUser eq "*");
		$setName = "[^|]*"  if ($setName eq ""  or $setName eq "*");
		$problemNumber = "[^|]*" if ($problemNumber eq "" or $problemNumber eq "*");
		
		# had to change the pattern a little to match
		# the initial time stamp: [Fri Feb 28 22:05:11 2003].
		my $pattern = "^[[^]]*]|$studentUser\\|$setName\\|$problemNumber\\|";
		#my $pattern = "^\\|$studentUser\\|$setName\\|$problemNumber\\|";
		
		our ($lastdate,$lasttime,$lastID,$lastn);
		
		
		if (open(LOG,"$answer_log")) {
		  my $line;
		  local ($lastdate,$lasttime,$lastID,$lastn) = ("",0,"",0);
		  $self->{lastdate}       = '';
		  $self->{lasttime}       = '';
		  $self->{lastID}         = '';
		  $self->{lastn}          = '';
		  
		  # get data from file
		  my @lines = grep(/$pattern/,<LOG>); close(LOG);
		  chomp(@lines);
		
		  print "<CENTER>\n";
		  print '<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="3">',"\n";
		  print "No entries for $safeUser set $safeSet, problem $safeProb)" unless @lines;  # warn if there are no answers
		  foreach $line (sort(@lines)) {
			print $self->tableRow(split("\t",$line."\tx"));
		  }
		  print qq{<TR><TD COLSPAN="$lastn"><HR SIZE="3"></TD></TR>\n} if ($lastn);
		  print "</TABLE>\n</CENTER>\n\n";
		} else {
		  print "<B>Can't open the access log $answer_log</B>";
		}
	}

		
	return "";
}

sub tableRow {
  my $self       = shift;
  my $lastID     = $self->{lastID};
  my $lastn      = $self->{lastn};
  my $lasttime   = $self->{lasttime};
  my $lastdate   = $self->{lastdate};
  my ($out,$answer,$studentUser,$set,$prob) = "";
  my ($ID,$rtime,@answers) = @_; pop(@answers);
  my $date = scalar(localtime($rtime)); $date =~ s/\s+/ /g;
  my ($day,$month,$mdate,$time,$year) = split(" ",$date);
  $date = "$mdate $month $year";
  my $n = 2*(scalar(@answers)+1);

  if ($lastID ne $ID) {
    if ($lastn) {
      print qq{<TR><TD COLSPAN="$lastn"><HR SIZE="3"></TD></TR>\n<P>\n\n};
      print '<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="3">',"\n";
    }
    ($studentUser,$set,$prob) = (split('\|',$ID))[1,2,3];
    $out .= qq{<TR ALIGN="CENTER"><TD COLSPAN="$n"><HR SIZE="3">
               User: <B>$studentUser</B> &nbsp;
               Set: <B>$set</B> &nbsp;
               Problem: <B>$prob</B></TD></TR>\n};
    $lastID = $ID; $lasttime = 0; $lastdate = "";
  }

  $out .= qq{<TR><TD COLSPAN="$n"><HR SIZE="1"></TD></TR>\n}
    if ($rtime - $lasttime > 30*60);
  $lasttime = $rtime; $lastn = $n;

  if ($lastdate ne $date) {
    $out .= qq{<TR><TD COLSPAN="$n"><SMALL><I>$date</I></SMALL></TD></TR>\n};
    $lastdate = $date;
  }

  $out .= '<TR><TD WIDTH="10"></TD>'.
          '<TD><FONT COLOR="#808080"><SMALL>'.$time.'</SMALL></FONT></TD>';
  foreach $answer (@answers) {
    $answer =~ s/(^\s+|\s+$)//g;
    $answer = showHTML($answer);
    $answer = "<SMALL><I>empty</I></SMALL>" if ($answer eq "");
    $out .= qq{<TD WIDTH="20"></TD><TD NOWRAP>$answer</TD>};
  }
  $out .= "</TR>\n";
  $out;
}

##################################################
#
#  Make HTML symbols printable
#
sub showHTML {
    my $string = shift;
    return '' unless $string;
    $string =~ s/&/\&amp;/g;
    $string =~ s/</\&lt;/g;
    $string =~ s/>/\&gt;/g;
    $string;
}

1;
