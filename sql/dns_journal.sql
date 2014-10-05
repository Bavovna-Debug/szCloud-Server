DELIMITER //

/******************************************************************************/
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.dns_journal_a (
	entry_id		INTEGER UNSIGNED		NOT NULL AUTO_INCREMENT,
	hash_id			INTEGER UNSIGNED		NOT NULL,
	active			BOOLEAN				NOT NULL DEFAULT TRUE,
	dns_from		TIMESTAMP				NOT NULL DEFAULT CURRENT_TIMESTAMP,
	dns_till		TIMESTAMP				NULL DEFAULT NULL,
	ttl				MEDIUMINT UNSIGNED		NOT NULL,
	ip_address		VARCHAR(15)			NOT NULL,

	PRIMARY KEY (entry_id),
	KEY idx_hash_id (hash_id),
	KEY idx_hash_id_active (hash_id, active)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.dns_journal_aaaa (
	entry_id		INTEGER UNSIGNED		NOT NULL AUTO_INCREMENT,
	hash_id			INTEGER UNSIGNED		NOT NULL,
	active			BOOLEAN				NOT NULL DEFAULT TRUE,
	dns_from		TIMESTAMP				NOT NULL DEFAULT CURRENT_TIMESTAMP,
	dns_till		TIMESTAMP				NULL DEFAULT NULL,
	ttl				MEDIUMINT UNSIGNED		NOT NULL,
	ip_address		VARCHAR(39)			NOT NULL,

	PRIMARY KEY (entry_id),
	KEY idx_hash_id (hash_id),
	KEY idx_hash_id_active (hash_id, active)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.dns_journal_cname (
	entry_id		INTEGER UNSIGNED		NOT NULL AUTO_INCREMENT,
	hash_id			INTEGER UNSIGNED		NOT NULL,
	active			BOOLEAN				NOT NULL DEFAULT TRUE,
	dns_from		TIMESTAMP				NOT NULL DEFAULT CURRENT_TIMESTAMP,
	dns_till		TIMESTAMP				NULL DEFAULT NULL,
	ttl				MEDIUMINT UNSIGNED		NOT NULL,
	canonical		VARCHAR(255)			NOT NULL,

	PRIMARY KEY (entry_id),
	KEY idx_hash_id (hash_id),
	KEY idx_hash_id_active (hash_id, active)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.dns_journal_mx (
	entry_id		INTEGER UNSIGNED		NOT NULL AUTO_INCREMENT,
	hash_id			INTEGER UNSIGNED		NOT NULL,
	active			BOOLEAN				NOT NULL DEFAULT TRUE,
	dns_from		TIMESTAMP				NOT NULL DEFAULT CURRENT_TIMESTAMP,
	dns_till		TIMESTAMP				NULL DEFAULT NULL,
	ttl				MEDIUMINT UNSIGNED		NOT NULL,
	preference		INTEGER UNSIGNED		NOT NULL,
	exchange		VARCHAR(255)			NOT NULL,

	PRIMARY KEY (entry_id),
	KEY idx_hash_id (hash_id),
	KEY idx_hash_id_active (hash_id, active)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.dns_journal_ns (
	entry_id		INTEGER UNSIGNED		NOT NULL AUTO_INCREMENT,
	hash_id			INTEGER UNSIGNED		NOT NULL,
	active			BOOLEAN				NOT NULL DEFAULT TRUE,
	dns_from		TIMESTAMP				NOT NULL DEFAULT CURRENT_TIMESTAMP,
	dns_till		TIMESTAMP				NULL DEFAULT NULL,
	ttl				MEDIUMINT UNSIGNED		NOT NULL,
	nameserver		VARCHAR(255)			NOT NULL,

	PRIMARY KEY (entry_id),
	KEY idx_hash_id (hash_id),
	KEY idx_hash_id_active (hash_id, active)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.dns_journal_txt (
	entry_id		INTEGER UNSIGNED		NOT NULL AUTO_INCREMENT,
	hash_id			INTEGER UNSIGNED		NOT NULL,
	active			BOOLEAN				NOT NULL DEFAULT TRUE,
	dns_from		TIMESTAMP				NOT NULL DEFAULT CURRENT_TIMESTAMP,
	dns_till		TIMESTAMP				NULL DEFAULT NULL,
	ttl				MEDIUMINT UNSIGNED		NOT NULL,
	txt_data		VARCHAR(255)			NOT NULL,

	PRIMARY KEY (entry_id),
	KEY idx_hash_id (hash_id),
	KEY idx_hash_id_active (hash_id, active)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.dns_journal_a_update;
CREATE TRIGGER cloud_bender.dns_journal_a_update
BEFORE UPDATE ON cloud_bender.dns_journal_a
FOR EACH ROW BEGIN
	IF (OLD.active = TRUE) AND (NEW.active = FALSE) THEN
		SET NEW.dns_till = CURRENT_TIMESTAMP;
	END IF;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.dns_journal_aaaa_update;
CREATE TRIGGER cloud_bender.dns_journal_aaaa_update
BEFORE UPDATE ON cloud_bender.dns_journal_aaaa
FOR EACH ROW BEGIN
	IF (OLD.active = TRUE) AND (NEW.active = FALSE) THEN
		SET NEW.dns_till = CURRENT_TIMESTAMP;
	END IF;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.dns_journal_cname_update;
CREATE TRIGGER cloud_bender.dns_journal_cname_update
BEFORE UPDATE ON cloud_bender.dns_journal_cname
FOR EACH ROW BEGIN
	IF (OLD.active = TRUE) AND (NEW.active = FALSE) THEN
		SET NEW.dns_till = CURRENT_TIMESTAMP;
	END IF;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.dns_journal_mx_update;
CREATE TRIGGER cloud_bender.dns_journal_mx_update
BEFORE UPDATE ON cloud_bender.dns_journal_mx
FOR EACH ROW BEGIN
	IF (OLD.active = TRUE) AND (NEW.active = FALSE) THEN
		SET NEW.dns_till = CURRENT_TIMESTAMP;
	END IF;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.dns_journal_ns_update;
CREATE TRIGGER cloud_bender.dns_journal_ns_update
BEFORE UPDATE ON cloud_bender.dns_journal_ns
FOR EACH ROW BEGIN
	IF (OLD.active = TRUE) AND (NEW.active = FALSE) THEN
		SET NEW.dns_till = CURRENT_TIMESTAMP;
	END IF;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.dns_journal_txt_update;
CREATE TRIGGER cloud_bender.dns_journal_txt_update
BEFORE UPDATE ON cloud_bender.dns_journal_txt
FOR EACH ROW BEGIN
	IF (OLD.active = TRUE) AND (NEW.active = FALSE) THEN
		SET NEW.dns_till = CURRENT_TIMESTAMP;
	END IF;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/

DROP VIEW IF EXISTS cloud_bender.dns_journal;
CREATE VIEW cloud_bender.dns_journal AS
SELECT "a" AS journal, entry_id, hash_id
FROM cloud_bender.dns_journal_a
UNION
SELECT "aaaa" AS journal, entry_id, hash_id
FROM cloud_bender.dns_journal_aaaa
UNION
SELECT "cname" AS journal, entry_id, hash_id
FROM cloud_bender.dns_journal_cname
UNION
SELECT "mx" AS journal, entry_id, hash_id
FROM cloud_bender.dns_journal_mx
UNION
SELECT "ns" AS journal, entry_id, hash_id
FROM cloud_bender.dns_journal_ns
UNION
SELECT "txt" AS journal, entry_id, hash_id
FROM cloud_bender.dns_journal_txt;
