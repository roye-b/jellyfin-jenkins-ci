# Jellyfin Jenkins CI Pipeline

## Project Overview

This project implements a Declarative Jenkins CI pipeline for Jellyfin 10.10.7 on Linux.

The pipeline builds Jellyfin Server (.NET 8) and Jellyfin Web (Node.js 20) from pinned Git commits.

## Architecture

- **Source Control:** GitHub
- **CI Server:** Jenkins
- **Build Agent:** Ubuntu 24.04 (Linux x86_64)
- **Pipeline Definition:** Jenkinsfile (Groovy)
- **Container Platform:** Docker

## Source Repositories

| Component | Repository | Version |
|---|---|---|
| Jellyfin Server | https://github.com/jellyfin/jellyfin | v10.10.7 |
| Jellyfin Web | https://github.com/jellyfin/jellyfin-web | v10.10.7 |

Exact source revisions are defined in `ci/source-lock.json`.

## Pipeline Stages

### 1. Checkout and Preflight

- Checkout the CI repository.
- Read the source lock file.
- Checkout Jellyfin Server and Web.
- Verify both Git commit SHAs.

### 2. Parallel CI

**Server CI**
- Restore .NET dependencies.
- Build the Jellyfin solution.

**Web CI**
- Install dependencies using `npm ci`.
- Compile production assets using `npm run build:production`.

## Toolchain

| Tool | Version |
|---|---|
| .NET SDK | 8.0.133 |
| Node.js | 20.20.2 |
| npm | 10.8.2 |

These are the currently installed lab versions. Containerized, pinned toolchains are planned for the final pipeline.

## Running the Pipeline

1. Open Jenkins.
2. Select the `Jellyfin-CI` job.
3. Click **Build Now**.
4. Open **Console Output** to inspect the results.

The job loads its `Jenkinsfile` from this repository's `main` branch.

## Current Status

- [x] Jenkins agent configuration
- [x] Source checkout and SHA verification
- [x] Parallel Server and Web CI stages configured
- [ ] Confirm successful Server and Web builds
- [ ] Automated tests and coverage reports
- [ ] NuGet locked dependency restore
- [ ] Containerized and pinned build toolchains
- [ ] Multi-stage Docker image
- [ ] Container smoke tests
- [ ] Artifact archival and cleanup
- [ ] Failure and concurrency evidence

## Notes

This project is a work in progress. The final goal is to produce a tested, verified Jellyfin Linux container image with reproducible build inputs and archived CI evidence.
