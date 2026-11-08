<?php
// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Netresearch DTT GmbH
//
// Builds SQL that seeds a local TER (extensions.typo3.org/ter, DDEV) from the
// public catalogue, so that extension pages and the version form can be
// checked on a running instance. Relation rows are left out on purpose: the
// derived relations come from the `dependencies` JSON.
//
// Usage: php ter-seed-from-catalogue.php extensions.xml.gz [ext_key ...] > seed.sql
// The catalogue is https://extensions.typo3.org/fileadmin/ter/extensions.xml.gz.

ini_set('memory_limit', '-1');
$keys = array_slice($argv, 2) ?: ['solr', 'news', 'dd_deepl', 'custom_shortcut', 'bgm_hreflang', 'container_modify_fields', 'iconcheck', 'sessionpassword', 'tt_products', 'mda_sbbtimetable', 'static_info_tables', 'tt_address'];
$xml = simplexml_load_string(gzdecode(file_get_contents($argv[1])), 'SimpleXMLElement', LIBXML_PARSEHUGE);
$q = fn ($s) => "'" . str_replace(["\\", "'"], ["\\\\", "''"], (string)$s) . "'";
$int = function (string $v): int { $p = array_map('intval', explode('.', $v)) + [0, 0, 0]; return $p[0] * 1000000 + ($p[1] ?? 0) * 1000 + ($p[2] ?? 0); };
$now = time();
$sql = [];
$sql[] = "INSERT INTO pages (uid,pid,title,slug,doktype,is_siteroot,hidden,deleted,perms_everybody,perms_user,perms_group,tstamp,crdate) VALUES
(1,0,'Extensions','/',1,1,0,0,1,31,31,$now,$now),
(2,1,'Storage','/storage',254,0,0,0,1,31,31,$now,$now),
(3,1,'Extension','/extension',1,0,0,0,1,31,31,$now,$now);";
$sql[] = "INSERT INTO sys_template (uid,pid,title,root,clear,include_static_file,constants,config,tstamp,crdate) VALUES
(1,1,'Review',1,3,'EXT:fluid_styled_content/Configuration/TypoScript/,EXT:ter_layout/Configuration/TypoScript/Default/,EXT:ter_fe2/Configuration/TypoScript/Default/','','',$now,$now);";
// TYPO3 13 renders the plugin from CType; a row with CType 'list' renders nothing.
$sql[] = "INSERT INTO tt_content (uid,pid,CType,list_type,colPos,header,tstamp,crdate) VALUES
(1,3,'terfe2_pi1','',0,'',$now,$now),(2,1,'terfe2_pi1','',0,'',$now,$now);";
// The backend version form saved only after the version had an author and a category.
$sql[] = "INSERT INTO tx_terfe2_domain_model_author (uid,pid,name,tstamp,crdate) VALUES (1,2,'Review',$now,$now);";
$eUid = 100; $vUid = 1000; $found = [];
foreach ($xml->extension as $ext) {
    $key = (string)$ext['extensionkey'];
    if (!in_array($key, $keys, true)) {
        continue;
    }
    $found[] = $key; $eUid++; $rows = []; $last = 0; $lastDate = -1; $n = 0;
    foreach ($ext->version as $ver) {
        $vUid++; $n++;
        // The catalogue stores dependencies only PHP-serialized; no class may be instantiated.
        $d = @unserialize((string)$ver->dependencies, ['allowed_classes' => false]); // nosemgrep: unserialize-use
        $json = (string)$ver->dependencies === '' ? null : json_encode($d);
        $date = (int)$ver->lastuploaddate;
        if ($date > $lastDate) { $lastDate = $date; $last = $vUid; }
        $vs = (string)$ver['version'];
        // composer_info has no default value, so it is written explicitly.
        $rows[] = "($vUid,2,$now,$now,$eUid," . $q($ver->title) . ',' . $q($ver->description) . ',' . $int($vs) . ',' . $q($vs) . ",$date," . $q($ver->state) . ',' . (int)$ver->reviewstate . ",''," . ($json === null ? 'NULL' : $q($json)) . ',' . $q($ver->authorname) . ",1,'plugin')";
    }
    $sql[] = "INSERT INTO tx_terfe2_domain_model_extension (uid,pid,tstamp,crdate,ext_key,frontend_user,versions,last_version,last_upload,composer_name) VALUES ($eUid,2,$now,$now," . $q($key) . ",'reviewer',$n,$last,$lastDate,'');";
    $sql[] = "INSERT INTO tx_terfe2_domain_model_version (uid,pid,tstamp,crdate,extension,title,description,version_number,version_string,upload_date,state,review_state,composer_info,dependencies,authorname,author,em_category) VALUES\n" . implode(",\n", $rows) . ';';
}
// A dependency on an extension without versions links to "No public version".
$eUid++;
$sql[] = "INSERT INTO tx_terfe2_domain_model_extension (uid,pid,tstamp,crdate,ext_key,frontend_user,versions,last_version,composer_name) VALUES ($eUid,2,$now,$now,'extbase','',0,0,'');";
echo implode("\n", $sql), "\n";
fwrite(STDERR, 'found: ' . implode(' ', $found) . ' versions=' . ($vUid - 1000) . "\n");
