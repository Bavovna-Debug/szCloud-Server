DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  List of hash codes for all types of objects and their activation status.  */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.hash_repository (
	stamp			TIMESTAMP					NOT NULL DEFAULT CURRENT_TIMESTAMP,
	hash_id			INTEGER UNSIGNED			NOT NULL AUTO_INCREMENT,
	user_id			INTEGER UNSIGNED			NULL DEFAULT NULL,
	object_type		ENUM('DOM', 'CLD', 'HST')	NOT NULL,
	parent_id		INTEGER UNSIGNED			NULL DEFAULT NULL,
	logo_id			INTEGER UNSIGNED			NOT NULL,
	hash_code		CHAR(16)					NOT NULL,
	secret			CHAR(16)					NOT NULL,
	secret_stamp	TIMESTAMP					NULL DEFAULT NULL,
	password		CHAR(32)					NULL DEFAULT NULL,
	password_stamp	TIMESTAMP					NULL DEFAULT NULL,
	name			VARCHAR(64)				NOT NULL,
	full_name		VARCHAR(255)				NOT NULL,

	PRIMARY KEY (hash_id),
	KEY idx_parent_id (parent_id),
	KEY idx_user_id (user_id),
	KEY idx_user_id_object_type (user_id, object_type),
	KEY idx_object_type (object_type),
	UNIQUE KEY idx_hash_code (hash_code),
	UNIQUE KEY idx_full_name (full_name),
	UNIQUE KEY idx_secret (secret)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.hash_repository_insert;
CREATE TRIGGER cloud_bender.hash_repository_insert
BEFORE INSERT ON cloud_bender.hash_repository
FOR EACH ROW BEGIN
	DECLARE $parent_full_name	VARCHAR(255);
	DECLARE $logo_id			INTEGER UNSIGNED;
	DECLARE $found				BOOLEAN DEFAULT TRUE;

	DECLARE CONTINUE HANDLER
	FOR NOT FOUND
	SET $found = FALSE;

	SELECT full_name
	FROM cloud_bender.hash_repository
	WHERE hash_id = NEW.parent_id
	INTO $parent_full_name;

	SET NEW.full_name = CONCAT(NEW.name, '.', $parent_full_name);

	SELECT logo_id
	FROM cloud_bender.logos
	WHERE recommended IS TRUE
	ORDER BY RAND()
	LIMIT 0, 1
	INTO $logo_id;

	SET NEW.logo_id = $logo_id;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.hash_repository_update;
CREATE TRIGGER cloud_bender.hash_repository_update
BEFORE UPDATE ON cloud_bender.hash_repository
FOR EACH ROW BEGIN
	/*
	 * Update time stamp on secret change.
	 */
	IF OLD.secret != NEW.secret THEN
		SET NEW.secret_stamp = CURRENT_TIMESTAMP;
	END IF;

	/*
	 * If password has changed then set a passowrd change time stamp.
	 */
	IF (OLD.password != NEW.password) OR
	  ((OLD.password IS NOT NULL) AND (NEW.password IS NULL)) OR
	  ((OLD.password IS NULL) AND (NEW.password IS NOT NULL)) THEN
		SET NEW.password_stamp = CURRENT_TIMESTAMP;
	END IF;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP FUNCTION IF EXISTS cloud_bender.create_hash;
CREATE FUNCTION cloud_bender.create_hash (
	$user_id			INTEGER UNSIGNED,
	$parent_id			INTEGER UNSIGNED,
	$object_type		CHAR(3),
	$object_name		VARCHAR(64) CHARACTER SET utf8)

	RETURNS			INTEGER UNSIGNED

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $user_name	VARCHAR(150) CHARACTER SET utf8;
	DECLARE $hash		VARCHAR(256) CHARACTER SET utf8;
	DECLARE $hash_code	CHAR(16);
	DECLARE $secret	CHAR(16);
	DECLARE $retries	SMALLINT DEFAULT 100;
	DECLARE $succeeded	BOOLEAN;

	/*
	 * Prepare handler for the case of duplicate index.
	 */
	DECLARE CONTINUE HANDLER
	FOR SQLSTATE VALUE '23000'
	SET $succeeded = FALSE;

	/*
	 * If user is specified...
	 */
	IF $user_id != 0 THEN
		/*
		 * ...then search for his login name.
		 */
		SELECT username
		FROM cloud_bender.customers
		WHERE user_id = $user_id
		INTO $user_name;
	ELSE
		/*
		 * ...otherwise take 'system' instead of login name.
		 */
		SET $user_name = 'system';
	END IF;

	/*
	 * If neccessary, repeat hash code and secret generation several times
	 * until unique values are generated.
	 */
	if_duplicate_index: REPEAT
		SET $hash = CONCAT(UNIX_TIMESTAMP(), '-', $retries);
		SET $hash = CONCAT($hash, '-', $user_name, '-', $object_type, '-', $object_name);
		SET $hash = MD5($hash);
		SET $hash = UPPER($hash);
		SET $hash_code = SUBSTRING($hash, 1, 16);
		SET $secret = SUBSTRING($hash, 17, 16);

		/*
		 * Try to insert a new entry.
		 */
		SET $succeeded = TRUE;
		INSERT LOW_PRIORITY
		INTO cloud_bender.hash_repository
			(user_id, parent_id, object_type, hash_code, secret, name)
		VALUES ($user_id, $parent_id, $object_type, $hash_code, $secret, $object_name);

		/*
		 * Check result after insertion.
		 */
		IF $succeeded = TRUE THEN
			/*
			 * If a new entry inserted successfully then its id
			 * must be a return value.
			 */
			RETURN LAST_INSERT_ID();
		ELSE
			/*
			 * If not then prepare for next try.
			 */
			SET $retries = $retries - 1;
		END IF;
	UNTIL $retries = 0
	END REPEAT if_duplicate_index;

	RETURN 0;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS cloud_bender.generate_new_secret;
CREATE PROCEDURE cloud_bender.generate_new_secret (
	IN $hash_id			INTEGER UNSIGNED)

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $hash		VARCHAR(256) CHARACTER SET utf8;
	DECLARE $secret	CHAR(16);
	DECLARE $retries	SMALLINT DEFAULT 100;
	DECLARE $succeeded	BOOLEAN;

	/*
	 * Prepare handler for the case of duplicate index.
	 */
	DECLARE CONTINUE HANDLER
	FOR SQLSTATE VALUE '23000'
	SET $succeeded = FALSE;

	/*
	 * If neccessary, repeat secret generation several times
	 * until unique secret is generated.
	 */
	if_duplicate_index: REPEAT
		SET $hash = CONCAT($hash_id, '-', UNIX_TIMESTAMP(), '-', $retries);
		SET $hash = MD5($hash);
		SET $hash = UPPER($hash);
		SET $secret = SUBSTRING($hash, 9, 16);

		/*
		 * Try to set new secret.
		 */
		SET $succeeded = TRUE;
		UPDATE LOW_PRIORITY cloud_bender.hash_repository
			USE INDEX (PRIMARY)
		SET secret = $secret
		WHERE hash_id = $hash_id;

		/*
		 * Check result after update.
		 */
		IF $succeeded = TRUE THEN
			/*
			 * Secret updated successfully.
			 */
			SET $retries = 0;
		ELSE
			/*
			 * If not then prepare for next try.
			 */
			SET $retries = $retries - 1;
		END IF;
	UNTIL $retries = 0
	END REPEAT if_duplicate_index;
END;


/******************************************************************************/
/*                                                                            */
/*  Set or reset password for specified object.                               */
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS cloud_bender.set_password;
CREATE PROCEDURE cloud_bender.set_password (
	$hash_id			INTEGER UNSIGNED,
	$password			VARCHAR(100) CHARACTER SET utf8)

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $user_id	INTEGER UNSIGNED;
	DECLARE $hash		CHAR(32);
	DECLARE $salt		CHAR(32);

	IF $password IS NOT NULL THEN
		/*
		 * Find out user id.
		 */
		SELECT user_id
		FROM cloud_bender.hash_repository
			USE INDEX (PRIMARY)
		WHERE hash_id = $hash_id
		INTO $user_id;

		/*
		 * Fetch salt value of user's password.
		 */
		SELECT SUBSTRING(password, 34, 32)
		FROM cloud_bender.customers
		WHERE user_id = $user_id
		INTO $salt;

		/*
		 * Clear text password is provided. We must encrypt it.
		 */
		SET $hash = MD5(CONCAT($password, $salt));

		/*
		 * Store encrypted password.
		 */
		UPDATE cloud_bender.hash_repository
			USE INDEX (PRIMARY)
		SET password = $hash
		WHERE hash_id = $hash_id;
	ELSE
		/*
		 * Reset password.
		 */
		UPDATE cloud_bender.hash_repository
			USE INDEX (PRIMARY)
		SET password = NULL
		WHERE hash_id = $hash_id;
	END IF;
END;


/******************************************************************************/
/*                                                                            */
/*  Check password for specified user and hash. If hash does not have         */
/*  its own password then check the one of his parent.                        */
/*                                                                            */
/******************************************************************************/
DROP FUNCTION IF EXISTS cloud_bender.hash_authorization;
CREATE FUNCTION cloud_bender.hash_authorization (
	$hash_id				INTEGER UNSIGNED,
	$user_id				INTEGER UNSIGNED,
	$password				VARCHAR(100) CHARACTER SET utf8)

	RETURNS				BOOLEAN

NOT DETERMINISTIC
READS SQL DATA
BEGIN
	DECLARE $cloud_id		INTEGER UNSIGNED;
	DECLARE $password_hash	CHAR(32);
	DECLARE $salt			CHAR(32);
	DECLARE $encrypted		CHAR(32);
	DECLARE $found			BOOLEAN DEFAULT TRUE;

	DECLARE CONTINUE HANDLER
	FOR NOT FOUND
	SET $found = FALSE;

	/*
	 * Fetch salt of user's password.
	 */
	SELECT SUBSTRING(password, 34, 32)
	FROM cloud_bender.customers
	WHERE user_id = $user_id
	INTO $salt;

	IF NOT $found THEN
		RETURN FALSE;
	END IF;

	/*
	 * Fetch host's encrypted password. If there is no host password defined
	 * then fetch the cloud's one.
	 */
	SELECT password, parent_id
	FROM cloud_bender.hash_repository
		USE INDEX (PRIMARY)
	WHERE hash_id = $hash_id
	INTO $password_hash, $cloud_id;

	IF NOT $found THEN
		RETURN FALSE;
	END IF;

	IF $password_hash IS NULL THEN
		SELECT password
		FROM cloud_bender.hash_repository
			USE INDEX (PRIMARY)
		WHERE hash_id = $cloud_id
		INTO $password_hash;

		IF NOT $found THEN
			RETURN FALSE;
		END IF;

		IF $password_hash IS NULL THEN
			RETURN FALSE;
		END IF;
	END IF;

	/*
	 * Clear text password is provided. We must encrypt it.
	 */
	SET $encrypted = MD5(CONCAT($password, $salt));

	/*
	 * If password does not match return 'false'.
	 */
	IF $encrypted <> $password_hash THEN
		RETURN FALSE;
	END IF;

	/*
	 * Host exists and password matches.
	 */
	RETURN TRUE;
END;
