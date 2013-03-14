<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetRankingMode(SPH_RANK_EXPR, 'sum(lcs*user_weight)*1000+bm25');
$cl->Query('query');

?>
