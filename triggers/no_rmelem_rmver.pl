require 5.000;
use strict;
our( $Scriptdir, $Scriptfile );

BEGIN {
    $Scriptdir  = ".\\";
    $Scriptfile = $0;      # Assume the script is called from 'current directory' (no leading path - $0 is the file)
    $Scriptfile =~ /(.*\\)(.*)$/ && do { $Scriptdir = $1; $Scriptfile = $2; }    # Try to match on back-slashes (file path included) and correct mis-assumption if any found
}
use lib $Scriptdir. "..";
use praqma::scriptlog;
use praqma::trigger_helper;

#Required if you call trigger_helper->enable_install
our $TRIGGER_NAME = "ACC_NO_RMELEM_RMVER";

our %install_params = (
    "name"     => $TRIGGER_NAME,                                                 # The name og the trigger
    "mktrtype" => "-element -all -preop rmver,rmelem",                           # The stripped-down mktrtype command
    "supports" => "bccvob,ucmvob",                                               # csv list of generic and/or custom VOB types (case insensetive)
);

# File version
our $VERSION  = "1.1";
our $REVISION = "3";

my $verbose_mode = 1;

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
2009-11-16  Lars Kruse     Now supporting the new enable_install method
2009-11-25  Jens Brejner   Isolate POD in separate file (v1.1.2)
2010-05-31  Jens Brejner   Enhance error checking after system calls (v1.1.3)
------------------------------------------------------------------------------
ENDREVISION

#Enable the features in trigger_helper
our $thelp = trigger_helper->new;
$thelp->enable_install( \%install_params );    #Pass a reference to the install-options
$thelp->require_trigger_context;
our $semaphore_status = $thelp->enable_semaphore_backdoor;

#Enable the features in scriptlog
our $log = scriptlog->new;
$log->conditional_enable();                    #Define either environment variabel CLEARCASE_TRIGGER_DEBUG=1 or SCRIPTLOG_ENABLE=1 to start logging
$log->set_verbose;                             #Define either environment variabel CLEARCASE_TRIGGER_VERBOSE=1 or SCRIPTLOG_VERBOSE=1 to start printing to STDOUT
our $logfile = $log->get_logfile;
($logfile) && $log->information("logfile is: $logfile\n");    # Logfile is null if logging isn't enabled.
$log->information($semaphore_status);
$log->dump_ccvars;                                            # Run this statement to have the trigger dump the CLEARCASE variables

# Cache the vobowner
my $cmd        = "cleartool desc -fmt \"\%\[owner\]p\" vob:$ENV{CLEARCASE_VOB_PN}";
my $clearowner = `$cmd`;

if ($?) {                                                     # Failed reading vob owner
    $log->enable(1);
    $log->error( "The command: '$cmd' failed\n" );
    exit 1;
}

our( $domain, $vobowner ) = split /\\/, $clearowner;

######### PREVENT REMOVAL OF VERSIONS AND ELEMENTS ##############
unless ( lc($vobowner) eq lc( $ENV{CLEARCASE_USER} ) ) {      # Do nothing if user is the vob owner

    if ( ( $ENV{CLEARCASE_OP_KIND} eq "rmver" ) || ( $ENV{CLEARCASE_OP_KIND} eq "rmelem" ) ) {    #Check that the events that fired the trigger are the ones we support
        my $object = ( $ENV{CLEARCASE_OP_KIND} eq "rmver" )                                       # Cache what 'mode' we're runningto make a meaningful message
          ? "version"
          : "element";
        my $msg = "The trigger $Scriptfile has refused the removal of the $object:\n" . "\t\t$ENV{CLEARCASE_XPN}\n";
        $log->information($msg);
        exit 1;
    }
    $log->warning("This script is triggered by an event which it was not originally designed to handle\t\tMaybe it's not installed correct?");
}

exit 0;
__END__
