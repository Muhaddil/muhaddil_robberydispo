CREATE TABLE IF NOT EXISTS `robbery_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `thief_identifier` varchar(64) NOT NULL,
  `thief_name` varchar(64) NOT NULL,
  `status` varchar(20) NOT NULL,
  `timestamp` int(11) NOT NULL,
  `decided_by_identifier` varchar(64) DEFAULT NULL,
  `decided_by_name` varchar(64) DEFAULT NULL,
  `robbery_type` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;