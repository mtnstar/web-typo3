# bin

Helper scripts for syncing the local dev setup with the remote hoster.

Scripts prefixed `local-` act on the local docker compose containers, scripts
prefixed `remote-` act on the remote hoster over ssh.

## Configuration

The `remote-*` scripts and `restore-file-folder` read their connection details
from `bin/secret-envs.sh`. It is not committed; create it from the example:

```sh
cp bin/secret-envs.sh.example bin/secret-envs.sh
```

| Variable                             | Used for                                            |
| ------------------------------------ | --------------------------------------------------- |
| `REMOTE_SSH_USER`, `REMOTE_SSH_SERVER` | ssh / rsync target                                |
| `REMOTE_VHOST_PATH`                  | TYPO3 document root on the remote                   |
| `REMOTE_MYSQL_HOST`, `REMOTE_MYSQL_USER`, `REMOTE_MYSQL_PASSWORD`, `REMOTE_MYSQL_DB` | remote database |
| `REMOTE_TYPO3_ENCRYPTION_KEY`        | written into the pushed `settings.php`              |
| `REMOTE_TYPO3_INSTALL_TOOL_PASSWORD` | written into the pushed `settings.php`              |
| `REMOTE_BASE_URL`                    | public URL of the site, used by `remote-warmup`     |

The `local-*` scripts and anything that calls `docker compose` expect the
containers to be running (`docker compose up -d`). Run the scripts from the
repository root.

## Local

### `local-flush-cache`

Flushes all TYPO3 caches in the local `typo3` container.

### `local-warmup`

Requests every blog post (doktype 137) on `http://localhost:4242` once, so
TYPO3 generates the processed images up front. Prints status code and response
time per page.

## Remote → local

### `remote-fetch`

Pulls the remote content into the local setup:

1. dumps the remote database and imports it into the local `database`
   container (overwrites the local database)
2. rsyncs the remote `fileadmin/` into `typo3/fileadmin/` (`--delete`, local
   files missing on the remote are removed)
3. makes `fileadmin` world-writable, so the container's `www-data` can create
   processed images

### `remote-fetch-extensions`

Rsyncs the remote `typo3conf/ext/` into `typo3/typo3conf/ext/` (`--delete`).

## Local → remote

### `remote-push-typo3-src`

Deploys the local TYPO3 source to the remote:

1. copies `/var/www/html` from the `typo3` container into `tmp/dist`,
   without `fileadmin`, `typo3temp` and `uploads`
2. replaces the database credentials, encryption key and install tool
   password in `tmp/dist/typo3conf/system/settings.php` with the remote values
3. creates `REMOTE_VHOST_PATH` and its `fileadmin`, `typo3temp` and `uploads`
   folders on the remote if missing
4. rsyncs `tmp/dist` to `REMOTE_VHOST_PATH` (`--delete`)

### `remote-push-fileadmin`

Rsyncs the local `typo3/fileadmin/` to the remote (`--delete`), skipping
`_processed_` since the remote regenerates those. Does a dry run by default:

```sh
bin/remote-push-fileadmin          # show what would change
bin/remote-push-fileadmin --apply  # sync for real
```

## Remote maintenance

### `remote-shell`

Opens an interactive login shell on the remote, in `REMOTE_VHOST_PATH`.

### `remote-flush-cache`

Flushes all TYPO3 caches on the remote.

### `remote-warmup`

Requests every visible standard page (doktype 1) and blog post (doktype 137)
on the remote once, so processed images are generated before visitors hit
them. The slug list is read from the remote database into `tmp/slugs.txt`.

```sh
bin/remote-warmup                      # uses REMOTE_BASE_URL
bin/remote-warmup https://example.com  # if REMOTE_BASE_URL is unset
```

## One-off

### `restore-file-folder`

Restores the `tt_content.file_folder` references lost in the move from the
previous hoster. Reads the source connection from `bin/secret-envs.sh.netzone`
and the target from `bin/secret-envs.sh`.

It generates `UPDATE` statements into `tmp/file-folder.sql`, only touching rows
whose `file_folder` is still empty on the target, so it is safe to re-run and
does not overwrite later edits.

```sh
bin/restore-file-folder          # generate tmp/file-folder.sql for review
bin/restore-file-folder --apply  # run the updates on the target
```
