# Change Log
All notable changes to this project will be documented in this file.

## 2023-11-15
- Initial Release

## 2024-02-19
- Changes build script to use dynamic chrome url

## 2024-03-21
- Updates build script to install chromedriver since chrome is installed via apt
- TODO: Verify versions match

## 2024-04-10
- Remove deprecated bionic stack

## 2024-09-17
- Rewrite to base upon https://github.com/heroku/heroku-buildpack-chrome-for-testing

## 2024-12-16
- Cleanup incorrect paths

## 2026-09-10
- Adds support for the heroku-26 stack (Ubuntu 26.04), which needs the t64
  package names for atk, atk-bridge and cups
- Updates the Docker-based tests to the CNB layer layout used since 2.0.0
- Drops support for the retired heroku-20 stack and the io.buildpacks.stacks.jammy
  stack ID, leaving heroku-22, heroku-24 and heroku-26
- Fixes GOOGLE_CHROME_CHANNEL and the CHROMEDRIVER_VERSION guard, which read the
  layer's own env directory instead of the platform's, so they never took effect
- Updates the README, which still described the shims removed in 2.0.0
