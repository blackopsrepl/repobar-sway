# Changelog

All notable changes to this project will be documented in this file. See [commit-and-tag-version](https://github.com/absolute-version/commit-and-tag-version) for commit guidelines.

## [1.0.0](///compare/v0.1.1...v1.0.0) (2026-05-16)


### Features

* **runtime:** preserve refresh state and pinned ordering a00bf28
* **ui:** center modal and drag pinned repos 8711f86

## 1.0.0 (2026-05-16)

### Features

* center the QuickShell UI as a taller modal overlay
* remove the pinned repository cap and preserve configured pinned order
* add drag and CLI reordering for pinned repositories
* preserve provider caches when refreshes overlap provider switches or same-provider pin changes

### Documentation

* align README, AGENTS, wireframe, PRD, architecture, and CLI docs to the current runtime
* refresh README screenshots for the modal overlay and pinned repo drag controls

## 0.1.1 (2026-05-16)


### Features

* add RepoBar Linux runtime 3b8d0ad
* add single-path runtime store 2af7a90
* make QuickShell panel state-driven 0e4b708
* route runtime actions through daemon 589be3e
* **runtime:** expose activity and work item views b13c4a8
* **ui:** add spiffy repo action controls b564c7f


### Bug Fixes

* show commit activity heatmap 5447615
