#
#
#
sub refreshTopDomains
{
	my($sql, $sth);

	# Fetch a list of domains whose BIND configuration files
	# must be included in a central BIND configuration file.
	#
	$sql = qq{
		SELECT hash_id, domain_file_id, name
		FROM cloud_bender.hash_repository
			USE INDEX (PRIMARY)
		JOIN cloud_bender.domains
			USE INDEX (idx_hash_id, idx_domain_file_id)
			USING (hash_id)
		WHERE domain_file_id IS NOT NULL
	};
	$sth = $dbh->prepare($sql)
		or die $DBI::errstr;

	$sth->execute()
		or die $DBI::errstr;

	my $content = '';
	while (my @row = $sth->fetchrow_array())
	{
		my $domainId = shift @row;
		my $domainFileId = shift @row;
		my $domainName = shift @row;

		my $domainFilePath = getFilePath($domainFileId);

		# Read template.
		#
		my $template = readRealFilePlain($templateTopDomain);

		$template =~ s/<DOMAIN_NAME>/$domainName/;
		$template =~ s/<ZONE_FILE>/$domainFilePath/;

		# Add to content.
		#
		$content .= $template;
	}

	$sth->finish();

	# Save content.
	#
	saveRealFilePlain($bindDirectory . '/' . $bindTopDomains, $content);
}

#
#
#
sub refreshSubDomains
{
	my($sql, $sth);

	# Fetch a list of clouds whose BIND configuration files
	# must be included in a central BIND configuration file.
	#
	$sql = qq{
		SELECT hash_id, bind_file_id
		FROM cloud_bender.clouds
			USE INDEX (idx_activated_confirmed)
		WHERE activated IS TRUE
		  AND confirmed IS TRUE
	};
	$sth = $dbh->prepare($sql)
		or die $DBI::errstr;

	$sth->execute()
		or die $DBI::errstr;

	my($statements);
	while (my($hashId, $bindFileId) = $sth->fetchrow_array())
	{
		next unless defined $bindFileId;

		my $filePath = getFilePath($bindFileId);

		# Add include statement to a list.
		#
		$statements .= sprintf "include \"%s\";\n", $filePath;
	}

	$sth->finish();

	# Save all include statements.
	#
	saveRealFilePlain($bindDirectory . '/' . $bindSubDomains, $statements);
}

#
#
#
sub generateZoneFile
{
	my($cloudId) = @_;

	my($sql, $sth);

	my $cloudName = fullHashName($cloudId);

	# Fetch a list of clouds whose BIND configuration files have to be recreated.
	#
	$sql = qq{
		SELECT user_id, bind_file_id, zone_file_id
		FROM cloud_bender.clouds
			USE INDEX (idx_hash_id)
		JOIN cloud_bender.hash_repository
			USE INDEX (PRIMARY)
			USING (hash_id)
		WHERE hash_id = ?
	};
	my($userId, $bindFileId, $zoneFileId) = $dbh->selectrow_array($sql, undef, $cloudId)
		or die $DBI::errstr;

	# Fetch list of DNSSec keys for this cloud.
	#
	$sql = qq{
		SELECT dnssec_key_id AS keyId, internal, key_name AS name, key_algorithm AS algorithm, key_secret AS secret
		FROM cloud_bender.dnssec_rules
			USE INDEX (idx_hash_id)
			USE INDEX FOR GROUP BY (idx_dnssec_key_id)
		JOIN cloud_bender.dnssec_keys
			USE INDEX (PRIMARY)
			USING (dnssec_key_id)
		WHERE hash_id IN (
			SELECT hash_id
			FROM cloud_bender.hash_repository
			WHERE hash_id = ? OR parent_id = ?
		)
		GROUP BY dnssec_key_id
	};
	my $keys = $dbh->selectall_arrayref($sql, { Slice => {} }, $cloudId, $cloudId)
		or die $DBI::errstr;

	# Prepare list of keys.
	#
	my @updatePolicy;
	foreach my $key (@$keys)
	{
		# Fetch list of hashes which authorised by this DNSSec key.
		#
		$sql = qq{
			SELECT hash_id
			FROM cloud_bender.dnssec_rules
				USE INDEX (PRIMARY)
				USE INDEX FOR GROUP BY (idx_hash_id)
			WHERE dnssec_key_id = ?
			GROUP BY hash_id
		};
		my $records = $dbh->selectall_arrayref($sql, undef, $key->{keyId})
			or die $DBI::errstr;

		foreach my $record (@$records)
		{
			my $hashId = shift $record;

			# Fetch list of hashes which authorised by this DNSSec key.
			#
			$sql = qq{
				SELECT dns_type
				FROM cloud_bender.dnssec_rules
					USE INDEX (idx_dnssec_key_id_hash_id)
				WHERE dnssec_key_id = ?
				  AND hash_id = ?
			};
			my $dnsTypes = $dbh->selectcol_arrayref($sql, undef, $key->{keyId}, $hashId)
				or die $DBI::errstr;

			my $statement;
			if ($key->{internal}) {
				$statement = sprintf("\n\t\tgrant %s. subdomain %s.;",
					$key->{name},
					fullHashName($hashId));
				$statement .= sprintf("\n\t\tgrant %s. name %s.;",
					$key->{name},
					fullHashName($hashId));
			} else {
				$statement = sprintf("\n\t\tgrant %s. name %s. %s;",
					$key->{name},
					fullHashName($hashId),
					join(' ', @$dnsTypes));
			}

			push @updatePolicy, $statement;
		}
	}

	# Read a template of BIND zone configuration file.
	#
	my $content  = readRealFilePlain($templateSubDomain);

	my $zoneFilePath = getFilePath($zoneFileId);

	# Produce content.
	#
	$content =~ s/<SUBDOMAIN_NAME>/$cloudName/;
	$content =~ s/<ZONE_FILE>/$zoneFilePath/;
	$content =~ s/<UPDATE_POLICY>/@updatePolicy/;

	# (Re)write BIND zone configuration file.
	#
	saveFilePlain($bindFileId, $content);

	scheduleEvent('BIND_RELOAD_CONFIG', undef, 0);
}

sub bindReloadConfig
{
	refreshTopDomains();
	refreshSubDomains();

	system("rndc reconfig");
}

sub bindReloadZone
{
	my($zoneName) = @_;

	system("rndc reload " . $zoneName);
}

1
