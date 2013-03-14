<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetMaxQueryTime(1000);
$cl->Query('query');

?>