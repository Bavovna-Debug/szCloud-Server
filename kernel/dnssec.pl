use Switch;

sub cloudIdOfDNSSecKey
{
	my($dnssecKeyId) = @_;

	my $sql;
	my $hashId;

	$sql = qq{
		SELECT hash_id
		FROM cloud_bender.dnssec_rules
			USE INDEX (idx_dnssec_key_id)
		JOIN cloud_bender.hash_repository
			USE INDEX (PRIMARY, idx_object_type)
			USING (hash_id)
		WHERE dnssec_key_id = ?
		  AND object_type = 'CLD'
	};
	$hashId = $dbh->selectrow_array($sql, undef, $dnssecKeyId);

	if (!defined $hashId) {
		$sql = qq{
			SELECT parent_id
			FROM cloud_bender.dnssec_rules
				USE INDEX (idx_dnssec_key_id)
			JOIN cloud_bender.hash_repository
				USE INDEX (PRIMARY, idx_object_type)
				USING (hash_id)
			WHERE dnssec_key_id = ?
			AND object_type = 'HST'
			GROUP BY parent_id
		};
		$hashId = $dbh->selectrow_array($sql, undef, $dnssecKeyId);
	}

	return $hashId;
}

#
#
#
sub createDNSSecKey
{
	my($hashId, $userId, $keyName, $keyType, $keySize, $algorithm) = @_;

	my $sql;

	$sql = qq{
		SELECT cloud_bender.define_dnssec_key(TRUE, ?, ?, ?, ?, ?)
	};
	my $dnssecKeyId = $dbh->selectrow_array($sql, undef,
		$userId, $keyName, $keyType, $keySize, $algorithm);

	$sql = qq{
		SELECT cloud_bender.define_dnssec_rule(?, ?, ?, ?)
	};
	$dbh->do($sql, undef, $userId, $dnssecKeyId, $hashId, 'ANY')
		or die $DBI::errstr;

	$dbh->commit()
		or die $DBI::errstr;

	generateDNSSecKey($dnssecKeyId);
}

#
#
#
sub generateDNSSecKey
{
	my($dnssecKeyId) = @_;

	my($sql, $sth);

	$sql = qq{
		SELECT user_id, key_name, key_type, key_size, key_algorithm, key_file_id, private_file_id
		FROM cloud_bender.dnssec_keys
			USE INDEX (PRIMARY)
		WHERE dnssec_key_id = ?
	};
	my($userId, $keyName, $keyType, $keySize, $algorithm, $keyFileId, $privateFileId) =
		$dbh->selectrow_array($sql, undef, $dnssecKeyId)
			or die $DBI::errstr;

	my $directory = userUserDirectory($userId) . '/keys';

	# Remove old key files if they exist.
	#
	removeFile($keyFileId)
		if defined $keyFileId;
	removeFile($privateFileId)
		if defined $privateFileId;

	# Start dnssec-keygen to generate key files pair for this host.
	#
	my @command = ("/usr/sbin/dnssec-keygen",
		sprintf("-a %s -b %d -K %s -r /dev/urandom -n %s %s",
			$algorithm,
			$keySize,
			$directory,
			$keyType,
			$keyName));

	my $keyFileNamePrefix = `@command`;
	chop $keyFileNamePrefix;

	$keyFileName = $keyFileNamePrefix . '.key';
	$privateFileName = $keyFileNamePrefix . '.private';

	# Fetch secret key from generated files.
	#
	my @content = readRealFile($directory . '/' . $keyFileName);
	my $secret;
	for my $line (@content)
	{
		chop $line;
		my @parts = split / /, $line;

		next if ($parts[0] cmp ($keyName . '.')) != 0;

		for (my $index = 6; $index < @parts; $index++) {
			$secret .= $parts[$index];
		}
		last;
	}

	# Create corresponding entries for both generated files in a file repository.
	#
	$keyFileId = createFile($directory, $keyFileName);
	$privateFileId = createFile($directory, $privateFileName);

	# Register new key.
	#
	$sql = qq{
		UPDATE LOW_PRIORITY cloud_bender.dnssec_keys
		SET need_recreation = FALSE,
			key_secret = ?,
			key_file_id = ?,
			private_file_id = ?
		WHERE dnssec_key_id = ?
	};
	$dbh->do($sql, undef,
		$secret,
		$keyFileId,
		$privateFileId,
		$dnssecKeyId)
		or die $DBI::errstr;

	$dbh->commit()
		or die $DBI::errstr;

	scheduleEvent('REGENERATE_DNSSEC_KEY_LIST_FILE', undef, 0);
}

#
#
#
sub purgeDNSSecKey
{
	my($dnssecKeyId) = @_;

	my $sql;

	$sql = qq{
		SELECT key_file_id, private_file_id
		FROM cloud_bender.dnssec_keys
			USE INDEX (PRIMARY)
		WHERE dnssec_key_id = ?
	};
	my($keyFileId, $privateFileId) =
		$dbh->selectrow_array($sql, undef, $dnssecKeyId)
			or die $DBI::errstr;

	# Delete key file if it exists.
	#
	deleteFile($keyFileId)
		if defined $keyFileId;

	# Delete private file if it exists.
	#
	deleteFile($privateFileId)
		if defined $privateFileId;

	$sql = qq{
		DELETE FROM cloud_bender.dnssec_keys
		WHERE dnssec_key_id = ?
	};
	$dbh->do($sql, undef, $dnssecKeyId)
		or die $DBI::errstr;

	$dbh->commit()
		or die $DBI::errstr;

	scheduleEvent('REGENERATE_DNSSEC_KEY_LIST_FILE', undef, 0);
}

#
#
#
sub defineDNSSecRule
{
	my($dnsSecRuleId) = @_;

	my($sql);

	$sql = qq{
		SELECT hash_id
		FROM cloud_bender.dnssec_rules
		WHERE dnssec_rule_id = ?
	};
	my $hashId = $dbh->selectrow_array($sql, undef, $dnsSecRuleId)
		or die $DBI::errstr;

	$sql = qq{
		SELECT hash_id
		FROM cloud_bender.hash_repository
		WHERE hash_id = ?
		  AND object_type = 'CLD'
		UNION
		SELECT parent_id
		FROM cloud_bender.hash_repository
		WHERE hash_id = ?
		  AND object_type = 'HST'
	};
	my $subdomainId = $dbh->selectrow_array($sql, undef, $hashId, $hashId)
		or die $DBI::errstr;

	scheduleEvent('UPDATE_SUBDOMAIN_FILE', $subdomainId, 0);
}

#
#
#
sub deleteDNSSecRule
{
	my($dnsSecRuleId) = @_;

	my($sql);

	$sql = qq{
		SELECT hash_id
		FROM cloud_bender.dnssec_rules
		WHERE dnssec_rule_id = ?
	};
	my $hashId = $dbh->selectrow_array($sql, undef, $dnsSecRuleId)
		or die $DBI::errstr;

	$sql = qq{
		SELECT hash_id
		FROM cloud_bender.hash_repository
		WHERE hash_id = ?
		  AND object_type = 'CLD'
		UNION
		SELECT parent_id
		FROM cloud_bender.hash_repository
		WHERE hash_id = ?
		  AND object_type = 'HST'
	};
	my $subdomainId = $dbh->selectrow_array($sql, undef, $hashId, $hashId)
		or die $DBI::errstr;

	$sql = qq{
		DELETE FROM cloud_bender.dnssec_rules
		WHERE dnssec_rule_id = ?
	};
	$dbh->do($sql, undef, $dnsSecRuleId)
		or die $DBI::errstr;

	scheduleEvent('UPDATE_SUBDOMAIN_FILE', $subdomainId, 0);
}


#
#
#
sub regenerateDNSSecKeyListFile
{
	my($sql, $sth);

	$sql = qq{
		SELECT key_name AS name, key_algorithm AS algorithm, key_secret AS secret
		FROM cloud_bender.dnssec_keys
			USE INDEX FOR ORDER BY (idx_internal)
		ORDER BY internal DESC
	};
	my $keys = $dbh->selectall_arrayref($sql, { Slice => {} })
		or die $DBI::errstr;

	my $content = '';
	foreach my $key (@$keys)
	{
		my($keyStatement) = readRealFilePlain($templateDNSSecKey);

		$keyStatement =~ s/<HOST_NAME>/$key->{name}/;
		$keyStatement =~ s/<ALGORITHM>/$key->{algorithm}/;
		$keyStatement =~ s/<SECRET>/$key->{secret}/;

		$content .= $keyStatement;
	}

	saveRealFilePlain($bindDirectory . '/' . $configDNSSecKeys, $content);
}

1
