<?php
// Backstop for private/: if a server ever ignored private/.htaccess, opening
// the folder itself shows nothing instead of a file list.
http_response_code(403);
exit;
