DELIMITER //

DROP FUNCTION IF EXISTS cloud_bender.create_dnssec_key;

/******************************************************************************/
/*                                                                            */
/*                                                                            */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.dnssec_keys (
	stamp			TIMESTAMP			NOT NULL DEFAULT CURRENT_TIMESTAMP,
	dnssec_key_id	INTEGER UNSIGNED	NOT NULL AUTO_INCREMENT,
	user_id			INTEGER UNSIGNED	NOT NULL,
	hash			CHAR(32)			NOT NULL,
	internal		BOOLEAN			NOT NULL DEFAULT FALSE,
	need_recreation	BOOLEAN			NOT NULL DEFAULT TRUE,
	key_name		VARCHAR(255)		NOT NULL,
	key_type		ENUM('ZONE', 'HOST', 'USER') NOT NULL,
	key_algorithm	CHAR(12)			NOT NULL,
	key_size		SMALLINT UNSIGNED	NOT NULL,
	key_secret		VARCHAR(720)		NULL DEFAULT NULL,
	key_file_id		INTEGER UNSIGNED	NULL DEFAULT NULL,
	private_file_id	INTEGER UNSIGNED	NULL DEFAULT NULL,

	PRIMARY KEY (dnssec_key_id),
	UNIQUE KEY idx_hash (hash),
	UNIQUE KEY idx_key_name (key_name),
	KEY idx_user_id (user_id),
	KEY idx_internal (internal),
	KEY idx_need_recreation (need_recreation)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/*                                                                            */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.dnssec_rules (
	stamp				TIMESTAMP			NOT NULL DEFAULT CURRENT_TIMESTAMP,
	hash				CHAR(32)			NOT NULL,
	dnssec_rule_id		INTEGER UNSIGNED	NOT NULL AUTO_INCREMENT,
	dnssec_key_id		INTEGER UNSIGNED	NOT NULL,
	hash_id				INTEGER UNSIGNED	NOT NULL,
	dns_type			ENUM('ANY', 'A', 'AAAA', 'CNAME', 'MX', 'NS', 'RP', 'TXT') NOT NULL DEFAULT 'ANY',

	PRIMARY KEY (dnssec_rule_id),
	UNIQUE KEY idx_hash (hash),
	UNIQUE KEY idx_unique (dnssec_key_id, hash_id, dns_type),
	KEY idx_dnssec_key_id (dnssec_key_id),
	KEY idx_hash_id (hash_id),
	KEY idx_dnssec_key_id_hash_id (dnssec_key_id, hash_id)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP FUNCTION IF EXISTS cloud_bender.define_dnssec_key;
CREATE FUNCTION cloud_bender.define_dnssec_key (
	$internal			BOOLEAN,
	$user_id			INTEGER UNSIGNED,
	$key_name			CHAR(64) CHARACTER SET utf8,
	$key_type			CHAR(4),
	$key_size			SMALLINT,
	$key_algorithm		CHAR(12))

	RETURNS			INTEGER UNSIGNED

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $dnssec_key_id	INTEGER UNSIGNED;
	DECLARE $user_name		VARCHAR(150) CHARACTER SET utf8;
	DECLARE $hash			VARCHAR(512) CHARACTER SET utf8;
	DECLARE $retries		SMALLINT DEFAULT 100;
	DECLARE $succeeded		BOOLEAN;

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
		SET $hash = CONCAT($hash, '-', $user_name, '-', $key_name);
		SET $hash = MD5($hash);
		SET $hash = UPPER($hash);

		/*
		 * Try to insert a new entry.
		 */
		SET $succeeded = TRUE;
		INSERT LOW_PRIORITY
		INTO cloud_bender.dnssec_keys (internal, user_id, hash, key_name, key_type, key_size, key_algorithm)
		VALUES ($internal, $user_id, $hash, $key_name, $key_type, $key_size, $key_algorithm);

		/*
		 * Check result after insertion.
		 */
		IF $succeeded = TRUE THEN
			/*
			 * If a new entry inserted successfully then its id
			 * must be a return value.
			 */
			SET $dnssec_key_id = LAST_INSERT_ID();

			CALL cloud_bender.schedule('DEFINE_DNSSEC_KEY', $dnssec_key_id, 0);

			RETURN $dnssec_key_id;
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
DROP FUNCTION IF EXISTS cloud_bender.delete_dnssec_key;
CREATE FUNCTION cloud_bender.delete_dnssec_key (
	$user_id			INTEGER UNSIGNED,
	$dnssec_key_id		INTEGER UNSIGNED)

	RETURNS			BOOLEAN

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $real_user_id		INTEGER UNSIGNED;
	DECLARE $dnssec_rule_id	INTEGER UNSIGNED;
	DECLARE $dummy				BOOLEAN;
	DECLARE $not_found			BOOLEAN DEFAULT FALSE;

	DECLARE cursor_rules CURSOR FOR
	SELECT dnssec_rule_id
	FROM cloud_bender.dnssec_rules
	WHERE dnssec_key_id = $dnssec_key_id;

	DECLARE CONTINUE HANDLER
	FOR NOT FOUND
	SET $not_found = TRUE;

	SELECT user_id
	FROM cloud_bender.dnssec_keys
	WHERE dnssec_key_id = $dnssec_key_id
	INTO $real_user_id;

	IF ($not_found IS TRUE) OR ($user_id != $real_user_id) THEN
		RETURN FALSE;
	END IF;

	OPEN cursor_rules;
	REPEAT
		FETCH cursor_rules
		INTO $dnssec_rule_id;

		IF NOT $not_found THEN
			SELECT cloud_bender.delete_dnssec_rule($user_id, $dnssec_rule_id)
			INTO $dummy;
		END IF;
	UNTIL $not_found
	END REPEAT;
	CLOSE cursor_rules;

	CALL cloud_bender.schedule('DELETE_DNSSEC_KEY', $dnssec_key_id, 0);

	RETURN TRUE;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP FUNCTION IF EXISTS cloud_bender.define_dnssec_rule;
CREATE FUNCTION cloud_bender.define_dnssec_rule (
	$user_id			INTEGER UNSIGNED,
	$dnssec_key_id		INTEGER UNSIGNED,
	$hash_id			INTEGER UNSIGNED,
	$dns_type			CHAR(5))

	RETURNS			INTEGER UNSIGNED

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $real_user_id		INTEGER UNSIGNED;
	DECLARE $dnssec_rule_id	INTEGER UNSIGNED;
	DECLARE $hash				VARCHAR(64) CHARACTER SET utf8;
	DECLARE $retries			SMALLINT DEFAULT 100;
	DECLARE $succeeded			BOOLEAN;

	DECLARE CONTINUE HANDLER
	FOR NOT FOUND
	RETURN 0;

	/*
	 * Prepare handler for the case of duplicate index.
	 */
	DECLARE CONTINUE HANDLER
	FOR SQLSTATE VALUE '23000'
	SET $succeeded = FALSE;

	SELECT user_id
	FROM cloud_bender.dnssec_keys
	WHERE dnssec_key_id = $dnssec_key_id
	INTO $real_user_id;

	IF $user_id != $real_user_id THEN
		RETURN 0;
	END IF;

	DELETE LOW_PRIORITY
	FROM cloud_bender.dnssec_rules
	WHERE dnssec_key_id = $dnssec_key_id
	  AND hash_id = $hash_id
	  AND dns_type = $dns_type;

	/*
	 * If neccessary, repeat hash code and secret generation several times
	 * until unique values are generated.
	 */
	if_duplicate_index: REPEAT
		SET $hash = CONCAT(UNIX_TIMESTAMP(), '-', $retries);
		SET $hash = CONCAT($hash, '-', $hash_id, '-', $dns_type);
		SET $hash = MD5($hash);
		SET $hash = UPPER($hash);

		/*
		 * Try to insert a new entry.
		 */
		SET $succeeded = TRUE;
		INSERT LOW_PRIORITY
		INTO cloud_bender.dnssec_rules (hash, dnssec_key_id, hash_id, dns_type)
		VALUES ($hash, $dnssec_key_id, $hash_id, $dns_type);

		/*
		 * Check result after insertion.
		 */
		IF $succeeded = TRUE THEN
			/*
			 * If a new entry inserted successfully then its id
			 * must be a return value.
			 */
			SET $dnssec_rule_id = LAST_INSERT_ID();

			CALL cloud_bender.schedule('DEFINE_DNSSEC_RULE', $dnssec_rule_id, 0);

			RETURN $dnssec_rule_id;
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
DROP FUNCTION IF EXISTS cloud_bender.delete_dnssec_rule;
CREATE FUNCTION cloud_bender.delete_dnssec_rule (
	$user_id			INTEGER UNSIGNED,
	$dnssec_rule_id		INTEGER UNSIGNED)

	RETURNS			BOOLEAN

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $real_user_id	INTEGER UNSIGNED;

	DECLARE CONTINUE HANDLER
	FOR NOT FOUND
	RETURN FALSE;

	SELECT user_id
	FROM cloud_bender.dnssec_rules
		USE INDEX (PRIMARY)
	JOIN cloud_bender.dnssec_keys
		USE INDEX (PRIMARY)
		USING (dnssec_key_id)
	WHERE dnssec_rule_id = $dnssec_rule_id
	INTO $real_user_id;

	IF $user_id != $real_user_id THEN
		RETURN FALSE;
	END IF;

	CALL cloud_bender.schedule('DELETE_DNSSEC_RULE', $dnssec_rule_id, 0);

	RETURN TRUE;
END;
