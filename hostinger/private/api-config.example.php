<?php
// Settings for the eBongabong Calendar file API.
//
// On Hostinger, copy this file to   private/api-config.php   (same folder),
// then check the four web addresses below match your site. Nothing in here
// is secret: the Supabase key is the PUBLIC "publishable" key that already
// ships inside the app and the admin portal. Never put Supabase's
// service_role / secret key on this server.
//
// This "private" folder must sit NEXT TO public_html, not inside it:
//   domains/calendar.bongabong.gov.ph/
//     public_html/      <- the web app, api/, media/
//     private/          <- this file, uploads/

const SUPABASE_URL = 'https://xuxnoydakqembrytdbyz.supabase.co';
const SUPABASE_KEY = 'sb_publishable_XnqlZ-m2efmbasNuZ7fyVg_74qTnghA';

// Where the api/ and media/ folders are reachable from the internet.
const API_PUBLIC_URL = 'https://calendar.bongabong.gov.ph/api';
const MEDIA_PUBLIC_URL = 'https://calendar.bongabong.gov.ph/media';

// Folders on this server (normally left as they are).
const PRIVATE_DIR = __DIR__;
const UPLOADS_DIR = __DIR__ . '/uploads';
const MEDIA_DIR = __DIR__ . '/../public_html/media';

// Websites allowed to call the API from a browser: the web app, and the
// LGU-admin portal (GitHub Pages, plus local testing addresses).
const ALLOWED_ORIGINS = [
    'https://calendar.bongabong.gov.ph',
    'https://vincentjhon31.github.io',
    'http://127.0.0.1:5500',
    'http://localhost:5500',
];
