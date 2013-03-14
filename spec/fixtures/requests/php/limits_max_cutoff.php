<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetLimits(10, 20, 30, 40);
$cl->Query('query');

?>