DELIMITER //

/******************************************************************************/
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_logger.log_client (
	event_id		INTEGER UNSIGNED	NOT NULL AUTO_INCREMENT,
	stamp			TIMESTAMP			NOT NULL DEFAULT CURRENT_TIMESTAMP,
	touched			BOOLEAN			NOT NULL DEFAULT FALSE,
	processed		BOOLEAN			NOT NULL DEFAULT FALSE,
	skipped			BOOLEAN			NOT NULL DEFAULT FALSE,
	message			VARCHAR(512)		NOT NULL,

	PRIMARY KEY (event_id),
	KEY idx_touched (touched),
	KEY idx_processed (processed),
	KEY idx_skipped (skipped)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;

CREATE TABLE IF NOT EXISTS cloud_logger.log_config
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_database
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_default
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_delegation_only
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_dispatch
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_dnssec
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_general
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_lame_servers
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_network
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_notify
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_queries
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_resolver
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_security
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_unmatched
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_update
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_update_security
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_xfer_in
LIKE cloud_logger.log_client;

CREATE TABLE IF NOT EXISTS cloud_logger.log_xfer_out
LIKE cloud_logger.log_client;
