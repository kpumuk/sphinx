<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->UpdateAttributes('test1', array('tags'), array(2 => array(array(1, 2, 3, 4, 5, 6, 7, 8, 9))), true);

?>
