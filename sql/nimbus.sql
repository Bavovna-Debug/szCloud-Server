DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  History of IP address changes in DNS system.                              */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.nimbus_journal (
	nimbus_id		INTEGER UNSIGNED		NOT NULL AUTO_INCREMENT,
	hash_id			INTEGER UNSIGNED		NULL DEFAULT NULL,
	stamp			TIMESTAMP				NOT NULL DEFAULT CURRENT_TIMESTAMP,
	guest_ip		CHAR(40)				NOT NULL,
	guest_port		SMALLINT UNSIGNED		NOT NULL,
	dns_type		ENUM('A', 'AAAA', 'CNAME')	NOT NULL,
	dns_value		VARCHAR(255)			NULL DEFAULT NULL,
	agent			VARCHAR(128)			NOT NULL,
	expire_seconds	INTEGER UNSIGNED		NULL DEFAULT NULL,

	PRIMARY KEY (nimbus_id)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.nimbus_journal_insert;
CREATE TRIGGER cloud_bender.nimbus_journal_insert
BEFORE INSERT ON cloud_bender.nimbus_journal
FOR EACH ROW BEGIN
	IF NEW.expire_seconds = 0 THEN
		SET NEW.expire_seconds = NULL;
	END IF;
END;
