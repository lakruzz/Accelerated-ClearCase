# Standard stuff
require 5.000;
use strict;
our ($Scriptdir, $Scriptfile);BEGIN{$Scriptdir =".\\";$Scriptfile = $0; $Scriptfile =~/(.*\\)(.*)$/ &&  do{$Scriptdir=$1;$Scriptfile=$2;}}
use lib $Scriptdir."..";


# Use clauses
use praqma::scriptlog;
use praqma::trigger_utils;

# Support trigger_utils::enable_install()
our $TRIGGER_NAME="NO_RMELEM_RMVER";                                             #Required if you call trigger_utils::enable_install()

# TODO: Review the TRIGGER_INSTALL string.
our $TRIGGER_INSTALL="mktrtype -element -all -preop rmver,rmelem vob:both";   #Required if you call trigger_utils::enable_install()

# File version
our $VERSION = "1.0"; 
our $REVISION = "1";


my $verbose_mode=1;

# Header and revision history
our $header = <<ENDHEADER;
#########################################################################
#     $Scriptfile  version $VERSION\.$REVISION                                      
#     This script is intended as trigger script for the 
#     $TRIGGER_NAME trigger.
#     The trigger prevent rmelem and rmver operations - unless you
#     are the VOB owner.
#     This script supports self-install (execute with the -install 
#     switch to learn more).
#     Read the POD documentation in the script for more details
#     Date:       2009-06-24                                            
#     Author:     Lars Kruse, lak\@praqma.net               
#     Copyright:  Praqma A/S
#     License:    GNU General Pulic License v3.0
#     Support:    http://launchpad.net/acc
#########################################################################
ENDHEADER

# Revision information
#########################################################################
our $revision = <<ENDREVISION;
DATE        EDITOR  NOTE
----------  -------------  ---------------------------------------------------
2009-06-24  Lars Kruse     1st release prepared for Novo Nordisk (version 1.0.1)
------------------------------------------------------------------------------
ENDREVISION

trigger_utils::enable_install();
trigger_utils::require_trigger_context();
our $semaphore_file = trigger_utils::enable_semaphore_backdoor();

our $log = scriptlog->new;
$log->conditional_enable();
$log->set_verbose($verbose_mode);
$log->information("logfile is: ".$log->get_logfile."\n");
$log->information("Searching valid semaphore file at '$semaphore_file'\n\t\t...but couldn't find any!\n");
$log->dump_ccvars;

our ($domain, $vobowner) = split /\\/, `cleartool desc -fmt \"\%\[owner\]p\" vob:$ENV{CLEARCASE_VOB_PN}`;

######### PREVENT REMOVAL OF version and elements ##############
unless ( lc($vobowner) eq lc($ENV{CLEARCASE_USER}) ){

  #Check that the events that fired the trigger are the ones we support - some one could have installed the trigger wrong!
  if ( ( $ENV{CLEARCASE_OP_KIND} eq "rmver") ||  ($ENV{CLEARCASE_OP_KIND} eq "rmelem") ) {
  	my $object = ($ENV{CLEARCASE_OP_KIND} eq "rmver") 
  	               ? "version" 
  	               : "element";
    my $msg = "The trigger $Scriptfile has refused the removal of the $object:\n".
              "\t\t$ENV{CLEARCASE_XPN}\n";
    $log->information($msg);
    exit 1;
  }
  
}
print "OK, but exit=1\n";
exit 1;

######################## DOCUMENTATION ##############################
=pod

=head1 NAME

Script:        F<no_rmelem_rmver.pl>

Trigger name:  C<NO_RMELEM_RMVER>

Used as a generic trigger which prevents rmelem and rmver (unless the version is a zero version).

=head1 SYNOPSIS

Runs as ClearCase trigger script installed on client VOBs both UCM and base ClearCase VOBs are supported

The scripts installs itself correctly when executed outside a trigger context using:

  no_rmelem_rmver.pl -install -vob \AdminVOB

The complete syntax is described in the POD for praqma::trigger_utils::enable_install()

=head2 Restrictions

The script is designed to install on Clients VOBs only - if you try to install this 
script on an Admin VOB it will fail.

During the install proicess, that script is supposed to run under the account which owns the VOB. The script will 
fail if that is not the case.

An exception is if you execute it in -preview mode)

=head1 DESCRIPTION

Elements and versions of elements can be removed by the users who owns them. This trigger prevents the 
operations all togeteher, regardless who owns the element or version. To bypass the script (force a rmelem or rmver 
operation) you must create the appropriate semaphor file first (see the POD documentation for 
praqma::trigger_utils::enable_semaphore_backdoor() ).

=head1 AUTHOR

Lars Kruse, E<lt>lak@praqma.netE<gt>.

=head1 BUGS

No known bugs.

=head1 COPYRIGHT

This program is distributed under the GNU General Pulic License v3.0

Support:    http://launchpad.net/acc

=for html <a href="http://launchpad.net/acc">Project home at Launchpad</a>


=cut







