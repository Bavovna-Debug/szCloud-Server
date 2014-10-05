use File::Path;

sub defineHost
{
	my($hashId, $userId) = @_;

	my $sql;

	# Fetch neccessary information about this host.
	#
	$sql = qq{
		SELECT parent_id
		FROM cloud_bender.hash_repository
		WHERE hash_id = ?
	};
	my $cloudId = $dbh->selectrow_array($sql, undef, $hashId)
		or die $DBI::errstr;

	# Raise a semaphore in a cloud which will let recreate its zone file.
	#
	$sql = qq{
		UPDATE cloud_bender.clouds
			USE INDEX (idx_hash_id)
		SET need_refresh = TRUE
		WHERE hash_id = ?
	};
	$dbh->do($sql, undef, $cloudId)
		or die $DBI::errstr;

	# Confirm completion.
	#
	$sql = "CALL cloud_bender.confirm_activated_state(?)";
	$dbh->do($sql, undef, $hashId)
		or die $DBI::errstr;

	# Signal that BIND has to be restarted.
	#
	scheduleBindRestart(0);
}

sub deleteHost
{
	my($hashId) = @_;

	my $sql;

	# Mark host that it does not have any DNS related information any more.
	#
	$sql = qq{
		DELETE FROM cloud_bender.dnssec_key_xref
		WHERE hash_id = ?
	};
	$dbh->do($sql, undef, $hashId)
		or die $DBI::errstr;

	# Raise a semaphore in a cloud which will let recreate its zone file.
	#
	$sql = qq{
		UPDATE cloud_bender.clouds
			USE INDEX (idx_hash_id)
		SET need_refresh = TRUE
		WHERE hash_id = ?
	};
	$dbh->do($sql, undef, $cloudId)
		or die $DBI::errstr;

	# Confirm completion.
	#
	$sql = "CALL cloud_bender.confirm_activated_state(?)";
	$dbh->do($sql, undef, $hashId)
		or die $DBI::errstr;

	# Signal that BIND has to be restarted.
	#
	scheduleBindRestart(0);
}

1
