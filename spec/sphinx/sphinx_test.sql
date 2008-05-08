/*
SQLyog Enterprise - MySQL GUI v5.20
Host - 5.0.27-community-nt : Database - sphinx_test
*********************************************************************
Server version : 5.0.27-community-nt
*/

SET NAMES utf8;

SET SQL_MODE='';

CREATE database IF NOT EXISTS `sphinx_test`;

USE `sphinx_test`;

/* Table structure for table `links` */

DROP TABLE IF EXISTS `links`;

CREATE TABLE `links` (
  `id` INT(11) NOT NULL auto_increment,
  `name` VARCHAR(255) NOT NULL,
  `created_at` DATETIME NOT NULL,
  `description` TEXT,
  `group_id` INT(11) NOT NULL,
  `rating` FLOAT NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

/* Table structure for table `links64` */

DROP TABLE IF EXISTS `links64`;

CREATE TABLE `links64` (
  `id` BIGINT(11) NOT NULL auto_increment,
  `name` VARCHAR(255) NOT NULL,
  `created_at` DATETIME NOT NULL,
  `description` TEXT,
  `group_id` INT(11) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

/* Data for the table `links` */

INSERT INTO `links`(`id`,`name`,`created_at`,`description`,`group_id`,`rating`) VALUES
	(1,'Paint Protects WiFi Network from Hackers','2007-04-04 06:48:10','A company known as SEC Technologies has created a special type of paint that blocks Wi-Fi signals so that you can be sure hackers can ',1,13.32),
	(2,'Airplanes To Become WiFi Hotspots','2007-04-04 06:49:15','Airlines will start turning their airplanes into WiFi hotspots beginning early next year, WSJ reports. Here\'s what you need to know...',2,54.85),
	(3,'Planet VIP-195 GSM/WiFi Phone With Windows Messanger','2007-04-04 06:50:47','The phone does comply with IEEE 802.11b and IEEE 802.11g to provide phone capability via WiFi. As GSM phone the VIP-195 support 900/1800/1900 band and GPRS too. It comes with simple button to switch between WiFi or GSM mod',1,16.25);

/* Data for the table `links64` */

INSERT INTO `links64`(`id`,`name`,`created_at`,`description`,`group_id`) VALUES
	(4294967297,'Paint Protects WiFi Network from Hackers','2007-04-04 06:48:10','A company known as SEC Technologies has created a special type of paint that blocks Wi-Fi signals so that you can be sure hackers can ',1),
	(4294967298,'Airplanes To Become WiFi Hotspots','2007-04-04 06:49:15','Airlines will start turning their airplanes into WiFi hotspots beginning early next year, WSJ reports. Here\'s what you need to know...',2),
	(4294967299,'Planet VIP-195 GSM/WiFi Phone With Windows Messanger','2007-04-04 06:50:47','The phone does comply with IEEE 802.11b and IEEE 802.11g to provide phone capability via WiFi. As GSM phone the VIP-195 support 900/1800/1900 band and GPRS too. It comes with simple button to switch between WiFi or GSM mod',1);
