<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->Query('wifi', 'fakeindex');

?>
