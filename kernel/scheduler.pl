use constant schedulerDatabase => 'DBI:mysql:cloud_bender';
use constant schedulerUsername => 'cloud';
use constant schedulerPassword => 'Nebula15';

sub scheduleEvent
{
	my($command, $options, $seconds) = @_;

	my $localDBH = DBI->connect(schedulerDatabase, schedulerUsername, schedulerPassword,
		{ AutoCommit => 1, PrintError => 1 });

	my $sql = qq{
		CALL cloud_bender.schedule(?, ?, ?)
	};
	$localDBH->do($sql, undef, $command, $options, $seconds)
		or die $DBI::errstr;

	$localDBH->disconnect();
}

sub schedulePurge
{
	my($command) = @_;

	my $localDBH = DBI->connect(schedulerDatabase, schedulerUsername, schedulerPassword,
		{ AutoCommit => 1, PrintError => 1 });

	my $sql = qq{
		DELETE LOW_PRIORITY
		FROM cloud_bender.schedules
		WHERE touched IS NULL
		  AND command = ?
	};
	$localDBH->do($sql, undef, $command)
		or die DBI::errstr;

	$localDBH->disconnect();
}

sub scheduleTouchNext
{
	my($command) = @_;

	my $localDBH = DBI->connect(schedulerDatabase, schedulerUsername, schedulerPassword,
		{ AutoCommit => 1, PrintError => 1 });

	my $sql = qq{
		SELECT MIN(schedule_id)
		FROM cloud_bender.schedules
			USE INDEX (idx_touched)
		WHERE scheduled <= NOW()
		  AND touched IS NULL
	};
	my $scheduleId = $localDBH->selectrow_array($sql);

	if (defined $scheduleId) {
		$sql = qq{
			UPDATE LOW_PRIORITY cloud_bender.schedules
				USE INDEX (PRIMARY)
			SET touched = CURRENT_TIMESTAMP
			WHERE schedule_id = ?
		};
		$localDBH->do($sql, undef, $scheduleId)
			or die DBI::errstr;
	}

	$localDBH->disconnect();

	return $scheduleId;
}

sub scheduleTouchByName
{
	my($command) = @_;

	my $localDBH = DBI->connect(schedulerDatabase, schedulerUsername, schedulerPassword,
		{ AutoCommit => 1, PrintError => 1 });

	my $sql = qq{
		SELECT schedule_id
		FROM cloud_bender.schedules
			USE INDEX (idx_touched_command)
		WHERE scheduled <= NOW()
		  AND touched IS NULL
		  AND command = ?
	};
	my $scheduleId = $localDBH->selectrow_array($sql, undef, $command);

	if (defined $scheduleId) {
		$sql = qq{
			UPDATE LOW_PRIORITY cloud_bender.schedules
				USE INDEX (PRIMARY)
			SET touched = CURRENT_TIMESTAMP
			WHERE schedule_id = ?
		};
		$localDBH->do($sql, undef, $scheduleId)
			or die DBI::errstr;
	}

	$localDBH->disconnect();

	return $scheduleId;
}

sub scheduleFetch
{
	my($scheduleId) = @_;

	my $localDBH = DBI->connect(schedulerDatabase, schedulerUsername, schedulerPassword,
		{ AutoCommit => 1, PrintError => 1 });

	my $sql = qq{
		SELECT command, options
		FROM cloud_bender.schedules
			USE INDEX (PRIMARY)
		WHERE schedule_id = ?
	};
	my @schedule = $localDBH->selectrow_array($sql, undef, $scheduleId)
		or die DBI::errstr;

	$localDBH->disconnect();

	return @schedule;
}

sub scheduleReady
{
	my($scheduleId) = @_;

	my $localDBH = DBI->connect(schedulerDatabase, schedulerUsername, schedulerPassword,
		{ AutoCommit => 1, PrintError => 1 });

	my $sql = qq{
		UPDATE LOW_PRIORITY cloud_bender.schedules
			USE INDEX (PRIMARY)
		SET processed = CURRENT_TIMESTAMP
		WHERE schedule_id = ?
	};
	$localDBH->do($sql, undef, $scheduleId)
		or die DBI::errstr;

	$localDBH->disconnect();
}

1
