<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetMatchMode(SPH_MATCH_FULLSCAN);
$cl->Query('query');

?>