DELIMITER //

/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP FUNCTION IF EXISTS cloud_bender.nimbus_set_ip;
CREATE FUNCTION cloud_bender.nimbus_set_ip (
	$hash_id			INTEGER UNSIGNED,
	$guest_ip			CHAR(40),
	$guest_port			SMALLINT UNSIGNED,
	$dns_type			CHAR(5),
	$dns_value			VARCHAR(255),
	$agent				VARCHAR(128) CHARACTER SET utf8,
	$expire_seconds		INTEGER UNSIGNED)

	RETURNS				BOOLEAN

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $nimbus_id		INTEGER UNSIGNED;
	DECLARE $expire		TIMESTAMP DEFAULT NULL;
	DECLARE $result		BOOLEAN;

	INSERT INTO cloud_bender.nimbus_journal
		(hash_id, guest_ip, guest_port, dns_type, dns_value, agent, expire_seconds)
	VALUES ($hash_id, $guest_ip, $guest_port, $dns_type, $dns_value, $agent, $expire_seconds);

	/*
	 * Get id of newly inserted record.
	 */
	SET $nimbus_id = LAST_INSERT_ID();

	/*
	 * If expiration parameter specified calculate expiration time since now.
	 */
	IF ($expire_seconds IS NOT NULL) AND ($expire_seconds > 0) THEN
		SET $expire = CURRENT_TIMESTAMP + INTERVAL $expire_seconds SECOND;
	END IF;

	/*
	 * Insert new entry in DNS journal.
	 */
	SELECT cloud_bender.set_ip($nimbus_id, $hash_id, $dns_type, $dns_value, $expire)
	INTO $result;

	RETURN $result;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS cloud_bender.frontend_set_ip;
CREATE PROCEDURE cloud_bender.frontend_set_ip (
	IN $hash_id			INTEGER UNSIGNED,
	$dns_type			CHAR(5),
	$dns_value			VARCHAR(255))

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $dummy		BOOLEAN;

	SELECT cloud_bender.set_ip(NULL, $hash_id, $dns_type, $dns_value, NULL)
	INTO $dummy;
END;


/******************************************************************************/
/*                                                                            */
/*  Validate user's IP address. If specified user did not use specified       */
/*  host name before then record his IP address and return 'true'.            */
/*  If he did already use this host name and his IP address has not           */
/*  changed since his last visit then return 'false'. If his IP address has   */
/*  changed then record his new IP address in a database and return 'true'.   */
/*                                                                            */
/*  Return value 'true' means that some DNS actions must take place.          */
/*                                                                            */
/*  IP family has to be taken as factor for comparison - IPv4 address must    */
/*  be compared with the last IPv4 request and though IPv6 with IPv6.         */
/*                                                                            */
/******************************************************************************/
DROP FUNCTION IF EXISTS cloud_bender.set_ip;
CREATE FUNCTION cloud_bender.set_ip (
	$nimbus_id				INTEGER UNSIGNED,
	$hash_id				INTEGER UNSIGNED,
	$dns_type				CHAR(5),
	$dns_value				VARCHAR(255),
	$dns_till				TIMESTAMP)

	RETURNS				BOOLEAN

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $event_id			INTEGER UNSIGNED;
	DECLARE $last_dns_value	VARCHAR(255) DEFAULT NULL;
	DECLARE $need_new_entry	BOOLEAN DEFAULT FALSE;
	DECLARE $found				BOOLEAN DEFAULT TRUE;

	DECLARE CONTINUE HANDLER
	FOR NOT FOUND
	SET $found = FALSE;

	/*
	 * Search for last IP address entry for specified host.
	 */
	SELECT MAX(event_id)
	FROM cloud_bender.dns_journal
		USE INDEX (idx_hash_id_dns_type_del_requested)
	WHERE hash_id = $hash_id
	  AND dns_type = $dns_type
	  AND del_requested IS FALSE
	INTO $event_id;

	/*
	 * If there is no IP address recorded for this host for specified
	 * IP version then we need to create a new entry.
	 */
	IF $event_id IS NULL THEN
		SET $need_new_entry = TRUE;
	ELSE
		/*
		 * If parameter IP address is null then last IP address
		 * of the specified IP version has to be deleted from DNS.
		 */
		IF ($dns_value IS NULL) THEN
			/*
			 * Mark last entry to delete its IP address.
			 */
			UPDATE cloud_bender.dns_journal
				USE INDEX (PRIMARY)
			SET dns_till = CURRENT_TIMESTAMP
			WHERE event_id = $event_id;
		ELSE
			/*
			 * Get the last known IP address.
			 */
			SELECT dns_value
			FROM cloud_bender.dns_journal
				USE INDEX (PRIMARY)
			WHERE event_id = $event_id
			INTO $last_dns_value;

			/*
			 * If it differs from the new one then we need to create a new entry.
			 */
			IF $last_dns_value <> $dns_value THEN
				/*
				 * Mark last entry to delete its IP address.
				 */
				UPDATE cloud_bender.dns_journal
					USE INDEX (PRIMARY)
				SET dns_till = CURRENT_TIMESTAMP
				WHERE event_id = $event_id;

				SET $need_new_entry = TRUE;
			END IF;
		END IF;
	END IF;

	/*
	 * If there were no IP address recorded for this host or if IP address
	 * has changed then notify new IP address.
	 */
	IF $need_new_entry THEN
		INSERT INTO cloud_bender.dns_journal
			(nimbus_id, hash_id, dns_type, dns_value, dns_till)
		VALUES ($nimbus_id, $hash_id, $dns_type, $dns_value, $dns_till);

		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END;
