# Drainpipe

Drainpipe is a composer package which provides build tool and testing helpers
for a Drupal site, including:

- Site and database updates
- Artifact packaging for deployment to a hosting provider
- Automated testing setup
- Integration with DDEV
- CI integration

* [Installation](#installation)
* [.env support](#env-support)
* [SASS Compilation](#sass-compilation)
    + [Setup](#setup)
* [JavaScript Compilation](#javascript-compilation)
    + [Setup](#setup-1)
* [Testing](#testing)
    + [Static Tests](#static-tests)
    + [Functional Tests](#functional-tests)
        - [PHPUnit](#phpunit)
        - [Nightwatch](#nightwatch)
    + [Autofix](#autofix)
* [Hosting Provider Integration](#hosting-provider-integration)
    + [Generic](#generic)
    + [Pantheon](#pantheon)
* [GitHub Actions Integration](#github-actions-integration)
    + [Composer Lock Diff](#composer-lock-diff)
    + [Pantheon](#pantheon-1)
* [GitLab CI Integration](#gitlab-ci-integration)
    + [Composer Lock Diff](#composer-lock-diff-1)
    + [Pantheon](#pantheon-2)

## Installation

```sh
composer config extra.drupal-scaffold.gitignore true
composer config --json extra.drupal-scaffold.allowed-packages "[\"lullabot/drainpipe\", \"lullabot/drainpipe-dev\"]"
composer require lullabot/drainpipe
composer require lullabot/drainpipe-dev --dev
```

or if using DDEV:
```sh
ddev composer config extra.drupal-scaffold.gitignore true
ddev composer config --json extra.drupal-scaffold.allowed-packages "[\"lullabot/drainpipe\", \"lullabot/drainpipe-dev\"]"
ddev composer require lullabot/drainpipe
ddev composer require lullabot/drainpipe-dev --dev
# Needed to enable the newly provided Selenium containers
ddev restart
```

This will scaffold out various files, most importantly a `Taskfile.yml` in the
root of your repository. Task is a task runner / build tool that aims to be
simpler and easier to use than, for example, GNU Make. Since it's written in Go,
Task is just a single binary and has no other dependencies. It's also
cross-platform with everything running through the same [shell interpreter](https://github.com/mvdan/sh).

You can see what tasks are available after installation by running
`./vendor/bin/task --list` or `ddev task --list` if you're running DDEV.

Your `Taskfile.yml` can be validated with JSON Schema:
```
curl -O https://taskfile.dev/schema.json
npx ajv-cli validate -s schema.json -d scaffold/Taskfile.yml
```

See [.github/workflows/validate-taskfile.yml](`.github/workflows/validate-taskfile.yml`)
for an example of this in use.

---

## .env support
Drainpipe will add `.env` file support for managing environment variables.
This consists of:
- Creation of a `.env` and `.env.defaults` file
- Default `Taskfile.yml` contains [dotenv support](https://taskfile.dev/usage/#env-files)
  _note: real environment variables will override these_
- Drupal integration via [`vlucas/phpdotenv`](https://packagist.org/packages/vlucas/phpdotenv)
  To enable this, add the following to your `composer.json`:
  ```
  "autoload-dev":
  {
    "files": [
      "vendor/lullabot/drainpipe/scaffold/env/dotenv.php"
    ]
  },
  ```
  **You will need to restart DDEV if you make any changes to `.env` or`.env.defaults`**

## SASS Compilation

This compiles CSS assets using [Sass](https://sass-lang.com/). It also supports
the following:
- Globbing
  ```
  // Base
  @use "sass/base/**/*";
  ```
- [Modern Normalizer](https://www.npmjs.com/package/modern-normalize)
- Autoprefixer configured through a [`.browserslistrc`](https://github.com/postcss/autoprefixer)
  file in the project root

### Setup
- Add @lullabot/drainpipe-sass to your project
  `yarn add @lullabot/drainpipe-sass` or `npm install @lullabot/drainpipe-sass`
- Edit `Taskfile.yml` and add `DRAINPIPE_SASS` in the `vars` section
  ```
  vars:
    DRAINPIPE_SASS: |
      web/themes/custom/mytheme/style.scss:web/themes/custom/mytheme/style.css
      web/themes/custom/myothertheme/style.scss:web/themes/custom/myothertheme/style.css
  ```
- Run `task sass:compile` to check it works as expected
- Run `task sass:watch` to check file watching works as expected
- Add the task to a task that compiles all your assets e.g.
  ```
  assets:
    desc: Builds assets such as CSS & JS
    cmds:
      - yarn install --immutable --immutable-cache --check-cache
      - task: sass:compile
      - task: javascript:compile
  assets:watch:
    desc: Builds assets such as CSS & JS, and watches them for changes
    deps: [sass:watch, javascript:watch]
  ```

## JavaScript Compilation

JavaScript bundling support is via [esbuild](https://esbuild.github.io/).

### Setup
- Add @lullabot/drainpipe-javascript to your project
  `yarn add @lullabot/drainpipe-javascript` or `npm install @lullabot/drainpipe-javascript`
- Edit `Taskfile.yml` and add `DRAINPIPE_JAVASCRIPT` in the `vars section`
  ```
  DRAINPIPE_JAVASCRIPT: |
    web/themes/custom/mytheme/script.js:web/themes/custom/mytheme/script.min.js
    web/themes/custom/myotherthemee/script.js:web/themes/custom/myothertheme/script.min.js
  ```
  Source and target need to have the same basedir (web or docroot) due to being
  unable to provide separate entryNames.
  See https://github.com/evanw/esbuild/issues/224
- Run `task javascript:compile` to check it works as expected
- Run `task javascript:watch` to check file watching works as expected
- Add the task to a task that compiles all your assets e.g.
  ```
  assets:
    desc: Builds assets such as CSS & JS
    cmds:
      - yarn install --immutable --immutable-cache --check-cache
      - task: sass:compile
      - task: javascript:compile
  assets:watch:
    desc: Builds assets such as CSS & JS, and watches them for changes
    deps: [sass:watch, javascript:watch]
  ```

## Testing
This is provided by the separate [drainpipe-dev](https://github.com/Lullabot/drainpipe-dev)
package (so the development/testing dependencies aren't installed in production
builds).

### Static Tests

All the below static code analysis tests can be run with `task test:static`

| Test Type | Task Command             | Description                                                                                                                                                                                                                                                            |
|-----------|--------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Security  | task test:security       | Runs security checks for composer packages against the [FriendsOfPHP Security Advisory Database](https://github.com/FriendsOfPHP/security-advisories) and Drupal core and contributed modules against [Drupal's Security Advisories](https://www.drupal.org/security). |
| Lint      | task test:lint           | - YAML lint on `.yml` files in the `web` directory<br />- Twig lint on files in `web/modules`, `web/profiles`, and `web/themes`<br />- `composer validate`<br />These cannot currently be customised. See [#9](https://github.com/Lullabot/drainpipe-dev/issues/9).    |
| PHPStan   | task test:phpstan        | Runs [PHPStan](https://phpstan.org/) with [mglaman/phpstan-drupal](https://github.com/mglaman/phpstan-drupal) on`web/modules/custom`, `web/themes/custom`, and `web/sites`.                                                                                            |
| PHPUnit   | task test:phpunit:static | Runs Unit tests in `web/modules/custom/**/tests/src/Unit` and `test/phpunit/**/Unit`                                                                                                                                                                                   |
| PHPCS     | task test:phpcs          | Runs PHPCS with Drupal coding standards provided by [Coder module](https://www.drupal.org/project/coder                                                                                                                                                                |


### Functional Tests

Functional tests require some mechanism of creating a functing Drupal site to
test against. All the below tests can be run with `task test:functional`

#### PHPUnit
`task test:phpunit:functional`

Runs PHPUnit tests in:
- `web/modules/custom/**/tests/src/Kernel`
- `test/phpunit/**/Kernel`
- `web/modules/custom/**/tests/src/Functional`
- `test/phpunit/**/Functional`
- `web/modules/custom/**/tests/src/FunctionalJavaScript`
- `test/phpunit/**/FunctionalJavaScript`

You will need to make sure you have a working Drupal site before you're
able to run these.

Support for [Drupal Test Traits](https://gitlab.com/weitzman/drupal-test-traits)
is included, set this in your `Taskfile.yml` vars:

```
vars:
  DRUPAL_TEST_TRAITS: true
```
This will additionally look for tests in:
- `web/modules/custom/**/tests/src/ExistingSite`
- `test/phpunit/**/ExistingSite`
- `web/modules/custom/**/tests/src/ExistingSiteJavascript`
- `test/phpunit/**/ExistingSiteJavascript`

_beware: DTT tests will run against the main working Drupal site rather than
installing a new instance in isolation_

#### Nightwatch

Runs functional browser tests with [Nightwatch](https://nightwatchjs.org/).

Run `test:nightwatch:setup` to help you setup your project to run Nightwatch
tests by installing the necessary node packages and DDEV configurations.

If you are using DDEV, Drainpipe will have created a
`.ddev/docker-compose.selenium.yaml` file that provides standalone Firefox and
Chrome as containers, as well as an example test in `test/nightwatch/example.nightwatch.js`.

To run the above test you will need to have a working Drupal installation in the
Firefox and Chrome containers. You can run the `test:nightwatch:siteinstall`
helper task to run the Drupal site installer for both sites with your existing
configuration.

After you've verified this test works, you can ignore it in your `composer.json`:
```
"extra": {
        "drupal-scaffold": {
            "file-mapping": {
                "[project-root]/test/nightwatch/example.nightwatch.js": {
			"mode": "skip"
		}
	}
}
```

Nightwatch tests must have the suffix `.nightwatch.js` to be recognised by
the test runner.

Whilst tests are running, you can view them in realtime through your browser.

https://<ddev-site-name>:7900 for Chrome
https://<ddev-site-name>:7901 for Firefox

The password for all environments is `secret`.

### Autofix

`task test:autofix` attempts to autofix any issues discovered by tests.
Currently, this is just fixing PHPCS errors with PHPCBF.

## Hosting Provider Integration

### Generic
Generic helpers for deployments can be found in [`tasks/snapshot.yml`,](tasks/snapshot.yml)
[`tasks/deploy.yml`](tasks/deploy.yml), and [`tasks/drupal.yml`](tasks/drupal.yml)

|                                    |                                                                               |
|------------------------------------|-------------------------------------------------------------------------------|
| `task drupal:composer:development` | Install composer dependencies                                                 |
| `task drupal:composer:production`  | Install composer dependencies without devDependencies                         |
| `task drupal:export-db`            | Exports a database fetches with a *:fetch-db command                          |
| `task drupal:import-db`            | Imports a database fetched with a *:fetch-db command                          |
| `task drupal:install`              | Runs the site installer                                                       |
| `task drupal:maintenance:off`      | Turn off Maintenance Mode                                                     |
| `task drupal:maintenance:on`       | Turn on Maintenance Mode                                                      |
| `task drupal:update`               | Run Drupal update tasks after deploying new code                              |
| `task snapshot:archive`            | Creates a snapshot of the current working directory and exports as an archive |
| `task snapshot:directory`          | Creates a snapshot of the current working directory                           |

### Pantheon
Pantheon specific tasks are contained in [`tasks/pantheon.yml`](tasks/pantheon.yml).
Add the following to your `Taskfile.yml`'s `includes` section to use them:
```yml
includes:
  pantheon: ./vendor/lullabot/drainpipe/tasks/pantheon.yml
```
|                          |                                                                             |
|--------------------------|-----------------------------------------------------------------------------|
| `task pantheon:fetch-db` | Fetches a database from Pantheon. Set `PANTHEON_SITE_ID` in Taskfile `vars` |

See below for CI specific integrations for hosting providers.

## GitHub Actions Integration

Add the following to `composer.json` for generic GitHub Actions that will be
copied to `.github/actions/drainpipe` in your project:
```json
"extra": {
  "drainpipe": {
    "github": []
  }
}
```

They are composite actions which can be used in any of your workflows e.g.
```
- uses: ./.github/actions/drainpipe/set-env

- name: Install and Start DDEV
  uses: ./.github/actions/drainpipe/ddev
  with:
    git-name: Drainpipe Bot
    git-email: no-reply@example.com
    ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
    ssh-known-hosts: ${{ secrets.SSH_KNOWN_HOSTS }}
```

### Composer Lock Diff
Update Pull Request descriptions with a markdown table of any changes detected
in `composer.lock` using [composer-lock-diff](https://github.com/davidrjonas/composer-lock-diff).

```json
"extra": {
    "drainpipe": {
        "github": ["ComposerLockDiff"]
    }
}
```

### Pantheon

To enable deployment of Pantheon Review Apps:

- Add the following composer.json
  ```json
  "extra": {
      "drainpipe": {
          "github": ["PantheonReviewApps"]
      }
  }
  ```
- Run `composer install` to install the workflow to `.github/workflows`
- Add the following secrets to your repository:
    - `PANTHEON_TERMINUS_TOKEN` See https://pantheon.io/docs/terminus/install#machine-token
    - `PANTHEON_SITE_NAME` The canonical site name
    - `SSH_PRIVATE_KEY` A private key of a user which can push to Pantheon
    - `SSH_KNOWN_HOSTS` The result of running `ssh-keyscan -H codeserver.dev.$PANTHEON_SITE_ID.drush.in`
    - `TERMINUS_PLUGINS` (optional) Comma-separated list of Terminus plugins to be available
    - `PANTHEON_REVIEW_USERNAME` (optional) A username for HTTP basic auth local
    - `PANTHEON_REVIEW_PASSWORD` (optional) The password to lock the site with

## GitLab CI Integration

Add the following to `composer.json` for GitLab helpers:
```json
"extra": {
  "drainpipe": {
    "gitlab": []
  }
}
```

This will import [`scaffold/gitlab/Common.gitlab-ci.yml`](scaffold/gitlab/Common.gitlab-ci.yml),
which provides helpers that can be used in GitLab CI with [includes and
references](https://docs.gitlab.com/ee/ci/yaml/yaml_specific_features.html#reference-tags).

### Composer Lock Diff
Updates Merge Request descriptions with a markdown table of any changes detected
in `composer.lock` using [composer-lock-diff](https://github.com/davidrjonas/composer-lock-diff).
Requires `GITLAB_ACCESS_TOKEN` variable to be set, which is an access token with
`api` scope.

```json
"extra": {
    "drainpipe": {
        "gitlab": ["ComposerLockDiff"]
    }
}
```

### Pantheon
```json
"extra": {
    "drainpipe": {
        "gitlab": ["Pantheon", "Pantheon Review Apps"]
    }
}
```

This will setup Merge Request deployment to Pantheon Multidev environments. See
[scaffold/gitlab/gitlab-ci.example.yml] for an example. You can also just
include which will give you helpers that you can include and reference for tasks
such as setting up [Terminus](https://pantheon.io/docs/terminus). See
[scaffold/gitlab/Pantheon.gitlab-ci.yml](scaffold/gitlab/Pantheon.gitlab-ci.yml).
