sub processFirstIP
{
	my($sql, $sth);

	$sql = qq{
		SELECT hash_id
		FROM cloud_bender.hosts
			USE INDEX (idx_first_ip_set)
		WHERE first_ip_set IS FALSE
	};
	$sth = $dbh->prepare($sql)
		or die $DBI::errstr;

	$sth->execute()
		or die $DBI::errstr;

	while (my($hashId) = $sth->fetchrow_array())
	{
		bindDNSValue($hashId, 'A', $firstIPAddress);

		$sql = qq{
			UPDATE cloud_bender.hosts
				USE INDEX (idx_hash_id)
			SET first_ip_set = TRUE
			WHERE hash_id = ?
		};
		$dbh->do($sql, undef, $hashId)
			or die $DBI::errstr;
	}
}

sub prepareDNS
{
	my($sql, $sth);

	$sql = qq{
		SELECT hash_id
		FROM cloud_bender.dns_journal
		WHERE add_processed IS FALSE
			AND (dns_type = 'A' OR dns_type = 'AAAA')
	};
	$sth = $dbh->prepare($sql)
		or die $DBI::errstr;

	$sth->execute()
		or die $DBI::errstr;

	while (my($hashId) = $sth->fetchrow_array())
	{
		$sql = qq{
			UPDATE cloud_bender.dns_journal
			SET del_requested = TRUE
			WHERE hash_id = ?
				AND del_requested IS FALSE
				AND dns_type = 'CNAME'
		};
		$dbh->do($sql, undef, $hashId)
			or die $DBI::errstr;
	}

	$sth->finish();

	$sql = qq{
		SELECT hash_id
		FROM cloud_bender.dns_journal
		WHERE add_processed IS FALSE
			AND dns_type = 'CNAME'
	};
	$sth = $dbh->prepare($sql)
		or die $DBI::errstr;

	$sth->execute()
		or die $DBI::errstr;

	while (my($hashId) = $sth->fetchrow_array())
	{
		$sql = qq{
			UPDATE cloud_bender.dns_journal
			SET del_requested = TRUE
			WHERE hash_id = ?
				AND del_requested IS FALSE
				AND (dns_type = 'A' OR dns_type = 'AAAA')
		};
		$dbh->do($sql, undef, $hashId)
			or die $DBI::errstr;
	}

	$sth->finish();
}
	
sub processExpiredDNS
{
	my $sql = qq{
		UPDATE cloud_bender.dns_journal
			USE INDEX (idx_expiration)
		SET del_requested = TRUE
		WHERE add_processed IS TRUE
		  AND del_processed IS FALSE
		  AND dns_till IS NOT NULL
		  AND dns_till < CURRENT_TIMESTAMP
	};
	$dbh->do($sql, undef)
		or die $DBI::errstr;
}

sub processDeletedDNS
{
	my($sql, $sth);

	$sql = qq{
		SELECT event_id, hash_id, dns_type
		FROM cloud_bender.dns_journal
			USE INDEX (idx_del)
			USE INDEX FOR ORDER BY (PRIMARY)
		WHERE del_requested IS TRUE
		  AND del_processed IS FALSE
		ORDER BY event_id
	};
	$sth = $dbh->prepare($sql)
		or die $DBI::errstr;

	$sth->execute()
		or die $DBI::errstr;

	while (my($eventId, $hashId, $dnsType) = $sth->fetchrow_array())
	{
		bindDNSValue($hashId, $dnsType, undef);

		$sql = qq{
			UPDATE cloud_bender.dns_journal
				USE INDEX (PRIMARY)
			SET del_processed = TRUE
			WHERE event_id = ?
		};
		$dbh->do($sql, undef, $eventId)
			or die $DBI::errstr;
	}

	$sth->finish();
}

sub processNewDNS
{
	my($sql, $sth);

	$sql = qq{
		SELECT event_id, hash_id, dns_type, dns_value
		FROM cloud_bender.dns_journal
			USE INDEX (idx_add)
		WHERE add_processed IS FALSE
		ORDER BY event_id
	};
	$sth = $dbh->prepare($sql)
		or die $DBI::errstr;

	$sth->execute()
		or die $DBI::errstr;

	while (my($eventId, $hashId, $dnsType, $dnsValue) = $sth->fetchrow_array())
	{
		bindDNSValue($hashId, $dnsType, $dnsValue);

		$sql = qq{
			UPDATE cloud_bender.dns_journal
				USE INDEX (PRIMARY)
			SET add_processed = TRUE
			WHERE event_id = ?
		};
		$dbh->do($sql, undef, $eventId)
			or die $DBI::errstr;
	}

	$sth->finish();
}

sub bindDNSValue
{
	my($hashId, $dnsType, $dnsValue) = @_;

	my($sql, $sth);

	# Get TTL value for this host.
	#
	$sql = qq{
		SELECT parent_id, ttl
		FROM cloud_bender.hash_repository
			USE INDEX (PRIMARY)
		WHERE hash_id = ?
	};
	my($cloudId, $ttl) = $dbh->selectrow_array($sql, undef, $hashId)
		or die $DBI::errstr;

	# Get DNS-Sec key.
	#
	$sql = qq{
		SELECT LOWER(key_algorithm), key_secret
		FROM cloud_bender.dnssec_keys
			USE INDEX (PRIMARY)
		JOIN cloud_bender.dnssec_key_xref
			USE INDEX (PRIMARY)
			USING (dnssec_key_id)
		WHERE hash_id = ?
	};
	my($algorithm, $secret) = $dbh->selectrow_array($sql, undef, $hashId)
		or die $DBI::errstr;

	my $zoneName = fullHashName($cloudId);
	my $hostName = fullHashName($hashId);

	# Prepare nsupdate input file with a sequence of commands.
	#
	my $nsupdate = '';
	$nsupdate .= sprintf "server %s\n", $nameServerIPAddress;
	$nsupdate .= sprintf "zone %s\n", $zoneName;

	if (!defined($dnsValue)) {
		$nsupdate .= sprintf "update delete %s %s\n",
			$hostName, $dnsType;
	} else {
		if (($dnsType cmp 'CNAME') == 0) {
			$nsupdate .= sprintf "update delete %s A\n",
				$hostName;
			$nsupdate .= sprintf "update delete %s AAAA\n",
				$hostName;
		} else {
			$nsupdate .= sprintf "update delete %s CNAME\n",
				$hostName;
		}
		$nsupdate .= sprintf "update delete %s %s\n",
			$hostName, $dnsType;
		$nsupdate .= sprintf "update add %s %d %s %s\n",
			$hostName, $ttl, $dnsType, $dnsValue;
	}

	$nsupdate .= "send\n";
	$nsupdate .= "quit\n";

	# Store sequence of commands.
	#
	saveRealFilePlain(sprintf("%s/%s", $workFilesPath, $hostName), $nsupdate);

	# Issue nsupdate command.
	#
	my $command = sprintf "nsupdate -v -d -y %s:%s:%s %s/%s",
		$algorithm, $hostName, $secret, $workFilesPath, $hostName;

	system($command);

	# Get id of SOA record of this host's cloud.
	#
	$sql = qq{
		SELECT soa_id
		FROM cloud_bender.clouds
			USE INDEX (idx_hash_id)
		WHERE hash_id = ?
	};
	my($soaId) = $dbh->selectrow_array($sql, undef, $cloudId)
		or die $DBI::errstr;

	# Increment serial number of the cloud's SOA.
	#
	getSOASerial($soaId);
}

1
