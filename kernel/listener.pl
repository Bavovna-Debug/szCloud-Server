#!/usr/bin/perl

require 'configuration.pl';
require 'procurator.pl';
require 'logs.pl';
require 'files.pl';

use DBI;
use File::Tail;

# MySQL authorisation data.
#
use constant dbDatabase	=> 'DBI:mysql:procurator';
use constant dbUsername	=> 'cloud';
use constant dbPassword	=> 'Nebula15';

exitIfAlreadyRunning('listener');

$originator = 'LISTENER';

# Since now activate our own die()-handler.
#
$SIG{__DIE__}  = 'signalDieHandler';

my @keys = keys %logs;

logInfo("Start LISTENER");

foreach my $key (@keys)
{
	my $pid = fork();
	die "fork() failed: $!" unless defined $pid;

	if ($pid)
	{
		my $fileName = $logs{$key}{FileName};
		my $tableName = $logs{$key}{TableName};

		my $logFile = File::Tail->new(
			name => $fileName,
			interval => 0,
			maxinterval => 2,
			tail => -1
		);

		while (defined(my $message = $logFile->read))
		{
			chomp $message;

			# Establish connection to MySQL and select a database.
			#
			my $dbh = DBI->connect(dbDatabase, dbUsername, dbPassword,
				{ AutoCommit => 1, PrintError => 1 });

			die "DBI-connect: $DBI::errstr"
				if (defined $DBI::err) and ($DBI::err != 0);

#			$sql = qq{
#				SELECT COUNT(*)
#				FROM cloud_logger.$tableName
#				WHERE message LIKE ?
#			};
#			my($counter) = $dbh->selectrow_array($sql, undef, $message);

#			next if $counter != 0;

			my $sql = qq{
				INSERT LOW_PRIORITY
				INTO cloud_logger.$tableName (message)
				VALUES (?)
			};
			$dbh->do($sql, undef, $message)
				or die $DBI::errstr;

			notifyIfRunning('interceptor')
				if ($key cmp 'update') == 0;

			# Leave MySQL connection.
			#
			$dbh->disconnect();
		}

		last;
	}		
}

#
# Common routine to be called in case of error.
#
sub signalDieHandler
{
	my($message) = @_;
	logError($message);
	exit;
}
