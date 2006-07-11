require 5.000;
use strict;

our ( $Scriptdir, $Scriptfile, $parentdir );

BEGIN {
	use File::Basename;
	$Scriptdir  = dirname(__FILE__) . "\\";
	$Scriptfile = basename(__FILE__);

	# Ensure that the view-private file will get named back on rejection.
	END {
		rename( "$ENV{CLEARCASE_PN}.mkelem", $ENV{CLEARCASE_PN} )
		  if $? && !-e $ENV{CLEARCASE_PN} && -e "$ENV{CLEARCASE_PN}.mkelem";

	}
}

use lib $Scriptdir . "..\\";

use praqma::scriptlog;
use praqma::trigger_helper;

$| = 1;

#Required if you call trigger_helper->enable_install
our $TRIGGER_NAME = "ACC_PRE_LNNAME";

our %install_params = (
	"name"     => $TRIGGER_NAME,                     # The name of the trigger
	"mktrtype" => "-element -all -preop lnname ",    # The stripped-down mktrtype command
	"supports" => "bccvob,ucmvob",                   # csv list of generic and/or custom VOB types (case insensetive)
);

# File version
our $VERSION  = "0.1";
our $REVISION = "1";

# Header and revision history
our $header = <<ENDHEADER;
#########################################################################
#     $Scriptfile  version $VERSION\.$REVISION
#     This script is intended as trigger script for the
#     $TRIGGER_NAME trigger.
#     The trigger runs before rmname on an element
#     The user cannot rmname if the file is checked out.
#     This script supports self-install (execute with the -install
#     switch to learn more).
#     Read the POD documentation for more details
#     Date:       2011-27-09
#     Author:
#     Copyright:  Praqma A/S
#     License:    GNU General Pulic License v3.0
#     Support:    http://launchpad.net/acc
#########################################################################
ENDHEADER

# Revision information
#########################################################################
our $revision = <<ENDREVISION;
DATE        EDITOR             NOTE
----------  -----------------  ---------------------------------------------------
2011-09-27  Margit Bennetzen   Script added to acc (v0.1)
2011-11-01  Margit Bennetzen   Script rename to pre_lnname and whitespacecheck added (v0.2)
------------------------------------------------------------------------------
ENDREVISION

#Enable the features in trigger_helper
our $thelp = trigger_helper->new;
$thelp->enable_install( \%install_params );    #Pass a reference to the install-options
$thelp->require_trigger_context;
our $semaphore_status = $thelp->enable_semaphore_backdoor;

# Script scope variables
my %trgconfig;

# Enable external configuration options
$thelp->get_config( \%trgconfig );

#Enable the features in scriptlog

our $log = scriptlog->new();
$log->set_verbose();

#Define either environment variable CLEARCASE_TRIGGER_DEBUG=1 or SCRIPTLOG_ENABLE=1 to start logging
$log->conditional_enable();

my $logfile = $log->get_logfile;
($logfile) && $log->information("logfile is: $logfile\n");    # Logfile is null if logging isn't enabled.
($logfile) && $log->information($semaphore_status);
($logfile) && $log->dump_ccvars;                              # Run this statement to have the trigger dump the CLEARCASE variables

########################### MAIN ###########################
# Vob symbolic links can not be renamed.
exit 0 if -l $ENV{CLEARCASE_PN};

# Only process if proper OP_KIND
if ( $ENV{CLEARCASE_OP_KIND} eq "lnname" ) {

	# Check pathlength if requested
	if ( $trgconfig{pathlength} > 0 ) {
		my $pathlength = length( $ENV{CLEARCASE_PN} );
		if ( $pathlength > $trgconfig{pathlength} ) {
			$log->error("The length of [$ENV{CLEARCASE_PN}] is $pathlength, which exceeds $trgconfig{pathlength}. Use a shorter name.");
			$log->error("The path length limitation of $trgconfig{pathlength}, has been chosen by ClearCase Administrator.");
		}
		else {
			$log->information("Length of [$ENV{CLEARCASE_XPN}] is OK; $pathlength is less than $trgconfig{pathlength}");
		}
	}

	# Check for whitespaces
	if ( $trgconfig{whitespacecheck} ) {
		my ( $name, $extension ) = ( fileparse( $ENV{CLEARCASE_PN}, qr/\.[^.]*/ ) )[ 0, 2 ];
		my $filename = $name . $extension;

		# Double whitespace anywhere ?
		complain( $filename, $name )      if ( $name      =~ m/\s{2,}/g );
		complain( $filename, $extension ) if ( $extension =~ m/\s{2,}/g );

		# Starts with whitespace ?
		complain( $filename, $name )      if ( $name      =~ m/^\s+.*/g );
		complain( $filename, $extension ) if ( $extension =~ m/^\s+.*/g );

		# Ends with whitespace ?
		complain( $filename, $name )      if ( $name      =~ m/.*\s+$/g );
		complain( $filename, $extension ) if ( $extension =~ m/.*\s+$/g );

	}

	# Cleanup
	my $exitcode = $log->get_accumulated_errorlevel();

	if ( $exitcode eq 2 ) {
		$parentdir = dirname( $ENV{CLEARCASE_PN} );

		# is parentdir checked-out ?
		if ( -w $parentdir ) {
			$log->information("[$parentdir] is checkedout");

			if (`cleartool diff -pre \"$parentdir\"`) {

				# "cleartool diff" returns 0 if versions are identical
				$log->information("[$parentdir] is being checked in");
				qx(cleartool checkin -nc \"$parentdir\");

			}
			else {
				$log->information("Undoing checkout of [$parentdir]");
				qx(cleartool uncheckout -rm -nc \"$parentdir\");
			}

		}
	}
	exit $exitcode;

}

die "Trigger called out of context, we should never end here.";

############################## S U B S ########################################

sub complain {
	my $filename = shift;
	my $part     = shift;
	my $msg      = "\n\"$filename\" contains forbidden whitespace in this part:\n\"$part\"\n\"";
	$msg = $msg . "+" x ( length($part) ) . "\"\n";

	$log->error($msg);

}

__END__
