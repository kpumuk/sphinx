<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetMatchMode(SPH_MATCH_ANY);
$cl->Query('query');

?>