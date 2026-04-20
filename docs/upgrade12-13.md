# TYPO3 12 → 13 Upgrade Guide

Upgrade from TYPO3 12.4.41 to 13.4.28.

## What changed

### Core
- TYPO3 source updated to 13.4.28
- `t3editor` removed from `PackageStates.php` (merged into `EXT:backend` in v13)
- `settings.php` cleaned up by TYPO3's silent configuration upgrade (deprecated keys removed)

### Extensions
| Extension | Before | After |
|---|---|---|
| bootstrap_package | 14.0.7 | 15.0.4 |
| blog | 12.0.2 | 13.0.1 |

### Custom extension (mountain_star_bootstrap_template)
- Replaced deprecated `<INCLUDE_TYPOSCRIPT: source="FILE:...">` with `@import '...'` in `setup.typoscript` and `constants.typoscript`
- Updated `addPageTSConfig()` call in `ext_localconf.php` to use `@import "..."` syntax
- Extended `bootstrap_package` dependency range to include `^15.0` in `ext_emconf.php` and `composer.json`

---

## Local upgrade procedure

### 1. Rebuild the container

```bash
podman compose down && podman compose up --build -d
```

### 2. Fix the sys_refindex table

`sys_refindex` gained many new columns in TYPO3 13. Since it is a pure cache table it is safe to recreate it. Run this against the local database:

```sql
DROP TABLE IF EXISTS sys_refindex;
CREATE TABLE sys_refindex (
    hash varchar(32) CHARACTER SET ascii COLLATE ascii_bin DEFAULT '' NOT NULL,
    tablename varchar(64) DEFAULT '' NOT NULL,
    recuid int unsigned DEFAULT 0 NOT NULL,
    field varchar(64) DEFAULT '' NOT NULL,
    hidden smallint unsigned DEFAULT 0 NOT NULL,
    starttime int unsigned DEFAULT 0 NOT NULL,
    endtime int unsigned DEFAULT 2147483647 NOT NULL,
    t3ver_state int unsigned DEFAULT 0 NOT NULL,
    flexpointer varchar(255) DEFAULT '' NOT NULL,
    softref_key varchar(30) DEFAULT '' NOT NULL,
    softref_id varchar(40) DEFAULT '' NOT NULL,
    sorting int DEFAULT 0 NOT NULL,
    workspace int unsigned DEFAULT 0 NOT NULL,
    ref_table varchar(64) DEFAULT '' NOT NULL,
    ref_uid int DEFAULT 0 NOT NULL,
    ref_field varchar(64) DEFAULT '' NOT NULL,
    ref_hidden smallint unsigned DEFAULT 0 NOT NULL,
    ref_starttime int unsigned DEFAULT 0 NOT NULL,
    ref_endtime int unsigned DEFAULT 2147483647 NOT NULL,
    ref_t3ver_state int unsigned DEFAULT 0 NOT NULL,
    ref_sorting int DEFAULT 0 NOT NULL,
    ref_string varchar(1024) DEFAULT '' NOT NULL,
    PRIMARY KEY (hash),
    KEY lookup_rec (tablename,recuid,field,workspace,ref_t3ver_state,ref_hidden,ref_starttime,ref_endtime),
    KEY lookup_ref (ref_table,ref_uid,tablename,workspace,t3ver_state,hidden,starttime,endtime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

Via podman:
```bash
podman compose exec database mysql -u typo3 -ppassword typo3
```

### 3. Make settings.php temporarily writable

The Install Tool needs to write to `settings.php` on first load:

```bash
chmod 666 typo3/typo3conf/system/settings.php
```

### 4. Run the Install Tool

Open **http://localhost:4242/typo3/install.php** and complete these steps in order:

1. **Maintenance → Analyze Database Structure** — apply all suggested changes
2. **Upgrade → Run Upgrade Wizard** — run all pending wizards
3. **Maintenance → Rebuild Reference Index**

### 5. Flush caches

```bash
bin/local-flush-cache
```

### 6. Commit the updated settings.php

After the Install Tool finishes, `settings.php` will have been updated with TYPO3 13 defaults. Commit those changes.

---

## Remote upgrade procedure

### 1. Push TYPO3 13 source to remote

```bash
bin/remote-push-typo3-src
```

### 2. Fix the sys_refindex table on remote

Connect to the remote database (credentials in `bin/secret-envs.sh`, variable `$REMOTE_VHOST_PATH`) and run the same SQL as in step 2 above.

### 3. Make settings.php temporarily writable on remote

```bash
ssh $REMOTE_SSH_USER@$REMOTE_SSH_SERVER \
  "chmod 666 $REMOTE_VHOST_PATH/typo3conf/system/settings.php"
```

### 4. Run the remote Install Tool

Open the remote Install Tool and complete the same steps as locally:

1. Maintenance → Analyze Database Structure
2. Upgrade → Run Upgrade Wizard
3. Maintenance → Rebuild Reference Index

### 5. Restore settings.php permissions

```bash
ssh $REMOTE_SSH_USER@$REMOTE_SSH_SERVER \
  "chmod 644 $REMOTE_VHOST_PATH/typo3conf/system/settings.php"
```
