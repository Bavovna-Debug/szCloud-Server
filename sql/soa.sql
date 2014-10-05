DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  List of SOA records for domains and clouds.                               */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.soas (
	soa_id			INTEGER UNSIGNED	NOT NULL AUTO_INCREMENT,
	root			BOOLEAN			NOT NULL DEFAULT FALSE,
	include_file_id	INTEGER UNSIGNED	NULL DEFAULT NULL,
	email			VARCHAR(100)		NOT NULL,
	last_serial		INTEGER UNSIGNED	NOT NULL DEFAULT 0,
	soa_refresh		MEDIUMINT UNSIGNED	NOT NULL DEFAULT 86400,
	soa_retry		MEDIUMINT UNSIGNED	NOT NULL DEFAULT 28800,
	soa_expire		MEDIUMINT UNSIGNED	NOT NULL DEFAULT 604800,
	soa_ttl			MEDIUMINT UNSIGNED	NOT NULL DEFAULT 86400,

	PRIMARY KEY (soa_id)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.soas_insert;
CREATE TRIGGER cloud_bender.soas_insert
BEFORE INSERT ON cloud_bender.soas
FOR EACH ROW BEGIN
	SET NEW.last_serial = CONCAT(DATE_FORMAT(NOW(), '%Y%m%d'), '00');
END;

/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS cloud_bender.update_soa;
CREATE PROCEDURE cloud_bender.update_soa (
	IN $soa_id				INTEGER UNSIGNED,
	IN $soa_refresh			MEDIUMINT UNSIGNED,
	IN $soa_retry			MEDIUMINT UNSIGNED,
	IN $soa_expire			MEDIUMINT UNSIGNED,
	IN $soa_ttl				MEDIUMINT UNSIGNED)

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	/*
	 * Chahge SOA values.
	 */
	UPDATE cloud_bender.soas
		USE INDEX (PRIMARY)
	SET soa_refresh = $soa_refresh,
		soa_retry = $soa_retry,
		soa_expire = $soa_expire,
		soa_ttl = $soa_ttl
	WHERE soa_id = $soa_id;

	/*
	 * Flag domain as "need update" (in case there is a domain associated with this SOA record).
	 */
/*
	UPDATE cloud_bender.domains
		USE INDEX (idx_soa_id)
	SET need_refresh = TRUE
	WHERE soa_id = $soa_id;
*/

	/*
	 * Flag cloud as "need update" (in case there is a cloud associated with this SOA record).
	 */
/*
	UPDATE cloud_bender.clouds
		USE INDEX (idx_soa_id)
	SET need_refresh = TRUE
	WHERE soa_id = $soa_id;
*/
END;
