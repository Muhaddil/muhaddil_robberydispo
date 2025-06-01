CREATE TABLE IF NOT EXISTS `robbery_requests` (
  `thief_id` INT NOT NULL,
  `status` VARCHAR(20) NOT NULL,
  `timestamp` INT NOT NULL,
  `decided_by` INT DEFAULT NULL,
  PRIMARY KEY (`thief_id`)
);

ALTER TABLE robbery_requests
ADD COLUMN robbery_type VARCHAR(50) DEFAULT NULL;