# buildpack-chrome-with-chromedriver

A [Cloud Native Buildpack](https://buildpacks.io) that installs headless
[Google Chrome for Testing](https://developer.chrome.com/blog/chrome-for-testing/)
and the matching chromedriver into a Docker image, so your browser tests run
against the same Chrome on your laptop, in CI, and on Heroku.

## Why this exists

**Short version:** this buildpack puts Chrome into a **Docker image you can run
anywhere** - your laptop, CI, a dev container - instead of only inside a Heroku
app. If you never need Chrome outside of a Heroku deploy, use
[Heroku's buildpack](https://github.com/heroku/heroku-buildpack-chrome-for-testing)
instead; it is maintained by Heroku and is the simpler path.

### The problem

Browser tests are painful when the Chrome on your laptop is not the Chrome your
CI and production run. You want one definition of "the browser we test against"
that works in every environment.

Heroku's buildpack is a **classic buildpack**. Classic buildpacks only run as
part of a Heroku build - `git push heroku main`, or Heroku CI. What comes out is
a *slug*, a Heroku-specific archive. You cannot `docker run` a slug, and you
cannot use one as the base for a local development container. So Heroku's
buildpack gives you Chrome on a dyno and nowhere else.

This repository is a **Cloud Native Buildpack**. That is the newer, vendor-neutral
buildpack format, and the thing it produces is an ordinary Docker image. The same
Chrome install then works under `docker run`, docker compose, a dev container,
GitHub Actions, or a container-based Heroku deploy - all from one definition.

There is a second, less obvious reason. Heroku's buildpack installs Chrome
**inside the app directory**, at `/app/.chrome-for-testing`. In a container you
normally mount your working copy over the app directory so your edits appear
without a rebuild - and that mount hides everything installed underneath it,
Chrome included. This buildpack installs to `/layers/`, which is outside the app
directory (`/workspace` in a Cloud Native Buildpack image), so you can mount your
source over the app and Chrome is still on `PATH`.

### Which should I use?

| Your situation | Use |
| --- | --- |
| You deploy with `git push heroku main` and only need Chrome on the dyno or in Heroku CI | **Heroku's** |
| You want a Docker image with Chrome that runs locally *and* in CI, matching what you deploy | **This one** |
| You want a dev container where you mount your source and run browser tests | **This one** |
| You just want Chrome on your laptop to run tests directly, with no containers involved | **Neither** - install Chrome and chromedriver normally |

Note: an official shim once let classic buildpacks run in Cloud Native Buildpack
builds, but it has been
[deprecated and sunset](https://github.com/heroku/cnb-shim), so that is no longer
a way to get Heroku's buildpack into a Docker image.

### Other differences

- **`GOOGLE_CHROME_BIN` is exported** with the absolute path to the binary, for
  drivers that need to be told where Chrome is. Heroku's only sets `PATH`.
- **heroku-26 is tested and correct.** Ubuntu 26.04 removed the transitional
  `libatk1.0-0`, `libatk-bridge2.0-0` and `libcups2` package names; the
  dependency list here uses the `t64` names that actually resolve.

Otherwise this follows Heroku's buildpack closely - the install logic is derived
from it, and the same `GOOGLE_CHROME_CHANNEL` config var and
`chrome`/`chromedriver` binary names apply.

## Usage

Cloud Native Buildpacks are applied with [`pack`](https://buildpacks.io/docs/for-platform-operators/how-to/integrate-ci/pack/),
the buildpack CLI (`brew install buildpacks/tap/pack`). It takes your source plus
a list of buildpacks and produces a Docker image - no Dockerfile needed:

```sh
pack build my-app \
  --builder heroku/builder:24 \
  --buildpack urn:cnb:registry:reenhanced/buildpack-chrome-with-chromedriver \
  --buildpack heroku/ruby
```

That gives you a local image named `my-app` with Chrome, chromedriver, and your
app in it. Run your tests in it like any other image:

```sh
docker run --rm my-app bundle exec rspec
```

To mount your working copy so you can edit and re-run without rebuilding, mount
over the app directory - Chrome lives outside it and stays available:

```sh
docker run --rm -v "$PWD:/workspace" my-app bundle exec rspec
```

Buildpacks are usually committed to a project.toml instead of being passed as
flags every time:

```toml
[[build.buildpacks]]
uri = "urn:cnb:registry:reenhanced/buildpack-chrome-with-chromedriver"
```

## Supported stacks

`heroku-22`, `heroku-24`, and `heroku-26` - matching the `heroku/builder:22`,
`heroku/builder:24` and `heroku/builder:26` images, so pass whichever builder
matches the stack you deploy to.

## Channels

Set `GOOGLE_CHROME_CHANNEL` at build time to choose a release channel:

```sh
pack build my-app --env GOOGLE_CHROME_CHANNEL=beta ...
```

On Heroku it is an ordinary app config var, and can also be set in your app.json
for Review Apps and Heroku CI.

Valid values are `stable`, `beta`, `dev`, and `canary`. If unspecified, the
`stable` channel will be used.

Chrome and chromedriver are always installed as a matching pair, so the
`CHROMEDRIVER_VERSION` config var is not supported. The build will fail if it
is still set, or if another buildpack (such as `heroku/google-chrome`) has
already installed Chrome.

## Binaries

Both binaries are added to `PATH`, so you can invoke them as `chrome` and
`chromedriver`. Note that these are the Chrome for Testing binary names - there
is no `google-chrome` executable and no wrapper script that injects flags, so
you are responsible for passing the flags your environment needs. On a Heroku
dyno that generally means at least `--headless` and `--no-sandbox`.

The buildpack also exports `GOOGLE_CHROME_BIN` with the absolute path to the
Chrome binary.

## Selenium

Chromedriver looks for Chrome at `/usr/bin/google-chrome` by default, which
does not exist here. Point it at `$GOOGLE_CHROME_BIN` instead, which lets you
use the standard location locally and the buildpack's location on Heroku. An
example configuration for Ruby's Capybara:

```ruby
chrome_bin = ENV.fetch('GOOGLE_CHROME_BIN', nil)

Capybara.register_driver :chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = chrome_bin if chrome_bin
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')

  Capybara::Selenium::Driver.new(
     app,
     browser: :chrome,
     options: options
  )
end

Capybara.javascript_driver = :chrome
```

## Testing
(For maintainers)

`support/test.sh` builds the buildpack against a Heroku image and checks that
Chrome boots headless with no missing shared libraries. Pass the stack version:

```sh
./support/test.sh 26
```

## Publishing a new release
(For maintainers)

Bump `version` in buildpack.toml, add a CHANGELOG entry, then publish a GitHub
release. The Release workflow packages the buildpack and registers the new
version with the buildpack registry.

To publish by hand instead:

```sh
pack buildpack package --publish reenhanced/buildpack-chrome-with-chromedriver:3.0.0
pack buildpack register reenhanced/buildpack-chrome-with-chromedriver:3.0.0
```

Always include the version tag - without one the image publishes to `latest`,
which is not what the registry references.
