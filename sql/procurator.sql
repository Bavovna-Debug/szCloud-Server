DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  File repository.                                                          */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS procurator.file_repository (
	stamp			TIMESTAMP			NOT NULL DEFAULT CURRENT_TIMESTAMP,
	file_id			INTEGER UNSIGNED	NOT NULL AUTO_INCREMENT,
	published		BOOLEAN			NOT NULL DEFAULT FALSE,
	in_validation	BOOLEAN			NOT NULL DEFAULT FALSE,
	directory		VARCHAR(128)		NOT NULL,
	file_name		VARCHAR(64)		NOT NULL,
	file_size		INTEGER UNSIGNED	NULL DEFAULT NULL,
	creation_stamp	DATETIME			NOT NULL,

	PRIMARY KEY (file_id),
	UNIQUE KEY idx_file_repository_unique (directory,file_name),
	KEY idx_published (published),
	KEY idx_in_validation (in_validation)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/*  Log messages.                                                             */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS procurator.log (
	stamp		TIMESTAMP			NOT NULL DEFAULT CURRENT_TIMESTAMP,
	log_id		INTEGER UNSIGNED	NOT NULL AUTO_INCREMENT,
	originator	CHAR(8)			NULL DEFAULT NULL,
	flag		ENUM('INFO','WARNING','ERROR') NULL DEFAULT NULL,
	message		TEXT				NOT NULL,

	PRIMARY KEY (log_id)
)
ENGINE = MyISAM
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS procurator.unlink_file;
CREATE PROCEDURE procurator.unlink_file (IN $file_id INTEGER UNSIGNED)
DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	UPDATE LOW_PRIORITY procurator.file_repository
	SET published = FALSE
	WHERE file_id = $file_id;
END;

/******************************************************************************/
/*                                                                            */
/*  Log an informational message.                                             */
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS procurator.log_info;
CREATE PROCEDURE procurator.log_info (
	IN $originator	CHAR(8),
	IN $message		TEXT CHARACTER SET utf8)

DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	INSERT LOW_PRIORITY
	INTO procurator.log (originator, flag, message)
	VALUES ($originator, 'INFO', $message);
END;


/******************************************************************************/
/*                                                                            */
/*  Log a warning message.                                                    */
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS procurator.log_warning;
CREATE PROCEDURE procurator.log_warning (
	IN $originator	CHAR(8),
	IN $message		TEXT CHARACTER SET utf8)

DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	INSERT LOW_PRIORITY
	INTO procurator.log (originator, flag, message)
	VALUES ($originator, 'WARNING', $message);
END;


/******************************************************************************/
/*                                                                            */
/*  Log an error message.                                                     */
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS procurator.log_error;
CREATE PROCEDURE procurator.log_error (
	IN $originator	CHAR(8),
	IN $message		TEXT CHARACTER SET utf8)

DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	INSERT LOW_PRIORITY
	INTO procurator.log (originator, flag, message)
	VALUES ($originator, 'ERROR', $message);
END;
