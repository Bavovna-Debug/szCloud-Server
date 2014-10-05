sub updateDomainFile
{
	my($domainId) = @_;

	my($sql, $sth);

	# Go through domains which need to be updated.
	#
	$sql = qq{
		SELECT domain_file_id, soa_id, name
		FROM cloud_bender.domains
			USE INDEX (idx_hash_id)
		JOIN cloud_bender.hash_repository
			USE INDEX (PRIMARY)
			USING (hash_id)
		WHERE hash_id = ?
	};
	my @row = $dbh->selectrow_array($sql, undef, $domainId)
		or die DBI::errstr;

	my $domainFileId = shift @row;
	my $soaId = shift @row;
	my $domainName = shift @row;

	# Prepare zone header.
	#
	my $content = zoneFileContent($domainId, $soaId);

	# Go through domains which need to be updated.
	#
	$sql = qq{
		SELECT hash_id, name
		FROM cloud_bender.hash_repository
			USE INDEX (idx_parent_id)
		WHERE parent_id = ?
	};
	$sth = $dbh->prepare($sql)
		or die DBI::errstr;

	$sth->execute($domainId)
		or die DBI::errstr;

	while (my @row = $sth->fetchrow_array())
	{
		my $cloudId = shift @row;
		my $cloudName = shift @row;

		$content .= sprintf "%s %d\tIN\tNS\t%s.\n",
			$cloudName, $defaultTTL, $defaultNameServer;
	}

	$sth->finish();

	# Save it to file.
	#
	saveFilePlain($domainFileId, $content);

	# Signal that BIND has to be restarted.
	#
	scheduleEvent('BIND_RELOAD_ZONE', $domainName, 0);
}

sub zoneFileContent
{
	my($hashId, $soaId) = @_;

	# Fetch SOA record.
	#
	$sql = qq{
		SELECT root, include_file_id,
			email, soa_refresh, soa_retry, soa_expire, soa_ttl
		FROM cloud_bender.soas
			USE INDEX (PRIMARY)
		WHERE soa_id = ?
	};
	my @row = $dbh->selectrow_array($sql, undef, $soaId)
		or die DBI::errstr;

	my $root = shift @row;
	my $includeFileId = shift @row;
	my $email = shift @row;
	my $soaRefresh = shift @row;
	my $soaRetry = shift @row;
	my $soaExpire = shift @row;
	my $soaTTL = shift @row;

	my $originTTL = $defaultTTL;
	my $serial = getSOASerial($soaId);

	$email =~ s/@/\./;

	my $extension;
	if (defined $includeFileId) {
		$extension = '';
	} else {
		if ($root) {
			$extension = $includeTopDomain;
		} else {
			$extension = $includeSubDomain;
		}
	}

	# Read a template of DNS zone file.
	#
	my $content = readRealFilePlain($templateZone);

	# Produce content of DNS zone file.
	#
	$content =~ s/<TTL>/$originTTL/;
	$content =~ s/<ROOT_SERVER>/$defaultNameServer/;
	$content =~ s/<ADMIN>/$email/;
	$content =~ s/<SERIAL>/$serial/;
	$content =~ s/<SOA_REFRESH>/$soaRefresh/;
	$content =~ s/<SOA_RETRY>/$soaRetry/;
	$content =~ s/<SOA_EXPIRE>/$soaExpire/;
	$content =~ s/<SOA_TTL>/$soaTTL/;
	$content =~ s/<PATH>/$bindDirectory/;
	$content =~ s/<INCLUDE>/$extension/;

	return $content;
}

1
