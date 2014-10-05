DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  List of activations of hash objects.                                      */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.hash_activations (
	activation_id	INTEGER UNSIGNED			NOT NULL AUTO_INCREMENT,
	activation_code	CHAR(20)					NOT NULL,
	hash_id			INTEGER UNSIGNED			NULL DEFAULT NULL,
	user_id			INTEGER UNSIGNED			NOT NULL,
	order_item_id	INTEGER UNSIGNED			NOT NULL,
	object_type		ENUM('DOM', 'CLD', 'HST')	NOT NULL,
	days			SMALLINT UNSIGNED			NOT NULL,
	valid_from		TIMESTAMP					NULL DEFAULT NULL,
	valid_till		TIMESTAMP					NULL DEFAULT NULL,
	paid			BOOLEAN					NOT NULL DEFAULT FALSE,

	PRIMARY KEY (activation_id),
	KEY idx_hash_id (hash_id),
	UNIQUE KEY idx_activation_code (activation_code),
	KEY idx_order_item_id (order_item_id)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/*  Trigger to be called for each change of order status.                     */
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_joomla.hash_activations_refresh;
CREATE TRIGGER cloud_joomla.hash_activations_refresh
BEFORE INSERT ON cloud_joomla.joomla_virtuemart_order_histories
FOR EACH ROW BEGIN
	DECLARE $activations_number	INTEGER UNSIGNED;
	DECLARE $activation_code		CHAR(20) CHARACTER SET utf8;
	DECLARE $user_id				INTEGER UNSIGNED;
	DECLARE $virtuemart_product_id	INTEGER UNSIGNED;
	DECLARE $order_number			CHAR(64) CHARACTER SET utf8;
	DECLARE $order_item_id			INTEGER UNSIGNED;
	DECLARE $order_item_sku		CHAR(64) CHARACTER SET utf8;
	DECLARE $product_quantity		INTEGER;
	DECLARE $order_status			CHAR(1);
	DECLARE $object_type			CHAR(3);
	DECLARE $custom_value			VARCHAR(10);
	DECLARE $days					SMALLINT UNSIGNED;
	DECLARE $paid					BOOLEAN;
	DECLARE $sub_coins				SMALLINT SIGNED;
	DECLARE $total_coins			SMALLINT SIGNED DEFAULT 0;
	DECLARE $seqno					SMALLINT UNSIGNED DEFAULT 0;
	DECLARE $not_found				BOOLEAN DEFAULT FALSE;

	DECLARE cursor_order_items CURSOR FOR
	SELECT virtuemart_order_item_id, virtuemart_product_id, order_item_sku,
		product_quantity, order_status,
		CEILING(product_subtotal_with_tax * 10) AS coins
	FROM cloud_joomla.joomla_virtuemart_order_items
		USE INDEX (idx_order_item_virtuemart_order_id)
	WHERE virtuemart_order_id = NEW.virtuemart_order_id;

	DECLARE CONTINUE HANDLER
	FOR NOT FOUND
	SET $not_found = TRUE;

	/*
	 * One order my contain several items. Go through all of them.
	 */
	OPEN cursor_order_items;
	order_items: REPEAT
		/*
		 * Fetch next item from the order.
		 */
		FETCH cursor_order_items
		INTO $order_item_id, $virtuemart_product_id, $order_item_sku, $product_quantity, $order_status, $sub_coins;

		/*
		 * Process the item.
		 */
		IF NOT $not_found THEN
			/*
			 * We will need user id.
			 */
			SELECT virtuemart_user_id
			FROM cloud_joomla.joomla_virtuemart_orders
				USE INDEX (PRIMARY)
			WHERE virtuemart_order_id = NEW.virtuemart_order_id
			INTO $user_id;

			/*
			 * Search for a corresponding activation entry.
			 */
			SELECT COUNT(*)
			FROM cloud_bender.hash_activations
				USE INDEX (idx_order_item_id)
			WHERE order_item_id = $order_item_id
			INTO $activations_number;

			/*
			 * If there is no activation entry for this item then create one.
			 */
			IF $activations_number = 0 THEN
				/*
				 * Get order number.
				 */
				SELECT order_number
				FROM cloud_joomla.joomla_virtuemart_orders
					USE INDEX (PRIMARY)
				WHERE virtuemart_order_id = NEW.virtuemart_order_id
				INTO $order_number;

				/*
				 * Find out object type.
				 */
				SET $object_type = SUBSTRING($order_item_sku, 1, 3);

				/*
				 * Find out duration.
				 */
				SELECT joomla_virtuemart_product_customfields.custom_value
				FROM cloud_joomla.joomla_virtuemart_product_customfields
					USE INDEX (idx_virtuemart_product_id)
				JOIN cloud_joomla.joomla_virtuemart_customs
					USE INDEX (PRIMARY)
					USING (virtuemart_custom_id)
				WHERE virtuemart_product_id = $virtuemart_product_id
				  AND custom_title LIKE "VALIDITY"
				INTO $custom_value;

				SELECT CASE $custom_value
					WHEN "1M" THEN 31
					WHEN "2M" THEN 62
					WHEN "3M" THEN 92
					WHEN "6M" THEN 182
					WHEN "1Y" THEN 365
					WHEN "2Y" THEN 730
				END
				INTO $days;

				/*
				 * In case customer has ordered multimple items of the same type.
				 */
				quantity: REPEAT
					/*
					 * Generate activation code (it should be unique).
					 */
					SET $seqno = $seqno + 1;
					SET $activation_code = CONCAT(UPPER($order_number), '-', LPAD($seqno, 3, 0));

					/*
					 * If this item has order status 'confirmed'
					 * then is is already paid.
					 */
					IF $order_status = 'C' THEN
						SET $paid = TRUE;
					ELSE
						SET $paid = FALSE;
					END IF;

					/*
					 * Insert new entry to activation list.
					 */
					INSERT LOW_PRIORITY
					INTO cloud_bender.hash_activations
						(activation_code, user_id, order_item_id, object_type, days, paid)
					VALUES ($activation_code, $user_id, $order_item_id, $object_type, $days, $paid);

					/*
					 * Decrease the counter.
					 */
					SET $product_quantity = $product_quantity - 1;
				UNTIL $product_quantity = 0
				END REPEAT quantity;
			ELSE
				/*
				 * If activation entry/entries exists/exist
				 * then update it/them.
				 * Mark activation(s) as 'paid' if this item
				 * has become status 'confirmed'.
				 */
				IF $order_status = 'C' THEN
					UPDATE LOW_PRIORITY cloud_bender.hash_activations
						USE INDEX (idx_order_item_id)
					SET paid = TRUE
					WHERE order_item_id = $order_item_id;

					/*
					 * Calculate DMAC coins for this item.
					 */
					SET $total_coins = $total_coins + $sub_coins;
				END IF;
			END IF;
		END IF;
	UNTIL $not_found
	END REPEAT order_items;
	CLOSE cursor_order_items;

	/*
	 * Insert a new DMAC entry for this order if there are some coins.
	 */
	IF $total_coins > 0 THEN
		INSERT LOW_PRIORITY
		INTO cloud_bender.dmac_repository
			(user_id, order_id, coins)
		VALUES ($user_id, NEW.virtuemart_order_id, $total_coins);
	END IF;
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS cloud_bender.activate_hash;
CREATE PROCEDURE cloud_bender.activate_hash (
	IN $activation_id		INTEGER UNSIGNED,
	IN $hash_id				INTEGER UNSIGNED)

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $user_id		INTEGER UNSIGNED;
	DECLARE $days			SMALLINT UNSIGNED;
	DECLARE $stamp			TIMESTAMP;
	DECLARE $valid_from	TIMESTAMP;
	DECLARE $valid_till	TIMESTAMP;

	/*
	 * First get user id and activation period.
	 */
	SELECT user_id, days
	FROM cloud_bender.hash_activations
		USE INDEX (PRIMARY)
	WHERE activation_id = $activation_id
	INTO $user_id, $days;

	SET $stamp = DATE(NOW());

	SET $valid_from = $stamp;
	SET $stamp = $stamp + INTERVAL 1 DAY - INTERVAL 1 SECOND;
	SET $valid_till = DATE_ADD($stamp, INTERVAL $days DAY);

	UPDATE LOW_PRIORITY cloud_bender.hash_activations
		USE INDEX (PRIMARY)
	SET hash_id = $hash_id,
	    valid_from = $valid_from,
	    valid_till = $valid_till
	WHERE activation_id = $activation_id;

	UPDATE LOW_PRIORITY cloud_bender.clouds
		USE INDEX (idx_hash_id)
	SET activated = TRUE
	WHERE hash_id = $hash_id;

	CALL cloud_bender.schedule('BIND_RELOAD_CONFIG', NULL, 0);
END;
