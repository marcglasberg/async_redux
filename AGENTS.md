# async_redux

## Formatting

- Lines are at most 90 columns. Format with `dart format`, which reads `page_width: 90`
  from `analysis_options.yaml` (or pass `--page-width=90` explicitly).
- Most existing files in `lib/` and `test/` are not `dart format` output yet. Format the
  files you create, but don't reformat whole existing files without asking, because
  that creates large diffs. In existing files, wrap your changes at 90 columns by hand.
- `async_redux_lints/` is fully formatted, so run `dart format lib test` there freely.

## Access

- You can access the local code of projects `async_redux`, `async_redux_lints`, and
  `asyncredux.com` but do not ever access code of other projects.
