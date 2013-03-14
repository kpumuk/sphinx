<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetRankingMode(SPH_RANK_FIELDMASK);
$cl->Query('query');

?>