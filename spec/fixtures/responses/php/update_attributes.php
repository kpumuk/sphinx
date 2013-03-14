<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->UpdateAttributes('test1', array('group_id'), array(2 => array(1)));

?>
