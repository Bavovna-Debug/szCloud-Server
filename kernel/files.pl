use File::Path qw(make_path);

# Privileges.
#
our $ownerUser	= 0;
our $ownerGroup	= 0;

my $filesDatabase = 'DBI:mysql:procurator';
my $filesUsername = 'cloud';
my $filesPassword = 'Nebula15';

#
# Create directory if it does not exist and set proper owner attributes.
#
sub prepareDirectory
{
	my($directory) = @_;

	if (! -e $directory)
	{
		make_path $directory, {
			verbose => 0,
			mode => 0755
		} or die "make_path $directory: $!";

		chown $ownerUser, $ownerGroup, $directory;
	}
}

#
#
#
sub getFilePath
{
	my($fileId) = @_;

	my $localDBH = DBI->connect($filesDatabase, $filesUsername, $filesPassword,
		{ AutoCommit => 1, PrintError => 1 });

	my $sql = qq{
		SELECT CONCAT(directory, '/', file_name)
		FROM procurator.file_repository
			USE INDEX (PRIMARY)
		WHERE file_id = ?
	};
	my $filePath = $localDBH->selectrow_array($sql, undef, $fileId)
		or die $DBI::errstr;

	$localDBH->disconnect();

	return $filePath;
}

#
# Read complete content of a file.
#
sub readFile
{
	my($fileId) = @_;

	return readRealFile(getFilePath($fileId));
}

#
# Read complete content of a file.
#
sub readFilePlain
{
	my($fileId) = @_;

	return readRealFilePlain(getFilePath($fileId));
}

#
# Store content to a file.
#
sub saveFilePlain
{
	my($fileId, $content) = @_;

	saveRealFilePlain(getFilePath($fileId), $content);
}

#
# Create a new entry in a file repository.
# Return file id of new entry.
#
sub createFile
{
	my($directory, $fileName) = @_;

	my $fullPath = sprintf "%s/%s", $directory, $fileName;

	my $localDBH = DBI->connect($filesDatabase, $filesUsername, $filesPassword,
		{ AutoCommit => 1, PrintError => 1 });

	if ( -e $fullPath) {
		my $fileSize = -s $fullPath;

		my $sql = qq{
			INSERT LOW_PRIORITY
			INTO procurator.file_repository
				(directory, file_name, file_size, creation_stamp)
			VALUES (?, ?, ?, NOW())
		};
		$localDBH->do($sql, undef, $directory, $fileName, $fileSize)
			or die $DBI::errstr;
	} else {
		my $sql = qq{
			INSERT LOW_PRIORITY
			INTO procurator.file_repository
				(directory, file_name, creation_stamp)
			VALUES (?, ?, NOW())
		};
		$localDBH->do($sql, undef, $directory, $fileName)
			or die $DBI::errstr;
	}

	my $fileId = $localDBH->selectrow_array("SELECT LAST_INSERT_ID()")
		or die $DBI::errstr;

	$localDBH->disconnect();

	return $fileId;
}

#
# Flag a file in file repository as "not published".
#
sub deleteFile
{
	my($fileId) = @_;

	my $localDBH = DBI->connect($filesDatabase, $filesUsername, $filesPassword,
		{ AutoCommit => 1, PrintError => 1 });

	my $sql = qq{
		UPDATE LOW_PRIORITY procurator.file_repository
		SET published = FALSE
		WHERE file_id = ?
	};
	$localDBH->do($sql, undef, $fileId)
		or die $DBI::errstr;

	$localDBH->disconnect();
}

#
# Remove file from file repository and delete it from file system.
#
sub removeFile
{
	my($fileId) = @_;

	my $fullPath = getFilePath($fileId);

	# Does the file exist on file system?
	#
	if ( -e $fullPath)
	{
		# If yes, then remove it.
		#
		unlink $fullPath
			or die "unlink $full_path: $!";
	}

	my $localDBH = DBI->connect($filesDatabase, $filesUsername, $filesPassword,
		{ AutoCommit => 1, PrintError => 1 });

	my $sql = qq{
		DELETE LOW_PRIORITY
		FROM procurator.file_repository
		WHERE file_id = ?
	};
	$localDBH->do($sql, undef, $fileId)
		or die $DBI::errstr;

	$localDBH->disconnect();
}

#
# Remove from file system all files that are flagged "not published" in a file repository.
# For each removed file delete the corresponding entry from file repository.
#
sub purgeDeletedFiles
{
	my($sql, $sth);

	my $localDBH = DBI->connect($filesDatabase, $filesUsername, $filesPassword,
		{ AutoCommit => 1, PrintError => 1 });

	# Issue SQL query to search for all files flagged as "not published".
	#
	$sql = qq{
		SELECT file_id
		FROM procurator.file_repository
			USE INDEX (idx_published)
		WHERE published IS FALSE
	};
	$sth = $localDBH->prepare($sql)
		or die $DBI::errstr;

	$sth->execute()
		or die $DBI::errstr;

	# Go through a list of files.
	#
	while (my $fileId = $sth->fetchrow_array())
	{
		removeFile($fileId);
	}

	# Release resources.
	#
	$sth->finish();

	$localDBH->disconnect();
}

#
# Search for file repository entries with missing files and flag
# such entries as "not published".
#
sub file_system_check_step1
{
	my($sql, $sth);

	my $localDBH = DBI->connect($filesDatabase, $filesUsername, $filesPassword,
		{ AutoCommit => 0, PrintError => 1 });

	# Flag all files for validation.
	#
	$sql = qq{
		UPDATE procurator.file_repository
			USE INDEX (idx_published)
		SET in_validation = TRUE
		WHERE published IS TRUE
	};
	$localDBH->do($sql)
		or die $DBI::errstr;

	# Issue SQL query to search for all files flagged as "published".
	#
	$sql = qq{
		SELECT file_id, CONCAT(directory, '/', file_name), file_size
		FROM procurator.file_repository
			USE INDEX (idx_in_validation)
		WHERE in_validation IS TRUE
	};
	$sth = $localDBH->prepare($sql)
		or die $DBI::errstr;

	$sth->execute()
		or die $DBI::errstr;

	my $counter_published = 0;
	my $counter_file_size = 0;

	# Go through a list of files.
	#
	while (my($file_id, $full_path, $file_size) = $sth->fetchrow_array())
	{
		# Does the file exist on file system?
		#
		if ( ! -e $full_path)
		{
			# If not, then flag this file as "not published".
			#
			$sql = qq{
				UPDATE procurator.file_repository
					USE INDEX (PRIMARY)
				SET published = FALSE
				WHERE file_id = ?
			};
			$localDBH->do($sql, undef, $file_id)
				or die $DBI::errstr;

			$counter_published++;
		}
		else
		{
			my $actual_file_size = -s $full_path;

			# Did the size of the file changed since last check?
			#
			if ($actual_file_size != $file_size)
			{
				# If yes, then update the file information.
				#
				$sql = qq{
					UPDATE procurator.file_repository
						USE INDEX (PRIMARY)
					SET file_size = ?
					WHERE file_id = ?
				};
				$localDBH->do($sql, undef, $actual_file_size, $file_id)
					or die $DBI::errstr;
			}

			$counter_file_size++;
		}

		# Flag all files for validation.
		#
		$sql = qq{
			UPDATE procurator.file_repository
				USE INDEX (PRIMARY)
			SET in_validation = FALSE
			WHERE file_id = ?
		};
		$localDBH->do($sql, undef, $file_id)
			or die $DBI::errstr;

		# Commit transaction.
		#
		$localDBH->commit()
			or die $DBI::errstr;
	}

	# Release resources.
	#
	$sth->finish();

	$localDBH->disconnect();

	printf "published: %d\nfile_size: %d\n", $counter_published, $counter_file_size;
}

#
# Read complete content of a file.
#
sub readRealFile
{
	my($filePath) = @_;

	open DATAFILE, $filePath
		or die "open $filePath: $!";

	my @content;
	push @content, $_ while (<DATAFILE>);

	close DATAFILE
		or die "close $filePath: $!";

	return @content;
}

#
# Read complete content of a file.
#
sub readRealFilePlain
{
	my($filePath) = @_;

	open DATAFILE, $filePath
		or die "open $filePath: $!";

	my $content = '';
	while (<DATAFILE>) { $content .= $_; }

	close DATAFILE
		or die "close $filePath: $!";

	return $content;
}

#
# Store content to a file.
#
sub saveRealFilePlain
{
	my($filePath, $content) = @_;

	open DATAFILE, ">" . $filePath
		or die "open $filePath: $!";

	print DATAFILE $content
		or die "write $filePath: $!";

	close DATAFILE
		or die "close $filePath: $!";

	chown $ownerUser, $ownerGroup, $filePath;
}

1
