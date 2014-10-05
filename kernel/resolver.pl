#!/usr/bin/perl

require 'configuration.pl';
require 'procurator.pl';
require 'files.pl';

use Switch;
use DBI;
use Net::DNS;

# MySQL authorisation data.
#
use constant dbDatabase	=> 'DBI:mysql:cloud_bender';
use constant dbUsername	=> 'cloud';
use constant dbPassword	=> 'Nebula15';

exitIfAlreadyRunning('resolver');

$originator = 'RESOLVER';

# Since now activate our own die()-handler.
#
$SIG{__DIE__}  = 'signalDieHandler';

$SIG{HUP} = "signalKillHandler";

logInfo("Start RESOLVER");

while (1) { goThroughClouds(); sleep(20); }

#
# Common routine to be called in case of error.
#
sub signalDieHandler
{
	my($message) = @_;
	logError($message);
	exit;
}

#
# Common routine to be called in case program becomes a signal.
#
sub signalKillHandler
{
	goThroughClouds();
}

my $lock: shared;

sub goThroughClouds
{
	lock $lock;

	# Establish connection to MySQL and select a database.
	#
	my $dbh = DBI->connect_cached(dbDatabase, dbUsername, dbPassword,
		{ AutoCommit => 1, PrintError => 1 });

	die "DBI-connect: $DBI::errstr"
		if (defined $DBI::err) and ($DBI::err != 0);

	my($sql, $sthOuter, $sthInner);

	$sql = qq{
		SELECT hash_id
		FROM cloud_bender.clouds
			USE INDEX (idx_need_dns_revalidation)
		WHERE need_dns_revalidation IS TRUE
	};
	$sthOuter = $dbh->prepare($sql)
		or die $DBI::errstr;

	$sthOuter->execute()
		or die $DBI::errstr;

	while (my $cloudId = $sthOuter->fetchrow_array())
	{
		$sql = qq{
			SELECT full_name
			FROM cloud_bender.hash_repository
			WHERE hash_id = ?
		};
		my $zoneName = $dbh->selectrow_array($sql, undef, $cloudId)
			or die $DBI::errstr;

		$sql = qq{
			SELECT full_name AS hashName, entry_id AS entryId, ttl AS ttl, ip_address AS ipAddress
			FROM cloud_bender.dns_journal_a AS journal
				USE INDEX (idx_hash_id_active)
			JOIN cloud_bender.hash_repository
				USE INDEX (PRIMARY)
				USING (hash_id)
			WHERE hash_id IN (
				SELECT hash_id
				FROM cloud_bender.hash_repository
				WHERE hash_id = ? OR parent_id = ?
			) AND active IS TRUE
		};
		my $listA = $dbh->selectall_hashref($sql, 'entryId', undef, $cloudId, $cloudId)
			or die $DBI::errstr;

		$sql = qq{
			SELECT full_name AS hashName, entry_id AS entryId, ttl AS ttl, ip_address AS ipAddress
			FROM cloud_bender.dns_journal_aaaa AS journal
				USE INDEX (idx_hash_id_active)
			JOIN cloud_bender.hash_repository
				USE INDEX (PRIMARY)
				USING (hash_id)
			WHERE hash_id IN (
				SELECT hash_id
				FROM cloud_bender.hash_repository
				WHERE hash_id = ? OR parent_id = ?
			) AND active IS TRUE
		};
		my $listAAAA = $dbh->selectall_hashref($sql, 'entryId', undef, $cloudId, $cloudId)
			or die $DBI::errstr;

		$sql = qq{
			SELECT full_name AS hashName, entry_id AS entryId, ttl AS ttl, canonical
			FROM cloud_bender.dns_journal_cname AS journal
				USE INDEX (idx_hash_id_active)
			JOIN cloud_bender.hash_repository
				USE INDEX (PRIMARY)
				USING (hash_id)
			WHERE hash_id IN (
				SELECT hash_id
				FROM cloud_bender.hash_repository
				WHERE hash_id = ? OR parent_id = ?
			) AND active IS TRUE
		};
		my $listCNAME = $dbh->selectall_hashref($sql, 'entryId', undef, $cloudId, $cloudId)
			or die $DBI::errstr;

		$sql = qq{
			SELECT full_name AS hashName, entry_id AS entryId, ttl AS ttl, preference, exchange
			FROM cloud_bender.dns_journal_mx AS journal
				USE INDEX (idx_hash_id_active)
			JOIN cloud_bender.hash_repository
				USE INDEX (PRIMARY)
				USING (hash_id)
			WHERE hash_id IN (
				SELECT hash_id
				FROM cloud_bender.hash_repository
				WHERE hash_id = ? OR parent_id = ?
			) AND active IS TRUE
		};
		my $listMX = $dbh->selectall_hashref($sql, 'entryId', undef, $cloudId, $cloudId)
			or die $DBI::errstr;

		$sql = qq{
			SELECT full_name AS hashName, entry_id AS entryId, ttl AS ttl, nameserver
			FROM cloud_bender.dns_journal_ns AS journal
				USE INDEX (idx_hash_id_active)
			JOIN cloud_bender.hash_repository
				USE INDEX (PRIMARY)
				USING (hash_id)
			WHERE hash_id IN (
				SELECT hash_id
				FROM cloud_bender.hash_repository
				WHERE hash_id = ? OR parent_id = ?
			) AND active IS TRUE
		};
		my $listNS = $dbh->selectall_hashref($sql, 'entryId', undef, $cloudId, $cloudId)
			or die $DBI::errstr;

		$sql = qq{
			SELECT full_name AS hashName, entry_id AS entryId, ttl AS ttl, txt_data AS txtData
			FROM cloud_bender.dns_journal_txt AS journal
				USE INDEX (idx_hash_id_active)
			JOIN cloud_bender.hash_repository
				USE INDEX (PRIMARY)
				USING (hash_id)
			WHERE hash_id IN (
				SELECT hash_id
				FROM cloud_bender.hash_repository
				WHERE hash_id = ? OR parent_id = ?
			) AND active IS TRUE
		};
		my $listTXT = $dbh->selectall_hashref($sql, 'entryId', undef, $cloudId, $cloudId)
			or die $DBI::errstr;

		my $resolver = new Net::DNS::Resolver;
		$resolver->nameservers($nameServerIPAddress);
		$resolver->axfr_start($zoneName);
		while (my $rr = $resolver->axfr_next)
		{
			$sql = qq{
				SELECT hash_id
				FROM cloud_bender.hash_repository
				WHERE full_name LIKE ?
			};
			my $hashId = $dbh->selectrow_array($sql, undef, $rr->name)
				or die $DBI::errstr;

			switch ($rr->type)
			{
				case 'A'
				{
					my $found = undef;
					foreach my $entryId (keys %$listA)
					{
						next unless ($listA->{$entryId}{hashName} cmp $rr->name) == 0;
						next unless ($listA->{$entryId}{ttl} cmp $rr->ttl) == 0;
						next unless ($listA->{$entryId}{ipAddress} cmp $rr->address) == 0;

						delete $listA->{$entryId};
						$found = defined;
						last;
					}

					if (!defined $found) {
						$sql = qq{
							INSERT LOW_PRIORITY
							INTO cloud_bender.dns_journal_a
								(hash_id, ttl, ip_address)
							VALUES (?, ?, ?)
						};
						$dbh->do($sql, undef, $hashId, $rr->ttl, $rr->address)
							or die $DBI::errstr;
					}
				}

				case 'AAAA'
				{
					my $found = undef;
					foreach my $entryId (keys %$listAAAA)
					{
						next unless ($listAAAA->{$entryId}{hashName} cmp $rr->name) == 0;
						next unless ($listAAAA->{$entryId}{ttl} cmp $rr->ttl) == 0;
						next unless ($listAAAA->{$entryId}{ipAddress} cmp $rr->address) == 0;

						delete $listAAAA->{$entryId};
						$found = defined;
						last;
					}

					if (!defined $found) {
						$sql = qq{
							INSERT LOW_PRIORITY
							INTO cloud_bender.dns_journal_aaaa
								(hash_id, ttl, ip_address)
							VALUES (?, ?, ?)
						};
						$dbh->do($sql, undef, $hashId, $rr->ttl, $rr->address)
							or die $DBI::errstr;
					}
				}

				case 'CNAME'
				{
					my $found = undef;
					foreach my $entryId (keys %$listCNAME)
					{
						next unless ($listCNAME->{$entryId}{hashName} cmp $rr->name) == 0;
						next unless ($listCNAME->{$entryId}{ttl} cmp $rr->ttl) == 0;
						next unless ($listCNAME->{$entryId}{canonical} cmp $rr->cname) == 0;

						delete $listCNAME->{$entryId};
						$found = defined;
						last;
					}

					if (!defined $found) {
						$sql = qq{
							INSERT LOW_PRIORITY
							INTO cloud_bender.dns_journal_cname
								(hash_id, ttl, canonical)
							VALUES (?, ?, ?)
						};
						$dbh->do($sql, undef, $hashId, $rr->ttl, $rr->cname)
							or die $DBI::errstr;
					}
				}

				case 'MX'
				{
					my $found = undef;
					foreach my $entryId (keys %$listMX)
					{
						next unless ($listMX->{$entryId}{hashName} cmp $rr->name) == 0;
						next unless ($listMX->{$entryId}{ttl} cmp $rr->ttl) == 0;
						next unless ($listMX->{$entryId}{preference} cmp $rr->preference) == 0;
						next unless ($listMX->{$entryId}{exchange} cmp $rr->exchange) == 0;

						delete $listMX->{$entryId};
						$found = defined;
						last;
					}

					if (!defined $found) {
						$sql = qq{
							INSERT LOW_PRIORITY
							INTO cloud_bender.dns_journal_mx
								(hash_id, ttl, preference, exchange)
							VALUES (?, ?, ?, ?)
						};
						$dbh->do($sql, undef, $hashId, $rr->ttl, $rr->preference, $rr->exchange)
							or die $DBI::errstr;
					}
				}

				case 'NS'
				{
					my $found = undef;
					foreach my $entryId (keys %$listNS)
					{
						next unless ($listNS->{$entryId}{hashName} cmp $rr->name) == 0;
						next unless ($listNS->{$entryId}{ttl} cmp $rr->ttl) == 0;
						next unless ($listNS->{$entryId}{nameserver} cmp $rr->nsdname) == 0;

						delete $listNS->{$entryId};
						$found = defined;
						last;
					}

					if (!defined $found) {
						$sql = qq{
							INSERT LOW_PRIORITY
							INTO cloud_bender.dns_journal_ns
								(hash_id, ttl, nameserver)
							VALUES (?, ?, ?)
						};
						$dbh->do($sql, undef, $hashId, $rr->ttl, $rr->nsdname)
							or die $DBI::errstr;
					}
				}

				case 'TXT'
				{
					my $found = undef;
					foreach my $entryId (keys %$listTXT)
					{
						next unless ($listTXT->{$entryId}{hashName} cmp $rr->name) == 0;
						next unless ($listTXT->{$entryId}{ttl} cmp $rr->ttl) == 0;
						next unless ($listTXT->{$entryId}{txtData} cmp $rr->txtdata) == 0;

						delete $listTXT->{$entryId};
						$found = defined;
						last;
					}

					if (!defined $found) {
						$sql = qq{
							INSERT LOW_PRIORITY
							INTO cloud_bender.dns_journal_txt
								(hash_id, ttl, txt_data)
							VALUES (?, ?, ?)
						};
						$dbh->do($sql, undef, $hashId, $rr->ttl, $rr->txtdata)
							or die $DBI::errstr;
					}
				}
			}
		}

		foreach my $entryId (keys %$listA)
		{
			$sql = qq{
				UPDATE LOW_PRIORITY cloud_bender.dns_journal_a
					USE INDEX (PRIMARY)
				SET active = FALSE
				WHERE entry_id = ?
			};
			$dbh->do($sql, undef, $entryId)
				or die $DBI::errstr;
		}

		foreach my $entryId (keys %$listAAAA)
		{
			$sql = qq{
				UPDATE LOW_PRIORITY cloud_bender.dns_journal_aaaa
					USE INDEX (PRIMARY)
				SET active = FALSE
				WHERE entry_id = ?
			};
			$dbh->do($sql, undef, $entryId)
				or die $DBI::errstr;
		}

		foreach my $entryId (keys %$listCNAME)
		{
			$sql = qq{
				UPDATE LOW_PRIORITY cloud_bender.dns_journal_cname
					USE INDEX (PRIMARY)
				SET active = FALSE
				WHERE entry_id = ?
			};
			$dbh->do($sql, undef, $entryId)
				or die $DBI::errstr;
		}

		foreach my $entryId (keys %$listMX)
		{
			$sql = qq{
				UPDATE LOW_PRIORITY cloud_bender.dns_journal_mx
					USE INDEX (PRIMARY)
				SET active = FALSE
				WHERE entry_id = ?
			};
			$dbh->do($sql, undef, $entryId)
				or die $DBI::errstr;
		}

		foreach my $entryId (keys %$listNS)
		{
			$sql = qq{
				UPDATE LOW_PRIORITY cloud_bender.dns_journal_ns
					USE INDEX (PRIMARY)
				SET active = FALSE
				WHERE entry_id = ?
			};
			$dbh->do($sql, undef, $entryId)
				or die $DBI::errstr;
		}

		foreach my $entryId (keys %$listTXT)
		{
			$sql = qq{
				UPDATE LOW_PRIORITY cloud_bender.dns_journal_txt
					USE INDEX (PRIMARY)
				SET active = FALSE
				WHERE entry_id = ?
			};
			$dbh->do($sql, undef, $entryId)
				or die $DBI::errstr;
		}

		$sql = qq{
			UPDATE LOW_PRIORITY cloud_bender.clouds
				USE INDEX (idx_hash_id)
			SET need_dns_revalidation = FALSE
			WHERE hash_id = ?
		};
		$dbh->do($sql, undef, $cloudId)
			or die $DBI::errstr;
	}

	# Leave MySQL connection.
	#
	$dbh->disconnect();

	return;
}
