# TYPO3 13 → 14 Upgrade Guide

Upgrade from TYPO3 13.4.35 to 14.3.7 LTS.

## What changed

### Core
- TYPO3 source updated to 14.3.7
- PHP `memory_limit` raised to 512M in the `Dockerfile` (v14 needs at least 256M)
- `setup` removed from `PackageStates.php` (merged into `EXT:backend` in v14)
- Site language locale changed from `en-US` to `en_US.UTF-8`: v14 passes the locale to `setlocale()`
  as written, and the container only generates `en_US.UTF-8` (`Locale "en_US" … not found` otherwise)

### Extensions
| Extension | Before | After |
|---|---|---|
| bootstrap_package | 15.0.4 | 16.0.1 |
| blog | 13.0.1 | 14.0.1 |

### TypoScript is now loaded via site sets

bootstrap_package 16 no longer ships `Configuration/TypoScript/` — it only provides
**site sets**. The site is therefore switched from `sys_template` static includes to sets:

- `typo3conf/sites/mtnstar/config.yaml` — `dependencies: [mountain-star/template, blog/integration]`
- `typo3conf/sites/mtnstar/settings.yaml` — blog page uids, formerly constants in `sys_template` uid 3.
  It also pins the blog settings whose defaults changed in blog 14 back to their blog 13 values:
  blog 14 enables every meta element (authors, categories, tags, date, comments) in every meta block,
  which renders tags/date/comments twice below list entries; it also limits lists to 10 posts
  (`lists.posts.maximumDisplayedItems`), the tag widget to 5 tags and changes two comment settings
- The `sys_template` records (uid 3 on *adventures*, uid 4 on *home*) and the page TSconfig
  include on the root page are obsolete and must be removed (see procedure below). Otherwise
  bootstrap_package and blog are included twice and the old static include path no longer exists.

### Custom extension (mountain_star_bootstrap_template)
- New site set `mountain-star/template` in `Configuration/Sets/MountainStar/`
  (depends on `bootstrap-package/full`):
  - `settings.yaml` — former `constants.typoscript` values (logo, favicon, template paths, SCSS colors)
  - `setup.typoscript` — former `setup.typoscript` (theme SCSS, footer JS)
  - `page.tsconfig` — imports `TsConfig/Page/All.tsconfig`
- Removed `Configuration/TypoScript/` and the static template / page TSconfig registrations in
  `Configuration/TCA/Overrides/` — replaced by the set
- Removed `ExtensionManagementUtility::addPageTSConfig()` from `ext_localconf.php` (removed in v14)
- Replaced `<INCLUDE_TYPOSCRIPT>` (removed in v14) with `@import` in `All.tsconfig` and `BackendLayouts.tsconfig`
- Dependency constraints raised to TYPO3 14.3 / bootstrap_package 16 in `ext_emconf.php` and `composer.json`;
  `composer.json` description now carries the extension title (v14 reads it from there)

---

## Local upgrade procedure

### 1. Get the current live state

```bash
docker compose up -d
bin/remote-fetch
```

### 2. Rebuild the container

```bash
docker compose down && docker compose up --build -d
```

### 3. Regenerate the class loading information

The new blog / bootstrap_package versions ship different classes. The generated files in
`typo3conf/autoload/` are committed, so regenerate them:

```bash
chmod o+w typo3/typo3conf/autoload typo3/typo3conf/autoload/*.php
docker compose exec typo3 typo3 dumpautoload
chmod o-w typo3/typo3conf/autoload typo3/typo3conf/autoload/*.php
git status --short typo3/typo3conf/autoload
```

The container runs as `www-data`, which can't write to the mounted `typo3conf/autoload/` (owned by
your host user). Running the command as your host user instead fails, because TYPO3 also writes its
log to the `www-data`-owned `typo3temp` volume. The new `autoload_files.php` ends up owned by `www-data`;
that's fine to commit.

### 4. Remove the obsolete sys_template records and TSconfig include, migrate blog plugins

```bash
docker compose exec -T database mysql -u typo3 -ppassword typo3 <<'SQL'
UPDATE sys_template SET deleted = 1 WHERE uid IN (3, 4);
UPDATE pages SET tsconfig_includes = '' WHERE uid = 1;
UPDATE tt_content SET CType = list_type, list_type = '' WHERE CType = 'list' AND list_type LIKE 'blog\\_%';
SQL
```

The last statement migrates the blog plugins from the removed "Plugin" content type (`CType = list`)
to their own content types — the same 1:1 mapping blog's *Migrate "t3g/blog" plugins to content
elements* wizard does, but independent of whether the wizard gets offered. It must run before
*Analyze Database Structure* removes `tt_content.list_type`.

Backend alternative: delete both records in **Site Management → TypoScript**, and clear
**Page TSconfig → Include static Page TSconfig** in the page properties of *home*.

### 5. Make settings.php temporarily writable

```bash
chmod 666 typo3/typo3conf/system/settings.php
```

### 6. Run the Install Tool

Open **http://localhost:4242/typo3/install.php** and complete these steps in order:

1. **Maintenance → Analyze Database Structure** — apply only the *Add* / *Change* suggestions,
   **not** the *Remove* ones yet
2. **Upgrade → Run Upgrade Wizard** — run all pending wizards, in particular
   *Migrate "t3g/blog" plugins to content elements*. It needs `tt_content.list_type`, which the
   *Remove* suggestions rename to `zzz_deleted_list_type` — once that happened the wizard silently
   reports nothing to do and every blog page fails with
   `TypoScript object path "tt_content.list.20." does not exist`
3. **Maintenance → Analyze Database Structure** again — now apply the *Remove* suggestions
4. **Maintenance → Rebuild Reference Index**

### 7. Flush caches and check

```bash
bin/local-flush-cache
chmod 644 typo3/typo3conf/system/settings.php
```

- **Site Management → Sites**: site *mtnstar* lists the sets *Mountain Star Bootstrap Template* and *Blog: Integration*
- **Site Management → TypoScript → Active TypoScript**: no `sys_template` records left, set TypoScript present
- Frontend: logo, colors, footer, blog list, category filter + pagination

### 8. Commit

Commit `settings.php` (silent configuration upgrade), `PackageStates.php` and `autoload/` in this
repo, and the custom extension changes in its own repository.

---

## Remote upgrade procedure

The site is broken between step 1 and step 2, so run them back to back.

### 0. Check the PHP memory limit on remote

TYPO3 14 needs `memory_limit` ≥ 256M (512M recommended); v13 got by with 128M. Building the TCA
schema cache otherwise dies with "Allowed memory size of 134217728 bytes exhausted" in
`TcaSchemaFactory.php`. Check it in the remote Install Tool (**Environment → Environment Status**) and raise it in the hoster's PHP settings before pushing.

### 1. Push TYPO3 14 source to remote

```bash
bin/remote-push-typo3-src
```

### 2. Remove the obsolete sys_template records and migrate blog plugins on remote

```bash
source bin/secret-envs.sh
ssh $REMOTE_SSH_USER@$REMOTE_SSH_SERVER "mysql -h $REMOTE_MYSQL_HOST -u $REMOTE_MYSQL_USER -p'$REMOTE_MYSQL_PASSWORD' $REMOTE_MYSQL_DB -e \"UPDATE sys_template SET deleted = 1 WHERE uid IN (3, 4); UPDATE pages SET tsconfig_includes = '' WHERE uid = 1; UPDATE tt_content SET CType = list_type, list_type = '' WHERE CType = 'list' AND list_type LIKE 'blog\\\\_%';\""
```

### 3. Make settings.php temporarily writable on remote

```bash
ssh $REMOTE_SSH_USER@$REMOTE_SSH_SERVER \
  "chmod 666 $REMOTE_VHOST_PATH/typo3conf/system/settings.php"
```

### 4. Run the remote Install Tool

Open the remote Install Tool and complete the same steps as locally:

1. Maintenance → Analyze Database Structure — *Add* / *Change* only
2. Upgrade → Run Upgrade Wizard — all, including the blog plugin migration
3. Maintenance → Analyze Database Structure — now the *Remove* suggestions
4. Maintenance → Rebuild Reference Index

### 5. Restore settings.php permissions and flush caches

```bash
ssh $REMOTE_SSH_USER@$REMOTE_SSH_SERVER \
  "chmod 644 $REMOTE_VHOST_PATH/typo3conf/system/settings.php"
bin/remote-flush-cache
```
