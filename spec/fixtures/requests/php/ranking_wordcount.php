<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetRankingMode(SPH_RANK_WORDCOUNT);
$cl->Query('query');

?>