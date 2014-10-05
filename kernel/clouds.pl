sub defineCloud
{
	my($hashId) = @_;
	my($sql);

	my $fullCloudName = fullHashName($hashId);
	my $userId = hashOwner($hashId);

	# Fetch neccessary information about this cloud.
	#
	$sql = qq{
		SELECT soa_id
		FROM cloud_bender.clouds
			USE INDEX (idx_hash_id)
		WHERE hash_id = ?
	};
	my $soaId = $dbh->selectrow_array($sql, undef, $hashId)
		or die $DBI::errstr;

	my $directory = userUserDirectory($userId);

	# Create corresponding entries for all generated files in a file repository.
	#
	my $bindFileId = createFile($directory, $fullCloudName . '.bind');
	my $zoneFileId = createFile($directory, $fullCloudName);
	my $journalFileId = createFile($directory, $fullCloudName . '.jnl');

	my $dnssecKeyId = createDNSSecKey($hashId, $userId, $fullCloudName, 'HOST', 512, 'HMAC-MD5');

	# Prepare zone header.
	#
	my $content = zoneFileContent($hashId, $soaId);

	# Add standard TTL for hosts.
	#
	$content .= "\$TTL 60\n";

	# And save it to file.
	#
	saveFilePlain($zoneFileId, $content);

	# Update entry in cloud list.
	#
	$sql = qq{
		UPDATE cloud_bender.clouds
			USE INDEX (idx_hash_id)
		SET bind_file_id = ?,
			zone_file_id = ?,
		    journal_file_id = ?,
		    confirmed = activated
		WHERE hash_id = ?
	};
	$dbh->do($sql, undef,
		$bindFileId,
		$zoneFileId,
		$journalFileId,
		$hashId)
		or die $DBI::errstr;

	# Signal that BIND has to be restarted.
	#
	scheduleEvent('UPDATE_SUBDOMAIN_FILE', $hashId, 0);
	scheduleEvent('BIND_RELOAD_CONFIG', undef, 0);
}

sub deleteCloud
{
	my($hashId) = @_;

	my($sql);

	# Fetch file ids end delete files if they exist.
	#
	$sql = qq{
		SELECT bind_file_id, zone_file_id, journal_file_id
		FROM cloud_bender.clouds
			USE INDEX (idx_hash_id)
		WHERE hash_id = ?
	};
	my($bindFileId, $zoneFileId, $journalFileId) =
		$dbh->selectrow_array($sql, undef, $hashId)
			or die $DBI::errstr;

	deleteFile($bindFileId)
		if defined $bindFileId;

	deleteFile($zoneFileId)
		if defined $zoneFileId;

	deleteFile($journalFileId)
		if defined $journalFileId;

	# Mark cloud that it does not have any related files any more.
	#
	$sql = qq{
		UPDATE cloud_bender.clouds
			USE INDEX (idx_hash_id)
		SET bind_file_id = NULL,
		    zone_file_id = NULL,
		    journal_file_id = NULL,
		    confirmed = activated
		WHERE hash_id = ?
	};
	$dbh->do($sql, undef, $hashId)
		or die $DBI::errstr;

	# Signal that BIND has to be restarted.
	#
	scheduleEvent('BIND_RELOAD_CONFIG', undef, 0);
}

sub deactivateExpiredClouds
{
	my($sql, $sth);

	# Mark cloud that it does not have any related files any more.
	#
	$sql = qq{
		UPDATE cloud_bender.clouds AS clouds
		SET activated = FALSE
		WHERE activated IS TRUE
		AND NOT EXISTS (
			SELECT *
			FROM cloud_bender.hash_activations AS activations
			WHERE activations.hash_id = clouds.hash_id
			  AND CURRENT_TIMESTAMP BETWEEN valid_from AND valid_till
		)
	};

	$sth = $dbh->prepare($sql)
			or die $DBI::errstr;

	$sth->execute()
			or die $DBI::errstr;

	if ($sth->rows() > 0) {
		refreshTopDomains();
		refreshSubDomains();
		scheduleEvent('BIND_RELOAD_CONFIG', undef, 0);
	}
}

1
