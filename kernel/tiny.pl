#
# Create user's directory if it does not exist.
#
sub userUserDirectory
{
	my($userId) = @_;

	my $directory = sprintf("%s/U%09d", $bindDirectory, $userId);
	prepareDirectory($directory);
	prepareDirectory($directory . '/keys');
	return $directory;
}

#
#
#
sub hashOwner
{
	my($hashId) = @_;

	my $sql = qq{
		SELECT user_id
		FROM cloud_bender.hash_repository
		WHERE hash_id = ?
	};
	my $userId = $dbh->selectrow_array($sql, undef, $hashId)
		or die DBI::errstr;

	return $userId;
}

#
#
#
sub fullHashName
{
	my($hashId) = @_;

	my $sql = qq{
		SELECT full_name
		FROM cloud_bender.hash_repository
		WHERE hash_id = ?
	};
	my $fullName = $dbh->selectrow_array($sql, undef, $hashId)
		or die DBI::errstr;

	return $fullName;
}

#
# Produce serial number for SOA record.
#
sub getSOASerial
{
	my($soaId) = @_;

	my($sql, $sth);

	my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
		localtime(time);
	my $todayStamp = sprintf "%4d%02d%02d", 1900 + $year, $mon + 1, $mday;

	return $todayStamp . '00'
		if $soaId == 0;

	$sql = qq{
		SELECT last_serial
		FROM cloud_bender.soas
			USE INDEX (PRIMARY)
		WHERE soa_id = ?
	};
	my $lastSerial = $dbh->selectrow_array($sql, undef, $soaId)
		or die DBI::errstr;

	my $stamp = substr $lastSerial, 0, 8;
	my $seqno = substr $lastSerial, 8, 2;

	if ($seqno < 99) {
		$seqno++;
		$stamp = $todayStamp;
	} else {
		$seqno = 0;
		if ($stamp >= $todayStamp) {
			$stamp++;
		} else {
			$stamp = $todayStamp;
		}
	}

	$serial = sprintf "%s%02d", $stamp, $seqno;

	$sql = qq{
		UPDATE cloud_bender.soas
			USE INDEX (PRIMARY)
		SET last_serial = ?
		WHERE soa_id = ?
	};
	$dbh->do($sql, undef, $serial, $soaId)
		or die DBI::errstr;

	return $serial;
}

#
# Get user's E-mail address.
#
sub getUserEmail
{
	my($userId) = @_;

	my $sql = qq{
		SELECT email
		FROM cloud_bender.customers
		WHERE user_id = ?
	};
	my $email = $dbh->selectrow_array($sql, undef, $userId)
		or die DBI::errstr;

	return $email;
}

1
