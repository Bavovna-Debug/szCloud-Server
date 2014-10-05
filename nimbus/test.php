<?php

$output = exec('date');
$output .= "\n";
$output .= exec('df -k');
$output .= exec('ifconfig');
echo $output;

exit;

?>
