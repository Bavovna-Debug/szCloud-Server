#!/usr/bin/perl

use DBI;
use File::Path;
use Fcntl;
use Switch;

require 'configuration.pl';
require 'procurator.pl';
require 'scheduler.pl';
require 'tiny.pl';
require 'files.pl';
require 'dnssec.pl';
require 'clouds.pl';
require 'zone.pl';
require 'bind.pl';

exitIfAlreadyRunning('processor');

$originator = 'CLOUD-BG';

# MySQL authorisation data.
#
use constant dbDatabase	=> 'DBI:mysql:cloud_bender';
use constant dbUsername	=> 'cloud';
use constant dbPassword	=> 'Nebula15';

$ownerUser = 106;
$ownerGroup = 113;

our $dbh;

# Check whether main directory exist. Create it if doesn't.
#
prepareDirectory($bindDirectory);

# Since now activate our own die()-handler.
#
$SIG{__DIE__}  = 'signalDieHandler';

$SIG{HUP} = "signalKillHandler";

logInfo("Start PROCESSOR");

while (1)
{
	my $processed = goThrough();
	sleep(3) unless defined $processed;
}

my $lock: shared;

sub goThrough
{
	lock $lock;

	my $scheduleId = scheduleTouchNext();
	return undef unless defined $scheduleId;

	my @schedule = scheduleFetch($scheduleId);
	my $command = $schedule[0];
	my $options = $schedule[1];

	# Establish connection to MySQL and select a database.
	#
	$dbh = DBI->connect(dbDatabase, dbUsername, dbPassword, { PrintError => 0 });

	die "DBI-connect: $DBI::errstr"
		if (defined $DBI::err) and ($DBI::err != 0);

	# From now issue messages in case of error.
	#
	$dbh->{'PrintError'} = 1;

	# Start transaction. Quit if transactions are not supported.
	#
	$dbh->{'AutoCommit'} = 0;
	die if $dbh->{'AutoCommit'} != 0;

	switch ($command)
	{
		case 'BIND_RELOAD_CONFIG'
		{
			schedulePurge('BIND_RELOAD_ZONE');
			bindReloadConfig();
		}

		case 'BIND_RELOAD_ZONE'
		{
			bindReloadZone($options);
		}

		case 'UPDATE_DOMAIN_FILE'
		{
			updateDomainFile($options);
		}

		case 'UPDATE_SUBDOMAIN_FILE'
		{
			generateZoneFile($options);
		}

		case 'DEFINE_CLOUD'
		{
			defineCloud($options);
		}

		case 'DELETE_CLOUD'
		{
			deleteCloud($options);
		}

		case 'DEFINE_DNSSEC_KEY'
		{
			generateDNSSecKey($options);
		}

		case 'DELETE_DNSSEC_KEY'
		{
			purgeDNSSecKey($options);
		}

		case 'DEFINE_DNSSEC_RULE'
		{
			defineDNSSecRule($options);
		}

		case 'DELETE_DNSSEC_RULE'
		{
			deleteDNSSecRule($options);
		}

		case 'REGENERATE_DNSSEC_KEY_LIST_FILE'
		{
			regenerateDNSSecKeyListFile();
		}

		case 'DEACTIVATE_EXPIRED_CLOUDS'
		{
			deactivateExpiredClouds();
		}

		case 'PURGE_FILES'
		{
			purgeDeletedFiles();
		}
	}
	scheduleReady($scheduleId);

	$dbh->commit()
		or die $DBI::errstr;

	# Leave MySQL connection.
	#
	$dbh->disconnect();

	return $scheduleId;
}

#
# Common routine to be called in case of error.
#
sub signalDieHandler
{
	my($message) = @_;

	printf "ERROR: %s\n", $message;
	logError($message);

	# We must exit in case of error to ommit that transaction is commited.
	#
	exit;
}

#
# Common routine to be called in case program becomes a signal.
#
sub signalKillHandler
{
	goThrough();
}
