<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetQueryFlag('reverse_scan', 1);
$cl->SetQueryFlag('sort_method', 'kbuffer');
$cl->SetQueryFlag('max_predicted_time', 15);
$cl->SetQueryFlag('boolean_simplify', true);
$cl->SetQueryFlag('idf', 'plain');

$cl->SetQueryFlag('reverse_scan', 0);
$cl->SetQueryFlag('sort_method', 'pq');
$cl->SetQueryFlag('max_predicted_time', 0);
$cl->SetQueryFlag('boolean_simplify', false);
$cl->SetQueryFlag('idf', 'normalized');
$cl->Query('query');

?>
