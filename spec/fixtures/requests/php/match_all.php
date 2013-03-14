<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetMatchMode(SPH_MATCH_ALL);
$cl->Query('query');

?>