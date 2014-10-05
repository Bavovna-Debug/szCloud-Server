our $originator = '';

use constant pathPIDFiles		=> '/var/run/cloud';

use constant procuratorDatabase => 'DBI:mysql:procurator';
use constant procuratorUsername => 'cloud';
use constant procuratorPassword => 'Nebula15';

sub logInfo
{
	my($message) = @_;

	my $localDBH = DBI->connect(procuratorDatabase, procuratorUsername, procuratorPassword,
		{ AutoCommit => 1, PrintError => 1 });

	$localDBH->do("CALL procurator.log_info(?, ?)", undef, $originator, $message);

	$localDBH->disconnect();
}

sub logWarning
{
	my($message) = @_;

	my $localDBH = DBI->connect(procuratorDatabase, procuratorUsername, procuratorPassword,
		{ AutoCommit => 1, PrintError => 1 });

	$localDBH->do("CALL procurator.log_warning(?, ?)", undef, $originator, $message);

	$localDBH->disconnect();
}

sub logError
{
	my($message) = @_;

	my $localDBH = DBI->connect(procuratorDatabase, procuratorUsername, procuratorPassword,
		{ AutoCommit => 1, PrintError => 1 });

	$localDBH->do("CALL procurator.log_error(?, ?)", undef, $originator, $message);

	$localDBH->disconnect();
}

sub exitIfAlreadyRunning
{
	my($programName) = @_;

	prepareDirectory(pathPIDFiles);

	my $pidFilePath = sprintf "%s/%s.pid", pathPIDFiles, $programName;

	if ( -e $pidFilePath) {
		my $runningPID = readRealFilePlain($pidFilePath);
		if ($runningPID) {
			exit if kill 0, $runningPID
		}
	}

	my $myPID = $$;
	saveRealFilePlain($pidFilePath, $myPID);
}

sub notifyIfRunning
{
	my($programName) = @_;

	prepareDirectory(pathPIDFiles);

	my $pidFilePath = sprintf "%s/%s.pid", pathPIDFiles, $programName;

	if ( -e $pidFilePath) {
		my $runningPID = readRealFilePlain($pidFilePath);
		kill HUP, $runningPID if $runningPID;
	}
}

1
