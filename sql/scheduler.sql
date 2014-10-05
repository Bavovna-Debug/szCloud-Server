DELIMITER //

/******************************************************************************/
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.schedules (
	schedule_id		INTEGER UNSIGNED	NOT NULL AUTO_INCREMENT,
	requested		TIMESTAMP			NOT NULL DEFAULT CURRENT_TIMESTAMP,
	scheduled		TIMESTAMP			NOT NULL,
	touched			TIMESTAMP			NULL DEFAULT NULL,
	processed		TIMESTAMP			NULL DEFAULT NULL,
	command			CHAR(40)			NOT NULL,
	options			VARCHAR(255)		NULL DEFAULT NULL,

	PRIMARY KEY (schedule_id),
	KEY idx_touched (touched),
	KEY idx_touched_command (touched, command),
	KEY idx_touched_command_options (touched, command, options)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS cloud_bender.schedule;
CREATE PROCEDURE cloud_bender.schedule (
	IN $command			CHAR(40),
	IN $options			VARCHAR(255),
	IN $seconds			INTEGER UNSIGNED)

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $schedule_id	INTEGER UNSIGNED;
	DECLARE $scheduled		TIMESTAMP;

	SET $scheduled = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL $seconds SECOND);

	/*
	 * Create a new host.
	 */
	INSERT LOW_PRIORITY
	INTO cloud_bender.schedules (scheduled, command, options)
	VALUES ($scheduled, $command, $options);

	SET $schedule_id = LAST_INSERT_ID();

	DELETE LOW_PRIORITY
	FROM cloud_bender.schedules
	WHERE touched IS NULL
	  AND command = $command
	  AND options LIKE $options
	  AND schedule_id != $schedule_id;
END;
